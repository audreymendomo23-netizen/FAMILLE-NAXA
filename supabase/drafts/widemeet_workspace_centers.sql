begin;

-- B4.7: private opt-in snapshots. The same identity lock order protects authorization.
create function public.wm_periodic_next(p_start date,p_cadence text) returns date
language sql immutable security invoker set search_path=pg_catalog,public as $wm$
 select (p_start+case p_cadence when 'daily' then interval '1 day' when 'weekly' then interval '1 week' when 'monthly' then interval '1 month' when 'quarterly' then interval '3 months' when 'yearly' then interval '1 year' end)::date
$wm$;
revoke all on function public.wm_periodic_next(date,text) from public,anon,authenticated;
grant execute on function public.wm_periodic_next(date,text) to service_role;
create function public.wm_periodic_action(p_hash text,p_action text,p_data jsonb) returns jsonb
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record;c text;d date;v jsonb;reports jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or a.plan<>'premium' or a.role not in ('promoteur','manager') or not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') then return null;end if;
 if p_action='center-periodic-save' then
  c:=p_data->>'cadence';
  if c is null or c not in ('daily','weekly','monthly','quarterly','yearly') or jsonb_typeof(p_data->'enabled') is distinct from 'boolean' then return null;end if;
  d:=date_trunc(case c when 'daily' then 'day' when 'weekly' then 'week' when 'monthly' then 'month' when 'quarterly' then 'quarter' else 'year' end,clock_timestamp() at time zone 'Africa/Douala')::date;
  insert into public.wm_periodic_preferences(account_id,workspace_id,member_role,cadence,enabled,next_start)
  values(a.account_id,a.workspace_id,a.role,c,(p_data->>'enabled')::boolean,d)
  on conflict(account_id,workspace_id,member_role,cadence) do update set next_start=case when not wm_periodic_preferences.enabled and excluded.enabled then excluded.next_start else wm_periodic_preferences.next_start end,enabled=excluded.enabled;
 elsif p_action<>'center-periodic-list' then return null;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('cadence',p.cadence,'enabled',p.enabled,'next_start',p.next_start) order by p.cadence),'[]'::jsonb) into v from public.wm_periodic_preferences p where p.account_id=a.account_id and p.workspace_id=a.workspace_id and p.member_role=a.role;
 select coalesce(jsonb_agg(to_jsonb(z) order by z.period_end desc,z.cadence),'[]'::jsonb) into reports from (select p.cadence,p.period_start,p.period_end,p.generated_at,p.metrics from public.wm_periodic_reports p where p.account_id=a.account_id and p.workspace_id=a.workspace_id and p.member_role=a.role order by p.period_end desc,p.cadence limit 50) z;
 return jsonb_build_object('preferences',v,'items',reports,'timezone','Africa/Douala','scope',case when a.role='promoteur' then 'enterprise' else 'organizer' end);
end $wm$;
revoke all on function public.wm_periodic_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_periodic_action(text,text,jsonb) to service_role;
create function public.wm_periodic_run(p_limit integer) returns integer
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare p record;d date;lo bigint;hi bigint;v jsonb;n integer:=0;today date:=(clock_timestamp() at time zone 'Africa/Douala')::date;
begin
 if p_limit is null or p_limit<1 or p_limit>50 then raise exception 'invalid batch';end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 for p in select pref.* from public.wm_periodic_preferences pref
 join public.wm_accounts ac on ac.id=pref.account_id and ac.enabled and not ac.password_change_required
 join public.wm_workspaces w on w.id=pref.workspace_id and w.enabled and w.kind='enterprise'
 join public.wm_memberships m on m.account_id=pref.account_id and m.workspace_id=pref.workspace_id and m.enabled and m.role=pref.member_role
 join public.wm_room_entitlements e on e.workspace_id=pref.workspace_id and e.enabled and e.plan='premium' and e.valid_until>clock_timestamp()
 where pref.enabled and public.wm_periodic_next(pref.next_start,pref.cadence)<=today order by pref.next_start,pref.account_id,pref.workspace_id,pref.cadence limit p_limit for update of pref
 loop
  d:=public.wm_periodic_next(p.next_start,p.cadence);
  lo:=floor(extract(epoch from (p.next_start::timestamp at time zone 'Africa/Douala'))*1000)::bigint;
  hi:=floor(extract(epoch from (d::timestamp at time zone 'Africa/Douala'))*1000)::bigint;
  select jsonb_build_object('total',count(*),'ended',count(*) filter(where r.state->>'status'='ended' and coalesce(r.state->>'cancelled','false')='false'),'cancelled',count(*) filter(where r.state->>'cancelled'='true'),'duration_minutes',coalesce(sum((r.state->>'durationMinutes')::bigint) filter(where coalesce(r.state->>'cancelled','false')='false'),0),'polls_closed',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(r.state->'polls','[]'::jsonb)) q where q->>'open'='false')),0),'tasks_done',coalesce(sum((select count(*) from public.wm_tasks t join public.wm_minutes_versions mv on mv.id=t.version_id and mv.revoked_at is null and mv.published_at is not null where t.room_id=r.id and t.state='done' and exists(select 1 from public.wm_minutes_recipients mr where mr.version_id=t.version_id and mr.account_id=t.assignee_id and mr.revoked_at is null))),0))
  into v from public.wm_rooms r where r.workspace_id=p.workspace_id and (p.member_role='promoteur' or r.host_id=p.account_id) and (r.state->>'scheduledMs')::bigint>=lo and (r.state->>'scheduledMs')::bigint<hi;
  insert into public.wm_periodic_reports(account_id,workspace_id,member_role,cadence,period_start,period_end,metrics) values(p.account_id,p.workspace_id,p.member_role,p.cadence,p.next_start,d,v) on conflict do nothing;
  update public.wm_periodic_preferences set next_start=d where account_id=p.account_id and workspace_id=p.workspace_id and member_role=p.member_role and cadence=p.cadence;
  n:=n+1;
 end loop;
 return n;
end $wm$;
revoke all on function public.wm_periodic_run(integer) from public,anon,authenticated;
grant execute on function public.wm_periodic_run(integer) to service_role;

-- Workspace private conversations. No implicit access for a manager or promoter.
create table public.wm_direct_messages(
 id uuid primary key,
 workspace_id uuid not null references public.wm_workspaces(id),
 sender_id uuid not null references public.wm_accounts(id),
 recipient_id uuid not null references public.wm_accounts(id),
 body text not null check(length(body) between 1 and 2000),
 created_at timestamptz not null default clock_timestamp(),
 read_at timestamptz,
 reply_to uuid references public.wm_direct_messages(id),
 check(sender_id<>recipient_id),check(reply_to is null or reply_to<>id)
);
create index wm_direct_thread_out on public.wm_direct_messages(workspace_id,sender_id,recipient_id,created_at desc,id);
create index wm_direct_thread_in on public.wm_direct_messages(workspace_id,recipient_id,sender_id,created_at desc,id);
alter table public.wm_direct_messages enable row level security;
revoke all on public.wm_direct_messages from public,anon,authenticated;
grant select,insert,update,delete on public.wm_direct_messages to service_role;
-- B4: calendar windows in Douala. Upper bound is exclusive; never include future rooms.
create function public.wm_b4_window(p_period text,p_days integer,p_now timestamptz)
returns table(start_ms bigint,end_ms bigint) language sql stable set search_path=pg_catalog as $b4$
 with t as (select p_now at time zone 'Africa/Douala' as local_now),
 bounds as (select case p_period
  when 'daily' then date_trunc('day',local_now)
  when 'weekly' then date_trunc('week',local_now)
  when 'monthly' then date_trunc('month',local_now)
  when 'quarterly' then date_trunc('quarter',local_now)
  when 'yearly' then date_trunc('year',local_now)
  when 'rolling' then local_now-make_interval(days=>p_days)
 end as start_local from t)
 select floor(extract(epoch from (start_local at time zone 'Africa/Douala'))*1000)::bigint,
 floor(extract(epoch from p_now)*1000)::bigint
 from bounds where start_local is not null and (p_period<>'rolling' or p_days in (7,30,90,365))
