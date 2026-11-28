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

-- Independent synthetic commercial, GPS and reviewed shift lifecycle fixture.
insert into auth.users values ('00000000-0000-0000-0000-000000000361'),('00000000-0000-0000-0000-000000000362');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000361','QA complete journey');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000361','owner',true),('10000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000362','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000361','10000000-0000-0000-0000-000000000361','QA lifecycle site');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000361',true),('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000362',true);
insert into public.sec_payment_receipts(organization_id,site_id,channel,reference,amount_fcfa,provider_confirmed_at) values ('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','bank','qa-journey-a',5000,now()),('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','bank','qa-journey-b',20000,now());
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000361','10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','QA gateway','gateway'),('40000000-0000-0000-0000-000000000362','10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','QA tracker','tracker');
insert into sec_private.gateway_bindings values ('40000000-0000-0000-0000-000000000361','10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','40000000-0000-0000-0000-000000000362',true);
insert into public.sec_shifts(id,organization_id,site_id,agent_id,created_by,label,starts_at,ends_at,state) values ('40000000-0000-0000-0000-000000000363','10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000362','00000000-0000-0000-0000-000000000361','QA complete shift',now()-interval '8 hours',now()-interval '1 hour','completed');
insert into public.sec_attendance_drafts(organization_id,site_id,reporter_id,request_id,action,lat,lon,accuracy_m,observed_at,source,mock_reported,state)
select '10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000362',gen_random_uuid(),a,4,9,10,now()-t,'browser',null,'reviewed' from (values('arrival',interval '7 hours 50 minutes'),('pause_start',interval '5 hours'),('pause_end',interval '4 hours 30 minutes'),('departure',interval '1 hour 10 minutes')) v(a,t);
begin;set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000361',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000361','30000000-0000-0000-0000-000000000361','payment','{"reference":"qa-journey-a","amount_fcfa":5000,"channel":"bank"}'),('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','00000000-0000-0000-0000-000000000361','30000000-0000-0000-0000-000000000362','payment','{"reference":"qa-journey-b","amount_fcfa":20000,"channel":"bank"}');
select public.sec_tracker_manage('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','40000000-0000-0000-0000-000000000362','QA vehicle',true);
select public.sec_create_geofence('10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361',gen_random_uuid(),'QA depot',4,9,100);
reset role;set local role sec_gateway_ingest;
select sec_private.ingest_asset_position('40000000-0000-0000-0000-000000000361','10000000-0000-0000-0000-000000000361','20000000-0000-0000-0000-000000000361','40000000-0000-0000-0000-000000000362',gen_random_uuid(),now(),4,9,10);
commit;

-- Additional expressly provisioned synthetic Livecare recipient.
insert into auth.users values ('00000000-0000-0000-0000-000000000145');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000145','operator',true);
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000145',true);
insert into sec_private.support_agents values ('10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000145',true);

-- Synthetic evidence for Livecare attachment journey.
insert into public.sec_evidence_files(id,organization_id,site_id,owner_id,reference,digest,size_bytes) values ('40000000-0000-0000-0000-000000000381','10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000141','QA-support-proof','ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',3);
insert into sec_private.evidence_content values ('40000000-0000-0000-0000-000000000381',decode('YWJj','base64'));

-- Deliberately corrupted synthetic evidence; detection must not repair or conceal it.
insert into public.sec_evidence_files(id,organization_id,site_id,owner_id,reference,digest,size_bytes) values ('40000000-0000-0000-0000-000000000403','10000000-0000-0000-0000-000000000141','20000000-0000-0000-0000-000000000141','00000000-0000-0000-0000-000000000141','QA-corrupted-proof','ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',3);
insert into sec_private.evidence_content values ('40000000-0000-0000-0000-000000000403',decode('eHl6','base64'));
