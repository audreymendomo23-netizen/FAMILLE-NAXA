-- Candidate only: load after family_admins and WideMeet identity/rooms/billing/support.
-- The central operator never receives a WideMeet device bearer. Existing support engine is reused.
begin;
create table public.wm_central_agent_links(
 operator_id uuid primary key references auth.users(id),
 account_id uuid not null unique references public.wm_support_agents(account_id),
 enabled boolean not null default false,
 changed_at timestamptz not null default clock_timestamp()
);
create table public.wm_central_support_sessions(
 auth_session_id uuid primary key, operator_id uuid not null references public.wm_central_agent_links(operator_id),
 device_id uuid not null unique references public.wm_device_sessions(id)
);
create table public.wm_central_audit(
 id bigint generated always as identity primary key, actor_id uuid not null,
 action text not null, target_id uuid, at timestamptz not null default clock_timestamp()
);
alter table public.wm_central_agent_links enable row level security;
alter table public.wm_central_support_sessions enable row level security;
alter table public.wm_central_audit enable row level security;
revoke all on public.wm_central_agent_links,public.wm_central_support_sessions,public.wm_central_audit from public,anon,authenticated;
-- Bound service-only helper; no auth-schema grant to client roles.
create function public.wm_central_auth_live(p_user uuid,p_session uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $wm$
 select exists(select 1 from auth.sessions s where s.id=p_session and s.user_id=p_user and s.aal::text='aal2' and (s.not_after is null or s.not_after>now()))
$wm$;
revoke all on function public.wm_central_auth_live(uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_central_auth_live(uuid,uuid) to service_role;
-- Preserve the existing customer check; additionally invalidate bridged calls when central authority disappears.
create or replace function public.wm_support_session_live(p_id uuid)
returns boolean language sql security definer set search_path=pg_catalog,public as $wm$
 select exists(select 1 from public.wm_device_sessions d cross join lateral public.wm_session_context(d.token_hash) c
 where d.id=p_id and c.session_id=d.id and not c.password_change_required and d.expires_at>clock_timestamp()
 and (not exists(select 1 from public.wm_central_support_sessions z where z.device_id=d.id)
 or exists(select 1 from public.wm_central_support_sessions z join public.wm_central_agent_links l on l.operator_id=z.operator_id and l.enabled and l.account_id=d.account_id
 join public.wm_support_agents a on a.account_id=l.account_id and a.enabled
 where z.device_id=d.id and public.wm_central_auth_live(z.operator_id,z.auth_session_id))))
$wm$;
revoke all on function public.wm_support_session_live(uuid) from public,anon,authenticated;
grant execute on function public.wm_support_session_live(uuid) to service_role;
create function public.wm_central_dispatch(p_user uuid,p_session uuid,p_exp timestamptz,p_new_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,auth,famille_core as $wm$
declare adm boolean; ag uuid; wid uuid; dev uuid; h text; tid uuid; target uuid; enabled boolean; v jsonb;
begin
 if p_exp is null or p_exp<=clock_timestamp() or not public.wm_central_auth_live(p_user,p_session) then return null;end if;
 select exists(select 1 from famille_core.family_admins f where f.user_id=p_user and f.status='active' and f.revoked_at is null) into adm;
 select l.account_id into ag from public.wm_central_agent_links l join public.wm_support_agents a on a.account_id=l.account_id and a.enabled
 join public.wm_accounts x on x.id=l.account_id and x.enabled and not x.password_change_required
 where l.operator_id=p_user and l.enabled;
 if p_action='capabilities' then
  if not adm and ag is null then return null;end if;
  return jsonb_build_object('admin',adm,'agent',ag is not null);
 end if;
 if p_action='overview' and adm then
  return jsonb_build_object(
  'individuals',(select count(distinct m.account_id) from public.wm_memberships m join public.wm_workspaces w on w.id=m.workspace_id where w.kind='individual' and m.role='owner'),
  'companies',(select count(*) from public.wm_workspaces where kind='enterprise'),
  'active_companies',(select count(*) from public.wm_workspaces where kind='enterprise' and enabled),
  'active_accounts',(select count(*) from public.wm_accounts where enabled),
  'new_accounts_30d',(select count(*) from public.wm_accounts where created_at>=now()-interval '30 days'),
  'rooms',(select count(*) from public.wm_rooms),
  'subscriptions',(select count(*) from public.wm_room_entitlements e join public.wm_workspaces w on w.id=e.workspace_id where w.kind='enterprise' and w.enabled and e.enabled and e.valid_until>now()),
  'confirmed_xaf',(select coalesce(sum(amount),0) from public.wm_billing_intents where status='confirmed'),
  'open_tickets',(select count(*) from public.wm_support_tickets where status<>'closed'),
  'closed_tickets',(select count(*) from public.wm_support_tickets where status='closed'),
  'satisfaction',(select round(avg(rating),2) from public.wm_support_feedback));
 end if;
 if p_action='agent-list' and adm then
  return jsonb_build_object('items',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select operator_id,account_id,enabled,changed_at from public.wm_central_agent_links order by changed_at desc limit 200) q));
 end if;
 if p_action='agent-set' and adm then
  target:=(p_data->>'operator_id')::uuid;ag:=(p_data->>'account_id')::uuid;
  if target is null or ag is null or target=p_user or jsonb_typeof(p_data->'enabled') is distinct from 'boolean' then return null;end if;
  enabled:=(p_data->>'enabled')::boolean;
  -- Map only already-provisioned dedicated support accounts. No new passwords or identities.
  if not exists(select 1 from auth.users u where u.id=target) or not exists(select 1 from public.wm_support_agents a join public.wm_accounts x on x.id=a.account_id where a.account_id=ag and a.enabled and x.enabled and x.auth_user_id<>target)
   or (select count(*) from public.wm_memberships where account_id=ag)<>1
   or not exists(select 1 from public.wm_memberships m join public.wm_workspaces w on w.id=m.workspace_id where m.account_id=ag and m.enabled and m.role='owner' and w.kind='individual' and w.enabled)
   or exists(select 1 from famille_core.family_admins where user_id=target and status='active') then return null;end if;
  insert into public.wm_central_agent_links(operator_id,account_id,enabled) values(target,ag,enabled)
   on conflict(operator_id) do update set enabled=excluded.enabled,changed_at=clock_timestamp()
   where wm_central_agent_links.account_id=excluded.account_id;
  if not found then return null;end if;
  if not enabled then update public.wm_device_sessions d set revoked_at=clock_timestamp(),refresh_hash=null,refresh_until=null where d.revoked_at is null and exists(select 1 from public.wm_central_support_sessions z where z.operator_id=target and z.device_id=d.id);end if;
  insert into public.wm_central_audit(actor_id,action,target_id) values(p_user,case when enabled then 'agent-enabled' else 'agent-disabled' end,target);
  return jsonb_build_object('saved',true);
 end if;
 if ag is null or p_action not in ('support-queue','support-claim','support-read','support-reply','support-close','support-release','support-call-read','support-call-accept','support-call-decline','support-call-end','support-call-heartbeat','support-call-grant','support-screen-stop') then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-central:'||p_session::text,0));
 -- Keep the dedicated mapped agent authority locked through the support operation.
 perform 1 from public.wm_central_agent_links l join public.wm_support_agents a on a.account_id=l.account_id where l.operator_id=p_user and l.account_id=ag and l.enabled and a.enabled for share of l,a;
 if not found then return null;end if;
 if p_action<>'support-queue' then
  tid:=(p_data->>'ticket_id')::uuid;
  if not exists(select 1 from public.wm_support_tickets where id=tid and requester_id<>ag and category not in ('privacy_access','privacy_rectify','privacy_erase')) then return null;end if;
 end if;
 select z.device_id,d.token_hash into dev,h from public.wm_central_support_sessions z join public.wm_device_sessions d on d.id=z.device_id where z.auth_session_id=p_session and z.operator_id=p_user;
 if not found then
  if p_new_hash is null or p_new_hash !~ '^[a-f0-9]{64}$' then return null;end if;
  select m.workspace_id into wid from public.wm_memberships m join public.wm_workspaces w on w.id=m.workspace_id where m.account_id=ag and m.enabled and m.role='owner' and w.kind='individual' and w.enabled;
  if wid is null or (select count(*) from public.wm_memberships where account_id=ag)<>1 then return null;end if;
  dev:=public.wm_issue_device_session(ag,p_session,wid,p_new_hash);
  update public.wm_device_sessions set expires_at=least(p_exp,created_at+interval '9 minutes') where id=dev;
  insert into public.wm_central_support_sessions values(p_session,p_user,dev);
  h:=p_new_hash;
 end if;
 if not public.wm_support_session_live(dev) then return null;end if;
 if p_action='support-call-grant' then
  if not exists(select 1 from public.wm_support_calls where id=(p_data->>'call_id')::uuid and ticket_id=tid) then return null;end if;
  return public.wm_support_issue_media(h,(p_data->>'call_id')::uuid,p_data->>'handle');
 end if;
 v:=public.wm_support_action(h,p_action,p_data);
 if p_action='support-queue' and v is not null then
  select jsonb_build_object('items',coalesce(jsonb_agg(e),'[]'::jsonb)) into v from jsonb_array_elements(v->'items') e where e->>'category' not in ('privacy_access','privacy_rectify','privacy_erase');
 end if;
 if v is not null and p_action in ('support-claim','support-reply','support-close','support-release','support-call-accept','support-call-decline','support-call-end','support-screen-stop') then
  insert into public.wm_central_audit(actor_id,action,target_id) values(p_user,p_action,tid);
 end if;
 return v;
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_central_dispatch(uuid,uuid,timestamptz,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_central_dispatch(uuid,uuid,timestamptz,text,text,jsonb) to service_role;
commit;