$b4$;
revoke all on function public.wm_b4_window(text,integer,timestamptz) from public,anon,authenticated;
grant execute on function public.wm_b4_window(text,integer,timestamptz) to service_role;
create function public.wm_workspace_center(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; peer uuid; mid uuid; b text; q text; v jsonb; m public.wm_direct_messages%rowtype; days integer; scope_name text; cutoff bigint; upper_ms bigint; period_name text; page_size integer; before_row public.wm_direct_messages%rowtype; has_more boolean; reply_id uuid;
begin
 -- Same lock order as identity membership mutations; then recheck session and entitlement.
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') then return null;end if;
 if p_action='center-statistics' then
  if a.plan<>'premium' or a.role not in ('promoteur','manager') then return null;end if;
  period_name:=coalesce(p_data->>'period','rolling');
  if period_name not in ('rolling','daily','weekly','monthly','quarterly','yearly') then return null;end if;
  if period_name='rolling' then
   if coalesce(p_data->>'days','') not in ('7','30','90','365') then return null;end if;
   days:=(p_data->>'days')::integer;
  elsif p_data ? 'days' then return null;end if;
  scope_name:=case when a.role='promoteur' then 'enterprise' else 'organizer' end;
  select start_ms,end_ms into cutoff,upper_ms from public.wm_b4_window(period_name,days,clock_timestamp());
  if not found then return null;end if;
  with scoped as (
   select * from public.wm_rooms where workspace_id=a.workspace_id and (a.role='promoteur' or host_id=a.account_id)
    and (state->>'scheduledMs')::bigint>=cutoff and (state->>'scheduledMs')::bigint<upper_ms
  ), valid_tasks as (
   select t.* from public.wm_tasks t join scoped r on r.id=t.room_id join public.wm_minutes_versions mv on mv.id=t.version_id and mv.revoked_at is null and mv.published_at is not null
   join public.wm_minutes_eligibility e on e.room_id=r.id and e.retain_until>clock_timestamp()
   where exists(select 1 from public.wm_minutes_recipients mr where mr.version_id=t.version_id and mr.account_id=t.assignee_id and mr.revoked_at is null)
  )
  select jsonb_build_object('scope',scope_name,'days',days,'period',period_name,'start_ms',cutoff,'end_ms',upper_ms,'total',count(*),
   'scheduled',count(*) filter(where state->>'status'='scheduled' and coalesce(state->>'cancelled','false')='false'),
   'open',count(*) filter(where state->>'status'='open'),
   'paused',count(*) filter(where state->>'status'='paused'),
   'ended',count(*) filter(where state->>'status'='ended' and coalesce(state->>'cancelled','false')='false'),
   'cancelled',count(*) filter(where state->>'cancelled'='true'),
   'duration_minutes',coalesce(sum((state->>'durationMinutes')::bigint) filter(where coalesce(state->>'cancelled','false')='false'),0),
   'polls_closed',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'polls','[]'::jsonb)) p where p->>'open'='false')),0),
   'polls_effectively_closed',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'polls','[]'::jsonb)) p where p->>'open'='false' or (p->>'closesMs')::bigint<=upper_ms or state->>'status'='ended')),0),
   'tasks_done',(select count(*) from valid_tasks where state='done'),
   'tasks_assigned',(select count(*) from valid_tasks where state='assigned'),
   'tasks_submitted',(select count(*) from valid_tasks where state='submitted'),
   'tasks_cancelled',(select count(*) from valid_tasks where state='cancelled'),
   'tasks_overdue',(select count(*) from valid_tasks where state='assigned' and due_at<=to_timestamp(upper_ms/1000.0)),
   'invitees',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'participants','[]'::jsonb)) p where p->>'memberId'<>scoped.host_id::text)),0),
   'accepted_invites',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'participants','[]'::jsonb)) p where p->>'memberId'<>scoped.host_id::text and p->>'response'='accepted')),0),
   'rooms_with_observations',count(*) filter(where exists(select 1 from public.wm_presence_samples s where s.room_id=scoped.id)),
   'by_organizer',(select coalesce(jsonb_agg(to_jsonb(g) order by g.organizer,g.organizer_id),'[]'::jsonb) from (
     select r.host_id as organizer_id,ac.display_name as organizer,count(*) as meetings,count(*) filter(where r.state->>'status'='ended' and coalesce(r.state->>'cancelled','false')='false') as ended
     from scoped r join public.wm_accounts ac on ac.id=r.host_id group by r.host_id,ac.display_name) g),
   'by_team',(select coalesce(jsonb_agg(to_jsonb(g) order by g.manager,g.manager_id),'[]'::jsonb) from (
     select ma.manager_id,ac.display_name as manager,count(*) as total,count(*) filter(where t.state='done') as done,count(*) filter(where t.state='assigned' and t.due_at<=to_timestamp(upper_ms/1000.0)) as overdue
     from valid_tasks t join public.wm_manager_assignments ma on ma.workspace_id=a.workspace_id and ma.staff_id=t.assignee_id join public.wm_accounts ac on ac.id=ma.manager_id and ac.enabled join public.wm_memberships mm on mm.workspace_id=ma.workspace_id and mm.account_id=ma.manager_id and mm.enabled and mm.role='manager'
     where a.role='promoteur' or ma.manager_id=a.account_id group by ma.manager_id,ac.display_name) g),
   'by_assignee',(select coalesce(jsonb_agg(to_jsonb(g) order by g.assignee,g.assignee_id),'[]'::jsonb) from (
     select t.assignee_id,ac.display_name as assignee,count(*) as total,count(*) filter(where t.state='done') as done,count(*) filter(where t.state='assigned' and t.due_at<=to_timestamp(upper_ms/1000.0)) as overdue
     from valid_tasks t join public.wm_accounts ac on ac.id=t.assignee_id group by t.assignee_id,ac.display_name) g))
   into v from scoped;
  return v;
 end if;
 if p_action='center-contacts' then
  q:=coalesce(p_data->>'query','');if length(q)>100 then return null;end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.display_name,c.member_id),'[]'::jsonb) into v from (
   select ac.id as member_id,ac.display_name,
    (select count(*) from public.wm_direct_messages dm where dm.workspace_id=a.workspace_id and dm.sender_id=ac.id and dm.recipient_id=a.account_id and dm.read_at is null) unread
   from public.wm_memberships mb join public.wm_accounts ac on ac.id=mb.account_id and ac.enabled and not ac.password_change_required
   where mb.workspace_id=a.workspace_id and mb.enabled and ac.id<>a.account_id and (q='' or strpos(lower(ac.display_name),lower(q))>0) order by ac.display_name,ac.id limit 200
  ) c;
  return jsonb_build_object('items',v);
 end if;
 peer:=(p_data->>'peer_id')::uuid;
 if peer is null or peer=a.account_id then return null;end if;
 -- No messages or history after either membership is revoked; do not trust client workspace.
 perform 1 from public.wm_accounts x where x.id=peer and x.enabled and not x.password_change_required for share;
 if not found then return null;end if;
 perform 1 from public.wm_memberships mb where mb.workspace_id=a.workspace_id and mb.account_id=peer and mb.enabled for share;
 if not found then return null;end if;
 if p_action='center-thread' then
  q:=coalesce(p_data->>'query','');if length(q)>100 then return null;end if;
  if p_data ? 'page_size' and (jsonb_typeof(p_data->'page_size') is distinct from 'number' or coalesce(p_data->>'page_size','') !~ '^[1-9][0-9]{0,2}$') then return null;end if;
  page_size:=coalesce((p_data->>'page_size')::integer,200);if page_size>200 then return null;end if;
  if p_data ? 'before_id' then
   if coalesce(p_data->>'before_id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then return null;end if;
   select * into before_row from public.wm_direct_messages where id=(p_data->>'before_id')::uuid and workspace_id=a.workspace_id
    and ((sender_id=a.account_id and recipient_id=peer) or (sender_id=peer and recipient_id=a.account_id))
    and (q='' or strpos(lower(body),lower(q))>0);
   if not found then return null;end if;
  end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at,c.id),'[]'::jsonb) into v from (
   select dm.id,dm.sender_id,dm.recipient_id,dm.body,dm.created_at,dm.read_at,dm.reply_to,
    (select left(parent.body,180) from public.wm_direct_messages parent where parent.id=dm.reply_to and parent.workspace_id=dm.workspace_id and ((parent.sender_id=dm.sender_id and parent.recipient_id=dm.recipient_id) or (parent.sender_id=dm.recipient_id and parent.recipient_id=dm.sender_id))) as reply_excerpt
    from public.wm_direct_messages dm
   where workspace_id=a.workspace_id and ((sender_id=a.account_id and recipient_id=peer) or (sender_id=peer and recipient_id=a.account_id))
   and (q='' or strpos(lower(body),lower(q))>0)
   and (before_row.id is null or (created_at,id)<(before_row.created_at,before_row.id))
   order by created_at desc,id desc limit page_size+1
  ) c;
  has_more:=jsonb_array_length(v)>page_size;
  if has_more then v:=v-0;end if;
  return jsonb_build_object('items',v,'next_before',case when has_more then v->0->>'id' else null end);
 end if;
 mid:=(p_data->>'message_id')::uuid;
 if mid is null then return null;end if;
 if p_action='center-seen' then
  update public.wm_direct_messages set read_at=coalesce(read_at,clock_timestamp()) where id=mid and workspace_id=a.workspace_id and sender_id=peer and recipient_id=a.account_id;
  if not found then return null;end if;return jsonb_build_object('seen',true);
 end if;
 if p_action='center-send' then
  b:=btrim(p_data->>'body');if b is null or length(b) not between 1 and 2000 then return null;end if;
  if p_data ? 'reply_to' then
   if jsonb_typeof(p_data->'reply_to') is distinct from 'string' or coalesce(p_data->>'reply_to','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then return null;end if;
   reply_id:=(p_data->>'reply_to')::uuid;
   if reply_id=mid or not exists(select 1 from public.wm_direct_messages parent where parent.id=reply_id and parent.workspace_id=a.workspace_id and ((parent.sender_id=a.account_id and parent.recipient_id=peer) or (parent.sender_id=peer and parent.recipient_id=a.account_id))) then return null;end if;
  end if;
  select * into m from public.wm_direct_messages where id=mid;
  if found then
   if m.workspace_id=a.workspace_id and m.sender_id=a.account_id and m.recipient_id=peer and m.body=b and m.reply_to is not distinct from reply_id then return jsonb_build_object('sent',true);end if;
   return null;
  end if;
  if (select count(*) from public.wm_direct_messages where sender_id=a.account_id and created_at>clock_timestamp()-interval '1 minute')>=20 then return null;end if;
  insert into public.wm_direct_messages(id,workspace_id,sender_id,recipient_id,body,reply_to) values(mid,a.workspace_id,a.account_id,peer,b,reply_id);
  return jsonb_build_object('sent',true);
 end if;
 return null;
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_workspace_center(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_workspace_center(text,text,jsonb) to service_role;

-- B2 shared discussion membership is distinct from a user's contact groups.
create table public.wm_chat_groups(
 id uuid primary key, workspace_id uuid not null references public.wm_workspaces(id),
 creator_id uuid not null references public.wm_accounts(id), name text not null check(length(name) between 1 and 80),
 original_name text not null, initial_members uuid[] not null, created_at timestamptz not null default clock_timestamp()
);
create table public.wm_chat_group_members(
 group_id uuid not null references public.wm_chat_groups(id), account_id uuid not null references public.wm_accounts(id),
 joined_at timestamptz not null default clock_timestamp(), removed_at timestamptz, primary key(group_id,account_id)
);
create table public.wm_chat_group_messages(
 id uuid primary key, group_id uuid not null references public.wm_chat_groups(id), sender_id uuid not null references public.wm_accounts(id),
 body text not null check(length(body) between 1 and 2000), created_at timestamptz not null default clock_timestamp(),
 reply_to uuid references public.wm_chat_group_messages(id), mention_ids uuid[] not null default '{}'
);
create table public.wm_chat_group_reads(
 message_id uuid not null references public.wm_chat_group_messages(id), account_id uuid not null references public.wm_accounts(id),
 read_at timestamptz not null default clock_timestamp(), primary key(message_id,account_id)
);
create table public.wm_chat_group_reports(
 message_id uuid not null references public.wm_chat_group_messages(id),
 reporter_id uuid not null references public.wm_accounts(id),
 reason text not null check(reason in ('abuse','spam','other')),
 created_at timestamptz not null default clock_timestamp(),
 resolved_at timestamptz,
 primary key(message_id,reporter_id)
);
alter table public.wm_chat_group_reports enable row level security;
revoke all on public.wm_chat_group_reports from public,anon,authenticated;
grant select,insert,update on public.wm_chat_group_reports to service_role;
create index wm_chat_group_messages_thread on public.wm_chat_group_messages(group_id,created_at desc,id);
create index wm_chat_group_members_account on public.wm_chat_group_members(account_id,group_id) where removed_at is null;
alter table public.wm_chat_groups enable row level security;
alter table public.wm_chat_group_members enable row level security;
alter table public.wm_chat_group_messages enable row level security;
alter table public.wm_chat_group_reads enable row level security;
revoke all on public.wm_chat_groups,public.wm_chat_group_members,public.wm_chat_group_messages,public.wm_chat_group_reads from public,anon,authenticated;
grant select,insert,update on public.wm_chat_groups,public.wm_chat_group_members,public.wm_chat_group_messages,public.wm_chat_group_reads to service_role;

create function public.wm_group_chat(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; gid uuid; mid uuid; target uuid; group_name text; b text; q text; members uuid[]; v jsonb; g public.wm_chat_groups%rowtype; m public.wm_chat_group_messages%rowtype; joined timestamptz; cursor_id uuid; cursor_at timestamptz; page_size integer; reply_id uuid; mentions uuid[]; reason_code text; reporter uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') then return null;end if;
 if p_action='group-chat-list' then
  select coalesce(jsonb_agg(to_jsonb(c) order by c.name,c.id),'[]'::jsonb) into v from (
   select x.id,x.name,x.creator_id,(select count(*) from public.wm_chat_group_members gm join public.wm_memberships mb on mb.account_id=gm.account_id and mb.workspace_id=a.workspace_id and mb.enabled join public.wm_accounts ac on ac.id=gm.account_id and ac.enabled and not ac.password_change_required where gm.group_id=x.id and gm.removed_at is null) member_count
   from public.wm_chat_groups x join public.wm_chat_group_members gm on gm.group_id=x.id and gm.account_id=a.account_id and gm.removed_at is null where x.workspace_id=a.workspace_id order by x.name,x.id limit 200
  ) c;return jsonb_build_object('items',v);
 end if;
 gid:=(p_data->>'group_id')::uuid;if gid is null then return null;end if;
 if p_action='group-chat-create' then
  group_name:=btrim(p_data->>'name');
  if group_name is null or length(group_name) not between 1 and 80 or jsonb_typeof(p_data->'member_ids') is distinct from 'array' then return null;end if;
  if jsonb_array_length(p_data->'member_ids') not between 2 and 49 then return null;end if;
  select array_agg(distinct x order by x) into members from (select value::uuid x from jsonb_array_elements_text(p_data->'member_ids')) t;
  if cardinality(members)<>jsonb_array_length(p_data->'member_ids') or a.account_id=any(members) or array_position(members,null) is not null then return null;end if;
  select * into g from public.wm_chat_groups where id=gid;
  if found then
   if g.workspace_id=a.workspace_id and g.creator_id=a.account_id and g.initial_members=members and g.original_name=group_name and exists(select 1 from public.wm_chat_group_members gm where gm.group_id=gid and gm.account_id=a.account_id and gm.removed_at is null) then return jsonb_build_object('created',true,'id',gid);end if;return null;
  end if;
  if (select count(*) from public.wm_memberships mb join public.wm_accounts ac on ac.id=mb.account_id and ac.enabled and not ac.password_change_required where mb.workspace_id=a.workspace_id and mb.enabled and mb.account_id=any(members))<>cardinality(members) then return null;end if;
  if (select count(*) from public.wm_chat_groups where creator_id=a.account_id and created_at>clock_timestamp()-interval '1 minute')>=5 then return null;end if;
  insert into public.wm_chat_groups(id,workspace_id,creator_id,name,original_name,initial_members) values(gid,a.workspace_id,a.account_id,group_name,group_name,members);
  insert into public.wm_chat_group_members(group_id,account_id) select gid,unnest(array_append(members,a.account_id));
  return jsonb_build_object('created',true,'id',gid);
 end if;
 select * into g from public.wm_chat_groups where id=gid and workspace_id=a.workspace_id;
 if not found then return null;end if;
 select gm.joined_at into joined from public.wm_chat_group_members gm where gm.group_id=gid and gm.account_id=a.account_id and gm.removed_at is null;
 if not found then return null;end if;
 if p_action='group-chat-rename' then
  group_name:=btrim(p_data->>'name');
  if a.account_id<>g.creator_id or group_name is null or length(group_name) not between 1 and 80 then return null;end if;
  update public.wm_chat_groups set name=group_name where id=gid;
  return jsonb_build_object('renamed',true,'name',group_name);
 end if;
 if p_action='group-chat-add' then
  if a.account_id<>g.creator_id then return null;end if;
  target:=(p_data->>'member_id')::uuid;
  if target is null or not exists(select 1 from public.wm_memberships mb join public.wm_accounts ac on ac.id=mb.account_id and ac.enabled and not ac.password_change_required where mb.workspace_id=a.workspace_id and mb.enabled and mb.account_id=target) then return null;end if;
  if exists(select 1 from public.wm_chat_group_members gm where gm.group_id=gid and gm.account_id=target and gm.removed_at is null) then return jsonb_build_object('added',true);end if;
  if (select count(*) from public.wm_chat_group_members gm where gm.group_id=gid and gm.removed_at is null)>=50 then return null;end if;
  -- Readmission resets the history boundary; old messages and read receipts stay inaccessible.
  insert into public.wm_chat_group_members(group_id,account_id) values(gid,target)
  on conflict(group_id,account_id) do update set joined_at=clock_timestamp(),removed_at=null;
  return jsonb_build_object('added',true);
 end if;
 if p_action='group-chat-members' then
  select coalesce(jsonb_agg(to_jsonb(c) order by c.display_name,c.member_id),'[]'::jsonb) into v from (
   select ac.id member_id,ac.display_name from public.wm_chat_group_members gm join public.wm_memberships mb on mb.account_id=gm.account_id and mb.workspace_id=a.workspace_id and mb.enabled join public.wm_accounts ac on ac.id=gm.account_id and ac.enabled and not ac.password_change_required where gm.group_id=gid and gm.removed_at is null
  ) c;return jsonb_build_object('items',v);
 end if;
 if p_action='group-chat-remove' then
  target:=(p_data->>'member_id')::uuid;if target is null or (target<>a.account_id and g.creator_id<>a.account_id) then return null;end if;
  update public.wm_chat_group_members set removed_at=coalesce(removed_at,clock_timestamp()) where group_id=gid and account_id=target;
  if not found then return null;end if;return jsonb_build_object('removed',true);
 end if;
 if p_action='group-chat-snapshot' then
  v:=public.wm_group_chat(p_hash,'group-chat-thread',p_data);
  if v is null then return null;end if;
  return jsonb_build_object('thread',v,'members',public.wm_group_chat(p_hash,'group-chat-members',p_data)->'items');
 end if;
 if p_action='group-chat-thread' then
  q:=coalesce(p_data->>'query','');if length(q)>100 then return null;end if;
  page_size:=coalesce((p_data->>'limit')::integer,200);if page_size not between 1 and 200 then return null;end if;
  cursor_id:=(p_data->>'before_id')::uuid;
  if cursor_id is not null then
   select x.created_at into cursor_at from public.wm_chat_group_messages x where x.id=cursor_id and x.group_id=gid and x.created_at>=joined and (q='' or strpos(lower(x.body),lower(q))>0);
   if not found then return null;end if;
  end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at,c.id),'[]'::jsonb) into v from (
   select x.id,x.sender_id,ac.display_name,x.body,x.created_at,
    (select r.read_at from public.wm_chat_group_reads r where r.message_id=x.id and r.account_id=a.account_id) read_at,
    case when parent.created_at>=joined then parent.id else null end reply_to,
    case when parent.created_at>=joined then left(parent.body,120) else null end reply_preview,
    x.mention_ids
   from public.wm_chat_group_messages x join public.wm_accounts ac on ac.id=x.sender_id
   left join public.wm_chat_group_messages parent on parent.id=x.reply_to and parent.group_id=x.group_id
   where x.group_id=gid and x.created_at>=joined and (q='' or strpos(lower(x.body),lower(q))>0)
   and (cursor_id is null or (x.created_at,x.id)<(cursor_at,cursor_id))
   order by x.created_at desc,x.id desc limit page_size+1
  ) c;
  if jsonb_array_length(v)>page_size then
   v:=v-0;
   return jsonb_build_object('items',v,'next_before_id',v->0->>'id');
  end if;
  return jsonb_build_object('items',v,'next_before_id',null);
 end if;
 if p_action='group-chat-reports' then
  if a.account_id<>g.creator_id then return null;end if;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at,c.message_id),'[]'::jsonb) into v from (
   select r.message_id,r.reporter_id,r.reason,r.created_at,left(x.body,120) preview
   from public.wm_chat_group_reports r join public.wm_chat_group_messages x on x.id=r.message_id
   where x.group_id=gid and x.created_at>=joined and r.resolved_at is null order by r.created_at desc limit 100
  ) c;return jsonb_build_object('items',v);
 end if;
 mid:=(p_data->>'message_id')::uuid;if mid is null then return null;end if;
 if p_action='group-chat-seen' then
  if not exists(select 1 from public.wm_chat_group_messages x where x.id=mid and x.group_id=gid and x.created_at>=joined and x.sender_id<>a.account_id) then return null;end if;
  insert into public.wm_chat_group_reads(message_id,account_id) values(mid,a.account_id) on conflict do nothing;return jsonb_build_object('seen',true);
 end if;
 if p_action='group-chat-report' then
  reason_code:=p_data->>'reason';
  if reason_code is null or reason_code not in ('abuse','spam','other') or not exists(select 1 from public.wm_chat_group_messages x where x.id=mid and x.group_id=gid and x.created_at>=joined and x.sender_id<>a.account_id) then return null;end if;
  if exists(select 1 from public.wm_chat_group_reports r where r.message_id=mid and r.reporter_id=a.account_id and r.reason=reason_code) then return jsonb_build_object('reported',true);end if;
  if (select count(*) from public.wm_chat_group_reports r where r.reporter_id=a.account_id and r.created_at>clock_timestamp()-interval '1 minute')>=5 then return null;end if;
  insert into public.wm_chat_group_reports(message_id,reporter_id,reason) values(mid,a.account_id,reason_code);
  return jsonb_build_object('reported',true);
 end if;
 if p_action='group-chat-resolve-report' then
  reporter:=(p_data->>'reporter_id')::uuid;
  if a.account_id<>g.creator_id or reporter is null or not exists(select 1 from public.wm_chat_group_messages x where x.id=mid and x.group_id=gid and x.created_at>=joined) then return null;end if;
  update public.wm_chat_group_reports set resolved_at=coalesce(resolved_at,clock_timestamp()) where message_id=mid and reporter_id=reporter;
  if not found then return null;end if;return jsonb_build_object('resolved',true);
 end if;
 if p_action='group-chat-send' then
  b:=btrim(p_data->>'body');if b is null or length(b) not between 1 and 2000 then return null;end if;
  reply_id:=(p_data->>'reply_to')::uuid;
  if reply_id is not null and not exists(select 1 from public.wm_chat_group_messages x where x.id=reply_id and x.group_id=gid and x.created_at>=joined) then return null;end if;
  if jsonb_typeof(coalesce(p_data->'mention_ids','[]'::jsonb)) is distinct from 'array' then return null;end if;
  if jsonb_array_length(coalesce(p_data->'mention_ids','[]'::jsonb))>10 then return null;end if;
  select coalesce(array_agg(distinct x order by x),'{}'::uuid[]) into mentions from (select value::uuid x from jsonb_array_elements_text(coalesce(p_data->'mention_ids','[]'::jsonb))) t;
  if array_position(mentions,null) is not null or a.account_id=any(mentions) then return null;end if;
  select * into m from public.wm_chat_group_messages where id=mid;
  if found then if m.group_id=gid and m.sender_id=a.account_id and m.created_at>=joined and m.body=b and m.reply_to is not distinct from reply_id and m.mention_ids=mentions then return jsonb_build_object('sent',true);end if;return null;end if;
  if (select count(*) from public.wm_chat_group_members gm join public.wm_memberships mb on mb.workspace_id=a.workspace_id and mb.account_id=gm.account_id and mb.enabled join public.wm_accounts ac on ac.id=gm.account_id and ac.enabled and not ac.password_change_required where gm.group_id=gid and gm.removed_at is null and gm.account_id=any(mentions))<>cardinality(mentions) then return null;end if;
  if (select count(*) from public.wm_chat_group_messages where sender_id=a.account_id and created_at>clock_timestamp()-interval '1 minute')>=20 then return null;end if;
  insert into public.wm_chat_group_messages(id,group_id,sender_id,body,reply_to,mention_ids) values(mid,gid,a.account_id,b,reply_id,mentions);return jsonb_build_object('sent',true);
 end if;
 return null;
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_group_chat(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_group_chat(text,text,jsonb) to service_role;

-- B2 shared chat media ledger. Distinct from meeting recording, archives and support.
-- The object is private; only a trusted gateway accesses Storage. Staging is never readable.
create table public.wm_chat_media(
 id uuid primary key, workspace_id uuid not null references public.wm_workspaces(id),
 sender_id uuid not null references public.wm_accounts(id),
 peer_id uuid references public.wm_accounts(id), group_id uuid references public.wm_chat_groups(id),
 room_id uuid references public.wm_rooms(id), channel text check(channel in ('agenda','room-chat')), post_id uuid,
 kind text not null check(kind in ('file','voice','video')),
 mime text not null check(mime in ('application/pdf','image/jpeg','image/png','audio/ogg','audio/webm','audio/mp4','video/mp4','video/webm')),
 name text not null check(length(name) between 1 and 120),
 bytes integer not null check(bytes between 1 and 1048576),
 sha256 text not null check(length(sha256)=64 and translate(sha256,'0123456789abcdef','')=''),
 state text not null default 'staged' check(state in ('staged','ready','revoked')),
 created_at timestamptz not null default clock_timestamp(), published_at timestamptz, revoked_at timestamptz, purged_at timestamptz,
 check(num_nonnulls(peer_id,group_id,room_id,post_id)=1), check(peer_id is null or peer_id<>sender_id),
 check((room_id is null)=(channel is null)),check(channel is distinct from 'agenda' or kind='file'),check(post_id is null or kind in ('file','video')),check(kind<>'video' or post_id is not null),
 check((kind='voice')=(mime in ('audio/ogg','audio/webm','audio/mp4'))),check((kind='video')=(mime in ('video/mp4','video/webm')))
);
create index wm_chat_media_direct on public.wm_chat_media(workspace_id,sender_id,peer_id,published_at desc,id);
create index wm_chat_media_group on public.wm_chat_media(group_id,published_at desc,id);
create index wm_chat_media_room on public.wm_chat_media(room_id,channel,published_at desc,id);
create index wm_chat_media_post on public.wm_chat_media(post_id,published_at desc,id);
alter table public.wm_chat_media enable row level security;
revoke all on public.wm_chat_media from public,anon,authenticated;
grant select,insert,update on public.wm_chat_media to service_role;
-- Current enterprise audience, checked at every projection and binary read.
create function public.wm_company_audience_allowed(w uuid,author uuid,team uuid,agency text,viewer uuid) returns boolean
language sql stable security invoker set search_path=pg_catalog,public as $aud$
 select exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled
  where m.workspace_id=w and m.account_id=viewer and m.enabled and
  ((team is null and agency is null) or viewer=author or m.role='promoteur' or (agency is not null and lower(btrim(m.agency_name))=agency) or
   (exists(select 1 from public.wm_memberships tm join public.wm_accounts ta on ta.id=tm.account_id and ta.enabled where tm.workspace_id=w and tm.account_id=team and tm.enabled and tm.role='manager')
   and ((viewer=team and m.role='manager') or (m.role='staff' and exists(select 1 from public.wm_manager_assignments ma where ma.workspace_id=w and ma.staff_id=viewer and ma.manager_id=team))))))
