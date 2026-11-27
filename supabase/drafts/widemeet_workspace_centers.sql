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
create function public.wm_workspace_center(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; peer uuid; mid uuid; b text; q text; v jsonb; m public.wm_direct_messages%rowtype; days integer; scope_name text; cutoff bigint; page_size integer; before_row public.wm_direct_messages%rowtype; has_more boolean;
begin
 -- Same lock order as identity membership mutations; then recheck session and entitlement.
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 select * into a from public.wm_lock_room_actor_for(p_hash,null);
 if not found or not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') then return null;end if;
 if p_action='center-statistics' then
  if a.plan<>'premium' or a.role not in ('promoteur','manager') then return null;end if;
  if coalesce(p_data->>'days','') not in ('7','30','90','365') then return null;end if;
  days:=(p_data->>'days')::integer;scope_name:=case when a.role='promoteur' then 'enterprise' else 'organizer' end;
  cutoff:=floor(extract(epoch from clock_timestamp()-make_interval(days=>days))*1000)::bigint;
  select jsonb_build_object('scope',scope_name,'days',days,'total',count(*),
   'scheduled',count(*) filter(where state->>'status'='scheduled' and coalesce(state->>'cancelled','false')='false'),
   'open',count(*) filter(where state->>'status'='open'),
   'paused',count(*) filter(where state->>'status'='paused'),
   'ended',count(*) filter(where state->>'status'='ended' and coalesce(state->>'cancelled','false')='false'),
   'cancelled',count(*) filter(where state->>'cancelled'='true'),
   'duration_minutes',coalesce(sum((state->>'durationMinutes')::bigint) filter(where coalesce(state->>'cancelled','false')='false'),0),
   'polls_closed',coalesce(sum((select count(*) from jsonb_array_elements(coalesce(state->'polls','[]'::jsonb)) p where p->>'open'='false')),0),
   'tasks_done',coalesce(sum((select count(*) from public.wm_tasks t join public.wm_minutes_versions mv on mv.id=t.version_id and mv.revoked_at is null and mv.published_at is not null where t.room_id=wm_rooms.id and t.state='done' and exists(select 1 from public.wm_minutes_recipients mr where mr.version_id=t.version_id and mr.account_id=t.assignee_id and mr.revoked_at is null))),0))
   into v from public.wm_rooms where workspace_id=a.workspace_id and (a.role='promoteur' or host_id=a.account_id)
   and (state->>'scheduledMs')::bigint>=cutoff and (state->>'scheduledMs')::bigint<=floor(extract(epoch from clock_timestamp())*1000)::bigint;
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
   select id,sender_id,recipient_id,body,created_at,read_at from public.wm_direct_messages
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
 room_id uuid references public.wm_rooms(id), channel text check(channel in ('agenda','room-chat')),
 kind text not null check(kind in ('file','voice')),
 mime text not null check(mime in ('application/pdf','image/jpeg','image/png','audio/ogg','audio/webm','audio/mp4')),
 name text not null check(length(name) between 1 and 120),
 bytes integer not null check(bytes between 1 and 1048576),
 sha256 text not null check(length(sha256)=64 and translate(sha256,'0123456789abcdef','')=''),
 state text not null default 'staged' check(state in ('staged','ready','revoked')),
 created_at timestamptz not null default clock_timestamp(), published_at timestamptz, revoked_at timestamptz, purged_at timestamptz,
 check(num_nonnulls(peer_id,group_id,room_id)=1), check(peer_id is null or peer_id<>sender_id),
 check((room_id is null)=(channel is null)),check(channel is distinct from 'agenda' or kind='file'),
 check((kind='voice')=(mime in ('audio/ogg','audio/webm','audio/mp4')))
);
create index wm_chat_media_direct on public.wm_chat_media(workspace_id,sender_id,peer_id,published_at desc,id);
create index wm_chat_media_group on public.wm_chat_media(group_id,published_at desc,id);
create index wm_chat_media_room on public.wm_chat_media(room_id,channel,published_at desc,id);
alter table public.wm_chat_media enable row level security;
revoke all on public.wm_chat_media from public,anon,authenticated;
grant select,insert,update on public.wm_chat_media to service_role;
create function public.wm_chat_media_action(p_hash text,p_action text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare a record; gid uuid; peer uuid; rid uuid; channel_name text; room_row public.wm_rooms%rowtype; participant jsonb; room_status text; mid uuid; m public.wm_chat_media%rowtype; joined timestamptz; v jsonb; k text; mime_type text; filename text; size_bytes integer; sha text;
begin
 perform pg_advisory_xact_lock(hashtextextended('wm-identity-action-v1',0));
 gid:=(p_data->>'group_id')::uuid;peer:=(p_data->>'peer_id')::uuid;rid:=(p_data->>'room_id')::uuid;channel_name:=p_data->>'channel';
 if num_nonnulls(gid,peer,rid)<>1 or (rid is null)<>(channel_name is null) then return null;end if;
 select * into a from public.wm_lock_room_actor_for(p_hash,rid);
 if not found then return null;end if;
 if not exists(select 1 from public.wm_workspaces w where w.id=a.workspace_id and w.enabled and w.kind='enterprise') or peer=a.account_id then return null;end if;
 if rid is not null then
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
   ((rid is not null and x.room_id=rid and x.channel=channel_name)
    or (gid is not null and x.group_id=gid and x.created_at>=joined and x.published_at>=joined)
    or (peer is not null and x.group_id is null and x.room_id is null and ((x.sender_id=a.account_id and x.peer_id=peer) or (x.sender_id=peer and x.peer_id=a.account_id))))
   order by x.published_at desc,x.id desc limit 100
  ) c;return jsonb_build_object('items',v);
 end if;
 mid:=(p_data->>'id')::uuid;if mid is null then return null;end if;
 select * into m from public.wm_chat_media x where x.id=mid;
 if p_action='reserve' then
  k:=p_data->>'kind';mime_type:=p_data->>'mime';filename:=p_data->>'name';size_bytes:=(p_data->>'bytes')::integer;sha:=p_data->>'sha256';
  if k is null or mime_type is null or filename is null or size_bytes is null or sha is null or (channel_name='agenda' and k<>'file') then return null;end if;
  if k not in ('file','voice') or mime_type not in ('application/pdf','image/jpeg','image/png','audio/ogg','audio/webm','audio/mp4') or (k='voice')<>(mime_type in ('audio/ogg','audio/webm','audio/mp4')) or length(filename) not between 1 and 120 or size_bytes not between 1 and 1048576 or length(sha)<>64 or translate(sha,'0123456789abcdef','')<>'' then return null;end if;
  if found then
   if m.workspace_id<>a.workspace_id or m.sender_id<>a.account_id or m.peer_id is distinct from peer or m.group_id is distinct from gid or m.room_id is distinct from rid or m.channel is distinct from channel_name or m.kind<>k or m.mime<>mime_type or m.name<>filename or m.bytes<>size_bytes or m.sha256<>sha or m.state='revoked' or (gid is not null and m.created_at<joined) then return null;end if;
   if m.state='staged' and m.created_at<=clock_timestamp()-interval '15 minutes' then return null;end if;
  else
   if (select count(*) from public.wm_chat_media x where x.sender_id=a.account_id and x.created_at>clock_timestamp()-interval '1 minute')>=5 then return null;end if;
   insert into public.wm_chat_media(id,workspace_id,sender_id,peer_id,group_id,room_id,channel,kind,mime,name,bytes,sha256) values(mid,a.workspace_id,a.account_id,peer,gid,rid,channel_name,k,mime_type,filename,size_bytes,sha) returning * into m;
  end if;
  return jsonb_build_object('id',m.id,'key',m.workspace_id::text||'/'||m.id::text,'state',m.state,'bytes',m.bytes,'sha256',m.sha256,'mime',m.mime,'name',m.name,'kind',m.kind);
 end if;
 if not found or m.workspace_id<>a.workspace_id then return null;end if;
 if rid is not null then
  if m.room_id is distinct from rid or m.channel is distinct from channel_name then return null;end if;
 elsif gid is not null then
  if m.group_id is distinct from gid or m.created_at<joined then return null;end if;
 else
  if m.group_id is not null or m.room_id is not null or not ((m.sender_id=a.account_id and m.peer_id=peer) or (m.sender_id=peer and m.peer_id=a.account_id)) then return null;end if;
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
commit;
