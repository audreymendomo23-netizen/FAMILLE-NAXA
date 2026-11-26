-- Run after installing v9 in disposable database.
begin;
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000091'),('10000000-0000-4000-8000-000000000092');
insert into public.ns_organizations(id,display_name,business_mode) values ('20000000-0000-4000-8000-000000000091','QA Attendance','multi_site_network');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000091','10000000-0000-4000-8000-000000000091','NS-QA91','qa91@example.invalid',false),('50000000-0000-4000-8000-000000000092','10000000-0000-4000-8000-000000000092','NS-QA92','qa92@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000091','QA Manager','site_manager'),('60000000-0000-4000-8000-000000000092','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000092','QA Staff','cashier');
insert into public.ns_sites(id,org_id,code,name) values ('30000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','QA91','QA Site');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000091','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,true),('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000092','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,false);
insert into public.ns_devices(account_id,installation_id,platform,label,session_id) values ('50000000-0000-4000-8000-000000000091','qa-91','web','QA','qa-91-session'),('50000000-0000-4000-8000-000000000092','qa-92','web','QA','qa-92-session');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
insert into public.ns_attendance_policies(org_id,site_id,event_type,require_gps,require_selfie,updated_by) values ('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091','staff_clock_in',true,false,'60000000-0000-4000-8000-000000000091'),('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091','staff_clock_out',false,true,'60000000-0000-4000-8000-000000000091');
reset role;
do $$ begin begin
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'60000000-0000-4000-8000-000000000092','QA Staff','staff_clock_in',now());
 raise exception 'QA IMPERSONATION ACCEPTED';
 exception when others then if sqlerrm not like '%NS_ATTENDANCE_SELF_ONLY%' then raise; end if; end; end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
do $$ begin begin
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000092','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'60000000-0000-4000-8000-000000000092','QA Staff','staff_clock_in',now());
 raise exception 'QA LEGACY BYPASS';
 exception when others then if sqlerrm not like '%NS_ATTENDANCE_EVIDENCE_REQUIRED%' then raise; end if; end; end $$;
set local role authenticated;
do $$ declare c integer; org uuid:='20000000-0000-4000-8000-000000000091'; site uuid:='30000000-0000-4000-8000-000000000091'; member uuid:='60000000-0000-4000-8000-000000000092'; eid uuid:='70000000-0000-4000-8000-000000000092'; outid uuid:='70000000-0000-4000-8000-000000000093'; t timestamptz:=now(); v jsonb;
begin
 update public.ns_attendance_policies set require_gps=false,updated_by=member where org_id=org and site_id=site and event_type='staff_clock_in';
 get diagnostics c=row_count; if c<>0 then raise exception 'QA STAFF CHANGED POLICY'; end if;
 begin perform public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,null,null,null,null,null); raise exception 'QA MISSING GPS ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_GPS_REQUIRED%' then raise; end if; end;
 begin perform public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,0,4.1,9.7,15,t,null); raise exception 'QA OLD POLICY ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_POLICY_CHANGED%' then raise; end if; end;
 begin perform public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,120,9.7,15,t,null); raise exception 'QA INVALID GPS ACCEPTED'; exception when check_violation then null; end;
 v:=public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,4.1,9.7,15,t,null);
 if v->>'recorded' is distinct from 'true' then raise exception 'QA GPS NOT RECORDED'; end if;
 if not exists(select 1 from public.ns_attendance_evidence where event_id=eid and required_gps and latitude=4.1) then raise exception 'QA GPS NOT STORED'; end if;
 v:=public.ns_record_staff_time_with_evidence(eid,org,site,null,'staff_clock_in',t,1,4.1,9.7,15,t,null);
 if v->>'duplicate' is distinct from 'true' then raise exception 'QA RETRY NOT IDEMPOTENT'; end if;
 begin perform public.ns_record_staff_time_with_evidence(outid,org,site,null,'staff_clock_out',t,1,null,null,null,null,null); raise exception 'QA MISSING SELFIE ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_SELFIE_REQUIRED%' then raise; end if; end;
 begin perform public.ns_record_staff_time_with_evidence(outid,org,site,null,'staff_clock_out',t,1,null,null,null,null,t); raise exception 'QA MISSING OBJECT ACCEPTED'; exception when others then if sqlerrm not like '%NS_ATTENDANCE_SELFIE_MISSING%' then raise; end if; end;
end $$;
reset role;
set constraints all immediate;
rollback;
select 'PASS: 11 attendance assertions and rollback' as result;
