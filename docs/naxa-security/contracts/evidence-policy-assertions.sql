begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000431'),('00000000-0000-0000-0000-000000000432');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000431','QA capacity');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000431','00000000-0000-0000-0000-000000000431','owner',true),('10000000-0000-0000-0000-000000000431','00000000-0000-0000-0000-000000000432','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000431','10000000-0000-0000-0000-000000000431','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431','00000000-0000-0000-0000-000000000431',true),('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431','00000000-0000-0000-0000-000000000432',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000431',true);
select public.sec_evidence_site_policy('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431',3,30,true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000432',true);
do $q$declare v jsonb;begin
 v:=public.sec_service_action('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431','40000000-0000-0000-0000-000000000431','evidence_store',null,'{"reference":"quota-test","digest":"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","base64":"YWJj"}');
 if v->>'state'<>'stored' or v<>public.sec_service_action('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431','40000000-0000-0000-0000-000000000431','evidence_store',null,'{"reference":"quota-test","digest":"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","base64":"YWJj"}') then raise exception 'idempotency';end if;
 begin perform public.sec_service_action('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431',gen_random_uuid(),'evidence_store',null,'{"reference":"quota-test","digest":"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","base64":"YWJj"}');raise exception 'limit bypass';exception when invalid_parameter_value then null;end;
 begin perform public.sec_evidence_site_policy('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431',100,30,false);raise exception 'operator config';exception when insufficient_privilege then null;end;
end $q$;
reset role;
update public.sec_evidence_files set created_at=now()-interval '40 days' where id='40000000-0000-0000-0000-000000000431';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000431',true);
do $q$declare v jsonb;begin
 v:=public.sec_evidence_site_policy('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431');if v->>'total_bytes'<>'3' or v->>'unreferenced_old_files'<>'0' or v->>'legal_hold'<>'true' then raise exception 'hold';end if;
 v:=public.sec_evidence_site_policy('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431',6,30,false);if v->>'unreferenced_old_files'<>'1' or v->>'preview_only'<>'true' or v->>'commercial_quota'<>'false' then raise exception 'preview';end if;
 begin perform public.sec_evidence_site_policy('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431',2,30,true);raise exception 'below used';exception when invalid_parameter_value then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000432',true);
select public.sec_service_action('10000000-0000-0000-0000-000000000431','20000000-0000-0000-0000-000000000431',gen_random_uuid(),'evidence_store',null,'{"reference":"quota-test","digest":"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","base64":"YWJj"}');
do $q$begin if (select count(*) from public.sec_evidence_files where organization_id='10000000-0000-0000-0000-000000000431')<>2 then raise exception 'retention removed or quota failed';end if;end $q$;
reset role;rollback;
