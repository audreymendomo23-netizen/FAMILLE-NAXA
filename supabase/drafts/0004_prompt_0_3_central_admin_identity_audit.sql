-- CANDIDATE ONLY — Prompt 0.3 governance decisions.
-- Requires isolated test chain: 0001 draft + 0002 RLS + 0003 contextual RLS.
-- Never apply to the shared NAXA Supabase project without a separately approved additive migration.
begin;

-- One dedicated central identity; no app membership is required.
create table if not exists famille_core.family_admins (
  user_id uuid primary key references auth.users(id) on delete restrict,
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  check ((status='active' and revoked_at is null) or status<>'active')
);
create unique index if not exists uq_famille_single_active_central_admin
  on famille_core.family_admins(status) where status='active';
alter table famille_core.family_admins enable row level security;
revoke all on famille_core.family_admins from public, anon, authenticated;

-- App membership alone is insufficient: every ordinary account must hold
-- exactly one granted app access record and the signed claim must match it.
create or replace function famille_core.has_app_access(p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $access$
  select exists (
    select 1 from famille_core.client_app_access ca
    where ca.user_id=auth.uid() and ca.app_id=p_app and ca.status='granted'
  );
$access$;
revoke all on function famille_core.has_app_access(uuid) from public,anon,authenticated;

-- Expose only the caller's access to the signed active application.
-- The parameterized helper stays private to SECURITY DEFINER authorization routines.
create or replace function famille_core.has_current_app_access()
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $current_access$
  select famille_core.current_app_id() is not null
    and famille_core.has_app_access(famille_core.current_app_id());
$current_access$;
revoke all on function famille_core.has_current_app_access() from public,anon,authenticated;
grant execute on function famille_core.has_current_app_access() to authenticated;

create or replace function famille_core.outlet_ids()
returns setof uuid language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $scope$
  select distinct l.id from famille_core.locations l
  join famille_core.memberships m on m.organization_id=l.organization_id
    and m.user_id=auth.uid() and m.app_id=famille_core.current_app_id() and m.status='active'
  join famille_core.organization_apps oa on oa.organization_id=m.organization_id
    and oa.app_id=m.app_id and oa.status='active'
  join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id
    and ra.organization_id=m.organization_id and ra.status='active'
    and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now())
  join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
  where famille_core.has_app_access(m.app_id) and l.status='active'
    and famille_core.subscription_allows_workspace(l.organization_id,m.app_id)
    and ((rc.scope_type='organization' and ra.location_id is null)
      or (rc.scope_type='location' and ra.location_id=l.id));
$scope$;

