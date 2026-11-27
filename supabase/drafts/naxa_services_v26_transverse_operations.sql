-- DRAFT ONLY. Requires v24 and v25. No payout or deployment.
begin;
create table public.ns_commission_review_events (
 id uuid primary key, org_id uuid not null, site_id uuid not null,
 entry_id uuid not null, actor_id uuid not null,
 decision text not null check(decision in ('approve','reject','reverse_refund')),
 reason text not null check(length(trim(reason)) between 4 and 500),
 previous_status text not null, next_status text not null,
 created_at timestamptz not null default now(),
 foreign key(entry_id,site_id,org_id) references public.ns_commission_entries(id,site_id,org_id),
 foreign key(actor_id,org_id) references public.ns_members(id,org_id)
);
alter table public.ns_commission_review_events enable row level security;
revoke all on public.ns_commission_review_events from public,anon,authenticated;
grant select,insert on public.ns_commission_review_events to service_role;
create function public.ns_review_settled_commission(p_org uuid,p_site uuid,p_entry uuid,p_event uuid,p_decision text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; e public.ns_commission_entries%rowtype; old_event public.ns_commission_review_events%rowtype;
 s public.ns_sales%rowtype; a public.ns_appointments%rowtype; paid numeric; next_status text; prior text;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_REVIEW_FORBIDDEN'; end if;
 if p_event is null or p_decision is null or p_decision not in ('approve','reject','reverse_refund') or length(trim(coalesce(p_reason,''))) not between 4 and 500 then raise exception 'NS_COMMISSION_REVIEW_INVALID'; end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_REVIEW_FORBIDDEN'; end if;
 select * into old_event from public.ns_commission_review_events where id=p_event;
 if found then
  if old_event.org_id<>p_org or old_event.site_id<>p_site or old_event.entry_id<>p_entry or old_event.actor_id<>actor or old_event.decision<>p_decision or old_event.reason<>trim(p_reason) then raise exception 'NS_COMMISSION_REVIEW_CONFLICT'; end if;
  return jsonb_build_object('entry_id',p_entry,'status',old_event.next_status,'replayed',true);
 end if;
 select c.* into e from public.ns_commission_entries c join public.ns_commission_settlements t on t.entry_id=c.id and t.org_id=c.org_id and t.site_id=c.site_id where c.id=p_entry and c.org_id=p_org and c.site_id=p_site for update of c;
 if not found then raise exception 'NS_COMMISSION_REVIEW_SCOPE'; end if;
 select * into a from public.ns_appointments where id=e.appointment_id and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_REVIEW_SCOPE'; end if;
 select * into s from public.ns_sales where id=e.sale_id and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_REVIEW_SCOPE'; end if;
 perform 1 from public.ns_payments where sale_id=s.id for update;
 if exists(select 1 from public.ns_payments where sale_id=s.id and (org_id<>p_org or site_id<>p_site)) then raise exception 'NS_COMMISSION_REVIEW_SCOPE'; end if;
 select coalesce(sum(amount_xaf),0) into paid from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status='confirmed' and confirmed_at is not null;
 prior:=e.status;
 if p_decision='approve' then
  if e.status<>'pending_approval' or a.status<>'completed' or s.status<>'posted' or paid<>s.total_xaf or paid<>e.base_amount_xaf or exists(select 1 from public.ns_payments where sale_id=s.id and status in ('refunded','reversed')) then raise exception 'NS_COMMISSION_REVIEW_NOT_ELIGIBLE'; end if;
  next_status:='approved';
  update public.ns_commission_entries set status=next_status,approved_by=actor,approved_at=now() where id=e.id;
 elsif p_decision='reject' then
  if e.status<>'pending_approval' then raise exception 'NS_COMMISSION_REVIEW_NOT_ELIGIBLE'; end if;
  next_status:='reversed';
  update public.ns_commission_entries set status=next_status where id=e.id;
 else
  -- Full refund only. Partial allocation is a distinct unfinished business rule.
  if e.status not in ('approved','paid') or s.status not in ('refunded','voided') or paid<>0 or not exists(select 1 from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status in ('refunded','reversed')) or exists(select 1 from public.ns_commission_adjustments where commission_entry_id=e.id) then raise exception 'NS_COMMISSION_REFUND_PROOF_REQUIRED'; end if;
  insert into public.ns_commission_adjustments(org_id,site_id,commission_entry_id,source_event_id,idempotency_key,adjustment_type,amount_delta_xaf,reason,created_by)
   values(p_org,p_site,e.id,p_event,p_event,'refund_reversal',-e.commission_xaf,trim(p_reason),actor);
  next_status:='reversed';
  update public.ns_commission_entries set status=next_status where id=e.id;
 end if;
 insert into public.ns_commission_review_events(id,org_id,site_id,entry_id,actor_id,decision,reason,previous_status,next_status) values(p_event,p_org,p_site,p_entry,actor,p_decision,trim(p_reason),prior,next_status);
 return jsonb_build_object('entry_id',p_entry,'status',next_status,'replayed',false);
end $fn$;
revoke all on function public.ns_review_settled_commission(uuid,uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.ns_review_settled_commission(uuid,uuid,uuid,uuid,text,text) to authenticated;
create function public.ns_settled_commission_queue(p_org uuid,p_site uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
begin
 if auth.uid() is null or public.ns_current_member_id(p_org) is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) or not exists(select 1 from public.ns_sites where id=p_site and org_id=p_org and status='active') then raise exception 'NS_COMMISSION_REVIEW_FORBIDDEN'; end if;
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id) from
 (select c.id,c.status,c.commission_xaf,c.base_amount_xaf,c.created_at,m.display_name as member_name,s.sale_number
 from public.ns_commission_entries c join public.ns_commission_settlements t on t.entry_id=c.id and t.org_id=c.org_id and t.site_id=c.site_id
 join public.ns_members m on m.id=c.member_id and m.org_id=c.org_id
 join public.ns_sales s on s.id=c.sale_id and s.org_id=c.org_id and s.site_id=c.site_id
 where c.org_id=p_org and c.site_id=p_site order by c.created_at desc,c.id limit 100) q),'[]'::jsonb);
