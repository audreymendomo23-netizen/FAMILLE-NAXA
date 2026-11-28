-- Dedicated synthetic personas; never point this harness at hosted databases.
insert into auth.users values ('00000000-0000-0000-0000-000000000141'),('00000000-0000-0000-0000-000000000142'),('00000000-0000-0000-0000-000000000143');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000141','E2E synthetic organization');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000141','operator',true),('10000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000142','operator',true),('10000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000143','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000141','10000000-0000-0000-0000-000000000141','E2E site'),('20000000-0000-0000-0000-000000000142','10000000-0000-0000-0000-000000000141','Other site');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000141',true),('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000142',true),('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000142','00000000-0000-0000-0000-000000000143',true);
insert into sec_private.support_agents values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000142',true);

insert into auth.users values ('00000000-0000-0000-0000-000000000144');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000144','manager',true);
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000144',true);
insert into public.sec_incidents(organization_id,site_id,subject,priority,state,occurred_at) select '10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','Synthetic report row '||g,'P3','new',now()-interval '1 minute' from generate_series(1,110) g;
insert into public.sec_incidents(organization_id,site_id,subject,priority,state,occurred_at) values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000142','Other site confidential','P2','new',now()-interval '1 minute');

-- Synthetic ERP and visitor fixtures (disposable only).
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000191','10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','QA maintenance device','environment');
insert into public.sec_work_orders(id,organization_id,site_id,subject,kind,reporter_id,request_id) values ('40000000-0000-0000-0000-000000000192','10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','QA maintenance order','inspection','00000000-0000-0000-0000-000000000141',gen_random_uuid());
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000141',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000141','30000000-0000-0000-0000-000000000191','visitor','{"reference":"qa-e2e-visit","purpose":"meeting","duration_minutes":120}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000144',true);
select public.sec_review_module_request('30000000-0000-0000-0000-000000000191','10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','reviewed','E2E fixture');
commit;
