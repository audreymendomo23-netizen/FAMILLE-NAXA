begin;
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

-- A justification and a decision are independent of the immutable clock and planning history.
create table public.ns_roster_justifications(
 shift_id uuid not null, baseline_revision bigint not null, org_id uuid not null, site_id uuid not null,
 workstation_id uuid, member_id uuid not null, explanation text not null check(length(trim(explanation)) between 1 and 1000),
 submitted_at timestamptz not null default clock_timestamp(),
 decision text check(decision in ('accepted','rejected')), decision_reason text,
 decided_by uuid, decided_at timestamptz,
 primary key(shift_id,baseline_revision),
 foreign key(shift_id,baseline_revision) references public.ns_roster_revisions(shift_id,revision),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 foreign key(decided_by,org_id) references public.ns_members(id,org_id),
 check((decision is null and decision_reason is null and decided_by is null and decided_at is null)
    or (decision is not null and decision_reason is not null and length(trim(decision_reason)) between 1 and 1000 and decided_by is not null and decided_at is not null)));
alter table public.ns_roster_justifications enable row level security;
revoke all on public.ns_roster_justifications from public,anon,authenticated;
grant select on public.ns_roster_justifications to authenticated;
create policy ns_roster_justification_read on public.ns_roster_justifications for select to authenticated
 using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));