end $fn$;
revoke all on function public.ns_settled_commission_queue(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_settled_commission_queue(uuid,uuid) to authenticated;
-- Common operational view across all 13 activity profiles. Separate categories; never sum unlike objects.
create function public.ns_cross_activity_operations(p_org uuid,p_site uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare orders jsonb; pressing jsonb; appointments jsonb; receivables jsonb; generated timestamptz:=now();
begin
 if auth.uid() is null or public.ns_current_member_id(p_org) is null or not public.ns_can_manage_site(p_org,p_site) or not exists(select 1 from public.ns_sites where id=p_site and org_id=p_org and status='active') then raise exception 'NS_OPERATIONS_FORBIDDEN'; end if;
 select jsonb_build_object('open',count(*) filter(where status not in ('closed','delivered','cancelled','rejected','paid')),'overdue',count(*) filter(where status not in ('closed','delivered','cancelled','rejected','paid') and due_at<generated),'ready',count(*) filter(where status='ready')) into orders from public.ns_management_records where org_id=p_org and site_id=p_site and record_type in ('work_order','repair_order','service_order');
 select jsonb_build_object('open',count(*) filter(where status in ('received','in_progress','ready')),'overdue',count(*) filter(where status in ('received','in_progress','ready') and promised_at<generated),'ready',count(*) filter(where status='ready')) into pressing from public.ns_pressing_orders where org_id=p_org and site_id=p_site;
 select jsonb_build_object('open',count(*) filter(where status in ('requested','booked','confirmed','arrived')),'overdue',count(*) filter(where status in ('requested','booked','confirmed','arrived') and ends_at<generated),'ready',0) into appointments from public.ns_appointments where org_id=p_org and site_id=p_site;
 select jsonb_build_object('open',count(*),'overdue',count(*) filter(where due_at<generated),'balance_xaf',coalesce(sum(amount_xaf-paid_xaf),0)) into receivables from public.ns_management_records where org_id=p_org and site_id=p_site and record_type='customer_receivable' and status in ('open','partial') and amount_xaf>paid_xaf;
 return jsonb_build_object('generated_at',generated,'site_id',p_site,'orders',orders,'pressing',pressing,'appointments',appointments,'receivables',receivables);
end $fn$;
revoke all on function public.ns_cross_activity_operations(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_cross_activity_operations(uuid,uuid) to authenticated;
rollback;
