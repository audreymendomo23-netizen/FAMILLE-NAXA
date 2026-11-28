begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000391'),('00000000-0000-0000-0000-000000000392'),('00000000-0000-0000-0000-000000000393');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000391','QA roster');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000391','owner',true),('10000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000392','operator',true),('10000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000393','operator',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000391','10000000-0000-0000-0000-000000000391','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000391',true),('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000392',true),('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000393',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000391',true);
select public.sec_support_roster('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000392',true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000393',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000393','30000000-0000-0000-0000-000000000391','support','{"category":"technical","detail":"QA roster"}');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000392',true);
do $q$begin
 begin perform public.sec_support_roster('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000393',true);raise exception 'operator can enable agents';exception when insufficient_privilege then null;end;
 perform public.sec_support_action('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','30000000-0000-0000-0000-000000000391',gen_random_uuid(),'claim','{}');
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000391',true);
do $q$begin
 if public.sec_support_roster('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','00000000-0000-0000-0000-000000000392',false)->>'released'<>'1' then raise exception 'case not released';end if;
 if exists(select 1 from public.sec_support_messages where request_id='30000000-0000-0000-0000-000000000391') then raise exception 'owner privacy leak';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000392',true);
do $q$begin
 if exists(select 1 from public.sec_support_cases where id='30000000-0000-0000-0000-000000000391') or exists(select 1 from public.sec_support_messages where request_id='30000000-0000-0000-0000-000000000391') then raise exception 'revoked agent still reads';end if;
 begin perform public.sec_support_action('10000000-0000-0000-0000-000000000391','20000000-0000-0000-0000-000000000391','30000000-0000-0000-0000-000000000391',gen_random_uuid(),'claim','{}');raise exception 'revoked claim';exception when insufficient_privilege then null;end;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000393',true);
do $q$begin if not exists(select 1 from public.sec_support_cases where id='30000000-0000-0000-0000-000000000391' and agent_id is null and state='open') then raise exception 'client ticket lost';end if;end $q$;
reset role;rollback;