create function public.ns_submit_roster_justification(p_shift uuid,p_revision bigint,p_explanation text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare r public.ns_roster_revisions%rowtype; j public.ns_roster_justifications%rowtype;
begin
 select * into r from public.ns_roster_revisions where shift_id=p_shift and revision=p_revision;
 if not found or not public.ns_roster_enabled(r.org_id) or public.ns_current_member_id(r.org_id) is distinct from r.member_id
 or public.ns_erp_access_reason(r.org_id)='blocked' then raise exception 'NS_ROSTER_JUSTIFICATION_FORBIDDEN'; end if;
 if p_explanation is null or length(trim(p_explanation)) not between 1 and 1000 then raise exception 'NS_ROSTER_JUSTIFICATION_INVALID'; end if;
 perform pg_advisory_xact_lock(hashtextextended(r.org_id::text||':'||r.member_id::text||':roster',0));
 select * into j from public.ns_roster_justifications where shift_id=p_shift and baseline_revision=p_revision;
 if found then
  if j.explanation is distinct from trim(p_explanation) then raise exception 'NS_ROSTER_JUSTIFICATION_CONFLICT'; end if;
 else
  if not exists(select 1 from public.ns_roster_service_comparison c where c.shift_id=p_shift and c.baseline_revision=p_revision
      and c.comparison_status in ('variance_review','unmatched_review','multiple_sessions_review')) then raise exception 'NS_ROSTER_JUSTIFICATION_NOT_REVIEWABLE'; end if;
  insert into public.ns_roster_justifications(shift_id,baseline_revision,org_id,site_id,workstation_id,member_id,explanation)
   values(p_shift,p_revision,r.org_id,r.site_id,r.workstation_id,r.member_id,trim(p_explanation)) returning * into j;
 end if;
 return jsonb_build_object('shift_id',j.shift_id,'baseline_revision',j.baseline_revision,'submitted',true,'decision',j.decision);
end $fn$;
create function public.ns_decide_roster_justification(p_shift uuid,p_revision bigint,p_decision text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare j public.ns_roster_justifications%rowtype; actor uuid;
begin
 select * into j from public.ns_roster_justifications where shift_id=p_shift and baseline_revision=p_revision for update;
 if not found or not public.ns_roster_can_manage(j.org_id,j.site_id,j.workstation_id,j.member_id) then raise exception 'NS_ROSTER_JUSTIFICATION_FORBIDDEN'; end if;
 actor:=public.ns_current_member_id(j.org_id);
 if p_decision is null or p_decision not in ('accepted','rejected') or p_reason is null or length(trim(p_reason)) not between 1 and 1000 then raise exception 'NS_ROSTER_JUSTIFICATION_INVALID'; end if;
 if j.decision is not null then
  if (j.decision,j.decision_reason,j.decided_by) is distinct from (p_decision,trim(p_reason),actor) then raise exception 'NS_ROSTER_JUSTIFICATION_CONFLICT'; end if;
 else
  update public.ns_roster_justifications set decision=p_decision,decision_reason=trim(p_reason),decided_by=actor,decided_at=clock_timestamp()
   where shift_id=p_shift and baseline_revision=p_revision returning * into j;
 end if;
 return jsonb_build_object('shift_id',j.shift_id,'baseline_revision',j.baseline_revision,'decision',j.decision);
end $fn$;
revoke all on function public.ns_submit_roster_justification(uuid,bigint,text),public.ns_decide_roster_justification(uuid,bigint,text,text) from public,anon,authenticated;
grant execute on function public.ns_submit_roster_justification(uuid,bigint,text),public.ns_decide_roster_justification(uuid,bigint,text,text) to authenticated;

-- B1 operational extensions: scoped availability, atomic replacement and reusable shift templates.
create table public.ns_roster_availability(
 id uuid primary key, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, kind text not null check(kind in ('leave','unavailable')),
 reason text not null check(length(trim(reason)) between 1 and 500),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 submitted_at timestamptz not null default clock_timestamp(), decided_by uuid, decided_at timestamptz, decision_reason text,
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(workstation_id,site_id,org_id) references public.ns_workstations(id,site_id,org_id),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 foreign key(decided_by,org_id) references public.ns_members(id,org_id),
 check(ends_at>starts_at and ends_at<=starts_at+interval '366 days'),
 check((status='pending' and decided_by is null and decided_at is null and decision_reason is null)
 or (status<>'pending' and decided_by is not null and decided_at is not null and length(trim(decision_reason)) between 1 and 500)));
create index ns_roster_availability_period on public.ns_roster_availability(org_id,member_id,starts_at,ends_at) where status in ('pending','approved');
alter table public.ns_roster_availability enable row level security;
revoke all on public.ns_roster_availability from public,anon,authenticated;
grant select on public.ns_roster_availability to authenticated;
create policy ns_roster_availability_read on public.ns_roster_availability for select to authenticated using(public.ns_roster_can_read(org_id,site_id,workstation_id,member_id));
create function public.ns_request_roster_availability(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_start timestamptz,p_end timestamptz,p_kind text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare m uuid; a public.ns_roster_availability%rowtype;
begin
 m:=public.ns_current_member_id(p_org);
 if m is null or not public.ns_roster_enabled(p_org) or not exists(select 1 from public.ns_sites where id=p_site and org_id=p_org and status='active')
 or (p_post is null and not public.ns_can_operate_site(p_org,p_site))
 or (p_post is not null and (not public.ns_can_operate_workstation(p_org,p_site,p_post) or not exists(select 1 from public.ns_workstations where id=p_post and org_id=p_org and site_id=p_site and status='active')))
 then raise exception 'NS_ROSTER_AVAILABILITY_FORBIDDEN'; end if;
 if p_id is null or p_start is null or p_end is null or p_end<=p_start or p_end>p_start+interval '366 days' or p_kind is null or p_kind not in ('leave','unavailable') or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'NS_ROSTER_AVAILABILITY_INVALID'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||m::text||':roster',0));
 select * into a from public.ns_roster_availability where id=p_id;
 if found then
  if (a.org_id,a.site_id,a.workstation_id,a.member_id,a.starts_at,a.ends_at,a.kind,a.reason) is distinct from (p_org,p_site,p_post,m,p_start,p_end,p_kind,trim(p_reason)) then raise exception 'NS_ROSTER_AVAILABILITY_CONFLICT'; end if;
 else
  if p_start<clock_timestamp() then raise exception 'NS_ROSTER_AVAILABILITY_PAST'; end if;
  if exists(select 1 from public.ns_roster_availability x where x.org_id=p_org and x.member_id=m and x.status in ('pending','approved') and x.starts_at<p_end and p_start<x.ends_at) then raise exception 'NS_ROSTER_AVAILABILITY_OVERLAP'; end if;
  insert into public.ns_roster_availability(id,org_id,site_id,workstation_id,member_id,starts_at,ends_at,kind,reason)
  values(p_id,p_org,p_site,p_post,m,p_start,p_end,p_kind,trim(p_reason)) returning * into a;
 end if;
 return jsonb_build_object('id',a.id,'status',a.status);
end $fn$;
create function public.ns_decide_roster_availability(p_id uuid,p_status text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare a public.ns_roster_availability%rowtype; actor uuid;
begin
 select * into a from public.ns_roster_availability where id=p_id;
 if not found or not public.ns_roster_can_manage(a.org_id,a.site_id,a.workstation_id,a.member_id) then raise exception 'NS_ROSTER_AVAILABILITY_FORBIDDEN'; end if;
 actor:=public.ns_current_member_id(a.org_id);
 if p_status is null or p_status not in ('approved','rejected') or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'NS_ROSTER_AVAILABILITY_INVALID'; end if;
 perform pg_advisory_xact_lock(hashtextextended(a.org_id::text||':'||a.member_id::text||':roster',0));
 select * into a from public.ns_roster_availability where id=p_id for update;
 if a.status<>'pending' then
  if (a.status,a.decided_by,a.decision_reason) is distinct from (p_status,actor,trim(p_reason)) then raise exception 'NS_ROSTER_AVAILABILITY_CONFLICT'; end if;
 else
  if p_status='approved' and (a.starts_at<clock_timestamp() or exists(select 1 from public.ns_roster_shifts s where s.org_id=a.org_id and s.member_id=a.member_id and s.status='published' and s.starts_at<a.ends_at and a.starts_at<s.ends_at)) then raise exception 'NS_ROSTER_AVAILABILITY_SHIFT_CONFLICT'; end if;
  update public.ns_roster_availability set status=p_status,decided_by=actor,decided_at=clock_timestamp(),decision_reason=trim(p_reason) where id=p_id returning * into a;
 end if;
 return jsonb_build_object('id',a.id,'status',a.status);
end $fn$;
create function public.ns_roster_guard_availability() returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if new.status='published' and exists(select 1 from public.ns_roster_availability a where a.org_id=new.org_id and a.member_id=new.member_id and a.status='approved' and a.starts_at<new.ends_at and new.starts_at<a.ends_at) then raise exception 'NS_ROSTER_MEMBER_UNAVAILABLE'; end if;
 return new;
end $fn$;
create trigger ns_roster_guard_availability before insert or update on public.ns_roster_shifts for each row execute function public.ns_roster_guard_availability();

-- Original shift, acknowledgement and revisions remain intact; replace only a future unstarted shift.
create table public.ns_roster_replacements(
 original_shift_id uuid primary key references public.ns_roster_shifts(id), replacement_shift_id uuid not null unique references public.ns_roster_shifts(id),
 original_revision bigint not null, org_id uuid not null, site_id uuid not null, workstation_id uuid, original_member_id uuid not null,
 replacement_member_id uuid not null, actor_member_id uuid not null, reason text not null, created_at timestamptz not null default clock_timestamp(),
 foreign key(original_shift_id,original_revision) references public.ns_roster_revisions(shift_id,revision));
alter table public.ns_roster_replacements enable row level security;
revoke all on public.ns_roster_replacements from public,anon,authenticated;
create function public.ns_replace_roster_shift(p_shift uuid,p_revision bigint,p_new_shift uuid,p_member uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare s public.ns_roster_shifts%rowtype; r public.ns_roster_replacements%rowtype; actor uuid;
begin
 select * into s from public.ns_roster_shifts where id=p_shift;
 if not found or not public.ns_roster_can_manage(s.org_id,s.site_id,s.workstation_id,s.member_id) or not public.ns_roster_can_manage(s.org_id,s.site_id,s.workstation_id,p_member) then raise exception 'NS_ROSTER_REPLACEMENT_FORBIDDEN'; end if;
 actor:=public.ns_current_member_id(s.org_id);
 if p_new_shift is null or p_new_shift=p_shift or p_member=s.member_id or p_revision is null or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'NS_ROSTER_REPLACEMENT_INVALID'; end if;
 perform pg_advisory_xact_lock(hashtextextended(s.org_id::text||':'||least(s.member_id,p_member)::text||':roster',0));
 perform pg_advisory_xact_lock(hashtextextended(s.org_id::text||':'||greatest(s.member_id,p_member)::text||':roster',0));
 select * into s from public.ns_roster_shifts where id=p_shift for update;
 if not public.ns_roster_can_manage(s.org_id,s.site_id,s.workstation_id,s.member_id) or not public.ns_roster_can_manage(s.org_id,s.site_id,s.workstation_id,p_member) then raise exception 'NS_ROSTER_REPLACEMENT_FORBIDDEN'; end if;
 select * into r from public.ns_roster_replacements where original_shift_id=p_shift;
 if found then
  if (r.original_revision,r.replacement_shift_id,r.replacement_member_id,r.actor_member_id,r.reason) is distinct from (p_revision,p_new_shift,p_member,actor,trim(p_reason)) then raise exception 'NS_ROSTER_REPLACEMENT_CONFLICT'; end if;
 else
  if s.revision<>p_revision or s.status<>'published' or s.starts_at<=clock_timestamp() or exists(select 1 from public.ns_roster_clock_links where shift_id=p_shift) then raise exception 'NS_ROSTER_REPLACEMENT_CONFLICT'; end if;
  perform public.ns_publish_roster_shift(s.id,s.org_id,s.site_id,s.workstation_id,s.member_id,s.starts_at,s.ends_at,s.planned_break_minutes,s.tolerance_minutes,'cancelled',p_revision,trim(p_reason));
  perform public.ns_publish_roster_shift(p_new_shift,s.org_id,s.site_id,s.workstation_id,p_member,s.starts_at,s.ends_at,s.planned_break_minutes,s.tolerance_minutes,'published',0,trim(p_reason));
  insert into public.ns_roster_replacements(original_shift_id,replacement_shift_id,original_revision,org_id,site_id,workstation_id,original_member_id,replacement_member_id,actor_member_id,reason)
  values(p_shift,p_new_shift,p_revision,s.org_id,s.site_id,s.workstation_id,s.member_id,p_member,actor,trim(p_reason));
 end if;
 return jsonb_build_object('original_shift_id',p_shift,'replacement_shift_id',p_new_shift,'replaced',true);
end $fn$;

create table public.ns_roster_templates(
 id uuid primary key, org_id uuid not null, site_id uuid not null, workstation_id uuid, member_id uuid not null,
 name text not null check(length(trim(name)) between 1 and 80),
 start_minute integer not null check(start_minute between 0 and 1439), duration_minutes integer not null check(duration_minutes between 1 and 1440),
 break_minutes integer not null check(break_minutes>=0 and break_minutes<duration_minutes), tolerance_minutes integer not null check(tolerance_minutes between 0 and 120),
 repeat_days integer not null check(repeat_days in (1,7)), repeat_count integer not null check(repeat_count between 1 and 31),
 created_by uuid not null, created_at timestamptz not null default clock_timestamp(), archived_at timestamptz,
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),
 foreign key(workstation_id,site_id,org_id) references public.ns_workstations(id,site_id,org_id),
 foreign key(member_id,org_id) references public.ns_members(id,org_id),
 foreign key(created_by,org_id) references public.ns_members(id,org_id));
alter table public.ns_roster_templates enable row level security;
revoke all on public.ns_roster_templates from public,anon,authenticated;
grant select on public.ns_roster_templates to authenticated;
create policy ns_roster_template_read on public.ns_roster_templates for select to authenticated using(public.ns_roster_can_manage(org_id,site_id,workstation_id,member_id));
create function public.ns_save_roster_template(p_id uuid,p_org uuid,p_site uuid,p_post uuid,p_member uuid,p_name text,p_start integer,p_duration integer,p_break integer,p_tolerance integer,p_step integer,p_count integer)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare t public.ns_roster_templates%rowtype; actor uuid;
begin
 if not public.ns_roster_can_manage(p_org,p_site,p_post,p_member) then raise exception 'NS_ROSTER_TEMPLATE_FORBIDDEN'; end if;
 actor:=public.ns_current_member_id(p_org);
 if p_id is null or p_name is null or length(trim(p_name)) not between 1 and 80 or p_start is null or p_start not between 0 and 1439 or p_duration is null or p_duration not between 1 and 1440 or p_break is null or p_break<0 or p_break>=p_duration or p_tolerance is null or p_tolerance not between 0 and 120 or p_step is null or p_step not in (1,7) or p_count is null or p_count not between 1 and 31 then raise exception 'NS_ROSTER_TEMPLATE_INVALID'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_member::text||':roster',0));
 select * into t from public.ns_roster_templates where id=p_id;
 if found then
  if (t.org_id,t.site_id,t.workstation_id,t.member_id,t.name,t.start_minute,t.duration_minutes,t.break_minutes,t.tolerance_minutes,t.repeat_days,t.repeat_count,t.created_by) is distinct from (p_org,p_site,p_post,p_member,trim(p_name),p_start,p_duration,p_break,p_tolerance,p_step,p_count,actor) then raise exception 'NS_ROSTER_TEMPLATE_CONFLICT'; end if;
 else
  insert into public.ns_roster_templates(id,org_id,site_id,workstation_id,member_id,name,start_minute,duration_minutes,break_minutes,tolerance_minutes,repeat_days,repeat_count,created_by)
  values(p_id,p_org,p_site,p_post,p_member,trim(p_name),p_start,p_duration,p_break,p_tolerance,p_step,p_count,actor) returning * into t;
 end if;
 return jsonb_build_object('id',t.id,'saved',true);
