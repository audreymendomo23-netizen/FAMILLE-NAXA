-- DRAFT: explicit one-to-one allocation of each service line to a completed appointment.
-- All lines must be covered; one appointment per line; no split within a line, no automatic payout.
begin;
alter table public.ns_commission_settlements drop constraint ns_commission_settlements_sale_id_key;
alter table public.ns_commission_settlements add column sale_line_id uuid unique references public.ns_sale_lines(id);
create unique index ns_commission_single_sale_idx on public.ns_commission_settlements(sale_id) where sale_line_id is null;
create index ns_commission_settlements_sale_idx on public.ns_commission_settlements(sale_id);
create table public.ns_commission_allocation_batches(
 id uuid primary key,org_id uuid not null,site_id uuid not null,sale_id uuid not null unique references public.ns_sales(id),
 actor_id uuid not null,allocation jsonb not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),foreign key(actor_id,org_id) references public.ns_members(id,org_id)
);
alter table public.ns_commission_allocation_batches enable row level security;
revoke all on public.ns_commission_allocation_batches from public,anon,authenticated;
grant select,insert on public.ns_commission_allocation_batches to service_role;
create function public.ns_prepare_multiline_commissions(p_org uuid,p_site uuid,p_sale uuid,p_id uuid,p_allocations jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; profile text; s public.ns_sales%rowtype; a public.ns_appointments%rowtype; l public.ns_sale_lines%rowtype;
 old public.ns_commission_allocation_batches%rowtype; p public.ns_commission_policy_versions%rowtype;
 line_id uuid; appointment_id uuid; item jsonb; canonical jsonb; result jsonb:='[]'::jsonb; paid numeric; net numeric; total numeric; d date; n integer; eid uuid; commission bigint;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_MULTILINE_FORBIDDEN';end if;
 if p_id is null or p_sale is null or p_allocations is null or jsonb_typeof(p_allocations)<>'array' then raise exception 'NS_MULTILINE_INVALID';end if;
 n:=jsonb_array_length(p_allocations);if n not between 2 and 30 then raise exception 'NS_MULTILINE_INVALID';end if;
 if exists(select 1 from jsonb_array_elements(p_allocations) x where jsonb_typeof(x)<>'object' or not (x?'line_id' and x?'appointment_id') or coalesce(x->>'line_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or coalesce(x->>'appointment_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'NS_MULTILINE_INVALID';end if;
 select jsonb_agg(jsonb_build_object('line_id',(x->>'line_id')::uuid,'appointment_id',(x->>'appointment_id')::uuid) order by (x->>'line_id')::uuid) into canonical from jsonb_array_elements(p_allocations) x;
 if (select count(distinct x->>'line_id') from jsonb_array_elements(canonical) x)<>n or (select count(distinct x->>'appointment_id') from jsonb_array_elements(canonical) x)<>n then raise exception 'NS_MULTILINE_DUPLICATE';end if;
 select activity_profile into profile from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_MULTILINE_FORBIDDEN';end if;
 select * into old from public.ns_commission_allocation_batches where id=p_id or sale_id=p_sale;
 if found then
  if old.id<>p_id or old.org_id<>p_org or old.site_id<>p_site or old.sale_id<>p_sale or old.actor_id<>actor or old.allocation<>canonical then raise exception 'NS_MULTILINE_CONFLICT';end if;
  return old.receipt;
 end if;
 if not exists(select 1 from public.ns_automatic_commission_settings where org_id=p_org and enabled) then raise exception 'NS_MULTILINE_DISABLED';end if;
 select * into s from public.ns_sales where id=p_sale and org_id=p_org and site_id=p_site for update;
 if not found or s.status<>'posted' or s.customer_id is null then raise exception 'NS_MULTILINE_SALE';end if;
 if exists(select 1 from public.ns_commission_entries where sale_id=s.id) or exists(select 1 from public.ns_commission_settlements where sale_id=s.id) then raise exception 'NS_MULTILINE_CONFLICT';end if;
 perform 1 from public.ns_sale_lines where sale_id=s.id for update;
 if (select count(*) from public.ns_sale_lines where sale_id=s.id)<>n or exists(select 1 from public.ns_sale_lines where sale_id=s.id and (org_id<>p_org or site_id<>p_site or item_type<>'service' or quantity<>1 or unit_price_xaf<=discount_xaf)) then raise exception 'NS_MULTILINE_COVERAGE';end if;
 select sum(quantity*unit_price_xaf-discount_xaf) into total from public.ns_sale_lines where sale_id=s.id;
 if total<>s.total_xaf then raise exception 'NS_MULTILINE_TOTAL';end if;
 perform 1 from public.ns_payments where sale_id=s.id for update;
 if exists(select 1 from public.ns_payments where sale_id=s.id and (org_id<>p_org or site_id<>p_site or status in ('refunded','reversed'))) then raise exception 'NS_MULTILINE_REFUND';end if;
 select coalesce(sum(amount_xaf),0) into paid from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status='confirmed' and confirmed_at is not null;
 if paid<>s.total_xaf or paid<=0 then raise exception 'NS_MULTILINE_UNPAID';end if;
 for item in select value from jsonb_array_elements(canonical) loop
  line_id:=(item->>'line_id')::uuid;appointment_id:=(item->>'appointment_id')::uuid;
  select * into l from public.ns_sale_lines where id=line_id and sale_id=s.id and org_id=p_org and site_id=p_site;
  if not found then raise exception 'NS_MULTILINE_COVERAGE';end if;
  select * into a from public.ns_appointments where id=appointment_id and org_id=p_org and site_id=p_site for update;
  if not found or a.status<>'completed' or a.customer_id is distinct from s.customer_id or a.assigned_member_id is null or a.service_id is null or not exists(select 1 from public.ns_members where id=a.assigned_member_id and org_id=p_org and status='active') or not exists(select 1 from public.ns_services where id=a.service_id and org_id=p_org and (site_id is null or site_id=p_site)) then raise exception 'NS_MULTILINE_APPOINTMENT';end if;
  if exists(select 1 from public.ns_commission_allocation_batches b where exists(select 1 from jsonb_array_elements(b.allocation) x where (x->>'appointment_id')::uuid=a.id)) or exists(select 1 from public.ns_commission_entries c where c.appointment_id=a.id) or exists(select 1 from public.ns_commission_settlements t where t.appointment_id=a.id) then raise exception 'NS_MULTILINE_CONFLICT';end if;
  select (max(occurred_at) at time zone 'Africa/Douala')::date into d from public.ns_appointment_status_events where ns_appointment_status_events.appointment_id=a.id and org_id=p_org and site_id=p_site and to_status='completed';
  if d is null then raise exception 'NS_MULTILINE_COMPLETION_PROOF';end if;
  select count(*) into n from public.ns_commission_policy_versions v where v.org_id=p_org and v.automatic_scope and v.status='approved' and (v.site_id is null or v.site_id=p_site) and (v.member_id is null or v.member_id=a.assigned_member_id) and (v.service_id is null or v.service_id=a.service_id) and (v.activity_profile is null or v.activity_profile=profile) and d>=v.effective_from and (v.effective_until is null or d<=v.effective_until);
  if n>1 then raise exception 'NS_MULTILINE_AMBIGUOUS';end if;
  net:=l.quantity*l.unit_price_xaf-l.discount_xaf;
  if n=0 then result:=result||jsonb_build_array(item||jsonb_build_object('status','no_applicable_policy'));continue;end if;
  select * into p from public.ns_commission_policy_versions v where v.org_id=p_org and v.automatic_scope and v.status='approved' and (v.site_id is null or v.site_id=p_site) and (v.member_id is null or v.member_id=a.assigned_member_id) and (v.service_id is null or v.service_id=a.service_id) and (v.activity_profile is null or v.activity_profile=profile) and d>=v.effective_from and (v.effective_until is null or d<=v.effective_until);
  commission:=case when p.method='percent_bps' then trunc(net*p.rate_bps/10000)::bigint else p.fixed_amount_xaf end;
  if commission=0 then result:=result||jsonb_build_array(item||jsonb_build_object('status','no_commission'));continue;end if;
  eid:=gen_random_uuid();
  insert into public.ns_commission_entries(id,org_id,site_id,member_id,sale_id,appointment_id,base_amount_xaf,commission_xaf,status,policy_version_id,source_event_id,idempotency_key,calculation_snapshot)
  values(eid,p_org,p_site,a.assigned_member_id,s.id,a.id,net::bigint,commission,'pending_approval',p.id,a.id,eid,jsonb_build_object('source','explicit_multiline_reconciliation','sale_line_id',l.id,'batch_id',p_id,'completion_day',d,'policy_version',p.version));
  insert into public.ns_commission_settlements(org_id,site_id,appointment_id,sale_id,entry_id,created_by,sale_line_id) values(p_org,p_site,a.id,s.id,eid,actor,l.id);
  result:=result||jsonb_build_array(item||jsonb_build_object('status','pending_approval','entry_id',eid,'commission_xaf',commission));
 end loop;
 result:=jsonb_build_object('id',p_id,'status','prepared','lines',result);
 insert into public.ns_commission_allocation_batches(id,org_id,site_id,sale_id,actor_id,allocation,receipt) values(p_id,p_org,p_site,p_sale,actor,canonical,result);
 return result;
end $fn$;
revoke all on function public.ns_prepare_multiline_commissions(uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.ns_prepare_multiline_commissions(uuid,uuid,uuid,uuid,jsonb) to authenticated;
create or replace function public.ns_review_settled_commission(p_org uuid,p_site uuid,p_entry uuid,p_event uuid,p_decision text,p_reason text)
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
  if e.status<>'pending_approval' or a.status<>'completed' or s.status<>'posted' or paid<>s.total_xaf or (not exists(select 1 from public.ns_commission_settlements where entry_id=e.id and sale_line_id is not null) and paid<>e.base_amount_xaf) or (exists(select 1 from public.ns_commission_settlements where entry_id=e.id and sale_line_id is not null) and not exists(select 1 from public.ns_commission_settlements t join public.ns_sale_lines l on l.id=t.sale_line_id where t.entry_id=e.id and l.sale_id=s.id and l.org_id=p_org and l.site_id=p_site and l.item_type='service' and l.quantity*l.unit_price_xaf-l.discount_xaf=e.base_amount_xaf)) or exists(select 1 from public.ns_payments where sale_id=s.id and status in ('refunded','reversed')) then raise exception 'NS_COMMISSION_REVIEW_NOT_ELIGIBLE'; end if;
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

create or replace function public.ns_prepare_settled_commission(p_org uuid,p_site uuid,p_appointment uuid,p_sale uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare a public.ns_appointments%rowtype; s public.ns_sales%rowtype;
 actor uuid; profile text; completion_day date; paid numeric; n integer; policy public.ns_commission_policy_versions%rowtype;
 receipt public.ns_commission_settlements%rowtype; eid uuid; commission bigint;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN'; end if;
 select activity_profile into profile from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN'; end if;
 if exists(select 1 from public.ns_commission_allocation_batches b where b.sale_id=p_sale or exists(select 1 from jsonb_array_elements(b.allocation) x where (x->>'appointment_id')::uuid=p_appointment)) then raise exception 'NS_COMMISSION_SETTLEMENT_CONFLICT';end if;
 select * into receipt from public.ns_commission_settlements where appointment_id=p_appointment or sale_id=p_sale;
 if found then
  if receipt.org_id<>p_org or receipt.site_id<>p_site or receipt.appointment_id<>p_appointment or receipt.sale_id<>p_sale then raise exception 'NS_COMMISSION_SETTLEMENT_CONFLICT'; end if;
  return jsonb_build_object('status','existing','entry_id',receipt.entry_id);
 end if;
 if not exists(select 1 from public.ns_automatic_commission_settings where org_id=p_org and enabled) then return jsonb_build_object('status','disabled'); end if;
 select * into a from public.ns_appointments where id=p_appointment and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_SCOPE'; end if;
 select * into s from public.ns_sales where id=p_sale and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_SCOPE'; end if;
 if a.status<>'completed' or s.status<>'posted' then return jsonb_build_object('status','awaiting_completed_and_confirmed'); end if;
 if a.customer_id is null or a.customer_id is distinct from s.customer_id or a.service_id is null or a.assigned_member_id is null
 or not exists(select 1 from public.ns_services where id=a.service_id and org_id=p_org and (site_id is null or site_id=p_site))
 or not exists(select 1 from public.ns_members where id=a.assigned_member_id and org_id=p_org and status='active')
 then raise exception 'NS_COMMISSION_SETTLEMENT_SCOPE'; end if;
 select (max(occurred_at) at time zone 'Africa/Douala')::date into completion_day from public.ns_appointment_status_events where appointment_id=a.id and org_id=p_org and site_id=p_site and to_status='completed';
 if completion_day is null then raise exception 'NS_COMMISSION_COMPLETION_PROOF_REQUIRED'; end if;
 perform 1 from public.ns_sale_lines where sale_id=s.id and org_id=p_org and site_id=p_site for update;
 select count(*) into n from public.ns_sale_lines where sale_id=s.id;
 if n<>1 or not exists(select 1 from public.ns_sale_lines where sale_id=s.id and org_id=p_org and site_id=p_site and item_type='service' and quantity=1 and unit_price_xaf-discount_xaf=s.total_xaf)
 then return jsonb_build_object('status','unsupported_sale_allocation'); end if;
 perform 1 from public.ns_payments where sale_id=s.id for update;
 if exists(select 1 from public.ns_payments where sale_id=s.id and (org_id<>p_org or site_id<>p_site or status in ('refunded','reversed'))) then return jsonb_build_object('status','refund_review_required'); end if;
 select coalesce(sum(amount_xaf),0) into paid from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status='confirmed' and confirmed_at is not null;
 if paid<>s.total_xaf or paid<=0 then return jsonb_build_object('status','awaiting_completed_and_confirmed'); end if;
 select count(*) into n from public.ns_commission_policy_versions p where p.org_id=p_org and p.automatic_scope and p.status='approved' and (p.site_id is null or p.site_id=p_site) and (p.member_id is null or p.member_id=a.assigned_member_id) and (p.service_id is null or p.service_id=a.service_id) and (p.activity_profile is null or p.activity_profile=profile) and completion_day>=p.effective_from and (p.effective_until is null or completion_day<=p.effective_until);
 if n=0 then return jsonb_build_object('status','no_applicable_policy'); end if;
 if n<>1 then return jsonb_build_object('status','blocked_ambiguous_policy'); end if;
 select * into policy from public.ns_commission_policy_versions p where p.org_id=p_org and p.automatic_scope and p.status='approved' and (p.site_id is null or p.site_id=p_site) and (p.member_id is null or p.member_id=a.assigned_member_id) and (p.service_id is null or p.service_id=a.service_id) and (p.activity_profile is null or p.activity_profile=profile) and completion_day>=p.effective_from and (p.effective_until is null or completion_day<=p.effective_until);
 if exists(select 1 from public.ns_commission_entries where sale_id=s.id or appointment_id=a.id) then raise exception 'NS_COMMISSION_EXISTING_LEDGER_REVIEW'; end if;
 commission:=case when policy.method='percent_bps' then trunc(paid*policy.rate_bps/10000)::bigint else policy.fixed_amount_xaf end;
 if commission=0 then return jsonb_build_object('status','no_commission'); end if;
 eid:=gen_random_uuid();
 insert into public.ns_commission_entries(id,org_id,site_id,member_id,sale_id,appointment_id,base_amount_xaf,commission_xaf,status,policy_version_id,source_event_id,idempotency_key,calculation_snapshot)
 values(eid,p_org,p_site,a.assigned_member_id,s.id,a.id,paid::bigint,commission,'pending_approval',policy.id,a.id,eid,jsonb_build_object('source','explicit_single_service_reconciliation','completion_day',completion_day,'policy_version',policy.version,'confirmed_paid_xaf',paid));
 insert into public.ns_commission_settlements(org_id,site_id,appointment_id,sale_id,entry_id,created_by) values(p_org,p_site,a.id,s.id,eid,actor);
 return jsonb_build_object('status','pending_approval','entry_id',eid,'commission_xaf',commission);
end $fn$;

rollback;
