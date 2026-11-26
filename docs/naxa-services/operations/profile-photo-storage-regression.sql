begin;
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000083');
insert into auth.sessions(id,user_id,created_at,updated_at) values ('11000000-0000-4000-8000-000000000083','10000000-0000-4000-8000-000000000083',now(),now());
insert into public.ns_organizations(id,display_name,business_mode) values ('20000000-0000-4000-8000-000000000083','QA photo','solo');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000083','10000000-0000-4000-8000-000000000083','NS-QA83','ns-qa83@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000083','20000000-0000-4000-8000-000000000083','50000000-0000-4000-8000-000000000083','QA','promoter');
insert into public.ns_devices(id,account_id,installation_id,platform,session_id) values ('70000000-0000-4000-8000-000000000083','50000000-0000-4000-8000-000000000083','qa83','web','11000000-0000-4000-8000-000000000083');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000083',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000083","session_id":"11000000-0000-4000-8000-000000000083","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if not public.ns_can_access_profile_photo('20000000-0000-4000-8000-000000000083/60000000-0000-4000-8000-000000000083/avatar.png') then raise exception 'OWN_PHOTO_DENIED'; end if;
 if public.ns_can_access_profile_photo('20000000-0000-4000-8000-000000000084/60000000-0000-4000-8000-000000000083/avatar.png') then raise exception 'FOREIGN_ORG_ALLOWED'; end if;
 if public.ns_can_access_profile_photo('20000000-0000-4000-8000-000000000083/60000000-0000-4000-8000-000000000084/avatar.png') then raise exception 'FOREIGN_MEMBER_ALLOWED'; end if;
 if public.ns_can_access_profile_photo('20000000-0000-4000-8000-000000000083/60000000-0000-4000-8000-000000000083/avatar.pdf') then raise exception 'WRONG_TYPE_ALLOWED'; end if;
end $qa$;
reset role;
update public.ns_devices set revoked_at=now() where id='70000000-0000-4000-8000-000000000083';
set local role authenticated;
do $qa$ begin
 if public.ns_can_access_profile_photo('20000000-0000-4000-8000-000000000083/60000000-0000-4000-8000-000000000083/avatar.png') then raise exception 'REVOKED_DEVICE_ALLOWED'; end if;
end $qa$;
reset role;
rollback;
select 'PASS: profile photo own member, tenant isolation, extension and revoked session' result;