end $fn$;
create function public.ns_archive_roster_template(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare t public.ns_roster_templates%rowtype;
begin
 select * into t from public.ns_roster_templates where id=p_id for update;
 if not found or not public.ns_roster_can_manage(t.org_id,t.site_id,t.workstation_id,t.member_id) then raise exception 'NS_ROSTER_TEMPLATE_FORBIDDEN'; end if;
 update public.ns_roster_templates set archived_at=coalesce(archived_at,clock_timestamp()) where id=p_id;
 return jsonb_build_object('id',p_id,'archived',true);
end $fn$;

-- Current revision reminders. Generic message contains no attendance or HR details.
create function public.ns_roster_schedule_reminders() returns trigger language plpgsql security definer set search_path='' as $fn$
declare locale text; msg jsonb;
begin
 update public.ns_notification_outbox set status='cancelled',claim_token=null,claim_expires_at=null
 where org_id=new.org_id and channel='push' and event_code in ('staff_schedule.reminder','staff_schedule.unacknowledged')
 and payload_redacted->>'shift_id'=new.id::text and status in ('pending','processing');
 if new.status='published' and new.starts_at>clock_timestamp() then
  select coalesce(m.preferred_locale,o.default_locale,'fr') into locale from public.ns_members m join public.ns_organizations o on o.id=m.org_id where m.id=new.member_id;
  msg:=case locale when 'en' then jsonb_build_object('title','Upcoming work shift','body','Check your current schedule.') when 'ff-CM' then jsonb_build_object('title','Golle arde','body','Ƴeewto feere golle maa.') else jsonb_build_object('title','Service à venir','body','Consultez votre planning actuel.') end;
  msg:=msg||jsonb_build_object('route','/team','shift_id',new.id,'revision',new.revision);
  insert into public.ns_notification_outbox(org_id,site_id,recipient_member_id,channel,event_code,idempotency_key,payload_redacted,scheduled_at)
  values(new.org_id,new.site_id,new.member_id,'push','staff_schedule.reminder','staff-schedule-reminder:'||new.id||':'||new.revision,msg,greatest(clock_timestamp(),new.starts_at-interval '30 minutes')) on conflict do nothing;
 end if;
 return new;
end $fn$;
create trigger ns_roster_schedule_reminders after insert or update on public.ns_roster_shifts for each row execute function public.ns_roster_schedule_reminders();

-- Alert only when an active appointment intersects a shift but no current published
-- shift at the same site/compatible post fully covers that appointment.
create function public.ns_roster_alerts(p_org uuid,p_site uuid)
returns table(shift_id uuid,revision bigint,unacknowledged_due boolean,appointment_conflicts bigint)
language sql stable security definer set search_path='' as $fn$
 select s.id,s.revision,
 (s.status='published' and s.starts_at<=now()+interval '30 minutes' and not exists(select 1 from public.ns_roster_acknowledgements a where a.shift_id=s.id and a.revision=s.revision)),
 (select count(*) from public.ns_appointments a where a.org_id=s.org_id and a.site_id=s.site_id and a.assigned_member_id=s.member_id and a.status in ('requested','booked','confirmed','arrived') and a.starts_at<s.ends_at and s.starts_at<a.ends_at
 and (s.workstation_id is null or a.workstation_id=s.workstation_id)
 and not exists(select 1 from public.ns_roster_shifts x where x.org_id=a.org_id and x.site_id=a.site_id and x.member_id=a.assigned_member_id and x.status='published' and x.starts_at<=a.starts_at and x.ends_at>=a.ends_at and (x.workstation_id is null or x.workstation_id=a.workstation_id)))
 from public.ns_roster_shifts s where s.org_id=p_org and s.site_id=p_site and public.ns_roster_can_manage(s.org_id,s.site_id,s.workstation_id,s.member_id)
 order by s.starts_at desc limit 200
$fn$;
revoke all on function public.ns_request_roster_availability(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text,text),public.ns_decide_roster_availability(uuid,text,text),public.ns_replace_roster_shift(uuid,bigint,uuid,uuid,text),public.ns_save_roster_template(uuid,uuid,uuid,uuid,uuid,text,integer,integer,integer,integer,integer,integer),public.ns_archive_roster_template(uuid),public.ns_roster_alerts(uuid,uuid),public.ns_roster_guard_availability(),public.ns_roster_schedule_reminders() from public,anon,authenticated;
grant execute on function public.ns_request_roster_availability(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text,text),public.ns_decide_roster_availability(uuid,text,text),public.ns_replace_roster_shift(uuid,bigint,uuid,uuid,text),public.ns_save_roster_template(uuid,uuid,uuid,uuid,uuid,text,integer,integer,integer,integer,integer,integer),public.ns_archive_roster_template(uuid),public.ns_roster_alerts(uuid,uuid) to authenticated;

create function public.ns_roster_own_posts(p_org uuid,p_site uuid)
returns table(workstation_id uuid,workstation_name text) language sql stable security definer set search_path='' as $fn$
 select null::uuid,null::text where public.ns_roster_enabled(p_org) and public.ns_can_operate_site(p_org,p_site)
 and exists(select 1 from public.ns_sites where org_id=p_org and id=p_site and status='active')
 union all select w.id,w.name from public.ns_workstations w where w.org_id=p_org and w.site_id=p_site and w.status='active' and public.ns_roster_enabled(p_org) and public.ns_can_operate_workstation(p_org,p_site,w.id)
 order by 2 nulls first
$fn$;
revoke all on function public.ns_roster_own_posts(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_roster_own_posts(uuid,uuid) to authenticated;



rollback;
