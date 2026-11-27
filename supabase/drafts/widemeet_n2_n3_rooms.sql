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
-- A named external guest is never made a member of the host workspace.
create table public.wm_external_guests(
 id uuid primary key,room_id uuid not null references public.wm_rooms(id),account_id uuid not null references public.wm_accounts(id),
 token_hash text not null unique check(token_hash~'^[a-f0-9]{64}$'),expires_at timestamptz not null,
 created_at timestamptz not null default clock_timestamp(),redeemed_at timestamptz,revoked_at timestamptz,
 unique(room_id,account_id),check(expires_at>created_at)
);
alter table public.wm_external_guests enable row level security;
revoke all on public.wm_external_guests from public,anon,authenticated;
grant select,insert,update on public.wm_external_guests to service_role;
create function public.wm_external_guest_valid(p_room uuid,p_account uuid)
returns boolean language sql security invoker stable set search_path=pg_catalog,public as $wm$
 select exists(select 1 from public.wm_external_guests g join public.wm_rooms r on r.id=g.room_id join public.wm_accounts a on a.id=g.account_id and a.enabled and not a.password_change_required
 where g.room_id=p_room and g.account_id=p_account and g.redeemed_at is not null and g.revoked_at is null
 and (r.state->>'hardEndMs')::bigint>floor(extract(epoch from now())*1000)::bigint
 and not exists(select 1 from public.wm_memberships m where m.workspace_id=r.workspace_id and m.account_id=g.account_id))
$wm$;
revoke all on function public.wm_external_guest_valid(uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_external_guest_valid(uuid,uuid) to service_role;

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
 -- A guest's target workspace grant must remain active through the write.
 perform 1 from public.wm_workspaces x where x.id=(select r.workspace_id from public.wm_rooms r where r.id=p_room) and x.enabled for share;
 perform 1 from public.wm_room_entitlements x where x.workspace_id=(select r.workspace_id from public.wm_rooms r where r.id=p_room) and x.enabled and x.valid_until>clock_timestamp() for share;
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
 if p_state->>'lobbyRequired' is distinct from 'true' and exists(select 1 from public.wm_external_guests g where g.room_id=p_room and g.revoked_at is null and (g.redeemed_at is not null or g.expires_at>clock_timestamp())) then return false;end if;
 if a.workspace_id<> (select s.workspace_id from public.wm_session_context(p_hash) s) and not public.wm_external_guest_valid(p_room,a.account_id) then return false;end if;
 -- A revoked participant must not block every subsequent legitimate transition.
 select jsonb_set(p_state,'{participants}',coalesce(jsonb_agg(case when p->>'memberId'<>v_old.host_id::text and not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and m.account_id::text=p->>'memberId') and not public.wm_external_guest_valid(v_old.id,(p->>'memberId')::uuid) and exists(select 1 from jsonb_array_elements(v_old.state->'participants') oldp where oldp->>'memberId'=p->>'memberId') then p||jsonb_build_object('excluded',true,'consent',false,'moderatorPermissions','[]'::jsonb) else p end order by ord),'[]'::jsonb)) into p_state from jsonb_array_elements(p_state->'participants') with ordinality as x(p,ord);
 if exists(select 1 from jsonb_array_elements(p_state->'participants') p where p->>'excluded'='true' and exists(select 1 from jsonb_array_elements(v_old.state->'participants') oldp where oldp->>'memberId'=p->>'memberId' and oldp->>'excluded'='false')) then p_state:=p_state||jsonb_build_object('recording','off');end if;
 if p_state->>'status' in ('open','paused') then
  if (p_state->>'endMs')::bigint is null or (p_state->>'endMs')::bigint>least(a.entitlement_end_ms,(p_state->>'hardEndMs')::bigint) then return false;end if;
  if v_old.state->>'status' not in ('open','paused') then
   if (p_state->>'endMs')::bigint<=v_now_ms then return false;end if;
   -- Conservative test-tier capacity: Access=1, Premium=3; negotiated tier not yet configured.
   v_limit:=case when a.plan='access' then 1 else 3 end;
   if (select count(*) from public.wm_rooms r where r.workspace_id=a.workspace_id and r.id<>p_room and r.state->>'status' in ('open','paused') and (r.state->>'endMs')::bigint>v_now_ms)>=v_limit then return false;end if;
  end if;
 end if;
 if exists(select 1 from jsonb_array_elements(p_state->'participants') p where not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and m.account_id::text=p->>'memberId') and not public.wm_external_guest_valid(v_old.id,(p->>'memberId')::uuid) and p->>'excluded' is distinct from 'true') then return false;end if;
 -- Persist the trusted starting entitlement for deterministic expiry archival.
 if v_old.state->>'status'='scheduled' and p_state->>'status' in ('open','paused') then
  p_state:=p_state||jsonb_build_object('startPlan',a.plan,'startEntitlementEndMs',a.entitlement_end_ms);
 end if;
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
 from public.wm_rooms r join lateral public.wm_room_actor_for(p_hash,r.id) a on a.workspace_id=r.workspace_id
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

