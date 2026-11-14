-- CANDIDATE ONLY — contextualize every authorization helper by signed app claim.
-- Requires 0001 + 0002; test only on an isolated PostgreSQL 17 database.
-- NEVER apply to NAXA Supabase before server-side Auth claim issuance is implemented.
begin;

create or replace function famille_core.current_app_id()
returns uuid language plpgsql stable security invoker
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
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id() is not null and exists (
    select 1 from famille_core.memberships m
    join famille_core.role_assignments ra
      on ra.membership_id=m.id and ra.app_id=m.app_id and ra.organization_id=m.organization_id
    join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
    where m.user_id=auth.uid() and m.app_id=famille_core.current_app_id()
      and m.status='active' and ra.status='active' and ra.starts_at<=now()
      and (ra.expires_at is null or ra.expires_at>now()) and rc.is_platform_admin
  );
$$;

create or replace function famille_core.outlet_ids()
returns setof uuid language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select distinct l.id from famille_core.locations l
  join famille_core.memberships m on m.organization_id=l.organization_id
    and m.user_id=auth.uid() and m.app_id=famille_core.current_app_id() and m.status='active'
  join famille_core.organization_apps oa on oa.organization_id=m.organization_id
    and oa.app_id=m.app_id and oa.status='active'
  join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id
    and ra.organization_id=m.organization_id and ra.status='active'
    and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now())
  join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
  where famille_core.current_app_id() is not null and l.status='active'
    and famille_core.subscription_allows_workspace(l.organization_id,m.app_id)
    and ((rc.scope_type='organization' and ra.location_id is null)
      or (rc.scope_type='location' and ra.location_id=l.id));
$$;

