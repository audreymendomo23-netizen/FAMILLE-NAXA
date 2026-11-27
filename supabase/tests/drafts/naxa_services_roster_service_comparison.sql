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
  -- A lost response may be retried only with the identical command by the same actor.
  if old.revision=p_expected_revision+1 and old.updated_by=v_actor and
     (old.site_id,old.workstation_id,old.starts_at,old.ends_at,old.planned_break_minutes,old.tolerance_minutes,old.status,old.change_reason)
     is not distinct from (p_site,p_post,p_starts,p_ends,p_break,p_tolerance,p_status,trim(p_reason)) then
   select n.id into v_notification from public.ns_notification_outbox n where n.org_id=p_org and n.recipient_member_id=p_member and n.idempotency_key='staff-schedule:'||p_id::text||':'||old.revision::text;
   if v_notification is null then raise exception 'NS_ROSTER_RECEIPT_MISSING'; end if;
   return jsonb_build_object('id',old.id,'revision',old.revision,'status',old.status,'notification_id',v_notification);
  end if;
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

-- Atomic bounded publication; each item uses the canonical authorized, idempotent RPC.
create function public.ns_publish_roster_batch(p_commands jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $fn$
declare c jsonb; receipts jsonb:='[]'::jsonb;
begin
 if jsonb_typeof(p_commands) is distinct from 'array' then raise exception 'NS_ROSTER_BATCH_INVALID'; end if;
 if jsonb_array_length(p_commands) not between 2 and 31 then raise exception 'NS_ROSTER_BATCH_INVALID'; end if;
 if exists(select 1 from jsonb_array_elements(p_commands) e where jsonb_typeof(e) is distinct from 'object'
  or e->>'p_id' is null or e->>'p_org' is null or e->>'p_member' is null or e->>'p_expected_revision' is distinct from '0'
  or e->>'p_status' is distinct from 'published') then raise exception 'NS_ROSTER_BATCH_INVALID'; end if;
 if (select count(distinct (e->>'p_id')::uuid) from jsonb_array_elements(p_commands) e)<>jsonb_array_length(p_commands) then raise exception 'NS_ROSTER_BATCH_INVALID'; end if;
 -- Deterministic member lock order for concurrent multi-member batches.
 for c in select e from jsonb_array_elements(p_commands) e order by (e->>'p_org')::uuid,(e->>'p_member')::uuid,(e->>'p_id')::uuid loop
  receipts:=receipts||jsonb_build_array(public.ns_publish_roster_shift(
    (c->>'p_id')::uuid,(c->>'p_org')::uuid,(c->>'p_site')::uuid,(c->>'p_post')::uuid,(c->>'p_member')::uuid,
    (c->>'p_starts')::timestamptz,(c->>'p_ends')::timestamptz,(c->>'p_break')::integer,(c->>'p_tolerance')::integer,
    c->>'p_status',0,c->>'p_reason'));
 end loop;
 return jsonb_build_object('receipts',receipts);
end $fn$;
revoke all on function public.ns_publish_roster_batch(jsonb) from public,anon,authenticated;
grant execute on function public.ns_publish_roster_batch(jsonb) to authenticated;


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
 if public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '8 hours',30,10,'published',0,'Initial') is distinct from v then raise exception 'QA LOST RESPONSE RECEIPT'; end if;
 begin perform public.ns_publish_roster_shift(y,o,s,null,u,t+interval '1 hour',t+interval '2 hours',0,10,'published',0,'Overlap'); raise exception 'QA OVERLAP ACCEPTED'; exception when others then if sqlerrm not like '%NS_ROSTER_OVERLAP%' then raise; end if; end;
 begin perform public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '7 hours',30,10,'published',0,'Stale'); raise exception 'QA STALE ACCEPTED'; exception when others then if sqlerrm not like '%NS_ROSTER_REVISION_CONFLICT%' then raise; end if; end;
 v:=public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '7 hours',30,10,'published',1,'Updated hours');
 if v->>'revision'<>'2' then raise exception 'QA UPDATE'; end if;
 if public.ns_publish_roster_shift(x,o,s,null,u,t,t+interval '7 hours',30,10,'published',1,'Updated hours') is distinct from v then raise exception 'QA UPDATE RETRY'; end if;
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