-- B2 Connect: private ledger. Explicit host permission; only standard rooms initially.
create table public.wm_display_policy(
 room_id uuid primary key references public.wm_rooms(id),
 enabled boolean not null default false
);
create table public.wm_display_offers(
 code_hash text primary key check(code_hash~'^[a-f0-9]{64}),
 receiver_session uuid not null references public.wm_device_sessions(id),
 receiver_name text not null check(length(receiver_name) between 1 and 80),
 created_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null,
 used_at timestamptz
);
create table public.wm_display_leases(
 id uuid primary key, room_id uuid not null references public.wm_rooms(id),
 source_session uuid not null references public.wm_device_sessions(id),
 receiver_session uuid not null references public.wm_device_sessions(id),
 offer_hash text not null unique references public.wm_display_offers(code_hash),
 expires_at timestamptz not null, revoked_at timestamptz,
 check(source_session<>receiver_session)
);
create index wm_display_source_idx on public.wm_display_leases(source_session,room_id);
alter table public.wm_display_policy enable row level security;
alter table public.wm_display_offers enable row level security;
alter table public.wm_display_leases enable row level security;
revoke all on public.wm_display_policy,public.wm_display_offers,public.wm_display_leases from public,anon,authenticated;
grant select,insert,update on public.wm_display_policy,public.wm_display_offers,public.wm_display_leases to service_role;

-- Only trusted Edge/proxy calls this function. Never send source_hash to a client.
create function public.wm_display_context(p_id uuid) returns jsonb
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare l public.wm_display_leases%rowtype; ss public.wm_device_sessions%rowtype; rs public.wm_device_sessions%rowtype; r public.wm_rooms%rowtype; a record; p jsonb; now_ms bigint;
begin
 select * into l from public.wm_display_leases where id=p_id and revoked_at is null and expires_at>clock_timestamp();if not found then return null;end if;
 select * into ss from public.wm_device_sessions where id=l.source_session;
 select * into rs from public.wm_device_sessions where id=l.receiver_session;
 if ss.id is null or rs.id is null or ss.account_id<>rs.account_id or ss.workspace_id<>rs.workspace_id or ss.installation_id=rs.installation_id
 or not exists(select 1 from public.wm_session_context(ss.token_hash) x where not x.password_change_required)
 or not exists(select 1 from public.wm_session_context(rs.token_hash) x where not x.password_change_required) then return null;end if;
 select * into r from public.wm_rooms where id=l.room_id and workspace_id=ss.workspace_id;
 if not found or r.state->>'status' is distinct from 'open' or coalesce(r.state->>'confidentiality','standard')<>'standard'
 or not exists(select 1 from public.wm_display_policy d where d.room_id=r.id and d.enabled) then return null;end if;
 select * into a from public.wm_room_actor_for(ss.token_hash,r.id);if not found or a.account_id<>ss.account_id or a.workspace_id<>r.workspace_id then return null;end if;
 now_ms:=floor(extract(epoch from clock_timestamp())*1000)::bigint;
 if (r.state->>'endMs')::bigint<=now_ms or a.entitlement_end_ms<=now_ms then return null;end if;
 select x into p from jsonb_array_elements(r.state->'participants') x where x->>'memberId'=ss.account_id::text and x->>'excluded'='false' and x->>'response'='accepted';
 if p is null or (r.state->>'lobbyRequired'='true' and ss.account_id<>r.host_id and p->>'lobbyStatus' is distinct from 'admitted') then return null;end if;
 return jsonb_build_object('source_hash',ss.token_hash,
 'ctx',jsonb_build_object(
 'meeting',jsonb_build_object('id',r.id,'orgId',r.workspace_id,'status','open','endMs',least((r.state->>'endMs')::bigint,a.entitlement_end_ms),'confidentiality','standard'),
 'actor',jsonb_build_object('enabled',true,'displayAllowed',true,'orgId',r.workspace_id,'meetingId',r.id,'memberId',ss.account_id),
 'source',jsonb_build_object('active',true,'orgId',r.workspace_id,'meetingId',r.id,'memberId',ss.account_id,'id',ss.id),
 'receiver',jsonb_build_object('approved',true,'active',true,'kind','widemeet_receiver','memberId',rs.account_id,'orgId',rs.workspace_id,'id',rs.id),
 'policy',jsonb_build_object('displayEnabled',true,'confidentialDisplayAllowed',false)),
 'lease',jsonb_build_object('id',l.id,'orgId',r.workspace_id,'meetingId',r.id,'memberId',ss.account_id,'sourceId',ss.id,'receiverId',rs.id,
 'expiresMs',least(floor(extract(epoch from l.expires_at)*1000)::bigint,(r.state->>'endMs')::bigint,a.entitlement_end_ms),'revoked',false,
 'canSubscribe',true,'canPublish',false,'canRecord',false,'canChat',false,'canControl',false));
end $wm$;
revoke all on function public.wm_display_context(uuid) from public,anon,authenticated;
grant execute on function public.wm_display_context(uuid) to service_role;

create function public.wm_display_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; a record; r public.wm_rooms%rowtype; o public.wm_display_offers%rowtype; rs public.wm_device_sessions%rowtype; l public.wm_display_leases%rowtype; rid uuid; lid uuid; ch text; n text; v jsonb; now_at timestamptz;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into s from public.wm_session_context(p_hash) where not password_change_required;
 if not found then return null;end if;
 now_at:=clock_timestamp();
 if p_action='offer' then
  ch:=p_data->>'code_hash';n:=btrim(p_data->>'name');
  if ch is null or ch!~'^[a-f0-9]{64} or n is null or length(n) not between 1 and 80 then return null;end if;
  select * into o from public.wm_display_offers where code_hash=ch;
  if found then if o.receiver_session=s.session_id and o.receiver_name=n and o.used_at is null and o.expires_at>now_at then return jsonb_build_object('offered',true);end if;return null;end if;
  if (select count(*) from public.wm_display_offers where receiver_session=s.session_id and created_at>now_at-interval '1 minute')>=5 then return null;end if;
  insert into public.wm_display_offers(code_hash,receiver_session,receiver_name,expires_at) values(ch,s.session_id,n,now_at+interval '60 seconds');
  return jsonb_build_object('offered',true);
 end if;
 if p_action='receive' then
  ch:=p_data->>'code_hash';
  select * into o from public.wm_display_offers where code_hash=ch and receiver_session=s.session_id;
  if not found then return null;end if;
  if o.used_at is null then if o.expires_at>now_at then return jsonb_build_object('pending',true);end if;return null;end if;
  select * into l from public.wm_display_leases where offer_hash=ch and receiver_session=s.session_id for update;
  if not found then return null;end if;
  v:=public.wm_display_context(l.id);if v is null then return null;end if;
  -- Renew only before expiration, never resurrect revoked or expired leases.
  update public.wm_display_leases set expires_at=now_at+interval '30 seconds' where id=l.id;
  return public.wm_display_context(l.id);
 end if;
 if p_action='receiver-stop' then
  ch:=p_data->>'code_hash';
  select * into o from public.wm_display_offers where code_hash=ch and receiver_session=s.session_id;
  if not found then return null;end if;
  update public.wm_display_offers set used_at=coalesce(used_at,now_at) where code_hash=ch;
  update public.wm_display_leases set revoked_at=coalesce(revoked_at,now_at) where offer_hash=ch and receiver_session=s.session_id;
  return jsonb_build_object('stopped',true);
 end if;
 rid:=(p_data->>'room_id')::uuid;if rid is null then return null;end if;
 select * into a from public.wm_lock_room_actor_for(p_hash,rid);if not found or a.workspace_id<>s.workspace_id then return null;end if;
 select * into r from public.wm_rooms where id=rid and workspace_id=s.workspace_id for share;
 if not found then return null;end if;
 if p_action='source-stop' then
  update public.wm_display_leases set revoked_at=coalesce(revoked_at,now_at) where source_session=s.session_id and room_id=rid;
  return jsonb_build_object('stopped',true);
 end if;
 if r.state->>'status' is distinct from 'open' or coalesce(r.state->>'confidentiality','standard')<>'standard'
 or (r.state->>'endMs')::bigint<=floor(extract(epoch from now_at)*1000)::bigint then return null;end if;
 if not exists(select 1 from jsonb_array_elements(r.state->'participants') x where x->>'memberId'=s.account_id::text and x->>'excluded'='false' and x->>'response'='accepted' and (coalesce(r.state->>'lobbyRequired','false')<>'true' or s.account_id=r.host_id or x->>'lobbyStatus'='admitted')) then return null;end if;
 if p_action='policy' then
  if s.account_id<>r.host_id or jsonb_typeof(p_data->'enabled') is distinct from 'boolean' then return null;end if;
  insert into public.wm_display_policy(room_id,enabled) values(rid,(p_data->>'enabled')::boolean) on conflict(room_id) do update set enabled=excluded.enabled;
  if not (p_data->>'enabled')::boolean then update public.wm_display_leases set revoked_at=coalesce(revoked_at,now_at) where room_id=rid;end if;
  return jsonb_build_object('enabled',(p_data->>'enabled')::boolean);
 end if;
 if p_action='source-status' then
  select * into l from public.wm_display_leases x where x.source_session=s.session_id and x.room_id=rid and x.revoked_at is null and x.expires_at>now_at order by x.expires_at desc limit 1;
  if found and public.wm_display_context(l.id) is not null then
   select * into o from public.wm_display_offers where code_hash=l.offer_hash;
   return jsonb_build_object('enabled',true,'receiver_name',o.receiver_name,'lease_id',l.id);
  end if;
  return jsonb_build_object('enabled',exists(select 1 from public.wm_display_policy d where d.room_id=rid and d.enabled));
 end if;
 if not exists(select 1 from public.wm_display_policy d where d.room_id=rid and d.enabled) then return null;end if;
 if p_action not in ('preview','confirm') then return null;end if;
 ch:=p_data->>'code_hash';
 select * into o from public.wm_display_offers where code_hash=ch and used_at is null and expires_at>now_at for update;
 if not found then return null;end if;
 select * into rs from public.wm_device_sessions where id=o.receiver_session;
 if not found or rs.account_id<>s.account_id or rs.workspace_id<>s.workspace_id or rs.installation_id=s.installation_id
 or not exists(select 1 from public.wm_session_context(rs.token_hash) x where not x.password_change_required) then return null;end if;
 if p_action='preview' then return jsonb_build_object('receiver_name',o.receiver_name);end if;
 if p_data->>'receiver_name' is distinct from o.receiver_name then return null;end if;
 lid:=(p_data->>'lease_id')::uuid;if lid is null then return null;end if;
 -- A new receiver replaces the old one; a used code can never be redeemed twice.
 update public.wm_display_leases set revoked_at=coalesce(revoked_at,now_at) where revoked_at is null and (source_session=s.session_id or receiver_session=rs.id);
 update public.wm_display_offers set used_at=now_at where code_hash=ch;
 insert into public.wm_display_leases(id,room_id,source_session,receiver_session,offer_hash,expires_at) values(lid,rid,s.session_id,rs.id,ch,now_at+interval '30 seconds');
 return jsonb_build_object('confirmed',true,'receiver_name',o.receiver_name,'lease_id',lid);
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_display_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_display_action(text,text,jsonb) to service_role;
commit;
