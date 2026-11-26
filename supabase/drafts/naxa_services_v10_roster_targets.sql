begin;
-- Scoped target directory: only assignable members and posts, no personal contact information.
create function public.ns_roster_targets(p_org uuid,p_site uuid)
returns table(member_id uuid,display_name text,workstation_id uuid,workstation_name text)
language sql stable security definer set search_path='' as $fn$
 select m.id,m.display_name,null::uuid,null::text
 from public.ns_members m where m.org_id=p_org and public.ns_roster_can_manage(p_org,p_site,null,m.id)
 union all
 select m.id,m.display_name,w.id,w.name
 from public.ns_members m join public.ns_workstations w on w.org_id=m.org_id and w.site_id=p_site and w.status='active'
 where m.org_id=p_org and public.ns_roster_can_manage(p_org,p_site,w.id,m.id)
 order by 2,4 nulls first
$fn$;
revoke all on function public.ns_roster_targets(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_roster_targets(uuid,uuid) to authenticated;

rollback;
