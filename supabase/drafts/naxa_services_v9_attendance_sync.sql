begin;
-- Candidate follow-on: four canonical operations use the existing atomic sync.
create function public.ns_record_attendance_sync(p_org uuid,p_site uuid,p_event_type text,p_payload jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare e jsonb:=p_payload->'attendance_evidence';
begin
 if (p_payload->>'staff_member_id')::uuid is distinct from public.ns_current_member_id(p_org) then raise exception 'NS_ATTENDANCE_SELF_ONLY'; end if;
 if e is null then
  return public.ns_record_staff_time_event((p_payload->>'time_event_id')::uuid,p_org,p_site,nullif(p_payload->>'workstation_id','')::uuid,(p_payload->>'staff_member_id')::uuid,p_payload->>'staff_name_snapshot',p_event_type,(p_payload->>'occurred_at')::timestamptz);
 end if;
 if jsonb_typeof(e)<>'object' then raise exception 'NS_ATTENDANCE_EVIDENCE_INVALID'; end if;
 return public.ns_record_staff_time_with_evidence((p_payload->>'time_event_id')::uuid,p_org,p_site,nullif(p_payload->>'workstation_id','')::uuid,p_event_type,(p_payload->>'occurred_at')::timestamptz,(e->>'policy_revision')::bigint,(e->>'latitude')::double precision,(e->>'longitude')::double precision,(e->>'accuracy_m')::double precision,(e->>'gps_captured_at')::timestamptz,(e->>'selfie_captured_at')::timestamptz);
end $$;
revoke all on function public.ns_record_attendance_sync(uuid,uuid,text,jsonb) from public,anon,authenticated;
do $patch$ declare d text; old text; event text; projection text:='public.ns_sync_redact_payload(p_payload || jsonb_build_object(''actor_member_id'', v_member_id, ''server_result'', coalesce(v_result, ''{}''::jsonb)))';
begin
 select pg_get_functiondef('public.ns_apply_sync_event(uuid,uuid,uuid,uuid,uuid,bigint,text,text,text,jsonb)'::regprocedure) into d;
 foreach event in array array['staff_clock_in','staff_break_start','staff_break_end','staff_clock_out'] loop
 old:=format($fmt$v_result := public.ns_record_staff_time_event(
        (p_payload->>'time_event_id')::uuid,p_org_id,p_site_id,
        nullif(p_payload->>'workstation_id','')::uuid,(p_payload->>'staff_member_id')::uuid,
        p_payload->>'staff_name_snapshot',%L,(p_payload->>'occurred_at')::timestamptz
      );$fmt$,event);
 if strpos(d,old)=0 then raise exception 'NS_ATTENDANCE_SYNC_PATCH_DRIFT: %',event; end if;
 d:=replace(d,old,format('v_result := public.ns_record_attendance_sync(p_org_id,p_site_id,%L,p_payload);',event));
 end loop;
 if strpos(d,projection)=0 then raise exception 'NS_ATTENDANCE_PROJECTION_PATCH_DRIFT'; end if;
 d:=replace(d,projection,$projection$case when p_action_code in ('staff_clock_in.recorded','staff_break_start.recorded','staff_break_end.recorded','staff_clock_out.recorded') then jsonb_build_object('time_event_id',p_payload->>'time_event_id','staff_member_id',v_member_id,'staff_name_snapshot',p_payload->>'staff_name_snapshot','occurred_at',p_payload->>'occurred_at','workstation_id',p_payload->>'workstation_id','org_id',p_org_id,'site_id',p_site_id,'actor_member_id',v_member_id,'server_result',v_result) else $projection$||projection||' end');
 execute d;
 select pg_get_functiondef('public.ns_pull_sync_changes(uuid,uuid,bigint,integer)'::regprocedure) into d;
 old:='and c.source_device_id <> p_device_id';
 if strpos(d,old)=0 then raise exception 'NS_ATTENDANCE_PULL_PATCH_DRIFT'; end if;
 d:=replace(d,old,old||$filter$
    and (c.action_code not in ('staff_clock_in.recorded','staff_break_start.recorded','staff_break_end.recorded','staff_clock_out.recorded')
      or c.projection_json->>'staff_member_id'=v_member_id::text
      or public.ns_can_manage_site(p_org_id,c.site_id))$filter$);
 execute d;
end $patch$;
revoke execute on function public.ns_record_staff_time_with_evidence(uuid,uuid,uuid,uuid,text,timestamptz,bigint,double precision,double precision,double precision,timestamptz,timestamptz) from authenticated;

rollback;
