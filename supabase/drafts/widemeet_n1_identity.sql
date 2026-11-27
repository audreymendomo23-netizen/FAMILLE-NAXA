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
 refresh_hash text unique check(refresh_hash ~ '^[a-f0-9]{64}$'),
 refresh_until timestamptz,
 remember_me boolean not null default false,
 check((refresh_hash is null)=(refresh_until is null)),
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
 update public.wm_device_sessions set revoked_at=clock_timestamp(),refresh_hash=null,refresh_until=null where id=v_old.id;
 -- Preserve the original access and refresh deadlines. Switching is not refresh.
 insert into public.wm_device_sessions(account_id,installation_id,workspace_id,token_hash,expires_at,refresh_hash,refresh_until,remember_me) values(v_account,v_old.installation_id,p_workspace,p_new_hash,v_old.expires_at,v_old.refresh_hash,v_old.refresh_until,v_old.remember_me) returning id into v_new;
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

-- N1 private account profile and onboarding. The profile belongs to the identity,
-- favorites belong to an identity within a particular workspace.
alter table public.wm_accounts add column locale text not null default 'fr' check(locale in ('fr','en'));
alter table public.wm_accounts add column onboarding_step integer not null default 0 check(onboarding_step between 0 and 5);
create table public.wm_favorites(
 account_id uuid not null, workspace_id uuid not null, contact_id uuid not null,
 primary key(account_id,workspace_id,contact_id),
 foreign key(account_id,workspace_id) references public.wm_memberships(account_id,workspace_id),
 foreign key(contact_id,workspace_id) references public.wm_memberships(account_id,workspace_id),
 check(account_id<>contact_id)
);
create table public.wm_membership_invites(
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.wm_workspaces(id),
 target_id uuid not null references public.wm_accounts(id),
 sender_id uuid not null references public.wm_accounts(id),
 role text not null check(role in ('manager','staff')),
 status text not null default 'pending' check(status in ('pending','accepted','declined','revoked')),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '7 days'),
 check(expires_at>created_at)
);
create unique index wm_invite_pending on public.wm_membership_invites(workspace_id,target_id) where status='pending';
alter table public.wm_favorites enable row level security;
alter table public.wm_membership_invites enable row level security;
revoke all on public.wm_favorites,public.wm_membership_invites from public,anon,authenticated;
grant select,insert,update,delete on public.wm_favorites,public.wm_membership_invites to service_role;
-- Personal contact groups within one active workspace. No client table access.
create table public.wm_contact_groups(
 id uuid primary key,
 account_id uuid not null,
 workspace_id uuid not null,
 name text not null check(length(btrim(name)) between 1 and 80),
 member_ids uuid[] not null default '{}'::uuid[] check(cardinality(member_ids)<=100),
 foreign key(account_id,workspace_id) references public.wm_memberships(account_id,workspace_id) on delete cascade,
 unique(account_id,workspace_id,name)
);
alter table public.wm_contact_groups enable row level security;
revoke all on public.wm_contact_groups from public,anon,authenticated;
grant select,insert,update,delete on public.wm_contact_groups to service_role;
-- Every mutation revalidates opaque session and current scope. No account IDs or
-- workspace IDs submitted by the client may override the trusted context.

-- One directly assigned manager per staff member, within the same enterprise.
-- The ordinary contact directory remains workspace-scoped; management is narrower.
create table public.wm_manager_assignments(
 workspace_id uuid not null,
 staff_id uuid not null,
 manager_id uuid not null,
 primary key(workspace_id,staff_id),
 foreign key(staff_id,workspace_id) references public.wm_memberships(account_id,workspace_id) on delete cascade,
 foreign key(manager_id,workspace_id) references public.wm_memberships(account_id,workspace_id) on delete cascade,
 check(staff_id<>manager_id)
);
alter table public.wm_manager_assignments enable row level security;
revoke all on public.wm_manager_assignments from public,anon,authenticated;
grant select,insert,update,delete on public.wm_manager_assignments to service_role;

