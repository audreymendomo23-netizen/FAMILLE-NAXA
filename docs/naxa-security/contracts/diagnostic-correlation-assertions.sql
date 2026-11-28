begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000121'),('00000000-0000-0000-0000-000000000122'),('00000000-0000-0000-0000-000000000123');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000121','QA diagnostics');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000121','operator',true),('10000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000122','manager',true),('10000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000123','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','QA'),('20000000-0000-0000-0000-000000000122','10000000-0000-0000-0000-000000000121','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000121',true),('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','00000000-0000-0000-0000-000000000122',true),('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000122','00000000-0000-0000-0000-000000000123',true);
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','QA gateway','gateway'),('40000000-0000-0000-0000-000000000122','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','QA sensor','environment'),('40000000-0000-0000-0000-000000000123','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','QA smoke','smoke');
insert into sec_private.gateway_bindings(gateway_id,organization_id,site_id,device_id) values ('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','40000000-0000-0000-0000-000000000122'),('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','40000000-0000-0000-0000-000000000123');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000121',true);
select public.sec_request_diagnostic('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000122','40000000-0000-0000-0000-000000000122','QA health check');
do $q$begin
 begin perform public.sec_authorize_diagnostic('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000122');raise exception 'self approval';exception when insufficient_privilege then null;end;
 if has_function_privilege(current_user,'sec_private.complete_diagnostic(uuid,uuid,uuid,uuid,uuid)','EXECUTE') then raise exception 'client completion';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000123',true);
do $q$begin if (select count(*) from public.sec_diagnostic_requests)<>0 then raise exception 'cross site';end if;
 begin perform public.sec_authorize_diagnostic('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000122');raise exception 'cross site approval';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000122',true);
select public.sec_authorize_diagnostic('10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000122');
reset role;set local role sec_gateway_ingest;
select sec_private.ingest_observation('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','40000000-0000-0000-0000-000000000122','50000000-0000-0000-0000-000000000121',now(),'fault',null,null);
select sec_private.ingest_fire('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','40000000-0000-0000-0000-000000000123','50000000-0000-0000-0000-000000000123',now(),'alarm');
do $q$declare j jsonb;begin
 j:=sec_private.complete_diagnostic('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000122','50000000-0000-0000-0000-000000000121');
 if j->>'state'<>'completed' or j->>'observed_status'<>'fault' or j->>'physical_action'<>'false' then raise exception 'wrong diagnostic';end if;
 if sec_private.complete_diagnostic('40000000-0000-0000-0000-000000000121','10000000-0000-0000-0000-000000000121','20000000-0000-0000-0000-000000000121','50000000-0000-0000-0000-000000000122','50000000-0000-0000-0000-000000000121')<>j then raise exception 'retry mismatch';end if;
end $q$;
reset role;set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000121',true);
do $q$begin
 if (select count(*) from public.sec_signal_correlations where source_state='alarm' and nearby_warnings=1 and human_review_required)<>1 then raise exception 'correlation lost alarm';end if;
 if (select count(*) from public.sec_diagnostic_requests where state='completed')<>1 then raise exception 'receipt missing';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000123',true);
do $q$begin if (select count(*) from public.sec_signal_correlations)<>0 then raise exception 'cross site correlation';end if;end $q$;
reset role;rollback;
