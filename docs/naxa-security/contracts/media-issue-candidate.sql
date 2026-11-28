-- Media authorization issuance, in isolated PostgreSQL. Transport must validate the grant itself.
begin;
create role sec_media_issuer nologin;
grant usage on schema sec_private to sec_media_issuer;
create table sec_private.media_origins(organization_id uuid not null,site_id uuid not null,origin text not null check(origin ~ '^https://[A-Za-z0-9.-]+$'),primary key(organization_id,site_id),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id));
revoke all on sec_private.media_origins from public,anon,authenticated,sec_media_issuer;
alter table public.sec_media_grants add column request_id uuid unique references public.sec_module_requests(request_id);
create function sec_private.issue_media(p_org uuid,p_site uuid,p_request uuid,p_grant uuid,p_path text,p_seconds integer) returns jsonb language plpgsql security definer set search_path=pg_catalog as $issue$
declare q public.sec_module_requests%rowtype; g public.sec_media_grants%rowtype; d public.sec_devices%rowtype; base text; actor_role text;
begin
 if p_grant is null or p_seconds is null or p_seconds not between 1 and 300 or p_path is null or p_path !~ '^/security/media/[A-Za-z0-9_-]{16,160}$' then raise exception 'invalid grant' using errcode='22023';end if;
 select * into q from public.sec_module_requests where request_id=p_request and organization_id=p_org and site_id=p_site and kind='media' and state='reviewed' and payload->>'consent'='yes' for update;
 if not found or q.reviewed_by=q.reporter_id then raise exception 'request denied' using errcode='42501';end if;
 select m.role into actor_role from public.sec_memberships m join public.sec_site_memberships sm using(organization_id,user_id) join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id where m.organization_id=p_org and sm.site_id=p_site and m.user_id=q.reporter_id and m.active and sm.active and s.active and o.active;
 if actor_role is null or actor_role not in ('owner','manager','operator') then raise exception 'requester inactive' using errcode='42501';end if;
 select * into d from public.sec_devices where organization_id=p_org and site_id=p_site and id::text=q.payload->>'reference' and kind=case q.payload->>'media' when 'video' then 'camera' else 'audio' end;
 if not found then raise exception 'device denied' using errcode='42501';end if;
 select origin into base from sec_private.media_origins where organization_id=p_org and site_id=p_site;
 if not found then raise exception 'transport unconfigured' using errcode='42501';end if;
 select * into g from public.sec_media_grants where request_id=p_request;
 if found then
  if g.id<>p_grant or g.playback_url<>base||p_path or g.revoked_at is not null or g.expires_at<=now() then raise exception 'grant conflict or expired' using errcode='23505';end if;
 else
  insert into public.sec_media_grants(id,organization_id,site_id,device_id,user_id,media,playback_url,expires_at,request_id) values(p_grant,p_org,p_site,d.id,q.reporter_id,q.payload->>'media',base||p_path,now()+make_interval(secs=>p_seconds),p_request) returning * into g;
 end if;
 return jsonb_build_object('id',g.id,'request_id',p_request,'media',g.media,'expires_at',g.expires_at);
end $issue$;
revoke all on function sec_private.issue_media(uuid,uuid,uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function sec_private.issue_media(uuid,uuid,uuid,uuid,text,integer) to sec_media_issuer;
-- Transport checks this on each new stream request. The database does not serve media bytes.
create function sec_private.media_active(p_id uuid,p_path text) returns boolean language sql stable security definer set search_path=pg_catalog as $active$
 select exists(select 1 from public.sec_media_grants g join sec_private.media_origins o on o.organization_id=g.organization_id and o.site_id=g.site_id join public.sec_memberships m on m.organization_id=g.organization_id and m.user_id=g.user_id join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id and sm.site_id=g.site_id join public.sec_sites s on s.id=g.site_id and s.organization_id=g.organization_id join public.sec_organizations org on org.id=g.organization_id
 where g.id=p_id and g.request_id is not null and g.playback_url=o.origin||p_path and g.revoked_at is null and g.expires_at>now() and m.active and sm.active and s.active and org.active and m.role in ('owner','manager','operator'))
$active$;
revoke all on function sec_private.media_active(uuid,text) from public,anon,authenticated;
grant execute on function sec_private.media_active(uuid,text) to sec_media_issuer;
commit;