create function public.wm_identity_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; a public.wm_accounts%rowtype; w public.wm_workspaces%rowtype;
 v_role text; v_target uuid; v_inv public.wm_membership_invites%rowtype; v_step integer; v_newrole text;
 v_name text; v_result jsonb; v_manager uuid;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 -- Serialize N1 mutations, including invite acceptance and cancellation, without
 -- cross-account lock order inversion. Candidate scoped to this application.
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_accounts where id=s.account_id and enabled and not password_change_required for update;
 if not found then return null;end if;
 if not exists(select 1 from public.wm_session_context(p_hash) c where c.session_id=s.session_id and not c.password_change_required) then return null;end if;
 select * into w from public.wm_workspaces where id=s.workspace_id and enabled;
 if not found then return null;end if;
 select role into v_role from public.wm_memberships where account_id=a.id and workspace_id=w.id and enabled;
 if not found then return null;end if;
 case p_action
 when 'devices' then
  select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'current',d.id=s.session_id,'created_at',d.created_at,'expires_at',d.expires_at,'remembered',d.remember_me,'refresh_until',d.refresh_until) order by d.created_at desc),'[]'::jsonb) into v_result
  from public.wm_device_sessions d where d.account_id=a.id and d.revoked_at is null and (d.expires_at>clock_timestamp() or d.refresh_until>clock_timestamp());
  return jsonb_build_object('devices',v_result);
 when 'revoke-device' then
  v_target:=(p_data->>'id')::uuid;
  if v_target is null or v_target=s.session_id then return null;end if;
  update public.wm_device_sessions set revoked_at=clock_timestamp(),refresh_hash=null,refresh_until=null where account_id=a.id and id=v_target and revoked_at is null;
  if not found then return null;end if;
  return jsonb_build_object('updated',true);
 when 'profile' then
  return jsonb_build_object('display_name',a.display_name,'login_id',a.login_id,'locale',a.locale,'onboarding_step',a.onboarding_step,'workspace_name',w.name,'workspace_kind',w.kind,'role',v_role);
 when 'profile-update' then
  v_name:=btrim(p_data->>'display_name');
  if v_name is null or length(v_name) not between 1 and 120 or p_data->>'locale' not in ('fr','en') or p_data->>'locale' is null then return null;end if;
  update public.wm_accounts set display_name=v_name,locale=p_data->>'locale' where id=a.id;
  return jsonb_build_object('updated',true);
 when 'onboarding-step' then
  if jsonb_typeof(p_data->'step') is distinct from 'number' or p_data->>'step' !~ '^[0-5]$' then return null;end if;
  v_step:=(p_data->>'step')::integer;
  if v_step>a.onboarding_step+1 then return null;end if;
  update public.wm_accounts set onboarding_step=greatest(onboarding_step,v_step) where id=a.id returning onboarding_step into v_step;
  return jsonb_build_object('step',v_step);
 when 'contacts' then
  select coalesce(jsonb_agg(q order by q->>'display_name',q->>'member_id'),'[]'::jsonb) into v_result from (
   select jsonb_build_object('member_id',m.account_id,'display_name',c.display_name,'role',m.role,'favorite',f.contact_id is not null,'manager_id',case when v_role='promoteur' or ma.manager_id=a.id then ma.manager_id else null end,'can_revoke',m.role in ('manager','staff') and (v_role='promoteur' or (v_role='manager' and m.role='staff' and ma.manager_id=a.id))) q
   from public.wm_memberships m join public.wm_accounts c on c.id=m.account_id and c.enabled
   left join public.wm_favorites f on f.account_id=a.id and f.workspace_id=w.id and f.contact_id=m.account_id
   left join public.wm_manager_assignments ma on ma.workspace_id=m.workspace_id and ma.staff_id=m.account_id
   where m.workspace_id=w.id and m.enabled and m.account_id<>a.id
   order by c.display_name,m.account_id limit 200
  ) q;
  return jsonb_build_object('contacts',v_result);
 when 'favorite' then
  v_target:=(p_data->>'member_id')::uuid;
  if v_target is null or v_target=a.id or jsonb_typeof(p_data->'enabled') is distinct from 'boolean' or not exists(select 1 from public.wm_memberships m join public.wm_accounts c on c.id=m.account_id and c.enabled where m.account_id=v_target and m.workspace_id=w.id and m.enabled) then return null;end if;
  if (p_data->>'enabled')::boolean then insert into public.wm_favorites values(a.id,w.id,v_target) on conflict do nothing;
  else delete from public.wm_favorites where account_id=a.id and workspace_id=w.id and contact_id=v_target;end if;
  return jsonb_build_object('updated',true);
 when 'groups' then
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'member_ids',
   coalesce((select jsonb_agg(mid order by mid) from unnest(g.member_ids) mid
   join public.wm_memberships m on m.account_id=mid and m.workspace_id=w.id and m.enabled
   join public.wm_accounts c on c.id=mid and c.enabled),'[]'::jsonb)) order by g.name,g.id),'[]'::jsonb) into v_result
  from public.wm_contact_groups g where g.account_id=a.id and g.workspace_id=w.id;
  return jsonb_build_object('groups',v_result);
 when 'group-save' then
  v_target:=(p_data->>'id')::uuid;v_name:=btrim(p_data->>'name');
  if v_target is null or v_name is null or length(v_name) not between 1 and 80 or jsonb_typeof(p_data->'member_ids') is distinct from 'array' then return null;end if;
  if jsonb_array_length(p_data->'member_ids')>100 then return null;end if;
  if exists(select 1 from jsonb_array_elements_text(p_data->'member_ids') as x(mid) where mid::uuid=a.id or not exists(select 1 from public.wm_memberships m join public.wm_accounts c on c.id=m.account_id and c.enabled where m.account_id=mid::uuid and m.workspace_id=w.id and m.enabled)) then return null;end if;
  if exists(select 1 from public.wm_contact_groups g where g.id=v_target and (g.account_id<>a.id or g.workspace_id<>w.id)) then return null;end if;
  if exists(select 1 from public.wm_contact_groups g where g.account_id=a.id and g.workspace_id=w.id and g.name=v_name and g.id<>v_target) then return null;end if;
  if not exists(select 1 from public.wm_contact_groups g where g.id=v_target) and (select count(*) from public.wm_contact_groups g where g.account_id=a.id and g.workspace_id=w.id)>=50 then return null;end if;
  insert into public.wm_contact_groups(id,account_id,workspace_id,name,member_ids)
   values(v_target,a.id,w.id,v_name,array(select distinct mid::uuid from jsonb_array_elements_text(p_data->'member_ids') as x(mid) order by mid::uuid))
   on conflict(id) do update set name=excluded.name,member_ids=excluded.member_ids where wm_contact_groups.account_id=a.id and wm_contact_groups.workspace_id=w.id;
  return jsonb_build_object('updated',true,'id',v_target);
 when 'group-delete' then
  v_target:=(p_data->>'id')::uuid;
  delete from public.wm_contact_groups where id=v_target and account_id=a.id and workspace_id=w.id;
  if not found then return null;end if;
  return jsonb_build_object('updated',true);
 when 'invite' then
  v_newrole:=p_data->>'role';
  if w.kind<>'enterprise' or v_role not in ('promoteur','manager') or v_newrole not in ('manager','staff') or v_newrole is null or (v_role='manager' and v_newrole<>'staff') then return null;end if;
  if coalesce(p_data->>'login_id','') !~ '^WM-[A-Z0-9]{8,24}$' then return null;end if;
  select id into v_target from public.wm_accounts where login_id=p_data->>'login_id' and enabled;
  -- Neutral success avoids exposing whether a global identifier exists.
  if not found or v_target=a.id or exists(select 1 from public.wm_memberships where account_id=v_target and workspace_id=w.id and enabled) then return jsonb_build_object('accepted',true);end if;
  update public.wm_membership_invites set status='revoked' where workspace_id=w.id and target_id=v_target and status='pending' and expires_at<=clock_timestamp();
  insert into public.wm_membership_invites(workspace_id,target_id,sender_id,role) values(w.id,v_target,a.id,v_newrole) on conflict do nothing;
  return jsonb_build_object('accepted',true);
 when 'invitations' then
  select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'workspace_name',x.name,'role',i.role,'expires_at',i.expires_at) order by i.created_at desc),'[]'::jsonb) into v_result
  from public.wm_membership_invites i join public.wm_workspaces x on x.id=i.workspace_id and x.enabled
  join public.wm_memberships m on m.account_id=i.sender_id and m.workspace_id=i.workspace_id and m.enabled
  where i.target_id=a.id and i.status='pending' and i.expires_at>clock_timestamp() and (m.role='promoteur' or (m.role='manager' and i.role='staff'));
  return jsonb_build_object('invitations',v_result);
 when 'respond-invite' then
  if jsonb_typeof(p_data->'accept') is distinct from 'boolean' then return null;end if;
  select * into v_inv from public.wm_membership_invites where id=(p_data->>'id')::uuid and target_id=a.id and status='pending' and expires_at>clock_timestamp() for update;
  if not found then return null;end if;
  if not exists(select 1 from public.wm_workspaces x join public.wm_memberships m on m.workspace_id=x.id join public.wm_accounts c on c.id=m.account_id and c.enabled where x.id=v_inv.workspace_id and x.enabled and x.kind='enterprise' and m.account_id=v_inv.sender_id and m.enabled and (m.role='promoteur' or (m.role='manager' and v_inv.role='staff'))) then return null;end if;
  if (p_data->>'accept')::boolean then
   -- Preserve existing active memberships; a disabled membership cannot
   -- silently be revived by an old invitation.
   if exists(select 1 from public.wm_memberships where account_id=a.id and workspace_id=v_inv.workspace_id) then return null;end if;
   insert into public.wm_memberships(account_id,workspace_id,role) values(a.id,v_inv.workspace_id,v_inv.role);
   if v_inv.role='staff' and exists(select 1 from public.wm_memberships m where m.account_id=v_inv.sender_id and m.workspace_id=v_inv.workspace_id and m.enabled and m.role='manager') then
    insert into public.wm_manager_assignments(workspace_id,staff_id,manager_id) values(v_inv.workspace_id,a.id,v_inv.sender_id);
   end if;
   update public.wm_membership_invites set status='accepted' where id=v_inv.id;
  else update public.wm_membership_invites set status='declined' where id=v_inv.id;end if;
  return jsonb_build_object('updated',true);
 when 'manager-assign' then
  if w.kind<>'enterprise' or v_role<>'promoteur' or not (p_data ? 'manager_id') then return null;end if;
  v_target:=(p_data->>'member_id')::uuid;v_manager:=(p_data->>'manager_id')::uuid;
  if not exists(select 1 from public.wm_memberships m join public.wm_accounts c on c.id=m.account_id and c.enabled where m.workspace_id=w.id and m.account_id=v_target and m.enabled and m.role='staff') then return null;end if;
  if v_manager is null then delete from public.wm_manager_assignments where workspace_id=w.id and staff_id=v_target;
  else
   if not exists(select 1 from public.wm_memberships m join public.wm_accounts c on c.id=m.account_id and c.enabled where m.workspace_id=w.id and m.account_id=v_manager and m.enabled and m.role='manager') then return null;end if;
   insert into public.wm_manager_assignments(workspace_id,staff_id,manager_id) values(w.id,v_target,v_manager)
   on conflict(workspace_id,staff_id) do update set manager_id=excluded.manager_id;
  end if;
  return jsonb_build_object('updated',true);
 when 'member-role' then
  v_target:=(p_data->>'member_id')::uuid;v_newrole:=p_data->>'role';
  if w.kind<>'enterprise' or v_role<>'promoteur' or v_newrole is null or v_newrole not in ('manager','staff') or v_target=a.id then return null;end if;
  update public.wm_memberships set role=v_newrole where workspace_id=w.id and account_id=v_target and role in ('manager','staff') and enabled;
  if not found then return null;end if;
  delete from public.wm_manager_assignments where workspace_id=w.id and (staff_id=v_target or manager_id=v_target);
  update public.wm_device_sessions set revoked_at=clock_timestamp() where workspace_id=w.id and account_id=v_target and revoked_at is null;
  update public.wm_membership_invites set status='revoked' where workspace_id=w.id and sender_id=v_target and status='pending';
  return jsonb_build_object('updated',true);
 when 'revoke-member' then
  v_target:=(p_data->>'member_id')::uuid;
  if w.kind<>'enterprise' or v_target=a.id or not (v_role='promoteur' or (v_role='manager' and exists(select 1 from public.wm_manager_assignments ma where ma.workspace_id=w.id and ma.staff_id=v_target and ma.manager_id=a.id))) then return null;end if;
  update public.wm_memberships set enabled=false where workspace_id=w.id and account_id=v_target and (role='staff' or (v_role='promoteur' and role='manager')) and enabled;
  if not found then return null;end if;
  update public.wm_device_sessions set revoked_at=clock_timestamp() where workspace_id=w.id and account_id=v_target and revoked_at is null;
  update public.wm_membership_invites set status='revoked' where workspace_id=w.id and (sender_id=v_target or target_id=v_target) and status='pending';
  delete from public.wm_manager_assignments where workspace_id=w.id and (staff_id=v_target or manager_id=v_target);
  delete from public.wm_favorites where workspace_id=w.id and (account_id=v_target or contact_id=v_target);
  delete from public.wm_contact_groups where workspace_id=w.id and account_id=v_target;
  update public.wm_contact_groups set member_ids=array_remove(member_ids,v_target) where workspace_id=w.id and v_target=any(member_ids);
  return jsonb_build_object('updated',true);
 else return null;
 end case;
