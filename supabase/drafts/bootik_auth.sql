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
create table bootik.bk_security_settings(
 organization_id uuid not null,app_id uuid not null,max_member_sessions integer not null default 2 check(max_member_sessions between 1 and 50),
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
create function bootik.bk_issue_session(p_org uuid,p_app uuid,p_user uuid,p_hash text,p_refresh text,p_version bigint)
returns table(expires_at timestamptz,device_session_id uuid) language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare lim integer;v_id uuid;v_exp timestamptz;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':session:'||p_user::text,0));
 if not exists(select 1 from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_user and active) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_version is distinct from coalesce((select version from bootik.bk_password_controls where organization_id=p_org and app_id=p_app and user_id=p_user),0) then raise exception 'BOOTIK_CREDENTIAL_CHANGED';end if;
 select coalesce((select max_member_sessions from bootik.bk_security_settings where organization_id=p_org and app_id=p_app),2) into lim;
 if (select count(*) from bootik.bk_sessions s where s.organization_id=p_org and s.app_id=p_app and s.user_id=p_user and s.revoked_at is null and (s.expires_at>now() or s.refresh_expires_at>now()))>=lim then raise exception 'BOOTIK_DEVICE_LIMIT';end if;
 insert into bootik.bk_sessions as s(token_hash,organization_id,app_id,user_id,expires_at,refresh_hash,refresh_expires_at) values(p_hash,p_org,p_app,p_user,now()+interval '15 minutes',p_refresh,case when p_refresh is null then null else now()+interval '30 days' end) returning s.expires_at,s.device_session_id into v_exp,v_id;
 insert into bootik.bk_security_audit(organization_id,app_id,actor,action,target) values(p_org,p_app,p_user,'session-open',v_id);
 return query select v_exp,v_id;
end $$;
-- Functional roles restrict existing coarse roles; no permission can enlarge the base SQL scope.
create table bootik.bk_member_functions(
 organization_id uuid not null,app_id uuid not null,user_id uuid not null,function_code text not null check(function_code in ('director','site_manager','stock_manager','buyer','cashier','accountant','auditor','delivery','territory_manager','sales','picker','collection','crm')),
 primary key(organization_id,app_id,user_id),foreign key(organization_id,app_id,user_id) references bootik.bk_members(organization_id,app_id,user_id)
);
alter table bootik.bk_member_functions enable row level security;alter table bootik.bk_member_functions force row level security;revoke all on bootik.bk_member_functions from public,anon,authenticated;
create function bootik.bk_permits_operation(p_org uuid,p_app uuid,p_user uuid,p_action text,p_payload jsonb)
returns boolean language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare f text;
begin
 select function_code into f from bootik.bk_member_functions where organization_id=p_org and app_id=p_app and user_id=p_user;
 if not found then return true;end if;
 if p_action in ('entitlement','security-state','support','support-cancel') or (p_action='admin-action' and p_payload->>'kind'='session-revoke') then return true;end if;
 if f in ('director','site_manager') then return p_action in ('activities','catalog','team','dashboard','stock-health','stock-setup','master-create','partners','stock-template','stock-import-preview','stock-import-apply','sync-stock','sale','sync-sale','sync-item-sale','count-batch','transfer-ship','transfer-receive','transfers','purchases','purchase-create','purchase-receive','purchase-pay','cash-state','cash-action');end if;
 if f in ('stock_manager','picker') then return p_action in ('activities','catalog','stock-health','stock-setup','stock-template','stock-import-preview','stock-import-apply','sync-stock','count-batch','transfers','transfer-ship','transfer-receive') or (p_action='master-create' and p_payload->>'kind'='item');end if;
 if f='buyer' then return p_action in ('activities','catalog','partners','purchases','purchase-create','purchase-receive','stock-health') or (p_action='master-create' and p_payload->>'kind'='supplier');end if;
 if f='cashier' then return p_action in ('activities','catalog','cash-state','sale','sync-sale','sync-item-sale') or (p_action='cash-action' and p_payload->>'kind' in ('open','checkout'));end if;
 if f in ('accountant','auditor') then return p_action in ('activities','catalog','partners','dashboard','stock-health','purchases','transfers','cash-state');end if;
 if f in ('territory_manager','sales','delivery','collection','crm') then return p_action in ('activities','catalog');end if;
 return false;
end $$;
revoke all on function bootik.bk_permits_operation(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
create function bootik.bk_admin_action(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_req uuid,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare old bootik.bk_admin_receipts%rowtype;target_user uuid;session_id uuid;k text;why text;role_name text;actor_role text;answer jsonb;activity uuid;restricted boolean;old_state jsonb;profile text;new_role text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 if p_req is null or jsonb_typeof(p_data) is distinct from 'object' then raise exception 'BOOTIK_ADMIN_INVALID';end if;
 k:=p_data->>'kind';why:=btrim(coalesce(p_data->>'reason',''));
 if k not in ('session-revoke','member-scope','member-disable','session-limit','member-role') or length(why) not between 3 and 500 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
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
revoke all on function bootik.bk_issue_session(uuid,uuid,uuid,text,text,bigint),bootik.bk_admin_action(uuid,uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;

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

commit;
