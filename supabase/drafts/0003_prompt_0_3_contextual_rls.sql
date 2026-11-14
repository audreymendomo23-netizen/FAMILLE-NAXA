-- CANDIDATE ONLY — requires 0001/0002 in an isolated PostgreSQL 17 test DB.
-- No application to Supabase NAXA. Fail closed unless a trusted server-issued
-- app_metadata.active_app_id claim is present in the access token.
begin;

create or replace function famille_core.current_app_id()
returns uuid
language plpgsql stable security invoker
set search_path = pg_catalog, auth
as $$
declare v text;
begin
  v := auth.jwt() -> 'app_metadata' ->> 'active_app_id';
  if v is null or v = '' then return null; end if;
  begin return v::uuid;
  exception when invalid_text_representation then return null;
  end;
end;
$$;

create or replace function famille_core.is_admin()
returns boolean
language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id() is not null and exists (
    select 1
    from famille_core.memberships m
    join famille_core.role_assignments ra
      on ra.membership_id = m.id and ra.app_id = m.app_id
     and ra.organization_id = m.organization_id
    join famille_core.role_catalog rc
      on rc.app_id = ra.app_id and rc.role_code = ra.role_code
    where m.user_id = auth.uid()
      and m.app_id = famille_core.current_app_id()
      and m.status = 'active'
      and ra.status = 'active'
      and ra.starts_at <= now()
      and (ra.expires_at is null or ra.expires_at > now())
      and rc.is_platform_admin
  );
$$;

create or replace function famille_core.outlet_ids()
returns setof uuid
language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select distinct l.id
  from famille_core.locations l
  join famille_core.memberships m
    on m.organization_id = l.organization_id
   and m.user_id = auth.uid()
   and m.app_id = famille_core.current_app_id()
   and m.status = 'active'
  join famille_core.role_assignments ra
    on ra.membership_id = m.id
   and ra.app_id = m.app_id
   and ra.organization_id = m.organization_id
   and ra.status = 'active'
   and ra.starts_at <= now()
   and (ra.expires_at is null or ra.expires_at > now())
  join famille_core.role_catalog rc
    on rc.app_id = ra.app_id and rc.role_code = ra.role_code
  where famille_core.current_app_id() is not null
    and l.status = 'active'
    and ((rc.scope_type = 'organization' and ra.location_id is null)
      or (rc.scope_type = 'location' and ra.location_id = l.id));
$$;

create or replace function famille_core.has_organization_access(p_org uuid)
returns boolean
language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id() is not null and exists (
    select 1
    from famille_core.memberships m
    join famille_core.role_assignments ra
      on ra.membership_id = m.id and ra.app_id = m.app_id
     and ra.organization_id = m.organization_id
    join famille_core.role_catalog rc
      on rc.app_id = ra.app_id and rc.role_code = ra.role_code
    where m.user_id = auth.uid()
      and m.organization_id = p_org
      and m.app_id = famille_core.current_app_id()
      and m.status = 'active'
      and ra.status = 'active'
      and ra.starts_at <= now()
      and (ra.expires_at is null or ra.expires_at > now())
      and ((rc.scope_type = 'organization' and ra.location_id is null)
        or (rc.scope_type = 'location' and ra.location_id is not null))
  );
$$;

-- Existing policy expressions now resolve app scope from the signed JWT claim.
-- Explicit, minimal EXECUTE allow-list: only helpers called directly by RLS.
revoke all on function famille_core.current_app_id() from public, anon, authenticated;
revoke all on function famille_core.is_admin() from public, anon, authenticated;
revoke all on function famille_core.outlet_ids() from public, anon, authenticated;
revoke all on function famille_core.has_organization_access(uuid) from public, anon, authenticated;
grant execute on function famille_core.current_app_id() to authenticated;
grant execute on function famille_core.is_admin() to authenticated;
grant execute on function famille_core.outlet_ids() to authenticated;
grant execute on function famille_core.has_organization_access(uuid) to authenticated;

-- Fail closed for clients lacking the trusted claim. This is an explicit
-- deployment prerequisite: a trusted Auth hook/server must issue app_metadata.active_app_id.
comment on function famille_core.current_app_id() is
'Returns only the trusted app_metadata.active_app_id claim; NULL fails closed. Never source app scope from user_metadata or a client-set GUC.';
commit;
