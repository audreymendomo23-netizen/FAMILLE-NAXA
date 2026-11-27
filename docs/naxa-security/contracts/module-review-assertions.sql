begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000041'),('00000000-0000-0000-0000-000000000042'),('00000000-0000-0000-0000-000000000043');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000041','QA review');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000041','operator',true),('10000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000042','manager',true),('10000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000043','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000041','10000000-0000-0000-0000-000000000041','QA authorized'),('20000000-0000-0000-0000-000000000042','10000000-0000-0000-0000-000000000041','QA other');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000041',true),('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000042',true),('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000042','00000000-0000-0000-0000-000000000043',true);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
insert into public.sec_module_requests(organization_id,site_id,reporter_id,request_id,kind,payload) values ('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000041','30000000-0000-0000-0000-000000000041','visitor','{"reference":"visit-qa","purpose":"test","duration_minutes":30}'),('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000041','30000000-0000-0000-0000-000000000042','support','{"category":"privacy","detail":"test"}');
do $qa$begin
 if (select count(*) from public.sec_module_review_queue('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041'))<>0 then raise exception 'operator sees review queue';end if;
 begin perform public.sec_review_module_request('30000000-0000-0000-0000-000000000041','10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','reviewed','QA');raise exception 'self review';exception when insufficient_privilege then null;end;
end $qa$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000043',true);
do $qa$begin
 if (select count(*) from public.sec_module_review_queue('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041'))<>0 then raise exception 'cross site queue';end if;
 begin perform public.sec_review_module_request('30000000-0000-0000-0000-000000000041','10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','reviewed','QA');raise exception 'cross site review';exception when insufficient_privilege then null;end;
end $qa$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000042',true);
do $qa$declare receipt jsonb;begin
 if (select count(*) from public.sec_module_review_queue('10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041'))<>1 then raise exception 'wrong queue privacy';end if;
 if has_column_privilege(current_user,'public.sec_module_requests','reviewed_by','UPDATE') then raise exception 'direct update';end if;
 receipt:=public.sec_review_module_request('30000000-0000-0000-0000-000000000041','10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','reviewed','QA');
 if receipt->>'state'<>'reviewed' then raise exception 'review missing';end if;
 if public.sec_review_module_request('30000000-0000-0000-0000-000000000041','10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','reviewed','QA')<>receipt then raise exception 'retry changed receipt';end if;
 begin perform public.sec_review_module_request('30000000-0000-0000-0000-000000000041','10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','declined','changed');raise exception 'review overwritten';exception when unique_violation then null;end;
 begin perform public.sec_review_module_request('30000000-0000-0000-0000-000000000042','10000000-0000-0000-0000-000000000041','20000000-0000-0000-0000-000000000041','reviewed','QA');raise exception 'private support review';exception when insufficient_privilege then null;end;
end $qa$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000041',true);
do $qa$begin if (select count(*) from public.sec_module_requests where state='reviewed' and reviewed_by='00000000-0000-0000-0000-000000000042')<>1 then raise exception 'requester cannot read disposition';end if;end $qa$;
reset role;
rollback;
