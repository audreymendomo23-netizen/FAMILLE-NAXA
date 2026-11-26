-- Run after original v15 staging fixture, before rollback.
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000091';s uuid:='30000000-0000-4000-8000-000000000091';a text;r bigint;begin
 foreach a in array array['staff_clock_in','staff_clock_out'] loop
 select revision into r from public.ns_attendance_policies where org_id=o and site_id=s and event_type=a;
 begin perform public.ns_set_attendance_policy(o,s,a,coalesce(r,0),false,false);raise exception 'QA GPS DISABLED';exception when others then if sqlerrm not like '%NS_ATTENDANCE_GPS_MANDATORY%' then raise;end if;end;
 end loop;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000091';s uuid:='30000000-0000-4000-8000-000000000091';a text;r bigint;t timestamptz:=clock_timestamp();begin
 foreach a in array array['staff_clock_in','staff_clock_out'] loop
 select revision into r from public.ns_attendance_policies where org_id=o and site_id=s and event_type=a;
 begin perform public.ns_stage_attendance_proof(gen_random_uuid(),o,s,null,a,t,coalesce(r,0),null,null,null,null,null);raise exception 'QA LEGACY GPS BYPASS';exception when others then if sqlerrm not like '%NS_ATTENDANCE_GPS_REQUIRED%' then raise;end if;end;
 end loop;
end $qa$;
reset role;
delete from public.ns_attendance_policies where org_id='20000000-0000-4000-8000-000000000091' and event_type in ('staff_clock_in','staff_clock_out');
set constraints all deferred;
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000091';s uuid:='30000000-0000-4000-8000-000000000091';m uuid:='60000000-0000-4000-8000-000000000092';d uuid:=current_setting('qa.attendance_device')::uuid;e uuid:=gen_random_uuid();t timestamptz:=clock_timestamp();v jsonb;a text;payload jsonb;begin
 foreach a in array array['staff_clock_in','staff_clock_out'] loop
 begin perform public.ns_stage_attendance_proof(gen_random_uuid(),o,s,null,a,t,0,null,null,null,null,null);raise exception 'QA NO POLICY GPS BYPASS';exception when others then if sqlerrm not like '%NS_ATTENDANCE_GPS_REQUIRED%' then raise;end if;end;
 end loop;
 payload:=jsonb_build_object('org_id',o,'site_id',s,'time_event_id',e,'staff_member_id',m,'staff_name_snapshot','QA Staff','occurred_at',t);
 begin perform public.ns_apply_sync_event(o,s,null,d,e,3,'staff_clock_out',e::text,'staff_clock_out.recorded',payload);raise exception 'QA RAW SYNC BYPASS';exception when others then if sqlerrm not like '%NS_ATTENDANCE_EVIDENCE_REQUIRED%' then raise;end if;end;
 e:=gen_random_uuid();v:=public.ns_stage_attendance_proof(e,o,s,null,'staff_clock_out',t,0,4.1,9.7,10,t,null);
 if v->>'proof_ref'<>e::text then raise exception 'QA MANDATORY STAGING';end if;
 payload:=payload||jsonb_build_object('time_event_id',e,'attendance_proof_ref',e);
 v:=public.ns_apply_sync_event(o,s,null,d,e,3,'staff_clock_out',e::text,'staff_clock_out.recorded',payload);
 if v->>'status'<>'applied' then raise exception 'QA MANDATORY SYNC %',v;end if;
 if not exists(select 1 from public.ns_attendance_evidence where event_id=e and required_gps and latitude=4.1 and policy_revision=0) then raise exception 'QA MANDATORY GPS MISSING';end if;
end $qa$;
reset role;
set constraints all immediate;
select 'PASS: mandatory GPS at shift boundaries, denied disable and no-policy bypass, confirmed proof' as result;
