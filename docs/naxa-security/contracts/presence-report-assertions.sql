begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000351'),('00000000-0000-0000-0000-000000000352'),('00000000-0000-0000-0000-000000000353');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000351','QA presence');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000351','manager',true),('10000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000352','operator',true),('10000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000353','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000351','10000000-0000-0000-0000-000000000351','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000351',true),('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000352',true),('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000353',true);
insert into public.sec_shifts(id,organization_id,site_id,agent_id,created_by,label,starts_at,ends_at,state) values ('40000000-0000-0000-0000-000000000351','10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000352','00000000-0000-0000-0000-000000000351','QA shift',now()-interval '8 hours',now()-interval '1 hour','completed');
insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,source,mock_reported,state)
select '10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000352',gen_random_uuid(),a,4,9,10,now()-t,'browser',null,'reviewed'
from (values('arrival',interval '7 hours 50 minutes'),('pause_start',interval '5 hours'),('pause_end',interval '4 hours 30 minutes'),('departure',interval '1 hour 10 minutes')) v(a,t);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000351',true);
do $q$declare v jsonb;begin
 v:=public.sec_presence_report('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','40000000-0000-0000-0000-000000000351');
 if v->>'attendance_status'<>'reviewed_complete' or v->>'complete'<>'true' or v->>'worked_seconds'<>'22200' or v->>'pause_seconds'<>'1800' or v->>'late_seconds'<>'600' or v->>'early_departure_seconds'<>'600' or v->>'physical_presence_certified'<>'false' then raise exception 'report %',v;end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000352',true);
do $q$begin if public.sec_presence_report('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','40000000-0000-0000-0000-000000000351')->>'complete'<>'true' then raise exception 'self report';end if;end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000353',true);
do $q$begin begin perform public.sec_presence_report('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','40000000-0000-0000-0000-000000000351');raise exception 'other worker report';exception when insufficient_privilege then null;end;end $q$;
reset role;
insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,source,mock_reported,state) values ('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000352',gen_random_uuid(),'arrival',4,9,10,now()-interval '6 hours','browser',null,'reviewed');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000351',true);
do $q$declare v jsonb;begin v:=public.sec_presence_report('10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','40000000-0000-0000-0000-000000000351');if v->>'attendance_status'<>'review_required' or v->>'complete'<>'false' or v->>'anomalies'<>'1' or v->'worked_seconds'<>'null'::jsonb then raise exception 'anomalous total';end if;end $q$;
reset role;
insert into public.sec_shifts(id,organization_id,site_id,agent_id,created_by,label,starts_at,ends_at,state) values
('40000000-0000-0000-0000-000000000352','10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000353','00000000-0000-0000-0000-000000000351','QA no evidence',now()-interval '8 hours',now()-interval '1 hour','accepted'),
('40000000-0000-0000-0000-000000000353','10000000-0000-0000-0000-000000000351','20000000-0000-0000-0000-000000000351','00000000-0000-0000-0000-000000000353','00000000-0000-0000-0000-000000000351','QA future',now()+interval '1 hour',now()+interval '8 hours','accepted');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000351',true);
do $q$declare o uuid:='10000000-0000-0000-0000-000000000351';s uuid:='20000000-0000-0000-0000-000000000351';v jsonb;begin
 v:=public.sec_presence_report(o,s,'40000000-0000-0000-0000-000000000352');
 if v->>'attendance_status'<>'missing_evidence' or v->>'complete'<>'false' or v->'worked_seconds'<>'null'::jsonb then raise exception 'missing evidence cannot prove absence';end if;
 v:=public.sec_presence_report(o,s,'40000000-0000-0000-0000-000000000353');
 if v->>'attendance_status'<>'scheduled' then raise exception 'future incorrectly absent';end if;
end $q$;
reset role;rollback;
