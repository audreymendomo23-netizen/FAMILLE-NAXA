CREATE OR REPLACE FUNCTION public.ns_can_manage_site(p_org_id uuid, p_site_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 select public.ns_erp_access_reason(p_org_id)<>'blocked'
 and exists (select 1 from public.ns_sites t where t.id=p_site_id and t.org_id=p_org_id)
 and exists (
 select 1 from public.ns_member_scopes s
 join public.ns_members m on m.id=s.member_id and m.org_id=s.org_id
 where m.account_id=public.ns_current_account_id()
 and m.org_id=p_org_id and m.status='active'
 and m.role_code in ('promoter','network_manager','site_manager') and s.can_manage
 and (s.scope_type='organization' or (s.scope_type='site' and s.site_id=p_site_id))
 );
$function$;
REVOKE EXECUTE ON FUNCTION public.ns_can_manage_site(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ns_can_manage_site(uuid,uuid) TO authenticated, service_role;
