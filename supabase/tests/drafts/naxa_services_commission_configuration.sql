-- Append to v24 draft transaction on disposable PostgreSQL only.
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000241'),('10000000-0000-4000-8000-000000000242');
insert into public.ns_organizations(id,display_name,business_mode) values ('20000000-0000-4000-8000-000000000241','QA commission','multi_site_network'),('20000000-0000-4000-8000-000000000242','QA other','solo');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000241','10000000-0000-4000-8000-000000000241','QA-COM241','qa-com241@example.invalid',false),('50000000-0000-4000-8000-000000000242','10000000-0000-4000-8000-000000000242','QA-COM242','qa-com242@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','50000000-0000-4000-8000-000000000241','QA promoter','promoter'),('60000000-0000-4000-8000-000000000242','20000000-0000-4000-8000-000000000241','50000000-0000-4000-8000-000000000242','QA manager','site_manager');
insert into public.ns_sites(id,org_id,code,name) values ('30000000-0000-4000-8000-000000000241','20000000-0000-4000-8000-000000000241','QA241','QA site'),('30000000-0000-4000-8000-000000000242','20000000-0000-4000-8000-000000000242','QA242','QA foreign');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000241','organization','20000000-0000-4000-8000-000000000241',true,true,true);
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000241','60000000-0000-4000-8000-000000000242','site','30000000-0000-4000-8000-000000000241','30000000-0000-4000-8000-000000000241',true,true,true);
insert into public.ns_devices(account_id,installation_id,platform,label,session_id) values ('50000000-0000-4000-8000-000000000241','qa-com241','web','QA','qa-com241-session'),('50000000-0000-4000-8000-000000000242','qa-com242','web','QA','qa-com242-session');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000241',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000241","session_id":"qa-com241-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241'; s uuid:='30000000-0000-4000-8000-000000000241'; p uuid:='70000000-0000-4000-8000-000000000241'; q uuid:='70000000-0000-4000-8000-000000000242'; d date:='2026-11-27'; begin
 if jsonb_array_length(public.ns_automatic_commission_catalog(o)->'sites')<>1 or jsonb_array_length(public.ns_automatic_commission_catalog(o)->'members')<>2 then raise exception 'QA_CATALOG_SCOPE'; end if;
 if public.ns_read_automatic_commission_settings(o) is distinct from '{"enabled":false,"revision":0}'::jsonb then raise exception 'QA_DEFAULT'; end if;
 if public.ns_set_automatic_commission_settings(o,true,0) is distinct from '{"enabled":true,"revision":1}'::jsonb then raise exception 'QA_ENABLE'; end if;
 begin perform public.ns_set_automatic_commission_settings(o,false,0); raise exception 'QA_STALE'; exception when others then if sqlerrm not like '%NS_COMMISSION_CONFIG_CONFLICT%' then raise; end if; end;
 begin perform public.ns_publish_automatic_commission_policy(q,o,s,null,null,null,'qa',1,'percent_bps',null,null,d,null,'QA approved terms'); raise exception 'QA_NULL_RATE'; exception when others then if sqlerrm not like '%NS_COMMISSION_POLICY_INVALID%' then raise; end if; end;
 begin perform public.ns_publish_automatic_commission_policy(q,o,'30000000-0000-4000-8000-000000000242',null,null,null,'qa',1,'fixed_xaf',null,500,d,null,'QA approved terms'); raise exception 'QA_FOREIGN_SITE'; exception when others then if sqlerrm not like '%NS_COMMISSION_POLICY_SCOPE%' then raise; end if; end;
 if public.ns_publish_automatic_commission_policy(p,o,s,null,null,null,'qa',1,'percent_bps',1000,null,d,null,'QA approved terms')<>p then raise exception 'QA_APPROVAL'; end if;
 if public.ns_publish_automatic_commission_policy(p,o,s,null,null,null,'qa',1,'percent_bps',1000,null,d,null,'QA approved terms')<>p then raise exception 'QA_REPLAY'; end if;
 begin perform public.ns_publish_automatic_commission_policy(p,o,s,null,null,null,'qa',1,'percent_bps',2000,null,d,null,'QA approved terms'); raise exception 'QA_MUTATED_REPLAY'; exception when others then if sqlerrm not like '%NS_COMMISSION_POLICY_ID_CONFLICT%' then raise; end if; end;
 begin perform public.ns_publish_automatic_commission_policy(q,o,null,null,null,null,'qa2',1,'fixed_xaf',null,500,d,null,'QA approved terms'); raise exception 'QA_OVERLAP'; exception when others then if sqlerrm not like '%NS_COMMISSION_POLICY_AMBIGUOUS%' then raise; end if; end;
 if not public.ns_retire_automatic_commission_policy(o,p) then raise exception 'QA_RETIRE'; end if;
 if public.ns_publish_automatic_commission_policy(q,o,s,null,null,null,'qa',2,'fixed_xaf',null,500,d,null,'QA approved terms')<>q then raise exception 'QA_REPLACEMENT'; end if;
 if public.ns_set_automatic_commission_settings(o,false,1) is distinct from '{"enabled":false,"revision":2}'::jsonb then raise exception 'QA_DISABLE'; end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000242',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000242","session_id":"qa-com242-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000241'; begin
 begin perform public.ns_automatic_commission_catalog(o); raise exception 'QA_CATALOG_LEAK'; exception when others then if sqlerrm not like '%NS_COMMISSION_CONFIG_FORBIDDEN%' then raise; end if; end;
 if exists(select 1 from public.ns_commission_policy_versions where org_id=o) then raise exception 'QA_RULE_LEAK'; end if;
 begin perform public.ns_read_automatic_commission_settings(o); raise exception 'QA_MANAGER_READ'; exception when others then if sqlerrm not like '%NS_COMMISSION_CONFIG_FORBIDDEN%' then raise; end if; end;
 begin perform public.ns_set_automatic_commission_settings(o,true,2); raise exception 'QA_MANAGER_WRITE'; exception when others then if sqlerrm not like '%NS_COMMISSION_CONFIG_FORBIDDEN%' then raise; end if; end;
end $qa$;
reset role;
do $qa$ begin
 if has_function_privilege('anon','public.ns_set_automatic_commission_settings(uuid,boolean,bigint)','EXECUTE') then raise exception 'QA_ANON_EXECUTE'; end if;
 if exists(select 1 from public.ns_commission_entries where org_id='20000000-0000-4000-8000-000000000241') then raise exception 'QA_UNAUTHORIZED_LEDGER'; end if;
end $qa$;
select 'PASS: automatic commission configuration, promoter scope, default disabled, explicit rates, exact retry, overlap, retirement and no ledger mutation' as result;
