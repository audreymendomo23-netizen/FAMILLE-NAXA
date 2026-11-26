begin;
-- v13 candidate: scoped in-meeting collaboration and moderation intent; no SFU effects implied.
alter table public.ns_internal_meeting_invitees
 add column excluded_at timestamptz,
 add column hand_raised_at timestamptz,
 add column screen_allowed boolean not null default false,
 add column chat_allowed boolean not null default true,
 add column mic_muted_by_host boolean not null default false;
create table public.ns_meeting_chat(
 id uuid primary key,meeting_id uuid not null references public.ns_internal_meetings(id),
 member_id uuid not null, message text not null check(length(trim(message)) between 1 and 2000),
 created_at timestamptz not null default clock_timestamp());
create index ns_meeting_chat_recent on public.ns_meeting_chat(meeting_id,created_at desc,id);
create table public.ns_meeting_reactions(
 id uuid primary key,meeting_id uuid not null references public.ns_internal_meetings(id),
 member_id uuid not null,reaction text not null check(reaction in ('like','clap','heart','laugh','agree','celebrate')),
 created_at timestamptz not null default clock_timestamp());
create index ns_meeting_reactions_recent on public.ns_meeting_reactions(meeting_id,created_at desc,id);
create table public.ns_meeting_moderation(
 id uuid primary key,meeting_id uuid not null references public.ns_internal_meetings(id),actor_member_id uuid not null,
 target_member_id uuid not null,action text not null check(action in ('lower_hand','mute','allow_mic','allow_screen','deny_screen','allow_chat','deny_chat','exclude')),
 created_at timestamptz not null default clock_timestamp());
create or replace function public.ns_meeting_can_read(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and public.ns_erp_access_reason(m.org_id)<>'blocked'
 and (public.ns_meeting_can_host(m.id) or (m.host_member_id<>public.ns_current_member_id(m.org_id)
 and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,public.ns_current_member_id(m.org_id),false)
 and exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id=public.ns_current_member_id(m.org_id) and i.excluded_at is null))))
$f$;
create function public.ns_meeting_can_interact(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m join public.ns_internal_meeting_invitees i on i.meeting_id=m.id
 where m.id=p_id and m.status='open' and public.ns_meeting_can_read(m.id)
 and i.member_id=public.ns_current_member_id(m.org_id) and i.response<>'declined' and i.excluded_at is null)
$f$;
revoke all on function public.ns_meeting_can_interact(uuid) from public,anon,authenticated;
grant execute on function public.ns_meeting_can_interact(uuid) to authenticated;
alter table public.ns_meeting_chat enable row level security;
alter table public.ns_meeting_reactions enable row level security;
alter table public.ns_meeting_moderation enable row level security;
revoke all on public.ns_meeting_chat,public.ns_meeting_reactions,public.ns_meeting_moderation from public,anon,authenticated;
grant select on public.ns_meeting_chat,public.ns_meeting_reactions,public.ns_meeting_moderation to authenticated;
create policy ns_meeting_chat_read on public.ns_meeting_chat for select to authenticated using(public.ns_meeting_can_interact(meeting_id));
create policy ns_meeting_reactions_read on public.ns_meeting_reactions for select to authenticated using(public.ns_meeting_can_interact(meeting_id) and created_at>now()-interval '2 minutes');
create policy ns_meeting_moderation_read on public.ns_meeting_moderation for select to authenticated using(public.ns_meeting_can_host(meeting_id));
create function public.ns_meeting_participants(p_id uuid) returns table(member_id uuid,display_name text,hand_raised_at timestamptz,screen_allowed boolean,chat_allowed boolean,mic_muted_by_host boolean) language sql stable security definer set search_path='' as $f$
 select i.member_id,m.display_name,i.hand_raised_at,i.screen_allowed,i.chat_allowed,i.mic_muted_by_host
 from public.ns_internal_meeting_invitees i join public.ns_internal_meetings r on r.id=i.meeting_id
 join public.ns_members m on m.org_id=i.org_id and m.id=i.member_id
 where i.meeting_id=p_id and public.ns_meeting_can_interact(p_id) and i.excluded_at is null and i.response<>'declined'
 and public.ns_meeting_scope_valid(r.org_id,r.site_id,r.workstation_id,i.member_id,false)
