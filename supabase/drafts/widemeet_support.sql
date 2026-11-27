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
-- Ticket-scoped satisfaction and assignment history; no meeting data.
create table public.wm_support_feedback(
 ticket_id uuid primary key references public.wm_support_tickets(id),
 requester_id uuid not null references public.wm_accounts(id),
 rating integer not null check(rating between 1 and 5),
 created_at timestamptz not null default clock_timestamp()
);
create table public.wm_support_assignment_events(
 id bigint generated always as identity primary key,
 ticket_id uuid not null references public.wm_support_tickets(id),
 actor_id uuid not null references public.wm_accounts(id),
 action text not null check(action in ('claim','release')),
 assignment_id bigint references public.wm_support_assignment_events(id),
 created_at timestamptz not null default clock_timestamp(),
 check((action='claim' and assignment_id is null) or (action='release' and assignment_id is not null))
);
create unique index wm_support_release_once on public.wm_support_assignment_events(assignment_id) where action='release';
create index wm_support_assignment_ticket_idx on public.wm_support_assignment_events(ticket_id,id desc);
alter table public.wm_support_feedback enable row level security;
alter table public.wm_support_assignment_events enable row level security;
revoke all on public.wm_support_feedback,public.wm_support_assignment_events from public,anon,authenticated;
grant select,insert on public.wm_support_feedback,public.wm_support_assignment_events to service_role;
grant usage,select on sequence public.wm_support_assignment_events_id_seq to service_role;
alter table public.wm_support_agents enable row level security;
alter table public.wm_support_tickets enable row level security;
alter table public.wm_support_messages enable row level security;
revoke all on public.wm_support_agents,public.wm_support_tickets,public.wm_support_messages from public,anon,authenticated;
grant select,insert,update,delete on public.wm_support_agents,public.wm_support_tickets,public.wm_support_messages to service_role;
-- B5: durable control plane, not a media grant. No capture or transport data stored.
create table public.wm_support_calls(
 id uuid primary key, ticket_id uuid not null references public.wm_support_tickets(id),
 assignment_id bigint not null references public.wm_support_assignment_events(id),
 requester_session uuid not null references public.wm_device_sessions(id),
 agent_session uuid references public.wm_device_sessions(id),
 state text not null check(state in ('requested','active','declined','ended')),
 deadline timestamptz not null, requester_lease timestamptz, agent_lease timestamptz,
 screen_id uuid, screen_state text check(screen_state in ('consented','active')),
 check((screen_id is null)=(screen_state is null))
);
create unique index wm_support_one_live_call on public.wm_support_calls(ticket_id) where state in ('requested','active');
create table public.wm_support_call_events(
 id bigint generated always as identity primary key, call_id uuid not null references public.wm_support_calls(id),
 actor_id uuid not null references public.wm_accounts(id),
 action text not null check(action in ('request','accept','decline','end','expired','screen-consent','screen-start','screen-stop')),
 share_id uuid, at timestamptz not null default clock_timestamp()
);
create unique index wm_support_one_consent on public.wm_support_call_events(call_id,share_id) where action='screen-consent';
-- Recovery reviewers are separately provisioned. A review never changes a credential.
create table public.wm_support_recovery_reviewers(account_id uuid primary key references public.wm_accounts(id),enabled boolean not null default false);
create table public.wm_support_recovery_reviews(
 request_id uuid not null references public.wm_recovery_requests(id),
 reviewer_id uuid not null references public.wm_support_recovery_reviewers(account_id),
 decision text not null check(decision in ('escalate','reject')),
 evidence_ref uuid not null, created_at timestamptz not null default clock_timestamp(),
 primary key(request_id,reviewer_id), unique(request_id,evidence_ref)
);
alter table public.wm_support_calls enable row level security;
alter table public.wm_support_call_events enable row level security;
alter table public.wm_support_recovery_reviewers enable row level security;
alter table public.wm_support_recovery_reviews enable row level security;
revoke all on public.wm_support_calls,public.wm_support_call_events,public.wm_support_recovery_reviewers,public.wm_support_recovery_reviews from public,anon,authenticated;
grant select,insert,update on public.wm_support_calls to service_role;
grant select,insert on public.wm_support_call_events,public.wm_support_recovery_reviews to service_role;
grant select,insert,update on public.wm_support_recovery_reviewers to service_role;
grant usage,select on sequence public.wm_support_call_events_id_seq to service_role;
-- Use the exact session, not just account/device; rotation invalidates the call.
create function public.wm_support_session_live(p_id uuid) returns boolean language sql security invoker set search_path=pg_catalog,public as $wm$
 select exists(select 1 from public.wm_device_sessions d cross join lateral public.wm_session_context(d.token_hash) c
 where d.id=p_id and c.session_id=d.id and not c.password_change_required and d.expires_at>clock_timestamp())
