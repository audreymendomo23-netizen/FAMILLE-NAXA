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

-- A normal account belongs to exactly one platform. The central admin is separate
-- and is intentionally not represented in client_app_access.
create unique index if not exists uq_famille_one_platform_per_identity
  on famille_core.client_app_access(user_id);

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
  v_app := nullif(v_row->>'app_id','')::uuid;
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
    'organizations','organization_apps','locations','memberships',
    'role_catalog','role_assignments','client_app_access','devices','app_installations',
    'subscriptions','plans','app_versions','payment_parser_rules'
  ] loop
    execute format('drop trigger if exists audit_central_admin_%I on famille_core.%I',t,t);
    execute format('create trigger audit_central_admin_%I after insert or update or delete on famille_core.%I for each row execute function famille_core.audit_central_admin_mutation()',t,t);
  end loop;
end $$;

revoke all on function famille_core.is_admin() from public,anon,authenticated;
grant execute on function famille_core.is_admin() to authenticated;
revoke all on function famille_core.can_read_financial_aggregates(uuid,uuid) from public,anon,authenticated;
grant execute on function famille_core.can_read_financial_aggregates(uuid,uuid) to authenticated;

comment on table famille_core.family_admins is
'Exactly one central Famille administrator identity; metadata-only cross-platform access. Not an app membership.';
comment on index famille_core.uq_famille_one_platform_per_identity is
'Enforces one normal user identity per platform. Central administrator is provisioned separately.';
commit;
