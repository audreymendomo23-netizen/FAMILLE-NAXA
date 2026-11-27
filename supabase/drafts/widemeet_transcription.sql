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
 speaker_annotations jsonb not null default '[]'::jsonb check(jsonb_typeof(speaker_annotations)='array' and jsonb_array_length(speaker_annotations)<=1000),
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
-- Extractive review only: verbatim source references, no fabricated commitments or identities.
-- This is not an abstractive model, a decision approval or automatic task creation.
create function public.wm_transcription_review(p_result jsonb,p_recording uuid)
returns jsonb language sql immutable security invoker set search_path=pg_catalog,public as $wm$
 with segments as (
  select value as seg,ord::integer as ord,count(*) over() as total
  from jsonb_array_elements(coalesce(p_result->'segments','[]'::jsonb)) with ordinality t(value,ord)
 ), excerpts as (
  select seg,ord from segments
  order by case when ord=1 or ord=total or ord=(total+1)/2 then 0 else 1 end, (seg->>'uncertain')::boolean,ord limit 5
 ), candidates as (
  select seg,ord from segments
  where seg->>'uncertain'='false'
   and lower(seg->>'text') ~ '^[[:space:]]*(nous avons décidé|nous décidons|la décision est|we decided|we have decided|we agree to|action item:|action à réaliser:)'
   and lower(seg->>'text') !~ '(pas décidé|not decided|not agree|ne décidons pas|proposons|suggest|propose|hypothèse|hypothetical|[?])'
  order by ord limit 10
 )
 select jsonb_build_object('method','extractive-review-v1','recording_id',p_recording,
  'excerpts',coalesce((select jsonb_agg(seg||jsonb_build_object('segment_index',ord-1) order by ord) from excerpts),'[]'::jsonb),
  'decision_candidates',coalesce((select jsonb_agg(seg||jsonb_build_object('segment_index',ord-1) order by ord) from candidates),'[]'::jsonb))
