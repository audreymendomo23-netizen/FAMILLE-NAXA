-- DRAFT ONLY. Explicit assignment recorded before settlement; no invented allocation, no payout.
begin;
create table public.ns_commission_reconciliation_plans(
 id uuid primary key,org_id uuid not null,site_id uuid not null,sale_id uuid not null unique references public.ns_sales(id),
 actor_id uuid not null,allocation jsonb not null check(jsonb_typeof(allocation)='array'),
 state text not null default 'waiting' check(state in ('waiting','processed','review_required')),
 receipt jsonb,created_at timestamptz not null default now(),processed_at timestamptz,
 foreign key(site_id,org_id) references public.ns_sites(id,org_id),foreign key(actor_id,org_id) references public.ns_members(id,org_id)
);
create table public.ns_commission_plan_appointments(
 appointment_id uuid primary key references public.ns_appointments(id),
 plan_id uuid not null references public.ns_commission_reconciliation_plans(id) on delete cascade
);
alter table public.ns_commission_reconciliation_plans enable row level security;
alter table public.ns_commission_plan_appointments enable row level security;
revoke all on public.ns_commission_reconciliation_plans,public.ns_commission_plan_appointments from public,anon,authenticated;
grant select,insert,update on public.ns_commission_reconciliation_plans to service_role;
grant select,insert on public.ns_commission_plan_appointments to service_role;
create function public.ns_register_commission_plan(p_org uuid,p_site uuid,p_sale uuid,p_id uuid,p_allocations jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare actor uuid; s public.ns_sales%rowtype; a public.ns_appointments%rowtype; old public.ns_commission_reconciliation_plans%rowtype;
 item jsonb; canonical jsonb; n integer; aid uuid; lid uuid;
begin
 actor:=public.ns_current_member_id(p_org);
 if auth.uid() is null or actor is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 if p_id is null or p_sale is null or p_allocations is null or jsonb_typeof(p_allocations)<>'array' then raise exception 'NS_COMMISSION_PLAN_INVALID';end if;
 n:=jsonb_array_length(p_allocations);
 if n not between 1 and 30 or exists(select 1 from jsonb_array_elements(p_allocations) x where jsonb_typeof(x)<>'object' or coalesce(x->>'line_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or coalesce(x->>'appointment_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'NS_COMMISSION_PLAN_INVALID';end if;
 select jsonb_agg(jsonb_build_object('line_id',(x->>'line_id')::uuid,'appointment_id',(x->>'appointment_id')::uuid) order by (x->>'line_id')::uuid) into canonical from jsonb_array_elements(p_allocations) x;
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
  if exists(select 1 from public.ns_commission_plan_appointments where appointment_id=aid) or exists(select 1 from public.ns_commission_entries where appointment_id=aid) or exists(select 1 from public.ns_commission_allocation_batches b where exists(select 1 from jsonb_array_elements(b.allocation) x where (x->>'appointment_id')::uuid=aid)) then raise exception 'NS_COMMISSION_PLAN_CONFLICT';end if;
 end loop;
 insert into public.ns_commission_reconciliation_plans(id,org_id,site_id,sale_id,actor_id,allocation) values(p_id,p_org,p_site,s.id,actor,canonical);
 insert into public.ns_commission_plan_appointments(appointment_id,plan_id) select (x->>'appointment_id')::uuid,p_id from jsonb_array_elements(canonical) x;
 return jsonb_build_object('id',p_id,'state','waiting');
end $fn$;
create function public.ns_process_commission_plan(p_org uuid,p_site uuid,p_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare t public.ns_commission_reconciliation_plans%rowtype; s public.ns_sales%rowtype; paid numeric; r jsonb; outcome text;
begin
 if auth.uid() is null or public.ns_current_member_id(p_org) is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 perform 1 from public.ns_organizations where id=p_org and status='active' for update;
 if not found then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 select * into t from public.ns_commission_reconciliation_plans where id=p_id and org_id=p_org and site_id=p_site for update;
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
    if jsonb_array_length(t.allocation)=1 then
     if not exists(select 1 from public.ns_sale_lines where id=(t.allocation->0->>'line_id')::uuid and sale_id=s.id and org_id=p_org and site_id=p_site) then raise exception 'NS_COMMISSION_PLAN_COVERAGE';end if;
     r:=public.ns_prepare_settled_commission(p_org,p_site,(t.allocation->0->>'appointment_id')::uuid,s.id);
    else
     r:=public.ns_prepare_multiline_commissions(p_org,p_site,s.id,t.id,t.allocation);
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
create function public.ns_list_commission_plans(p_org uuid,p_site uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
begin
 if auth.uid() is null or public.ns_current_member_id(p_org) is null or not public.ns_can_manage_org(p_org) or not public.ns_can_manage_site(p_org,p_site) then raise exception 'NS_COMMISSION_PLAN_FORBIDDEN';end if;
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id) from (select t.id,t.state,t.created_at,t.processed_at,s.sale_number,jsonb_array_length(t.allocation) as line_count from public.ns_commission_reconciliation_plans t join public.ns_sales s on s.id=t.sale_id and s.org_id=t.org_id and s.site_id=t.site_id where t.org_id=p_org and t.site_id=p_site order by (t.state='waiting') desc,t.created_at desc,t.id limit 100) q),'[]'::jsonb);
end $fn$;
revoke all on function public.ns_register_commission_plan(uuid,uuid,uuid,uuid,jsonb),public.ns_process_commission_plan(uuid,uuid,uuid),public.ns_list_commission_plans(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ns_register_commission_plan(uuid,uuid,uuid,uuid,jsonb),public.ns_process_commission_plan(uuid,uuid,uuid),public.ns_list_commission_plans(uuid,uuid) to authenticated;
rollback;
