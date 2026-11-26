-- Candidate schema and synthetic fixtures in one rollback transaction.
begin;
-- Planning candidate. Install only in disposable qualification until UI and delivery pass.
create function public.ns_roster_enabled(p_org uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.ns_current_member_id(p_org) is not null and exists(select 1 from public.ns_organizations o where o.id=p_org and o.status='active' and o.business_mode in ('single_site_multi_workstation','multi_site_network'))
$$;
create function public.ns_roster_rank(p_role text) returns integer language sql immutable set search_path='' as $$
 select case p_role when 'promoter' then 40 when 'network_manager' then 30 when 'site_manager' then 20 when 'workstation_manager' then 10 else 0 end
$$;
create function public.ns_roster_can_manage(p_org uuid,p_site uuid,p_post uuid,p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.ns_roster_enabled(p_org) and public.ns_erp_access_reason(p_org)<>'blocked' and exists(
 select 1 from public.ns_members a join public.ns_members t on t.org_id=a.org_id
 join public.ns_sites s on s.org_id=a.org_id and s.id=p_site and s.status='active'
 where a.id=public.ns_current_member_id(p_org) and a.org_id=p_org and t.id=p_member and t.status='active'
 and public.ns_roster_rank(a.role_code)>public.ns_roster_rank(t.role_code)
 and (p_post is null or exists(select 1 from public.ns_workstations w where w.id=p_post and w.org_id=p_org and w.site_id=p_site and w.status='active'))
 and exists(select 1 from public.ns_member_scopes x where x.org_id=p_org and x.member_id=a.id and x.can_manage and (
 (a.role_code='promoter' and x.scope_type='organization')
 or (a.role_code in ('network_manager','site_manager') and x.scope_type='site' and x.site_id=p_site)
 or (a.role_code='workstation_manager' and p_post is not null and x.scope_type='workstation' and x.site_id=p_site and x.workstation_id=p_post)))
 and exists(select 1 from public.ns_member_scopes x where x.org_id=p_org and x.member_id=t.id and (x.can_operate or x.can_manage) and (
 x.scope_type='organization' or (x.scope_type='site' and x.site_id=p_site) or (x.scope_type='workstation' and x.site_id=p_site and x.workstation_id=p_post))))
$$;
create function public.ns_roster_can_read(p_org uuid,p_site uuid,p_post uuid,p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.ns_roster_enabled(p_org) and (p_member=public.ns_current_member_id(p_org) or public.ns_roster_can_manage(p_org,p_site,p_post,p_member))
$$;
revoke all on function public.ns_roster_enabled(uuid),public.ns_roster_rank(text),public.ns_roster_can_manage(uuid,uuid,uuid,uuid),public.ns_roster_can_read(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_roster_enabled(uuid),public.ns_roster_can_manage(uuid,uuid,uuid,uuid),public.ns_roster_can_read(uuid,uuid,uuid,uuid) to authenticated;
create table public.ns_roster_shifts(
 id uuid primary key, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, planned_break_minutes integer not null default 0,
 tolerance_minutes integer not null default 10, status text not null check(status in ('published','cancelled')),
 revision bigint not null check(revision>0), updated_by uuid not null, updated_at timestamptz not null,
 change_reason text not null check(length(trim(change_reason)) between 1 and 500),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(workstation_id,site_id,org_id) references public.ns_workstations(id,site_id,org_id),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 foreign key(updated_by,org_id) references public.ns_members(id,org_id),
 check(ends_at>starts_at and ends_at<=starts_at+interval '24 hours'),
 check(planned_break_minutes>=0 and planned_break_minutes<extract(epoch from ends_at-starts_at)/60),
 check(tolerance_minutes between 0 and 120));
create index ns_roster_member_period on public.ns_roster_shifts(org_id,member_id,starts_at,ends_at) where status='published';
create table public.ns_roster_revisions(
 shift_id uuid not null references public.ns_roster_shifts(id), revision bigint not null,
 org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, planned_break_minutes integer not null,
 tolerance_minutes integer not null,status text not null,updated_by uuid not null,updated_at timestamptz not null,change_reason text not null,
 primary key(shift_id,revision));
create table public.ns_roster_acknowledgements(
 shift_id uuid not null, revision bigint not null, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 acknowledged_at timestamptz not null default clock_timestamp(), primary key(shift_id,revision),
 foreign key(shift_id,revision) references public.ns_roster_revisions(shift_id,revision));
alter table public.ns_roster_shifts enable row level security;
alter table public.ns_roster_revisions enable row level security;
alter table public.ns_roster_acknowledgements enable row level security;
revoke all on public.ns_roster_shifts,public.ns_roster_revisions,public.ns_roster_acknowledgements from public,anon,authenticated;
grant select on public.ns_roster_shifts,public.ns_roster_revisions,public.ns_roster_acknowledgements to authenticated;
create policy ns_roster_shift_read on public.ns_roster_shifts for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create policy ns_roster_revision_read on public.ns_roster_revisions for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create policy ns_roster_ack_read on public.ns_roster_acknowledgements for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create function public.ns_publish_roster_shift(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_member uuid,p_starts timestamptz,p_ends timestamptz,p_break integer,p_tolerance integer,p_status text,p_expected_revision bigint,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ns_roster_shifts%rowtype; old public.ns_roster_shifts%rowtype; v_notification uuid; v_locale text; v_message jsonb; v_actor uuid;
begin
 if p_id is null or p_expected_revision is null or p_status not in ('published','cancelled') or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'NS_ROSTER_INVALID'; end if;
 if not public.ns_roster_can_manage(p_org,p_site,p_post,p_member) then raise exception 'NS_ROSTER_FORBIDDEN'; end if;
 v_actor:=public.ns_current_member_id(p_org);
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_member::text||':roster',0));
 select * into old from public.ns_roster_shifts where id=p_id for update;
 if found then
  if (old.org_id,old.member_id) is distinct from (p_org,p_member) or not public.ns_roster_can_manage(old.org_id,old.site_id,old.workstation_id,old.member_id) then raise exception 'NS_ROSTER_FORBIDDEN'; end if;
  if old.revision<>p_expected_revision then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
  if old.status='cancelled' then raise exception 'NS_ROSTER_CANCELLED'; end if;
  if p_status='cancelled' and (old.site_id,old.workstation_id,old.starts_at,old.ends_at,old.planned_break_minutes,old.tolerance_minutes) is distinct from (p_site,p_post,p_starts,p_ends,p_break,p_tolerance) then raise exception 'NS_ROSTER_CANCEL_CHANGE'; end if;
 else
  if p_expected_revision<>0 or p_status<>'published' then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
 end if;
 if p_starts is null or p_ends is null or p_ends<=p_starts or p_ends>p_starts+interval '24 hours' or p_break is null or p_break<0 or p_break>=extract(epoch from p_ends-p_starts)/60 or p_tolerance is null or p_tolerance not between 0 and 120 then raise exception 'NS_ROSTER_TIME_INVALID'; end if;
 if p_status='published' and exists(select 1 from public.ns_roster_shifts s where s.org_id=p_org and s.member_id=p_member and s.id<>p_id and s.status='published' and s.starts_at<p_ends and p_starts<s.ends_at) then raise exception 'NS_ROSTER_OVERLAP'; end if;
 insert into public.ns_roster_shifts(id,org_id,site_id,workstation_id,member_id,starts_at,ends_at,planned_break_minutes,tolerance_minutes,status,revision,updated_by,updated_at,change_reason)
 values(p_id,p_org,p_site,p_post,p_member,p_starts,p_ends,p_break,p_tolerance,p_status,p_expected_revision+1,v_actor,clock_timestamp(),trim(p_reason))
 on conflict(id) do update set site_id=excluded.site_id,workstation_id=excluded.workstation_id,starts_at=excluded.starts_at,ends_at=excluded.ends_at,planned_break_minutes=excluded.planned_break_minutes,tolerance_minutes=excluded.tolerance_minutes,status=excluded.status,revision=excluded.revision,updated_by=excluded.updated_by,updated_at=excluded.updated_at,change_reason=excluded.change_reason
 where ns_roster_shifts.org_id=excluded.org_id and ns_roster_shifts.member_id=excluded.member_id and ns_roster_shifts.revision=p_expected_revision
 returning * into v;
 if not found then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
 insert into public.ns_roster_revisions select v.id,v.revision,v.org_id,v.site_id,v.workstation_id,v.member_id,v.starts_at,v.ends_at,v.planned_break_minutes,v.tolerance_minutes,v.status,v.updated_by,v.updated_at,v.change_reason;
 select coalesce(m.preferred_locale,o.default_locale,'fr') into v_locale from public.ns_members m join public.ns_organizations o on o.id=m.org_id where m.id=p_member;
 v_message:=case v_locale when 'en' then jsonb_build_object('title','Work schedule updated','body','Open your schedule to review and acknowledge the latest change.')
 when 'ff-CM' then jsonb_build_object('title','Feere golle hesɗitinaama','body','Uddit feere golle maa ngam ƴeewtaade baylugol kesol.')
 else jsonb_build_object('title','Planning de service mis à jour','body','Consultez votre planning et confirmez la prise de connaissance.') end;
 v_message:=v_message||jsonb_build_object('route','/team','shift_id',p_id,'revision',v.revision);
 insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
 values(p_org,p_site,p_member,'push','staff_schedule.updated','staff-schedule:'||p_id::text||':'||v.revision::text,v_message)
 returning id into v_notification;
 -- In-app visible even without a push token. Push worker later updates the SAME inbox record.
 insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
 values(p_org,p_site,p_member,v_notification,'staff_schedule.updated',v_message,'sent',clock_timestamp());
 return jsonb_build_object('id',v.id,'revision',v.revision,'status',v.status,'notification_id',v_notification);
end $$;
create function public.ns_ack_roster_shift(p_id uuid,p_revision bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.ns_roster_shifts%rowtype;
begin
 select * into v from public.ns_roster_shifts where id=p_id for share;
 if not found or not public.ns_roster_enabled(v.org_id) or public.ns_current_member_id(v.org_id) is distinct from v.member_id then raise exception 'NS_ROSTER_FORBIDDEN'; end if;
 if v.revision is distinct from p_revision then raise exception 'NS_ROSTER_REVISION_CONFLICT'; end if;
 insert into public.ns_roster_acknowledgements(shift_id,revision,org_id,site_id,workstation_id,member_id) values(v.id,v.revision,v.org_id,v.site_id,v.workstation_id,v.member_id) on conflict do nothing;
 return jsonb_build_object('id',v.id,'revision',v.revision,'acknowledged',true);
end $$;
revoke all on function public.ns_publish_roster_shift(uuid,uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,integer,text,bigint,text),public.ns_ack_roster_shift(uuid,bigint) from public,anon,authenticated;
grant execute on function public.ns_publish_roster_shift(uuid,uuid,uuid,uuid,uuid,timestamptz,timestamptz,integer,integer,text,bigint,text),public.ns_ack_roster_shift(uuid,bigint) to authenticated;

create table public.ns_roster_clock_links(
 event_id uuid primary key references public.ns_staff_time_events(id),
 shift_id uuid not null, revision bigint not null, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 foreign key(shift_id,revision) references public.ns_roster_revisions(shift_id,revision));
alter table public.ns_roster_clock_links enable row level security;
revoke all on public.ns_roster_clock_links from public,anon,authenticated;
grant select on public.ns_roster_clock_links to authenticated;
create policy ns_roster_clock_read on public.ns_roster_clock_links for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create function public.ns_roster_link_clock() returns trigger language plpgsql security definer set search_path='' as $fn$
declare v public.ns_roster_shifts%rowtype; l public.ns_roster_clock_links%rowtype; n integer;
begin
 if not exists(select 1 from public.ns_organizations o where o.id=new.org_id and o.business_mode in ('single_site_multi_workstation','multi_site_network') and o.status='active') or new.staff_member_id is distinct from new.actor_member_id then return new; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.org_id::text||':'||new.staff_member_id::text||':roster',0));
 if new.event_type='staff_clock_in' then
  select count(*) into n from public.ns_roster_shifts s where s.org_id=new.org_id and s.site_id=new.site_id and s.member_id=new.staff_member_id and s.status='published' and (s.workstation_id is null or s.workstation_id=new.workstation_id) and new.occurred_at>=s.starts_at and new.occurred_at<s.ends_at;
  if n=1 then
   select * into v from public.ns_roster_shifts s where s.org_id=new.org_id and s.site_id=new.site_id and s.member_id=new.staff_member_id and s.status='published' and (s.workstation_id is null or s.workstation_id=new.workstation_id) and new.occurred_at>=s.starts_at and new.occurred_at<s.ends_at;
  elsif n=0 then
   select count(*) into n from public.ns_roster_shifts s where s.org_id=new.org_id and s.site_id=new.site_id and s.member_id=new.staff_member_id and s.status='published' and (s.workstation_id is null or s.workstation_id=new.workstation_id) and new.occurred_at>=s.starts_at-interval '2 hours' and new.occurred_at<s.starts_at;
   if n=1 then select * into v from public.ns_roster_shifts s where s.org_id=new.org_id and s.site_id=new.site_id and s.member_id=new.staff_member_id and s.status='published' and (s.workstation_id is null or s.workstation_id=new.workstation_id) and new.occurred_at>=s.starts_at-interval '2 hours' and new.occurred_at<s.starts_at; end if;
  end if;
  if v.id is not null then insert into public.ns_roster_clock_links values(new.id,v.id,v.revision,new.org_id,new.site_id,v.workstation_id,new.staff_member_id); end if;
 else
  select cl.* into l from public.ns_staff_time_events e join public.ns_roster_clock_links cl on cl.event_id=e.id where e.org_id=new.org_id and e.site_id=new.site_id and e.staff_member_id=new.staff_member_id and e.sequence_no=new.sequence_no-1;
  if found then insert into public.ns_roster_clock_links values(new.id,l.shift_id,l.revision,l.org_id,l.site_id,l.workstation_id,l.member_id); end if;
 end if;
 return new;
end $fn$;
revoke all on function public.ns_roster_link_clock() from public,anon,authenticated;
create trigger ns_roster_link_clock after insert on public.ns_staff_time_events for each row execute function public.ns_roster_link_clock();
create view public.ns_roster_service_comparison with (security_invoker=true) as
with paired as (
 select c.shift_id,c.revision,e.event_type,e.occurred_at,e.sequence_no,
 lead(e.event_type) over(partition by c.shift_id,c.revision order by e.sequence_no) next_type,
 lead(e.occurred_at) over(partition by c.shift_id,c.revision order by e.sequence_no) next_at
 from public.ns_roster_clock_links c join public.ns_staff_time_events e on e.id=c.event_id
), totals as (
 select shift_id,revision,min(occurred_at) filter(where event_type='staff_clock_in') actual_start,
 max(occurred_at) filter(where event_type='staff_clock_out') actual_end,
 count(*) filter(where event_type='staff_clock_in') starts_count,
 count(*) filter(where event_type='staff_clock_out') ends_count,
 coalesce(sum(extract(epoch from next_at-occurred_at)/60) filter(where event_type='staff_break_start' and next_type='staff_break_end'),0)::integer actual_break_minutes
 from paired group by shift_id,revision
)
select s.id shift_id,s.org_id,s.site_id,s.workstation_id,s.member_id,s.revision current_revision,r.revision baseline_revision,
 r.starts_at planned_start,r.ends_at planned_end,r.planned_break_minutes,r.tolerance_minutes,s.status,
 t.actual_start,t.actual_end,t.actual_break_minutes,
 case when t.actual_start is not null then greatest(0,floor(extract(epoch from t.actual_start-r.starts_at)/60)::integer) end late_minutes,
 case when t.actual_end is not null and t.starts_count=t.ends_count then greatest(0,floor(extract(epoch from r.ends_at-t.actual_end)/60)::integer) end early_departure_minutes,
 case when t.actual_end is not null and t.starts_count=t.ends_count then greatest(0,floor(extract(epoch from t.actual_end-r.ends_at)/60)::integer) end extra_minutes,
 case when t.actual_start is null and s.status='cancelled' then 'cancelled'
 when t.actual_start is null and now()>=r.ends_at then 'unmatched_review'
 when t.actual_start is null then 'awaiting_clock_in'
 when t.actual_end is null or t.starts_count<>t.ends_count then 'in_service_or_incomplete'
 when t.starts_count<>1 then 'multiple_sessions_review'
 when t.actual_start>r.starts_at+make_interval(mins=>r.tolerance_minutes) or t.actual_end<r.ends_at-make_interval(mins=>r.tolerance_minutes) or t.actual_end>r.ends_at+make_interval(mins=>r.tolerance_minutes) or abs(t.actual_break_minutes-r.planned_break_minutes)>r.tolerance_minutes then 'variance_review'
 else 'within_tolerance' end comparison_status
 from public.ns_roster_shifts s left join totals t on t.shift_id=s.id
 join public.ns_roster_revisions r on r.shift_id=s.id and r.revision=coalesce(t.revision,s.revision);
revoke all on public.ns_roster_service_comparison from public,anon,authenticated;
grant select on public.ns_roster_service_comparison to authenticated;

-- Scoped target directory: only assignable members and posts, no personal contact information.
create function public.ns_roster_targets(p_org uuid,p_site uuid)
returns table(member_id uuid,display_name text,workstation_id uuid,workstation_name text)
language sql stable security definer set search_path='' as $fn$
 select m.id,m.display_name,null::uuid,null::text
 from public.ns_members m where m.org_id=p_org and public.ns_roster_can_manage(p_org,p_site,null,m.id)
 union all
 select m.id,m.display_name,w.id,w.name
 from public.ns_members m join public.ns_workstations w on w.org_id=m.org_id and w.site_id=p_site and w.status='active'
 where m.org_id=p_org and public.ns_roster_can_manage(p_org,p_site,w.id,m.id)
 order by 2,4 nulls first
$fn$;
revoke all on function public.ns_roster_targets(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_roster_targets(uuid,uuid) to authenticated;

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

-- v12 candidate: invitation lifecycle, scope revocation and auditable meeting changes.
alter table public.ns_internal_meetings add column agenda text not null default '' check(length(agenda)<=2000),add column duration_minutes integer not null default 30 check(duration_minutes between 5 and 480);
alter table public.ns_internal_meeting_invitees add column response text not null default 'pending' check(response in ('pending','accepted','declined','tentative')),add column response_revision integer,add column responded_at timestamptz;
create table public.ns_internal_meeting_history(
 meeting_id uuid not null references public.ns_internal_meetings(id), revision integer not null, actor_member_id uuid not null,
 title text not null,scheduled_at timestamptz not null,agenda text not null,duration_minutes integer not null,status text not null,changed_at timestamptz not null default clock_timestamp(),primary key(meeting_id,revision));
alter table public.ns_internal_meeting_history enable row level security;
revoke all on public.ns_internal_meeting_history from public,anon,authenticated;
grant select on public.ns_internal_meeting_history to authenticated;
create policy ns_meeting_history_read on public.ns_internal_meeting_history for select to authenticated using(public.ns_meeting_can_read(meeting_id));
create function public.ns_meeting_scope_valid(p_org uuid,p_site uuid,p_post uuid,p_member uuid,p_manage boolean) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_members m join public.ns_member_scopes s on s.org_id=m.org_id and s.member_id=m.id
 join public.ns_sites t on t.org_id=m.org_id and t.id=p_site and t.status='active'
 where m.org_id=p_org and m.id=p_member and m.status='active'
 and (p_post is null or exists(select 1 from public.ns_workstations w where w.id=p_post and w.org_id=p_org and w.site_id=p_site and w.status='active'))
 and (case when p_manage then s.can_manage and m.role_code in ('promoter','network_manager','site_manager','workstation_manager') else (s.can_read or s.can_operate or s.can_manage) end)
 and ((s.scope_type='organization' and (not p_manage or m.role_code='promoter'))
 or (s.scope_type='site' and s.site_id=p_site and (not p_manage or m.role_code in ('promoter','network_manager','site_manager')))
 or (s.scope_type='workstation' and p_post is not null and s.site_id=p_site and s.workstation_id=p_post and (not p_manage or m.role_code='workstation_manager'))))
$f$;
revoke all on function public.ns_meeting_scope_valid(uuid,uuid,uuid,uuid,boolean) from public,anon,authenticated;
create or replace function public.ns_meeting_can_host(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and public.ns_erp_access_reason(m.org_id)<>'blocked'
 and m.host_member_id=public.ns_current_member_id(m.org_id) and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,m.host_member_id,true))
$f$;
create or replace function public.ns_meeting_can_read(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and public.ns_roster_enabled(m.org_id) and public.ns_erp_access_reason(m.org_id)<>'blocked'
 and (public.ns_meeting_can_host(m.id) or (m.host_member_id<>public.ns_current_member_id(m.org_id)
 and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,public.ns_current_member_id(m.org_id),false)
 and exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id=public.ns_current_member_id(m.org_id)))))
