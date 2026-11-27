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


rollback;
