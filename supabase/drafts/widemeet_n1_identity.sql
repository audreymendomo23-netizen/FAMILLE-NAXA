-- WideMeet N1 draft ONLY. Run on disposable Replay, never hosted production.
-- Adapted from NAXA SERVICES ns_accounts and ZIPPLE opaque device sessions.
-- No grants to anon/authenticated; dedicated Edge gateway verifies credentials.
begin;
create table public.wm_accounts (
 id uuid primary key default gen_random_uuid(),
 auth_user_id uuid not null unique references auth.users(id) on delete restrict,
 login_id text not null unique check(login_id ~ '^WM-[A-Z0-9]{8,24}$'),
 auth_alias text not null unique check(length(auth_alias) between 3 and 254),
 display_name text not null check(length(btrim(display_name)) between 1 and 120),
 enabled boolean not null default true,
 password_change_required boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.wm_workspaces (
 id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in ('individual','enterprise')),
 name text not null check(length(btrim(name)) between 1 and 120),
 enabled boolean not null default true
);
create table public.wm_memberships (
 account_id uuid not null references public.wm_accounts(id),
 workspace_id uuid not null references public.wm_workspaces(id),
 role text not null check(role in ('owner','promoteur','manager','staff')),
 enabled boolean not null default true,
 primary key(account_id,workspace_id)
);
create unique index wm_one_owner_per_workspace on public.wm_memberships(workspace_id) where role in ('owner','promoteur') and enabled;
create table public.wm_device_sessions (
 id uuid primary key default gen_random_uuid(),
 account_id uuid not null references public.wm_accounts(id),
 installation_id uuid not null,
 workspace_id uuid not null,
 token_hash text not null unique check(token_hash ~ '^[a-f0-9]{64}$'),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 foreign key(account_id,workspace_id) references public.wm_memberships(account_id,workspace_id),
 check(expires_at>created_at)
);
create index wm_device_sessions_account_idx on public.wm_device_sessions(account_id,installation_id);
alter table public.wm_accounts enable row level security;
alter table public.wm_workspaces enable row level security;
alter table public.wm_memberships enable row level security;
alter table public.wm_device_sessions enable row level security;
revoke all on public.wm_accounts,public.wm_workspaces,public.wm_memberships,public.wm_device_sessions from public,anon,authenticated;
grant select,insert,update,delete on public.wm_accounts,public.wm_workspaces,public.wm_memberships,public.wm_device_sessions to service_role;
-- Atomic issuance: serialize per account; validate membership and role at source.
create function public.wm_issue_device_session(p_account uuid,p_installation uuid,p_workspace uuid,p_hash text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare v_id uuid;
begin
 perform 1 from public.wm_accounts where id=p_account and enabled for update;
 if not found then raise exception 'account unavailable'; end if;
 if not exists(select 1 from public.wm_memberships m join public.wm_workspaces w on w.id=m.workspace_id where m.account_id=p_account and m.workspace_id=p_workspace and m.enabled and w.enabled and ((w.kind='individual' and m.role='owner') or (w.kind='enterprise' and m.role in ('promoteur','manager','staff')))) then raise exception 'scope unavailable'; end if;
 update public.wm_device_sessions set revoked_at=clock_timestamp() where account_id=p_account and installation_id=p_installation and revoked_at is null;
 insert into public.wm_device_sessions(account_id,installation_id,workspace_id,token_hash,expires_at) values(p_account,p_installation,p_workspace,p_hash,clock_timestamp()+interval '30 minutes') returning id into v_id;
 return v_id;
end $$;
revoke all on function public.wm_issue_device_session(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.wm_issue_device_session(uuid,uuid,uuid,text) to service_role;
-- Revalidate authority on EVERY sensitive action; this function does not confer client SQL access.
create function public.wm_session_context(p_hash text)
returns table(session_id uuid,account_id uuid,installation_id uuid,workspace_id uuid,expires_at timestamptz,password_change_required boolean)
language sql security invoker stable set search_path=pg_catalog,public as $$
 select s.id,s.account_id,s.installation_id,s.workspace_id,s.expires_at,a.password_change_required
 from public.wm_device_sessions s
 join public.wm_accounts a on a.id=s.account_id and a.enabled
 join public.wm_memberships m on m.account_id=s.account_id and m.workspace_id=s.workspace_id and m.enabled
 join public.wm_workspaces w on w.id=m.workspace_id and w.enabled
 where s.token_hash=p_hash and s.revoked_at is null and s.expires_at>now()
 and ((w.kind='individual' and m.role='owner') or (w.kind='enterprise' and m.role in ('promoteur','manager','staff')))
$$;
revoke all on function public.wm_session_context(text) from public,anon,authenticated;
grant execute on function public.wm_session_context(text) to service_role;
-- Serialize rotation with login, then recheck OLD token under the lock; never accept client account IDs.
create function public.wm_switch_workspace(p_old_hash text,p_workspace uuid,p_new_hash text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare v_account uuid;v_installation uuid;v_old public.wm_device_sessions%rowtype;v_new uuid;
begin
 select s.account_id into v_account from public.wm_device_sessions s where s.token_hash=p_old_hash;
 if not found then raise exception 'invalid session';end if;
 perform 1 from public.wm_accounts a where a.id=v_account and a.enabled and not a.password_change_required for update;
 if not found then raise exception 'account unavailable';end if;
 select * into v_old from public.wm_device_sessions s where s.token_hash=p_old_hash and s.account_id=v_account and s.revoked_at is null and s.expires_at>clock_timestamp() for update;
 if not found then raise exception 'invalid session';end if;
 if not exists(select 1 from public.wm_session_context(p_old_hash)) then raise exception 'scope unavailable';end if;
 if not exists(select 1 from public.wm_memberships m join public.wm_workspaces w on w.id=m.workspace_id where m.account_id=v_account and m.workspace_id=p_workspace and m.enabled and w.enabled and ((w.kind='individual' and m.role='owner') or (w.kind='enterprise' and m.role in ('promoteur','manager','staff')))) then raise exception 'scope unavailable';end if;
 update public.wm_device_sessions set revoked_at=clock_timestamp() where id=v_old.id;
 -- Preserve the original expiry: switching is not refresh.
 insert into public.wm_device_sessions(account_id,installation_id,workspace_id,token_hash,expires_at) values(v_account,v_old.installation_id,p_workspace,p_new_hash,v_old.expires_at) returning id into v_new;
 return v_new;
end $$;
revoke all on function public.wm_switch_workspace(text,uuid,text) from public,anon,authenticated;
grant execute on function public.wm_switch_workspace(text,uuid,text) to service_role;
-- N1 anti-brute-force: reserve attempt BEFORE credential lookup, including unknown accounts.
-- Adapted from NAXA SERVICES isLimited; database upsert serializes each bucket.
create table public.wm_auth_attempt_buckets (
 bucket_key text primary key check(bucket_key ~ '^[a-f0-9]{64}$'),
 window_start timestamptz not null,
 attempts integer not null check(attempts between 1 and 21)
);
alter table public.wm_auth_attempt_buckets enable row level security;
revoke all on public.wm_auth_attempt_buckets from public,anon,authenticated;
grant select,insert,update,delete on public.wm_auth_attempt_buckets to service_role;
create function public.wm_reserve_auth_attempt(p_identifier_hash text,p_installation_hash text)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare
 k text; n integer; t timestamptz:=clock_timestamp(); allowed boolean:=true;
begin
 if p_identifier_hash is null or p_installation_hash is null or p_identifier_hash !~ '^[a-f0-9]{64}$' or p_installation_hash !~ '^[a-f0-9]{64}$' or p_identifier_hash=p_installation_hash then raise exception 'invalid bucket'; end if;
 -- Fixed order prevents deadlocks across concurrent reservations.
 for k in select unnest(array[p_identifier_hash,p_installation_hash]) order by 1 loop
  insert into public.wm_auth_attempt_buckets as b(bucket_key,window_start,attempts) values(k,t,1)
  on conflict(bucket_key) do update set
   attempts=case when b.window_start<=t-interval '15 minutes' then 1 else least(b.attempts+1,21) end,
   window_start=case when b.window_start<=t-interval '15 minutes' then t else b.window_start end
  returning attempts into n;
  if n>(case when k=p_identifier_hash then 5 else 20 end) then allowed:=false;end if;
 end loop;
 return allowed;
end $wm$;
revoke all on function public.wm_reserve_auth_attempt(text,text) from public,anon,authenticated;
grant execute on function public.wm_reserve_auth_attempt(text,text) to service_role;
-- N1 supervised recovery intake, adapted from NS. A request never resets a password.
create table public.wm_recovery_requests(
 id uuid primary key default gen_random_uuid(),
 account_id uuid not null references public.wm_accounts(id) on delete restrict,
 requested_at timestamptz not null default clock_timestamp(),
 status text not null default 'pending' check(status in ('pending','resolved','rejected'))
);
create unique index wm_recovery_one_pending on public.wm_recovery_requests(account_id) where status='pending';
alter table public.wm_recovery_requests enable row level security;
revoke all on public.wm_recovery_requests from public,anon,authenticated;
grant select,insert,update,delete on public.wm_recovery_requests to service_role;
create function public.wm_request_recovery(p_identifier text)
returns void language plpgsql security invoker set search_path=pg_catalog,public as $wm$
begin
 -- No response distinguishes an existing, disabled or unknown account.
 if p_identifier is null or p_identifier !~ '^WM-[A-Z0-9]{8,24}$' then return;end if;
 insert into public.wm_recovery_requests(account_id)
 select id from public.wm_accounts where login_id=p_identifier and enabled
 on conflict(account_id) where status='pending' do nothing;
end $wm$;
revoke all on function public.wm_request_recovery(text) from public,anon,authenticated;
grant execute on function public.wm_request_recovery(text) to service_role;
-- Autonomous registration candidate (disabled outside Replay until anti-abuse/recovery/legal qualification).
-- GoTrue user provision is separate; this RPC atomically creates the product account, workspace and receipt.
create table public.wm_registration_receipts(
 installation_id uuid not null,
 request_id uuid not null,
 account_id uuid not null unique references public.wm_accounts(id),
 workspace_id uuid not null unique references public.wm_workspaces(id),
 auth_user_id uuid not null unique references auth.users(id),
 display_name text not null,
 workspace_name text not null,
 workspace_kind text not null check(workspace_kind in ('individual','enterprise')),
 terms_version text not null,
 privacy_version text not null,
 created_at timestamptz not null default clock_timestamp(),
 primary key(installation_id,request_id)
);
alter table public.wm_registration_receipts enable row level security;
revoke all on public.wm_registration_receipts from public,anon,authenticated;
grant select,insert,update,delete on public.wm_registration_receipts to service_role;
create function public.wm_register_account(p_installation uuid,p_request uuid,p_auth_user uuid,p_login text,p_alias text,p_display text,p_kind text,p_workspace text,p_terms text,p_privacy text)
returns text language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare receipt public.wm_registration_receipts%rowtype; aid uuid; wid uuid; result text;
begin
 if p_installation is null or p_request is null or p_auth_user is null or p_kind is null or p_kind not in ('individual','enterprise') or p_display is null or length(trim(p_display)) not between 1 and 120 or p_workspace is null or length(trim(p_workspace)) not between 1 and 120 or p_terms is distinct from 'wm-replay-draft-20261126' or p_privacy is distinct from 'wm-replay-draft-20261126' then raise exception 'invalid registration';end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-register:'||p_installation::text||':'||p_request::text,0));
 select * into receipt from public.wm_registration_receipts x where x.installation_id=p_installation and x.request_id=p_request;
 if found then
  if receipt.auth_user_id<>p_auth_user or receipt.display_name<>trim(p_display) or receipt.workspace_kind<>p_kind or receipt.workspace_name<>trim(p_workspace) or receipt.terms_version<>p_terms or receipt.privacy_version<>p_privacy then raise exception 'registration conflict';end if;
  select a.login_id into result from public.wm_accounts a where a.id=receipt.account_id and a.enabled;
  if result is null then raise exception 'account unavailable';end if;
  return result;
 end if;
 if p_login is null or p_login !~ '^WM-[A-Z0-9]{8,24}$' or p_alias is null or length(p_alias) not between 3 and 254 then raise exception 'invalid registration';end if;
 insert into public.wm_accounts(auth_user_id,login_id,auth_alias,display_name,password_change_required)
 values(p_auth_user,p_login,p_alias,trim(p_display),false) returning id into aid;
 insert into public.wm_workspaces(kind,name) values(p_kind,trim(p_workspace)) returning id into wid;
 insert into public.wm_memberships(account_id,workspace_id,role) values(aid,wid,case when p_kind='individual' then 'owner' else 'promoteur' end);
 insert into public.wm_registration_receipts(installation_id,request_id,account_id,workspace_id,auth_user_id,display_name,workspace_name,workspace_kind,terms_version,privacy_version)
 values(p_installation,p_request,aid,wid,p_auth_user,trim(p_display),trim(p_workspace),p_kind,p_terms,p_privacy);
 return p_login;
end $wm$;
revoke all on function public.wm_register_account(uuid,uuid,uuid,text,text,text,text,text,text,text) from public,anon,authenticated;
grant execute on function public.wm_register_account(uuid,uuid,uuid,text,text,text,text,text,text,text) to service_role;
-- Credential rotation fence: password verified before session issuance must match the
-- account epoch observed before GoTrue. A pending change blocks new sessions.
alter table public.wm_accounts add column credential_epoch bigint not null default 0;
alter table public.wm_accounts add column password_change_id uuid;
alter table public.wm_accounts add column password_change_session uuid;
alter table public.wm_accounts add constraint wm_password_change_pair check ((password_change_id is null)=(password_change_session is null));
create function public.wm_issue_verified_session(p_account uuid,p_installation uuid,p_workspace uuid,p_hash text,p_epoch bigint)
returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $wm$
begin
 perform 1 from public.wm_accounts a where a.id=p_account and a.enabled and a.credential_epoch=p_epoch and a.password_change_id is null for update;
 if not found then raise exception 'credential changed';end if;
 return public.wm_issue_device_session(p_account,p_installation,p_workspace,p_hash);
end $wm$;
revoke all on function public.wm_issue_verified_session(uuid,uuid,uuid,text,bigint) from public,anon,authenticated;
grant execute on function public.wm_issue_verified_session(uuid,uuid,uuid,text,bigint) to service_role;
create function public.wm_begin_password_change(p_hash text,p_request uuid,p_epoch bigint)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a public.wm_accounts%rowtype; s record;
begin
 if p_request is null or p_epoch is null then return false;end if;
 select * into s from public.wm_session_context(p_hash);
 if not found then return false;end if;
 select * into a from public.wm_accounts where id=s.account_id and enabled for update;
 if not found then return false;end if;
 if not exists(select 1 from public.wm_session_context(p_hash) c where c.account_id=a.id and c.session_id=s.session_id) then return false;end if;
 if a.password_change_id is not null then
  return false; -- one writer; a retry can only prove the already changed password
 end if;
 if a.credential_epoch<>p_epoch then return false;end if;
 update public.wm_accounts set credential_epoch=credential_epoch+1,password_change_required=true,password_change_id=p_request,password_change_session=s.session_id where id=a.id;
 update public.wm_device_sessions set revoked_at=clock_timestamp() where account_id=a.id and id<>s.session_id and revoked_at is null;
 return true;
end $wm$;
revoke all on function public.wm_begin_password_change(text,uuid,bigint) from public,anon,authenticated;
grant execute on function public.wm_begin_password_change(text,uuid,bigint) to service_role;
create function public.wm_finish_password_change(p_hash text,p_request uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found then return false;end if;
 perform 1 from public.wm_accounts a where a.id=s.account_id and a.enabled and a.password_change_id=p_request and a.password_change_session=s.session_id for update;
 if not found then return false;end if;
 if not exists(select 1 from public.wm_session_context(p_hash) c where c.session_id=s.session_id) then return false;end if;
 update public.wm_accounts set password_change_required=false,password_change_id=null,password_change_session=null where id=s.account_id;
 update public.wm_device_sessions set revoked_at=clock_timestamp() where account_id=s.account_id and revoked_at is null;
 return true;
end $wm$;
revoke all on function public.wm_finish_password_change(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_finish_password_change(text,uuid) to service_role;
commit;
