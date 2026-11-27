-- N4 isolated candidate: manual minutes, explicit validation/publication and
-- private archives. Not an AI transcription claim. No hosted migration.
begin;
create table public.wm_minutes_eligibility(
 room_id uuid primary key references public.wm_rooms(id),
 premium boolean not null,
 closed_at timestamptz not null,
 retain_until timestamptz not null,
 snapshot jsonb not null
);
create table public.wm_minutes_versions(
 id uuid primary key,
 room_id uuid not null references public.wm_minutes_eligibility(room_id),
 version integer not null check(version>0),
 author_id uuid not null references public.wm_accounts(id),
 body text not null check(length(body) between 1 and 8000),
 created_at timestamptz not null default clock_timestamp(),
 approved_at timestamptz,
 published_at timestamptz,
 revoked_at timestamptz,
 unique(room_id,version),
 check(published_at is null or approved_at is not null)
);
create table public.wm_minutes_recipients(
 version_id uuid not null references public.wm_minutes_versions(id),
 account_id uuid not null references public.wm_accounts(id),
 published_at timestamptz not null default clock_timestamp(),
 read_at timestamptz,
 revoked_at timestamptz,
 primary key(version_id,account_id)
);
alter table public.wm_minutes_eligibility enable row level security;
alter table public.wm_minutes_versions enable row level security;
alter table public.wm_minutes_recipients enable row level security;
revoke all on public.wm_minutes_eligibility,public.wm_minutes_versions,public.wm_minutes_recipients from public,anon,authenticated;
grant select,insert,update on public.wm_minutes_eligibility,public.wm_minutes_versions,public.wm_minutes_recipients to service_role;
-- Snapshot at actual closure: entitlement checked then, archive access remains
-- independent of current subscription. 90 days is a test-only retention ceiling.
create function public.wm_minutes_on_close()
returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare eligible boolean; snap jsonb;
begin
 if new.state->>'status' is distinct from 'ended' or old.state->>'status'='ended' or old.state->>'status' not in ('open','paused') then return new;end if;
 eligible:=exists(select 1 from public.wm_room_entitlements e where e.workspace_id=new.workspace_id and e.enabled and e.plan='premium' and e.valid_until>clock_timestamp())
 or exists(select 1 from public.wm_paid_passes p where p.consumed_room_id=new.id and p.valid_until>clock_timestamp());
 snap:=jsonb_build_object('title',new.state->>'title','description',new.state->>'description','scheduled_ms',new.state->'scheduledMs','started_ms',new.state->'startedMs','closed_ms',floor(extract(epoch from clock_timestamp())*1000)::bigint,
 'participants',(select coalesce(jsonb_agg(jsonb_build_object('member_id',p->>'memberId','response',p->>'response','excluded',p->'excluded','attendance','unknown')),'[]') from jsonb_array_elements(new.state->'participants') p));
 insert into public.wm_minutes_eligibility(room_id,premium,closed_at,retain_until,snapshot)
 values(new.id,eligible,clock_timestamp(),clock_timestamp()+interval '90 days',snap) on conflict do nothing;
 return new;
end $wm$;
revoke all on function public.wm_minutes_on_close() from public,anon,authenticated;
grant execute on function public.wm_minutes_on_close() to service_role;
create trigger wm_minutes_close after update of state on public.wm_rooms for each row execute function public.wm_minutes_on_close();

