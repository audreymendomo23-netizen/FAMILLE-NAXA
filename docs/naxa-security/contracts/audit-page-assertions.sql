begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000251'),('00000000-0000-0000-0000-000000000252');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000251','QA audit pages');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000251','manager',true),('10000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000252','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000251','10000000-0000-0000-0000-000000000251','QA'),('20000000-0000-0000-0000-000000000252','10000000-0000-0000-0000-000000000251','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000251',true),('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000252','00000000-0000-0000-0000-000000000252',true);
insert into public.sec_field_events(id,organization_id,site_id,actor_id,operation,detail,result) select gen_random_uuid(),'10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000251','qa_page','{"secret":"synthetic"}','{"state":"recorded"}' from generate_series(1,121);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000251',true);
do $q$declare a jsonb;b jsonb;begin
 a:=public.sec_audit_page('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','field',null);
 b:=public.sec_audit_page('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','field',a->'next');
 if jsonb_array_length(a->'rows')<>100 or jsonb_array_length(b->'rows')<>21 or b->'next'<>'null'::jsonb or (a::text||b::text) like '%synthetic%' then raise exception 'page incorrect or payload leaked';end if;
 if exists(select 1 from jsonb_array_elements(a->'rows') x join jsonb_array_elements(b->'rows') y on x->>'id'=y->>'id') then raise exception 'duplicate page event';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000252',true);
do $q$begin
 begin perform public.sec_audit_page('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','all',null);raise exception 'cross site audit page';exception when insufficient_privilege then null;end;
end $q$;
reset role;rollback;
