-- Run only against disposable PostgreSQL after donor and candidate contracts.
begin;
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000001'),('10000000-0000-4000-8000-000000000002');
insert into public.ns_organizations(id,display_name,business_mode,status) values ('20000000-0000-4000-8000-000000000001','Fixture Services','multi_site_network','active');
insert into public.ns_sites(id,org_id,code,name) values ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','A','Fixture A'),('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','B','Fixture B');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,status,password_change_required) values ('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','BRIDGE-CI','bridge@example.invalid','active',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code,status) values ('60000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','Fixture manager','site_manager','active');
insert into public.ns_member_scopes(id,org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('70000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','60000000-0000-4000-8000-000000000001','site','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',true,true,true);
insert into public.ns_devices(id,account_id,installation_id,platform,label,remember_device,session_id) values ('80000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','ci-bridge','web','CI device',true,'ci-bridge-session');
insert into public.ns_support_requests(id,org_id,site_id,subject,description,priority,created_by) values ('90000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Fixture assistance','Fixture message','normal','60000000-0000-4000-8000-000000000001');
insert into public.sec_organizations(id,name,active) values ('21000000-0000-4000-8000-000000000001','Fixture Security',true);
insert into public.sec_sites(id,organization_id,name,active) values ('31000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','Security A',true),('31000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000001','Security B',true);
insert into public.sec_memberships(organization_id,user_id,role,active) values ('21000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','manager',true);
insert into public.sec_site_memberships(organization_id,site_id,user_id,active) values ('21000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',true);
insert into public.sec_devices(id,organization_id,site_id,label,kind) values ('81000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001','Camera A','camera'),('81000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002','Camera B','camera');
insert into public.sec_incidents(id,organization_id,site_id,device_id,subject,priority,state) values ('91000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','Fixture incident','P2','new');
insert into public.ns_v1_security_site_links values ('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001');
update famille_core.applications set status='active' where code='naxa_services';
insert into famille_core.organizations(id,legal_name,organization_type,status) values ('22000000-0000-4000-8000-000000000001','Fixture Central','company','active');
insert into famille_core.memberships(id,user_id,organization_id,app_id,status) select '62000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','22000000-0000-4000-8000-000000000001',id,'active' from famille_core.applications where code='naxa_services';
insert into famille_core.role_assignments(membership_id,app_id,organization_id,role_code) select id,app_id,organization_id,'owner' from famille_core.memberships where id='62000000-0000-4000-8000-000000000001';
insert into public.ns_v1_core_org_links values ('20000000-0000-4000-8000-000000000001','22000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","session_id":"ci-bridge-session"}',true);
set local role authenticated;
do $test$
declare snap jsonb; receipt jsonb;
begin
 snap:=public.ns_v1_security_snapshot('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001');
 if snap->>'state' is distinct from 'linked' or jsonb_array_length(snap->'devices') is distinct from 1 or snap->'devices'->0->>'label' is distinct from 'Camera A' or jsonb_array_length(snap->'incidents') is distinct from 1 then raise exception 'Security snapshot failed'; end if;
 begin
  perform public.ns_v1_security_snapshot('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002');
  raise exception 'Unauthorized site accepted';
 exception when insufficient_privilege then null; end;
 receipt:=public.ns_v1_forward_support_ticket('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');
 if receipt->>'state' is distinct from 'confirmed' then raise exception 'Ticket not forwarded'; end if;
 if public.ns_v1_forward_support_ticket('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001') is distinct from receipt then raise exception 'Replay changed receipt'; end if;
 if (select count(*) from famille_core.support_tickets where id='90000000-0000-4000-8000-000000000001') <> 1 then raise exception 'Ticket duplicate'; end if;
 begin
  delete from public.ns_v1_security_site_links;
  raise exception 'Client may modify mapping';
 exception when insufficient_privilege then null; end;
end $test$;
reset role;
update public.sec_site_memberships set active=false;
set local role authenticated;
do $test$
begin
 if public.ns_v1_security_snapshot('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001')->>'state' is distinct from 'unavailable' then raise exception 'Revoked SECURITY scope accepted'; end if;
end $test$;
reset role;
update public.ns_devices set revoked_at=now();
set local role authenticated;
do $test$
begin
 begin
  perform public.ns_v1_forward_support_ticket('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001');
  raise exception 'Revoked session accepted';
 exception when insufficient_privilege then null; end;
end $test$;
reset role;
select 'PASS scoped security snapshot, incident isolation, revoked security membership, canonical central ticket, idempotence, denied mapping writes and revoked session';
rollback;