$wm$;
revoke all on function public.wm_support_session_live(uuid) from public,anon,authenticated;
grant execute on function public.wm_support_session_live(uuid) to service_role;
create function public.wm_support_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record; t public.wm_support_tickets%rowtype; m public.wm_support_messages%rowtype; aid uuid; tid uuid; mid uuid; b text; subj text; cat text; agent boolean:=false; own boolean:=false; kind text; result jsonb; score integer; prior_score integer; assignment bigint; call public.wm_support_calls%rowtype; call_id uuid; share uuid; ts timestamptz; recovery public.wm_recovery_requests%rowtype; decision text; evidence uuid; review public.wm_support_recovery_reviews%rowtype; reviewer boolean;
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
 select coalesce((select enabled from public.wm_support_recovery_reviewers where account_id=aid),false) into reviewer;
 if p_action='support-capabilities' then return jsonb_build_object('agent',agent,'recovery_reviewer',reviewer);end if;
 if p_action in ('support-recovery-queue','support-recovery-review') then
  if not reviewer then return null;end if;
  if p_action='support-recovery-queue' then
   select coalesce(jsonb_agg(to_jsonb(q) order by q.requested_at),'[]'::jsonb) into result from
    (select r.id,r.requested_at,(select count(*) from public.wm_support_recovery_reviews v where v.request_id=r.id and v.decision='escalate') as escalations,
     (select count(*) from public.wm_support_recovery_reviews v where v.request_id=r.id and v.decision='reject') as objections,
     exists(select 1 from public.wm_support_recovery_reviews v where v.request_id=r.id and v.reviewer_id=aid) as reviewed
     from public.wm_recovery_requests r where r.status='pending' and r.account_id<>aid order by r.requested_at limit 100) q;
   return jsonb_build_object('items',result);
  end if;
  tid:=(p_data->>'request_id')::uuid; evidence:=(p_data->>'evidence_ref')::uuid;decision:=p_data->>'decision';
  if tid is null or evidence is null or decision is null or decision not in ('escalate','reject') then return null;end if;
  select * into recovery from public.wm_recovery_requests where id=tid and status='pending' for update;
  if not found or recovery.account_id=aid then return null;end if;
  select * into review from public.wm_support_recovery_reviews where request_id=tid and reviewer_id=aid;
  if found then
   if review.decision=decision and review.evidence_ref=evidence then return jsonb_build_object('recorded',true);end if;return null;
  end if;
  insert into public.wm_support_recovery_reviews(request_id,reviewer_id,decision,evidence_ref) values(tid,aid,decision,evidence);
  return jsonb_build_object('recorded',true);
 end if;
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
  insert into public.wm_support_assignment_events(ticket_id,actor_id,action) values(tid,aid,'claim');
  return jsonb_build_object('claimed',true);
 end if;
 if p_action='support-release' then
  if not agent or t.requester_id=aid or t.status='closed' then return null;end if;
  if jsonb_typeof(p_data->'assignment_version') is distinct from 'string' or coalesce(p_data->>'assignment_version','') !~ '^[1-9][0-9]{0,17}$' then return null;end if;
  assignment:=(p_data->>'assignment_version')::bigint;
  if exists(select 1 from public.wm_support_assignment_events e where e.ticket_id=tid and e.actor_id=aid and e.action='release' and e.assignment_id=assignment) then
   if t.agent_id is null then return jsonb_build_object('released',true);end if;return null;
  end if;
  if t.agent_id is distinct from aid or not exists(select 1 from public.wm_support_assignment_events e where e.ticket_id=tid and e.actor_id=aid and e.action='claim' and e.id=assignment and e.id=(select max(id) from public.wm_support_assignment_events where ticket_id=tid)) then return null;end if;
  with ended as (update public.wm_support_calls set state='ended',screen_id=null,screen_state=null where ticket_id=tid and state in ('requested','active') returning id)
   insert into public.wm_support_call_events(call_id,actor_id,action) select id,aid,'end' from ended;
  update public.wm_support_tickets set agent_id=null,status='open',updated_at=clock_timestamp() where id=tid;
  insert into public.wm_support_assignment_events(ticket_id,actor_id,action,assignment_id) values(tid,aid,'release',assignment);
  return jsonb_build_object('released',true);
 end if;
 if not own and not (agent and coalesce(t.agent_id=aid,false)) then return null;end if;
 kind:=case when own then 'requester' else 'agent' end;
 if p_action in ('support-call-read','support-call-request','support-call-accept','support-call-decline','support-call-end','support-call-heartbeat','support-screen-consent','support-screen-start','support-screen-stop') then
  ts:=clock_timestamp();
  select max(id) into assignment from public.wm_support_assignment_events where ticket_id=tid and action='claim' and actor_id=t.agent_id;
  select * into call from public.wm_support_calls where ticket_id=tid and state in ('requested','active') for update;
  if found and (t.status not in ('assigned','waiting') or t.agent_id is null or call.assignment_id is distinct from assignment
   or not coalesce((select enabled from public.wm_support_agents where account_id=t.agent_id),false)
   or not public.wm_support_session_live(call.requester_session)
   or ts>=call.deadline or (call.state='active' and (not public.wm_support_session_live(call.agent_session) or ts>=call.requester_lease or ts>=call.agent_lease))) then
   update public.wm_support_calls set state='ended',screen_id=null,screen_state=null where id=call.id;
   insert into public.wm_support_call_events(call_id,actor_id,action) values(call.id,aid,'expired');
   call:=null;
  end if;
  if p_action='support-call-request' then
   call_id:=(p_data->>'call_id')::uuid;
   if not own or call_id is null or t.status not in ('assigned','waiting') or assignment is null or not coalesce((select enabled from public.wm_support_agents where account_id=t.agent_id),false) then return null;end if;
   if call.id is not null then
    if call.id=call_id and call.requester_session=s.session_id then return jsonb_build_object('id',call.id,'state',call.state,'screen_state',call.screen_state,'screen_id',call.screen_id);end if;return null;
   end if;
   insert into public.wm_support_calls(id,ticket_id,assignment_id,requester_session,state,deadline) values(call_id,tid,assignment,s.session_id,'requested',ts+interval '60 seconds') returning * into call;
   insert into public.wm_support_call_events(call_id,actor_id,action) values(call.id,aid,'request');
  elsif call.id is null then
   if p_action='support-call-read' then return jsonb_build_object('state','idle');end if;return null;
  else
   if own and call.requester_session<>s.session_id or not own and call.agent_session is not null and call.agent_session<>s.session_id then return null;end if;
   if p_action<>'support-call-read' and ((p_data->>'call_id')::uuid is distinct from call.id) then return null;end if;
   if p_action='support-call-accept' then
    if own or call.state<>'requested' then return null;end if;
    update public.wm_support_calls set state='active',agent_session=s.session_id,deadline=ts+interval '30 minutes',requester_lease=ts+interval '30 seconds',agent_lease=ts+interval '30 seconds' where id=call.id returning * into call;
    insert into public.wm_support_call_events(call_id,actor_id,action) values(call.id,aid,'accept');
   elsif p_action='support-call-decline' then
    if own or call.state<>'requested' then return null;end if;
    update public.wm_support_calls set state='declined' where id=call.id returning * into call;
    insert into public.wm_support_call_events(call_id,actor_id,action) values(call.id,aid,'decline');
   elsif p_action='support-call-end' then
    update public.wm_support_calls set state='ended',screen_id=null,screen_state=null where id=call.id returning * into call;
    insert into public.wm_support_call_events(call_id,actor_id,action) values(call.id,aid,'end');
   elsif p_action='support-call-heartbeat' then
    if call.state<>'active' then return null;end if;
    update public.wm_support_calls set requester_lease=case when own then least(deadline,ts+interval '30 seconds') else requester_lease end,agent_lease=case when not own then least(deadline,ts+interval '30 seconds') else agent_lease end where id=call.id returning * into call;
   elsif p_action in ('support-screen-consent','support-screen-start','support-screen-stop') then
    if call.state<>'active' then return null;end if;
    share:=(p_data->>'share_id')::uuid;if share is null then return null;end if;
    if p_action='support-screen-consent' then
     if not own or call.screen_id is not null then return null;end if;
     insert into public.wm_support_call_events(call_id,actor_id,action,share_id) values(call.id,aid,'screen-consent',share);
     update public.wm_support_calls set screen_id=share,screen_state='consented' where id=call.id returning * into call;
    elsif p_action='support-screen-start' then
     if not own or call.screen_id is distinct from share or call.screen_state<>'consented' then return null;end if;
     update public.wm_support_calls set screen_state='active' where id=call.id returning * into call;
     insert into public.wm_support_call_events(call_id,actor_id,action,share_id) values(call.id,aid,'screen-start',share);
    else
     if call.screen_id is distinct from share then return null;end if;
     update public.wm_support_calls set screen_id=null,screen_state=null where id=call.id returning * into call;
     insert into public.wm_support_call_events(call_id,actor_id,action,share_id) values(call.id,aid,'screen-stop',share);
    end if;
   end if;
  end if;
  return jsonb_build_object('id',call.id,'state',call.state,'screen_state',call.screen_state,'screen_id',call.screen_id,'transport_ready',false);
 end if;
 if p_action='support-read' then
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at,q.id),'[]'::jsonb) into result from
  (select id,author_kind,body,created_at from public.wm_support_messages where ticket_id=tid order by created_at,id limit 500) q;
  return jsonb_build_object('id',tid,'subject',t.subject,'category',t.category,'status',t.status,'messages',result,'viewer',kind,'assignment_version',case when kind='agent' then (select max(id)::text from public.wm_support_assignment_events where ticket_id=tid and action='claim') else null end,'feedback',case when own then (select rating from public.wm_support_feedback where ticket_id=tid) else null end);
 end if;
 if p_action='support-feedback' then
  if not own or t.status<>'closed' or jsonb_typeof(p_data->'rating') is distinct from 'number' or coalesce(p_data->>'rating','') !~ '^[1-5]$' then return null;end if;
  score:=(p_data->>'rating')::integer;
  select rating into prior_score from public.wm_support_feedback where ticket_id=tid;
  if found then
   if prior_score=score then return jsonb_build_object('saved',true,'rating',score);end if;
   return null;
  end if;
  insert into public.wm_support_feedback(ticket_id,requester_id,rating) values(tid,aid,score);
  return jsonb_build_object('saved',true,'rating',score);
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
  with ended as (update public.wm_support_calls set state='ended',screen_id=null,screen_state=null where ticket_id=tid and state in ('requested','active') returning id)
   insert into public.wm_support_call_events(call_id,actor_id,action) select id,aid,'end' from ended;
  update public.wm_support_tickets set status='closed',updated_at=clock_timestamp() where id=tid and status<>'closed';
  return jsonb_build_object('closed',true);
 end if;
 return null;
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_support_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_support_action(text,text,jsonb) to service_role;
commit;