-- A worker can explain the frozen baseline, cannot decide it; a manager cannot submit for them.
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare x uuid:='70000000-0000-4000-8000-000000000095'; a jsonb; begin
 a:=public.ns_submit_roster_justification(x,2,'Transport delay');
 if public.ns_submit_roster_justification(x,2,'Transport delay') is distinct from a then raise exception 'QA JUSTIFICATION RETRY'; end if;
 begin perform public.ns_submit_roster_justification(x,2,'Changed'); raise exception 'QA ALTERED JUSTIFICATION'; exception when others then if sqlerrm not like '%NS_ROSTER_JUSTIFICATION_CONFLICT%' then raise; end if; end;
 begin perform public.ns_decide_roster_justification(x,2,'accepted','Own'); raise exception 'QA SELF DECISION'; exception when others then if sqlerrm not like '%NS_ROSTER_JUSTIFICATION_FORBIDDEN%' then raise; end if; end;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare x uuid:='70000000-0000-4000-8000-000000000095'; a jsonb; begin
 begin perform public.ns_submit_roster_justification(x,2,'Manager impersonation'); raise exception 'QA MANAGER SUBMIT'; exception when others then if sqlerrm not like '%NS_ROSTER_JUSTIFICATION_FORBIDDEN%' then raise; end if; end;
 a:=public.ns_decide_roster_justification(x,2,'accepted','Reviewed');
 if public.ns_decide_roster_justification(x,2,'accepted','Reviewed') is distinct from a then raise exception 'QA DECISION RETRY'; end if;
 begin perform public.ns_decide_roster_justification(x,2,'rejected','Changed'); raise exception 'QA ALTERED DECISION'; exception when others then if sqlerrm not like '%NS_ROSTER_JUSTIFICATION_CONFLICT%' then raise; end if; end;
 if not exists(select 1 from public.ns_roster_service_comparison where shift_id=x and baseline_revision=2 and late_minutes=20 and comparison_status='variance_review') then raise exception 'QA CLOCK ALTERED'; end if;
 if (select count(*) from public.ns_roster_justifications where shift_id=x and baseline_revision=2 and decision='accepted')<>1 then raise exception 'QA DECISION MISSING'; end if;
end $qa$;
reset role;

select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare base jsonb; a jsonb; b jsonb; commands jsonb; receipt jsonb; t timestamptz:=now()+interval '10 days';
begin
 base:=jsonb_build_object('p_org','20000000-0000-4000-8000-000000000091','p_site','30000000-0000-4000-8000-000000000091','p_post',null,'p_member','60000000-0000-4000-8000-000000000092','p_break',30,'p_tolerance',10,'p_status','published','p_expected_revision',0,'p_reason','QA weekly repeat');
 a:=base||jsonb_build_object('p_id','70000000-0000-4000-8000-000000000101','p_starts',t,'p_ends',t+interval '8 hours');
 b:=base||jsonb_build_object('p_id','70000000-0000-4000-8000-000000000102','p_starts',t+interval '7 days','p_ends',t+interval '7 days 8 hours');
 commands:=jsonb_build_array(a,b);
 receipt:=public.ns_publish_roster_batch(commands);
 if jsonb_array_length(receipt->'receipts')<>2 or public.ns_publish_roster_batch(commands) is distinct from receipt then raise exception 'QA BATCH RECEIPT'; end if;
 if (select count(*) from public.ns_roster_revisions where shift_id in ('70000000-0000-4000-8000-000000000101','70000000-0000-4000-8000-000000000102'))<>2 then raise exception 'QA BATCH DUPLICATE'; end if;
 a:=base||jsonb_build_object('p_id','70000000-0000-4000-8000-000000000103','p_starts',t+interval '1 day','p_ends',t+interval '1 day 8 hours');
 b:=base||jsonb_build_object('p_id','70000000-0000-4000-8000-000000000104','p_starts',t+interval '1 hour','p_ends',t+interval '2 hours');
 begin perform public.ns_publish_roster_batch(jsonb_build_array(a,b)); raise exception 'QA BATCH OVERLAP ACCEPTED'; exception when others then if sqlerrm not like '%NS_ROSTER_OVERLAP%' then raise; end if; end;
 if exists(select 1 from public.ns_roster_shifts where id in ('70000000-0000-4000-8000-000000000103','70000000-0000-4000-8000-000000000104')) then raise exception 'QA BATCH PARTIAL COMMIT'; end if;
 begin perform public.ns_publish_roster_batch(jsonb_build_array(a,a)); raise exception 'QA DUPLICATE IDS'; exception when others then if sqlerrm not like '%NS_ROSTER_BATCH_INVALID%' then raise; end if; end;