create function public.wm_minutes_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; a_role text; r public.wm_rooms%rowtype; e public.wm_minutes_eligibility%rowtype; v public.wm_minutes_versions%rowtype; rid uuid; vid uuid; latest integer; selected uuid[]; member uuid; host boolean; txt text; result jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required or jsonb_typeof(p_data) is distinct from 'object' then return null;end if;
 -- Serialize against account/session revocation and role changes.
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for share;
 if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;
 if not found then return null;end if;
 select role into a_role from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled for share;
 if not found then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;
 if not found or not exists(select 1 from public.wm_session_context(p_hash)) then return null;end if;
 if p_action='list' then
  if p_data<>'{}'::jsonb then return null;end if;
  return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(q)) from (
   select rr.id as room_id,ee.snapshot->>'title' as title,ee.closed_at,ee.premium,ee.retain_until,
    (rr.host_id=s.account_id and a_role in ('owner','promoteur','manager')) as can_manage,
    vv.id as version_id,vv.version,vv.published_at,
    coalesce(pr.read_at is null and pr.account_id is not null,false) as unread
   from public.wm_minutes_eligibility ee join public.wm_rooms rr on rr.id=ee.room_id
   left join lateral (select x.* from public.wm_minutes_versions x where x.room_id=rr.id and x.revoked_at is null and
     (rr.host_id=s.account_id and a_role in ('owner','promoteur','manager') or (x.published_at is not null and exists(select 1 from public.wm_minutes_recipients y where y.version_id=x.id and y.account_id=s.account_id and y.revoked_at is null))) order by x.version desc limit 1) vv on true
   left join public.wm_minutes_recipients pr on pr.version_id=vv.id and pr.account_id=s.account_id and pr.revoked_at is null
   where rr.workspace_id=s.workspace_id and ee.retain_until>clock_timestamp() and (rr.host_id=s.account_id and a_role in ('owner','promoteur','manager') or pr.account_id is not null)
   order by ee.closed_at desc limit 100) q),'[]'::jsonb));
 end if;
 begin rid:=(p_data->>'room_id')::uuid;vid:=(p_data->>'version_id')::uuid;exception when invalid_text_representation then return null;end;
 select * into r from public.wm_rooms where id=rid and workspace_id=s.workspace_id for update;
 if not found then return null;end if;
 select * into e from public.wm_minutes_eligibility where room_id=rid and retain_until>clock_timestamp();
 if not found then return null;end if;
 host:=r.host_id=s.account_id and a_role in ('owner','promoteur','manager');
 if p_action='prepare' then
  if not host then return null;end if;
  select coalesce(max(version),0) into latest from public.wm_minutes_versions where room_id=rid;
  return jsonb_build_object('room_id',rid,'latest_version',latest,'premium',e.premium,'snapshot',e.snapshot,'recipients',coalesce((select jsonb_agg(jsonb_build_object('member_id',m.account_id,'display_name',ac.display_name) order by ac.display_name) from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=r.workspace_id and m.enabled and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=m.account_id::text and p->>'response'='accepted' and p->>'excluded'='false')),'[]'::jsonb));
 end if;
 if p_action='read' then
  select * into v from public.wm_minutes_versions where id=vid and room_id=rid and revoked_at is null;
  if not found then return null;end if;
  if not host then
   if v.published_at is null or not exists(select 1 from public.wm_minutes_recipients where version_id=vid and account_id=s.account_id and revoked_at is null) then return null;end if;
   update public.wm_minutes_recipients set read_at=coalesce(read_at,clock_timestamp()) where version_id=vid and account_id=s.account_id and revoked_at is null;
  end if;
  return jsonb_build_object('room_id',rid,'version_id',v.id,'version',v.version,'body',v.body,'approved_at',v.approved_at,'published_at',v.published_at,'snapshot',case when host then e.snapshot else e.snapshot-'participants' end,'can_manage',host,'origin','human_draft');
 end if;
 if not host or not e.premium then return null;end if;
 if p_action='draft' then
  txt:=btrim(p_data->>'body');
  if vid is null or txt is null or length(txt) not between 1 and 8000 then return null;end if;
  select * into v from public.wm_minutes_versions where id=vid;
  if found then
   if v.room_id<>rid or v.body<>txt or v.author_id<>s.account_id then return null;end if;
   return jsonb_build_object('version_id',v.id,'version',v.version);
  end if;
  select coalesce(max(version),0) into latest from public.wm_minutes_versions where room_id=rid;
  if p_data->>'expected_version' is distinct from latest::text or latest>=100 then return null;end if;
  insert into public.wm_minutes_versions(id,room_id,version,author_id,body) values(vid,rid,latest+1,s.account_id,txt);
  return jsonb_build_object('version_id',vid,'version',latest+1);
 end if;
 select * into v from public.wm_minutes_versions where id=vid and room_id=rid and revoked_at is null for update;
 if not found then return null;end if;
 if p_action='approve' then
  if exists(select 1 from public.wm_minutes_versions where room_id=rid and version>v.version) then return null;end if;
  update public.wm_minutes_versions set approved_at=coalesce(approved_at,clock_timestamp()) where id=vid;
  return jsonb_build_object('approved',true);
 elsif p_action='publish' then
  if v.approved_at is null or exists(select 1 from public.wm_minutes_versions where room_id=rid and version>v.version) or jsonb_typeof(p_data->'recipients') is distinct from 'array' or jsonb_array_length(p_data->'recipients') not between 1 and 100 then return null;end if;
  begin select array_agg(distinct x::uuid order by x::uuid) into selected from jsonb_array_elements_text(p_data->'recipients') x;exception when invalid_text_representation then return null;end;
  if cardinality(selected)<>jsonb_array_length(p_data->'recipients') then return null;end if;
  foreach member in array selected loop
   if not exists(select 1 from public.wm_memberships m join public.wm_accounts a on a.id=m.account_id and a.enabled where m.workspace_id=r.workspace_id and m.account_id=member and m.enabled) or not exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=member::text and p->>'response'='accepted' and p->>'excluded'='false') then return null;end if;
  end loop;
  if v.published_at is not null then
   if selected is distinct from (select array_agg(account_id order by account_id) from public.wm_minutes_recipients where version_id=vid and revoked_at is null) then return null;end if;
   return jsonb_build_object('published',true);
  end if;
  update public.wm_minutes_recipients set revoked_at=coalesce(revoked_at,clock_timestamp()) where version_id in(select id from public.wm_minutes_versions where room_id=rid and version<v.version);
  update public.wm_minutes_versions set revoked_at=coalesce(revoked_at,clock_timestamp()) where room_id=rid and version<v.version and published_at is not null;
  insert into public.wm_minutes_recipients(version_id,account_id) select vid,x from unnest(selected) x;
  update public.wm_minutes_versions set published_at=clock_timestamp() where id=vid;
  return jsonb_build_object('published',true);
 elsif p_action='revoke' then
  update public.wm_minutes_versions set revoked_at=clock_timestamp() where id=vid;
  update public.wm_minutes_recipients set revoked_at=coalesce(revoked_at,clock_timestamp()) where version_id=vid;
  return jsonb_build_object('revoked',true);
 end if;
 return null;
end $wm$;
revoke all on function public.wm_minutes_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_minutes_action(text,text,jsonb) to service_role;
commit;
