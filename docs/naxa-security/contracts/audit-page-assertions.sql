begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000251'),('00000000-0000-0000-0000-000000000252');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000251','QA audit pages');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000251','manager',true),('10000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000252','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000251','10000000-0000-0000-0000-000000000251','QA'),('20000000-0000-0000-0000-000000000252','10000000-0000-0000-0000-000000000251','Other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000251',true),('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000252','00000000-0000-0000-0000-000000000252',true);
insert into public.sec_field_events(id,organization_id,site_id,actor_id,operation,detail,result) select gen_random_uuid(),'10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','00000000-0000-0000-0000-000000000251','qa_page','{"secret":"synthetic"}','{"state":"recorded"}' from generate_series(1,121);
insert into public.sec_field_events(id,organization_id,site_id,actor_id,operation,detail,result) values(gen_random_uuid(),'10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000252','00000000-0000-0000-0000-000000000252','qa_other','{}','{}');
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
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000251',true);
do $q$declare j jsonb;begin
 j:=public.sec_audit_export('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','field',now()-interval '1 day',now()+interval '30 seconds');
 if (j->>'count')::int is distinct from 121 or jsonb_array_length(j->'rows')<>121 or j::text like '%synthetic%' or j::text like '%qa_other%' then raise exception 'full export incomplete or leaked';end if;
 if not exists(select 1 from public.sec_access_audit where id=(j->>'export_id')::uuid and operation='audit_export') then raise exception 'export trace absent';end if;
 begin perform public.sec_audit_export('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000252','all',now()-interval '1 day',now());raise exception 'cross site export';exception when insufficient_privilege then null;end;
 begin perform public.sec_audit_export('10000000-0000-0000-0000-000000000251','20000000-0000-0000-0000-000000000251','all',now()-interval '367 days',now());raise exception 'unbounded export';exception when invalid_parameter_value then null;end;
end $q$;
reset role;rollback;
