-- WideMeet N2/N3 transactional room storage candidate. No media/provider or payment activation.
begin;
create table public.wm_room_entitlements(
 workspace_id uuid primary key references public.wm_workspaces(id),
 plan text not null check(plan in ('access','premium')),
 valid_until timestamptz not null,
 enabled boolean not null default false
);
create table public.wm_rooms(
 id uuid primary key,
 workspace_id uuid not null references public.wm_workspaces(id),
 host_id uuid not null,
 revision bigint not null check(revision>=1),
 state jsonb not null check(jsonb_typeof(state)='object'),
 foreign key(host_id,workspace_id) references public.wm_memberships(account_id,workspace_id),
 check((state->>'id') is not distinct from id::text and (state->>'workspaceId') is not distinct from workspace_id::text and (state->>'hostId') is not distinct from host_id::text and (state->>'revision')::bigint is not distinct from revision),
 check(octet_length(state::text)<=1048576)
);
create index wm_rooms_workspace on public.wm_rooms(workspace_id);
alter table public.wm_room_entitlements enable row level security;
alter table public.wm_rooms enable row level security;
revoke all on public.wm_room_entitlements,public.wm_rooms from public,anon,authenticated;
grant select,insert,update,delete on public.wm_room_entitlements,public.wm_rooms to service_role;
-- Trusted server context, not caller-provided role or plan. No client execution grant.
create function public.wm_room_actor(p_hash text)
returns table(account_id uuid,workspace_id uuid,role text,plan text,entitlement_end_ms bigint)
language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select s.account_id,s.workspace_id,m.role,e.plan,floor(extract(epoch from e.valid_until)*1000)::bigint
 from public.wm_session_context(p_hash) s
 join public.wm_memberships m on m.account_id=s.account_id and m.workspace_id=s.workspace_id and m.enabled
 join public.wm_room_entitlements e on e.workspace_id=s.workspace_id and e.enabled and e.valid_until>now()
 where not s.password_change_required
