begin;
-- Candidate v11: meeting authorization and auditable scheduling, not media transport.
create table public.ns_internal_meetings(
 id uuid primary key,org_id uuid not null,site_id uuid not null,workstation_id uuid,host_member_id uuid not null,
 title text not null check(length(trim(title)) between 1 and 160),scheduled_at timestamptz not null,
 status text not null check(status in ('scheduled','open','closed','cancelled')),revision integer not null default 1,
 started_at timestamptz,ended_at timestamptz,created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(workstation_id,site_id,org_id) references public.ns_workstations(id,site_id,org_id),
 foreign key(host_member_id,org_id) references public.ns_members(id,org_id));
create table public.ns_internal_meeting_invitees(
 meeting_id uuid not null references public.ns_internal_meetings(id),org_id uuid not null,member_id uuid not null,
 listening_locale text not null default 'fr' check(listening_locale in ('fr','en','ff-CM','es','it','zh-CN','original')),
 recording_consent boolean,consent_at timestamptz,
 primary key(meeting_id,member_id),foreign key(member_id,org_id) references public.ns_members(id,org_id));
create function public.ns_meeting_can_read(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and public.ns_erp_access_reason(m.org_id)<>'blocked' and
 (m.host_member_id=public.ns_current_member_id(m.org_id) or exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id=public.ns_current_member_id(m.org_id))))
$f$;
create function public.ns_meeting_can_host(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and m.host_member_id=public.ns_current_member_id(m.org_id)
 and exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id<>m.host_member_id)
 and not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id<>m.host_member_id and not public.ns_roster_can_manage(m.org_id,m.site_id,m.workstation_id,i.member_id)))
$f$;
revoke all on function public.ns_meeting_can_read(uuid),public.ns_meeting_can_host(uuid) from public,anon,authenticated;
grant execute on function public.ns_meeting_can_read(uuid),public.ns_meeting_can_host(uuid) to authenticated;
alter table public.ns_internal_meetings enable row level security;
alter table public.ns_internal_meeting_invitees enable row level security;
revoke all on public.ns_internal_meetings,public.ns_internal_meeting_invitees from public,anon,authenticated;
grant select on public.ns_internal_meetings,public.ns_internal_meeting_invitees to authenticated;
create policy ns_meeting_read on public.ns_internal_meetings for select to authenticated using(public.ns_meeting_can_read(id));
create policy ns_meeting_invite_read on public.ns_internal_meeting_invitees for select to authenticated using(public.ns_meeting_can_read(meeting_id) and (member_id=public.ns_current_member_id(org_id) or public.ns_meeting_can_host(meeting_id)));
create function public.ns_schedule_internal_meeting(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_title text,p_at timestamptz,p_members uuid[]) returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor uuid:=public.ns_current_member_id(p_org); target uuid; nid uuid; msg jsonb; loc text;
begin
 if not public.ns_roster_enabled(p_org) or p_id is null or p_at is null or p_at<now()-interval '5 minutes' or p_title is null or length(trim(p_title)) not between 1 and 160 or coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 foreach target in array p_members loop
  if target is null or not public.ns_roster_can_manage(p_org,p_site,p_post,target) then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 end loop;
 insert into public.ns_internal_meetings(id,org_id,site_id,workstation_id,host_member_id,title,scheduled_at,status) values(p_id,p_org,p_site,p_post,actor,trim(p_title),p_at,'scheduled');
 insert into public.ns_internal_meeting_invitees(meeting_id,org_id,member_id) values(p_id,p_org,actor);
 foreach target in array p_members loop
  insert into public.ns_internal_meeting_invitees(meeting_id,org_id,member_id) values(p_id,p_org,target) on conflict do nothing;
  if found then
   select coalesce(preferred_locale,'fr') into loc from public.ns_members where id=target;
   msg:=case loc when 'en' then jsonb_build_object('title','Meeting invitation','body','Open your internal meetings to review the invitation.')
    when 'ff-CM' then jsonb_build_object('title','Noddaango dental','body','Uddit dental golle ngam ƴeewtaade noddaango.')
    else jsonb_build_object('title','Invitation à une réunion','body','Consultez vos réunions internes pour voir votre invitation.') end;
   msg:=msg||jsonb_build_object('meeting_id',p_id,'route','/team');
   insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
    values(p_org,p_site,target,'push','internal_meeting.invited','meeting:'||p_id::text||':'||target::text,msg) returning id into nid;
   insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
    values(p_org,p_site,target,nid,'internal_meeting.invited',msg,'sent',now());
  end if;
 end loop;
 return jsonb_build_object('id',p_id,'status','scheduled');
