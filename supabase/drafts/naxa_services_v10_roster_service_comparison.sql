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

rollback;