$f$;
create function public.ns_meeting_history_trigger() returns trigger language plpgsql security definer set search_path='' as $f$
declare i record; n uuid; msg jsonb; loc text; code text;
begin
 insert into public.ns_internal_meeting_history(meeting_id,revision,actor_member_id,title,scheduled_at,agenda,duration_minutes,status)
 values(new.id,new.revision,new.host_member_id,new.title,new.scheduled_at,new.agenda,new.duration_minutes,new.status);
 if tg_op='UPDATE' then
  if new.status='scheduled' then
   update public.ns_internal_meeting_invitees set response='pending',response_revision=null,responded_at=null,recording_consent=null,consent_at=null where meeting_id=new.id;
  end if;
  code:=case new.status when 'scheduled' then 'internal_meeting.updated' when 'open' then 'internal_meeting.opened' when 'closed' then 'internal_meeting.closed' else 'internal_meeting.cancelled' end;
  for i in select member_id from public.ns_internal_meeting_invitees where meeting_id=new.id and member_id<>new.host_member_id loop
   if public.ns_meeting_scope_valid(new.org_id,new.site_id,new.workstation_id,i.member_id,false) then
    select coalesce(preferred_locale,'fr') into loc from public.ns_members where id=i.member_id;
    msg:=case loc when 'en' then jsonb_build_object('title','Meeting update','body','Open your internal meetings to see the latest change.')
      when 'ff-CM' then jsonb_build_object('title','Dental hesɗitinaama','body','Uddit dental ngam ƴeewtaade baylugol.')
      else jsonb_build_object('title','Réunion mise à jour','body','Consultez vos réunions pour voir le changement.') end;
    msg:=msg||jsonb_build_object('meeting_id',new.id,'revision',new.revision,'route','/team');
    insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
    values(new.org_id,new.site_id,i.member_id,'push',code,'meeting:'||new.id::text||':'||i.member_id::text||':'||new.revision,msg) returning id into n;
    insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
    values(new.org_id,new.site_id,i.member_id,n,code,msg,'sent',now());
   end if;
  end loop;
 end if;
 return new;
