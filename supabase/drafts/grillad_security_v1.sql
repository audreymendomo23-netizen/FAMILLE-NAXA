-- GRILLAD read-only boundary for NAXA SECURITY; actual gateway not present in audited source.
begin;
create table grillad_private.security_links(org uuid not null,site uuid not null,security_site uuid not null,security_org uuid not null,enabled boolean not null default false,
 primary key(org,site),foreign key(org,site) references grillad_private.enabled_sites(org,site),
 foreign key(security_site,security_org) references famille_core.locations(id,organization_id));
create table grillad_private.camera_inventory(org uuid not null,site uuid not null,camera uuid not null,label text not null check(length(label) between 1 and 120),health text not null check(health in ('online','offline','unknown')),observed_at timestamptz not null,primary key(org,site,camera),foreign key(org,site) references grillad_private.security_links(org,site));
create table grillad_private.security_incidents(org uuid not null,site uuid not null,id uuid not null,camera uuid,category text not null check(category in ('intrusion','offline','tamper','fire','other')),observed_at timestamptz not null,primary key(org,site,id),foreign key(org,site) references grillad_private.security_links(org,site));
alter table grillad_private.security_links enable row level security;
alter table grillad_private.camera_inventory enable row level security;
alter table grillad_private.security_incidents enable row level security;
revoke all on grillad_private.security_links,grillad_private.camera_inventory,grillad_private.security_incidents from public,anon,authenticated;
create function grillad_private.security_list(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text;linked boolean;multi boolean;cams jsonb;incidents jsonb;
begin
 r:=grillad_private.scope(p_org,p_site);if r='seller' then raise exception 'GRILLAD_ROLE' using errcode='42501';end if;
 select exists(select 1 from famille_core.memberships m join famille_core.role_assignments ra on ra.membership_id=m.id and ra.app_id=m.app_id and ra.organization_id=m.organization_id where m.organization_id=p_org and m.app_id=famille_core.current_app_id() and m.status='active' and ra.status='active' and ra.starts_at<=now() and (ra.expires_at is null or ra.expires_at>now()) and ra.role_code in ('manager','seller') and ra.location_id=p_site) or (select count(*) from grillad_private.enabled_sites where org=p_org and enabled)>1 into multi;
 if not multi then return jsonb_build_object('available',false,'reason','MULTILEVEL_REQUIRED','cameras','[]'::jsonb,'incidents','[]'::jsonb);end if;
 select exists(select 1 from grillad_private.security_links l join famille_core.applications a on a.code='naxa_security' and a.status='active' join famille_core.organization_apps o on o.organization_id=l.security_org and o.app_id=a.id and o.status='active' join famille_core.locations s on s.id=l.security_site and s.organization_id=l.security_org and s.status='active' where l.org=p_org and l.site=p_site and l.enabled and exists(select 1 from famille_core.subscriptions b where b.organization_id=l.security_org and b.app_id=a.id and b.status='active' and (b.starts_at is null or b.starts_at<=now()) and b.ends_at>now())) into linked;
 if not linked then return jsonb_build_object('available',false,'reason','PARTNER_NOT_LINKED','cameras','[]'::jsonb,'incidents','[]'::jsonb);end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',camera,'name',label,'status',case when observed_at<now()-interval '2 minutes' then 'unknown' else health end,'observed_at',observed_at) order by label),'[]'::jsonb) into cams from grillad_private.camera_inventory where org=p_org and site=p_site;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.observed_at desc),'[]'::jsonb) into incidents from (select id,camera,category,observed_at from grillad_private.security_incidents where org=p_org and site=p_site order by observed_at desc limit 50)x;
 return jsonb_build_object('available',true,'live_available',false,'reason','VIDEO_GATEWAY_NOT_QUALIFIED','cameras',cams,'incidents',incidents);
end $$;
create function public.grillad_security_list(p_org uuid,p_site uuid) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select grillad_private.security_list(p_org,p_site)$$;
revoke all on function grillad_private.security_list(uuid,uuid),public.grillad_security_list(uuid,uuid) from public,anon,authenticated;
grant execute on function grillad_private.security_list(uuid,uuid),public.grillad_security_list(uuid,uuid) to authenticated;
commit;
