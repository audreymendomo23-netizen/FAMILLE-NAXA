-- CANDIDATE ONLY. Do not apply to shared/production database.
-- Requires the existing NAXA SERVICES, famille_core and NAXA SECURITY schemas.
-- Explicit mappings must be approved/provisioned by a trusted operator; no auto matching.
begin;
create table public.ns_v1_security_site_links (
  org_id uuid not null, site_id uuid not null,
  security_org_id uuid not null, security_site_id uuid not null,
  primary key (org_id,site_id),
  foreign key(site_id,org_id) references public.ns_sites(id,org_id),
  foreign key(security_org_id,security_site_id) references public.sec_sites(organization_id,id)
);
alter table public.ns_v1_security_site_links enable row level security;
revoke all on public.ns_v1_security_site_links from public,anon,authenticated;
grant select on public.ns_v1_security_site_links to authenticated;
create policy ns_v1_security_link_read on public.ns_v1_security_site_links
for select to authenticated using (
  public.ns_current_account_id() is not null
  and public.ns_can_access_site(org_id,site_id)
  and exists(select 1 from public.ns_sites s where s.id=ns_v1_security_site_links.site_id and s.org_id=ns_v1_security_site_links.org_id and s.status='active')
  and exists(select 1 from public.sec_sites s where s.id=ns_v1_security_site_links.security_site_id and s.organization_id=ns_v1_security_site_links.security_org_id and s.active)
  and exists(select 1 from public.sec_site_memberships m where m.organization_id=ns_v1_security_site_links.security_org_id and m.site_id=ns_v1_security_site_links.security_site_id and m.user_id=auth.uid() and m.active)
);
create function public.ns_v1_security_snapshot(p_org uuid,p_site uuid)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare l public.ns_v1_security_site_links%rowtype;
begin
  if auth.uid() is null or public.ns_current_account_id() is null
     or not public.ns_can_access_site(p_org,p_site) then
    raise exception 'SECURITY_SCOPE_DENIED' using errcode='42501';
  end if;
  select * into l from public.ns_v1_security_site_links where org_id=p_org and site_id=p_site;
  if not found then return jsonb_build_object('state','unavailable'); end if;
  return jsonb_build_object('state','linked',
    'devices',coalesce((select jsonb_agg(to_jsonb(d)) from (
      select id,label,kind,observed_at from public.sec_devices
      where organization_id=l.security_org_id and site_id=l.security_site_id
      order by id limit 100)d),'[]'::jsonb),
    'incidents',coalesce((select jsonb_agg(to_jsonb(i)) from (
      select id,device_id,subject,priority,state,occurred_at from public.sec_incidents
      where organization_id=l.security_org_id and site_id=l.security_site_id
      order by occurred_at desc,id limit 100)i),'[]'::jsonb));
end $$;
revoke all on function public.ns_v1_security_snapshot(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_v1_security_snapshot(uuid,uuid) to authenticated;

create table public.ns_v1_core_org_links (
  org_id uuid primary key references public.ns_organizations(id),
  core_org_id uuid not null unique references famille_core.organizations(id)
);
alter table public.ns_v1_core_org_links enable row level security;
revoke all on public.ns_v1_core_org_links from public,anon,authenticated;
grant select on public.ns_v1_core_org_links to authenticated;
create policy ns_v1_core_org_link_read on public.ns_v1_core_org_links
for select to authenticated using (
  public.ns_current_account_id() is not null and public.ns_is_org_member(org_id)
  and exists (select 1 from famille_core.memberships m join famille_core.applications a on a.id=m.app_id
    where m.user_id=auth.uid() and m.organization_id=core_org_id and m.status='active'
    and a.code='naxa_services' and a.status='active')
  and exists (select 1 from famille_core.organizations o where o.id=core_org_id and o.status='active' and o.deleted_at is null)
);
-- Reuse the canonical, confirmed Services request and the existing central ticket.
-- No fabricated conversation, actor, organization, role or new ticket per retry.
create function public.ns_v1_forward_support_ticket(p_org uuid,p_site uuid,p_request uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare q public.ns_support_requests%rowtype; l public.ns_v1_core_org_links%rowtype; a uuid; t famille_core.support_tickets%rowtype;
begin
  if auth.uid() is null or public.ns_current_account_id() is null
     or not public.ns_can_access_site(p_org,p_site) then
    raise exception 'SUPPORT_SCOPE_DENIED' using errcode='42501';
  end if;
  select * into q from public.ns_support_requests where id=p_request and org_id=p_org and site_id=p_site
    and created_by=public.ns_current_member_id(p_org);
  if not found then raise exception 'SUPPORT_REQUEST_DENIED' using errcode='42501'; end if;
  select * into l from public.ns_v1_core_org_links where org_id=p_org;
  if not found then return jsonb_build_object('state','unavailable'); end if;
  select id into a from famille_core.applications where code='naxa_services' and status='active';
  if a is null then return jsonb_build_object('state','unavailable'); end if;
  insert into famille_core.support_tickets(id,user_id,app_id,organization_id,subject,description)
    values(q.id,auth.uid(),a,l.core_org_id,q.subject,q.description)
    on conflict(id) do nothing;
  select * into t from famille_core.support_tickets where id=q.id and user_id=auth.uid() and app_id=a
    and organization_id=l.core_org_id and subject=q.subject and description=q.description and deleted_at is null;
  if not found then raise exception 'SUPPORT_RECEIPT_CONFLICT' using errcode='42501'; end if;
  return jsonb_build_object('state','confirmed','ticket_id',t.id,'status',t.status);
end $$;
revoke all on function public.ns_v1_forward_support_ticket(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_v1_forward_support_ticket(uuid,uuid,uuid) to authenticated;
commit;
