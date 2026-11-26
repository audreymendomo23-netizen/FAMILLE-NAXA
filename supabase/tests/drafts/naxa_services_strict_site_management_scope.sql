-- Requires hosted strict-site-scope migration. Disposable fixtures; rollback always.
begin;
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000081');
insert into public.ns_organizations(id,display_name,business_mode) values ('20000000-0000-4000-8000-000000000081','QA scope A','multi_site_network'),('20000000-0000-4000-8000-000000000082','QA scope B','solo');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000081','10000000-0000-4000-8000-000000000081','NS-QA81','qa81@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000081','20000000-0000-4000-8000-000000000081','50000000-0000-4000-8000-000000000081','QA manager','site_manager');
insert into public.ns_sites(id,org_id,code,name) values ('30000000-0000-4000-8000-000000000081','20000000-0000-4000-8000-000000000081','QA81','QA A'),('30000000-0000-4000-8000-000000000082','20000000-0000-4000-8000-000000000082','QA82','QA B');
insert into public.ns_workstations(id,org_id,site_id,code,name,kind) values ('40000000-0000-4000-8000-000000000081','20000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081','QA81','QA workstation','other');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,workstation_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000081','60000000-0000-4000-8000-000000000081','workstation','40000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081','40000000-0000-4000-8000-000000000081',true,true,true);
insert into public.ns_devices(account_id,installation_id,platform,label,session_id) values ('50000000-0000-4000-8000-000000000081','qa-81','web','QA','qa-81-session');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000081',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000081","session_id":"qa-81-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if public.ns_can_manage_site('20000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081') is distinct from false then raise exception 'WORKSTATION_SCOPE_WIDENED'; end if;
 if public.ns_can_operate_workstation('20000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081','40000000-0000-4000-8000-000000000081') is distinct from true then raise exception 'WORKSTATION_SCOPE_LOST'; end if;
end $qa$;
reset role;
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000081','60000000-0000-4000-8000-000000000081','site','30000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081',true,true,true);
set local role authenticated;
do $qa$ begin
 if public.ns_can_manage_site('20000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081') is distinct from true then raise exception 'VALID_SITE_SCOPE_REJECTED'; end if;
end $qa$;
reset role;
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000081','60000000-0000-4000-8000-000000000081','organization','20000000-0000-4000-8000-000000000081',true,true,true);
set local role authenticated;
do $qa$ begin
 if public.ns_can_manage_site('20000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000081') is distinct from true then raise exception 'VALID_ORG_SCOPE_REJECTED'; end if;
 if public.ns_can_manage_site('20000000-0000-4000-8000-000000000081','30000000-0000-4000-8000-000000000082') is distinct from false then raise exception 'FOREIGN_SITE_ACCEPTED'; end if;
end $qa$;
reset role;
rollback;
select 'PASS: strict site scope, five assertions' as result;
