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
language sql security invoker stable set search_path=pg_catalog,public as $
 select s.id,s.account_id,s.installation_id,s.workspace_id,s.expires_at,a.password_change_required
 from public.wm_device_sessions s
 join public.wm_accounts a on a.id=s.account_id and a.enabled
 join public.wm_memberships m on m.account_id=s.account_id and m.workspace_id=s.workspace_id and m.enabled
 join public.wm_workspaces w on w.id=m.workspace_id and w.enabled
 where s.token_hash=p_hash and s.revoked_at is null and s.expires_at>now()
 and ((w.kind='individual' and m.role='owner') or (w.kind='enterprise' and m.role in ('promoteur','manager','staff')))
$;
revoke all on function public.wm_session_context(text) from public,anon,authenticated;
grant execute on function public.wm_session_context(text) to service_role;
-- Serialize rotation with login, then recheck OLD token under the lock; never accept client account IDs.
create function public.wm_switch_workspace(p_old_hash text,p_workspace uuid,p_new_hash text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $
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
end $;
revoke all on function public.wm_switch_workspace(text,uuid,text) from public,anon,authenticated;
grant execute on function public.wm_switch_workspace(text,uuid,text) to service_role;
commit;
