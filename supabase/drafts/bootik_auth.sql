-- Isolated candidate. Runtime role provisioned by infrastructure, never by a client.
begin;
create table bootik.bk_credentials (
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,identifier text not null unique,
 salt_hex text not null check(salt_hex ~ '^[0-9a-f]{32}$'),
 verifier_hex text not null check(verifier_hex ~ '^[0-9a-f]{128}$'),
 primary key(organization_id,app_id,user_id),
 foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
create table bootik.bk_sessions (
 token_hash text primary key check(token_hash ~ '^[0-9a-f]{64}$'), organization_id uuid not null,app_id uuid not null,user_id uuid not null,
 expires_at timestamptz not null,revoked_at timestamptz,
 refresh_hash text unique check(refresh_hash ~ '^[0-9a-f]{64}$'),refresh_expires_at timestamptz,
 check((refresh_hash is null)=(refresh_expires_at is null)),
 foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
create table bootik.bk_recovery_requests (
 id uuid primary key default gen_random_uuid(),identifier text not null,created_at timestamptz not null default now()
);
do $$ declare n text;begin foreach n in array array['bk_credentials','bk_sessions','bk_recovery_requests'] loop
 execute format('alter table bootik.%I enable row level security',n);
 execute format('alter table bootik.%I force row level security',n);
 execute format('revoke all on bootik.%I from public,anon,authenticated',n);
 end loop;end $$;
-- Reuse the NAXA Services active-device-session model with BOOTIK opaque tokens.
alter table bootik.bk_sessions add column device_session_id uuid not null default gen_random_uuid() unique;
alter table bootik.bk_sessions add column created_at timestamptz not null default clock_timestamp();
alter table bootik.bk_sessions add column installation_id uuid,add column platform text check(platform in ('android','web','test'));
create table bootik.bk_security_settings(
 organization_id uuid not null,app_id uuid not null,max_member_sessions integer not null default 2 check(max_member_sessions between 1 and 50),offline_minutes integer not null default 15 check(offline_minutes between 1 and 15),
 primary key(organization_id,app_id),foreign key(organization_id,app_id) references bootik.bk_organizations(organization_id,app_id)
);
create table bootik.bk_security_audit(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,app_id uuid not null,actor uuid not null,site_id uuid,action text not null,target uuid,details jsonb not null default '{}'::jsonb,created_at timestamptz not null default clock_timestamp()
);
create table bootik.bk_admin_receipts(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,actor uuid not null,site_id uuid not null,payload jsonb not null,result jsonb not null,created_at timestamptz not null default clock_timestamp()
);
do $$ declare n text;begin foreach n in array array['bk_security_settings','bk_security_audit','bk_admin_receipts'] loop execute format('alter table bootik.%I enable row level security',n);execute format('alter table bootik.%I force row level security',n);execute format('revoke all on bootik.%I from public,anon,authenticated',n);end loop;end $$;
-- NAXA SERVICES recovery contract: no OTP, no email, temporary password delivered once.
alter table bootik.bk_recovery_requests add column processed_at timestamptz,add column handled_by uuid;
create table bootik.bk_password_controls(
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,version bigint not null check(version>0),requires_change boolean not null,
 primary key(organization_id,app_id,user_id),foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
alter table bootik.bk_password_controls enable row level security;alter table bootik.bk_password_controls force row level security;revoke all on bootik.bk_password_controls from public,anon,authenticated;
create function bootik.bk_issue_session(p_org uuid,p_app uuid,p_user uuid,p_hash text,p_refresh text,p_version bigint,p_install uuid,p_platform text)
returns table(expires_at timestamptz,device_session_id uuid) language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare lim integer;v_id uuid;v_exp timestamptz;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':session:'||p_user::text,0));
 if not exists(select 1 from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_user and active) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_version is distinct from coalesce((select version from bootik.bk_password_controls where organization_id=p_org and app_id=p_app and user_id=p_user),0) then raise exception 'BOOTIK_CREDENTIAL_CHANGED';end if;
 if p_install is null or p_platform is null or p_platform not in ('android','web','test') then raise exception 'BOOTIK_DEVICE_INVALID';end if;
 update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=p_user and installation_id=p_install and revoked_at is null;
 select coalesce((select max_member_sessions from bootik.bk_security_settings where organization_id=p_org and app_id=p_app),2) into lim;
 if (select count(*) from bootik.bk_sessions s where s.organization_id=p_org and s.app_id=p_app and s.user_id=p_user and s.revoked_at is null and (s.expires_at>now() or s.refresh_expires_at>now()))>=lim then raise exception 'BOOTIK_DEVICE_LIMIT';end if;
 insert into bootik.bk_sessions as s(token_hash,organization_id,app_id,user_id,expires_at,refresh_hash,refresh_expires_at,installation_id,platform) values(p_hash,p_org,p_app,p_user,now()+interval '15 minutes',p_refresh,case when p_refresh is null then null else now()+interval '30 days' end,p_install,p_platform) returning s.expires_at,s.device_session_id into v_exp,v_id;
 insert into bootik.bk_security_audit(organization_id,app_id,actor,action,target) values(p_org,p_app,p_user,'session-open',v_id);
 return query select v_exp,v_id;
end $$;
-- Functional roles restrict existing coarse roles; no permission can enlarge the base SQL scope.
create table bootik.bk_member_functions(
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,function_code text not null check(function_code in ('director','site_manager','stock_manager','buyer','cashier','accountant','auditor','delivery','territory_manager','sales','picker','collection','crm')),
 primary key(organization_id,app_id,user_id),foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
alter table bootik.bk_member_functions enable row level security;alter table bootik.bk_member_functions force row level security;revoke all on bootik.bk_member_functions from public,anon,authenticated;
-- Scoped resource assignments do not imply whole-site access (NAXA Services scope contract).
create table bootik.bk_member_resource_rules(
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,location_id uuid not null,
 resource_kind text not null check(resource_kind in ('register','workstation','storage','territory')),resources jsonb not null check(jsonb_typeof(resources)='array' and jsonb_array_length(resources)<=50),
 primary key(organization_id,app_id,user_id,location_id),foreign key(organization_id,app_id,user_id,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id) on delete cascade
);
create table bootik.bk_workstations(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,activity_id uuid not null,location_id uuid not null,code text not null,label text not null,
 unique(organization_id,app_id,location_id,activity_id,code),foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
create table bootik.bk_territories(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,activity_id uuid not null,location_id uuid not null,code text not null,label text not null,
 unique(organization_id,app_id,location_id,activity_id,code),foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
do $$ declare n text;begin foreach n in array array['bk_member_resource_rules','bk_workstations','bk_territories'] loop execute format('alter table bootik.%I enable row level security',n);execute format('alter table bootik.%I force row level security',n);execute format('revoke all on bootik.%I from public,anon,authenticated',n);end loop;end $$;
-- Cache scope fingerprint; not a secret or authorization token. Any changed assignment yields a different cache partition.
create function bootik.bk_scope_stamp(p_org uuid,p_app uuid,p_user uuid)
returns text language sql stable security invoker set search_path=pg_catalog,bootik as $$
 select md5(jsonb_build_object('role',m.role,'function',f.function_code,'sites',coalesce((select jsonb_agg(jsonb_build_object('id',s.location_id,'restricted',s.activity_restricted,'resource_rule',(select jsonb_build_object('kind',rr.resource_kind,'ids',rr.resources) from bootik.bk_member_resource_rules rr where rr.organization_id=p_org and rr.app_id=p_app and rr.user_id=p_user and rr.location_id=s.location_id),'activities',coalesce((select jsonb_agg(a.activity_id order by a.activity_id) from bootik.bk_member_activity_scopes a where a.organization_id=p_org and a.app_id=p_app and a.user_id=p_user and a.location_id=s.location_id),'[]'::jsonb)) order by s.location_id) from bootik.bk_member_sites s where s.organization_id=p_org and s.app_id=p_app and s.user_id=p_user),'[]'::jsonb))::text)
 from bootik.bk_members m left join bootik.bk_member_functions f using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=p_user and m.active;
$$;
revoke all on function bootik.bk_scope_stamp(uuid,uuid,uuid) from public,anon,authenticated;
create function bootik.bk_permits_operation(p_org uuid,p_app uuid,p_user uuid,p_action text,p_payload jsonb)
returns boolean language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare f text;
begin
 select function_code into f from bootik.bk_member_functions where organization_id=p_org and app_id=p_app and user_id=p_user;
 if not found then return true;end if;
 if p_action in ('entitlement','security-state','support','support-cancel','approval-own-state','approval-execute') or (p_action='admin-action' and p_payload->>'kind'='session-revoke') then return true;end if;
 if f in ('director','site_manager') then return p_action in ('activities','catalog','team','dashboard','stock-health','stock-setup','master-create','partners','stock-template','stock-import-preview','stock-import-apply','sync-stock','sale','sync-sale','sync-item-sale','count-batch','transfer-ship','transfer-receive','transfers','purchases','purchase-create','purchase-receive','purchase-pay','cash-state','cash-action');end if;
 if f in ('stock_manager','picker') then return p_action in ('activities','catalog','stock-health','stock-setup','stock-template','stock-import-preview','stock-import-apply','sync-stock','count-batch','transfers','transfer-ship','transfer-receive') or (p_action='master-create' and p_payload->>'kind'='item');end if;
 if f='buyer' then return p_action in ('activities','catalog','partners','purchases','purchase-create','purchase-receive','stock-health') or (p_action='master-create' and p_payload->>'kind'='supplier');end if;
 if f='cashier' then return p_action in ('activities','catalog','cash-state','sale','sync-sale','sync-item-sale') or (p_action='cash-action' and p_payload->>'kind' in ('open','checkout'));end if;
 if f in ('accountant','auditor') then return p_action in ('activities','catalog','partners','dashboard','stock-health','purchases','transfers','cash-state');end if;
 if f in ('territory_manager','sales','delivery','collection','crm') then return p_action in ('activities','catalog');end if;
 return false;
end $$;
revoke all on function bootik.bk_permits_operation(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
-- Site device limit: installation identifier is not a credential or hardware attestation.
create table bootik.bk_site_device_policy(
 organization_id uuid not null,app_id uuid not null,location_id uuid not null,max_devices integer not null default 2 check(max_devices between 1 and 50),
 primary key(organization_id,app_id,location_id),foreign key(location_id,organization_id,app_id) references bootik.bk_locations(id,organization_id,app_id)
);
create table bootik.bk_device_site_bindings(
 device_session_id uuid not null references bootik.bk_sessions(device_session_id),organization_id uuid not null,app_id uuid not null,location_id uuid not null,
 user_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 primary key(device_session_id,location_id),foreign key(organization_id,app_id,user_id,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id) on delete cascade
);
alter table bootik.bk_site_device_policy enable row level security;alter table bootik.bk_site_device_policy force row level security;
alter table bootik.bk_device_site_bindings enable row level security;alter table bootik.bk_device_site_bindings force row level security;
revoke all on bootik.bk_site_device_policy,bootik.bk_device_site_bindings from public,anon,authenticated;
create function bootik.bk_bind_device_site(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_session uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare v_install uuid;lim integer;n integer;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':site-devices:'||p_site::text,0));
 select installation_id into v_install from bootik.bk_sessions where device_session_id=p_session and organization_id=p_org and app_id=p_app and user_id=p_actor and revoked_at is null and expires_at>now();
 if not found or v_install is null then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if exists(select 1 from bootik.bk_device_site_bindings d where d.device_session_id=p_session and d.location_id=p_site and d.organization_id=p_org and d.app_id=p_app and d.user_id=p_actor) then return true;end if;
 select coalesce((select max_devices from bootik.bk_site_device_policy where organization_id=p_org and app_id=p_app and location_id=p_site),2) into lim;
 select count(distinct s.installation_id) into n from bootik.bk_device_site_bindings d join bootik.bk_sessions s using(device_session_id) where d.organization_id=p_org and d.app_id=p_app and d.location_id=p_site and s.revoked_at is null and (s.expires_at>now() or s.refresh_expires_at>now()) and s.installation_id<>v_install;
 if n>=lim then raise exception 'BOOTIK_SITE_DEVICE_LIMIT' using errcode='42501';end if;
 insert into bootik.bk_device_site_bindings(device_session_id,organization_id,app_id,location_id,user_id) values(p_session,p_org,p_app,p_site,p_actor);
 if not exists(select 1 from bootik.bk_device_site_bindings d join bootik.bk_sessions s using(device_session_id) where d.organization_id=p_org and d.app_id=p_app and d.location_id=p_site and s.installation_id=v_install and d.device_session_id<>p_session) then
  insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,'new-site-device',v_install,jsonb_build_object('device_session_id',p_session));
 end if;
 return true;
end $$;
revoke all on function bootik.bk_bind_device_site(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;
create function bootik.bk_admin_action(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_req uuid,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare old bootik.bk_admin_receipts%rowtype;target_user uuid;session_id uuid;k text;why text;role_name text;actor_role text;answer jsonb;activity uuid;restricted boolean;old_state jsonb;profile text;new_role text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 if p_req is null or jsonb_typeof(p_data) is distinct from 'object' then raise exception 'BOOTIK_ADMIN_INVALID';end if;
 k:=p_data->>'kind';why:=btrim(coalesce(p_data->>'reason',''));
 if k not in ('session-revoke','member-scope','member-disable','session-limit','member-role','site-device-limit','offline-policy') or length(why) not between 3 and 500 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
 select role into actor_role from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_actor and active;
 if k='session-revoke' then
  session_id:=(p_data->>'device_session_id')::uuid;
  select user_id into target_user from bootik.bk_sessions s where s.device_session_id=session_id and s.organization_id=p_org and s.app_id=p_app;
  if not found or (target_user<>p_actor and (actor_role<>'promoteur' or exists(select 1 from bootik.bk_member_sites ms where ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=target_user and not exists(select 1 from bootik.bk_member_sites mine where mine.organization_id=p_org and mine.app_id=p_app and mine.user_id=p_actor and mine.location_id=ms.location_id and not mine.activity_restricted)))) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  select jsonb_build_object('revoked_at',revoked_at) into old_state from bootik.bk_sessions where device_session_id=session_id;
 elsif actor_role<>'promoteur' then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';
 elsif k in ('member-scope','member-disable','member-role') then
  target_user:=(p_data->>'member_id')::uuid;
  select role into role_name from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=target_user;
  if not found or target_user=p_actor or role_name='promoteur' or not exists(select 1 from bootik.bk_member_sites where organization_id=p_org and app_id=p_app and user_id=target_user and location_id=p_site) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if exists(select 1 from bootik.bk_member_sites ms where ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=target_user and not exists(select 1 from bootik.bk_member_sites mine where mine.organization_id=p_org and mine.app_id=p_app and mine.user_id=p_actor and mine.location_id=ms.location_id and not mine.activity_restricted)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  select jsonb_build_object('role',m.role,'active',m.active,'function',f.function_code,'restricted',ms.activity_restricted,'activities',(select coalesce(jsonb_agg(sc.activity_id order by sc.activity_id),'[]'::jsonb) from bootik.bk_member_activity_scopes sc where sc.organization_id=p_org and sc.app_id=p_app and sc.user_id=target_user and sc.location_id=p_site)) into old_state from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) left join bootik.bk_member_functions f using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=target_user and ms.location_id=p_site;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':admin:'||p_req::text,0));
 select * into old from bootik.bk_admin_receipts where id=p_req and organization_id=p_org and app_id=p_app;
 if found then
  if (old.actor,old.site_id,old.payload) is distinct from (p_actor,p_site,p_data) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.result;
 end if;
 if k='session-revoke' then
  update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where device_session_id=session_id and organization_id=p_org and app_id=p_app;
  answer:=jsonb_build_object('revoked',true,'device_session_id',session_id);
 elsif k='offline-policy' then
  if exists(select 1 from bootik.bk_locations l where l.organization_id=p_org and l.app_id=p_app and not exists(select 1 from bootik.bk_member_sites ms where ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=p_actor and ms.location_id=l.id and not ms.activity_restricted)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if (p_data->>'minutes')::integer not between 1 and 15 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
  select jsonb_build_object('minutes',coalesce((select offline_minutes from bootik.bk_security_settings where organization_id=p_org and app_id=p_app),15)) into old_state;
  insert into bootik.bk_security_settings(organization_id,app_id,offline_minutes) values(p_org,p_app,(p_data->>'minutes')::integer) on conflict(organization_id,app_id) do update set offline_minutes=excluded.offline_minutes;
  answer:=jsonb_build_object('minutes',(p_data->>'minutes')::integer);
 elsif k='site-device-limit' then
  if not exists(select 1 from bootik.bk_member_sites where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site and not activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if (p_data->>'limit')::integer not between 1 and 50 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||':site-devices:'||p_site::text,0));
  select jsonb_build_object('limit',coalesce((select max_devices from bootik.bk_site_device_policy where organization_id=p_org and app_id=p_app and location_id=p_site),2)) into old_state;
  if (select count(distinct s.installation_id) from bootik.bk_device_site_bindings d join bootik.bk_sessions s using(device_session_id) where d.organization_id=p_org and d.app_id=p_app and d.location_id=p_site and s.revoked_at is null and (s.expires_at>now() or s.refresh_expires_at>now()))>(p_data->>'limit')::integer then raise exception 'BOOTIK_REVOKE_DEVICES_FIRST';end if;
  insert into bootik.bk_site_device_policy(organization_id,app_id,location_id,max_devices) values(p_org,p_app,p_site,(p_data->>'limit')::integer) on conflict(organization_id,app_id,location_id) do update set max_devices=excluded.max_devices;
  answer:=jsonb_build_object('limit',(p_data->>'limit')::integer);
 elsif k='session-limit' then
  if exists(select 1 from bootik.bk_locations l where l.organization_id=p_org and l.app_id=p_app and not exists(select 1 from bootik.bk_member_sites ms where ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=p_actor and ms.location_id=l.id and not ms.activity_restricted)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  select jsonb_build_object('limit',coalesce((select max_member_sessions from bootik.bk_security_settings where organization_id=p_org and app_id=p_app),2)) into old_state;
  if (p_data->>'limit')::integer not between 1 and 50 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
  insert into bootik.bk_security_settings(organization_id,app_id,max_member_sessions) values(p_org,p_app,(p_data->>'limit')::integer) on conflict(organization_id,app_id) do update set max_member_sessions=excluded.max_member_sessions;
  answer:=jsonb_build_object('limit',(p_data->>'limit')::integer);
 elsif k='member-disable' then
  update bootik.bk_members set active=false where organization_id=p_org and app_id=p_app and user_id=target_user;
  update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=target_user;
  answer:=jsonb_build_object('disabled',true,'member_id',target_user);
 elsif k='member-role' then
  profile:=p_data->>'function_code';
  if profile is null or profile not in ('director','site_manager','stock_manager','buyer','cashier','accountant','auditor','delivery','territory_manager','sales','picker','collection','crm') then raise exception 'BOOTIK_ADMIN_INVALID';end if;
  new_role:=case when profile in ('cashier','delivery','sales','collection','crm') then 'staff' else 'manager' end;
  update bootik.bk_members set role=new_role where organization_id=p_org and app_id=p_app and user_id=target_user;
  insert into bootik.bk_member_functions(organization_id,app_id,user_id,function_code) values(p_org,p_app,target_user,profile) on conflict(organization_id,app_id,user_id) do update set function_code=excluded.function_code;
  update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=target_user;
  answer:=jsonb_build_object('member_id',target_user,'function_code',profile,'role',new_role);
 else
  if jsonb_typeof(p_data->'activities') is distinct from 'array' or jsonb_array_length(p_data->'activities')>22 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
  if not exists(select 1 from bootik.bk_member_sites where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site and not activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  -- An empty restricted list means no activity, never implicit whole-site permission.
  for activity in select value::uuid from jsonb_array_elements_text(p_data->'activities') loop
   if not exists(select 1 from bootik.bk_activity_locations al where al.organization_id=p_org and al.app_id=p_app and al.location_id=p_site and al.activity_id=activity) or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,activity) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  end loop;
  update bootik.bk_member_sites set activity_restricted=true where organization_id=p_org and app_id=p_app and user_id=target_user and location_id=p_site;
  delete from bootik.bk_member_activity_scopes where organization_id=p_org and app_id=p_app and user_id=target_user and location_id=p_site;
  insert into bootik.bk_member_activity_scopes(organization_id,app_id,user_id,location_id,activity_id) select p_org,p_app,target_user,p_site,distinct_ids.id from (select distinct value::uuid as id from jsonb_array_elements_text(p_data->'activities')) distinct_ids;
  update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=target_user;
  answer:=jsonb_build_object('member_id',target_user,'restricted',true,'activities',p_data->'activities');
 end if;
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,k,coalesce(session_id,target_user),jsonb_build_object('before',old_state,'after',answer,'reason',why));
 insert into bootik.bk_admin_receipts(id,organization_id,app_id,actor,site_id,payload,result) values(p_req,p_org,p_app,p_actor,p_site,p_data,answer);
 return answer;
end $$;
revoke all on function bootik.bk_issue_session(uuid,uuid,uuid,text,text,bigint,uuid,text),bootik.bk_admin_action(uuid,uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;

create function bootik.bk_complete_recovery(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_request uuid,p_method text,p_note text,p_salt text,p_hash text)
returns boolean language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare target_user uuid;identifier_value text;processed timestamptz;target_role text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not exists(select 1 from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_actor and role='promoteur' and active) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_method not in ('in_person','verified_internal') or p_note is null or length(btrim(p_note)) not between 10 and 500 or p_salt !~ '^[0-9a-f]{32}$' or p_hash !~ '^[0-9a-f]{128}$' then raise exception 'BOOTIK_RECOVERY_INVALID';end if;
 select c.user_id,c.identifier,m.role into target_user,identifier_value,target_role from bootik.bk_recovery_requests q join bootik.bk_credentials c on c.identifier=q.identifier join bootik.bk_members m using(organization_id,app_id,user_id) where q.id=p_request and c.organization_id=p_org and c.app_id=p_app and m.active;
 if not found or target_user=p_actor or target_role='promoteur' or not exists(select 1 from bootik.bk_member_sites where organization_id=p_org and app_id=p_app and user_id=target_user and location_id=p_site) or exists(select 1 from bootik.bk_member_sites ms where ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=target_user and not exists(select 1 from bootik.bk_member_sites mine where mine.organization_id=p_org and mine.app_id=p_app and mine.user_id=p_actor and mine.location_id=ms.location_id and not mine.activity_restricted)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':session:'||target_user::text,0));
 select processed_at into processed from bootik.bk_recovery_requests where id=p_request;
 if processed is not null then return false;end if;
 update bootik.bk_credentials set salt_hex=p_salt,verifier_hex=p_hash where organization_id=p_org and app_id=p_app and user_id=target_user;
 insert into bootik.bk_password_controls(organization_id,app_id,user_id,version,requires_change) values(p_org,p_app,target_user,1,true) on conflict(organization_id,app_id,user_id) do update set version=bootik.bk_password_controls.version+1,requires_change=true;
 update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=target_user;
 update bootik.bk_recovery_requests set processed_at=clock_timestamp(),handled_by=p_actor where identifier=identifier_value and processed_at is null;
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,'recovery-complete',target_user,jsonb_build_object('request_id',p_request,'method',p_method,'note',btrim(p_note),'sessions_revoked',true));
 return true;
end $$;
create function bootik.bk_change_password(p_org uuid,p_app uuid,p_actor uuid,p_token_hash text,p_version bigint,p_salt text,p_hash text)
returns boolean language plpgsql security invoker set search_path=pg_catalog,bootik as $$
begin
 if p_salt !~ '^[0-9a-f]{32}$' or p_hash !~ '^[0-9a-f]{128}$' then raise exception 'BOOTIK_PASSWORD_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':session:'||p_actor::text,0));
 if not exists(select 1 from bootik.bk_sessions s join bootik.bk_members m using(organization_id,app_id,user_id) where s.token_hash=p_token_hash and s.organization_id=p_org and s.app_id=p_app and s.user_id=p_actor and s.revoked_at is null and s.expires_at>now() and m.active) or p_version is distinct from coalesce((select version from bootik.bk_password_controls where organization_id=p_org and app_id=p_app and user_id=p_actor),0) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 update bootik.bk_credentials set salt_hex=p_salt,verifier_hex=p_hash where organization_id=p_org and app_id=p_app and user_id=p_actor;
 insert into bootik.bk_password_controls(organization_id,app_id,user_id,version,requires_change) values(p_org,p_app,p_actor,1,false) on conflict(organization_id,app_id,user_id) do update set version=bootik.bk_password_controls.version+1,requires_change=false;
 update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=p_actor;
 insert into bootik.bk_security_audit(organization_id,app_id,actor,action,target,details) values(p_org,p_app,p_actor,'password-change',p_actor,jsonb_build_object('sessions_revoked',true));
 return true;
end $$;
revoke all on function bootik.bk_complete_recovery(uuid,uuid,uuid,uuid,uuid,text,text,text,text),bootik.bk_change_password(uuid,uuid,uuid,text,bigint,text,text) from public,anon,authenticated;

-- Family provisioning adapter. Only accepts an existing central Auth identity; no local auth.users creation.
create table bootik.bk_member_profiles(
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,display_name text not null,central_event_id uuid not null unique,
 primary key(organization_id,app_id,user_id),foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
create table bootik.bk_member_requests(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,location_id uuid not null,requested_by uuid not null,
 display_name text not null,function_code text not null,activities jsonb not null,reason text not null,state text not null default 'pending' check(state in ('pending','provisioned','refused')),created_at timestamptz not null default clock_timestamp(),completed_at timestamptz,member_id uuid,
 foreign key(organization_id,app_id,requested_by,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
create table bootik.bk_family_provision_events(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,central_actor_id uuid not null,payload jsonb not null,result jsonb not null,created_at timestamptz not null default clock_timestamp()
);
do $$ declare n text;begin foreach n in array array['bk_member_profiles','bk_member_requests','bk_family_provision_events'] loop execute format('alter table bootik.%I enable row level security',n);execute format('alter table bootik.%I force row level security',n);execute format('revoke all on bootik.%I from public,anon,authenticated',n);end loop;end $$;
create function bootik.bk_request_member(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_id uuid,p_name text,p_function text,p_activities jsonb,p_reason text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare old bootik.bk_member_requests%rowtype;v_act uuid;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not exists(select 1 from bootik.bk_members m join bootik.bk_member_sites s using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=p_actor and m.role='promoteur' and s.location_id=p_site and not s.activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_id is null or length(btrim(coalesce(p_name,''))) not between 2 and 160 or length(btrim(coalesce(p_reason,''))) not between 3 and 500 or p_function not in ('director','site_manager','stock_manager','buyer','cashier','accountant','auditor','delivery','territory_manager','sales','picker','collection','crm') or jsonb_typeof(p_activities) is distinct from 'array' or jsonb_array_length(p_activities) not between 1 and 22 then raise exception 'BOOTIK_PROVISION_INVALID';end if;
 for v_act in select value::uuid from jsonb_array_elements_text(p_activities) loop
  if not exists(select 1 from bootik.bk_activity_locations al join bootik.bk_activities a on (a.id,a.organization_id,a.app_id)=(al.activity_id,al.organization_id,al.app_id) where al.organization_id=p_org and al.app_id=p_app and al.location_id=p_site and al.activity_id=v_act and a.status='active') or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,v_act) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 end loop;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':member-request:'||p_id::text,0));
 select * into old from bootik.bk_member_requests where id=p_id and organization_id=p_org and app_id=p_app;
 if found then
  if (old.requested_by,old.location_id,old.display_name,old.function_code,old.activities,old.reason) is distinct from (p_actor,p_site,btrim(p_name),p_function,p_activities,btrim(p_reason)) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 insert into bootik.bk_member_requests(id,organization_id,app_id,location_id,requested_by,display_name,function_code,activities,reason) values(p_id,p_org,p_app,p_site,p_actor,btrim(p_name),p_function,p_activities,btrim(p_reason));
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,'member-request',p_id,jsonb_build_object('function',p_function,'activities',p_activities));
 return p_id;
end $$;
create function bootik.bk_family_provision(p_event uuid,p_central_actor uuid,p_payload jsonb,p_salt text,p_hash text)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;o uuid;u uuid;s uuid;v uuid;rid uuid;k text;identifier_value text;name_value text;role_value text;f text;req bootik.bk_member_requests%rowtype;old bootik.bk_family_provision_events%rowtype;answer jsonb;v_act uuid;member_role text;activities jsonb;
begin
 if p_event is null or p_central_actor is null or jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'BOOTIK_PROVISION_INVALID';end if;
 select app_id into a from bootik.bk_app_registration where app_code='bootik';
 o:=(p_payload->>'organization_id')::uuid;k:=p_payload->>'kind';
 if o is null or k not in ('organization','employee','refuse','site','activity','member-site','promoter-recovery') then raise exception 'BOOTIK_PROVISION_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(o::text||':family-provision:'||p_event::text,0));
 select * into old from bootik.bk_family_provision_events where id=p_event;
 if found then
  if (old.organization_id,old.app_id,old.central_actor_id,old.payload) is distinct from (o,a,p_central_actor,p_payload) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.result||jsonb_build_object('fresh',false);
 end if;
 if k in ('site','activity','member-site','promoter-recovery') then
  s:=(p_payload->>'site_id')::uuid;u:=(p_payload->>'central_user_id')::uuid;
  if s is null or u is null or not exists(select 1 from bootik.bk_organizations where organization_id=o and app_id=a) then raise exception 'BOOTIK_PROVISION_INVALID';end if;
  perform pg_advisory_xact_lock(hashtextextended(o::text||':organization-structure:'||a::text,0));
  select role into member_role from bootik.bk_members where organization_id=o and app_id=a and user_id=u and active;
  if not found then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if k='site' then
   v:=(p_payload->>'activity_id')::uuid;
   if member_role<>'promoteur' or v is null or length(btrim(coalesce(p_payload->>'site_name',''))) not between 2 and 160 or not exists(select 1 from bootik.bk_activities where id=v and organization_id=o and app_id=a and status='active') then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   insert into bootik.bk_locations(id,organization_id,app_id,display_name) values(s,o,a,btrim(p_payload->>'site_name'));
   insert into bootik.bk_activity_locations(app_id,organization_id,activity_id,location_id) values(a,o,v,s);
   insert into bootik.bk_member_sites(organization_id,app_id,user_id,location_id,activity_restricted) values(o,a,u,s,false);
   answer:=jsonb_build_object('state','provisioned','site_id',s,'activity_id',v,'member_id',u);
  elsif k='activity' then
   v:=(p_payload->>'activity_id')::uuid;
   if member_role<>'promoteur' or v is null or length(btrim(coalesce(p_payload->>'activity_name',''))) not between 2 and 160 or not exists(select 1 from bootik.bk_member_sites where organization_id=o and app_id=a and user_id=u and location_id=s and not activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   insert into bootik.bk_activities(id,app_id,organization_id,universe_code,profile_code,display_name,status) values(v,a,o,p_payload->>'universe',p_payload->>'profile',btrim(p_payload->>'activity_name'),'active');
   insert into bootik.bk_activity_locations(app_id,organization_id,activity_id,location_id,is_primary) values(a,o,v,s,true);
   answer:=jsonb_build_object('state','provisioned','site_id',s,'activity_id',v,'member_id',u);
  elsif k='member-site' then
   activities:=p_payload->'activities';
   if member_role='promoteur' or jsonb_typeof(activities) is distinct from 'array' or jsonb_array_length(activities) not between 1 and 22 or not exists(select 1 from bootik.bk_locations where id=s and organization_id=o and app_id=a) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   for v_act in select value::uuid from jsonb_array_elements_text(activities) loop
    if not exists(select 1 from bootik.bk_activity_locations al join bootik.bk_activities ac on (ac.id,ac.organization_id,ac.app_id)=(al.activity_id,al.organization_id,al.app_id) where al.organization_id=o and al.app_id=a and al.location_id=s and al.activity_id=v_act and ac.status='active') then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   end loop;
   -- New membership only; existing site restrictions remain under the promoteur's scoped admin contract.
   insert into bootik.bk_member_sites(organization_id,app_id,user_id,location_id,activity_restricted) values(o,a,u,s,true);
   insert into bootik.bk_member_activity_scopes(organization_id,app_id,user_id,location_id,activity_id) select o,a,u,s,id from (select distinct value::uuid as id from jsonb_array_elements_text(activities)) ids;
   answer:=jsonb_build_object('state','provisioned','site_id',s,'member_id',u,'activities',activities);
  else
   if member_role<>'promoteur' or not exists(select 1 from bootik.bk_member_sites where organization_id=o and app_id=a and user_id=u and location_id=s and not activity_restricted) or length(btrim(coalesce(p_payload->>'note',''))) not between 10 and 500 or p_salt !~ '^[0-9a-f]{32}$' or p_hash !~ '^[0-9a-f]{128}$' then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   perform pg_advisory_xact_lock(hashtextextended(o::text||':session:'||u::text,0));
   update bootik.bk_credentials set salt_hex=p_salt,verifier_hex=p_hash where organization_id=o and app_id=a and user_id=u;
   if not found then raise exception 'BOOTIK_PROVISION_INVALID';end if;
   insert into bootik.bk_password_controls(organization_id,app_id,user_id,version,requires_change) values(o,a,u,1,true) on conflict(organization_id,app_id,user_id) do update set version=bootik.bk_password_controls.version+1,requires_change=true;
   answer:=jsonb_build_object('state','recovered','site_id',s,'member_id',u);
  end if;
  if k in ('member-site','promoter-recovery') then update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=o and app_id=a and user_id=u;end if;
  insert into bootik.bk_family_provision_events(id,organization_id,app_id,central_actor_id,payload,result) values(p_event,o,a,p_central_actor,p_payload,answer);
  insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(o,a,p_central_actor,s,'family-provision-'||k,u,jsonb_build_object('event_id',p_event,'result',answer));
  return answer||jsonb_build_object('fresh',true);
 end if;
 if k in ('employee','refuse') then
  rid:=(p_payload->>'request_id')::uuid;
  -- A central event may complete only the exact pending request from this tenant.
  perform pg_advisory_xact_lock(hashtextextended(o::text||':member-request:'||rid::text,0));
  select * into req from bootik.bk_member_requests where id=rid and organization_id=o and app_id=a for update;
  if not found or req.state<>'pending' then raise exception 'BOOTIK_PROVISION_REQUEST_NOT_PENDING';end if;
  s:=req.location_id;
  if k='refuse' then
   if length(btrim(coalesce(p_payload->>'reason',''))) not between 3 and 500 then raise exception 'BOOTIK_PROVISION_INVALID';end if;
   update bootik.bk_member_requests set state='refused',completed_at=clock_timestamp() where id=rid;
   answer:=jsonb_build_object('request_id',rid,'state','refused');
  else
   if not exists(select 1 from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) where m.organization_id=o and m.app_id=a and m.user_id=req.requested_by and m.active and m.role='promoteur' and ms.location_id=s and not ms.activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   name_value:=req.display_name;f:=req.function_code;role_value:=case when f in ('cashier','delivery','sales','collection','crm') then 'staff' else 'manager' end;
  end if;
 else
  s:=(p_payload->>'site_id')::uuid;v:=(p_payload->>'activity_id')::uuid;name_value:=btrim(p_payload->>'display_name');role_value:='promoteur';
  if s is null or v is null or length(btrim(coalesce(p_payload->>'organization_name',''))) not between 2 and 160 or length(btrim(coalesce(p_payload->>'site_name',''))) not between 2 and 160 or length(btrim(coalesce(p_payload->>'activity_name',''))) not between 2 and 160 then raise exception 'BOOTIK_PROVISION_INVALID';end if;
  insert into bootik.bk_organizations(organization_id,app_id,display_name) values(o,a,btrim(p_payload->>'organization_name'));
  insert into bootik.bk_locations(id,organization_id,app_id,display_name) values(s,o,a,btrim(p_payload->>'site_name'));
  insert into bootik.bk_activities(id,app_id,organization_id,universe_code,profile_code,display_name,status) values(v,a,o,p_payload->>'universe',p_payload->>'profile',btrim(p_payload->>'activity_name'),'active');
  insert into bootik.bk_activity_locations(app_id,organization_id,activity_id,location_id,is_primary) values(a,o,v,s,true);
 end if;
 if k<>'refuse' then
  u:=(p_payload->>'central_user_id')::uuid;identifier_value:=lower(btrim(p_payload->>'identifier'));
  if u is null or length(coalesce(name_value,'')) not between 2 and 160 or identifier_value is null or identifier_value !~ '^[a-z0-9][a-z0-9._-]{2,159}$' or p_salt !~ '^[0-9a-f]{32}$' or p_hash !~ '^[0-9a-f]{128}$' then raise exception 'BOOTIK_PROVISION_INVALID';end if;
  -- FK to auth.users requires a central-provisioned identity. No write to auth schema.
  insert into bootik.bk_members(organization_id,app_id,user_id,role,active) values(o,a,u,role_value,true);
  insert into bootik.bk_member_sites(organization_id,app_id,user_id,location_id,activity_restricted) values(o,a,u,s,k='employee');
  if k='employee' then
   for v_act in select value::uuid from jsonb_array_elements_text(req.activities) loop
    if not exists(select 1 from bootik.bk_activity_locations al join bootik.bk_activities a1 on (a1.id,a1.organization_id,a1.app_id)=(al.activity_id,al.organization_id,al.app_id) where al.organization_id=o and al.app_id=a and al.location_id=s and al.activity_id=v_act and a1.status='active') then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
   end loop;
   insert into bootik.bk_member_activity_scopes(organization_id,app_id,user_id,location_id,activity_id) select o,a,u,s,id from (select distinct value::uuid as id from jsonb_array_elements_text(req.activities)) ids;
   insert into bootik.bk_member_functions(organization_id,app_id,user_id,function_code) values(o,a,u,f);
   update bootik.bk_member_requests set state='provisioned',completed_at=clock_timestamp(),member_id=u where id=rid;
  end if;
  insert into bootik.bk_credentials(organization_id,app_id,user_id,identifier,salt_hex,verifier_hex) values(o,a,u,identifier_value,p_salt,p_hash);
  insert into bootik.bk_password_controls(organization_id,app_id,user_id,version,requires_change) values(o,a,u,1,true);
  insert into bootik.bk_member_profiles(organization_id,app_id,user_id,display_name,central_event_id) values(o,a,u,name_value,p_event);
  answer:=jsonb_build_object('member_id',u,'organization_id',o,'site_id',s,'request_id',rid,'identifier',identifier_value,'state','provisioned');
 end if;
 insert into bootik.bk_family_provision_events(id,organization_id,app_id,central_actor_id,payload,result) values(p_event,o,a,p_central_actor,p_payload,answer);
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(o,a,p_central_actor,s,'family-provision-'||k,coalesce(u,rid),jsonb_build_object('event_id',p_event,'result',answer));
 return answer||jsonb_build_object('fresh',true);
end $$;
revoke all on function bootik.bk_request_member(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,text),bootik.bk_family_provision(uuid,uuid,jsonb,text,text) from public,anon,authenticated;

commit;