$aud$;
revoke all on function public.wm_company_audience_allowed(uuid,uuid,uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.wm_company_audience_allowed(uuid,uuid,uuid,text,uuid) to service_role;
create function public.wm_chat_media_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; gid uuid; peer uuid; rid uuid; pid uuid; post_author uuid; channel_name text; room_row public.wm_rooms%rowtype; participant jsonb; room_status text; mid uuid; m public.wm_chat_media%rowtype; joined timestamptz; v jsonb; k text; mime_type text; filename text; size_bytes integer; sha text;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 gid:=(p_data->>'group_id')::uuid;peer:=(p_data->>'peer_id')::uuid;rid:=(p_data->>'room_id')::uuid;pid:=(p_data->>'post_id')::uuid;channel_name:=p_data->>'channel';
 if num_nonnulls(gid,peer,rid,pid)<>1 or (rid is null)<>(channel_name is null) then return null;end if;
 select * into a from public.wm_lock_room_actor_for(p_hash,rid);
 if not found then return null;end if;
 if not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') or peer=a.account_id then return null;end if;
 if pid is not null then
  select p.author_id into post_author from public.wm_company_posts p join public.wm_memberships mb on mb.account_id=p.author_id and mb.workspace_id=p.workspace_id and mb.enabled join public.wm_accounts ac on ac.id=p.author_id and ac.enabled where p.id=pid and p.workspace_id=a.workspace_id and p.removed_at is null and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,a.account_id);
  if not found or (p_action in ('reserve','publish') and post_author<>a.account_id) then return null;end if;
 elsif rid is not null then
  -- Internal enterprise, standard confidentiality, current attendance rights only.
  if channel_name not in ('agenda','room-chat') or a.workspace_id is distinct from (select x.workspace_id from public.wm_session_context(p_hash) x) then return null;end if;
  select * into room_row from public.wm_rooms where id=rid and workspace_id=a.workspace_id for share;
  if not found or coalesce(room_row.state->>'confidentiality','standard')<>'standard' then return null;end if;
  room_status:=room_row.state->>'status';
  if room_status is null or (channel_name='agenda' and room_status not in ('scheduled','open')) or (channel_name='room-chat' and room_status is distinct from 'open') then return null;end if;
  if room_status='open' and coalesce((room_row.state->>'endMs')::bigint,0)<=floor(extract(epoch from clock_timestamp())*1000)::bigint then return null;end if;
  select p into participant from jsonb_array_elements(room_row.state->'participants') p where p->>'memberId'=a.account_id::text and p->>'response'='accepted' and p->>'excluded'='false';
  if participant is null or (room_status='open' and room_row.state->>'lobbyRequired'='true' and a.account_id<>room_row.host_id and participant->>'lobbyStatus' is distinct from 'admitted') then return null;end if;
  if p_action in ('reserve','publish') and ((channel_name='agenda' and a.account_id<>room_row.host_id) or (channel_name='room-chat' and participant->>'chat' is distinct from 'true' and a.account_id<>room_row.host_id)) then return null;end if;
 elsif gid is not null then
  select gm.joined_at into joined from public.wm_chat_group_members gm join public.wm_chat_groups cg on cg.id=gm.group_id and cg.workspace_id=a.workspace_id where gm.group_id=gid and gm.account_id=a.account_id and gm.removed_at is null;
  if not found then return null;end if;
 else
  perform 1 from public.wm_accounts x join public.wm_memberships mb on mb.account_id=x.id and mb.workspace_id=a.workspace_id and mb.enabled where x.id=peer and x.enabled and not x.password_change_required for share of x,mb;
  if not found then return null;end if;
 end if;
 if p_action='list' then
  select coalesce(jsonb_agg(to_jsonb(c) order by c.published_at,c.id),'[]'::jsonb) into v from (
   select x.id,x.sender_id,x.kind,x.mime,x.name,x.bytes,x.sha256,x.published_at from public.wm_chat_media x
   where x.workspace_id=a.workspace_id and x.state='ready' and
   ((pid is not null and x.post_id=pid)
    or (rid is not null and x.room_id=rid and x.channel=channel_name)
    or (gid is not null and x.group_id=gid and x.created_at>=joined and x.published_at>=joined)
    or (peer is not null and x.group_id is null and x.room_id is null and x.post_id is null and ((x.sender_id=a.account_id and x.peer_id=peer) or (x.sender_id=peer and x.peer_id=a.account_id))))
   order by x.published_at desc,x.id desc limit 100
  ) c;return jsonb_build_object('items',v);
 end if;
 mid:=(p_data->>'id')::uuid;if mid is null then return null;end if;
 select * into m from public.wm_chat_media x where x.id=mid;
 if p_action='reserve' then
  k:=p_data->>'kind';mime_type:=p_data->>'mime';filename:=p_data->>'name';size_bytes:=(p_data->>'bytes')::integer;sha:=p_data->>'sha256';
  if k is null or mime_type is null or filename is null or size_bytes is null or sha is null or (channel_name='agenda' and k<>'file') or (pid is not null and k not in ('file','video')) or (pid is null and k='video') then return null;end if;
  if k not in ('file','voice','video') or mime_type not in ('application/pdf','image/jpeg','image/png','audio/ogg','audio/webm','audio/mp4','video/mp4','video/webm') or (k='voice')<>(mime_type in ('audio/ogg','audio/webm','audio/mp4')) or (k='video')<>(mime_type in ('video/mp4','video/webm')) or length(filename) not between 1 and 120 or size_bytes not between 1 and 1048576 or length(sha)<>64 or translate(sha,'0123456789abcdef','')<>'' then return null;end if;
  if found then
   if m.workspace_id<>a.workspace_id or m.sender_id<>a.account_id or m.peer_id is distinct from peer or m.group_id is distinct from gid or m.room_id is distinct from rid or m.post_id is distinct from pid or m.channel is distinct from channel_name or m.kind<>k or m.mime<>mime_type or m.name<>filename or m.bytes<>size_bytes or m.sha256<>sha or m.state='revoked' or (gid is not null and m.created_at<joined) then return null;end if;
   if m.state='staged' and m.created_at<=clock_timestamp()-interval '15 minutes' then return null;end if;
  else
   if (select count(*) from public.wm_chat_media x where x.sender_id=a.account_id and x.created_at>clock_timestamp()-interval '1 minute')>=5 then return null;end if;
   insert into public.wm_chat_media(id,workspace_id,sender_id,peer_id,group_id,room_id,channel,post_id,kind,mime,name,bytes,sha256) values(mid,a.workspace_id,a.account_id,peer,gid,rid,channel_name,pid,k,mime_type,filename,size_bytes,sha) returning * into m;
  end if;
  return jsonb_build_object('id',m.id,'key',m.workspace_id::text||'/'||m.id::text,'state',m.state,'bytes',m.bytes,'sha256',m.sha256,'mime',m.mime,'name',m.name,'kind',m.kind);
 end if;
 if not found or m.workspace_id<>a.workspace_id then return null;end if;
 if pid is not null then
  if m.post_id is distinct from pid then return null;end if;
 elsif rid is not null then
  if m.room_id is distinct from rid or m.channel is distinct from channel_name then return null;end if;
 elsif gid is not null then
  if m.group_id is distinct from gid or m.created_at<joined then return null;end if;
 else
  if m.group_id is not null or m.room_id is not null or m.post_id is not null or not ((m.sender_id=a.account_id and m.peer_id=peer) or (m.sender_id=peer and m.peer_id=a.account_id)) then return null;end if;
 end if;
 if p_action='publish' then
  if m.sender_id<>a.account_id or m.state='revoked' or (m.state='staged' and m.created_at<=clock_timestamp()-interval '15 minutes') then return null;end if;
  update public.wm_chat_media set state='ready',published_at=coalesce(published_at,clock_timestamp()) where id=mid returning * into m;
 elsif p_action='revoke' then
  if m.sender_id<>a.account_id then return null;end if;
  update public.wm_chat_media set state='revoked',revoked_at=coalesce(revoked_at,clock_timestamp()) where id=mid returning * into m;
 elsif p_action='read' then
  if m.state<>'ready' or (gid is not null and m.published_at<joined) then return null;end if;
 else return null;
 end if;
 return jsonb_build_object('id',m.id,'key',m.workspace_id::text||'/'||m.id::text,'state',m.state,'bytes',m.bytes,'sha256',m.sha256,'mime',m.mime,'name',m.name,'kind',m.kind);