end $f$;
revoke all on function public.ns_meeting_history_trigger() from public,anon,authenticated;
create trigger ns_meeting_history after insert or update on public.ns_internal_meetings for each row execute function public.ns_meeting_history_trigger();
create function public.ns_revise_internal_meeting(p_id uuid,p_revision integer,p_title text,p_at timestamptz,p_agenda text,p_duration integer) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype;
begin
 if not public.ns_meeting_can_host(p_id) then raise exception 'NS_MEETING_FORBIDDEN'; end if;
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if m.status<>'scheduled' or m.revision is distinct from p_revision then raise exception 'NS_MEETING_STATE_CONFLICT'; end if;
 if p_title is null or length(trim(p_title)) not between 1 and 160 or p_at is null or p_at<now()-interval '5 minutes' or p_agenda is null or length(p_agenda)>2000 or p_duration is null or p_duration not between 5 and 480 then raise exception 'NS_MEETING_INVALID'; end if;
 update public.ns_internal_meetings set title=trim(p_title),scheduled_at=p_at,agenda=trim(p_agenda),duration_minutes=p_duration,revision=revision+1 where id=p_id returning * into m;
 return jsonb_build_object('id',m.id,'revision',m.revision,'status',m.status);
end $f$;
create function public.ns_respond_meeting_invitation(p_id uuid,p_revision integer,p_response text) returns boolean language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype;
begin
 if not public.ns_meeting_can_read(p_id) or p_response is null or p_response not in ('accepted','declined','tentative') then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 select * into m from public.ns_internal_meetings where id=p_id for share;
 if m.status<>'scheduled' or m.revision is distinct from p_revision then raise exception 'NS_MEETING_STATE_CONFLICT'; end if;
 update public.ns_internal_meeting_invitees set response=p_response,response_revision=p_revision,responded_at=now()
 where meeting_id=p_id and member_id=public.ns_current_member_id(m.org_id) and member_id<>m.host_member_id;
 if not found then raise exception 'NS_MEETING_FORBIDDEN'; end if;
 return true;
end $f$;
revoke all on function public.ns_revise_internal_meeting(uuid,integer,text,timestamptz,text,integer),public.ns_respond_meeting_invitation(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.ns_revise_internal_meeting(uuid,integer,text,timestamptz,text,integer),public.ns_respond_meeting_invitation(uuid,integer,text) to authenticated;

-- Candidate only: authorization for a single opaque SFU room, never provider admin credentials.
create function public.ns_meeting_media_grant(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; actor uuid; host boolean;
begin
 if not public.ns_meeting_can_read(p_id) then raise exception 'NS_MEDIA_FORBIDDEN'; end if;
 select * into m from public.ns_internal_meetings where id=p_id;
 if m.status<>'open' then raise exception 'NS_MEDIA_NOT_OPEN'; end if;
 actor:=public.ns_current_member_id(m.org_id);host:=public.ns_meeting_can_host(p_id);
 if not host and not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id=actor and i.response<>'declined') then raise exception 'NS_MEDIA_FORBIDDEN'; end if;
 return jsonb_build_object('meeting_id',m.id,'member_id',actor,'room','ns-'||m.id::text,'host',host,'revision',m.revision);
end $f$;
revoke all on function public.ns_meeting_media_grant(uuid) from public,anon,authenticated;
grant execute on function public.ns_meeting_media_grant(uuid) to authenticated;

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

-- v14 candidate: recording authorization lifecycle only. No worker, media file or successful recording is simulated.
create table public.ns_meeting_recording_requests(
 id uuid primary key,meeting_id uuid not null references public.ns_internal_meetings(id),requested_by uuid not null,
 status text not null check(status in ('requested','cancelled','stop_requested','failed','recording','ready')),
 requested_at timestamptz not null default clock_timestamp(),stop_requested_at timestamptz,
 display_name text not null check(length(display_name) between 1 and 220),
 check(status not in ('cancelled','stop_requested') or stop_requested_at is not null));
create unique index ns_recording_active on public.ns_meeting_recording_requests(meeting_id) where status in ('requested','recording','stop_requested');
alter table public.ns_meeting_recording_requests enable row level security;
revoke all on public.ns_meeting_recording_requests from public,anon,authenticated;
grant select on public.ns_meeting_recording_requests to authenticated;
create policy ns_recording_status_read on public.ns_meeting_recording_requests for select to authenticated using(public.ns_meeting_can_read(meeting_id));
create function public.ns_meeting_recording_consent_ok(p_id uuid) returns boolean language sql stable security definer set search_path='' as $f$
 select exists(select 1 from public.ns_internal_meetings m where m.id=p_id and m.status='open'
 and exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.member_id=m.host_member_id and i.recording_consent is true)
 and not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=m.id and i.excluded_at is null and i.response<>'declined'
 and public.ns_meeting_scope_valid(m.org_id,m.site_id,m.workstation_id,i.member_id,false) and i.recording_consent is distinct from true))
