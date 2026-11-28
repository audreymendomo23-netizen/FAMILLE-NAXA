-- Authenticated media grant administration; transport remains a separate trusted service.
begin;
drop policy sec_media_grant_self on public.sec_media_grants;
create policy sec_media_grant_self on public.sec_media_grants for select to authenticated using(user_id=auth.uid() and revoked_at is null and expires_at>now() and request_id is not null and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create function sec_private.media_manage(p_org uuid,p_site uuid,p_grant uuid default null,p_revoke boolean default false) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;v public.sec_media_grants%rowtype;rows jsonb;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 if p_revoke is null or (p_revoke and p_grant is null) or (not p_revoke and p_grant is not null) then raise exception 'invalid action' using errcode='22023';end if;
 if p_revoke then
  select * into v from public.sec_media_grants where id=p_grant and organization_id=p_org and site_id=p_site and request_id is not null and (user_id=auth.uid() or r in ('owner','manager')) for update;
  if not found then raise exception 'grant denied' using errcode='42501';end if;
  if v.revoked_at is null then
   update public.sec_media_grants set revoked_at=clock_timestamp() where id=v.id;
   insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'media_grant_revoke',v.id);
  end if;
 end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id),'[]'::jsonb) into rows from
 (select id,device_id,user_id,media,created_at,expires_at,revoked_at from public.sec_media_grants where organization_id=p_org and site_id=p_site and request_id is not null and (user_id=auth.uid() or r in ('owner','manager')) order by created_at desc,id limit 100)x;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'grants',rows,'physical_action',false);
end $f$;
revoke all on function sec_private.media_manage(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function sec_private.media_manage(uuid,uuid,uuid,boolean) to authenticated;
create function public.sec_media_manage(p_org uuid,p_site uuid,p_grant uuid default null,p_revoke boolean default false) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.media_manage(p_org,p_site,p_grant,p_revoke)$r$;
revoke all on function public.sec_media_manage(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.sec_media_manage(uuid,uuid,uuid,boolean) to authenticated;
-- Return URL only after current membership and configured origin are revalidated.
create function sec_private.media_open(p_org uuid,p_site uuid,p_grant uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare v public.sec_media_grants%rowtype;base text;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 select g.* into v from public.sec_media_grants g where g.id=p_grant and g.organization_id=p_org and g.site_id=p_site and g.user_id=auth.uid() and g.request_id is not null and g.revoked_at is null and g.expires_at>now() for update;
 if not found then raise exception 'grant denied' using errcode='42501';end if;
 select origin into base from sec_private.media_origins where organization_id=p_org and site_id=p_site;
 if base is null or left(v.playback_url,length(base))<>base or substring(v.playback_url from length(base)+1) !~ '^/security/media/[A-Za-z0-9_-]{16,160}$' then raise exception 'origin denied' using errcode='42501';end if;
 insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),'media_open_authorized',v.id);
 return to_jsonb(v);
end $f$;
revoke all on function sec_private.media_open(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.media_open(uuid,uuid,uuid) to authenticated;
create function public.sec_media_open(p_org uuid,p_site uuid,p_grant uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.media_open(p_org,p_site,p_grant)$r$;
revoke all on function public.sec_media_open(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_media_open(uuid,uuid,uuid) to authenticated;
-- Force playback through audited RPC: list can expose metadata but not the URL.
revoke select on public.sec_media_grants from authenticated;
grant select(id,organization_id,site_id,device_id,user_id,media,created_at,expires_at,revoked_at,request_id) on public.sec_media_grants to authenticated;
commit;
