-- DRAFT ONLY: optional promoter-owned commission configuration. No production activation.
-- Depends on v1-v8 and bound session identity; no ledger or payment mutation.
begin;
create table if not exists public.ns_automatic_commission_settings (
 org_id uuid primary key references public.ns_organizations(id) on delete restrict,
 enabled boolean not null default false,
 revision bigint not null default 0 check(revision>=0),
 updated_by uuid not null,
 updated_at timestamptz not null default now(),
 foreign key(updated_by,org_id) references public.ns_members(id,org_id) on delete restrict
);
alter table public.ns_automatic_commission_settings enable row level security;
revoke all on public.ns_automatic_commission_settings from public, anon, authenticated;
grant all on public.ns_automatic_commission_settings to service_role;

-- The approved v7 policy is immutable (including these new scope fields).
alter table public.ns_commission_policy_versions
 add column if not exists automatic_scope boolean not null default false,
 add column if not exists member_id uuid,
 add column if not exists service_id uuid references public.ns_services(id) on delete restrict,
 add column if not exists activity_profile text;
alter table public.ns_commission_policy_versions add constraint ns_commission_policy_member_org_fk
 foreign key(member_id,org_id) references public.ns_members(id,org_id) on delete restrict;
alter table public.ns_commission_policy_versions add constraint ns_commission_policy_automatic_fields
 check(not automatic_scope or (
 (method='percent_bps' and rate_bps is not null and rate_bps between 0 and 10000 and fixed_amount_xaf is null)
 or (method='fixed_xaf' and rate_bps is null and fixed_amount_xaf is not null and fixed_amount_xaf>0)
 ));
-- Remove broad policy visibility; compensation rules are confidential.
drop policy if exists ns_commission_policy_versions_select on public.ns_commission_policy_versions;
create policy ns_commission_policy_versions_select on public.ns_commission_policy_versions
 for select to authenticated using(public.ns_can_manage_org(org_id));
revoke insert,update,delete on public.ns_commission_policy_versions from authenticated,anon;

