-- Disposable PostgreSQL only, fixture identities; no real auth data.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
insert into public.wm_accounts(id,auth_user_id,login_id,auth_alias,display_name) values
('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','WM-FIXTURE1','wm1@example.invalid','Fixture One'),
('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','WM-FIXTURE2','wm2@example.invalid','Fixture Two');
insert into public.wm_workspaces(id,kind,name) values
('20000000-0000-4000-8000-000000000001','enterprise','Fixture A'),
('20000000-0000-4000-8000-000000000002','enterprise','Fixture B');
insert into public.wm_memberships(account_id,workspace_id,role) values
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','promoteur'),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','promoteur');
do $$ begin
 if has_table_privilege('anon','public.wm_accounts','SELECT') or has_table_privilege('authenticated','public.wm_device_sessions','SELECT') or has_function_privilege('authenticated','public.wm_issue_device_session(uuid,uuid,uuid,text)','EXECUTE') then raise exception 'public grant leak';end if;
 if (select count(*) from pg_class where relname in ('wm_accounts','wm_workspaces','wm_memberships','wm_device_sessions') and relrowsecurity)<>4 then raise exception 'rls missing';end if;
end $$;
insert into public.wm_workspaces(id,kind,name) values('20000000-0000-4000-8000-000000000003','individual','Fixture Personal');
insert into public.wm_memberships(account_id,workspace_id,role) values('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','owner');
set local role service_role;
select public.wm_issue_device_session('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',repeat('a',64));
select public.wm_issue_device_session('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',repeat('b',64));
do $$ begin
 if (select count(*) from public.wm_device_sessions where revoked_at is null)<>1 then raise exception 'rotation failed';end if;
 if not exists(select 1 from public.wm_device_sessions where token_hash=repeat('a',64) and revoked_at is not null) then raise exception 'old token active';end if;
 begin
 perform public.wm_issue_device_session('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002',repeat('c',64));
 raise exception 'cross workspace accepted' using errcode='XX000';
 exception when raise_exception then null;
 end;
 if not exists(select 1 from public.wm_session_context(repeat('b',64))) then raise exception 'valid context rejected';end if;
 if exists(select 1 from public.wm_session_context(repeat('a',64))) then raise exception 'revoked context accepted';end if;
 begin
 perform public.wm_switch_workspace(repeat('b',64),'20000000-0000-4000-8000-000000000002',repeat('e',64));
 raise exception 'foreign switch accepted' using errcode='XX000';
 exception when raise_exception then null;
 end;
 perform public.wm_switch_workspace(repeat('b',64),'20000000-0000-4000-8000-000000000003',repeat('f',64));
 if exists(select 1 from public.wm_session_context(repeat('b',64))) then raise exception 'old switch token active';end if;
 if not exists(select 1 from public.wm_session_context(repeat('f',64)) where workspace_id='20000000-0000-4000-8000-000000000003') then raise exception 'switch scope invalid';end if;
 if (select expires_at from public.wm_device_sessions where token_hash=repeat('b',64))<>(select expires_at from public.wm_device_sessions where token_hash=repeat('f',64)) then raise exception 'switch extended lease';end if;
 update public.wm_memberships set enabled=false where account_id='10000000-0000-4000-8000-000000000001';
 if exists(select 1 from public.wm_session_context(repeat('f',64))) then raise exception 'disabled context accepted';end if;
 begin
 perform public.wm_issue_device_session('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',repeat('d',64));
 raise exception 'disabled membership accepted' using errcode='XX000';
 exception when raise_exception then null;
 end;
end $$;
reset role;
-- Additional independent negative cases; all fixtures rolled back.
do $$ begin
 if has_function_privilege('anon','public.wm_session_context(text)','EXECUTE') or has_function_privilege('authenticated','public.wm_switch_workspace(text,uuid,text)','EXECUTE') then raise exception 'function grant leak';end if;
 if has_table_privilege('anon','public.wm_memberships','SELECT') or has_table_privilege('authenticated','public.wm_accounts','UPDATE') then raise exception 'table grant leak';end if;
