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
 update public.wm_memberships set enabled=false where account_id='10000000-0000-4000-8000-000000000001';
 begin
 perform public.wm_issue_device_session('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',repeat('d',64));
 raise exception 'disabled membership accepted' using errcode='XX000';
 exception when raise_exception then null;
 end;
end $$;
reset role;
rollback;
select 'WIDEMEET_IDENTITY_SQL_PASS';
