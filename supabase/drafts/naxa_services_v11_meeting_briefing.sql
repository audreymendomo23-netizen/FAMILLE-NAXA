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
declare actor uuid:=public.ns_current_member_id(p_org); manager boolean; start_at timestamptz; stop_at timestamptz; fin jsonb; appointments jsonb; clocks jsonb; details jsonb:='{}'::jsonb; today date:=(now() at time zone 'Africa/Douala')::date; network_ids uuid[]; post_ids uuid[]; network_count integer; network_revenue numeric; network_sales numeric; current_day boolean; role_name text;
begin
 if actor is null or p_day is null or p_day>(now() at time zone 'Africa/Douala')::date or p_day<(now() at time zone 'Africa/Douala')::date-366 or public.ns_erp_access_reason(p_org)='blocked' or not exists(select 1 from public.ns_sites where id=p_site and org_id=p_org and status='active') then raise exception 'NS_BRIEFING_FORBIDDEN'; end if;
 if not public.ns_can_access_site(p_org,p_site) and not exists(select 1 from public.ns_member_scopes s where s.org_id=p_org and s.member_id=actor and s.site_id=p_site and s.scope_type='workstation' and s.can_read) then raise exception 'NS_BRIEFING_FORBIDDEN'; end if;
 select role_code into role_name from public.ns_members where id=actor and org_id=p_org;
 -- A workstation-only manager is never treated as a whole-site manager.
 manager:=role_name in ('promoter','network_manager','site_manager') and exists(select 1 from public.ns_member_scopes sc where sc.org_id=p_org and sc.member_id=actor and sc.can_read and sc.can_manage and (sc.scope_type='organization' or (sc.scope_type='site' and sc.site_id=p_site)));
 select array_agg(distinct sc.workstation_id) into post_ids from public.ns_member_scopes sc join public.ns_workstations w on w.id=sc.workstation_id and w.org_id=p_org and w.site_id=p_site where sc.org_id=p_org and sc.member_id=actor and sc.site_id=p_site and sc.scope_type='workstation' and sc.can_read and sc.can_manage and w.status='active' and role_name in ('promoter','network_manager','site_manager','workstation_manager');
 current_day:=p_day=today;
 start_at:=p_day::timestamp at time zone 'Africa/Douala';stop_at:=(p_day+1)::timestamp at time zone 'Africa/Douala';
 if manager then select jsonb_build_object('revenue_xaf',v.revenue_xaf,'confirmed_sales_count',v.confirmed_sales_count,'uncosted_sales_count',v.uncosted_sales_count) into fin from public.ns_performance_daily v where v.org_id=p_org and v.site_id=p_site and v.performance_day=p_day; end if;
 select jsonb_build_object('scheduled_count',count(*),'completed_count',count(*) filter(where a.status='completed')) into appointments from public.ns_appointments a where a.org_id=p_org and a.site_id=p_site and a.starts_at>=start_at and a.starts_at<stop_at and (manager or a.assigned_member_id=actor);
 if public.ns_roster_enabled(p_org) then
  select jsonb_build_object('first_clock_in',min(e.occurred_at) filter(where e.event_type='staff_clock_in'),'last_clock_out',max(e.occurred_at) filter(where e.event_type='staff_clock_out'),'event_count',count(*)) into clocks from public.ns_staff_time_events e where e.org_id=p_org and e.site_id=p_site and e.staff_member_id=actor and e.occurred_at>=start_at and e.occurred_at<stop_at and e.actor_member_id=actor;
 end if;
 -- Personal data only, even if an employee has a broad read grant.
 details:=jsonb_build_object(
 'own_commissions_xaf',(select coalesce(sum(c.commission_xaf),0) from public.ns_commission_entries c where c.org_id=p_org and c.site_id=p_site and c.member_id=actor and c.created_at>=start_at and c.created_at<stop_at and c.status in ('approved','paid')),
 'tomorrow_appointments',case when current_day then (select count(*) from public.ns_appointments a where a.org_id=p_org and a.site_id=p_site and a.starts_at>=stop_at and a.starts_at<stop_at+interval '1 day' and a.status in ('requested','booked','confirmed','arrived') and (manager or a.assigned_member_id=actor)) else null end,
 'tomorrow_shifts',case when current_day and public.ns_roster_enabled(p_org) then (select count(*) from public.ns_roster_shifts r where r.org_id=p_org and r.site_id=p_site and r.member_id=actor and r.status='published' and r.starts_at>=stop_at and r.starts_at<stop_at+interval '1 day') else null end,
 'post_appointments',case when post_ids is not null and not manager then (select count(*) from public.ns_appointments a where a.org_id=p_org and a.site_id=p_site and a.workstation_id=any(post_ids) and a.starts_at>=start_at and a.starts_at<stop_at) else null end,
 'post_completed',case when post_ids is not null and not manager then (select count(*) from public.ns_appointments a where a.org_id=p_org and a.site_id=p_site and a.workstation_id=any(post_ids) and a.starts_at>=start_at and a.starts_at<stop_at and a.status='completed') else null end);
 if manager then
  details:=details||jsonb_build_object(
   'receipts_xaf',(select coalesce(sum(p.amount_xaf),0) from public.ns_payments p where p.org_id=p_org and p.site_id=p_site and p.status='confirmed' and p.confirmed_at>=start_at and p.confirmed_at<stop_at),
   'pending_payments_xaf',case when current_day then (select coalesce(sum(p.amount_xaf),0) from public.ns_payments p where p.org_id=p_org and p.site_id=p_site and p.status='pending' and p.created_at>=start_at and p.created_at<stop_at) else null end,
   'expenses_xaf',(select coalesce(sum(e.amount_xaf),0) from public.ns_expenses e where e.org_id=p_org and e.site_id=p_site and e.created_at>=start_at and e.created_at<stop_at),
   'gross_profit_xaf',(select v.gross_profit_xaf from public.ns_performance_daily v where v.org_id=p_org and v.site_id=p_site and v.performance_day=p_day and v.gross_profit_xaf>=0),
   'objective_xaf',(select v.target_revenue_xaf from public.ns_performance_objectives v where v.org_id=p_org and v.site_id=p_site and v.period_type='daily' and v.period_start=p_day order by v.version desc limit 1),
   'cash_closed',(select count(*) from public.ns_cash_sessions c where c.org_id=p_org and c.site_id=p_site and c.closed_at>=start_at and c.closed_at<stop_at and c.status in ('closed','reviewed')),
   'cash_variances',(select count(*) from public.ns_cash_sessions c where c.org_id=p_org and c.site_id=p_site and c.closed_at>=start_at and c.closed_at<stop_at and c.variance_xaf<>0),
   'new_customers',(select count(*) from public.ns_customers c where c.org_id=p_org and c.site_id=p_site and c.created_at>=start_at and c.created_at<stop_at),
   'loyalty_rewards',(select count(*) from public.ns_loyalty_events e where e.org_id=p_org and e.site_id=p_site and e.created_at>=start_at and e.created_at<stop_at and e.event_type='reward_earned'),
   'support_requests',(select count(*) from public.ns_support_requests r where r.org_id=p_org and r.site_id=p_site and r.created_at>=start_at and r.created_at<stop_at),
   'completed_work',(select count(distinct e.record_id) from public.ns_management_record_events e join public.ns_management_records r on r.id=e.record_id and r.org_id=e.org_id and r.site_id=e.site_id where e.org_id=p_org and e.site_id=p_site and r.record_type in ('work_order','repair_order','service_order') and e.to_status in ('delivered','closed') and e.occurred_at>=start_at and e.occurred_at<stop_at),
   'supplier_payments_xaf',(select coalesce(sum(p.amount_xaf),0) from public.ns_supplier_payments p where p.org_id=p_org and p.site_id=p_site and p.paid_at>=start_at and p.paid_at<stop_at),
   'receivables_xaf',case when current_day then (select coalesce(sum(r.amount_xaf-r.paid_xaf),0) from public.ns_management_records r where r.org_id=p_org and r.site_id=p_site and r.record_type='customer_receivable' and r.status in ('open','partial')) else null end,
   'followups_due',case when current_day then (select count(*) from public.ns_customer_followups r where r.org_id=p_org and r.site_id=p_site and r.status='active' and r.next_due_at<stop_at) else null end,
   'stock_low',case when current_day then (select count(*) from public.ns_inventory_items i where i.org_id=p_org and i.site_id=p_site and i.active and i.quantity<=i.reorder_level) else null end,
   'purchase_open',case when current_day then (select count(*) from public.ns_purchase_documents r where r.org_id=p_org and r.site_id=p_site and r.status in ('ordered','partially_received')) else null end,
   'supplier_debt_xaf',case when current_day then (select coalesce(sum(r.received_total_xaf-r.paid_total_xaf),0) from public.ns_purchase_documents r where r.org_id=p_org and r.site_id=p_site and r.status<>'cancelled') else null end,
   'supplier_overdue_xaf',case when current_day then (select coalesce(sum(r.received_total_xaf-r.paid_total_xaf),0) from public.ns_purchase_documents r where r.org_id=p_org and r.site_id=p_site and r.status<>'cancelled' and r.due_at<now()) else null end,
   'work_open',case when current_day then (select count(*) from public.ns_management_records r where r.org_id=p_org and r.site_id=p_site and r.record_type in ('work_order','repair_order','service_order') and r.status not in ('closed','delivered','cancelled','rejected','paid')) else null end,
   'work_overdue',case when current_day then (select count(*) from public.ns_management_records r where r.org_id=p_org and r.site_id=p_site and r.record_type in ('work_order','repair_order','service_order') and r.status not in ('closed','delivered','cancelled','rejected','paid') and r.due_at<now()) else null end,
   'pressing_open',case when current_day then (select count(*) from public.ns_pressing_orders r where r.org_id=p_org and r.site_id=p_site and r.status in ('received','in_progress','ready')) else null end,
   'pressing_overdue',case when current_day then (select count(*) from public.ns_pressing_orders r where r.org_id=p_org and r.site_id=p_site and r.status in ('received','in_progress','ready') and r.promised_at<now()) else null end);
  if role_name in ('promoter','network_manager') then
   select array_agg(si.id order by si.id) into network_ids from public.ns_sites si where si.org_id=p_org and si.status='active' and exists(select 1 from public.ns_member_scopes sc where sc.org_id=p_org and sc.member_id=actor and sc.can_read and sc.can_manage and (sc.scope_type='organization' or (sc.scope_type='site' and sc.site_id=si.id)));
   select count(*),sum(v.revenue_xaf),sum(v.confirmed_sales_count) into network_count,network_revenue,network_sales from public.ns_performance_daily v where v.org_id=p_org and v.site_id=any(network_ids) and v.performance_day=p_day;
   details:=details||jsonb_build_object('network_sites',cardinality(network_ids),'network_revenue_xaf',case when network_count=cardinality(network_ids) then network_revenue else null end,'network_sales',case when network_count=cardinality(network_ids) then network_sales else null end);
  end if;
 end if;
 return jsonb_build_object('day',p_day,'generated_at',now(),'scope',case when manager then 'site' else 'personal' end,'finance',fin,'appointments',appointments,'personal_clock_events',clocks,'details',details,'coverage','partial_confirmed_server_facts');
end $f$;
revoke all on function public.ns_daily_briefing(uuid,uuid,date) from public,anon,authenticated;
grant execute on function public.ns_daily_briefing(uuid,uuid,date) to authenticated;

rollback;
