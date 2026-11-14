-- Prompt 0.4 — additive account lifecycle candidate.
-- DRAFT ONLY: never apply to the shared NAXA project without an explicit migration approval.
-- auth.users and public.profiles remain canonical. This schema stores only Famille grants,
-- one-time invitations, device registrations and security workflow metadata.
begin;
create schema if not exists famille_private;
comment on schema famille_private is 'Private Famille account lifecycle metadata; never expose through PostgREST.';
create table if not exists famille_private.account_app_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  app_code text not null check (app_code in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad')),
  account_kind text not null check (account_kind in ('client','professional','employee')),
  organization_id uuid,
  location_id uuid,
  role_code text,
  plan_code text,
  duration_days integer check (duration_days is null or duration_days > 0),
  discount_percent numeric(5,2) not null default 0 check (discount_percent between 0 and 100),
  trial_days integer not null default 0 check (trial_days >= 0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  status text not null default 'active' check (status in ('pending','active','suspended','revoked')),
  granted_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at),
  unique nulls not distinct (user_id, app_code, organization_id, location_id)
);
create index if not exists account_app_access_scope_idx on famille_private.account_app_access(user_id,app_code,status);
create table if not exists famille_private.account_invites (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  user_id uuid not null references auth.users(id) on delete restrict,
  token_hash bytea not null unique,
  app_code text not null check (app_code in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad')),
  account_kind text not null check (account_kind in ('client','professional','employee')),
  organization_id uuid,
  location_id uuid,
  role_code text,
  status text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  check (expires_at > created_at),
  check ((status='accepted') = (accepted_at is not null))
);
create index if not exists account_invites_pending_idx on famille_private.account_invites(expires_at) where status='pending';
create table if not exists famille_private.account_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  app_code text not null check (app_code in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad')),
  organization_id uuid,
  location_id uuid,
  installation_id text not null,
  auth_session_id uuid,
  platform text not null check (platform in ('android','web')),
  device_label text,
  status text not null default 'active' check (status in ('active','revoked','lost')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  unique(user_id,app_code,installation_id),
  check ((status='active' and revoked_at is null) or (status in ('revoked','lost') and revoked_at is not null))
);
create index if not exists account_devices_scope_idx on famille_private.account_devices(user_id,app_code,organization_id,location_id,status,created_at);
create table if not exists famille_private.login_guard (
  login_hash text not null,
  app_code text not null check (app_code in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad')),
  failed_attempts integer not null default 0 check (failed_attempts between 0 and 5),
  locked_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key(login_hash,app_code)
);
create table if not exists famille_private.recovery_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete restrict,
  login_hash text not null,
  channel text not null check(channel in ('email','whatsapp')),
  status text not null default 'pending' check(status in ('pending','identity_check','approved','rejected','completed')),
  reviewed_by uuid references auth.users(id) on delete restrict,
  review_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  completed_at timestamptz
);
create table if not exists famille_private.account_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete restrict,
  subject_user_id uuid references auth.users(id) on delete restrict,
  app_code text,
  event_code text not null,
  outcome text not null check(outcome in ('success','denied','failed')),
  reason_code text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists account_audit_subject_idx on famille_private.account_audit_log(subject_user_id,created_at desc);
alter table famille_private.account_app_access enable row level security;
alter table famille_private.account_invites enable row level security;
alter table famille_private.account_devices enable row level security;
alter table famille_private.login_guard enable row level security;
alter table famille_private.recovery_requests enable row level security;
alter table famille_private.account_audit_log enable row level security;
revoke all on schema famille_private from public,anon,authenticated;
revoke all on all tables in schema famille_private from public,anon,authenticated;
grant usage on schema famille_private to service_role;
grant select,insert,update,delete on all tables in schema famille_private to service_role;
grant usage,select on all sequences in schema famille_private to service_role;

create or replace function famille_private.register_device(
  p_user_id uuid,p_app_code text,p_organization_id uuid,p_location_id uuid,
  p_installation_id text,p_auth_session_id uuid,p_platform text,p_device_label text
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,famille_private
as $$
declare v_device uuid; v_evicted uuid; v_device_status text;
begin
  if p_user_id is null or p_installation_id is null or length(p_installation_id)<16
     or p_app_code not in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad')
     or p_platform not in ('android','web') then
    raise exception 'invalid_device_registration' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    p_app_code||':'||coalesce(p_organization_id::text,'-')||':'||coalesce(p_location_id::text,'-')||':'||case when p_organization_id is null and p_location_id is null then p_user_id::text else 'shared-point' end,0));
  select id,status into v_device,v_device_status from famille_private.account_devices
    where user_id=p_user_id and app_code=p_app_code and installation_id=p_installation_id;
  if v_device is not null and v_device_status<>'active' then raise exception 'device_revoked' using errcode='42501'; end if;
  if v_device is not null then
    update famille_private.account_devices set organization_id=p_organization_id,location_id=p_location_id,
      auth_session_id=p_auth_session_id,platform=p_platform,device_label=p_device_label,last_seen_at=now() where id=v_device;
  else
    insert into famille_private.account_devices(user_id,app_code,organization_id,location_id,installation_id,auth_session_id,platform,device_label)
      values(p_user_id,p_app_code,p_organization_id,p_location_id,p_installation_id,p_auth_session_id,p_platform,p_device_label)
      returning id into v_device;
  end if;
  if (select count(*) from famille_private.account_devices where user_id=p_user_id and app_code=p_app_code
      and organization_id is not distinct from p_organization_id and location_id is not distinct from p_location_id and status='active') > 2 then
    select id into v_evicted from famille_private.account_devices
      where user_id=p_user_id and app_code=p_app_code
        and organization_id is not distinct from p_organization_id
        and location_id is not distinct from p_location_id and status='active'
      order by created_at asc,id asc limit 1;
  end if;
  if v_evicted is not null then
    update famille_private.account_devices set status='revoked',revoked_at=now()
      where id=v_evicted;
  end if;
  return jsonb_build_object('device_id',v_device,'revoked_oldest_device_id',v_evicted,'active_limit',2);
end $$;
create or replace function famille_private.record_login_failure(p_login_hash text,p_app_code text)
returns timestamptz language plpgsql security definer
set search_path=pg_catalog,famille_private
as $$
declare v_count integer; v_locked timestamptz;
begin
  insert into famille_private.login_guard(login_hash,app_code,failed_attempts,updated_at)
  values(p_login_hash,p_app_code,1,now())
  on conflict(login_hash,app_code) do update set
    failed_attempts=case when famille_private.login_guard.locked_until>now() then 5 else least(5,famille_private.login_guard.failed_attempts+1) end,
    locked_until=case when (case when famille_private.login_guard.locked_until>now() then 5 else least(5,famille_private.login_guard.failed_attempts+1) end)>=5
      then greatest(coalesce(famille_private.login_guard.locked_until,now()),now())+interval '15 minutes' else null end,
    updated_at=now()
  returning failed_attempts,locked_until into v_count,v_locked;
  if v_count>=5 and v_locked is null then
    update famille_private.login_guard set locked_until=now()+interval '15 minutes'
      where login_hash=p_login_hash and app_code=p_app_code returning locked_until into v_locked;
  end if;
  return v_locked;
end $$;
create or replace function famille_private.login_is_locked(p_login_hash text,p_app_code text)
returns boolean language sql stable security definer
set search_path=pg_catalog,famille_private
as $$ select exists(select 1 from famille_private.login_guard where login_hash=p_login_hash and app_code=p_app_code and locked_until>now()) $$;
create or replace function famille_private.clear_login_failures(p_login_hash text,p_app_code text)
returns void language sql security definer set search_path=pg_catalog,famille_private
as $$ delete from famille_private.login_guard where login_hash=p_login_hash and app_code=p_app_code $$;
create or replace function famille_private.revoke_device(p_device_id uuid,p_actor_id uuid)
returns boolean language plpgsql security definer set search_path=pg_catalog,famille_private
as $$
begin
  update famille_private.account_devices set status='revoked',revoked_at=now(),revoked_by=p_actor_id
    where id=p_device_id and status='active';
  return found;
end $$;

create or replace function famille_private.bind_auth_session(p_user_id uuid,p_session_id uuid,p_app_code text)
returns boolean language plpgsql security definer
set search_path=pg_catalog,auth,famille_private
as $$
begin
  if p_user_id is null or p_session_id is null or p_app_code not in ('kiosko','bootik','zipple','naxa_services','cotiz','loyable','naxa_hotel','campus237','naxa_security','grillad') then
    raise exception 'invalid_session_binding' using errcode='22023';
  end if;
  update auth.sessions set tag='famille:'||p_app_code where id=p_session_id and user_id=p_user_id;
  return found;
end $$;
revoke all on function famille_private.bind_auth_session(uuid,uuid,text) from public,anon,authenticated;
grant execute on function famille_private.bind_auth_session(uuid,uuid,text) to service_role;

-- The signed Supabase session id is bound server-side to one app and one active device.
-- Revoking/evicting the device makes current_app_id() NULL on the very next RLS check.
create or replace function famille_core.current_app_id()
returns uuid language sql stable security definer
set search_path=pg_catalog,famille_core,famille_private,auth
as $$
  select a.id
  from auth.sessions s
  join famille_core.applications a on s.tag='famille:'||a.code
  where s.id = case when coalesce(auth.jwt()->>'session_id','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                    then (auth.jwt()->>'session_id')::uuid else null end
    and s.user_id=auth.uid()
    and exists (
      select 1 from famille_private.account_devices d
      where d.auth_session_id=s.id and d.user_id=s.user_id
        and d.app_code=a.code and d.status='active'
    )
  limit 1
$$;
revoke all on function famille_core.current_app_id() from public,anon,authenticated;
grant execute on function famille_core.current_app_id() to service_role;

revoke all on all functions in schema famille_private from public,anon,authenticated;
grant execute on function famille_private.register_device(uuid,text,uuid,uuid,text,uuid,text,text) to service_role;
grant execute on function famille_private.record_login_failure(text,text) to service_role;
grant execute on function famille_private.login_is_locked(text,text) to service_role;
grant execute on function famille_private.clear_login_failures(text,text) to service_role;
grant execute on function famille_private.revoke_device(uuid,uuid) to service_role;
commit;