end $$;
set local role service_role;
update public.wm_memberships set enabled=true where account_id='10000000-0000-4000-8000-000000000001';
select public.wm_issue_device_session('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',repeat('1',64));
do $$ begin
 if not exists(select 1 from public.wm_session_context(repeat('1',64))) then raise exception 'active session missing';end if;
 update public.wm_workspaces set enabled=false where id='20000000-0000-4000-8000-000000000001';
 if exists(select 1 from public.wm_session_context(repeat('1',64))) then raise exception 'disabled workspace accepted';end if;
 update public.wm_workspaces set enabled=true where id='20000000-0000-4000-8000-000000000001';
 update public.wm_accounts set enabled=false where id='10000000-0000-4000-8000-000000000001';
 if exists(select 1 from public.wm_session_context(repeat('1',64))) then raise exception 'disabled account accepted';end if;
 update public.wm_accounts set enabled=true,password_change_required=true where id='10000000-0000-4000-8000-000000000001';
 begin
 perform public.wm_switch_workspace(repeat('1',64),'20000000-0000-4000-8000-000000000003',repeat('2',64));
 raise exception 'password gate bypass' using errcode='XX000';
 exception when raise_exception then null;
 end;
 update public.wm_accounts set password_change_required=false where id='10000000-0000-4000-8000-000000000001';
 update public.wm_device_sessions set created_at=now()-interval '2 hours',expires_at=now()-interval '1 hour' where token_hash=repeat('1',64);
 if exists(select 1 from public.wm_session_context(repeat('1',64))) then raise exception 'expired session accepted';end if;
end $$;
reset role;

-- N1 throttle: shared identifier across installations, shared device across identifiers,
-- reset after window, no direct client privileges.
do $wm$ begin
 if has_function_privilege('anon','public.wm_reserve_auth_attempt(text,text)','EXECUTE') or has_function_privilege('authenticated','public.wm_reserve_auth_attempt(text,text)','EXECUTE') or has_table_privilege('authenticated','public.wm_auth_attempt_buckets','SELECT') then raise exception 'throttle acl leak';end if;
 if not exists(select 1 from pg_class where oid='public.wm_auth_attempt_buckets'::regclass and relrowsecurity) then raise exception 'throttle rls missing';end if;
end $wm$;
set local role service_role;
do $wm$ declare i integer; begin
 for i in 1..5 loop
  if not public.wm_reserve_auth_attempt(repeat('a',64),repeat('b',64)) then raise exception 'premature throttle';end if;
 end loop;
 if public.wm_reserve_auth_attempt(repeat('a',64),repeat('c',64)) then raise exception 'identifier limit bypass';end if;
 for i in 1..20 loop
  if not public.wm_reserve_auth_attempt(lpad(to_hex(i),64,'0'),repeat('d',64)) then raise exception 'device premature throttle';end if;
 end loop;
 if public.wm_reserve_auth_attempt(lpad(to_hex(21),64,'0'),repeat('d',64)) then raise exception 'device limit bypass';end if;
 update public.wm_auth_attempt_buckets set window_start=clock_timestamp()-interval '16 minutes';
 if not public.wm_reserve_auth_attempt(repeat('a',64),repeat('b',64)) then raise exception 'window did not reset';end if;
end $wm$;
reset role;

-- Recovery requests are service-only, neutral and idempotent; no password mutation.
do $wm$ begin
 if has_function_privilege('anon','public.wm_request_recovery(text)','EXECUTE') or has_function_privilege('authenticated','public.wm_request_recovery(text)','EXECUTE') or has_table_privilege('authenticated','public.wm_recovery_requests','SELECT') then raise exception 'recovery acl leak';end if;
 if not exists(select 1 from pg_class where oid='public.wm_recovery_requests'::regclass and relrowsecurity) then raise exception 'recovery rls missing';end if;
end $wm$;
set local role service_role;
do $wm$ begin
 perform public.wm_request_recovery('WM-FIXTURE1');
 perform public.wm_request_recovery('WM-FIXTURE1');
 perform public.wm_request_recovery('WM-UNKNOWN1');
 perform public.wm_request_recovery('invalid');
 if (select count(*) from public.wm_recovery_requests)<>1 then raise exception 'recovery deduplication or privacy failed';end if;
 if not exists(select 1 from public.wm_recovery_requests where account_id='10000000-0000-4000-8000-000000000001' and status='pending') then raise exception 'recovery not recorded';end if;
 if (select password_change_required from public.wm_accounts where login_id='WM-FIXTURE1') then raise exception 'request mutated account';end if;
end $wm$;
reset role;


-- Registration creates exactly one receipt/account/workspace and preserves role boundaries.
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000003'),('00000000-0000-4000-8000-000000000004');
do $wm$ begin
 if has_table_privilege('authenticated','public.wm_registration_receipts','SELECT') or has_function_privilege('anon','public.wm_register_account(uuid,uuid,uuid,text,text,text,text,text,text,text)','EXECUTE') then raise exception 'registration acl leak';end if;
