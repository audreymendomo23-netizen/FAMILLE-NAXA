-- Disposable database only. Positive and negative checks; rollback all fixtures.
begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000011'),('00000000-0000-0000-0000-000000000012');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000011','QA');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011','operator',true),('10000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000012','viewer',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000011','10000000-0000-0000-0000-000000000011','QA allowed'),('20000000-0000-0000-0000-000000000012','10000000-0000-0000-0000-000000000011','QA denied');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011',true),('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000012',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000011',true);
insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported)
values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011','30000000-0000-0000-0000-000000000011','arrival',4,9,12,now(),false);
do $$begin
 if (select count(*) from public.sec_attendance_drafts where state='pending_review')<>1 then raise exception 'pending evidence missing';end if;
 if has_column_privilege(current_user,'public.sec_attendance_drafts','state','UPDATE') or has_column_privilege(current_user,'public.sec_attendance_drafts','state','INSERT') then raise exception 'client can confirm';end if;
 begin
 insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported) values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000011',gen_random_uuid(),'arrival',4,9,12,now(),false);
 raise exception 'cross-site accepted';exception when insufficient_privilege then null;end;
 begin
 insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported) values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011',gen_random_uuid(),'departure',4,9,12,now()-interval '121 seconds',false);
 raise exception 'stale accepted';exception when insufficient_privilege then null;end;
 begin
 insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported) values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011',gen_random_uuid(),'arrival',4,9,12,now(),true);
 raise exception 'mock accepted';exception when check_violation then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000012',true);
do $$begin
 if (select count(*) from public.sec_attendance_drafts)<>0 then raise exception 'other employee data visible';end if;
 begin
 insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported) values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000012',gen_random_uuid(),'arrival',4,9,12,now(),false);
 raise exception 'viewer write accepted';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000011',true);
insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported,source)
values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011','30000000-0000-0000-0000-000000000012','departure',4,9,12,now(),null,'browser');
do $$begin
 if (select count(*) from public.sec_attendance_drafts where source='browser' and mock_reported is null and state='pending_review')<>1 then raise exception 'browser evidence not pending';end if;
 begin
 insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,mock_reported,source) values ('10000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000011',gen_random_uuid(),'arrival',4,9,12,now(),false,'browser');
 raise exception 'browser mock status falsely asserted';exception when check_violation then null;end;
end$$;
reset role;
set local role anon;
do $$begin if has_table_privilege(current_user,'public.sec_attendance_drafts','SELECT') then raise exception 'anonymous select';end if;end$$;
reset role;
rollback;
