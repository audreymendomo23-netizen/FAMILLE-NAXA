begin;
-- Workspace private conversations. No implicit access for a manager or promoter.
create table public.wm_direct_messages(
 id uuid primary key,
 workspace_id uuid not null references public.wm_workspaces(id),
 sender_id uuid not null references public.wm_accounts(id),
 recipient_id uuid not null references public.wm_accounts(id),
 body text not null check(length(body) between 1 and 2000),
 created_at timestamptz not null default clock_timestamp(),
 read_at timestamptz,
 check(sender_id<>recipient_id)
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
declare a record; peer uuid; mid uuid; b text; q text; v jsonb; m public.wm_direct_messages%rowtype; days integer; scope_name text; cutoff bigint; upper_ms bigint; period_name text;
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
  select jsonb_build_object('scope',scope_name,'days',days,'period',period_name,'start_ms',cutoff,'end_ms',upper_ms,'total',count(*),
   'scheduled',count(*) filter(where state->>'status'='scheduled' and coalesce(state->>'cancelled','false')='false'),
   'open',count(*) filter(where state->>'status'='open'),
   'paused',count(*) filter(where state->>'status'='paused'),
   'ended',count(*) filter(where state->>'status'='ended' and coalesce(state->>'cancelled','false')='false'),
   'cancelled',count(*) filter(where state->>'cancelled'='true'),
   'duration_minutes',coalesce(sum((state->>'durationMinutes')::bigint) filter(where coalesce(state->>'cancelled','false')='false'),0),
   'polls_closed',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'polls','[]'::jsonb)) p where p->>'open'='false')),0),
   'polls_effectively_closed',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'polls','[]'::jsonb)) p where p->>'open'='false' or (p->>'closesMs')::bigint<=upper_ms or state->>'status'='ended')),0),
   'tasks_done',coalesce(sum((select count(*) from public.wm_tasks t join public.wm_minutes_versions mv on mv.id=t.version_id and mv.revoked_at is null and mv.published_at is not null where t.room_id=wm_rooms.id and t.state='done' and exists(select 1 from public.wm_minutes_recipients mr where mr.version_id=t.version_id and mr.account_id=t.assignee_id and mr.revoked_at is null))),0))
   into v from public.wm_rooms where workspace_id=a.workspace_id and (a.role='promoteur' or host_id=a.account_id)
   and (state->>'scheduledMs')::bigint>=cutoff and (state->>'scheduledMs')::bigint<upper_ms;
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
  select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at,c.id),'[]'::jsonb) into v from (
   select id,sender_id,recipient_id,body,created_at,read_at from public.wm_direct_messages
   where workspace_id=a.workspace_id and ((sender_id=a.account_id and recipient_id=peer) or (sender_id=peer and recipient_id=a.account_id))
   and (q='' or strpos(lower(body),lower(q))>0) order by created_at desc,id desc limit 200
  ) c;
  return jsonb_build_object('items',v);
 end if;
 mid:=(p_data->>'message_id')::uuid;
 if mid is null then return null;end if;
 if p_action='center-seen' then
  update public.wm_direct_messages set read_at=coalesce(read_at,clock_timestamp()) where id=mid and workspace_id=a.workspace_id and sender_id=peer and recipient_id=a.account_id;
  if not found then return null;end if;return jsonb_build_object('seen',true);
 end if;
 if p_action='center-send' then
  b:=btrim(p_data->>'body');if b is null or length(b) not between 1 and 2000 then return null;end if;
  select * into m from public.wm_direct_messages where id=mid;
  if found then
   if m.workspace_id=a.workspace_id and m.sender_id=a.account_id and m.recipient_id=peer and m.body=b then return jsonb_build_object('sent',true);end if;
   return null;
  end if;
  if (select count(*) from public.wm_direct_messages where sender_id=a.account_id and created_at>clock_timestamp()-interval '1 minute')>=20 then return null;end if;
  insert into public.wm_direct_messages(id,workspace_id,sender_id,recipient_id,body) values(mid,a.workspace_id,a.account_id,peer,b);
  return jsonb_build_object('sent',true);
 end if;
 return null;
exception when invalid_text_representation or unique_violation then return null;
end $wm$;
revoke all on function public.wm_workspace_center(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.wm_workspace_center(text,text,jsonb) to service_role;
commit;