end $wm$;
revoke all on function public.wm_identity_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_identity_action(text,text,jsonb) to service_role;
-- Separate rotating opaque refresh credentials. The refresh secret is never
-- stored in clear text on the server, and its absolute deadline is preserved.
create function public.wm_attach_refresh(p_hash text,p_refresh_hash text,p_remember boolean)
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;
begin
 if p_refresh_hash is null or p_refresh_hash !~ '^[a-f0-9]{64}$' or p_refresh_hash=p_hash or p_remember is null then return false;end if;
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return false;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for update;
 if not found then return false;end if;
 update public.wm_device_sessions set refresh_hash=p_refresh_hash,refresh_until=clock_timestamp()+case when p_remember then interval '30 days' else interval '8 hours' end,remember_me=p_remember
 where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() and refresh_hash is null
 and exists(select 1 from public.wm_session_context(p_hash) c where c.session_id=s.session_id and not c.password_change_required);
 return found;
end $wm$;
revoke all on function public.wm_attach_refresh(text,text,boolean) from public,anon,authenticated;
grant execute on function public.wm_attach_refresh(text,text,boolean) to service_role;

create function public.wm_rotate_refresh(p_old text,p_installation uuid,p_access text,p_refresh text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare v_account uuid; d public.wm_device_sessions%rowtype; v_id uuid; t timestamptz;
begin
 if p_old is null or p_access is null or p_refresh is null or p_access !~ '^[a-f0-9]{64}$' or p_refresh !~ '^[a-f0-9]{64}$' or p_access=p_refresh or p_old=p_access or p_old=p_refresh then return null;end if;
 select account_id into v_account from public.wm_device_sessions where refresh_hash=p_old;
 if not found then return null;end if;
 perform 1 from public.wm_accounts where id=v_account and enabled and not password_change_required and password_change_id is null for update;
 if not found then return null;end if;
 select * into d from public.wm_device_sessions where refresh_hash=p_old and account_id=v_account and installation_id=p_installation and revoked_at is null for update;
 if not found then return null;end if;
 t:=clock_timestamp();
 if d.refresh_until<=t or not exists(select 1 from public.wm_memberships m join public.wm_workspaces w on w.id=m.workspace_id and w.enabled where m.account_id=d.account_id and m.workspace_id=d.workspace_id and m.enabled and ((w.kind='individual' and m.role='owner') or (w.kind='enterprise' and m.role in ('promoteur','manager','staff')))) then return null;end if;
 update public.wm_device_sessions set revoked_at=t,refresh_hash=null,refresh_until=null where id=d.id;
 insert into public.wm_device_sessions(account_id,installation_id,workspace_id,token_hash,expires_at,refresh_hash,refresh_until,remember_me)
 values(d.account_id,d.installation_id,d.workspace_id,p_access,least(t+interval '30 minutes',d.refresh_until),p_refresh,d.refresh_until,d.remember_me) returning id into v_id;
 return v_id;
end $wm$;
revoke all on function public.wm_rotate_refresh(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.wm_rotate_refresh(text,uuid,text,text) to service_role;

-- Private self-profile thumbnail. No public Storage URL or cross-account access.
create table public.wm_profile_photos(
 account_id uuid primary key references public.wm_accounts(id) on delete cascade,
 jpeg bytea not null check(octet_length(jpeg) between 4 and 65536),
 updated_at timestamptz not null default clock_timestamp()
);
alter table public.wm_profile_photos enable row level security;
revoke all on public.wm_profile_photos from public,anon,authenticated;
grant select,insert,update,delete on public.wm_profile_photos to service_role;
create function public.wm_profile_photo(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; b bytea; raw text;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 perform 1 from public.wm_accounts where id=s.account_id and enabled and not password_change_required for update;
 if not found or not exists(select 1 from public.wm_session_context(p_hash) c where c.session_id=s.session_id and not c.password_change_required) then return null;end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' then return null;end if;
 if p_action='photo-read' then
  if p_data<>'{}'::jsonb then return null;end if;
  select jpeg into b from public.wm_profile_photos where account_id=s.account_id;
  return jsonb_build_object('jpeg',case when b is null then null else replace(encode(b,'base64'),chr(10),'') end);
 elsif p_action='photo-delete' then
  if p_data<>'{}'::jsonb then return null;end if;
  delete from public.wm_profile_photos where account_id=s.account_id;
  return jsonb_build_object('updated',true);
 elsif p_action='photo-save' then
  if not (p_data ? 'jpeg') or p_data-'jpeg'<>'{}'::jsonb or jsonb_typeof(p_data->'jpeg')<>'string' then return null;end if;
  raw:=p_data->>'jpeg';
  if length(raw)>87384 or length(raw)%4<>0 or raw !~ '^[A-Za-z0-9+/]+={0,2}$' then return null;end if;
  begin b:=decode(raw,'base64');exception when others then return null;end;
  if octet_length(b) not between 4 and 65536 or substring(b from 1 for 2)<>decode('ffd8','hex') or substring(b from octet_length(b)-1 for 2)<>decode('ffd9','hex') then return null;end if;
  insert into public.wm_profile_photos(account_id,jpeg) values(s.account_id,b)
  on conflict(account_id) do update set jpeg=excluded.jpeg,updated_at=clock_timestamp();
  return jsonb_build_object('updated',true);
 end if;
 return null;
end $wm$;
revoke all on function public.wm_profile_photo(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_profile_photo(text,text,jsonb) to service_role;
commit;