create or replace function famille_core.has_organization_access(p_org uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id() is not null and exists (
    select 1 from famille_core.memberships m
    join famille_core.role_assignments ra on ra.membership_id=m.id
      and ra.app_id=m.app_id and ra.organization_id=m.organization_id
    join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
    where m.user_id=auth.uid() and m.organization_id=p_org
      and m.app_id=famille_core.current_app_id() and m.status='active'
      and ra.status='active' and ra.starts_at<=now()
      and (ra.expires_at is null or ra.expires_at>now())
      and rc.scope_type='organization' and ra.location_id is null
      and famille_core.subscription_allows_workspace(p_org,m.app_id)
  );
$;

create or replace function famille_core.subscription_allows_workspace(p_org uuid,p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core
as $$
  select famille_core.current_app_id()=p_app and exists (
    select 1 from famille_core.subscriptions s
    where s.organization_id=p_org and s.app_id=p_app
      and ((s.status='active' and (s.starts_at is null or s.starts_at<=now())
        and (s.ends_at is null or s.ends_at>=now()))
        or (s.status='past_due' and s.grace_until is not null and s.grace_until>=now()))
  );
$$;

create or replace function famille_core.can_access_outlet(p_org uuid,p_app uuid,p_loc uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id()=p_app and exists (
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
$$;

create or replace function famille_core.can_read_transaction_details(p_org uuid,p_app uuid,p_loc uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id()=p_app and not famille_core.is_admin()
    and famille_core.subscription_allows_workspace(p_org,p_app)
    and famille_core.can_access_outlet(p_org,p_app,p_loc)
    and exists (
      select 1 from famille_core.memberships m
      join famille_core.role_assignments ra on ra.membership_id=m.id
        and ra.app_id=m.app_id and ra.organization_id=m.organization_id
      join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
      where m.user_id=auth.uid() and m.organization_id=p_org and m.app_id=p_app
        and m.status='active' and ra.status='active' and ra.starts_at<=now()
        and (ra.expires_at is null or ra.expires_at>now())
        and rc.can_read_transaction_details and not rc.is_platform_admin
        and not rc.is_commercial and not rc.is_partner
        and ((rc.scope_type='organization' and ra.location_id is null)
          or (rc.scope_type='location' and ra.location_id=p_loc))
    );
$$;

create or replace function famille_core.can_write_transactions(p_org uuid,p_app uuid,p_loc uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id()=p_app and not famille_core.is_admin()
    and famille_core.subscription_allows_workspace(p_org,p_app)
    and famille_core.can_access_outlet(p_org,p_app,p_loc)
    and exists (
      select 1 from famille_core.memberships m
      join famille_core.role_assignments ra on ra.membership_id=m.id
        and ra.app_id=m.app_id and ra.organization_id=m.organization_id
      join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
      where m.user_id=auth.uid() and m.organization_id=p_org and m.app_id=p_app
        and m.status='active' and ra.status='active' and ra.starts_at<=now()
        and (ra.expires_at is null or ra.expires_at>now())
        and rc.can_write_transactions and not rc.is_platform_admin
        and not rc.is_commercial and not rc.is_partner
        and ((rc.scope_type='organization' and ra.location_id is null)
          or (rc.scope_type='location' and ra.location_id=p_loc))
    );
$$;

create or replace function famille_core.can_read_financial_aggregates(p_org uuid,p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id()=p_app and (
    famille_core.is_admin() or (
      famille_core.subscription_allows_workspace(p_org,p_app) and exists (
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
    )
  );
$$;

create or replace function famille_core.can_manage_billing(p_org uuid,p_app uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select famille_core.current_app_id()=p_app and exists (
    select 1 from famille_core.memberships m
    join famille_core.role_assignments ra on ra.membership_id=m.id
      and ra.app_id=m.app_id and ra.organization_id=m.organization_id
    join famille_core.role_catalog rc on rc.app_id=ra.app_id and rc.role_code=ra.role_code
    where m.user_id=auth.uid() and m.organization_id=p_org and m.app_id=p_app
      and m.status='active' and ra.status='active' and ra.starts_at<=now()
      and (ra.expires_at is null or ra.expires_at>now())
      and rc.can_manage_billing and rc.scope_type='organization' and ra.location_id is null
  );
$$;

create or replace function famille_core.can_manage_billing_for_intent(p_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, famille_core, auth
as $$
  select exists (
    select 1 from famille_core.payment_intents pi
    join famille_core.subscriptions s on s.id=pi.subscription_id
    where pi.id=p_id and s.app_id=famille_core.current_app_id()
      and famille_core.can_manage_billing(s.organization_id,s.app_id)
  );
$$;

create or replace function famille_core.submit_payment_intent(p_id uuid)
returns boolean language plpgsql security definer
set search_path = pg_catalog, famille_core, auth
as $$
declare v_status text;
begin
  if auth.uid() is null or famille_core.current_app_id() is null
     or not famille_core.can_manage_billing_for_intent(p_id) then
    raise exception 'not_authorized' using errcode='42501';
  end if;
  select status into v_status from famille_core.payment_intents where id=p_id for update;
  if not found then raise exception 'payment_intent_not_found' using errcode='P0002'; end if;
  if v_status='submitted' then return true; end if;
  if v_status not in ('pending','rejected') then
    raise exception 'payment_intent_not_submittable' using errcode='22023';
  end if;
  update famille_core.payment_intents set status='submitted' where id=p_id;
  return true;
end;
$$;

-- Remove the broad 0002 EXECUTE grant; expose only helpers used by RLS/RPC.
revoke all on all functions in schema famille_core from public, anon, authenticated;
grant execute on function famille_core.current_app_id() to authenticated;
grant execute on function famille_core.is_admin() to authenticated;
grant execute on function famille_core.outlet_ids() to authenticated;
grant execute on function famille_core.has_organization_access(uuid) to authenticated;
grant execute on function famille_core.can_read_transaction_details(uuid,uuid,uuid) to authenticated;
grant execute on function famille_core.can_write_transactions(uuid,uuid,uuid) to authenticated;
grant execute on function famille_core.can_read_financial_aggregates(uuid,uuid) to authenticated;
grant execute on function famille_core.can_manage_billing(uuid,uuid) to authenticated;
grant execute on function famille_core.can_manage_billing_for_intent(uuid) to authenticated;
grant execute on function famille_core.submit_payment_intent(uuid) to authenticated;

comment on function famille_core.current_app_id() is
'Reads only signed app_metadata.active_app_id. NULL/malformed claims fail closed; never trust user_metadata or client GUC.';
commit;
