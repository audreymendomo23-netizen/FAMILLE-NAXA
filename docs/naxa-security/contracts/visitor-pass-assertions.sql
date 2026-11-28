begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000171'),('00000000-0000-0000-0000-000000000172'),('00000000-0000-0000-0000-000000000173');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000171','QA pass');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000171','00000000-0000-0000-0000-000000000171','manager',true),('10000000-0000-0000-0000-000000000171','00000000-0000-0000-0000-000000000172','operator',true),('10000000-0000-0000-0000-000000000171','00000000-0000-0000-0000-000000000173','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000171','10000000-0000-0000-0000-000000000171','QA'),('20000000-0000-0000-0000-000000000172','10000000-0000-0000-0000-000000000171','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','00000000-0000-0000-0000-000000000171',true),('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','00000000-0000-0000-0000-000000000172',true),('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000172','00000000-0000-0000-0000-000000000173',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000172',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','00000000-0000-0000-0000-000000000172','30000000-0000-0000-0000-000000000171','visitor','{"reference":"qa-visitor","purpose":"meeting","duration_minutes":30}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000171',true);
select public.sec_review_module_request('30000000-0000-0000-0000-000000000171','10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','reviewed','QA');
do $q$declare j jsonb;begin
 j:=public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000171','issue',(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000171'),'{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","minutes":60}');
 if j->>'state'<>'issued' or j->>'physical_access'<>'false' or (j->>'expires_at')::timestamptz>now()+interval '30 minutes' or public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000171','issue',(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000171'),'{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","minutes":60}')<>j then raise exception 'issue invalid';end if;
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000172','issue',(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000171'),'{"token":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","minutes":10}');raise exception 'duplicate active pass';exception when unique_violation then null;end;
 if has_table_privilege(current_user,'sec_private.visit_pass_hashes','SELECT') then raise exception 'hash exposed';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000173',true);
do $q$begin
 if (select count(*) from public.sec_visit_passes)<>0 then raise exception 'cross-site leak';end if;
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000173','consume','50000000-0000-0000-0000-000000000171','{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}');raise exception 'cross-site pass';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000172',true);
do $q$declare j jsonb;begin
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000174','consume','50000000-0000-0000-0000-000000000171','{"token":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}');raise exception 'wrong token';exception when insufficient_privilege then null;end;
 j:=public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000175','consume','50000000-0000-0000-0000-000000000171','{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}');
 if j->>'state'<>'checked' or public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000175','consume','50000000-0000-0000-0000-000000000171','{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}')<>j then raise exception 'consume invalid';end if;
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000176','consume','50000000-0000-0000-0000-000000000171','{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}');raise exception 'reused token';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000171',true);
select public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000177','issue',(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000171'),'{"token":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","minutes":10}');
select public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000178','revoke','50000000-0000-0000-0000-000000000177','{}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000172',true);
do $q$begin
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000171','20000000-0000-0000-0000-000000000171','50000000-0000-0000-0000-000000000179','consume','50000000-0000-0000-0000-000000000177','{"token":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}');raise exception 'revoked pass accepted';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