$wm$;
revoke all on function public.wm_room_actor(text) from public,anon,authenticated;
grant execute on function public.wm_room_actor(text) to service_role;
-- Room-specific entitlement boundary; billing draft replaces this default with paid-pass support.
create function public.wm_room_actor_for(p_hash text,p_room uuid)
returns table(account_id uuid,workspace_id uuid,role text,plan text,entitlement_end_ms bigint)
language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select * from public.wm_room_actor(p_hash)
$wm$;
revoke all on function public.wm_room_actor_for(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_room_actor_for(text,uuid) to service_role;
-- Lock workspace entitlement and current account, membership and session before write.
-- Ordering account -> workspace -> membership -> device matches identity account lock.
create function public.wm_lock_room_actor_for(p_hash text,p_room uuid)
returns table(account_id uuid,workspace_id uuid,role text,plan text,entitlement_end_ms bigint)
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a uuid; w uuid;
begin
 select s.account_id,s.workspace_id into a,w from public.wm_device_sessions s where s.token_hash=p_hash;
 if not found then return;end if;
 perform 1 from public.wm_accounts x where x.id=a and x.enabled and not x.password_change_required for share;
 if not found then return;end if;
 perform 1 from public.wm_workspaces x where x.id=w and x.enabled for share;
 if not found then return;end if;
 perform 1 from public.wm_memberships x where x.account_id=a and x.workspace_id=w and x.enabled for share;
 if not found then return;end if;
 perform 1 from public.wm_device_sessions x where x.token_hash=p_hash and x.revoked_at is null and x.expires_at>clock_timestamp() for share;
 if not found then return;end if;
 -- A global subscription can change only after its shared lock is released.
 perform 1 from public.wm_room_entitlements x where x.workspace_id=w and x.enabled and x.valid_until>clock_timestamp() for share;
 return query select c.account_id,c.workspace_id,c.role,c.plan,c.entitlement_end_ms from public.wm_room_actor_for(p_hash,p_room) c;
end $wm$;
revoke all on function public.wm_lock_room_actor_for(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_lock_room_actor_for(text,uuid) to service_role;
create function public.wm_room_create(p_hash text,p_state jsonb)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; rid uuid;
begin
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or a.role not in ('owner','promoteur','manager') then return false;end if;
 if p_state is null or p_state->>'workspaceId' is distinct from a.workspace_id::text or p_state->>'hostId' is distinct from a.account_id::text or p_state->>'status' is distinct from 'scheduled' or p_state->>'revision' is distinct from '1' or jsonb_typeof(p_state->'participants') is distinct from 'array' or (p_state->>'hardEndMs')::bigint>a.entitlement_end_ms then return false;end if;
 if not exists(select 1 from jsonb_array_elements(p_state->'participants') p where p->>'memberId'=a.account_id::text and p->>'response'='accepted') then return false;end if;
 if exists(select 1 from jsonb_array_elements(p_state->'participants') p where not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and m.account_id::text=p->>'memberId')) then return false;end if;
 rid:=(p_state->>'id')::uuid;
 insert into public.wm_rooms(id,workspace_id,host_id,revision,state) values(rid,a.workspace_id,a.account_id,1,p_state) on conflict(id) do nothing;
 return found;
end $wm$;
revoke all on function public.wm_room_create(text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_room_create(text,jsonb) to service_role;
-- Raw state is private service-to-service only; gateway must project permitted fields.
create function public.wm_room_read(p_hash text,p_room uuid)
returns jsonb language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select r.state from public.wm_rooms r join lateral public.wm_room_actor_for(p_hash,r.id) a on a.workspace_id=r.workspace_id
 where r.id=p_room and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=a.account_id::text and p->>'excluded'='false')
$wm$;
revoke all on function public.wm_room_read(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_room_read(text,uuid) to service_role;
-- The trusted gateway calls domain policy before CAS. SQL rejects scope, revoked session and stale version.
create function public.wm_room_write(p_hash text,p_room uuid,p_expected bigint,p_role text,p_plan text,p_state jsonb)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; v_old public.wm_rooms%rowtype; v_now_ms bigint; v_limit integer;
begin
 select * into a from public.wm_lock_room_actor_for(p_hash,p_room);
 if not found or a.role is distinct from p_role or a.plan is distinct from p_plan then return false;end if;
 -- Serialize all room transitions per workspace, including concurrent starts in different rooms.
 perform pg_advisory_xact_lock(hashtextextended('wm-room-quota:'||a.workspace_id::text,0));
 v_now_ms:=floor(extract(epoch from clock_timestamp())*1000)::bigint;
 select * into v_old from public.wm_rooms r where r.id=p_room and r.workspace_id=a.workspace_id for update;
 if not found or v_old.revision<>p_expected or not exists(select 1 from jsonb_array_elements(v_old.state->'participants') p where p->>'memberId'=a.account_id::text and p->>'excluded'='false') then return false;end if;
 if p_state is null or p_state->>'id' is distinct from v_old.id::text or p_state->>'workspaceId' is distinct from v_old.workspace_id::text or p_state->>'hostId' is distinct from v_old.host_id::text or (p_state->>'revision')::bigint is distinct from p_expected+1 or jsonb_typeof(p_state->'participants') is distinct from 'array' then return false;end if;
 if p_state->>'recording'='requested' and a.plan<>'premium' then return false;end if;
 if p_state->>'status' in ('open','paused') then
  if (p_state->>'endMs')::bigint is null or (p_state->>'endMs')::bigint>least(a.entitlement_end_ms,(p_state->>'hardEndMs')::bigint) then return false;end if;
  if v_old.state->>'status' not in ('open','paused') then
   if (p_state->>'endMs')::bigint<=v_now_ms then return false;end if;
   -- Conservative test-tier capacity: Access=1, Premium=3; negotiated tier not yet configured.
   v_limit:=case when a.plan='access' then 1 else 3 end;
   if (select count(*) from public.wm_rooms r where r.workspace_id=a.workspace_id and r.id<>p_room and r.state->>'status' in ('open','paused') and (r.state->>'endMs')::bigint>v_now_ms)>=v_limit then return false;end if;
  end if;
 end if;
 if exists(select 1 from jsonb_array_elements(p_state->'participants') p where not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and m.account_id::text=p->>'memberId') and p->>'excluded' is distinct from 'true') then return false;end if;
 update public.wm_rooms set revision=p_expected+1,state=p_state where id=p_room and revision=p_expected;
 return found;
end $wm$;
revoke all on function public.wm_room_write(text,uuid,bigint,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_room_write(text,uuid,bigint,text,text,jsonb) to service_role;
-- Agenda summaries: no raw room state, chat, ballots or consent in list responses.
create function public.wm_room_list(p_hash text)
returns table(id uuid,title text,status text,scheduled_ms bigint,duration_minutes integer,revision bigint,host_id uuid,response text)
language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select r.id,r.state->>'title',r.state->>'status',(r.state->>'scheduledMs')::bigint,(r.state->>'durationMinutes')::integer,r.revision,r.host_id,p->>'response'
 from public.wm_rooms r join public.wm_room_actor(p_hash) a on a.workspace_id=r.workspace_id
 cross join lateral jsonb_array_elements(r.state->'participants') p
 where p->>'memberId'=a.account_id::text and p->>'excluded'='false'
 order by (r.state->>'scheduledMs')::bigint desc nulls last,r.id limit 200
$wm$;
revoke all on function public.wm_room_list(text) from public,anon,authenticated;
grant execute on function public.wm_room_list(text) to service_role;
create function public.wm_room_contacts(p_hash text)
returns table(member_id uuid,display_name text,role text)
language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select m.account_id,ac.display_name,m.role
 from public.wm_room_actor(p_hash) a
 join public.wm_memberships m on m.workspace_id=a.workspace_id and m.enabled and m.account_id<>a.account_id
 join public.wm_accounts ac on ac.id=m.account_id and ac.enabled
 order by ac.display_name,m.account_id limit 200
$wm$;
revoke all on function public.wm_room_contacts(text) from public,anon,authenticated;
grant execute on function public.wm_room_contacts(text) to service_role;
commit;