exception when invalid_text_representation or numeric_value_out_of_range or unique_violation or check_violation then return null;
end $wm$;
revoke all on function public.wm_chat_media_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_chat_media_action(text,text,jsonb) to service_role;
-- Terminal states cannot be resurrected. Wait beyond the bounded transfer timeout before cleanup.
-- This RPC is worker-only: it never accepts an arbitrary Storage key.
create function public.wm_chat_media_purge_candidates(p_limit integer default 50) returns jsonb
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare v jsonb;
begin
 if p_limit is null or p_limit not between 1 and 100 then return null;end if;
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 update public.wm_chat_media set state='revoked',revoked_at=clock_timestamp() where state='staged' and created_at<clock_timestamp()-interval '15 minutes';
 select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into v from (
 select id,workspace_id::text||'/'||id::text as key from public.wm_chat_media where state='revoked' and purged_at is null
 and revoked_at<clock_timestamp()-interval '2 minutes' order by revoked_at,id limit p_limit
 ) c;
 return jsonb_build_object('items',v);
end $wm$;
create function public.wm_chat_media_purge_ack(p_id uuid) returns boolean
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
begin
 update public.wm_chat_media set purged_at=coalesce(purged_at,clock_timestamp()) where id=p_id and state='revoked' and revoked_at<clock_timestamp()-interval '2 minutes';
 return found;
