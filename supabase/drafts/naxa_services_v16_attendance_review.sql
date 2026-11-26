begin;
-- v16 candidate: review restricted to self or strictly superior authorized manager.
create function public.ns_attendance_review_allowed(p_event uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(
 select 1 from public.ns_staff_time_events e join public.ns_members a on a.org_id=e.org_id and a.id=public.ns_current_member_id(e.org_id)
 join public.ns_members t on t.org_id=e.org_id and t.id=e.staff_member_id
 join public.ns_organizations o on o.id=e.org_id
 where e.id=p_event and o.status='active' and a.status='active'
 and public.ns_erp_access_reason(e.org_id)<>'blocked'
 and (public.ns_can_access_site(e.org_id,e.site_id) or (e.workstation_id is not null and public.ns_can_access_workstation(e.org_id,e.site_id,e.workstation_id)))
 and (a.id=t.id or (o.business_mode in ('single_site_multi_workstation','multi_site_network')
 and (case a.role_code when 'promoter' then 40 when 'network_manager' then 30 when 'site_manager' then 20 when 'workstation_manager' then 10 else 0 end)>
 (case t.role_code when 'promoter' then 40 when 'network_manager' then 30 when 'site_manager' then 20 when 'workstation_manager' then 10 else 0 end)
 and exists(select 1 from public.ns_member_scopes x where x.org_id=e.org_id and x.member_id=a.id and x.can_manage and
 ((a.role_code='promoter' and x.scope_type='organization') or
 (a.role_code in ('promoter','network_manager','site_manager') and x.scope_type='site' and x.site_id=e.site_id) or
 (a.role_code='workstation_manager' and x.scope_type='workstation' and x.site_id=e.site_id and x.workstation_id=e.workstation_id))))))
 $f$;
revoke all on function public.ns_attendance_review_allowed(uuid) from public,anon,authenticated;
grant execute on function public.ns_attendance_review_allowed(uuid) to authenticated;
drop policy ns_attendance_evidence_read on public.ns_attendance_evidence;
create policy ns_attendance_evidence_read on public.ns_attendance_evidence for select to authenticated using(public.ns_attendance_review_allowed(event_id));
create function public.ns_attendance_review(p_org uuid,p_site uuid,p_before timestamptz default now(),p_limit integer default 30)
returns table(event_id uuid,member_name text,event_type text,occurred_at timestamptz,required_gps boolean,required_selfie boolean,latitude double precision,longitude double precision,accuracy_m double precision,gps_captured_at timestamptz,selfie_path text,selfie_captured_at timestamptz,policy_revision bigint)
language sql stable security definer set search_path='' as $f$
 select e.event_id,t.staff_name_snapshot,e.event_type,t.occurred_at,e.required_gps,e.required_selfie,e.latitude,e.longitude,e.accuracy_m,e.gps_captured_at,e.selfie_path,e.selfie_captured_at,e.policy_revision
 from public.ns_attendance_evidence e join public.ns_staff_time_events t on t.id=e.event_id
 where e.org_id=p_org and e.site_id=p_site and t.occurred_at<p_before and public.ns_attendance_review_allowed(e.event_id)
 order by t.occurred_at desc,e.event_id desc limit greatest(1,least(coalesce(p_limit,30),100))
 $f$;
revoke all on function public.ns_attendance_review(uuid,uuid,timestamptz,integer) from public,anon,authenticated;
grant execute on function public.ns_attendance_review(uuid,uuid,timestamptz,integer) to authenticated;
-- No direct deletion from storage.objects. Binary cleanup must use the Storage API in a separate worker.
create function public.ns_purge_expired_attendance_staging(p_limit integer default 100) returns integer
language plpgsql security definer set search_path='' as $f$
declare n integer;
begin
 with expired as (select event_id from public.ns_attendance_staged_proof where expires_at<clock_timestamp() order by expires_at limit greatest(1,least(coalesce(p_limit,100),500)) for update skip locked)
 delete from public.ns_attendance_staged_proof s using expired e where s.event_id=e.event_id;
 get diagnostics n=row_count;return n;
end $f$;
revoke all on function public.ns_purge_expired_attendance_staging(integer) from public,anon,authenticated;
grant execute on function public.ns_purge_expired_attendance_staging(integer) to service_role;

rollback;
