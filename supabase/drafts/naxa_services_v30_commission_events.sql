-- DRAFT ONLY. Event-driven reconciliation: explicit promoter allocation, no guessed assignment or payout.
begin;
create schema ns_commission_internal;
revoke all on schema ns_commission_internal from public,anon,authenticated,service_role;
create function ns_commission_internal.authorized_actor(p_org uuid,p_site uuid,p_actor uuid) returns boolean language plpgsql security definer set search_path='' as $fn$
begin
 -- Lock the real authorization rows, never fabricate a JWT or elevate a client.
 perform 1 from public.ns_members m join public.ns_accounts a on a.id=m.account_id join public.ns_member_scopes sc on sc.org_id=m.org_id and sc.member_id=m.id
 join public.ns_organizations o on o.id=m.org_id join public.ns_sites si on si.org_id=o.id and si.id=p_site
 where m.id=p_actor and m.org_id=p_org and m.role_code='promoter' and m.status='active' and a.status='active' and not a.password_change_required
 and sc.scope_type='organization' and sc.can_manage and o.status='active' and si.status='active' for share of m,a,sc,si;
 return found;
end $fn$;
revoke all on function ns_commission_internal.authorized_actor(uuid,uuid,uuid) from public,anon,authenticated,service_role;
-- Explicit promoter allocation, no assumed shares.
create function ns_commission_internal.normalize_shares(p_shares jsonb) returns jsonb language plpgsql immutable set search_path='' as $fn$
declare normalized jsonb;n integer;
begin
 if p_shares is null or jsonb_typeof(p_shares)<>'array' then raise exception 'NS_COMMISSION_SHARES_INVALID';end if;
 n:=jsonb_array_length(p_shares);
 if n not between 2 and 20 or exists(select 1 from jsonb_array_elements(p_shares) x where jsonb_typeof(x)<>'object' or coalesce(x->>'member_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or jsonb_typeof(x->'share_bps') is distinct from 'number' or coalesce(x->>'share_bps','') !~ '^[0-9]{1,5}$') then raise exception 'NS_COMMISSION_SHARES_INVALID';end if;
 if exists(select 1 from jsonb_array_elements(p_shares) x where (x->>'share_bps')::integer not between 1 and 10000) or (select count(distinct (x->>'member_id')::uuid) from jsonb_array_elements(p_shares) x)<>n or (select sum((x->>'share_bps')::integer) from jsonb_array_elements(p_shares) x)<>10000 then raise exception 'NS_COMMISSION_SHARES_INVALID';end if;
 select jsonb_agg(jsonb_build_object('member_id',(x->>'member_id')::uuid,'share_bps',(x->>'share_bps')::integer) order by (x->>'member_id')::uuid) into normalized from jsonb_array_elements(p_shares) x;
 return normalized;
end $fn$;
revoke all on function ns_commission_internal.normalize_shares(jsonb) from public,anon,authenticated,service_role;
alter table public.ns_commission_settlements drop constraint ns_commission_settlements_pkey,drop constraint ns_commission_settlements_appointment_id_key,drop constraint ns_commission_settlements_sale_line_id_key;
alter table public.ns_commission_settlements add primary key(entry_id),add column allocation_member_id uuid,add foreign key(allocation_member_id,org_id) references public.ns_members(id,org_id);
create unique index ns_commission_settlement_unshared_appt on public.ns_commission_settlements(appointment_id) where allocation_member_id is null;
create unique index ns_commission_settlement_unshared_line on public.ns_commission_settlements(sale_line_id) where allocation_member_id is null;
create unique index ns_commission_settlement_shared_line_member on public.ns_commission_settlements(sale_line_id,allocation_member_id) where allocation_member_id is not null;
create or replace function public.ns_register_commission_plan(p_org uuid,p_site uuid,p_sale uuid,p_id uuid,p_allocations jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; s public.ns_sales%rowtype; a public.ns_appointments%rowtype; old public.ns_commission_reconciliation_plans%rowtype;
 item jsonb; canonical jsonb; n integer; aid uuid; lid uuid;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 if p_id is null or p_sale is null or p_allocations is null or jsonb_typeof(p_allocations)<>'array' then raise exception 'NS_COMMISSION_PLAN_INVALID';end if;
 n:=jsonb_array_length(p_allocations);
 if n not between 1 and 30 or exists(select 1 from jsonb_array_elements(p_allocations) x where jsonb_typeof(x)<>'object' or coalesce(x->>'line_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or coalesce(x->>'appointment_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'NS_COMMISSION_PLAN_INVALID';end if;
 select jsonb_agg((jsonb_build_object('line_id',(x->>'line_id')::uuid,'appointment_id',(x->>'appointment_id')::uuid)||case when x?'shares' then jsonb_build_object('shares',ns_commission_internal.normalize_shares(x->'shares')) else '{}'::jsonb end) order by (x->>'line_id')::uuid) into canonical from jsonb_array_elements(p_allocations) x;
 if (select count(distinct x->>'line_id') from jsonb_array_elements(canonical) x)<>n or (select count(distinct x->>'appointment_id') from jsonb_array_elements(canonical) x)<>n then raise exception 'NS_COMMISSION_PLAN_DUPLICATE';end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 select * into old from public.ns_commission_reconciliation_plans where id=p_id or sale_id=p_sale;
 if found then
  if old.id<>p_id or old.org_id<>p_org or old.site_id<>p_site or old.sale_id<>p_sale or old.actor_id<>actor or old.allocation<>canonical then raise exception 'NS_COMMISSION_PLAN_CONFLICT';end if;
  return jsonb_build_object('id',old.id,'state',old.state);
 end if;
 if not exists(select 1 from public.ns_automatic_commission_settings where org_id=p_org and enabled) then raise exception 'NS_COMMISSION_PLAN_DISABLED';end if;
 select * into s from public.ns_sales where id=p_sale and org_id=p_org and site_id=p_site for update;
 if not found or s.status not in ('draft','posted') or s.customer_id is null then raise exception 'NS_COMMISSION_PLAN_SALE';end if;
 if exists(select 1 from public.ns_commission_entries where sale_id=s.id) or exists(select 1 from public.ns_commission_settlements where sale_id=s.id) or exists(select 1 from public.ns_commission_allocation_batches where sale_id=s.id) then raise exception 'NS_COMMISSION_PLAN_CONFLICT';end if;
 if (select count(*) from public.ns_sale_lines where sale_id=s.id)<>n then raise exception 'NS_COMMISSION_PLAN_COVERAGE';end if;
 for item in select value from jsonb_array_elements(canonical) loop
  lid:=(item->>'line_id')::uuid;aid:=(item->>'appointment_id')::uuid;
  if not exists(select 1 from public.ns_sale_lines where id=lid and sale_id=s.id and org_id=p_org and site_id=p_site and item_type='service' and quantity=1) then raise exception 'NS_COMMISSION_PLAN_COVERAGE';end if;
  select * into a from public.ns_appointments where id=aid and org_id=p_org and site_id=p_site for update;
  if not found or a.status in ('cancelled','no_show') or a.customer_id is distinct from s.customer_id or a.service_id is null or a.assigned_member_id is null then raise exception 'NS_COMMISSION_PLAN_APPOINTMENT';end if;
  if item?'shares' then
   if not exists(select 1 from jsonb_array_elements(item->'shares') x where (x->>'member_id')::uuid=a.assigned_member_id) then raise exception 'NS_COMMISSION_SHARES_SCOPE';end if;
   if exists(select 1 from jsonb_array_elements(item->'shares') x where not exists(select 1 from public.ns_members mm join public.ns_accounts aa on aa.id=mm.account_id join public.ns_member_scopes sc on sc.member_id=mm.id and sc.org_id=mm.org_id where mm.id=(x->>'member_id')::uuid and mm.org_id=p_org and mm.status='active' and aa.status='active' and (sc.can_operate or sc.can_manage) and (sc.scope_type='organization' or sc.site_id=p_site))) then raise exception 'NS_COMMISSION_SHARES_SCOPE';end if;
  end if;
  if exists(select 1 from public.ns_commission_plan_appointments where appointment_id=aid) or exists(select 1 from public.ns_commission_entries where appointment_id=aid) or exists(select 1 from public.ns_commission_allocation_batches b where exists(select 1 from jsonb_array_elements(b.allocation) x where (x->>'appointment_id')::uuid=aid)) then raise exception 'NS_COMMISSION_PLAN_CONFLICT';end if;
 end loop;
 insert into public.ns_commission_reconciliation_plans(id,org_id,site_id,sale_id,actor_id,allocation) values(p_id,p_org,p_site,s.id,actor,canonical);
 insert into public.ns_commission_plan_appointments(appointment_id,plan_id) select (x->>'appointment_id')::uuid,p_id from jsonb_array_elements(canonical) x;
 return jsonb_build_object('id',p_id,'state','waiting');
end $fn$;
create function ns_commission_internal.ns_prepare_settled_commission(p_org uuid,p_site uuid,p_appointment uuid,p_sale uuid,p_actor uuid,p_plan uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare a public.ns_appointments%rowtype; s public.ns_sales%rowtype;
 actor uuid; profile text; completion_day date; paid numeric; n integer; policy public.ns_commission_policy_versions%rowtype;
 receipt public.ns_commission_settlements%rowtype; eid uuid; commission bigint;
begin
 actor:=p_actor;
 if not ns_commission_internal.authorized_actor(p_org,p_site,p_actor) then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN';end if;
 select activity_profile into profile from public.ns_organizations where id=p_org and status='active' for no key update;
 if not found then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN'; end if;
 if exists(select 1 from public.ns_commission_reconciliation_plans r where (r.sale_id=p_sale or exists(select 1 from public.ns_commission_plan_appointments reserved_appt where reserved_appt.plan_id=r.id and reserved_appt.appointment_id=p_appointment)) and r.id is distinct from p_plan) then raise exception 'NS_COMMISSION_SETTLEMENT_RESERVED';end if;
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
revoke all on function ns_commission_internal.ns_prepare_settled_commission(uuid,uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
create or replace function public.ns_prepare_settled_commission(p_org uuid,p_site uuid,p_appointment uuid,p_sale uuid) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid:=public.ns_current_member_id(p_org);
begin
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_SETTLEMENT_FORBIDDEN';end if;
 return ns_commission_internal.ns_prepare_settled_commission(p_org,p_site,p_appointment,p_sale,actor,null);
end $fn$;
revoke all on function public.ns_prepare_settled_commission(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_prepare_settled_commission(uuid,uuid,uuid,uuid) to authenticated;
create function ns_commission_internal.ns_prepare_multiline_commissions(p_org uuid,p_site uuid,p_sale uuid,p_id uuid,p_allocations jsonb,p_actor uuid,p_plan uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; profile text; s public.ns_sales%rowtype; a public.ns_appointments%rowtype; l public.ns_sale_lines%rowtype;
 old public.ns_commission_allocation_batches%rowtype; p public.ns_commission_policy_versions%rowtype;
 line_id uuid; appointment_id uuid; item jsonb; canonical jsonb; result jsonb:='[]'::jsonb; paid numeric; net numeric; total numeric; d date; n integer; eid uuid; commission bigint; sh record; shares jsonb; shared boolean; entries jsonb;
begin
 actor:=p_actor;
 if not ns_commission_internal.authorized_actor(p_org,p_site,p_actor) then raise exception 'NS_MULTILINE_FORBIDDEN';end if;
 if p_id is null or p_sale is null or p_allocations is null or jsonb_typeof(p_allocations)<>'array' then raise exception 'NS_MULTILINE_INVALID';end if;
 n:=jsonb_array_length(p_allocations);if n not between 1 and 30 or (n=1 and not (p_allocations->0?'shares')) then raise exception 'NS_MULTILINE_INVALID';end if;
 if exists(select 1 from jsonb_array_elements(p_allocations) x where jsonb_typeof(x)<>'object' or not (x?'line_id' and x?'appointment_id') or coalesce(x->>'line_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or coalesce(x->>'appointment_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'NS_MULTILINE_INVALID';end if;
 select jsonb_agg((jsonb_build_object('line_id',(x->>'line_id')::uuid,'appointment_id',(x->>'appointment_id')::uuid)||case when x?'shares' then jsonb_build_object('shares',ns_commission_internal.normalize_shares(x->'shares')) else '{}'::jsonb end) order by (x->>'line_id')::uuid) into canonical from jsonb_array_elements(p_allocations) x;
 if (select count(distinct x->>'line_id') from jsonb_array_elements(canonical) x)<>n or (select count(distinct x->>'appointment_id') from jsonb_array_elements(canonical) x)<>n then raise exception 'NS_MULTILINE_DUPLICATE';end if;
 select activity_profile into profile from public.ns_organizations where id=p_org and status='active' for no key update;
 if not found then raise exception 'NS_MULTILINE_FORBIDDEN';end if;
 if exists(select 1 from public.ns_commission_reconciliation_plans r where (r.sale_id=p_sale or exists(select 1 from public.ns_commission_plan_appointments reserved_appt where reserved_appt.plan_id=r.id and reserved_appt.appointment_id in (select (x->>'appointment_id')::uuid from jsonb_array_elements(canonical) x))) and r.id is distinct from p_plan) then raise exception 'NS_MULTILINE_RESERVED';end if;
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
  if item?'shares' then
   if not exists(select 1 from jsonb_array_elements(item->'shares') x where (x->>'member_id')::uuid=a.assigned_member_id) then raise exception 'NS_COMMISSION_SHARES_SCOPE';end if;
   if exists(select 1 from jsonb_array_elements(item->'shares') x where not exists(select 1 from public.ns_members mm join public.ns_accounts aa on aa.id=mm.account_id join public.ns_member_scopes sc on sc.member_id=mm.id and sc.org_id=mm.org_id where mm.id=(x->>'member_id')::uuid and mm.org_id=p_org and mm.status='active' and aa.status='active' and (sc.can_operate or sc.can_manage) and (sc.scope_type='organization' or sc.site_id=p_site))) then raise exception 'NS_COMMISSION_SHARES_SCOPE';end if;
  end if;
  shared:=item?'shares';
  shares:=case when shared then item->'shares' else jsonb_build_array(jsonb_build_object('member_id',a.assigned_member_id,'share_bps',10000)) end;
  select count(*) into n from public.ns_commission_policy_versions v where v.org_id=p_org and v.automatic_scope and v.status='approved' and (v.site_id is null or v.site_id=p_site) and (v.member_id is null or exists(select 1 from jsonb_array_elements(shares) ss where (ss->>'member_id')::uuid=v.member_id)) and (v.service_id is null or v.service_id=a.service_id) and (v.activity_profile is null or v.activity_profile=profile) and d>=v.effective_from and (v.effective_until is null or d<=v.effective_until);
  if n>1 then raise exception 'NS_MULTILINE_AMBIGUOUS';end if;
  net:=l.quantity*l.unit_price_xaf-l.discount_xaf;
  if n=0 then result:=result||jsonb_build_array(item||jsonb_build_object('status','no_applicable_policy'));continue;end if;
  select * into p from public.ns_commission_policy_versions v where v.org_id=p_org and v.automatic_scope and v.status='approved' and (v.site_id is null or v.site_id=p_site) and (v.member_id is null or exists(select 1 from jsonb_array_elements(shares) ss where (ss->>'member_id')::uuid=v.member_id)) and (v.service_id is null or v.service_id=a.service_id) and (v.activity_profile is null or v.activity_profile=profile) and d>=v.effective_from and (v.effective_until is null or d<=v.effective_until);
  if shared and p.member_id is not null then raise exception 'NS_MULTILINE_AMBIGUOUS';end if;
  commission:=case when p.method='percent_bps' then trunc(net*p.rate_bps/10000)::bigint else p.fixed_amount_xaf end;
  if commission=0 then result:=result||jsonb_build_array(item||jsonb_build_object('status','no_commission'));continue;end if;
  if not shared then
  eid:=gen_random_uuid();
  insert into public.ns_commission_entries(id,org_id,site_id,member_id,sale_id,appointment_id,base_amount_xaf,commission_xaf,status,policy_version_id,source_event_id,idempotency_key,calculation_snapshot)
  values(eid,p_org,p_site,a.assigned_member_id,s.id,a.id,net::bigint,commission,'pending_approval',p.id,a.id,eid,jsonb_build_object('source','explicit_multiline_reconciliation','sale_line_id',l.id,'batch_id',p_id,'completion_day',d,'policy_version',p.version));
  insert into public.ns_commission_settlements(org_id,site_id,appointment_id,sale_id,entry_id,created_by,sale_line_id) values(p_org,p_site,a.id,s.id,eid,actor,l.id);
  result:=result||jsonb_build_array(item||jsonb_build_object('status','pending_approval','entry_id',eid,'commission_xaf',commission));
  else
   entries:='[]'::jsonb;
   for sh in
    with parts as (select (x->>'member_id')::uuid mid,(x->>'share_bps')::integer bps,trunc(net*(x->>'share_bps')::numeric/10000)::bigint base_part,trunc(commission*(x->>'share_bps')::numeric/10000)::bigint comm_part from jsonb_array_elements(shares) x),
    ranked as (select parts.*,row_number() over(order by mid) rn,sum(base_part) over() base_sum,sum(comm_part) over() comm_sum from parts)
    select mid,bps,base_part+case when rn<=net-base_sum then 1 else 0 end allocated_base,comm_part+case when rn<=commission-comm_sum then 1 else 0 end allocated_commission from ranked order by mid
   loop
    eid:=gen_random_uuid();
    insert into public.ns_commission_entries(id,org_id,site_id,member_id,sale_id,appointment_id,base_amount_xaf,commission_xaf,status,policy_version_id,source_event_id,idempotency_key,calculation_snapshot)
    values(eid,p_org,p_site,sh.mid,s.id,a.id,sh.allocated_base,sh.allocated_commission,'pending_approval',p.id,a.id,eid,jsonb_build_object('source','explicit_shared_line','sale_line_id',l.id,'batch_id',p_id,'completion_day',d,'policy_version',p.version,'line_base_xaf',net::bigint,'share_bps',sh.bps));
    insert into public.ns_commission_settlements(org_id,site_id,appointment_id,sale_id,entry_id,created_by,sale_line_id,allocation_member_id) values(p_org,p_site,a.id,s.id,eid,actor,l.id,sh.mid);
    entries:=entries||jsonb_build_array(jsonb_build_object('entry_id',eid,'member_id',sh.mid,'commission_xaf',sh.allocated_commission));
   end loop;
   result:=result||jsonb_build_array(item||jsonb_build_object('status','pending_approval','entries',entries,'commission_xaf',commission));
  end if;
 end loop;
 result:=jsonb_build_object('id',p_id,'status','prepared','lines',result);
 insert into public.ns_commission_allocation_batches(id,org_id,site_id,sale_id,actor_id,allocation,receipt) values(p_id,p_org,p_site,p_sale,actor,canonical,result);
 return result;
end $fn$;
revoke all on function ns_commission_internal.ns_prepare_multiline_commissions(uuid,uuid,uuid,uuid,jsonb,uuid,uuid) from public,anon,authenticated,service_role;
create or replace function public.ns_prepare_multiline_commissions(p_org uuid,p_site uuid,p_sale uuid,p_id uuid,p_allocations jsonb) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid:=public.ns_current_member_id(p_org);
begin
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_MULTILINE_FORBIDDEN';end if;
 return ns_commission_internal.ns_prepare_multiline_commissions(p_org,p_site,p_sale,p_id,p_allocations,actor,null);
end $fn$;
revoke all on function public.ns_prepare_multiline_commissions(uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.ns_prepare_multiline_commissions(uuid,uuid,uuid,uuid,jsonb) to authenticated;
create function ns_commission_internal.ns_process_commission_plan(p_org uuid,p_site uuid,p_id uuid,p_actor uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare t public.ns_commission_reconciliation_plans%rowtype; s public.ns_sales%rowtype; paid numeric; r jsonb; outcome text;
begin
 if not ns_commission_internal.authorized_actor(p_org,p_site,p_actor) then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for no key update;
 if not found then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 select * into t from public.ns_commission_reconciliation_plans where id=p_id and org_id=p_org and site_id=p_site for no key update;
 if not found then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 if t.state<>'waiting' then return jsonb_build_object('id',t.id,'state',t.state,'receipt',t.receipt);end if;
 if not exists(select 1 from public.ns_automatic_commission_settings where org_id=p_org and enabled) then return jsonb_build_object('id',t.id,'state','waiting','reason','disabled');end if;
 select * into s from public.ns_sales where id=t.sale_id and org_id=p_org and site_id=p_site for update;
 if not found then raise exception 'NS_COMMISSION_PLAN_SALE';end if;
 if s.status in ('refunded','voided') or exists(select 1 from public.ns_commission_plan_appointments l join public.ns_appointments a on a.id=l.appointment_id where l.plan_id=t.id and a.status in ('cancelled','no_show')) then
  r:=jsonb_build_object('status','source_cancelled');outcome:='review_required';
 else
  perform 1 from public.ns_payments where sale_id=s.id for update;
  if exists(select 1 from public.ns_payments where sale_id=s.id and (org_id<>p_org or site_id<>p_site or status in ('refunded','reversed'))) then
   r:=jsonb_build_object('status','refund_review_required');outcome:='review_required';
  else
   select coalesce(sum(amount_xaf),0) into paid from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status='confirmed' and confirmed_at is not null;
   if s.status<>'posted' or paid<>s.total_xaf or paid<=0 or exists(select 1 from public.ns_commission_plan_appointments l join public.ns_appointments a on a.id=l.appointment_id where l.plan_id=t.id and a.status<>'completed') then return jsonb_build_object('id',t.id,'state','waiting','reason','awaiting_completed_and_confirmed');end if;
   begin
    -- Existing transactional calculation; no new commission formula. Exact plan line is checked again by existing functions.
    if jsonb_array_length(t.allocation)=1 and not (t.allocation->0?'shares') then
     if not exists(select 1 from public.ns_sale_lines where id=(t.allocation->0->>'line_id')::uuid and sale_id=s.id and org_id=p_org and site_id=p_site) then raise exception 'NS_COMMISSION_PLAN_COVERAGE';end if;
     r:=ns_commission_internal.ns_prepare_settled_commission(p_org,p_site,(t.allocation->0->>'appointment_id')::uuid,s.id,p_actor,t.id);
    else
     r:=ns_commission_internal.ns_prepare_multiline_commissions(p_org,p_site,s.id,t.id,t.allocation,p_actor,t.id);
    end if;
    outcome:=case when r->>'status' in ('pending_approval','existing','prepared','no_applicable_policy','no_commission') then 'processed' else 'review_required' end;
   exception when raise_exception then
    if sqlerrm not like 'NS_COMMISSION_%' and sqlerrm not like 'NS_MULTILINE_%' then raise;end if;
    r:=jsonb_build_object('status','reconciliation_conflict','code',sqlerrm);outcome:='review_required';
   end;
  end if;
 end if;
 update public.ns_commission_reconciliation_plans set state=outcome,receipt=r,processed_at=now() where id=t.id;
 return jsonb_build_object('id',t.id,'state',outcome,'receipt',r);
end $fn$;
revoke all on function ns_commission_internal.ns_process_commission_plan(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
create or replace function public.ns_process_commission_plan(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid:=public.ns_current_member_id(p_org);
begin
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 return ns_commission_internal.ns_process_commission_plan(p_org,p_site,p_id,actor);
end $fn$;
revoke all on function public.ns_process_commission_plan(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_process_commission_plan(uuid,uuid,uuid) to authenticated;

-- Append-only wakeups: no queue-row lock is taken by a source transaction while a worker holds domain locks.
create table ns_commission_internal.events(id bigint generated always as identity primary key,plan_id uuid not null references public.ns_commission_reconciliation_plans(id) on delete cascade,created_at timestamptz not null default now());
alter table ns_commission_internal.events enable row level security;
revoke all on ns_commission_internal.events from public,anon,authenticated,service_role;
create index ns_commission_events_plan_idx on ns_commission_internal.events(plan_id);
create function ns_commission_internal.wake() returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 if tg_table_name='ns_commission_reconciliation_plans' then
  if new.state='waiting' then insert into ns_commission_internal.events(plan_id) values(new.id);end if;
 elsif tg_table_name='ns_appointments' then
  insert into ns_commission_internal.events(plan_id) select p.id from public.ns_commission_reconciliation_plans p join public.ns_commission_plan_appointments a on a.plan_id=p.id where a.appointment_id=new.id and p.state='waiting';
 elsif tg_table_name='ns_appointment_status_events' then
  insert into ns_commission_internal.events(plan_id) select p.id from public.ns_commission_reconciliation_plans p join public.ns_commission_plan_appointments a on a.plan_id=p.id where a.appointment_id=new.appointment_id and p.state='waiting';
 elsif tg_table_name='ns_payments' then
  insert into ns_commission_internal.events(plan_id) select id from public.ns_commission_reconciliation_plans where sale_id=new.sale_id and state='waiting';
 elsif tg_table_name='ns_sales' then
  insert into ns_commission_internal.events(plan_id) select id from public.ns_commission_reconciliation_plans where sale_id=new.id and state='waiting';
 elsif tg_table_name='ns_automatic_commission_settings' then
  if new.enabled then insert into ns_commission_internal.events(plan_id) select id from public.ns_commission_reconciliation_plans where org_id=new.org_id and state='waiting';end if;
 end if;
 return new;
end $fn$;
revoke all on function ns_commission_internal.wake() from public,anon,authenticated,service_role;
create trigger ns_commission_wake_registration after insert on public.ns_commission_reconciliation_plans for each row execute function ns_commission_internal.wake();
create trigger ns_commission_wake_appointment after update of status on public.ns_appointments for each row when (old.status is distinct from new.status) execute function ns_commission_internal.wake();
create trigger ns_commission_wake_completion after insert on public.ns_appointment_status_events for each row execute function ns_commission_internal.wake();
create trigger ns_commission_wake_payment after insert or update of status,confirmed_at on public.ns_payments for each row execute function ns_commission_internal.wake();
create trigger ns_commission_wake_sale after update of status on public.ns_sales for each row when (old.status is distinct from new.status) execute function ns_commission_internal.wake();
create trigger ns_commission_wake_settings after insert or update of enabled on public.ns_automatic_commission_settings for each row execute function ns_commission_internal.wake();
insert into ns_commission_internal.events(plan_id) select id from public.ns_commission_reconciliation_plans where state='waiting';
-- One event per transaction. Concurrent workers may read the same event; organization lock and idempotent ledger prevent duplicate writes.
-- Only the trusted worker role may invoke this RPC. It is not a client API and accepts no actor or amount.
create function public.ns_process_next_commission_event() returns jsonb language plpgsql security definer set search_path='' as $fn$
declare e ns_commission_internal.events%rowtype;t public.ns_commission_reconciliation_plans%rowtype;r jsonb;
begin
 select * into e from ns_commission_internal.events order by id limit 1;
 if not found then return jsonb_build_object('state','empty');end if;
 select * into t from public.ns_commission_reconciliation_plans where id=e.plan_id;
 if not found then delete from ns_commission_internal.events where id=e.id;return jsonb_build_object('state','discarded');end if;
 perform 1 from public.ns_organizations where id=t.org_id for no key update;
 select * into t from public.ns_commission_reconciliation_plans where id=e.plan_id for no key update;
 if not found then delete from ns_commission_internal.events where id=e.id;return jsonb_build_object('state','discarded');end if;
 if t.state<>'waiting' then r:=jsonb_build_object('id',t.id,'state',t.state);
 elsif not ns_commission_internal.authorized_actor(t.org_id,t.site_id,t.actor_id) then
  r:=jsonb_build_object('status','authorization_revoked');
  update public.ns_commission_reconciliation_plans set state='review_required',receipt=r,processed_at=now() where id=t.id;
  r:=jsonb_build_object('id',t.id,'state','review_required');
 else
  r:=ns_commission_internal.ns_process_commission_plan(t.org_id,t.site_id,t.id,t.actor_id);
 end if;
 delete from ns_commission_internal.events where id=e.id;
 return r;
end $fn$;
revoke all on function public.ns_process_next_commission_event() from public,anon,authenticated;
grant execute on function public.ns_process_next_commission_event() to service_role;
create or replace function public.ns_review_settled_commission(p_org uuid,p_site uuid,p_entry uuid,p_event uuid,p_decision text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; e public.ns_commission_entries%rowtype; old_event public.ns_commission_review_events%rowtype;
 s public.ns_sales%rowtype; a public.ns_appointments%rowtype; paid numeric; next_status text; prior text; previous_reversal numeric;
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
  if e.status<>'pending_approval' or a.status<>'completed' or s.status<>'posted' or paid<>s.total_xaf or (not exists(select 1 from public.ns_commission_settlements where entry_id=e.id and sale_line_id is not null) and paid<>e.base_amount_xaf) or (exists(select 1 from public.ns_commission_settlements where entry_id=e.id and sale_line_id is not null) and not exists(select 1 from public.ns_commission_settlements t join public.ns_sale_lines l on l.id=t.sale_line_id where t.entry_id=e.id and l.sale_id=s.id and l.org_id=p_org and l.site_id=p_site and l.item_type='service' and l.quantity*l.unit_price_xaf-l.discount_xaf=case when t.allocation_member_id is not null then (e.calculation_snapshot->>'line_base_xaf')::numeric else e.base_amount_xaf end)) or exists(select 1 from public.ns_payments where sale_id=s.id and status in ('refunded','reversed')) then raise exception 'NS_COMMISSION_REVIEW_NOT_ELIGIBLE'; end if;
  next_status:='approved';
  update public.ns_commission_entries set status=next_status,approved_by=actor,approved_at=now() where id=e.id;
 elsif p_decision='reject' then
  if e.status<>'pending_approval' then raise exception 'NS_COMMISSION_REVIEW_NOT_ELIGIBLE'; end if;
  next_status:='reversed';
  update public.ns_commission_entries set status=next_status where id=e.id;
 else
  -- Final refund reverses only the balance not already adjusted.
  select coalesce(sum(-amount_delta_xaf),0) into previous_reversal from public.ns_commission_adjustments where commission_entry_id=e.id and adjustment_type='refund_reversal';
  if e.status not in ('approved','paid') or s.status not in ('refunded','voided') or paid<>0 or not exists(select 1 from public.ns_payments where sale_id=s.id and org_id=p_org and site_id=p_site and status in ('refunded','reversed')) or previous_reversal>e.commission_xaf or exists(select 1 from public.ns_commission_adjustments where commission_entry_id=e.id and (adjustment_type<>'refund_reversal' or amount_delta_xaf>=0)) then raise exception 'NS_COMMISSION_REFUND_PROOF_REQUIRED'; end if;
  if e.commission_xaf>previous_reversal then insert into public.ns_commission_adjustments(org_id,site_id,commission_entry_id,source_event_id,idempotency_key,adjustment_type,amount_delta_xaf,reason,created_by)
   values(p_org,p_site,e.id,p_event,p_event,'refund_reversal',-(e.commission_xaf-previous_reversal)::bigint,trim(p_reason),actor);end if;
  next_status:='reversed';
  update public.ns_commission_entries set status=next_status where id=e.id;
 end if;
 insert into public.ns_commission_review_events(id,org_id,site_id,entry_id,actor_id,decision,reason,previous_status,next_status) values(p_event,p_org,p_site,p_entry,actor,p_decision,trim(p_reason),prior,next_status);
 return jsonb_build_object('entry_id',p_entry,'status',next_status,'replayed',false);
end $fn$;
-- Confirmed refund proof, explicit approved allocation, append-only ledger.
create table ns_commission_internal.refund_batches(
 id uuid primary key,org_id uuid not null,site_id uuid not null,payment_id uuid not null unique references public.ns_payments(id),actor_id uuid not null,
 allocations jsonb not null,reason text not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),foreign key(actor_id,org_id) references public.ns_members(id,org_id)
);
create table ns_commission_internal.refund_parts(
 batch_id uuid not null references ns_commission_internal.refund_batches(id),entry_id uuid not null references public.ns_commission_entries(id),
 refund_base_xaf bigint not null check(refund_base_xaf>0),reversed_commission_xaf bigint not null check(reversed_commission_xaf>=0),
 adjustment_id uuid unique references public.ns_commission_adjustments(id),primary key(batch_id,entry_id),
 check((reversed_commission_xaf=0)=(adjustment_id is null))
);
alter table ns_commission_internal.refund_batches enable row level security;
alter table ns_commission_internal.refund_parts enable row level security;
revoke all on ns_commission_internal.refund_batches,ns_commission_internal.refund_parts from public,anon,authenticated,service_role;
create function public.ns_reverse_partial_commissions(p_org uuid,p_site uuid,p_payment uuid,p_event uuid,p_allocations jsonb,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid:=public.ns_current_member_id(p_org); pay public.ns_payments%rowtype; sale public.ns_sales%rowtype; e public.ns_commission_entries%rowtype; old ns_commission_internal.refund_batches%rowtype;
 canonical jsonb; item jsonb; count_items integer; paid numeric; refunded numeric; assigned_base numeric; assigned_delta numeric; prior_base numeric; prior_delta numeric; delta bigint; refund_base bigint; adj uuid; receipt jsonb;
begin
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_PARTIAL_REFUND_FORBIDDEN';end if;
 if p_payment is null or p_event is null or p_allocations is null or jsonb_typeof(p_allocations)<>'array' or length(trim(coalesce(p_reason,''))) not between 4 and 500 then raise exception 'NS_PARTIAL_REFUND_INVALID';end if;
 count_items:=jsonb_array_length(p_allocations);
 if count_items not between 1 and 100 or exists(select 1 from jsonb_array_elements(p_allocations) x where jsonb_typeof(x)<>'object' or coalesce(x->>'entry_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or jsonb_typeof(x->'refund_base_xaf') is distinct from 'number' or jsonb_typeof(x->'commission_xaf') is distinct from 'number' or coalesce(x->>'refund_base_xaf','') !~ '^[0-9]{1,15}$' or coalesce(x->>'commission_xaf','') !~ '^[0-9]{1,15}$') then raise exception 'NS_PARTIAL_REFUND_INVALID';end if;
 if (select count(distinct (x->>'entry_id')::uuid) from jsonb_array_elements(p_allocations) x)<>count_items or exists(select 1 from jsonb_array_elements(p_allocations) x where (x->>'refund_base_xaf')::bigint<=0) then raise exception 'NS_PARTIAL_REFUND_INVALID';end if;
 select jsonb_agg(jsonb_build_object('entry_id',(x->>'entry_id')::uuid,'refund_base_xaf',(x->>'refund_base_xaf')::bigint,'commission_xaf',(x->>'commission_xaf')::bigint) order by (x->>'entry_id')::uuid),sum((x->>'refund_base_xaf')::bigint),sum((x->>'commission_xaf')::bigint) into canonical,assigned_base,assigned_delta from jsonb_array_elements(p_allocations) x;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_PARTIAL_REFUND_FORBIDDEN';end if;
 select * into old from ns_commission_internal.refund_batches where id=p_event or payment_id=p_payment;
 if found then
  if old.id<>p_event or old.org_id<>p_org or old.site_id<>p_site or old.payment_id<>p_payment or old.actor_id<>actor or old.allocations<>canonical or old.reason<>trim(p_reason) then raise exception 'NS_PARTIAL_REFUND_CONFLICT';end if;
  return old.receipt;
 end if;
 select * into pay from public.ns_payments where id=p_payment and org_id=p_org and site_id=p_site and status in ('refunded','reversed') and confirmed_at is not null and sale_id is not null for update;
 if not found then raise exception 'NS_PARTIAL_REFUND_PROOF';end if;
 select * into sale from public.ns_sales where id=pay.sale_id and org_id=p_org and site_id=p_site and status='posted' for update;
 if not found then raise exception 'NS_PARTIAL_REFUND_PROOF';end if;
 perform 1 from public.ns_payments where sale_id=sale.id for update;
 if exists(select 1 from public.ns_payments where sale_id=sale.id and (org_id<>p_org or site_id<>p_site)) then raise exception 'NS_PARTIAL_REFUND_PROOF';end if;
 select coalesce(sum(amount_xaf) filter(where status='confirmed' and confirmed_at is not null),0),coalesce(sum(amount_xaf) filter(where status in ('refunded','reversed') and confirmed_at is not null),0) into paid,refunded from public.ns_payments where sale_id=sale.id;
 if paid<=0 or refunded<=0 or paid+refunded<>sale.total_xaf or assigned_base>pay.amount_xaf then raise exception 'NS_PARTIAL_REFUND_PROOF';end if;
 -- All entries must be original scoped, approved ledger entries of this exact sale.
 receipt:=jsonb_build_object('id',p_event,'status','recorded','refund_xaf',pay.amount_xaf,'allocated_refund_xaf',assigned_base,'commission_reversed_xaf',assigned_delta);
 insert into ns_commission_internal.refund_batches(id,org_id,site_id,payment_id,actor_id,allocations,reason,receipt) values(p_event,p_org,p_site,p_payment,actor,canonical,trim(p_reason),receipt);
 for item in select value from jsonb_array_elements(canonical) loop
  select c.* into e from public.ns_commission_entries c join public.ns_commission_settlements t on t.entry_id=c.id and t.org_id=c.org_id and t.site_id=c.site_id where c.id=(item->>'entry_id')::uuid and c.org_id=p_org and c.site_id=p_site and c.sale_id=sale.id and c.status in ('approved','paid') for update of c;
  if not found then raise exception 'NS_PARTIAL_REFUND_SCOPE';end if;
  refund_base:=(item->>'refund_base_xaf')::bigint;delta:=(item->>'commission_xaf')::bigint;
  select coalesce(sum(refund_base_xaf),0) into prior_base from ns_commission_internal.refund_parts where entry_id=e.id;
  select coalesce(sum(-amount_delta_xaf),0) into prior_delta from public.ns_commission_adjustments where commission_entry_id=e.id and adjustment_type='refund_reversal';
  if exists(select 1 from public.ns_commission_adjustments where commission_entry_id=e.id and (adjustment_type<>'refund_reversal' or amount_delta_xaf>=0)) or prior_base+refund_base>e.base_amount_xaf or prior_delta+delta>e.commission_xaf then raise exception 'NS_PARTIAL_REFUND_LIMIT';end if;
  adj:=null;
  if delta>0 then
   adj:=gen_random_uuid();
   insert into public.ns_commission_adjustments(id,org_id,site_id,commission_entry_id,source_event_id,idempotency_key,adjustment_type,amount_delta_xaf,reason,created_by) values(adj,p_org,p_site,e.id,adj,adj,'refund_reversal',-delta,trim(p_reason),actor);
  end if;
  insert into ns_commission_internal.refund_parts(batch_id,entry_id,refund_base_xaf,reversed_commission_xaf,adjustment_id) values(p_event,e.id,refund_base,delta,adj);
 end loop;
 return receipt;
end $fn$;
revoke all on function public.ns_reverse_partial_commissions(uuid,uuid,uuid,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.ns_reverse_partial_commissions(uuid,uuid,uuid,uuid,jsonb,text) to authenticated;

rollback;