end $wm$;
set local role service_role;
do $wm$ declare
 v_install uuid:='30000000-0000-4000-8000-000000000003';
 v_request uuid:='40000000-0000-4000-8000-000000000003';
 v_user uuid:='00000000-0000-4000-8000-000000000003';
 v_login text;
begin
 v_login:=public.wm_register_account(v_install,v_request,v_user,'WM-REGISTER1','wm3@example.invalid','New Individual','individual','Personal','wm-replay-draft-20261126','wm-replay-draft-20261126');
 if v_login<>'WM-REGISTER1' then raise exception 'registration login mismatch';end if;
 if public.wm_register_account(v_install,v_request,v_user,'WM-REGISTER9','wm3@example.invalid','New Individual','individual','Personal','wm-replay-draft-20261126','wm-replay-draft-20261126')<>v_login then raise exception 'registration retry changed login';end if;
 if (select count(*) from public.wm_accounts where auth_user_id=v_user)<>1 then raise exception 'duplicate account';end if;
 if not exists(select 1 from public.wm_memberships m join public.wm_accounts a on a.id=m.account_id join public.wm_workspaces w on w.id=m.workspace_id where a.auth_user_id=v_user and w.kind='individual' and m.role='owner') then raise exception 'individual role mismatch';end if;
 begin
 perform public.wm_register_account(v_install,v_request,v_user,'WM-REGISTER1','wm3@example.invalid','Changed','individual','Personal','wm-replay-draft-20261126','wm-replay-draft-20261126');
 raise exception 'changed registration accepted' using errcode='XX000';
 exception when raise_exception then null;
 end;
 perform public.wm_register_account(v_install,'40000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000004','WM-REGISTER2','wm4@example.invalid','New Enterprise','enterprise','Company','wm-replay-draft-20261126','wm-replay-draft-20261126');
 if not exists(select 1 from public.wm_memberships m join public.wm_accounts a on a.id=m.account_id join public.wm_workspaces w on w.id=m.workspace_id where a.login_id='WM-REGISTER2' and w.kind='enterprise' and m.role='promoteur') then raise exception 'enterprise role mismatch';end if;
end $wm$;
reset role;


-- Credential epoch fencing and one writer: no GoTrue calls in this SQL-only test.
set local role service_role;
do $wm$
declare
 a uuid:='10000000-0000-4000-8000-000000000001';
 w uuid:='20000000-0000-4000-8000-000000000001';
 i1 uuid:='30000000-0000-4000-8000-000000000021';
 i2 uuid:='30000000-0000-4000-8000-000000000022';
 req uuid:='40000000-0000-4000-8000-000000000021';
begin
 perform public.wm_issue_verified_session(a,i1,w,repeat('3',64),0);
 perform public.wm_issue_verified_session(a,i2,w,repeat('4',64),0);
 if not public.wm_begin_password_change(repeat('3',64),req,0) then raise exception 'rotation begin failed';end if;
 if public.wm_begin_password_change(repeat('3',64),req,0) then raise exception 'second writer accepted';end if;
 if exists(select 1 from public.wm_session_context(repeat('4',64))) then raise exception 'other device not revoked';end if;
 if not exists(select 1 from public.wm_session_context(repeat('3',64)) c where c.password_change_required) then raise exception 'rotation gate missing';end if;
 begin
  perform public.wm_issue_verified_session(a,i2,w,repeat('5',64),0);
  raise exception 'stale epoch issued' using errcode='XX000';
 exception when raise_exception then null;end;
 if public.wm_finish_password_change(repeat('4',64),req) then raise exception 'revoked actor completed rotation';end if;
 if not public.wm_finish_password_change(repeat('3',64),req) then raise exception 'rotation finish failed';end if;
 if exists(select 1 from public.wm_session_context(repeat('3',64))) then raise exception 'initiating session not revoked';end if;
 perform public.wm_issue_verified_session(a,i1,w,repeat('5',64),1);
 if not exists(select 1 from public.wm_session_context(repeat('5',64)) c where not c.password_change_required) then raise exception 'new epoch session failed';end if;
end $wm$;
reset role;


-- N1 profile, monotonic onboarding, invitations, favorites and membership revocation.
set local role service_role;
do $wm$ declare
 a uuid:='10000000-0000-4000-8000-000000000001';
 b uuid:='10000000-0000-4000-8000-000000000002';
 w uuid:='20000000-0000-4000-8000-000000000001';
 z uuid:='20000000-0000-4000-8000-000000000002';
 i uuid; j jsonb; gid uuid:=gen_random_uuid();
