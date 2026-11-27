begin;
-- WideMeet-only support intake, adapted from NAXA atomic queue claim.
-- All data and actions are service-role only. No support access to meeting records.
create table public.wm_support_agents(
 account_id uuid primary key references public.wm_accounts(id), enabled boolean not null default false
);
create table public.wm_support_tickets(
 id uuid primary key, workspace_id uuid not null references public.wm_workspaces(id),
 requester_id uuid not null references public.wm_accounts(id),
 agent_id uuid references public.wm_support_agents(account_id),
 subject text not null check(length(subject) between 1 and 120),
 category text not null check(category in ('account','meeting','billing','other')),
 status text not null default 'open' check(status in ('open','assigned','waiting','closed')),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp()
);
create index wm_support_requester_idx on public.wm_support_tickets(requester_id,workspace_id,updated_at desc);
create index wm_support_queue_idx on public.wm_support_tickets(status,agent_id,created_at);
create table public.wm_support_messages(
 id uuid primary key, ticket_id uuid not null references public.wm_support_tickets(id),
 actor_id uuid not null references public.wm_accounts(id),
 author_kind text not null check(author_kind in ('requester','agent')),
 body text not null check(length(body) between 1 and 4000),
 created_at timestamptz not null default clock_timestamp()
);
create index wm_support_messages_idx on public.wm_support_messages(ticket_id,created_at,id);
alter table public.wm_support_agents enable row level security;
alter table public.wm_support_tickets enable row level security;
alter table public.wm_support_messages enable row level security;
revoke all on public.wm_support_agents,public.wm_support_tickets,public.wm_support_messages from public,anon,authenticated;
grant select,insert,update,delete on public.wm_support_agents,public.wm_support_tickets,public.wm_support_messages to service_role;
create function public.wm_support_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; t public.wm_support_tickets%rowtype; m public.wm_support_messages%rowtype; aid uuid; tid uuid; mid uuid; b text; subj text; cat text; agent boolean:=false; own boolean:=false; kind text; result jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 aid:=s.account_id;
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 perform 1 from public.wm_accounts where id=aid and enabled and not password_change_required for share;if not found then return null;end if;
 perform 1 from public.wm_workspaces where id=s.workspace_id and enabled for share;if not found then return null;end if;
 perform 1 from public.wm_memberships where account_id=aid and workspace_id=s.workspace_id and enabled for share;if not found then return null;end if;
 perform 1 from public.wm_device_sessions where id=s.session_id and revoked_at is null and expires_at>clock_timestamp() for share;if not found then return null;end if;
 -- Serialize writes for each requester/agent; row lock below arbitrates competing agents.
 perform pg_advisory_xact_lock(hashtextextended('wm-support:'||aid::text,0));
 if not exists(select 1 from public.wm_session_context(p_hash) c where c.session_id=s.session_id and not c.password_change_required) then return null;end if;
 select enabled into agent from public.wm_support_agents where account_id=aid for share;
 agent:=coalesce(agent,false);
 if p_action='support-capabilities' then return jsonb_build_object('agent',agent);end if;
 if p_action='support-list' then
  select coalesce(jsonb_agg(to_jsonb(q) order by q.updated_at desc),'[]'::jsonb) into result from
   (select id,subject,category,status,created_at,updated_at from public.wm_support_tickets where requester_id=aid and workspace_id=s.workspace_id order by updated_at desc limit 100) q;
  return jsonb_build_object('items',result);
 end if;
 if p_action='support-queue' then
  if not agent then return null;end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at),'[]'::jsonb) into result from
   (select id,category,status,created_at,updated_at,case when agent_id=aid then subject else null end as subject,coalesce(agent_id=aid,false) as assigned from public.wm_support_tickets where agent_id=aid or (agent_id is null and status='open' and requester_id<>aid) order by created_at limit 100) q;
  return jsonb_build_object('items',result);
 end if;
 tid:=(p_data->>'ticket_id')::uuid;
 if tid is null then return null;end if;
 if p_action='support-create' then
  subj:=btrim(p_data->>'subject');cat:=p_data->>'category';b:=btrim(p_data->>'body');mid:=(p_data->>'message_id')::uuid;
  if subj is null or length(subj) not between 1 and 120 or cat is null or cat not in ('account','meeting','billing','other') or b is null or length(b) not between 1 and 4000 or mid is null then return null;end if;
  select * into t from public.wm_support_tickets where id=tid for update;
  if found then
   if t.requester_id<>aid or t.workspace_id<>s.workspace_id or t.subject<>subj or t.category<>cat or not exists(select 1 from public.wm_support_messages x where x.id=mid and x.ticket_id=tid and x.actor_id=aid and x.body=b and x.author_kind='requester') then return null;end if;
   return jsonb_build_object('id',tid,'created',true);
  end if;
  if (select count(*) from public.wm_support_tickets where requester_id=aid and workspace_id=s.workspace_id and status<>'closed')>=10 then return null;end if;
  if (select count(*) from public.wm_support_tickets where requester_id=aid and created_at>clock_timestamp()-interval '1 hour')>=5 then return null;end if;
  insert into public.wm_support_tickets(id,workspace_id,requester_id,subject,category) values(tid,s.workspace_id,aid,subj,cat);
  insert into public.wm_support_messages(id,ticket_id,actor_id,author_kind,body) values(mid,tid,aid,'requester',b);
  return jsonb_build_object('id',tid,'created',true);
 end if;
 select * into t from public.wm_support_tickets where id=tid for update;
 if not found then return null;end if;
 own:=t.requester_id=aid and t.workspace_id=s.workspace_id;
 if p_action='support-claim' then
  if not agent or t.requester_id=aid then return null;end if;
  if t.agent_id=aid and t.status<>'closed' then return jsonb_build_object('claimed',true);end if;
  if t.agent_id is not null or t.status<>'open' then return null;end if;
  update public.wm_support_tickets set agent_id=aid,status='assigned',updated_at=clock_timestamp() where id=tid;
  return jsonb_build_object('claimed',true);
 end if;
 if not own and not (agent and coalesce(t.agent_id=aid,false)) then return null;end if;
 kind:=case when own then 'requester' else 'agent' end;
 if p_action='support-read' then
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at,q.id),'[]'::jsonb) into result from
  (select id,author_kind,body,created_at from public.wm_support_messages where ticket_id=tid order by created_at,id limit 500) q;
  return jsonb_build_object('id',tid,'subject',t.subject,'category',t.category,'status',t.status,'messages',result);
 end if;
 if p_action='support-reply' then
  mid:=(p_data->>'message_id')::uuid;b:=btrim(p_data->>'body');
  if mid is null or b is null or length(b) not between 1 and 4000 then return null;end if;
  select * into m from public.wm_support_messages where id=mid;
  if found then
   if m.ticket_id=tid and m.actor_id=aid and m.body=b and m.author_kind=kind then return jsonb_build_object('sent',true);end if;return null;
  end if;
  if t.status='closed' or (select count(*) from public.wm_support_messages where ticket_id=tid)>=500 or (select count(*) from public.wm_support_messages where actor_id=aid and created_at>clock_timestamp()-interval '1 minute')>=20 then return null;end if;
  insert into public.wm_support_messages(id,ticket_id,actor_id,author_kind,body) values(mid,tid,aid,kind,b);
  update public.wm_support_tickets set status=case when kind='agent' then 'waiting' when agent_id is not null then 'assigned' else 'open' end,updated_at=clock_timestamp() where id=tid;
  return jsonb_build_object('sent',true);
 end if;
 if p_action='support-close' then
  update public.wm_support_tickets set status='closed',updated_at=clock_timestamp() where id=tid and status<>'closed';
  return jsonb_build_object('closed',true);
 end if;
 return null;
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_support_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_support_action(text,text,jsonb) to service_role;
commit;
