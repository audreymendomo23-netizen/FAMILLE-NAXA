begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000031'),('00000000-0000-0000-0000-000000000032');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000031','QA');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031','owner',true),('10000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000032','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000031','10000000-0000-0000-0000-000000000031','QA'),('20000000-0000-0000-0000-000000000032','10000000-0000-0000-0000-000000000031','QA denied');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',true),('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000032',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000031',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'media','{"reference":"cam-01","purpose":"inspection","consent":"yes","media":"video"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'media','{"reference":"audio-01","purpose":"interphonie","consent":"yes","media":"audio"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'access','{"reference":"badge-01","purpose":"maintenance","duration_minutes":30}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'alarm','{"reference":"zone-01","kind":"intrusion","detail":"Contrôle requis"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'visitor','{"reference":"visite-01","purpose":"rendez-vous","duration_minutes":30}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'vehicle','{"reference":"veh-01","purpose":"livraison","duration_minutes":45}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'sos','{"reference":"zone-01","detail":"Demande assistance"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'compatibility','{"reference":"modele-01","firmware":"1.0","protocol":"onvif"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'assignment','{"reference":"poste-01","purpose":"affectation","duration_minutes":60}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'payment','{"reference":"txn-qa","amount_fcfa":5000,"channel":"mobile_money"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'support','{"category":"technical","detail":"Diagnostic demandé"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'notification','{"channel":"push","preference":"enabled"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'language','{"locale":"en"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'admin','{"reference":"compte-01","purpose":"revue"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'evidence','{"reference":"preuve-01","digest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'backup','{"reference":"backup-01","purpose":"test-restauration"}'::jsonb);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'partner','{"reference":"installateur-01","purpose":"qualification"}'::jsonb);
do $qa$begin
 if (select count(*) from public.sec_module_requests)<>17 then raise exception 'requests missing';end if;
 if has_column_privilege(current_user,'public.sec_module_requests','state','UPDATE') or has_column_privilege(current_user,'public.sec_module_requests','state','INSERT') then raise exception 'state writable';end if;
 if public.sec_valid_module_request('media','{"reference":"x","purpose":"test","consent":"no","media":"audio"}') then raise exception 'consent bypass';end if;
 if public.sec_valid_module_request('payment','{"reference":"x","amount_fcfa":-1,"channel":"bank"}') then raise exception 'negative amount';end if;
 if public.sec_valid_module_request('admin','{"reference":"x","purpose":"test","role":"owner"}') then raise exception 'extra keys';end if;
 begin
 insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000032','00000000-0000-0000-0000-000000000031',gen_random_uuid(),'support','{"category":"technical","detail":"test"}'::jsonb);
 raise exception 'cross site accepted';exception when insufficient_privilege then null;end;
end $qa$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000032',true);
do $qa$begin
 if (select count(*) from public.sec_module_requests)<>0 then raise exception 'cross user leak';end if;
 begin
 insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000031','20000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000032',gen_random_uuid(),'admin','{"reference":"x","purpose":"test"}'::jsonb);
 raise exception 'operator admin request accepted';exception when insufficient_privilege then null;end;
end $qa$;
reset role;
set local role anon;
do $qa$begin if has_table_privilege(current_user,'public.sec_module_requests','SELECT') then raise exception 'anon read';end if;end $qa$;
reset role;
rollback;