end $qa$;
reset role;
do $qa$ begin
 if (select count(*) from public.ns_notification_outbox where idempotency_key in ('staff-schedule:70000000-0000-4000-8000-000000000101:1','staff-schedule:70000000-0000-4000-8000-000000000102:1'))<>2 then raise exception 'QA BATCH NOTIFICATION DUPLICATE'; end if;
 if exists(select 1 from public.ns_notification_outbox where idempotency_key in ('staff-schedule:70000000-0000-4000-8000-000000000103:1','staff-schedule:70000000-0000-4000-8000-000000000104:1')) then raise exception 'QA BATCH PARTIAL NOTIFICATION'; end if;
end $qa$;


-- Extra synthetic collaborator for replacement.
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000093');
insert into public.ns_accounts(id,auth_user_id,login_id,auth_alias,password_change_required) values ('50000000-0000-4000-8000-000000000093','10000000-0000-4000-8000-000000000093','NS-QA93','qa93@example.invalid',false);
insert into public.ns_members(id,org_id,account_id,display_name,role_code) values ('60000000-0000-4000-8000-000000000093','20000000-0000-4000-8000-000000000091','50000000-0000-4000-8000-000000000093','QA Substitute','cashier');
insert into public.ns_member_scopes(org_id,member_id,scope_type,scope_id,site_id,can_read,can_operate,can_manage) values ('20000000-0000-4000-8000-000000000091','60000000-0000-4000-8000-000000000093','site','30000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',true,true,false);
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000092',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000092","session_id":"qa-92-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare x uuid:='70000000-0000-4000-8000-000000000105'; o uuid:='20000000-0000-4000-8000-000000000091'; s uuid:='30000000-0000-4000-8000-000000000091'; t timestamptz:=now()+interval '20 days'; a jsonb; begin
 a:=public.ns_request_roster_availability(x,o,s,null,t,t+interval '1 day','leave','QA personal request');
 if public.ns_request_roster_availability(x,o,s,null,t,t+interval '1 day','leave','QA personal request') is distinct from a then raise exception 'QA AVAILABILITY RETRY'; end if;
 begin perform public.ns_decide_roster_availability(x,'approved','Self'); raise exception 'QA AVAILABILITY SELF DECISION'; exception when others then if sqlerrm not like '%NS_ROSTER_AVAILABILITY_FORBIDDEN%' then raise; end if; end;
 if exists(select 1 from public.ns_roster_alerts(o,s)) then raise exception 'QA EMPLOYEE ALERT LEAK'; end if;
