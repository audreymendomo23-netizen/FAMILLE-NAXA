-- Positive physical count: separate documented review, never an automatic zero-cost stock increase.
begin;
create table public.zp_inventory_gains(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,lot_id uuid not null,member_id uuid not null,request_id uuid not null,
 before_milli bigint not null check(before_milli>=0),before_cost bigint not null check(before_cost>=0),counted_milli bigint not null check(counted_milli>before_milli),
 reason text not null check(length(reason) between 5 and 500),state text not null default 'pending' check(state in ('pending','approved','rejected')),
 approved_value bigint check(approved_value>=0),evidence text,decided_by uuid,decided_at timestamptz,created_at timestamptz not null default now(),
 unique(member_id,request_id),foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id),foreign key(decided_by,org_id) references public.zp_members(id,org_id));
create function public.zp_inventory_gain_request(p_access text,p_site uuid,p_lot uuid,p_request uuid,p_expected bigint,p_counted bigint,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;l public.zp_ingredient_lots;x public.zp_inventory_gains;i uuid;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_inventory_gains where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.lot_id,x.before_milli,x.counted_milli,x.reason) is distinct from (p_site,p_lot,p_expected,p_counted,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 select * into l from public.zp_ingredient_lots where id=p_lot and org_id=m.org_id and site_id=p_site for update;if l.id is null then raise exception 'DENIED';end if;
 if p_expected is distinct from l.remaining_milli then raise exception 'STALE_INVENTORY_COUNT';end if;
 if p_request is null or p_counted is null or p_counted<=p_expected or p_counted>1000000000 or length(why) not between 5 and 500 then raise exception 'INVALID_INVENTORY_GAIN';end if;
 if l.expires_on<(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_INVENTORY_GAIN';end if;
 insert into public.zp_inventory_gains(org_id,site_id,lot_id,member_id,request_id,before_milli,before_cost,counted_milli,reason) values(m.org_id,p_site,l.id,m.id,p_request,l.remaining_milli,l.remaining_cost,p_counted,why) returning id into i;return i;end $$;
create function public.zp_inventory_gain_decide(p_access text,p_site uuid,p_id uuid,p_decision text,p_value bigint,p_evidence text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_inventory_gains;l public.zp_ingredient_lots;proof text:=trim(coalesce(p_evidence,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_inventory_gains where id=p_id and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if p_decision is null or p_decision not in ('approved','rejected') or length(proof) not between 5 and 500 or (p_decision='approved' and (p_value is null or p_value not between 0 and 2147483647)) or (p_decision='rejected' and p_value is not null) then raise exception 'INVALID_INVENTORY_GAIN';end if;
 if x.state<>'pending' then if (x.state,x.approved_value,x.evidence) is distinct from (p_decision,p_value,proof) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.state;end if;
 if p_decision='approved' then
  select * into l from public.zp_ingredient_lots where id=x.lot_id and org_id=m.org_id and site_id=p_site for update;
  if (l.remaining_milli,l.remaining_cost) is distinct from (x.before_milli,x.before_cost) then raise exception 'STALE_INVENTORY_COUNT';end if;
  if l.expires_on<(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_INVENTORY_GAIN';end if;
  update public.zp_ingredient_lots set remaining_milli=x.counted_milli,remaining_cost=remaining_cost+p_value where id=l.id;
 end if;
 update public.zp_inventory_gains set state=p_decision,approved_value=p_value,evidence=proof,decided_by=m.id,decided_at=clock_timestamp() where id=x.id;return p_decision;end $$;
create function public.zp_inventory_gain_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('can_decide',m.role_code='promoteur','requests',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select g.id,g.lot_id,l.lot_label,g.before_milli,g.counted_milli,g.before_cost,g.reason,g.state,g.approved_value,g.evidence,g.member_id,g.decided_by,g.created_at,g.decided_at from public.zp_inventory_gains g join public.zp_ingredient_lots l on l.id=g.lot_id where g.org_id=m.org_id and g.site_id=p_site order by g.created_at desc limit 200)x),'[]'::jsonb));end $$;
create or replace view public.zp_ledger_sources with (security_invoker=true) as
 select org_id,site_id,(case when method='credit' then 'credit_sale' else 'sale' end)::text as kind,id as source_id,(created_at at time zone 'Africa/Douala')::date as entry_date,amount_xaf,'Sale receipt'::text as label from public.zp_cash_receipts
 union all select r.org_id,r.site_id,'sale_cost',r.id,(r.created_at at time zone 'Africa/Douala')::date,sum(c.cost_xaf)::bigint,'Cost of sale' from public.zp_cash_receipts r join public.zp_sale_costs c on c.receipt_id=r.id group by r.id,r.org_id,r.site_id,r.created_at having count(*)=count(c.cost_xaf) and sum(c.cost_xaf)>0
 union all select org_id,site_id,'purchase_receipt',id,(created_at at time zone 'Africa/Douala')::date,cost_xaf,'Purchase receipt' from public.zp_purchase_receipts where cost_xaf>0
 union all select org_id,site_id,'supplier_payment',id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,'Supplier payment' from public.zp_supplier_payments
 union all select org_id,site_id,'expense',id,expense_date,amount_xaf,label from public.zp_expenses
 union all select org_id,site_id,'inventory_loss',id,(created_at at time zone 'Africa/Douala')::date,loss_cost,reason from public.zp_inventory_counts where loss_cost>0
 union all select org_id,site_id,'deposit_'||direction,id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,'Packaging deposit/refund' from public.zp_container_finance
 union all select org_id,site_id,'credit_payment',id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,'Customer credit payment' from public.zp_credit_payments
 union all select org_id,site_id,'braise_loss',id,(created_at at time zone 'Africa/Douala')::date,loss_cost,'Prepared stock loss' from public.zp_braise_losses where loss_cost>0
 union all select org_id,destination_site,'transfer_loss',id,(received_at at time zone 'Africa/Douala')::date,transferred_cost-received_cost,'Material transfer loss' from public.zp_transfers where state='received' and transferred_cost>received_cost
 union all select org_id,destination_site,'prepared_transfer_loss',id,(received_at at time zone 'Africa/Douala')::date,transferred_cost-received_cost,'Preparation transfer loss' from public.zp_prepared_transfers where state='received' and transferred_cost>received_cost
 union all select org_id,site_id,kind,id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,reason from public.zp_cash_outflows where kind in ('refund','withdrawal')
 union all select org_id,site_id,'prepared_expiry_loss',id,(created_at at time zone 'Africa/Douala')::date,loss_cost,reason from public.zp_expired_preparation_losses where loss_cost>0
 union all select org_id,site_id,'inventory_gain',id,(decided_at at time zone 'Africa/Douala')::date,approved_value,reason from public.zp_inventory_gains where state='approved' and approved_value>0;
alter table public.zp_inventory_gains enable row level security;
revoke all on public.zp_inventory_gains from public,anon,authenticated;
grant select,insert,update on public.zp_inventory_gains to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_inventory_gain_request','zp_inventory_gain_decide','zp_inventory_gain_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
