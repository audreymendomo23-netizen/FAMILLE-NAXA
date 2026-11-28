-- After central registry and wm_central_naxa. Service-only signed NAXA server federation.
begin;
create table public.wm_naxa_operator_links(
 legacy_user uuid primary key,
 operator_id uuid not null unique references auth.users(id),
 operator_role text not null check(operator_role in ('admin','agent')),
 enabled boolean not null default false
);
create table public.wm_naxa_bridge_sessions(
 legacy_user uuid not null references public.wm_naxa_operator_links(legacy_user),
 legacy_session uuid not null, bridge_id uuid not null unique default gen_random_uuid(),
 operator_id uuid not null references auth.users(id), lease_until timestamptz not null,
 primary key(legacy_user,legacy_session)
);
create table public.wm_naxa_bridge_nonces(nonce uuid primary key,expires_at timestamptz not null);
alter table public.wm_naxa_operator_links enable row level security;
alter table public.wm_naxa_bridge_sessions enable row level security;
alter table public.wm_naxa_bridge_nonces enable row level security;
revoke all on public.wm_naxa_operator_links,public.wm_naxa_bridge_sessions,public.wm_naxa_bridge_nonces from public,anon,authenticated;
create or replace function public.wm_central_auth_live(p_user uuid,p_session uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $wm$
 select exists(select 1 from auth.sessions s where s.id=p_session and s.user_id=p_user and s.aal::text='aal2' and (s.not_after is null or s.not_after>now()))
 or exists(select 1 from public.wm_naxa_bridge_sessions b join public.wm_naxa_operator_links l on l.legacy_user=b.legacy_user and l.operator_id=b.operator_id and l.enabled
 where b.bridge_id=p_session and b.operator_id=p_user and b.lease_until>now())
$wm$;
revoke all on function public.wm_central_auth_live(uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_central_auth_live(uuid,uuid) to service_role;
create function public.wm_naxa_federated_dispatch(p_legacy_user uuid,p_legacy_session uuid,p_role text,p_exp timestamptz,p_nonce uuid,p_issued timestamptz,p_new_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,famille_core as $wm$
declare op uuid; bridge uuid; lease timestamptz; v jsonb;
begin
 if p_nonce is null or p_issued is null or p_issued<clock_timestamp()-interval '25 seconds' or p_issued>clock_timestamp()+interval '5 seconds' or p_exp is null or p_exp<=clock_timestamp() then return null;end if;
 if (p_role='admin' and p_action not in ('capabilities','overview','agent-list')) or (p_role='agent' and p_action not in ('capabilities','support-queue','support-read','support-claim','support-reply','support-close','support-release')) or p_role not in ('admin','agent') then return null;end if;
 -- Only the verified server can call; consume each signed request exactly once.
 delete from public.wm_naxa_bridge_nonces where expires_at<clock_timestamp();
 insert into public.wm_naxa_bridge_nonces values(p_nonce,p_issued+interval '60 seconds') on conflict do nothing;
 if not found then return null;end if;
 select operator_id into op from public.wm_naxa_operator_links where legacy_user=p_legacy_user and enabled and operator_role=p_role for share;
 if not found then return null;end if;
 if p_role='admin' and not exists(select 1 from famille_core.family_admins where user_id=op and status='active' and revoked_at is null) then return null;end if;
 if p_role='agent' and not exists(select 1 from public.wm_central_agent_links l join public.wm_support_agents a on a.account_id=l.account_id and a.enabled where l.operator_id=op and l.enabled) then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-naxa-bridge:'||p_legacy_session::text,0));
 select bridge_id,lease_until into bridge,lease from public.wm_naxa_bridge_sessions where legacy_user=p_legacy_user and legacy_session=p_legacy_session for update;
 if not found then
 insert into public.wm_naxa_bridge_sessions(legacy_user,legacy_session,operator_id,lease_until) values(p_legacy_user,p_legacy_session,op,least(p_exp,clock_timestamp()+interval '25 seconds')) returning bridge_id into bridge;
 elsif lease<=clock_timestamp() then
 update public.wm_naxa_bridge_sessions set bridge_id=gen_random_uuid(),operator_id=op,lease_until=least(p_exp,clock_timestamp()+interval '25 seconds') where legacy_user=p_legacy_user and legacy_session=p_legacy_session returning bridge_id into bridge;
 else
 update public.wm_naxa_bridge_sessions set lease_until=least(p_exp,clock_timestamp()+interval '25 seconds') where legacy_user=p_legacy_user and legacy_session=p_legacy_session and operator_id=op;
 if not found then return null;end if;
 end if;
 v:=public.wm_central_dispatch(op,bridge,p_exp,p_new_hash,p_action,p_data);
 if p_action='capabilities' and v is not null then return jsonb_build_object('admin',p_role='admin' and v->>'admin'='true','agent',p_role='agent' and v->>'agent'='true');end if;
 return v;
end $wm$;
revoke all on function public.wm_naxa_federated_dispatch(uuid,uuid,text,timestamptz,uuid,timestamptz,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_naxa_federated_dispatch(uuid,uuid,text,timestamptz,uuid,timestamptz,text,text,jsonb) to service_role;
commit;