create or replace function famille_core.has_organization_access(p_org uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $scope$
  select exists (
    select 1 from famille_core.memberships m
    join famille_core.role_assignments ra on ra.membership_id=m.id
      and ra.app_id=m.app_id and ra.organization_id=m.organization_id
    join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
    where m.user_id=auth.uid() and m.organization_id=p_org
      and m.app_id=famille_core.current_app_id() and m.status='active'
      and famille_core.has_app_access(m.app_id)
      and ra.status='active' and ra.starts_at<=now()
      and (ra.expires_at is null or ra.expires_at>now())
      and rc.scope_type='organization' and ra.location_id is null
      and famille_core.subscription_allows_workspace(p_org,m.app_id)
  );
$scope$;

create or replace function famille_core.subscription_allows_workspace(p_org uuid,p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $scope$
  select famille_core.current_app_id()=p_app and famille_core.has_app_access(p_app) and exists (
    select 1 from famille_core.subscriptions s
    where s.organization_id=p_org and s.app_id=p_app
      and ((s.status='active' and (s.starts_at is null or s.starts_at<=now())
        and (s.ends_at is null or s.ends_at>=now()))
        or (s.status='past_due' and s.grace_until is not null and s.grace_until>=now()))
  );
$scope$;

create or replace function famille_core.can_access_outlet(p_org uuid,p_app uuid,p_loc uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $scope$
  select famille_core.current_app_id()=p_app and famille_core.has_app_access(p_app) and exists (
    select 1 from famille_core.locations l
    join famille_core.memberships m on m.organization_id=l.organization_id
      and m.app_id=p_app and m.user_id=auth.uid() and m.status='active'
    join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id
      and ra.organization_id=m.organization_id and ra.status='active'
      and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now())
    join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
    join famille_core.organization_apps oa on oa.organization_id=m.organization_id
      and oa.app_id=m.app_id and oa.status='active'
    where l.id=p_loc and l.organization_id=p_org and l.status='active'
      and ((rc.scope_type='organization' and ra.location_id is null)
        or (rc.scope_type='location' and ra.location_id=l.id))
  );
$scope$;

-- A normal account belongs to exactly one platform. The central admin is separate
-- and is intentionally not represented in client_app_access.
create unique index if not exists uq_famille_one_platform_per_identity
  on famille_core.client_app_access(user_id);
update famille_core.role_catalog set can_read_transaction_details=false,
  can_write_transactions=false,can_read_financial_aggregates=false,
  can_manage_billing=false,is_platform_admin=false
where role_code='platform_admin';

create or replace function famille_core.can_manage_billing(p_org uuid,p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $billing$
  select famille_core.current_app_id()=p_app and famille_core.has_app_access(p_app) and exists (
    select 1 from famille_core.memberships m
    join famille_core.role_assignments ra on ra.membership_id=m.id
      and ra.app_id=m.app_id and ra.organization_id=m.organization_id
    join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
    where m.user_id=auth.uid() and m.organization_id=p_org and m.app_id=p_app
      and m.status='active' and ra.status='active' and ra.starts_at<=now()
      and (ra.expires_at is null or ra.expires_at>now())
      and rc.can_manage_billing and rc.scope_type='organization' and ra.location_id is null
  );
$billing$;

create or replace function famille_core.is_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select exists (
    select 1 from famille_core.family_admins fa
    where fa.user_id=auth.uid() and fa.status='active'
      and fa.revoked_at is null
  );
$$;

-- Central admin may inspect platform/account/billing metadata across all ten apps.
-- Personal profile content, support-ticket text, notifications and business
-- transaction rows remain outside this metadata privilege.
drop policy if exists identities_read_self on famille_core.identities;
create policy identities_read_self on famille_core.identities
  for select to authenticated using (user_id=auth.uid());

drop policy if exists app_installations_read_scope on famille_core.app_installations;
create policy app_installations_read_scope on famille_core.app_installations
  for select to authenticated
  using (exists (
    select 1 from famille_core.devices d
    where d.id=device_id and d.user_id=auth.uid()
  ));

drop policy if exists support_tickets_read_self on famille_core.support_tickets;
create policy support_tickets_read_self on famille_core.support_tickets
  for select to authenticated using (user_id=auth.uid());

drop policy if exists audit_events_read_scope on famille_core.audit_events;
create policy audit_events_read_scope on famille_core.audit_events
  for select to authenticated
  using (famille_core.is_admin() or actor_id=auth.uid()
    or (organization_id is not null and famille_core.has_organization_access(organization_id)));

-- Keep the central admin's aggregate visibility cross-platform, never row-level
-- transaction visibility. The detailed transaction helper explicitly denies admins.
create or replace function famille_core.can_read_financial_aggregates(p_org uuid,p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.is_admin() or (
    famille_core.current_app_id()=p_app
    and famille_core.subscription_allows_workspace(p_org,p_app)
    and exists (
      select 1 from famille_core.memberships m
      join famille_core.role_assignments ra on ra.membership_id=m.id
        and ra.app_id=m.app_id and ra.organization_id=m.organization_id
      join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
      where m.user_id=auth.uid() and m.organization_id=p_org and m.app_id=p_app
        and famille_core.has_app_access(p_app)
        and m.status='active' and ra.status='active' and ra.starts_at<=now()
        and (ra.expires_at is null or ra.expires_at>now())
        and rc.can_read_financial_aggregates and not rc.is_commercial
        and not rc.is_partner and not rc.is_platform_admin
        and rc.scope_type='organization' and ra.location_id is null
    )
  );
$$;

-- Append-only audit trail for authenticated central-admin mutations routed through
-- approved server-side RPCs. Only table/operation/scope metadata is captured.
create or replace function famille_core.reject_audit_event_mutation()
returns trigger language plpgsql security definer
set search_path = pg_catalog, famille_core
as $audit$
begin
  raise exception 'audit_events_are_append_only' using errcode='55000';
end;
$audit$;
create trigger famille_audit_events_append_only
  before update or delete on famille_core.audit_events
  for each row execute function famille_core.reject_audit_event_mutation();
revoke all on function famille_core.reject_audit_event_mutation() from public,anon,authenticated;

create or replace function famille_core.audit_central_admin_mutation()
returns trigger language plpgsql security definer
set search_path = pg_catalog, famille_core, auth
as $$
declare
  v_row jsonb;
  v_app uuid;
  v_org uuid;
  v_loc uuid;
  v_id text;
begin
  if not famille_core.is_admin() then
    if TG_OP='DELETE' then return OLD; else return NEW; end if;
  end if;
  v_row := case when TG_OP='DELETE' then to_jsonb(OLD) else to_jsonb(NEW) end;
  v_app := coalesce(nullif(v_row->>'app_id','')::uuid,
    case when TG_TABLE_NAME='applications' then nullif(v_row->>'id','')::uuid else null end);
  v_org := nullif(v_row->>'organization_id','')::uuid;
  v_loc := nullif(v_row->>'location_id','')::uuid;
  v_id := coalesce(v_row->>'id',v_row->>'user_id',v_row->>'code');
  insert into famille_core.audit_events(app_id,organization_id,location_id,actor_id,
    action_code,entity_type,entity_id,metadata)
  values(v_app,v_org,v_loc,auth.uid(),lower(TG_OP),TG_TABLE_NAME,v_id,
    jsonb_build_object('source','central_admin_audit_trigger','table',TG_TABLE_NAME,'operation',TG_OP));
  if TG_OP='DELETE' then return OLD; else return NEW; end if;
end;
$$;

revoke all on function famille_core.audit_central_admin_mutation() from public,anon,authenticated;

do $$
declare t text;
begin
  foreach t in array array[
    'applications','organizations','organization_apps','locations','memberships',
    'role_catalog','role_assignments','client_app_access','devices','app_installations',
    'subscriptions','plans','app_versions','payment_parser_rules'
  ] loop
    execute format('drop trigger if exists audit_central_admin_%I on famille_core.%I',t,t);
    execute format('create trigger audit_central_admin_%I after insert or update or delete on famille_core.%I for each row execute function famille_core.audit_central_admin_mutation()',t,t);
  end loop;
end $$;

revoke all on function famille_core.is_admin() from public,anon,authenticated;
grant execute on function famille_core.is_admin() to authenticated;
revoke all on function famille_core.has_app_access(uuid) from public,anon,authenticated;
revoke all on function famille_core.can_read_financial_aggregates(uuid,uuid) from public,anon,authenticated;
revoke all on function famille_core.can_manage_billing(uuid,uuid) from public,anon,authenticated;
grant execute on function famille_core.can_manage_billing(uuid,uuid) to authenticated;
grant execute on function famille_core.can_read_financial_aggregates(uuid,uuid) to authenticated;

comment on table famille_core.family_admins is
'Exactly one central Famille administrator identity; metadata-only cross-platform access. Not an app membership.';
comment on index famille_core.uq_famille_one_platform_per_identity is
'Enforces one normal user identity per platform. Central administrator is provisioned separately.';
commit;