$f$;
revoke all on function public.ns_meeting_recording_consent_ok(uuid) from public,anon,authenticated;
create function public.ns_request_meeting_recording(p_id uuid,p_request uuid,p_action text) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; r public.ns_meeting_recording_requests%rowtype;
begin
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if not found or not public.ns_meeting_can_host(p_id) or p_request is null or p_action is null or p_action not in ('start','stop') then raise exception 'NS_RECORDING_FORBIDDEN';end if;
 if p_action='start' then
  if m.status<>'open' or not public.ns_meeting_recording_consent_ok(p_id) then raise exception 'NS_RECORDING_CONSENT_REQUIRED';end if;
  select * into r from public.ns_meeting_recording_requests where id=p_request and meeting_id=p_id;
  if not found then
   insert into public.ns_meeting_recording_requests(id,meeting_id,requested_by,status,display_name) values(p_request,p_id,m.host_member_id,'requested',m.title||' — '||to_char(m.scheduled_at at time zone 'Africa/Douala','YYYY-MM-DD HH24-MI')) returning * into r;
  end if;
 else
  select * into r from public.ns_meeting_recording_requests where id=p_request and meeting_id=p_id for update;
  if not found then raise exception 'NS_RECORDING_FORBIDDEN';end if;
  if r.status in ('requested','recording') then
   update public.ns_meeting_recording_requests set status=case when status='requested' then 'cancelled' else 'stop_requested' end,stop_requested_at=clock_timestamp() where id=r.id returning * into r;
  end if;
 end if;
 return jsonb_build_object('id',r.id,'status',r.status,'display_name',r.display_name);
end $f$;
revoke all on function public.ns_request_meeting_recording(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ns_request_meeting_recording(uuid,uuid,text) to authenticated;
create function public.ns_recording_cancel_on_consent() returns trigger language plpgsql security definer set search_path='' as $f$
begin
 if new.recording_consent is distinct from true and old.recording_consent is true then
  update public.ns_meeting_recording_requests set status=case when status='requested' then 'cancelled' else 'stop_requested' end,stop_requested_at=clock_timestamp()
  where meeting_id=new.meeting_id and status in ('requested','recording');
 end if;
 return new;
end $f$;
revoke all on function public.ns_recording_cancel_on_consent() from public,anon,authenticated;
create trigger ns_recording_consent_guard after update of recording_consent on public.ns_internal_meeting_invitees for each row execute function public.ns_recording_cancel_on_consent();
create function public.ns_recording_cancel_on_close() returns trigger language plpgsql security definer set search_path='' as $f$
begin
 if old.status='open' and new.status<>'open' then
  update public.ns_meeting_recording_requests set status=case when status='requested' then 'cancelled' else 'stop_requested' end,stop_requested_at=clock_timestamp()
  where meeting_id=new.id and status in ('requested','recording');
 end if;
 return new;
end $f$;
revoke all on function public.ns_recording_cancel_on_close() from public,anon,authenticated;
create trigger ns_recording_close_guard after update of status on public.ns_internal_meetings for each row execute function public.ns_recording_cancel_on_close();
-- No authenticated route may mark recording/ready. Future trusted egress worker must enforce
-- current consent, active room membership, recording notice, provider receipt and private Storage object.

create function public.ns_schedule_internal_meeting_details(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_title text,p_at timestamptz,p_members uuid[],p_agenda text,p_duration integer) returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor uuid:=public.ns_current_member_id(p_org); target uuid; nid uuid; msg jsonb; loc text; existing public.ns_internal_meetings%rowtype;
begin
 if p_agenda is null or length(p_agenda)>2000 or p_duration is null or p_duration not between 5 and 480 or not public.ns_roster_enabled(p_org) or p_id is null or p_at is null or p_at<now()-interval '5 minutes' or p_title is null or length(trim(p_title)) not between 1 and 160 or coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 foreach target in array p_members loop
  if target is null or not public.ns_roster_can_manage(p_org,p_site,p_post,target) then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID'; end if;
 end loop;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id::text,0));
 select * into existing from public.ns_internal_meetings where id=p_id;
 if found then
  if existing.host_member_id is distinct from actor or not public.ns_meeting_can_host(p_id) or (existing.org_id,existing.site_id,existing.workstation_id,existing.title,existing.scheduled_at,existing.agenda,existing.duration_minutes) is distinct from (p_org,p_site,p_post,trim(p_title),p_at,trim(p_agenda),p_duration) or existing.status<>'scheduled' or existing.revision<>1 or (select array_agg(distinct i.member_id order by i.member_id) from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id<>actor) is distinct from (select array_agg(distinct x order by x) from unnest(p_members) x) then raise exception 'NS_MEETING_CREATE_CONFLICT';end if;
  return jsonb_build_object('id',p_id,'status','scheduled','revision',1,'duplicate',true);
 end if;
 insert into public.ns_internal_meetings(id,org_id,site_id,workstation_id,host_member_id,title,scheduled_at,status,agenda,duration_minutes) values(p_id,p_org,p_site,p_post,actor,trim(p_title),p_at,'scheduled',trim(p_agenda),p_duration);
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
 return jsonb_build_object('id',p_id,'status','scheduled','revision',1);
end $f$;

revoke all on function public.ns_schedule_internal_meeting_details(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer) from public,anon,authenticated;
grant execute on function public.ns_schedule_internal_meeting_details(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer) to authenticated;

-- v19: bounded recurring series; all occurrences created atomically using the qualified v18 path.
create table public.ns_meeting_series(
 id uuid primary key,org_id uuid not null,site_id uuid not null,host_member_id uuid not null,
 frequency text not null check(frequency in ('daily','weekly')),occurrence_count integer not null check(occurrence_count between 2 and 12),
 request_payload jsonb not null,created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(host_member_id,org_id) references public.ns_members(id,org_id));
alter table public.ns_meeting_series enable row level security;
revoke all on public.ns_meeting_series from public,anon,authenticated;
alter table public.ns_internal_meetings add column series_id uuid references public.ns_meeting_series(id),add column series_occurrence integer;
alter table public.ns_internal_meetings add constraint ns_meeting_series_pair check((series_id is null and series_occurrence is null) or (series_id is not null and series_occurrence between 1 and 12));
create unique index ns_meeting_series_occurrence on public.ns_internal_meetings(series_id,series_occurrence) where series_id is not null;
-- Attach series metadata at INSERT, not UPDATE: the existing revision/history trigger remains unchanged.
create function public.ns_meeting_attach_series() returns trigger language plpgsql security definer set search_path='' as $f$
declare s public.ns_meeting_series%rowtype; n integer;
begin
 for s in select * from public.ns_meeting_series where org_id=new.org_id and site_id=new.site_id and host_member_id=new.host_member_id and id::text=current_setting('ns.meeting_series_id',true) loop
  for n in 1..s.occurrence_count loop
   if new.id=md5(s.id::text||':'||n)::uuid then new.series_id:=s.id;new.series_occurrence:=n;return new;end if;
  end loop;
 end loop;
 return new;
end $f$;
revoke all on function public.ns_meeting_attach_series() from public,anon,authenticated;
create trigger ns_meeting_attach_series before insert on public.ns_internal_meetings for each row execute function public.ns_meeting_attach_series();
create function public.ns_schedule_meeting_series(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_title text,p_at timestamptz,p_members uuid[],p_agenda text,p_duration integer,p_frequency text,p_count integer) returns jsonb language plpgsql security definer set search_path='' as $f$
declare actor uuid:=public.ns_current_member_id(p_org); target uuid; n integer; s public.ns_meeting_series%rowtype; payload jsonb; ids uuid[]:='{}'; mid uuid; prior text;
begin
 if actor is null or not public.ns_roster_enabled(p_org) or p_id is null or p_frequency is null or p_frequency not in ('daily','weekly') or p_count is null or p_count not between 2 and 12 or p_at is null or p_at<now()-interval '5 minutes' or p_at>now()+interval '1 year' or p_title is null or length(trim(p_title)) not between 1 and 160 or p_agenda is null or length(p_agenda)>2000 or p_duration is null or p_duration not between 5 and 480 or coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_SERIES_INVALID';end if;
 foreach target in array p_members loop
  if target is null or not public.ns_roster_can_manage(p_org,p_site,p_post,target) then raise exception 'NS_SERIES_FORBIDDEN';end if;
 end loop;
 payload:=jsonb_build_object('org',p_org,'site',p_site,'post',p_post,'title',trim(p_title),'at',p_at,'members',(select array_agg(distinct x order by x) from unnest(p_members) x),'agenda',trim(p_agenda),'duration',p_duration,'frequency',p_frequency,'count',p_count);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id::text,0));
 select * into s from public.ns_meeting_series where id=p_id;
 if found then
  if s.host_member_id is distinct from actor or s.request_payload is distinct from payload then raise exception 'NS_SERIES_CONFLICT';end if;
  select array_agg(id order by series_occurrence) into ids from public.ns_internal_meetings where series_id=p_id;
  if coalesce(cardinality(ids),0)<>p_count then raise exception 'NS_SERIES_INCOMPLETE';end if;
  return jsonb_build_object('id',p_id,'meeting_ids',ids,'duplicate',true);
 end if;
 insert into public.ns_meeting_series(id,org_id,site_id,host_member_id,frequency,occurrence_count,request_payload) values(p_id,p_org,p_site,actor,p_frequency,p_count,payload);
 prior:=current_setting('ns.meeting_series_id',true);
 perform set_config('ns.meeting_series_id',p_id::text,true);
 for n in 1..p_count loop
  mid:=md5(p_id::text||':'||n)::uuid;
  perform public.ns_schedule_internal_meeting_details(mid,p_org,p_site,p_post,p_title,p_at+make_interval(hours=>24*(n-1)*case when p_frequency='weekly' then 7 else 1 end),p_members,p_agenda,p_duration);
  if not exists(select 1 from public.ns_internal_meetings where id=mid and series_id=p_id and series_occurrence=n) then raise exception 'NS_SERIES_LINK_FAILED';end if;
  ids:=array_append(ids,mid);
 end loop;
 perform set_config('ns.meeting_series_id',coalesce(prior,''),true);
 return jsonb_build_object('id',p_id,'meeting_ids',ids,'duplicate',false);