$wm$;
revoke all on function public.wm_transcription_review(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.wm_transcription_review(jsonb,uuid) to service_role;
-- Canonical source view: original-language cues, exact segment identities and explicit unknown speaker.
-- This is archival timing, not a live caption or diarization claim.
create function public.wm_transcription_cues(p_result jsonb,p_recording uuid)
returns jsonb language sql immutable security invoker set search_path=pg_catalog,public as $wm$
 select jsonb_build_object('method','source-cues-v1','recording_id',p_recording,
  'language',p_result->>'language','duration_ms',p_result->'duration_ms',
  'cues',coalesce(jsonb_agg(jsonb_build_object('segment_index',ord-1,'start_ms',seg->'start_ms',
    'end_ms',seg->'end_ms','text',seg->>'text','uncertain',seg->'uncertain',
    'speaker_id',null,'speaker_status','unknown') order by ord),'[]'::jsonb))
 from jsonb_array_elements(p_result->'segments') with ordinality as t(seg,ord)
$wm$;
revoke all on function public.wm_transcription_cues(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.wm_transcription_cues(jsonb,uuid) to service_role;
-- A literal query is not an instruction to the model. Search returns source excerpts only.
create function public.wm_transcription_search(p_result jsonb,p_recording uuid,p_query text)
returns jsonb language sql immutable security invoker set search_path=pg_catalog,public as $wm$
 select jsonb_build_object('method','literal-source-search-v1','recording_id',p_recording,
  'matches',coalesce(jsonb_agg(q.seg||jsonb_build_object('segment_index',q.ord-1) order by q.ord),'[]'::jsonb))
 from (select seg,ord from jsonb_array_elements(p_result->'segments') with ordinality as t(seg,ord)
       where length(btrim(p_query)) between 2 and 120
       and strpos(lower(seg->>'text'),lower(btrim(p_query)))>0 order by ord limit 20) q
$wm$;
revoke all on function public.wm_transcription_search(jsonb,uuid,text) from public,anon,authenticated;
grant execute on function public.wm_transcription_search(jsonb,uuid,text) to service_role;
create function public.wm_transcription_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; rid uuid; recid uuid; j public.wm_transcription_jobs%rowtype; v jsonb; src jsonb; selection jsonb; review jsonb; selected_items jsonb; segment_no integer; speaker_no integer; expected_rev integer; current_rev integer; event_id uuid; previous_event jsonb; annotation jsonb;
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
 elsif p_action='speaker-review' then
  if not found or j.status<>'complete' then return null;end if;
  if jsonb_typeof(p_data->'segment_index') is distinct from 'number' or coalesce(p_data->>'segment_index','') !~ '^(0|[1-9][0-9]{0,2})$'
   or jsonb_typeof(p_data->'speaker_number') is distinct from 'number' or coalesce(p_data->>'speaker_number','') !~ '^(0|[1-9]|10)$'
   or jsonb_typeof(p_data->'expected_revision') is distinct from 'number' or coalesce(p_data->>'expected_revision','') !~ '^(0|[1-9][0-9]{0,3})$'
   or jsonb_typeof(p_data->'event_id') is distinct from 'string' then return null;end if;
  segment_no:=(p_data->>'segment_index')::integer;speaker_no:=(p_data->>'speaker_number')::integer;expected_rev:=(p_data->>'expected_revision')::integer;event_id:=(p_data->>'event_id')::uuid;
  if event_id is null or segment_no>=jsonb_array_length(j.result->'segments') or expected_rev>1000 then return null;end if;
  select x into previous_event from jsonb_array_elements(j.speaker_annotations) x where x->>'event_id'=event_id::text;
  if found then
   if (previous_event->>'segment_index')::integer=segment_no and (previous_event->>'speaker_number')::integer=speaker_no and (previous_event->>'revision')::integer=expected_rev+1 then return jsonb_build_object('saved',true,'event',previous_event);end if;
   return null;
  end if;
  select coalesce(max((x->>'revision')::integer),0) into current_rev from jsonb_array_elements(j.speaker_annotations) x where (x->>'segment_index')::integer=segment_no;
  if current_rev<>expected_rev or jsonb_array_length(j.speaker_annotations)>=1000 then return null;end if;
  annotation:=jsonb_build_object('event_id',event_id,'segment_index',segment_no,'speaker_number',speaker_no,'revision',current_rev+1,'method','human-anonymous-v1','created_at',clock_timestamp());
  update public.wm_transcription_jobs set speaker_annotations=speaker_annotations||jsonb_build_array(annotation),updated_at=clock_timestamp() where recording_id=recid;
  return jsonb_build_object('saved',true,'event',annotation);
 elsif p_action='draft-review' then
  if not found or j.status<>'complete' or jsonb_typeof(p_data->'indices') is distinct from 'array' then return null;end if;
  selection:=p_data->'indices';
  if jsonb_array_length(selection) not between 1 and 10 then return null;end if;
  if exists(select 1 from jsonb_array_elements(selection) x where jsonb_typeof(x)<>'number' or x::text !~ '^(0|[1-9][0-9]{0,6})$') then return null;end if;
  if (select count(distinct x) from jsonb_array_elements(selection) x)<>jsonb_array_length(selection) then return null;end if;
  review:=public.wm_transcription_review(j.result,recid);
  select coalesce(jsonb_agg(x order by (x->>'segment_index')::integer),'[]'::jsonb) into selected_items from (
   select value as x from jsonb_array_elements(review->'excerpts')
   union
   select value as x from jsonb_array_elements(review->'decision_candidates')
  ) q where selection @> jsonb_build_array((x->>'segment_index')::integer);
  if jsonb_array_length(selected_items)<>jsonb_array_length(selection) then return null;end if;
  return jsonb_build_object('method','selected-source-review-v1','recording_id',recid,'items',selected_items,'approved',false,'speaker_annotations',coalesce((select jsonb_agg(z.x order by (z.x->>'segment_index')::integer) from (select distinct on ((x->>'segment_index')::integer) x from jsonb_array_elements(j.speaker_annotations) x where selection @> jsonb_build_array((x->>'segment_index')::integer) order by (x->>'segment_index')::integer,(x->>'revision')::integer desc) z),'[]'::jsonb));
 elsif p_action='search' then
  if not found or j.status<>'complete' or jsonb_typeof(p_data->'query') is distinct from 'string' or length(btrim(p_data->>'query')) not between 2 and 120 then return null;end if;
  return public.wm_transcription_search(j.result,recid,p_data->>'query');
 elsif p_action='read' then
  if not found then return jsonb_build_object('status','not_requested','attempts',0);end if;
 else return null;end if;
 return jsonb_build_object('recording_id',recid,'status',j.status,'attempts',j.attempts,'result',case when j.status='complete' then j.result||jsonb_build_object('review',public.wm_transcription_review(j.result,recid),'captions',public.wm_transcription_cues(j.result,recid),'speaker_annotations',j.speaker_annotations) else null end);
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

-- Ephemeral captions from an already-consented active audio recording only.
-- One latest window per room; no caption archive and no client write privilege.
create table public.wm_live_captions(
 room_id uuid primary key references public.wm_rooms(id) on delete cascade,
 recording_id uuid not null references public.wm_recording_runs(id) on delete cascade,
 offset_ms bigint not null check(offset_ms between 0 and 28800000),
 end_ms bigint not null check(end_ms>offset_ms and end_ms-offset_ms<=12000),
 language text not null check(language ~ '^[a-z]{2,3}$'),
 original_text text not null check(length(original_text)<=4000),
 english_text text check(length(english_text)<=4000),
 uncertain boolean not null,
 expires_at timestamptz not null
);
alter table public.wm_live_captions enable row level security;
revoke all on public.wm_live_captions from public,anon,authenticated;
grant select,insert,update,delete on public.wm_live_captions to service_role;
create function public.wm_live_caption_guard()
returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $wm$
begin
 if new.phase<>'active' or new.disposition<>'retain' then
  delete from public.wm_live_captions where recording_id=new.id;
 end if;
 return new;
end $wm$;
revoke all on function public.wm_live_caption_guard() from public,anon,authenticated;
create trigger wm_live_caption_guard after update of phase,disposition on public.wm_recording_runs for each row execute function public.wm_live_caption_guard();
create function public.wm_live_caption_write(p_room uuid,p_recording uuid,p_offset bigint,p_end bigint,p_language text,p_original text,p_english text,p_uncertain boolean)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare policy jsonb; r public.wm_recording_runs%rowtype;
begin
 -- Same room lock as mutations; recheck policy after inference, before exposure.
 perform 1 from public.wm_rooms where id=p_room for update;
 if not found then return false;end if;
 policy:=public.wm_recording_policy(p_room);
 select * into r from public.wm_recording_runs where id=p_recording and room_id=p_room and phase='active' and disposition='retain' for share;
 if not found or policy->>'permitted' is distinct from 'true' or policy->>'request_id' is distinct from r.request_id::text then return false;end if;
 if p_offset is null or p_end is null or p_offset<0 or p_end<=p_offset or p_end-p_offset>12000 or p_end>28800000
 or p_language is null or p_language!~'^[a-z]{2,3}$' or p_original is null or length(p_original)>4000
 or length(p_english)>4000 or p_uncertain is null then return false;end if;
 insert into public.wm_live_captions(room_id,recording_id,offset_ms,end_ms,language,original_text,english_text,uncertain,expires_at)
 values(p_room,p_recording,p_offset,p_end,p_language,p_original,p_english,p_uncertain,clock_timestamp()+interval '15 seconds')
 on conflict(room_id) do update set recording_id=excluded.recording_id,offset_ms=excluded.offset_ms,end_ms=excluded.end_ms,
 language=excluded.language,original_text=excluded.original_text,english_text=excluded.english_text,uncertain=excluded.uncertain,expires_at=excluded.expires_at
 where wm_live_captions.recording_id<>excluded.recording_id or wm_live_captions.end_ms<excluded.end_ms;
 return found;
end $wm$;
revoke all on function public.wm_live_caption_write(uuid,uuid,bigint,bigint,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.wm_live_caption_write(uuid,uuid,bigint,bigint,text,text,text,boolean) to service_role;
create function public.wm_live_caption_read(p_hash text,p_room uuid,p_language text)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; state jsonb; policy jsonb; c public.wm_live_captions%rowtype; chosen text;
begin
 if p_language is null or p_language not in ('original','fr','en','ff','es','it','zh','wes','ewo','dua','bas','bbj','bum','bax','ybb','mhk','ar','pt','de') then return null;end if;
 select * into a from public.wm_room_actor_for(p_hash,p_room);
 if not found then return null;end if;
 state:=public.wm_room_read(p_hash,p_room);
 if state is null or state->>'status' is distinct from 'open' or (state->>'endMs')::bigint<=floor(extract(epoch from clock_timestamp())*1000)::bigint
 or not exists(select 1 from jsonb_array_elements(state->'participants') p where p->>'memberId'=a.account_id::text and p->>'response'='accepted'
 and p->>'excluded'='false' and p->>'consent'='true' and (state->>'lobbyRequired' is distinct from 'true' or a.account_id::text=state->>'hostId' or p->>'lobbyStatus'='admitted')) then return null;end if;
 policy:=public.wm_recording_policy(p_room);
 if policy->>'permitted' is distinct from 'true' then return jsonb_build_object('status','unavailable');end if;
 select x.* into c from public.wm_live_captions x join public.wm_recording_runs r on r.id=x.recording_id and r.room_id=x.room_id
 where x.room_id=p_room and x.expires_at>clock_timestamp() and r.phase='active' and r.disposition='retain' and r.request_id::text=policy->>'request_id';
 if not found then return jsonb_build_object('status','waiting');end if;
 chosen:=case when p_language='en' and c.english_text is not null and c.english_text<>'' then 'en' else c.language end;
 return jsonb_build_object('status','ready','recording_id',c.recording_id,'start_ms',c.offset_ms,'end_ms',c.end_ms,'source_language',c.language,
 'language',chosen,'original',c.original_text,'text',case when chosen='en' and c.language<>'en' then c.english_text else c.original_text end,
 'fallback',p_language<>'original' and p_language<>chosen,'uncertain',c.uncertain,'ttl_ms',greatest(0,least(15000,floor(extract(epoch from(c.expires_at-clock_timestamp()))*1000)::integer)));
end $wm$;
revoke all on function public.wm_live_caption_read(text,uuid,text) from public,anon,authenticated;
grant execute on function public.wm_live_caption_read(text,uuid,text) to service_role;
commit;