end $wm$;
revoke all on function public.wm_chat_media_purge_candidates(integer),public.wm_chat_media_purge_ack(uuid) from public,anon,authenticated;
grant execute on function public.wm_chat_media_purge_candidates(integer),public.wm_chat_media_purge_ack(uuid) to service_role;

-- V2-03 private enterprise feed: one publication engine, distinct kinds.
create table public.wm_company_posts(
 id uuid primary key, workspace_id uuid not null, author_id uuid not null,
 kind text not null check(kind in ('news','announcement')),
 body text not null check(length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default clock_timestamp(), removed_at timestamptz, team_id uuid, agency_key text,
 check(num_nonnulls(team_id,agency_key)<=1),check(agency_key is null or length(agency_key) between 1 and 80),
 foreign key(author_id,workspace_id) references public.wm_memberships(account_id,workspace_id)
);
alter table public.wm_chat_media add constraint wm_chat_media_company_post_fk foreign key(post_id) references public.wm_company_posts(id);
create index wm_company_posts_feed on public.wm_company_posts(workspace_id,kind,created_at desc,id desc) where removed_at is null;
-- Reuse the existing notice inbox without copying post content to the push ledger.
create function public.wm_company_notice_items(w uuid,viewer uuid) returns jsonb
language sql stable security invoker set search_path=pg_catalog,public as $notice$
 select coalesce(jsonb_agg(to_jsonb(x) order by x.due desc,x.k),'[]'::jsonb) from (
  select 'company:'||p.id::text as k,case when p.kind='announcement' then 'company_announcement' else 'company_news' end as kind,p.id as ref,null::text as title,p.created_at as due
  from public.wm_company_posts p join public.wm_memberships mb on mb.account_id=p.author_id and mb.workspace_id=p.workspace_id and mb.enabled
  join public.wm_accounts ac on ac.id=p.author_id and ac.enabled
  join public.wm_workspaces ws on ws.id=p.workspace_id and ws.enabled and ws.kind='enterprise'
  where p.workspace_id=w and p.author_id<>viewer and p.removed_at is null and public.wm_company_audience_allowed(w,p.author_id,p.team_id,p.agency_key,viewer)
  order by p.created_at desc,p.id desc limit 100
 ) x
$notice$;
revoke all on function public.wm_company_notice_items(uuid,uuid) from public,anon,authenticated;
grant execute on function public.wm_company_notice_items(uuid,uuid) to service_role;

create table public.wm_company_reads(
 post_id uuid not null references public.wm_company_posts(id),account_id uuid not null references public.wm_accounts(id),
 confirmed_at timestamptz not null default clock_timestamp(),primary key(post_id,account_id)
);
alter table public.wm_company_posts enable row level security;
alter table public.wm_company_reads enable row level security;
revoke all on public.wm_company_posts,public.wm_company_reads from public,anon,authenticated;
grant select,insert,update,delete on public.wm_company_posts,public.wm_company_reads to service_role;
-- V2-03 interactions, private bookmarks and moderated comments.
create table public.wm_company_reactions(
 post_id uuid not null references public.wm_company_posts(id),account_id uuid not null references public.wm_accounts(id),
 reaction text not null check(reaction in ('like','love','celebrate','insightful','support','funny')),primary key(post_id,account_id)
);
create table public.wm_company_favorites(
 post_id uuid not null references public.wm_company_posts(id),account_id uuid not null references public.wm_accounts(id),primary key(post_id,account_id)
);
create table public.wm_company_comments(
 id uuid primary key,post_id uuid not null references public.wm_company_posts(id),author_id uuid not null references public.wm_accounts(id),
 body text not null check(length(btrim(body)) between 1 and 1000),created_at timestamptz not null default clock_timestamp(),removed_at timestamptz
);
create index wm_company_comments_post on public.wm_company_comments(post_id,created_at,id) where removed_at is null;
alter table public.wm_company_reactions enable row level security;
alter table public.wm_company_favorites enable row level security;
alter table public.wm_company_comments enable row level security;
revoke all on public.wm_company_reactions,public.wm_company_favorites,public.wm_company_comments from public,anon,authenticated;
grant select,insert,update,delete on public.wm_company_reactions,public.wm_company_favorites,public.wm_company_comments to service_role;
create table public.wm_company_polls(
 post_id uuid primary key references public.wm_company_posts(id), options jsonb not null,
 closed_at timestamptz,
 check(jsonb_typeof(options)='array' and jsonb_array_length(options) between 2 and 6)
);
create table public.wm_company_votes(
 post_id uuid not null references public.wm_company_polls(post_id),account_id uuid not null references public.wm_accounts(id),
 choice integer not null check(choice between 0 and 5),primary key(post_id,account_id)
);
alter table public.wm_company_polls enable row level security;
alter table public.wm_company_votes enable row level security;
revoke all on public.wm_company_polls,public.wm_company_votes from public,anon,authenticated;
grant select,insert,update,delete on public.wm_company_polls,public.wm_company_votes to service_role;
create function public.wm_company_action(p_hash text,p_action text,p_data jsonb) returns jsonb
language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; item public.wm_company_posts%rowtype; pid uuid; cid uuid; k text; content text; result jsonb; comment_row public.wm_company_comments%rowtype; only_favorites boolean; poll_options jsonb; choice_idx integer; existing_choice integer; poll_row public.wm_company_polls%rowtype; target_team uuid; teams jsonb; target_agency text; agencies jsonb; profile_member uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') or jsonb_typeof(p_data) is distinct from 'object' then return null;end if;
 if p_action='center-company-list' then
  if (p_data-'kind'-'favorites')<>'{}'::jsonb or jsonb_typeof(p_data->'kind') is distinct from 'string' or (p_data ? 'favorites' and jsonb_typeof(p_data->'favorites') is distinct from 'boolean') then return null;end if;
  k:=p_data->>'kind';if k not in ('news','announcement') then return null;end if;
  only_favorites:=coalesce((p_data->>'favorites')::boolean,false);
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc,x.id desc),'[]'::jsonb) into result from (
   select p.id,p.kind,p.author_id,ac.display_name,mb.job_title,p.body,p.created_at,p.team_id,p.agency_key,
    (select jsonb_build_object('options',cp.options,'closed',cp.closed_at is not null,'my_vote',(select v.choice from public.wm_company_votes v where v.post_id=p.id and v.account_id=a.account_id),
     'counts',case when cp.closed_at is not null or exists(select 1 from public.wm_company_votes v where v.post_id=p.id and v.account_id=a.account_id) then
       (select jsonb_agg((select count(*) from public.wm_company_votes v join public.wm_memberships mm on mm.account_id=v.account_id and mm.workspace_id=p.workspace_id and mm.enabled join public.wm_accounts aa on aa.id=mm.account_id and aa.enabled where v.post_id=p.id and v.choice=i and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,v.account_id)) order by i) from generate_series(0,jsonb_array_length(cp.options)-1) i) else null end)
     from public.wm_company_polls cp where cp.post_id=p.id) as poll,
    exists(select 1 from public.wm_company_favorites f where f.post_id=p.id and f.account_id=a.account_id) as favorite,
    (select r.reaction from public.wm_company_reactions r where r.post_id=p.id and r.account_id=a.account_id) as my_reaction,
    (select count(*) from public.wm_company_reactions r join public.wm_memberships m on m.account_id=r.account_id and m.workspace_id=p.workspace_id and m.enabled join public.wm_accounts ca on ca.id=m.account_id and ca.enabled where r.post_id=p.id and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,r.account_id)) as reaction_count,
    (select count(*) from public.wm_company_comments c join public.wm_memberships m on m.account_id=c.author_id and m.workspace_id=p.workspace_id and m.enabled join public.wm_accounts ca on ca.id=m.account_id and ca.enabled where c.post_id=p.id and c.removed_at is null and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,c.author_id)) as comment_count,
    p.author_id=a.account_id or a.role='promoteur' as can_remove,
    (p.kind='announcement' and p.author_id<>a.account_id) as can_confirm,
    exists(select 1 from public.wm_company_reads cr where cr.post_id=p.id and cr.account_id=a.account_id) as confirmed,
    case when p.kind='announcement' and (p.author_id=a.account_id or a.role='promoteur') then
      (select count(*) from public.wm_company_reads cr join public.wm_memberships cm on cm.account_id=cr.account_id and cm.workspace_id=p.workspace_id and cm.enabled join public.wm_accounts ca on ca.id=cm.account_id and ca.enabled where cr.post_id=p.id and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,cr.account_id)) else null end as confirmation_count
   from public.wm_company_posts p join public.wm_memberships mb on mb.account_id=p.author_id and mb.workspace_id=p.workspace_id and mb.enabled
   join public.wm_accounts ac on ac.id=p.author_id and ac.enabled
   where p.workspace_id=a.workspace_id and p.kind=k and p.removed_at is null and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,a.account_id) and (not only_favorites or exists(select 1 from public.wm_company_favorites f where f.post_id=p.id and f.account_id=a.account_id)) order by p.created_at desc,p.id desc limit 100
  ) x;
  select coalesce(jsonb_agg(jsonb_build_object('id',m.account_id,'name',ac.display_name) order by ac.display_name,m.account_id),'[]'::jsonb) into teams
  from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled
  where m.workspace_id=a.workspace_id and m.enabled and m.role='manager'
   and (a.role='promoteur' or m.account_id=a.account_id or (a.role='staff' and exists(select 1 from public.wm_manager_assignments ma where ma.workspace_id=a.workspace_id and ma.staff_id=a.account_id and ma.manager_id=m.account_id)));
  select coalesce(jsonb_agg(jsonb_build_object('id',x.agency_key,'name',x.label) order by x.label),'[]'::jsonb) into agencies from (select lower(btrim(m.agency_name)) as agency_key,min(btrim(m.agency_name)) as label from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and m.agency_name is not null and (a.role='promoteur' or lower(btrim(m.agency_name))=(select lower(btrim(mm.agency_name)) from public.wm_memberships mm where mm.workspace_id=a.workspace_id and mm.account_id=a.account_id and mm.enabled)) group by lower(btrim(m.agency_name))) x;
  return jsonb_build_object('items',result,'teams',teams,'agencies',agencies,'can_publish',k='news' or a.role in ('promoteur','manager'));
 end if;
 if jsonb_typeof(p_data->'id') is distinct from 'string' or coalesce(p_data->>'id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then return null;end if;
 pid:=(p_data->>'id')::uuid;
 if p_action='center-company-publish' then
  if (p_data-'id'-'kind'-'body'-'poll_options'-'team_id'-'agency_key')<>'{}'::jsonb or jsonb_typeof(p_data->'kind') is distinct from 'string' or jsonb_typeof(p_data->'body') is distinct from 'string' then return null;end if;
  k:=p_data->>'kind';content:=btrim(p_data->>'body');
  if k not in ('news','announcement') or length(content) not between 1 and 4000 or (k='announcement' and a.role not in ('promoteur','manager')) then return null;end if;
  if p_data ? 'agency_key' then
   if p_data ? 'team_id' or jsonb_typeof(p_data->'agency_key') is distinct from 'string' then return null;end if;
   target_agency:=lower(btrim(p_data->>'agency_key'));
   if length(target_agency) not between 1 and 80 or not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.enabled and lower(btrim(m.agency_name))=target_agency and (a.role='promoteur' or m.account_id=a.account_id)) then return null;end if;
  end if;
  if p_data ? 'team_id' then
   if jsonb_typeof(p_data->'team_id') is distinct from 'string' or coalesce(p_data->>'team_id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then return null;end if;
   target_team:=(p_data->>'team_id')::uuid;
   if not exists(select 1 from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled where m.workspace_id=a.workspace_id and m.account_id=target_team and m.enabled and m.role='manager'
   and (a.role='promoteur' or target_team=a.account_id or (a.role='staff' and exists(select 1 from public.wm_manager_assignments ma where ma.workspace_id=a.workspace_id and ma.staff_id=a.account_id and ma.manager_id=target_team)))) then return null;end if;
  end if;
  if p_data ? 'poll_options' then
   if k<>'news' or jsonb_typeof(p_data->'poll_options') is distinct from 'array' then return null;end if;
   if jsonb_array_length(p_data->'poll_options') not between 2 and 6 then return null;end if;
   if exists(select 1 from jsonb_array_elements(p_data->'poll_options') v where jsonb_typeof(v)<>'string' or length(btrim(v#>>'{}')) not between 1 and 120) then return null;end if;
   if (select count(distinct lower(btrim(v))) from jsonb_array_elements_text(p_data->'poll_options') v)<>jsonb_array_length(p_data->'poll_options') then return null;end if;
   select jsonb_agg(btrim(v) order by ord) into poll_options from jsonb_array_elements_text(p_data->'poll_options') with ordinality t(v,ord);
  end if;
  if exists(select 1 from public.wm_company_posts where id=pid) then
   if (select options from public.wm_company_polls where post_id=pid) is distinct from poll_options then return null;end if;
  end if;
  insert into public.wm_company_posts(id,workspace_id,author_id,kind,body,team_id,agency_key) values(pid,a.workspace_id,a.account_id,k,content,target_team,target_agency) on conflict(id) do nothing;
  select * into item from public.wm_company_posts where id=pid and workspace_id=a.workspace_id and author_id=a.account_id and kind=k and body=content and team_id is not distinct from target_team and agency_key is not distinct from target_agency and removed_at is null;
  if not found then return null;end if;
  if poll_options is not null then insert into public.wm_company_polls(post_id,options) values(pid,poll_options) on conflict do nothing;end if;
  return jsonb_build_object('id',pid,'published',true);
 end if;
 select p.* into item from public.wm_company_posts p join public.wm_memberships mb on mb.account_id=p.author_id and mb.workspace_id=p.workspace_id and mb.enabled join public.wm_accounts ac on ac.id=p.author_id and ac.enabled where p.id=pid and p.workspace_id=a.workspace_id and public.wm_company_audience_allowed(p.workspace_id,p.author_id,p.team_id,p.agency_key,a.account_id);
 if not found then return null;end if;
 if p_action='center-company-profile' then
  if item.removed_at is not null or (p_data-'id'-'member_id')<>'{}'::jsonb or jsonb_typeof(p_data->'member_id') is distinct from 'string' then return null;end if;
  profile_member:=(p_data->>'member_id')::uuid;
  if profile_member<>item.author_id and not exists(select 1 from public.wm_company_comments c where c.post_id=pid and c.author_id=profile_member and c.removed_at is null) then return null;end if;
  select jsonb_build_object('display_name',ac.display_name,'job_title',m.job_title,'agency_name',m.agency_name,'workspace_name',w.name) into result
  from public.wm_memberships m join public.wm_accounts ac on ac.id=m.account_id and ac.enabled join public.wm_workspaces w on w.id=m.workspace_id and w.enabled
  where m.workspace_id=a.workspace_id and m.account_id=profile_member and m.enabled and public.wm_company_audience_allowed(item.workspace_id,item.author_id,item.team_id,item.agency_key,profile_member);
  return result;
 end if;
 if p_action in ('center-company-vote','center-company-poll-close') then
  if item.removed_at is not null or item.kind<>'news' then return null;end if;
  select * into poll_row from public.wm_company_polls where post_id=pid;
  if not found then return null;end if;
  if p_action='center-company-poll-close' then
   if (p_data-'id')<>'{}'::jsonb or (item.author_id<>a.account_id and a.role<>'promoteur') then return null;end if;
   update public.wm_company_polls set closed_at=coalesce(closed_at,clock_timestamp()) where post_id=pid;
   return jsonb_build_object('closed',true);
  end if;
  if (p_data-'id'-'choice')<>'{}'::jsonb or jsonb_typeof(p_data->'choice') is distinct from 'number' or coalesce(p_data->>'choice','') !~ '^[0-5]$' then return null;end if;
  choice_idx:=(p_data->>'choice')::integer;
  if choice_idx>=jsonb_array_length(poll_row.options) then return null;end if;
  select choice into existing_choice from public.wm_company_votes where post_id=pid and account_id=a.account_id;
  if found then
   if existing_choice<>choice_idx then return null;end if;return jsonb_build_object('voted',true);
  end if;
  if poll_row.closed_at is not null then return null;end if;
  insert into public.wm_company_votes(post_id,account_id,choice) values(pid,a.account_id,choice_idx);
  return jsonb_build_object('voted',true);
 end if;
 if p_action in ('center-company-reaction','center-company-favorite','center-company-comments','center-company-comment','center-company-comment-remove') then
  if item.removed_at is not null or item.kind<>'news' then return null;end if;
  if p_action='center-company-reaction' then
   if (p_data-'id'-'reaction')<>'{}'::jsonb or not (p_data ? 'reaction') then return null;end if;
   if jsonb_typeof(p_data->'reaction')='null' then delete from public.wm_company_reactions where post_id=pid and account_id=a.account_id;
   elsif jsonb_typeof(p_data->'reaction')='string' and p_data->>'reaction' in ('like','love','celebrate','insightful','support','funny') then
    insert into public.wm_company_reactions(post_id,account_id,reaction) values(pid,a.account_id,p_data->>'reaction') on conflict(post_id,account_id) do update set reaction=excluded.reaction;
   else return null;end if;
   return jsonb_build_object('saved',true);
  elsif p_action='center-company-favorite' then
   if (p_data-'id'-'enabled')<>'{}'::jsonb or jsonb_typeof(p_data->'enabled') is distinct from 'boolean' then return null;end if;
   if (p_data->>'enabled')::boolean then insert into public.wm_company_favorites(post_id,account_id) values(pid,a.account_id) on conflict do nothing;
   else delete from public.wm_company_favorites where post_id=pid and account_id=a.account_id;end if;
   return jsonb_build_object('saved',true);
  elsif p_action='center-company-comments' then
   if (p_data-'id')<>'{}'::jsonb then return null;end if;
   select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at,x.id),'[]'::jsonb) into result from (
    select c.id,c.author_id,c.body,c.created_at,ac.display_name,mb.job_title,(c.author_id=a.account_id or a.role='promoteur') as can_remove
    from public.wm_company_comments c join public.wm_memberships mb on mb.account_id=c.author_id and mb.workspace_id=a.workspace_id and mb.enabled
    join public.wm_accounts ac on ac.id=c.author_id and ac.enabled
    where c.post_id=pid and c.removed_at is null and public.wm_company_audience_allowed(item.workspace_id,item.author_id,item.team_id,item.agency_key,c.author_id) order by c.created_at desc,c.id desc limit 100
   ) x;
   return jsonb_build_object('items',result);
  end if;
  if jsonb_typeof(p_data->'comment_id') is distinct from 'string' or coalesce(p_data->>'comment_id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then return null;end if;
  cid:=(p_data->>'comment_id')::uuid;
  if p_action='center-company-comment' then
   if (p_data-'id'-'comment_id'-'body')<>'{}'::jsonb or jsonb_typeof(p_data->'body') is distinct from 'string' then return null;end if;
   content:=btrim(p_data->>'body');if length(content) not between 1 and 1000 then return null;end if;
   insert into public.wm_company_comments(id,post_id,author_id,body) values(cid,pid,a.account_id,content) on conflict(id) do nothing;
   select * into comment_row from public.wm_company_comments where id=cid and post_id=pid and author_id=a.account_id and body=content and removed_at is null;
   if not found then return null;end if;return jsonb_build_object('created',true);
  else
   if (p_data-'id'-'comment_id')<>'{}'::jsonb then return null;end if;
   update public.wm_company_comments set removed_at=coalesce(removed_at,clock_timestamp()) where id=cid and post_id=pid and (author_id=a.account_id or a.role='promoteur');
   if not found then return null;end if;return jsonb_build_object('removed',true);
  end if;
 end if;
 if (p_data-'id')<>'{}'::jsonb then return null;end if;
 if p_action='center-company-remove' then
  if item.author_id<>a.account_id and a.role<>'promoteur' then return null;end if;
  update public.wm_company_posts set removed_at=coalesce(removed_at,clock_timestamp()) where id=pid and workspace_id=a.workspace_id;
  update public.wm_chat_media set state='revoked',revoked_at=coalesce(revoked_at,clock_timestamp()) where post_id=pid and workspace_id=a.workspace_id and state<>'revoked';
  return jsonb_build_object('removed',true);
 elsif p_action='center-company-confirm' then
  if item.removed_at is not null or item.kind<>'announcement' or item.author_id=a.account_id then return null;end if;
  insert into public.wm_company_reads(post_id,account_id) values(pid,a.account_id) on conflict do nothing;
  return jsonb_build_object('confirmed',true);
 end if;
 return null;
end $wm$;
revoke all on function public.wm_company_action(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_company_action(text,text,jsonb) to service_role;
commit;