end $f$;
revoke all on function public.ns_schedule_meeting_series(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer,text,integer) from public,anon,authenticated;
grant execute on function public.ns_schedule_meeting_series(uuid,uuid,uuid,uuid,text,timestamptz,uuid[],text,integer,text,integer) to authenticated;
-- Atomically cancel all still-scheduled occurrences; preserve opened/closed/cancelled history.
create function public.ns_cancel_meeting_series(p_id uuid,p_expected jsonb) returns jsonb language plpgsql security definer set search_path='' as $f$
declare s public.ns_meeting_series%rowtype; m public.ns_internal_meetings%rowtype; actual jsonb; n integer:=0;
begin
 select * into s from public.ns_meeting_series where id=p_id for update;
 if not found or s.host_member_id is distinct from public.ns_current_member_id(s.org_id) or not public.ns_roster_enabled(s.org_id) then raise exception 'NS_SERIES_FORBIDDEN';end if;
 -- Lock all occurrences before validating the caller's snapshot.
 perform 1 from public.ns_internal_meetings where series_id=p_id order by id for update;
 if exists(select 1 from public.ns_internal_meetings where series_id=p_id and not public.ns_meeting_can_host(id)) then raise exception 'NS_SERIES_FORBIDDEN';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'revision',revision) order by id),'[]'::jsonb) into actual from public.ns_internal_meetings where series_id=p_id and status='scheduled';
 if jsonb_typeof(p_expected) is distinct from 'array' or jsonb_array_length(p_expected)>12 then raise exception 'NS_SERIES_STATE_CONFLICT';end if;
 if actual is distinct from (select coalesce(jsonb_agg(x order by x->>'id'),'[]'::jsonb) from jsonb_array_elements(p_expected) x) then raise exception 'NS_SERIES_STATE_CONFLICT';end if;
 for m in select * from public.ns_internal_meetings where series_id=p_id and status='scheduled' order by id loop
  perform public.ns_transition_internal_meeting(m.id,m.revision,'cancelled');n:=n+1;
 end loop;
 return jsonb_build_object('id',p_id,'cancelled_count',n);
end $f$;
revoke all on function public.ns_cancel_meeting_series(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.ns_cancel_meeting_series(uuid,jsonb) to authenticated;
-- Scheduled-only invite edits, with revision checks and a private audit of added/removed participants.
create table public.ns_meeting_invitation_changes(
 meeting_id uuid not null references public.ns_internal_meetings(id),revision integer not null,actor_member_id uuid not null,
 added uuid[] not null,removed uuid[] not null,changed_at timestamptz not null default clock_timestamp(),primary key(meeting_id,revision));
alter table public.ns_meeting_invitation_changes enable row level security;
revoke all on public.ns_meeting_invitation_changes from public,anon,authenticated;
create function public.ns_revise_meeting_invitees(p_id uuid,p_revision integer,p_title text,p_at timestamptz,p_agenda text,p_duration integer,p_members uuid[]) returns jsonb language plpgsql security definer set search_path='' as $f$
declare m public.ns_internal_meetings%rowtype; target uuid; wanted uuid[]; added uuid[]; removed uuid[]; result jsonb; loc text; msg jsonb; nid uuid;
begin
 select * into m from public.ns_internal_meetings where id=p_id for update;
 if not found or not public.ns_meeting_can_host(p_id) then raise exception 'NS_MEETING_FORBIDDEN';end if;
 if m.status<>'scheduled' or m.revision is distinct from p_revision then raise exception 'NS_MEETING_STATE_CONFLICT';end if;
 if coalesce(cardinality(p_members),0) not between 1 and 100 then raise exception 'NS_MEETING_INVALID';end if;
 foreach target in array p_members loop
  if target is null or target=m.host_member_id or not public.ns_roster_can_manage(m.org_id,m.site_id,m.workstation_id,target) then raise exception 'NS_MEETING_FORBIDDEN_OR_INVALID';end if;
 end loop;
 select array_agg(distinct x order by x) into wanted from unnest(p_members) x;
 select coalesce(array_agg(i.member_id order by i.member_id),'{}') into removed from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id<>m.host_member_id and not(i.member_id=any(wanted));
 select coalesce(array_agg(x order by x),'{}') into added from unnest(wanted) x where not exists(select 1 from public.ns_internal_meeting_invitees i where i.meeting_id=p_id and i.member_id=x);
 delete from public.ns_internal_meeting_invitees where meeting_id=p_id and member_id=any(removed);
 insert into public.ns_internal_meeting_invitees(meeting_id,org_id,member_id) select p_id,m.org_id,x from unnest(added) x;
 -- Existing revision/history trigger resets RSVP and notifies the newly selected invitees.
 result:=public.ns_revise_internal_meeting(p_id,p_revision,p_title,p_at,p_agenda,p_duration);
 insert into public.ns_meeting_invitation_changes(meeting_id,revision,actor_member_id,added,removed) values(p_id,p_revision+1,m.host_member_id,added,removed);
 foreach target in array removed loop
  select coalesce(preferred_locale,'fr') into loc from public.ns_members where id=target and org_id=m.org_id;
  msg:=case loc when 'en' then jsonb_build_object('title','Invitation withdrawn','body','Your invitation to an internal meeting was withdrawn.')
   when 'ff-CM' then jsonb_build_object('title','Noddaango momtaama','body','Noddaango maa dental momtaama.')
   else jsonb_build_object('title','Invitation retirée','body','Votre invitation à une réunion interne a été retirée.') end;
  -- No meeting title, time, link or participant list is disclosed to a removed member.
  insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted)
    values(m.org_id,m.site_id,target,'push','internal_meeting.invitation_withdrawn','meeting-withdrawn:'||p_id::text||':'||target::text||':'||(p_revision+1),msg) returning id into nid;
  insert into public.ns_notification_inbox(org_id,site_id,member_id,notification_id,event_code,payload_redacted,status,sent_at)
    values(m.org_id,m.site_id,target,nid,'internal_meeting.invitation_withdrawn',msg,'sent',now());
 end loop;
 return result||jsonb_build_object('added_count',cardinality(added),'removed_count',cardinality(removed));
end $f$;
revoke all on function public.ns_revise_meeting_invitees(uuid,integer,text,timestamptz,text,integer,uuid[]) from public,anon,authenticated;
grant execute on function public.ns_revise_meeting_invitees(uuid,integer,text,timestamptz,text,integer,uuid[]) to authenticated;



insert into auth.users(id) values ('10000000-0000-4000-8000-000000000091'),('10000000-0000-4000-8000-000000000092');
insert into public.ns_organizations(id,display_name,business_mode) values ('20000000-0000-4000-8000-000000000091','QA Attendance','multi_site_network');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000091','10000000-0000-4000-8000-000000000091','NS-QA91','qa91@example.invalid',false),('50000000-0000-4000-8000-000000000092','10000000-0000-4000-8000-000000000092','NS-QA92','qa92@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000091','QA Manager','site_manager'),('60000000-0000-4000-8000-000000000092','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000092','QA Staff','cashier');
insert into public.ns_sites(id,org_id,code,name) values ('30000000-0000-4000-8000-000000000091','20000000-0000-4000-8000-000000000091','QA91','QA Site');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000091','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,true),('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000092','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,false);
insert into public.ns_devices(account_id,installation_id,platform,label,session_id) values ('50000000-0000-4000-8000-000000000091','qa-91','web','QA','qa-91-session'),('50000000-0000-4000-8000-000000000092','qa-92','web','QA','qa-92-session');

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $$ declare o uuid:='20000000-0000-4000-8000-000000000091'; s uuid:='30000000-0000-4000-8000-000000000091'; u uuid:='60000000-0000-4000-8000-000000000092'; x uuid:='70000000-0000-4000-8000-000000000095'; y uuid:='70000000-0000-4000-8000-000000000096'; t timestamptz:=now()+interval '1 day'; v jsonb;
begin
 if not public.ns_roster_enabled(o) or not public.ns_roster_can_manage(o,s,null,u) then raise exception 'QA MANAGER SCOPE'; end if;
 if (select count(*) from public.ns_roster_targets(o,s) where member_id=u and workstation_id is null)<>1 then raise exception 'QA TARGET DIRECTORY'; end if;
 if exists(select 1 from public.ns_roster_targets(o,s) where member_id='60000000-0000-4000-8000-000000000091') then raise exception 'QA SELF DIRECTORY'; end if;
 if public.ns_roster_can_manage(o,s,null,'60000000-0000-4000-8000-000000000091') then raise exception 'QA SELF MANAGEMENT'; end if;
 v:=public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '8 hours',30,10,'published',0,'Initial');
 if v->>'revision'<>'1' then raise exception 'QA INITIAL REVISION'; end if;
 begin perform public.ns_publish_roster_shift(y,o,s,null,u,t+interval '1 hour',t+interval '2 hours',0,10,'published',0,'Overlap'); raise exception 'QA OVERLAP ACCEPTED'; exception when others then if sqlerrm not like '%NS_ROSTER_OVERLAP%' then raise; end if; end;
 begin perform public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '7 hours',30,10,'published',0,'Stale'); raise exception 'QA STALE ACCEPTED'; exception when others then if sqlerrm not like '%NS_ROSTER_REVISION_CONFLICT%' then raise; end if; end;
 v:=public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '7 hours',30,10,'published',1,'Updated hours');
 if v->>'revision'<>'2' then raise exception 'QA UPDATE'; end if;
 if (select count(*) from public.ns_roster_revisions where shift_id=x)<>2 then raise exception 'QA HISTORY'; end if;
 begin perform public.ns_ack_roster_shift(x,2); raise exception 'QA MANAGER ACK'; exception when others then if sqlerrm not like '%NS_ROSTER_FORBIDDEN%' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $$ declare o uuid:='20000000-0000-4000-8000-000000000091'; s uuid:='30000000-0000-4000-8000-000000000091'; u uuid:='60000000-0000-4000-8000-000000000092'; x uuid:='70000000-0000-4000-8000-000000000095'; t timestamptz:=now()+interval '1 day';
