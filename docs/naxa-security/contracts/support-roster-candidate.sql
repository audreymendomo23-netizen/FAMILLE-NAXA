-- Owner manages explicitly authorized support agents of their own site only.
begin;
create function sec_private.support_roster(p_org uuid,p_site uuid,p_user uuid default null,p_active boolean default null) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare r text;data jsonb;released integer:=0;
begin
 r:=sec_private.field_role(p_org,p_site);
 if coalesce(r,'')<>'owner' then raise exception 'owner required' using errcode='42501';end if;
 if (p_user is null)<>(p_active is null) then raise exception 'invalid operation' using errcode='22023';end if;
 if p_user is not null then
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,392));
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text||':'||p_user::text,391));
  if not exists(select 1 from public.sec_site_memberships sm join public.sec_memberships m using(organization_id,user_id) where sm.organization_id=p_org and sm.site_id=p_site and sm.user_id=p_user and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'member denied' using errcode='42501';end if;
  if p_active then
   insert into sec_private.support_agents values(p_org,p_site,p_user,true) on conflict(organization_id,site_id,user_id) do update set active=true;
  else
   update sec_private.support_agents set active=false where organization_id=p_org and site_id=p_site and user_id=p_user;
   if not found then raise exception 'agent denied' using errcode='42501';end if;
   -- Return ongoing work to the authorized queue, preserving message history and SLA.
   update public.sec_support_cases set agent_id=null,state='open' where organization_id=p_org and site_id=p_site and agent_id=p_user and state in ('assigned','waiting_customer');
   get diagnostics released=row_count;
  end if;
  insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,object_id) values(p_org,p_site,auth.uid(),case when p_active then 'support_agent_enable' else 'support_agent_disable' end,p_user);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'role',m.role,'active',coalesce(a.active,false)) order by m.user_id),'[]'::jsonb) into data
 from public.sec_memberships m join public.sec_site_memberships sm using(organization_id,user_id)
 left join sec_private.support_agents a on a.organization_id=sm.organization_id and a.site_id=sm.site_id and a.user_id=sm.user_id
 where m.organization_id=p_org and sm.site_id=p_site and m.active and sm.active and m.role in ('owner','manager','operator');
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'actor_id',auth.uid(),'members',data,'released',released);
end $f$;
revoke all on function sec_private.support_roster(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function sec_private.support_roster(uuid,uuid,uuid,boolean) to authenticated;
create function public.sec_support_roster(p_org uuid,p_site uuid,p_user uuid default null,p_active boolean default null) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.support_roster(p_org,p_site,p_user,p_active)$r$;
revoke all on function public.sec_support_roster(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.sec_support_roster(uuid,uuid,uuid,boolean) to authenticated;
commit;