begin
 perform public.wm_issue_verified_session(a,'30000000-0000-4000-8000-000000000031',w,repeat('6',64),1);
 perform public.wm_issue_verified_session(b,'30000000-0000-4000-8000-000000000032',z,repeat('7',64),0);
 if public.wm_identity_action(repeat('6',64),'profile-update',jsonb_build_object('display_name','Updated name','locale','en','account_id',b)) is null then raise exception 'profile update failed';end if;
 if (select display_name from public.wm_accounts where id=b)<>'Fixture Two' then raise exception 'foreign profile changed';end if;
 if public.wm_identity_action(repeat('6',64),'onboarding-step','{"step":5}') is not null then raise exception 'onboarding skipped';end if;
 for k in 1..5 loop
  j:=public.wm_identity_action(repeat('6',64),'onboarding-step',jsonb_build_object('step',k));
  if (j->>'step')::integer is distinct from k then raise exception 'onboarding failed';end if;
 end loop;
 if (public.wm_identity_action(repeat('6',64),'onboarding-step','{"step":1}')->>'step')::integer is distinct from 5 then raise exception 'onboarding regressed';end if;
 if public.wm_identity_action(repeat('6',64),'favorite',jsonb_build_object('member_id',b,'enabled',true)) is not null then raise exception 'foreign favorite accepted';end if;
 if public.wm_identity_action(repeat('6',64),'group-save',jsonb_build_object('id',gid,'name','Foreign','member_ids',jsonb_build_array(b))) is not null then raise exception 'foreign contact group accepted';end if;
 if public.wm_identity_action(repeat('6',64),'invite','{"login_id":"WM-FIXTURE2","role":"staff"}') is null then raise exception 'invite failed';end if;
 if public.wm_identity_action(repeat('6',64),'invite','{"login_id":"WM-FIXTURE2","role":"promoteur"}') is not null then raise exception 'invite escalation';end if;
 j:=public.wm_identity_action(repeat('7',64),'invitations','{}');
 i:=(j->'invitations'->0->>'id')::uuid;
 if i is null then raise exception 'invite not received';end if;
 if public.wm_identity_action(repeat('6',64),'respond-invite',jsonb_build_object('id',i,'accept',true)) is not null then raise exception 'foreign invite acceptance';end if;
 if public.wm_identity_action(repeat('7',64),'respond-invite',jsonb_build_object('id',i,'accept',true)) is null then raise exception 'invite acceptance failed';end if;
 perform public.wm_switch_workspace(repeat('7',64),w,repeat('8',64));
 if public.wm_identity_action(repeat('8',64),'invite','{"login_id":"WM-REGISTER1","role":"staff"}') is not null then raise exception 'staff invite accepted';end if;
 if public.wm_identity_action(repeat('6',64),'favorite',jsonb_build_object('member_id',b,'enabled',true)) is null then raise exception 'favorite failed';end if;
 if (public.wm_identity_action(repeat('6',64),'contacts','{}')->'contacts'->0->>'favorite') is distinct from 'true' then raise exception 'favorite not returned';end if;
 if public.wm_identity_action(repeat('6',64),'group-save',jsonb_build_object('id',gid,'name','Team','member_ids',jsonb_build_array(b))) is null then raise exception 'group creation failed';end if;
 if (public.wm_identity_action(repeat('6',64),'groups','{}')->'groups'->0->'member_ids'->>0) is distinct from b::text then raise exception 'group member missing';end if;
 if jsonb_array_length(public.wm_identity_action(repeat('8',64),'groups','{}')->'groups')<>0 then raise exception 'group read leak';end if;
 if public.wm_identity_action(repeat('8',64),'group-delete',jsonb_build_object('id',gid)) is not null then raise exception 'foreign group deletion';end if;
 if public.wm_identity_action(repeat('8',64),'member-role',jsonb_build_object('member_id',a,'role','staff')) is not null then raise exception 'staff changed owner';end if;
 if public.wm_identity_action(repeat('6',64),'member-role',jsonb_build_object('member_id',b,'role','manager')) is null then raise exception 'manager promotion failed';end if;
 if exists(select 1 from public.wm_session_context(repeat('8',64))) then raise exception 'old staff session survived role change';end if;
 if public.wm_identity_action(repeat('6',64),'revoke-member',jsonb_build_object('member_id',b)) is null then raise exception 'revocation failed';end if;
 if exists(select 1 from public.wm_contact_groups where id=gid and b=any(member_ids)) then raise exception 'revoked contact retained in group';end if;
 if public.wm_identity_action(repeat('6',64),'group-delete',jsonb_build_object('id',gid)) is null then raise exception 'group delete failed';end if;
 if exists(select 1 from public.wm_favorites where contact_id=b and workspace_id=w) then raise exception 'revoked favorite retained';end if;
 if exists(select 1 from public.wm_memberships where account_id=b and workspace_id=w and enabled) then raise exception 'membership still enabled';end if;
