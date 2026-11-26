begin;
-- v17: candidates only; use Storage API to delete bytes, never DELETE storage.objects.
create function public.ns_attendance_orphan_candidates(p_limit integer default 100)
returns table(object_name text) language sql stable security definer set search_path='' as $f$
 select o.name from storage.objects o
 where o.bucket_id='ns-attendance-selfies' and o.created_at<now()-interval '24 hours'
 and o.updated_at<now()-interval '24 hours'
 and o.name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$'
 and not exists(select 1 from public.ns_attendance_evidence e where e.selfie_path=o.name)
 and not exists(select 1 from public.ns_attendance_staged_proof s where s.org_id::text||'/'||s.site_id::text||'/'||s.member_id::text||'/'||s.event_id::text||'.jpg'=o.name)
 and not exists(select 1 from public.ns_staff_time_events e where e.id::text||'.jpg'=split_part(o.name,'/',4))
 order by o.created_at,o.name limit greatest(1,least(coalesce(p_limit,100),100))
$f$;
revoke all on function public.ns_attendance_orphan_candidates(integer) from public,anon,authenticated;
grant execute on function public.ns_attendance_orphan_candidates(integer) to service_role;

rollback;