end $qa$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $qa$ declare o uuid:='20000000-0000-4000-8000-000000000091'; s uuid:='30000000-0000-4000-8000-000000000091'; u uuid:='60000000-0000-4000-8000-000000000092'; v uuid:='60000000-0000-4000-8000-000000000093'; x uuid:='70000000-0000-4000-8000-000000000105'; y uuid:='70000000-0000-4000-8000-000000000106'; z uuid:='70000000-0000-4000-8000-000000000107'; k uuid:='70000000-0000-4000-8000-000000000108'; t timestamptz:=now()+interval '20 days'; a jsonb; begin
 perform public.ns_publish_roster_shift(y,o,s,null,u,t,t+interval '8 hours',30,10,'published',0,'QA service needing replacement');
 begin perform public.ns_decide_roster_availability(x,'approved','Needs cover'); raise exception 'QA LEAVE APPROVED DESPITE SHIFT'; exception when others then if sqlerrm not like '%NS_ROSTER_AVAILABILITY_SHIFT_CONFLICT%' then raise; end if; end;
 a:=public.ns_replace_roster_shift(y,1,z,v,'QA replacement');
 if public.ns_replace_roster_shift(y,1,z,v,'QA replacement') is distinct from a then raise exception 'QA REPLACEMENT RETRY'; end if;
 if not exists(select 1 from public.ns_roster_shifts where id=y and status='cancelled' and revision=2) or not exists(select 1 from public.ns_roster_shifts where id=z and member_id=v and status='published' and revision=1) then raise exception 'QA REPLACEMENT ATOMIC'; end if;
 a:=public.ns_decide_roster_availability(x,'approved','Coverage confirmed');
 if public.ns_decide_roster_availability(x,'approved','Coverage confirmed') is distinct from a then raise exception 'QA APPROVAL RETRY'; end if;
 begin perform public.ns_publish_roster_shift(k,o,s,null,u,t,t+interval '2 hours',0,10,'published',0,'QA leave guard'); raise exception 'QA SHIFT DURING LEAVE'; exception when others then if sqlerrm not like '%NS_ROSTER_MEMBER_UNAVAILABLE%' then raise; end if; end;
 a:=public.ns_save_roster_template(k,o,s,null,v,'Weekly morning',480,480,30,10,7,3);
 if public.ns_save_roster_template(k,o,s,null,v,'Weekly morning',480,480,30,10,7,3) is distinct from a then raise exception 'QA TEMPLATE RETRY'; end if;
 if not exists(select 1 from public.ns_roster_templates where id=k and repeat_count=3 and archived_at is null) then raise exception 'QA TEMPLATE MISSING'; end if;
 perform public.ns_archive_roster_template(k);
 if not exists(select 1 from public.ns_roster_templates where id=k and archived_at is not null) then raise exception 'QA TEMPLATE ARCHIVE'; end if;
 if not exists(select 1 from public.ns_roster_alerts(o,s) where shift_id=z and appointment_conflicts=0 and not unacknowledged_due) then raise exception 'QA ALERT SCOPE'; end if;
end $qa$;
reset role;
do $qa$ begin
 if not exists(select 1 from public.ns_notification_outbox where idempotency_key='staff-schedule-reminder:70000000-0000-4000-8000-000000000106:1' and status='cancelled') then raise exception 'QA STALE REMINDER'; end if;
 if (select count(*) from public.ns_notification_outbox where idempotency_key='staff-schedule-reminder:70000000-0000-4000-8000-000000000107:1' and status='pending')<>1 then raise exception 'QA REPLACEMENT REMINDER'; end if;
end $qa$;

update public.ns_organizations set business_mode='solo' where id='20000000-0000-4000-8000-000000000091';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000091',true); select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000091","session_id":"qa-91-session","role":"authenticated"}',true);
set local role authenticated;
do $$ begin
 if public.ns_roster_enabled('20000000-0000-4000-8000-000000000091') or exists(select 1 from public.ns_roster_shifts where id='70000000-0000-4000-8000-000000000095') then raise exception 'QA SOLO READ'; end if;
 if public.ns_roster_can_manage('20000000-0000-4000-8000-000000000091','30000000-0000-4000-8000-000000000091',null,'60000000-0000-4000-8000-000000000092') then raise exception 'QA SOLO MANAGE'; end if;
end $$;
reset role;

rollback;
select 'PASS: roster, scoped directory, service comparison and frozen baseline' as result;