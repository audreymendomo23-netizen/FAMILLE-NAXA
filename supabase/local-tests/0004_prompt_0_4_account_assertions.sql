\set ON_ERROR_STOP on
begin;
grant usage on schema auth to service_role;
insert into auth.users(id) values
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002')
on conflict do nothing;
set local role service_role;
-- Explicit app access is per account and app; no cross-app grant is implied.
insert into famille_private.account_app_access(user_id,app_code,account_kind,plan_code,duration_days,discount_percent,trial_days)
values('10000000-0000-0000-0000-000000000001','kiosko','client','essentiel',90,10,7);
do $$ begin
 if (select count(*) from famille_private.account_app_access where user_id='10000000-0000-0000-0000-000000000001')<>1 then raise exception 'account grant missing'; end if;
 if exists(select 1 from famille_private.account_app_access where user_id='10000000-0000-0000-0000-000000000001' and app_code='bootik') then raise exception 'implicit cross-app grant'; end if;
end $$;
-- First and second device stay active; the third atomically evicts the oldest.
select famille_private.register_device('10000000-0000-0000-0000-000000000001','kiosko',null,null,'install-00000000000001',null,'android','Android 1');
select famille_private.register_device('10000000-0000-0000-0000-000000000001','kiosko',null,null,'install-00000000000002',null,'android','Android 2');
select famille_private.register_device('10000000-0000-0000-0000-000000000001','kiosko',null,null,'install-00000000000003',null,'android','Android 3');
do $$ begin
 if (select count(*) from famille_private.account_devices where user_id='10000000-0000-0000-0000-000000000001' and app_code='kiosko' and status='active')<>2 then raise exception 'device cap not enforced'; end if;
 if (select status from famille_private.account_devices where installation_id='install-00000000000001')<>'revoked' then raise exception 'oldest device not revoked'; end if;
end $$;
-- Five failed attempts lock for fifteen minutes; a successful login clears the guard.
select famille_private.record_login_failure('sha256:sample','kiosko');
select famille_private.record_login_failure('sha256:sample','kiosko');
select famille_private.record_login_failure('sha256:sample','kiosko');
select famille_private.record_login_failure('sha256:sample','kiosko');
select famille_private.record_login_failure('sha256:sample','kiosko');
do $$ begin
 if not famille_private.login_is_locked('sha256:sample','kiosko') then raise exception 'five failures did not lock'; end if;
end $$;
select famille_private.clear_login_failures('sha256:sample','kiosko');
do $$ begin
 if famille_private.login_is_locked('sha256:sample','kiosko') then raise exception 'successful login did not clear lock'; end if;
end $$;
-- Private data is not directly accessible to authenticated clients.
reset role;
do $$ begin
 if has_table_privilege('authenticated','famille_private.account_devices','select') then raise exception 'authenticated has direct device access'; end if;
 if has_table_privilege('anon','famille_private.account_invites','select') then raise exception 'anon has direct invite access'; end if;
 if not has_function_privilege('service_role','famille_private.register_device(uuid,text,uuid,uuid,text,uuid,text,text)','execute') then raise exception 'service role cannot register device'; end if;
end $$;
rollback;