begin
 if (select count(*) from public.ns_roster_shifts where id=x and revision=2)<>1 then raise exception 'QA PERSONAL READ'; end if;
 if exists(select 1 from public.ns_roster_targets(o,s)) then raise exception 'QA STAFF DIRECTORY'; end if;
 begin perform public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '7 hours',30,10,'published',2,'Employee'); raise exception 'QA EMPLOYEE WRITE'; exception when others then if sqlerrm not like '%NS_ROSTER_FORBIDDEN%' then raise; end if; end;
 begin perform public.ns_ack_roster_shift(x,1); raise exception 'QA OLD ACK'; exception when others then if sqlerrm not like '%NS_ROSTER_REVISION_CONFLICT%' then raise; end if; end;
 perform public.ns_ack_roster_shift(x,2); perform public.ns_ack_roster_shift(x,2);
 if (select count(*) from public.ns_roster_acknowledgements where shift_id=x and revision=2)<>1 then raise exception 'QA ACK IDEMPOTENCE'; end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.ns_notification_outbox where org_id='20000000-0000-4000-8000-000000000091' and recipient_member_id='60000000-0000-4000-8000-000000000092' and event_code='staff_schedule.updated' and status='pending')<>2 then raise exception 'QA PUSH QUEUE'; end if;
 if (select count(*) from public.ns_notification_inbox where org_id='20000000-0000-4000-8000-000000000091' and member_id='60000000-0000-4000-8000-000000000092' and event_code='staff_schedule.updated')<>2 then raise exception 'QA INBOX'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
do $qa$ declare s public.ns_roster_shifts%rowtype; t timestamptz; begin
 select * into s from public.ns_roster_shifts where id='70000000-0000-4000-8000-000000000095'; t:=s.starts_at+interval '20 minutes';
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000097',s.org_id,s.site_id,null,s.member_id,'QA Staff','staff_clock_in',t);
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000098',s.org_id,s.site_id,null,s.member_id,'QA Staff','staff_break_start',t+interval '2 hours');
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000099',s.org_id,s.site_id,null,s.member_id,'QA Staff','staff_break_end',t+interval '2 hours 30 minutes');
 perform public.ns_record_staff_time_event('70000000-0000-4000-8000-000000000100',s.org_id,s.site_id,null,s.member_id,'QA Staff','staff_clock_out',s.ends_at-interval '15 minutes');
end $qa$;
set local role authenticated;
do $qa$ begin
 if not exists(select 1 from public.ns_roster_service_comparison where shift_id='70000000-0000-4000-8000-000000000095' and baseline_revision=2 and late_minutes=20 and early_departure_minutes=15 and actual_break_minutes=30 and comparison_status='variance_review') then raise exception 'QA COMPARISON'; end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare s public.ns_roster_shifts%rowtype; begin
 select * into s from public.ns_roster_shifts where id='70000000-0000-4000-8000-000000000095';
 perform public.ns_publish_roster_shift(s.id,s.org_id,s.site_id,s.workstation_id,s.member_id,s.starts_at+interval '20 minutes',s.ends_at,s.planned_break_minutes,s.tolerance_minutes,'published',2,'Post-clock revision');
 if not exists(select 1 from public.ns_roster_service_comparison where shift_id=s.id and current_revision=3 and baseline_revision=2 and late_minutes=20) then raise exception 'QA BASELINE REWRITTEN'; end if;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare v jsonb; begin
 v:=public.ns_schedule_internal_meeting('70000000-0000-4000-8000-000000000105','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'QA meeting',now()+interval '1 hour',array['60000000-0000-4000-8000-000000000092'::uuid]);
 if v->>'status'<>'scheduled' then raise exception 'QA SCHEDULE'; end if;
 begin perform public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000105');raise exception 'QA PREOPEN MEDIA';exception when others then if sqlerrm not like '%NS_MEDIA_NOT_OPEN%' then raise;end if;end;
 v:=public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000105',1,'open');
 if v->>'status'<>'open' then raise exception 'QA OPEN'; end if;
 v:=public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000105');
 if v->>'host'<>'true' or v->>'room'<>'ns-70000000-0000-4000-8000-000000000105' then raise exception 'QA HOST MEDIA GRANT';end if;
 v:=public.ns_daily_briefing('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',(now() at time zone 'Africa/Douala')::date);
 if v->>'scope'<>'site' then raise exception 'QA SITE REPORT'; end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare v jsonb; begin
 if not exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000105') then raise exception 'QA INVITED READ'; end if;
 v:=public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000105');
 if v->>'host'<>'false' or v->>'member_id'<>'60000000-0000-4000-8000-000000000092' then raise exception 'QA STAFF MEDIA GRANT'; end if;
 begin perform public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000199');raise exception 'QA NONINVITED MEDIA';exception when others then if sqlerrm not like '%NS_MEDIA_FORBIDDEN%' then raise;end if;end;
 begin perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000105',2,'closed'); raise exception 'QA EMPLOYEE CLOSED'; exception when others then if sqlerrm not like '%NS_MEETING_FORBIDDEN%' then raise; end if; end;
 if not public.ns_set_meeting_listener('70000000-0000-4000-8000-000000000105','it',true) or not public.ns_set_meeting_listener('70000000-0000-4000-8000-000000000105','ff-CM',false) then raise exception 'QA LANGUAGE'; end if;
 if not exists(select 1 from public.ns_internal_meeting_invitees where meeting_id='70000000-0000-4000-8000-000000000105' and member_id='60000000-0000-4000-8000-000000000092' and listening_locale='ff-CM' and recording_consent=false) then raise exception 'QA PERSONAL SETTINGS'; end if;
 v:=public.ns_daily_briefing('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',(now() at time zone 'Africa/Douala')::date);
 if v->>'scope'<>'personal' or v->'finance'<>'null'::jsonb then raise exception 'QA REPORT LEAK'; end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000105',2,'closed');
 if not exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000105' and status='closed') then raise exception 'QA HOST CLOSE'; end if;
 begin perform public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000105');raise exception 'QA CLOSED MEDIA';exception when others then if sqlerrm not like '%NS_MEDIA_NOT_OPEN%' then raise;end if;end;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_schedule_internal_meeting('70000000-0000-4000-8000-000000000106','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'QA planning',now()+interval '1 hour',array['60000000-0000-4000-8000-000000000092'::uuid]);
 if (select count(*) from public.ns_internal_meeting_history where meeting_id='70000000-0000-4000-8000-000000000106')<>1 then raise exception 'QA INITIAL HISTORY'; end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if not public.ns_respond_meeting_invitation('70000000-0000-4000-8000-000000000106',1,'accepted') then raise exception 'QA RSVP'; end if;
 begin perform public.ns_revise_internal_meeting('70000000-0000-4000-8000-000000000106',1,'Hijack',now()+interval '2 hours','',30);raise exception 'QA UNAUTHORIZED REVISE';exception when others then if sqlerrm not like '%NS_MEETING_FORBIDDEN%' then raise;end if;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_revise_internal_meeting('70000000-0000-4000-8000-000000000106',1,'Updated',now()+interval '2 hours','Agenda',45);
 if not exists(select 1 from public.ns_internal_meeting_invitees where meeting_id='70000000-0000-4000-8000-000000000106' and member_id='60000000-0000-4000-8000-000000000092' and response='pending') then raise exception 'QA RSVP RESET';end if;
 if (select count(*) from public.ns_internal_meeting_history where meeting_id='70000000-0000-4000-8000-000000000106')<>2 then raise exception 'QA REVISED HISTORY';end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 begin perform public.ns_respond_meeting_invitation('70000000-0000-4000-8000-000000000106',1,'accepted');raise exception 'QA STALE RSVP';exception when others then if sqlerrm not like '%NS_MEETING_STATE_CONFLICT%' then raise;end if;end;
 perform public.ns_respond_meeting_invitation('70000000-0000-4000-8000-000000000106',2,'tentative');
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_notification_inbox where event_code='internal_meeting.updated' and payload_redacted->>'meeting_id'='70000000-0000-4000-8000-000000000106')<>1 then raise exception 'QA UPDATE NOTIFICATION';end if;
end $qa$;
update public.ns_member_scopes set can_read=false,can_operate=false,can_manage=false where member_id='60000000-0000-4000-8000-000000000092';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000106') then raise exception 'QA REVOKED SCOPE';end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000106',2,'cancelled');
 if not exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000106' and status='cancelled') then raise exception 'QA HOST CANCEL';end if;