end $wm$;
reset role;
do $wm$ begin
 if has_function_privilege('anon','public.wm_identity_action(text,text,jsonb)','EXECUTE') or has_table_privilege('authenticated','public.wm_membership_invites','SELECT') or has_table_privilege('anon','public.wm_favorites','SELECT') or has_table_privilege('authenticated','public.wm_contact_groups','SELECT') then raise exception 'identity ACL leak';end if;
end $wm$;


-- Rotating refresh secret, original absolute expiry, revoked devices and scope.
set local role service_role;
do $wm$ declare
 a uuid:='10000000-0000-4000-8000-000000000001';
 w uuid:='20000000-0000-4000-8000-000000000001';
 ins uuid:='30000000-0000-4000-8000-000000000041';
 sid uuid; next_id uuid; deadline timestamptz; j jsonb;
begin
 sid:=public.wm_issue_verified_session(a,ins,w,repeat('9',64),1);
 if not public.wm_attach_refresh(repeat('9',64),repeat('0',64),true) then raise exception 'refresh attachment failed';end if;
 select refresh_until into deadline from public.wm_device_sessions where id=sid;
 if deadline<=now()+interval '29 days' or deadline>clock_timestamp()+interval '30 days' then raise exception 'invalid remember deadline';end if;
 if public.wm_attach_refresh(repeat('9',64),repeat('1',64),true) then raise exception 'refresh reattached';end if;
 if public.wm_rotate_refresh(repeat('0',64),gen_random_uuid(),repeat('a',63)||'1',repeat('b',63)||'1') is not null then raise exception 'wrong installation accepted';end if;
 next_id:=public.wm_rotate_refresh(repeat('0',64),ins,repeat('a',63)||'1',repeat('b',63)||'1');
 if next_id is null then raise exception 'refresh rotation failed';end if;
 if exists(select 1 from public.wm_session_context(repeat('9',64))) then raise exception 'old access survived';end if;
 if public.wm_rotate_refresh(repeat('0',64),ins,repeat('a',63)||'2',repeat('b',63)||'2') is not null then raise exception 'old refresh replay accepted';end if;
 if (select refresh_until from public.wm_device_sessions where id=next_id) is distinct from deadline then raise exception 'absolute deadline extended';end if;
 perform public.wm_switch_workspace(repeat('a',63)||'1','20000000-0000-4000-8000-000000000003',repeat('a',63)||'2');
 next_id:=public.wm_rotate_refresh(repeat('b',63)||'1',ins,repeat('a',63)||'3',repeat('b',63)||'3');
 if next_id is null or (select workspace_id from public.wm_device_sessions where id=next_id)<>'20000000-0000-4000-8000-000000000003'::uuid then raise exception 'refresh did not preserve selected workspace';end if;
 j:=public.wm_identity_action(repeat('a',63)||'3','devices','{}');
 if not exists(select 1 from jsonb_array_elements(j->'devices') d where d->>'id'=next_id::text and d->>'current'='true') then raise exception 'device listing failed';end if;
 if public.wm_identity_action(repeat('a',63)||'3','revoke-device',jsonb_build_object('id',next_id)) is not null then raise exception 'self device revocation not via logout';end if;
 update public.wm_device_sessions set refresh_until=clock_timestamp()-interval '1 second' where id=next_id;
 if public.wm_rotate_refresh(repeat('b',63)||'3',ins,repeat('a',63)||'4',repeat('b',63)||'4') is not null then raise exception 'expired refresh accepted';end if;
end $wm$;
reset role;
do $wm$ begin
 if has_function_privilege('anon','public.wm_rotate_refresh(text,uuid,text,text)','EXECUTE') or has_function_privilege('authenticated','public.wm_attach_refresh(text,text,boolean)','EXECUTE') then raise exception 'refresh ACL leak';end if;
end $wm$;

rollback;
select 'WIDEMEET_IDENTITY_SQL_PASS';