create or replace function public.ns_read_automatic_commission_settings(p_org uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare v public.ns_automatic_commission_settings%rowtype;
begin
 if auth.uid() is null or not public.ns_can_manage_org(p_org) or not exists(select 1 from public.ns_organizations where id=p_org and status='active') then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 select * into v from public.ns_automatic_commission_settings where org_id=p_org;
 return jsonb_build_object('enabled',coalesce(v.enabled,false),'revision',coalesce(v.revision,0));
end $fn$;
create or replace function public.ns_set_automatic_commission_settings(p_org uuid,p_enabled boolean,p_expected_revision bigint)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare v public.ns_automatic_commission_settings%rowtype; actor uuid;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 if p_enabled is null or p_expected_revision is null or p_expected_revision<0 then raise exception 'NS_COMMISSION_CONFIG_INVALID'; end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 select * into v from public.ns_automatic_commission_settings where org_id=p_org;
 if coalesce(v.revision,0)<>p_expected_revision then raise exception 'NS_COMMISSION_CONFIG_CONFLICT'; end if;
 if coalesce(v.enabled,false)=p_enabled then return jsonb_build_object('enabled',p_enabled,'revision',coalesce(v.revision,0)); end if;
 insert into public.ns_automatic_commission_settings(org_id,enabled,revision,updated_by)
 values(p_org,p_enabled,p_expected_revision+1,actor)
 on conflict(org_id) do update set enabled=excluded.enabled,revision=excluded.revision,updated_by=excluded.updated_by,updated_at=now()
 returning * into v;
 return jsonb_build_object('enabled',v.enabled,'revision',v.revision);
end $fn$;

-- Explicit approval, immutable policy version and exact retry. Overlapping versions
-- are rejected rather than guessing which policy takes precedence.
create or replace function public.ns_publish_automatic_commission_policy(
 p_id uuid,p_org uuid,p_site uuid,p_member uuid,p_service uuid,p_activity text,p_code text,p_version integer,
 p_method text,p_rate integer,p_fixed bigint,p_from date,p_until date,p_reference text
) returns uuid language plpgsql security definer set search_path = '' as $fn$
declare actor uuid; v public.ns_commission_policy_versions%rowtype; profile text;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 select activity_profile into profile from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 if p_id is null or p_version is null or p_version<1 or length(trim(coalesce(p_code,''))) not between 2 and 80
 or length(trim(coalesce(p_reference,''))) not between 8 and 500 or p_from is null or (p_until is not null and p_until<p_from)
 or not coalesce((p_method='percent_bps' and p_rate between 0 and 10000 and p_fixed is null) or (p_method='fixed_xaf' and p_rate is null and p_fixed between 1 and 9007199254740991),false)
 then raise exception 'NS_COMMISSION_POLICY_INVALID'; end if;
 if (p_site is not null and not exists(select 1 from public.ns_sites where id=p_site and org_id=p_org and status='active'))
 or (p_member is not null and not exists(select 1 from public.ns_members m where m.id=p_member and m.org_id=p_org and m.status='active' and (p_site is null or exists(select 1 from public.ns_member_scopes s where s.org_id=p_org and s.member_id=m.id and (s.can_operate or s.can_manage) and (s.scope_type='organization' or s.site_id=p_site)))))
 or (p_service is not null and not exists(select 1 from public.ns_services s where s.id=p_service and s.org_id=p_org and s.active and (s.site_id is null or s.site_id=p_site)))
 or (p_activity is not null and p_activity is distinct from profile) then raise exception 'NS_COMMISSION_POLICY_SCOPE'; end if;
 select * into v from public.ns_commission_policy_versions where id=p_id;
 if found then
  if v.org_id=p_org and v.automatic_scope and v.status='approved' and v.site_id is not distinct from p_site
  and v.member_id is not distinct from p_member and v.service_id is not distinct from p_service and v.activity_profile is not distinct from p_activity
  and v.policy_code=trim(p_code) and v.version=p_version and v.method=p_method and v.rate_bps is not distinct from p_rate
  and v.fixed_amount_xaf is not distinct from p_fixed and v.effective_from=p_from and v.effective_until is not distinct from p_until
  and v.source_reference=trim(p_reference) then return v.id; end if;
  raise exception 'NS_COMMISSION_POLICY_ID_CONFLICT';
 end if;
 if exists(select 1 from public.ns_commission_policy_versions p where p.org_id=p_org and p.automatic_scope and p.status='approved'
  and (p.site_id is null or p_site is null or p.site_id=p_site)
  and (p.member_id is null or p_member is null or p.member_id=p_member)
  and (p.service_id is null or p_service is null or p.service_id=p_service)
  and (p.activity_profile is null or p_activity is null or p.activity_profile=p_activity)
  and daterange(p.effective_from,p.effective_until,'[]') && daterange(p_from,p_until,'[]'))
 then raise exception 'NS_COMMISSION_POLICY_AMBIGUOUS'; end if;
 insert into public.ns_commission_policy_versions(id,org_id,site_id,member_id,service_id,activity_profile,automatic_scope,policy_code,version,method,rate_bps,fixed_amount_xaf,effective_from,effective_until,status,source_reference,approved_by,approved_at,created_by)
 values(p_id,p_org,p_site,p_member,p_service,p_activity,true,trim(p_code),p_version,p_method,p_rate,p_fixed,p_from,p_until,'approved',trim(p_reference),actor,now(),actor);
 return p_id;
end $fn$;
-- Retirement never changes approved terms, never deletes history.
create or replace function public.ns_retire_automatic_commission_policy(p_org uuid,p_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $fn$
begin
 if auth.uid() is null or not public.ns_can_manage_org(p_org) then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_CONFIG_FORBIDDEN'; end if;
 update public.ns_commission_policy_versions set status='retired' where id=p_id and org_id=p_org and automatic_scope and status='approved';
 if found then return true; end if;
 return exists(select 1 from public.ns_commission_policy_versions where id=p_id and org_id=p_org and automatic_scope and status='retired');
end $fn$;
revoke all on function public.ns_read_automatic_commission_settings(uuid),public.ns_set_automatic_commission_settings(uuid,boolean,bigint),public.ns_publish_automatic_commission_policy(uuid,uuid,uuid,uuid,uuid,text,text,integer,text,integer,bigint,date,date,text),public.ns_retire_automatic_commission_policy(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_read_automatic_commission_settings(uuid),public.ns_set_automatic_commission_settings(uuid,boolean,bigint),public.ns_publish_automatic_commission_policy(uuid,uuid,uuid,uuid,uuid,text,text,integer,text,integer,bigint,date,date,text),public.ns_retire_automatic_commission_policy(uuid,uuid) to authenticated;
rollback;