end $qa$;
reset role;
update public.ns_member_scopes set can_read=true,can_operate=true where member_id='60000000-0000-4000-8000-000000000092';

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_schedule_internal_meeting('70000000-0000-4000-8000-000000000107','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'QA interactions',now(),array['60000000-0000-4000-8000-000000000092'::uuid]);
 begin perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000108','chat','early');raise exception 'QA PREOPEN CHAT';exception when others then if sqlerrm not like '%NS_MEETING_INTERACTION_FORBIDDEN%' then raise;end if;end;
 perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000107',1,'open');
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare n integer; begin
 perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107',null,'raise_hand');
 perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000108','chat','Hello');
 perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000108','chat','Hello');
 perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000109','reaction','clap');
 if (select count(*) from public.ns_meeting_chat where meeting_id='70000000-0000-4000-8000-000000000107')<>1 then raise exception 'QA CHAT IDEMPOTENCE';end if;
 for n in 1..4 loop perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107',('70000000-0000-4000-8000-00000000013'||n)::uuid,'chat','Rate fixture '||n);end loop;
 begin perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000139','chat','Rate limit');raise exception 'QA RATE NOT ENFORCED';exception when others then if sqlerrm not like '%NS_MEETING_RATE_LIMIT%' then raise;end if;end;
 begin perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000140','reaction','invalid');raise exception 'QA INVALID REACTION';exception when others then if sqlerrm not like '%NS_MEETING_REACTION_INVALID%' then raise;end if;end;

 if not exists(select 1 from public.ns_meeting_participants('70000000-0000-4000-8000-000000000107') where member_id='60000000-0000-4000-8000-000000000092' and hand_raised_at is not null) then raise exception 'QA HAND';end if;
 begin perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000110','60000000-0000-4000-8000-000000000092','allow_screen');raise exception 'QA STAFF MODERATION';exception when others then if sqlerrm not like '%NS_MEETING_MODERATION_FORBIDDEN%' then raise;end if;end;
 begin insert into public.ns_meeting_chat values('70000000-0000-4000-8000-000000000111','70000000-0000-4000-8000-000000000107','60000000-0000-4000-8000-000000000092','direct',now());raise exception 'QA DIRECT WRITE';exception when insufficient_privilege then null;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000110','60000000-0000-4000-8000-000000000092','allow_screen');
 perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000112','60000000-0000-4000-8000-000000000092','mute');
 perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000113','60000000-0000-4000-8000-000000000092','lower_hand');
 perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000114','60000000-0000-4000-8000-000000000092','deny_chat');
 if (select count(*) from public.ns_meeting_moderation where meeting_id='70000000-0000-4000-8000-000000000107')<>4 then raise exception 'QA MODERATION HISTORY';end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare g jsonb;begin
 g:=public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000107');
 if g->>'screen_allowed'<>'true' or g->>'microphone_allowed'<>'false' then raise exception 'QA MEDIA PERMISSIONS';end if;
 if exists(select 1 from public.ns_meeting_participants('70000000-0000-4000-8000-000000000107') where member_id='60000000-0000-4000-8000-000000000092' and hand_raised_at is not null) then raise exception 'QA HAND LOWER';end if;
 begin perform public.ns_meeting_action('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000115','chat','blocked');raise exception 'QA BLOCKED CHAT';exception when others then if sqlerrm not like '%NS_MEETING_CHAT_FORBIDDEN%' then raise;end if;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000116','60000000-0000-4000-8000-000000000092','exclude');
 perform public.ns_moderate_meeting('70000000-0000-4000-8000-000000000107','70000000-0000-4000-8000-000000000116','60000000-0000-4000-8000-000000000092','exclude');
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000107') or exists(select 1 from public.ns_meeting_chat where meeting_id='70000000-0000-4000-8000-000000000107') or exists(select 1 from public.ns_meeting_participants('70000000-0000-4000-8000-000000000107')) then raise exception 'QA EXCLUDED READ';end if;
 begin perform public.ns_meeting_media_grant('70000000-0000-4000-8000-000000000107');raise exception 'QA EXCLUDED MEDIA';exception when others then if sqlerrm not like '%NS_MEDIA_FORBIDDEN%' then raise;end if;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000107',2,'closed');
 if exists(select 1 from public.ns_meeting_chat where meeting_id='70000000-0000-4000-8000-000000000107') then raise exception 'QA CLOSED CHAT';end if;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_schedule_internal_meeting('70000000-0000-4000-8000-000000000120','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'QA audio',now(),array['60000000-0000-4000-8000-000000000092'::uuid]);
 perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000120',1,'open');
 begin perform public.ns_request_meeting_recording('70000000-0000-4000-8000-000000000120','70000000-0000-4000-8000-000000000121','start');raise exception 'QA NO CONSENT';exception when others then if sqlerrm not like '%NS_RECORDING_CONSENT_REQUIRED%' then raise;end if;end;
 perform public.ns_set_meeting_listener('70000000-0000-4000-8000-000000000120','fr',true);
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_set_meeting_listener('70000000-0000-4000-8000-000000000120','en',true);
 begin perform public.ns_request_meeting_recording('70000000-0000-4000-8000-000000000120','70000000-0000-4000-8000-000000000121','start');raise exception 'QA EMPLOYEE RECORD';exception when others then if sqlerrm not like '%NS_RECORDING_FORBIDDEN%' then raise;end if;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare v jsonb;begin
 v:=public.ns_request_meeting_recording('70000000-0000-4000-8000-000000000120','70000000-0000-4000-8000-000000000121','start');
 if v->>'status'<>'requested' or v->>'display_name' not like 'QA audio — %' then raise exception 'QA REQUEST NAME';end if;
 perform public.ns_request_meeting_recording('70000000-0000-4000-8000-000000000120','70000000-0000-4000-8000-000000000121','start');
 if (select count(*) from public.ns_meeting_recording_requests where meeting_id='70000000-0000-4000-8000-000000000120')<>1 then raise exception 'QA REQUEST IDEMPOTENCE';end if;
 begin update public.ns_meeting_recording_requests set status='ready' where id='70000000-0000-4000-8000-000000000121';raise exception 'QA FORGED READY';exception when insufficient_privilege then null;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if not exists(select 1 from public.ns_meeting_recording_requests where id='70000000-0000-4000-8000-000000000121' and status='requested') then raise exception 'QA VISIBLE REQUEST';end if;
 perform public.ns_set_meeting_listener('70000000-0000-4000-8000-000000000120','en',false);
 if not exists(select 1 from public.ns_meeting_recording_requests where id='70000000-0000-4000-8000-000000000121' and status='cancelled') then raise exception 'QA WITHDRAW CONSENT';end if;
 perform public.ns_set_meeting_listener('70000000-0000-4000-8000-000000000120','en',true);
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 perform public.ns_request_meeting_recording('70000000-0000-4000-8000-000000000120','70000000-0000-4000-8000-000000000122','start');
 perform public.ns_transition_internal_meeting('70000000-0000-4000-8000-000000000120',2,'closed');
 if not exists(select 1 from public.ns_meeting_recording_requests where id='70000000-0000-4000-8000-000000000122' and status='cancelled') then raise exception 'QA CLOSE CANCEL';end if;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare t timestamptz:=now()+interval '1 hour'; r jsonb;begin
 r:=public.ns_schedule_internal_meeting_details('70000000-0000-4000-8000-000000000210','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Coordination',t,array['60000000-0000-4000-8000-000000000092'::uuid],'Objectifs et service',45);
 if r->>'revision'<>'1' then raise exception 'QA CREATE REV';end if;
 if not exists(select 1 from public.ns_internal_meeting_history where meeting_id='70000000-0000-4000-8000-000000000210' and revision=1 and agenda='Objectifs et service' and duration_minutes=45) then raise exception 'QA INITIAL HISTORY';end if;
 r:=public.ns_schedule_internal_meeting_details('70000000-0000-4000-8000-000000000210','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Coordination',t,array['60000000-0000-4000-8000-000000000092'::uuid],'Objectifs et service',45);
 if r->>'duplicate'<>'true' then raise exception 'QA CREATE REPLAY';end if;
 begin perform public.ns_schedule_internal_meeting_details('70000000-0000-4000-8000-000000000210','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Coordination',t,array['60000000-0000-4000-8000-000000000092'::uuid],'Different',45);raise exception 'QA CHANGED CREATE';exception when others then if sqlerrm not like '%NS_MEETING_CREATE_CONFLICT%' then raise;end if;end;
 begin perform public.ns_schedule_internal_meeting_details('70000000-0000-4000-8000-000000000211','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Invalid',t,array['60000000-0000-4000-8000-000000000092'::uuid],'',481);raise exception 'QA INVALID DURATION';exception when others then if sqlerrm not like '%NS_MEETING_FORBIDDEN_OR_INVALID%' then raise;end if;end;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_notification_outbox where event_code='internal_meeting.invited' and payload_redacted->>'meeting_id'='70000000-0000-4000-8000-000000000210')<>1 then raise exception 'QA DUPLICATE INVITE';end if;
end $qa$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if not exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000210' and agenda='Objectifs et service' and duration_minutes=45) then raise exception 'QA INVITE DETAILS';end if;
 begin perform public.ns_schedule_internal_meeting_details('70000000-0000-4000-8000-000000000212','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Unauthorized',now(),array['60000000-0000-4000-8000-000000000091'::uuid],'',30);raise exception 'QA STAFF CREATE';exception when others then if sqlerrm not like '%NS_MEETING_FORBIDDEN_OR_INVALID%' then raise;end if;end;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare a timestamptz:=now()+interval '1 day';v jsonb;mid uuid;begin
 v:=public.ns_schedule_meeting_series('70000000-0000-4000-8000-000000000230','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Hebdomadaire',a,array['60000000-0000-4000-8000-000000000092'::uuid],'Objectifs',45,'weekly',3);
 if jsonb_array_length(v->'meeting_ids')<>3 or v->>'duplicate'<>'false' then raise exception 'QA SERIES CREATE';end if;
 if (select count(*) from public.ns_internal_meetings where series_id='70000000-0000-4000-8000-000000000230' and scheduled_at=a+make_interval(hours=>168*(series_occurrence-1)) and revision=1 and duration_minutes=45)<>3 then raise exception 'QA SERIES CADENCE';end if;
 v:=public.ns_schedule_meeting_series('70000000-0000-4000-8000-000000000230','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Hebdomadaire',a,array['60000000-0000-4000-8000-000000000092'::uuid],'Objectifs',45,'weekly',3);
 if v->>'duplicate'<>'true' then raise exception 'QA SERIES REPLAY';end if;
 begin perform public.ns_schedule_meeting_series('70000000-0000-4000-8000-000000000230','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Hebdomadaire',a,array['60000000-0000-4000-8000-000000000092'::uuid],'Different',45,'weekly',3);raise exception 'QA SERIES CONFLICT';exception when others then if sqlerrm not like '%NS_SERIES_CONFLICT%' then raise;end if;end;
 begin perform public.ns_schedule_meeting_series('70000000-0000-4000-8000-000000000231','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Invalid',a,array['60000000-0000-4000-8000-000000000092'::uuid],'',45,'daily',13);raise exception 'QA SERIES LIMIT';exception when others then if sqlerrm not like '%NS_SERIES_INVALID%' then raise;end if;end;
 mid:=(v->'meeting_ids'->>1)::uuid;
 perform public.ns_transition_internal_meeting(mid,1,'cancelled');
 if (select count(*) from public.ns_internal_meetings where series_id='70000000-0000-4000-8000-000000000230' and status='scheduled')<>2 then raise exception 'QA SERIES CANCEL INDIVIDUAL';end if;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_notification_outbox n join public.ns_internal_meetings m on n.payload_redacted->>'meeting_id'=m.id::text where m.series_id='70000000-0000-4000-8000-000000000230' and n.event_code='internal_meeting.invited')<>3 then raise exception 'QA SERIES INVITATION COUNT';end if;
