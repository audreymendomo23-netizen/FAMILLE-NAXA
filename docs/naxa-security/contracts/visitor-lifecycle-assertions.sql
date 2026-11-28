begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000441'),('00000000-0000-0000-0000-000000000442');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000441','QA visitor lifecycle');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000441','00000000-0000-0000-0000-000000000441','manager',true),('10000000-0000-0000-0000-000000000441','00000000-0000-0000-0000-000000000442','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000441','10000000-0000-0000-0000-000000000441','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','00000000-0000-0000-0000-000000000441',true),('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','00000000-0000-0000-0000-000000000442',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000442',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','00000000-0000-0000-0000-000000000442','30000000-0000-0000-0000-000000000441','visitor','{"reference":"QA-visit","purpose":"meeting","duration_minutes":60}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000441',true);
select public.sec_review_module_request('30000000-0000-0000-0000-000000000441','10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','reviewed','QA review');
select public.sec_visit_pass('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','50000000-0000-0000-0000-000000000441','issue',(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000441'),'{"token":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","minutes":30}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000442',true);
do $q$declare reg uuid:=(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000441');begin
 perform public.sec_field_action('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441',gen_random_uuid(),'passage',reg,'{"direction":"entry","reason":"QA entry"}');
 begin perform public.sec_visitor_lifecycle('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','cancel',reg,gen_random_uuid(),'QA forbidden');raise exception 'operator cancel';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000441',true);
do $q$declare reg uuid:=(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000441');e uuid:=gen_random_uuid();v jsonb;begin
 v:=public.sec_visitor_lifecycle('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','cancel',reg,e,'QA cancelled');
 if v->>'revoked_passes'<>'1' or v<>public.sec_visitor_lifecycle('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','cancel',reg,e,'QA cancelled') then raise exception 'cancellation receipt';end if;
 if public.sec_visitor_lifecycle('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','list')->'rows'->0->>'state'<>'inside' then raise exception 'visitor still inside';end if;
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441',gen_random_uuid(),'issue',reg,'{"token":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","minutes":10}');raise exception 'cancelled issue';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000442',true);
do $q$declare reg uuid:=(select id from public.sec_service_register where request_id='30000000-0000-0000-0000-000000000441');begin
 begin perform public.sec_visit_pass('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441',gen_random_uuid(),'consume_entry','50000000-0000-0000-0000-000000000441','{"token":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}');raise exception 'cancelled code';exception when insufficient_privilege then null;end;
 perform public.sec_field_action('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441',gen_random_uuid(),'passage',reg,'{"direction":"exit","reason":"QA exit"}');
 if public.sec_visitor_lifecycle('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','list')->'rows'->0->>'state'<>'cancelled' then raise exception 'cancelled after exit';end if;
 begin perform public.sec_field_action('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441',gen_random_uuid(),'passage',reg,'{"direction":"entry","reason":"QA forbidden"}');raise exception 'reentry allowed';exception when invalid_parameter_value then null;end;
 if jsonb_array_length(public.sec_visitor_lifecycle('10000000-0000-0000-0000-000000000441','20000000-0000-0000-0000-000000000441','history',reg)->'rows')<>2 then raise exception 'history';end if;
end $q$;
reset role;rollback;
