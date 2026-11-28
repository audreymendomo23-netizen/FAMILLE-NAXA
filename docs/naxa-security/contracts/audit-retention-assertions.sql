begin;
insert into auth.users values ('00000000-0000-0000-0000-000000000271'),('00000000-0000-0000-0000-000000000272');
insert into public.sec_organizations(id,name) values ('10000000-0000-0000-0000-000000000271','QA retention');
insert into public.sec_memberships values ('10000000-0000-0000-0000-000000000271','00000000-0000-0000-0000-000000000271','owner',true),('10000000-0000-0000-0000-000000000271','00000000-0000-0000-0000-000000000272','manager',true);
insert into public.sec_sites(id,organization_id,name) values ('20000000-0000-0000-0000-000000000271','10000000-0000-0000-0000-000000000271','QA');
insert into public.sec_site_memberships values ('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271','00000000-0000-0000-0000-000000000271',true),('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271','00000000-0000-0000-0000-000000000272',true);
insert into public.sec_access_audit(organization_id,site_id,actor_id,operation,created_at) values ('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271','00000000-0000-0000-0000-000000000272','integration_list_read',now()-interval '45 days');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000271',true);
do $q$declare j jsonb;begin
 j:=public.sec_audit_retention('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271');
 if (j->>'configured')::boolean or not (j->>'legal_hold')::boolean then raise exception 'unsafe default';end if;
 j:=public.sec_audit_retention('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271',30,true);
 if (j->>'access_trace_candidates')::int<>0 then raise exception 'hold failed';end if;
 j:=public.sec_audit_retention('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271',30,false);
 if (j->>'access_trace_candidates')::int<>1 or not (j->>'preview_only')::boolean then raise exception 'preview inaccurate';end if;
 if has_table_privilege(current_user,'sec_private.audit_retention_policy','UPDATE') then raise exception 'policy direct write';end if;
end $q$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000272',true);
do $q$begin
 begin perform public.sec_audit_retention('10000000-0000-0000-0000-000000000271','20000000-0000-0000-0000-000000000271',1,false);raise exception 'manager configured policy';exception when insufficient_privilege then null;end;
 if (select count(*) from public.sec_access_audit)<>1 then raise exception 'data deleted';end if;
end $q$;
reset role;rollback;