end $f$;
create function public.ns_transition_internal_meeting(p_id uuid,p_revision integer,p_next text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype;
begin
 if not public.ns_meeting_can_host(p_id) then raise exception 'NS_MEETING_FORBIDDEN'; end if;
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if m.revision is distinct from p_revision or not ((m.status='scheduled' and p_next in ('open','cancelled')) or (m.status='open' and p_next='closed')) then raise exception 'NS_MEETING_STATE_CONFLICT'; end if;
 update public.ns_internal_meetings set status=p_next,revision=revision+1,started_at=case when p_next='open' then clock_timestamp() else started_at end,ended_at=case when p_next in ('closed','cancelled') then clock_timestamp() else ended_at end where id=p_id returning * into m;
 return jsonb_build_object('id',m.id,'status',m.status,'revision',m.revision);
end $f$;
create function public.ns_set_meeting_listener(p_id uuid,p_locale text,p_consent boolean default null) returns boolean language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype;
begin
 if not public.ns_meeting_can_read(p_id) or p_locale is null or p_locale not in ('fr','en','ff-CM','es','it','zh-CN','original') then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if m.status not in ('scheduled','open') then raise exception 'NS_MEETING_STATE_CONFLICT'; end if;
 update public.ns_internal_meeting_invitees set listening_locale=p_locale,recording_consent=coalesce(p_consent,recording_consent),consent_at=case when p_consent is not null then now() else consent_at end where meeting_id=p_id and member_id=public.ns_current_member_id(m.org_id);
 return found;
end $f$;
revoke all on function public.ns_schedule_internal_meeting(uuid,uuid,uuid,uuid,text,timestamptz,uuid[]),public.ns_transition_internal_meeting(uuid,integer,text),public.ns_set_meeting_listener(uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.ns_schedule_internal_meeting(uuid,uuid,uuid,uuid,text,timestamptz,uuid[]),public.ns_transition_internal_meeting(uuid,integer,text),public.ns_set_meeting_listener(uuid,text,boolean) to authenticated;
-- Report reads only confirmed server facts. Site finance restricted to site managers; other staff see own assignments.
create function public.ns_daily_briefing(p_org uuid,p_site uuid,p_day date) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare actor uuid:=public.ns_current_member_id(p_org); manager boolean; start_at timestamptz; stop_at timestamptz; fin jsonb; appointments jsonb; clocks jsonb;
begin
 if actor is null or p_day is null or p_day>(now() at time zone 'Africa/Douala')::date or p_day<(now() at time zone 'Africa/Douala')::date-366 or public.ns_erp_access_reason(p_org)='blocked' or not exists(select 1 from public.ns_sites where id=p_site and org_id=p_org and status='active') then raise exception 'NS_BRIEFING_FORBIDDEN'; end if;
 if not public.ns_can_access_site(p_org,p_site) and not exists(select 1 from public.ns_member_scopes s where s.org_id=p_org and s.member_id=actor and s.site_id=p_site and s.scope_type='workstation' and s.can_read) then raise exception 'NS_BRIEFING_FORBIDDEN'; end if;
 manager:=public.ns_can_manage_site(p_org,p_site);
 start_at:=p_day::timestamp at time zone 'Africa/Douala';stop_at:=(p_day+1)::timestamp at time zone 'Africa/Douala';
 if manager then select jsonb_build_object('revenue_xaf',v.revenue_xaf,'confirmed_sales_count',v.confirmed_sales_count,'uncosted_sales_count',v.uncosted_sales_count) into fin from public.ns_performance_daily v where v.org_id=p_org and v.site_id=p_site and v.performance_day=p_day; end if;
 select jsonb_build_object('scheduled_count',count(*),'completed_count',count(*) filter(where a.status='completed')) into appointments from public.ns_appointments a where a.org_id=p_org and a.site_id=p_site and a.starts_at>=start_at and a.starts_at<stop_at and (manager or a.assigned_member_id=actor);
 if public.ns_roster_enabled(p_org) then
  select jsonb_build_object('first_clock_in',min(e.occurred_at) filter(where e.event_type='staff_clock_in'),'last_clock_out',max(e.occurred_at) filter(where e.event_type='staff_clock_out'),'event_count',count(*)) into clocks from public.ns_staff_time_events e where e.org_id=p_org and e.site_id=p_site and e.staff_member_id=actor and e.occurred_at>=start_at and e.occurred_at<stop_at and e.actor_member_id=actor;
 end if;
 return jsonb_build_object('day',p_day,'generated_at',now(),'scope',case when manager then 'site' else 'personal' end,'finance',fin,'appointments',appointments,'personal_clock_events',clocks,'coverage','partial_confirmed_server_facts');
end $f$;
revoke all on function public.ns_daily_briefing(uuid,uuid,date) from public,anon,authenticated;
grant execute on function public.ns_daily_briefing(uuid,uuid,date) to authenticated;

rollback;
