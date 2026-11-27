-- Run after candidate schema on disposable PostgreSQL only.
begin;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000001','QA A'),('10000000-0000-0000-0000-000000000002','QA B');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','operator',true),('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','QA A1'),('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','QA A2'),('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','QA B1');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',true);
insert into public.sec_devices(organization_id,site_id,label,kind) select organization_id,id,name,'camera' from public.sec_sites;
insert into public.sec_incidents(organization_id,site_id,subject,priority,state) select organization_id,id,'QA only','P2','new' from public.sec_sites;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
insert into public.sec_incidents(organization_id,site_id,subject,priority,state,reporter_id,request_id) values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Manual QA','P2','new','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001');
insert into public.sec_work_orders(organization_id,site_id,subject,kind,reporter_id,request_id) values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','QA maintenance','preventive','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002');
do $$begin
 if (select count(*) from public.sec_work_orders)<>1 then raise exception 'work read';end if;
 if (select count(*) from public.sec_incidents)<>2 then raise exception 'report read';end if;
 begin
 insert into public.sec_work_orders(organization_id,site_id,subject,kind,reporter_id,request_id) values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','Denied','corrective','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000003');
 raise exception 'cross site allowed';exception when insufficient_privilege then null;end;
 begin
 insert into public.sec_incidents(organization_id,site_id,subject,priority,state,reporter_id,request_id) values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Denied','P1','new','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000004');
 raise exception 'critical source impersonation';exception when insufficient_privilege then null;end;
 begin
 insert into public.sec_incidents(organization_id,site_id,subject,priority,state,reporter_id,request_id) values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Duplicate','P2','new','00000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001');
 raise exception 'duplicate accepted';exception when unique_violation then null;end;
end$$;
reset role;
update public.sec_memberships set active=false where user_id='00000000-0000-0000-0000-000000000001';
set local role authenticated;
do $$begin if (select count(*) from public.sec_work_orders)<>0 then raise exception 'revocation';end if;end$$;
reset role;
rollback;
