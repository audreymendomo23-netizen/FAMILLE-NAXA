begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000421'),('00000000-0000-0000-0000-000000000422'),('00000000-0000-0000-0000-000000000423');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000421','QA manual presence');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000421','manager',true),('10000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000422','operator',true),('10000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000423','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000421','10000000-0000-0000-0000-000000000421','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000421',true),('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000422',true),('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000423',true);
insert into public.sec_shifts(id,organization_id,site_id,agent_id,created_by,label,starts_at,ends_at,state) values
('40000000-0000-0000-0000-000000000421','10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000422','00000000-0000-0000-0000-000000000421','QA manual shift',now()-interval '8 hours',now()-interval '1 hour','completed'),
('40000000-0000-0000-0000-000000000422','10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','00000000-0000-0000-0000-000000000422','00000000-0000-0000-0000-000000000421','QA absent shift',now()-interval '20 hours',now()-interval '12 hours','completed');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000422',true);
select public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','submit','50000000-0000-0000-0000-000000000421','40000000-0000-0000-0000-000000000421',jsonb_build_object('kind','arrival','observed_at',now()-interval '7 hours','reason','Terminal unavailable'));
select public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','submit','50000000-0000-0000-0000-000000000422','40000000-0000-0000-0000-000000000421',jsonb_build_object('kind','departure','observed_at',now()-interval '2 hours','reason','Terminal unavailable'));
select public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','submit','50000000-0000-0000-0000-000000000423','40000000-0000-0000-0000-000000000422','{"kind":"absence","reason":"Absence declared"}');
do $q$begin
 if public.sec_presence_report('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','40000000-0000-0000-0000-000000000421')->>'attendance_status'<>'review_required' then raise exception 'pending not shown';end if;
 begin perform public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','review','50000000-0000-0000-0000-000000000421','40000000-0000-0000-0000-000000000421','{"decision":"approved","reason":"self"}');raise exception 'self review';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000423',true);
do $q$begin if exists(select 1 from public.sec_presence_exceptions) then raise exception 'other worker data';end if;
 begin perform public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','list',null,'40000000-0000-0000-0000-000000000421');raise exception 'other worker list';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000421',true);
select public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','review','50000000-0000-0000-0000-000000000421','40000000-0000-0000-0000-000000000421','{"decision":"approved","reason":"Supervisor confirms"}');
select public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','review','50000000-0000-0000-0000-000000000422','40000000-0000-0000-0000-000000000421','{"decision":"approved","reason":"Supervisor confirms"}');
select public.sec_presence_exception('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','review','50000000-0000-0000-0000-000000000423','40000000-0000-0000-0000-000000000422','{"decision":"approved","reason":"Supervisor confirms"}');
do $q$declare v jsonb;begin
 v:=public.sec_presence_report('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','40000000-0000-0000-0000-000000000421');if v->>'complete'<>'true' or v->>'worked_seconds'<>'18000' or v->>'manual_approved_events'<>'2' or v->>'physical_presence_certified'<>'false' then raise exception 'manual totals %',v;end if;
 v:=public.sec_presence_report('10000000-0000-0000-0000-000000000421','20000000-0000-0000-0000-000000000421','40000000-0000-0000-0000-000000000422');if v->>'attendance_status'<>'absence_reviewed' or v->'worked_seconds'<>'null'::jsonb then raise exception 'absence disposition %',v;end if;
 if exists(select 1 from public.sec_attendance_drafts where organization_id='10000000-0000-0000-0000-000000000421') then raise exception 'fabricated GPS';end if;
end $q$;
reset role;rollback;
