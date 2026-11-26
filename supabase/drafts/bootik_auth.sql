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
create function bootik.bk_issue_session(p_org uuid,p_app uuid,p_user uuid,p_hash text,p_refresh text)
returns table(expires_at timestamptz,device_session_id uuid) language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare lim integer;v_id uuid;v_exp timestamptz;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':session:'||p_user::text,0));
 if not exists(select 1 from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_user and active) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select coalesce((select max_member_sessions from bootik.bk_security_settings where organization_id=p_org and app_id=p_app),2) into lim;
 if (select count(*) from bootik.bk_sessions s where s.organization_id=p_org and s.app_id=p_app and s.user_id=p_user and s.revoked_at is null and (s.expires_at>now() or s.refresh_expires_at>now()))>=lim then raise exception 'BOOTIK_DEVICE_LIMIT';end if;
 insert into bootik.bk_sessions as s(token_hash,organization_id,app_id,user_id,expires_at,refresh_hash,refresh_expires_at) values(p_hash,p_org,p_app,p_user,now()+interval '15 minutes',p_refresh,case when p_refresh is null then null else now()+interval '30 days' end) returning s.expires_at,s.device_session_id into v_exp,v_id;
 insert into bootik.bk_security_audit(organization_id,app_id,actor,action,target) values(p_org,p_app,p_user,'session-open',v_id);
 return query select v_exp,v_id;
end $$;
create function bootik.bk_admin_action(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_req uuid,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare old bootik.bk_admin_receipts%rowtype;target_user uuid;session_id uuid;k text;why text;role_name text;actor_role text;answer jsonb;activity uuid;restricted boolean;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 if p_req is null or jsonb_typeof(p_data) is distinct from 'object' then raise exception 'BOOTIK_ADMIN_INVALID';end if;
 k:=p_data->>'kind';why:=btrim(coalesce(p_data->>'reason',''));
 if k not in ('session-revoke','member-scope','member-disable','session-limit') or length(why) not between 3 and 500 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
 select role into actor_role from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_actor and active;
 if k='session-revoke' then
  session_id:=(p_data->>'device_session_id')::uuid;
  select user_id into target_user from bootik.bk_sessions s where s.device_session_id=session_id and s.organization_id=p_org and s.app_id=p_app;
  if not found or (target_user<>p_actor and actor_role<>'promoteur') then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 elsif actor_role<>'promoteur' then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';
 elsif k in ('member-scope','member-disable') then
  target_user:=(p_data->>'member_id')::uuid;
  select role into role_name from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=target_user;
  if not found or target_user=p_actor or role_name='promoteur' or not exists(select 1 from bootik.bk_member_sites where organization_id=p_org and app_id=p_app and user_id=target_user and location_id=p_site) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if exists(select 1 from bootik.bk_member_sites ms where ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=target_user and not exists(select 1 from bootik.bk_member_sites mine where mine.organization_id=p_org and mine.app_id=p_app and mine.user_id=p_actor and mine.location_id=ms.location_id and not mine.activity_restricted)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
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
  if not exists(select 1 from bootik.bk_member_sites where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site and not activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if (p_data->>'limit')::integer not between 1 and 50 then raise exception 'BOOTIK_ADMIN_INVALID';end if;
  insert into bootik.bk_security_settings(organization_id,app_id,max_member_sessions) values(p_org,p_app,(p_data->>'limit')::integer) on conflict(organization_id,app_id) do update set max_member_sessions=excluded.max_member_sessions;
  answer:=jsonb_build_object('limit',(p_data->>'limit')::integer);
 elsif k='member-disable' then
  update bootik.bk_members set active=false where organization_id=p_org and app_id=p_app and user_id=target_user;
  update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=target_user;
  answer:=jsonb_build_object('disabled',true,'member_id',target_user);
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
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,k,coalesce(session_id,target_user),p_data);
 insert into bootik.bk_admin_receipts(id,organization_id,app_id,actor,site_id,payload,result) values(p_req,p_org,p_app,p_actor,p_site,p_data,answer);
 return answer;
end $$;
revoke all on function bootik.bk_issue_session(uuid,uuid,uuid,text,text),bootik.bk_admin_action(uuid,uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;

commit;
