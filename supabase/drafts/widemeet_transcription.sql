begin;
-- Private local ASR queue; no public content, no automatic publication.
create table public.wm_transcription_jobs(
 recording_id uuid primary key references public.wm_recording_runs(id),
 room_id uuid not null references public.wm_rooms(id),
 requester_id uuid not null references public.wm_accounts(id),
 status text not null default 'queued' check(status in ('queued','running','complete','failed')),
 attempts integer not null default 0 check(attempts between 0 and 3),
 lease uuid,
 lease_until timestamptz,
 result jsonb,
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 check((status='running')=(lease is not null and lease_until is not null)),
 check((status='complete')=(result is not null))
);
create index wm_asr_queue on public.wm_transcription_jobs(status,created_at);
alter table public.wm_transcription_jobs enable row level security;
revoke all on public.wm_transcription_jobs from public,anon,authenticated;
grant select,insert,update,delete on public.wm_transcription_jobs to service_role;
create function public.wm_transcription_source(p_recording uuid,p_room uuid,p_requester uuid)
returns jsonb language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select jsonb_build_object('recording_id',v.id,'room_id',r.id,'storage_key',v.storage_key,'sha256',v.content_sha256,'bytes',v.bytes)
 from public.wm_recording_runs v join public.wm_rooms r on r.id=v.room_id
 join public.wm_minutes_eligibility e on e.room_id=r.id and e.premium and e.retain_until>now()
 join public.wm_accounts a on a.id=r.host_id and a.enabled and not a.password_change_required
 join public.wm_memberships m on m.account_id=a.id and m.workspace_id=r.workspace_id and m.enabled and m.role in ('owner','promoteur','manager')
 join public.wm_workspaces w on w.id=r.workspace_id and w.enabled
 where v.id=p_recording and r.id=p_room and r.host_id=p_requester and r.state->>'status'='ended' and r.state->>'cancelled' is distinct from 'true'
 and v.phase='complete' and v.disposition='retain' and v.storage_key is not null and v.finished_at>now()-interval '90 days'
 and v.bytes between 1000 and 134217728 and v.content_sha256~'^[a-f0-9]{64}$'