$f$;
revoke all on function public.ns_meeting_participants(uuid) from public,anon,authenticated;
grant execute on function public.ns_meeting_participants(uuid) to authenticated;
create function public.ns_meeting_action(p_id uuid,p_event uuid,p_action text,p_value text default null) returns boolean language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; actor uuid; i public.ns_internal_meeting_invitees%rowtype;
begin
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if not found or not public.ns_meeting_can_interact(p_id) then raise exception 'NS_MEETING_INTERACTION_FORBIDDEN';end if;
 actor:=public.ns_current_member_id(m.org_id);
 select * into i from public.ns_internal_meeting_invitees where meeting_id=p_id and member_id=actor;
 if p_action in ('raise_hand','lower_hand') then
  update public.ns_internal_meeting_invitees set hand_raised_at=case when p_action='raise_hand' then coalesce(hand_raised_at,clock_timestamp()) else null end where meeting_id=p_id and member_id=actor;
 elsif p_action='chat' then
  if not i.chat_allowed or p_event is null or p_value is null or length(trim(p_value)) not between 1 and 2000 then raise exception 'NS_MEETING_CHAT_FORBIDDEN_OR_INVALID';end if;
  if exists(select 1 from public.ns_meeting_chat where id=p_event and meeting_id=p_id and member_id=actor and message=trim(p_value)) then return true;end if;
  if (select count(*) from public.ns_meeting_chat where meeting_id=p_id and member_id=actor and created_at>clock_timestamp()-interval '10 seconds')>=5 then raise exception 'NS_MEETING_RATE_LIMIT';end if;
  insert into public.ns_meeting_chat(id,meeting_id,member_id,message) values(p_event,p_id,actor,trim(p_value));
 elsif p_action='reaction' then
  if p_event is null or p_value is null or p_value not in ('like','clap','heart','laugh','agree','celebrate') then raise exception 'NS_MEETING_REACTION_INVALID';end if;
  if exists(select 1 from public.ns_meeting_reactions where id=p_event and meeting_id=p_id and member_id=actor and reaction=p_value) then return true;end if;
  if (select count(*) from public.ns_meeting_reactions where meeting_id=p_id and member_id=actor and created_at>clock_timestamp()-interval '10 seconds')>=5 then raise exception 'NS_MEETING_RATE_LIMIT';end if;
  insert into public.ns_meeting_reactions(id,meeting_id,member_id,reaction) values(p_event,p_id,actor,p_value);
 else raise exception 'NS_MEETING_INTERACTION_INVALID';
 end if;
 return true;
end $f$;
revoke all on function public.ns_meeting_action(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.ns_meeting_action(uuid,uuid,text,text) to authenticated;
create function public.ns_moderate_meeting(p_id uuid,p_event uuid,p_target uuid,p_action text) returns boolean language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; actor uuid;
begin
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if not found or m.status<>'open' or not public.ns_meeting_can_host(p_id) or p_target is null or p_target=m.host_member_id or p_event is null or p_action is null or p_action not in ('lower_hand','mute','allow_mic','allow_screen','deny_screen','allow_chat','deny_chat','exclude') then raise exception 'NS_MEETING_MODERATION_FORBIDDEN';end if;
 actor:=public.ns_current_member_id(m.org_id);
 if exists(select 1 from public.ns_meeting_moderation where id=p_event and meeting_id=p_id and actor_member_id=actor and target_member_id=p_target and action=p_action) then return true;end if;
 update public.ns_internal_meeting_invitees set
 hand_raised_at=case when p_action in ('lower_hand','exclude') then null else hand_raised_at end,
 mic_muted_by_host=case when p_action='mute' then true when p_action='allow_mic' then false else mic_muted_by_host end,
 screen_allowed=case when p_action='allow_screen' then true when p_action in ('deny_screen','exclude') then false else screen_allowed end,
 chat_allowed=case when p_action='allow_chat' then true when p_action in ('deny_chat','exclude') then false else chat_allowed end,
 excluded_at=case when p_action='exclude' then clock_timestamp() else excluded_at end
 where meeting_id=p_id and member_id=p_target and excluded_at is null;
 if not found then raise exception 'NS_MEETING_MODERATION_FORBIDDEN';end if;
 insert into public.ns_meeting_moderation(id,meeting_id,actor_member_id,target_member_id,action) values(p_event,p_id,actor,p_target,p_action);
 return true;
end $f$;
revoke all on function public.ns_moderate_meeting(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ns_moderate_meeting(uuid,uuid,uuid,text) to authenticated;
-- Permissions are desired state; active SFU participants must still be reconciled before enabling media.
create or replace function public.ns_meeting_media_grant(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; actor uuid; host boolean; i public.ns_internal_meeting_invitees%rowtype;
begin
 if not public.ns_meeting_can_read(p_id) then raise exception 'NS_MEDIA_FORBIDDEN';end if;
 select * into m from public.ns_internal_meetings where id=p_id;
 if m.status<>'open' then raise exception 'NS_MEDIA_NOT_OPEN';end if;
 actor:=public.ns_current_member_id(m.org_id);host:=public.ns_meeting_can_host(p_id);
 select * into i from public.ns_internal_meeting_invitees where meeting_id=p_id and member_id=actor and excluded_at is null and response<>'declined';
 if not found then raise exception 'NS_MEDIA_FORBIDDEN';end if;
 return jsonb_build_object('meeting_id',m.id,'member_id',actor,'room','ns-'||m.id::text,'host',host,'revision',m.revision,'screen_allowed',host or i.screen_allowed,'microphone_allowed',not i.mic_muted_by_host);
end $f$;

rollback;