end $qa$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if (select count(*) from public.ns_internal_meetings where series_id='70000000-0000-4000-8000-000000000230')<>3 then raise exception 'QA SERIES INVITEE';end if;
 begin perform public.ns_schedule_meeting_series('70000000-0000-4000-8000-000000000232','20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'Unauthorized',now()+interval '1 day',array['60000000-0000-4000-8000-000000000091'::uuid],'',30,'daily',2);raise exception 'QA SERIES STAFF';exception when others then if sqlerrm not like '%NS_SERIES_FORBIDDEN%' then raise;end if;end;
 begin perform 1 from public.ns_meeting_series;raise exception 'QA SERIES PRIVATE';exception when insufficient_privilege then null;end;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 begin perform public.ns_cancel_meeting_series('70000000-0000-4000-8000-000000000230','[]');raise exception 'QA STAFF SERIES CANCEL';exception when others then if sqlerrm not like '%NS_SERIES_FORBIDDEN%' then raise;end if;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare expected jsonb;r jsonb;begin
 begin perform public.ns_cancel_meeting_series('70000000-0000-4000-8000-000000000230','[]');raise exception 'QA STALE SERIES CANCEL';exception when others then if sqlerrm not like '%NS_SERIES_STATE_CONFLICT%' then raise;end if;end;
 select jsonb_agg(jsonb_build_object('id',id,'revision',revision)) into expected from public.ns_internal_meetings where series_id='70000000-0000-4000-8000-000000000230' and status='scheduled';
 r:=public.ns_cancel_meeting_series('70000000-0000-4000-8000-000000000230',expected);
 if r->>'cancelled_count'<>'2' or (select count(*) from public.ns_internal_meetings where series_id='70000000-0000-4000-8000-000000000230' and status='cancelled' and revision=2)<>3 then raise exception 'QA SERIES CANCEL ALL';end if;
 r:=public.ns_cancel_meeting_series('70000000-0000-4000-8000-000000000230','[]');
 if r->>'cancelled_count'<>'0' then raise exception 'QA SERIES CANCEL EMPTY';end if;
end $qa$;
reset role;

-- A third, newly eligible employee is introduced only after prior directory assertions.
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000093');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000093','10000000-0000-4000-8000-000000000093','NS-QA93','qa93@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000093','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000093','QA Replacement','cashier');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000093','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,false);
insert into public.ns_devices(account_id,installation_id,platform,label,session_id) values ('50000000-0000-4000-8000-000000000093','qa-93','web','QA','qa-93-session');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true);select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare r jsonb;t timestamptz:=now()+interval '1 day';begin
 begin perform public.ns_revise_meeting_invitees('70000000-0000-4000-8000-000000000210',0,'Stale',t,'',30,array['60000000-0000-4000-8000-000000000093'::uuid]);raise exception 'QA STALE INVITE';exception when others then if sqlerrm not like '%NS_MEETING_STATE_CONFLICT%' then raise;end if;end;
 begin perform public.ns_revise_meeting_invitees('70000000-0000-4000-8000-000000000210',1,'Invalid',t,'',30,array['60000000-0000-4000-8000-000000000091'::uuid]);raise exception 'QA SELF INVITE';exception when others then if sqlerrm not like '%NS_MEETING_FORBIDDEN_OR_INVALID%' then raise;end if;end;
 r:=public.ns_revise_meeting_invitees('70000000-0000-4000-8000-000000000210',1,'Coordination updated',t,'New agenda',40,array['60000000-0000-4000-8000-000000000093'::uuid]);
 if r->>'added_count'<>'1' or r->>'removed_count'<>'1' or r->>'revision'<>'2' then raise exception 'QA INVITATION REVISION';end if;
end $qa$;
reset role;
do $qa$ begin
 if not exists(select 1 from public.ns_meeting_invitation_changes where meeting_id='70000000-0000-4000-8000-000000000210' and revision=2 and added=array['60000000-0000-4000-8000-000000000093'::uuid] and removed=array['60000000-0000-4000-8000-000000000092'::uuid]) then raise exception 'QA INVITATION AUDIT';end if;
 if (select count(*) from public.ns_notification_outbox where event_code='internal_meeting.invitation_withdrawn' and recipient_member_id='60000000-0000-4000-8000-000000000092' and not(payload_redacted?'meeting_id'))<>1 then raise exception 'QA WITHDRAWAL NOTICE';end if;
end $qa$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true);select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000210') then raise exception 'QA REMOVED READ';end if;
 begin perform public.ns_revise_meeting_invitees('70000000-0000-4000-8000-000000000210',2,'Unauthorized',now()+interval '1 day','',30,array['60000000-0000-4000-8000-000000000093'::uuid]);raise exception 'QA STAFF INVITE EDIT';exception when others then if sqlerrm not like '%NS_MEETING_FORBIDDEN%' then raise;end if;end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000093',true);select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000093","session_id":"qa-93-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ begin
 if not exists(select 1 from public.ns_internal_meetings where id='70000000-0000-4000-8000-000000000210' and revision=2 and agenda='New agenda') then raise exception 'QA NEW INVITEE READ';end if;
end $qa$;
reset role;

update public.ns_organizations set business_mode='solo' where id='20000000-0000-4000-8000-000000000091';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.ns_internal_meetings) then raise exception 'QA SOLO MEETING'; end if;
 if public.ns_roster_enabled('20000000-0000-4000-8000-000000000091') or exists(select 1 from public.ns_roster_shifts where id='70000000-0000-4000-8000-000000000095') then raise exception 'QA SOLO READ'; end if;
 if public.ns_roster_can_manage('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'60000000-0000-4000-8000-000000000092') then raise exception 'QA SOLO MANAGE'; end if;
end $$;
reset role;

rollback;
select 'PASS: recurring meetings, atomic series cancellation, scoped invitation replacement and revocation' as result;