$wm$;
revoke all on function public.wm_transcription_source(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_transcription_source(uuid,uuid,uuid) to service_role;
create function public.wm_transcription_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; rid uuid; recid uuid; j public.wm_transcription_jobs%rowtype; v jsonb; src jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for share;
 if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;
 if not found then return null;end if;
 perform 1 from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled and role in ('owner','promoteur','manager') for share;
 if not found then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;
 if not found or not exists(select 1 from public.wm_session_context(p_hash)) then return null;end if;
 rid:=(p_data->>'room_id')::uuid;
 if rid is null or not exists(select 1 from public.wm_rooms r join public.wm_minutes_eligibility e on e.room_id=r.id where r.id=rid and r.workspace_id=s.workspace_id and r.host_id=s.account_id and e.premium and e.retain_until>clock_timestamp()) then return null;end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(q) order by q.finished_at),'[]'::jsonb) into v from (
    select r.id as recording_id,r.finished_at,coalesce(j.status,'not_requested') as status,coalesce(j.attempts,0) as attempts
    from public.wm_recording_runs r left join public.wm_transcription_jobs j on j.recording_id=r.id
    where r.room_id=rid and public.wm_transcription_source(r.id,rid,s.account_id) is not null
    order by r.finished_at limit 100
  ) q;return jsonb_build_object('items',v);
 end if;
 recid:=(p_data->>'recording_id')::uuid;
 src:=public.wm_transcription_source(recid,rid,s.account_id);
 if src is null then return null;end if;
 select * into j from public.wm_transcription_jobs where recording_id=recid for update;
 if p_action='request' then
  if not found then
   if (select count(*) from public.wm_transcription_jobs where requester_id=s.account_id and status in ('queued','running'))>=5 then return null;end if;
   insert into public.wm_transcription_jobs(recording_id,room_id,requester_id) values(recid,rid,s.account_id) returning * into j;
  end if;
 elsif p_action='retry' then
  if not found or j.status<>'failed' or j.attempts>=3 then return null;end if;
  update public.wm_transcription_jobs set status='queued',updated_at=clock_timestamp() where recording_id=recid returning * into j;
 elsif p_action='read' then
  if not found then return jsonb_build_object('status','not_requested','attempts',0);end if;
 else return null;end if;
 return jsonb_build_object('recording_id',recid,'status',j.status,'attempts',j.attempts,'result',j.result);
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_transcription_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_transcription_action(text,text,jsonb) to service_role;
create function public.wm_transcription_worker(p_action text,p_recording uuid,p_lease uuid,p_result jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare j public.wm_transcription_jobs%rowtype; src jsonb; seg jsonb; prev bigint:=0; startms bigint; endms bigint; duration bigint;
begin
 if p_action='claim' then
  if p_lease is null then return null;end if;
  update public.wm_transcription_jobs set status='failed',lease=null,lease_until=null,updated_at=clock_timestamp()
   where status='running' and lease_until<=clock_timestamp() and attempts>=3;
  select * into j from public.wm_transcription_jobs x where (x.status='queued' or x.status='running' and x.lease_until<=clock_timestamp()) and x.attempts<3
   and public.wm_transcription_source(x.recording_id,x.room_id,x.requester_id) is not null order by x.created_at for update skip locked limit 1;
  if not found then return null;end if;
  src:=public.wm_transcription_source(j.recording_id,j.room_id,j.requester_id);
  if src is null then return null;end if;
  update public.wm_transcription_jobs set status='running',lease=p_lease,lease_until=clock_timestamp()+interval '12 minutes',attempts=attempts+1,updated_at=clock_timestamp() where recording_id=j.recording_id;
  return src||jsonb_build_object('lease',p_lease);
 end if;
 select * into j from public.wm_transcription_jobs where recording_id=p_recording and status='running' and lease=p_lease and lease_until>clock_timestamp() for update;
 if not found then return null;end if;
 if p_action='fail' or public.wm_transcription_source(j.recording_id,j.room_id,j.requester_id) is null then
  update public.wm_transcription_jobs set status='failed',lease=null,lease_until=null,updated_at=clock_timestamp() where recording_id=j.recording_id;
  return jsonb_build_object('status','failed');
 end if;
 if p_action<>'finish' or jsonb_typeof(p_result) is distinct from 'object' or p_result->>'model' is distinct from 'whisper-tiny-local'
 or coalesce(p_result->>'language','')!~'^[a-z]{2,3}$' or jsonb_typeof(p_result->'segments') is distinct from 'array'
 or jsonb_array_length(p_result->'segments')>1000 or octet_length(p_result::text)>500000
 or coalesce(p_result->>'duration_ms','')!~'^[0-9]{1,8}$' then return null;end if;
 duration:=(p_result->>'duration_ms')::bigint;
 if duration not between 1 and 7200000 then return null;end if;
 for seg in select value from jsonb_array_elements(p_result->'segments') loop
  if jsonb_typeof(seg) is distinct from 'object' or coalesce(seg->>'start_ms','')!~'^[0-9]{1,8}$' or coalesce(seg->>'end_ms','')!~'^[0-9]{1,8}$'
   or jsonb_typeof(seg->'text') is distinct from 'string' or length(btrim(seg->>'text')) not between 1 and 2000
   or jsonb_typeof(seg->'uncertain') is distinct from 'boolean' then return null;end if;
  startms:=(seg->>'start_ms')::bigint;endms:=(seg->>'end_ms')::bigint;
  if startms<prev or endms<=startms or endms>duration+1000 then return null;end if;
  prev:=startms;
 end loop;
 update public.wm_transcription_jobs set status='complete',result=p_result,lease=null,lease_until=null,updated_at=clock_timestamp() where recording_id=j.recording_id;
 return jsonb_build_object('status','complete');
exception when invalid_text_representation or numeric_value_out_of_range then return null;
end $wm$;
revoke all on function public.wm_transcription_worker(text,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.wm_transcription_worker(text,uuid,uuid,jsonb) to service_role;
commit;
