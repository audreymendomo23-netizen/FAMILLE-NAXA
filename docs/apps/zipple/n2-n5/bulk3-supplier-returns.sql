-- Supplier credit and actual refunds: original receipt and purchase payment remain immutable.
begin;
create table public.zp_supplier_returns(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,purchase_id uuid not null,receipt_id uuid not null references public.zp_purchase_receipts(id),
 lot_id uuid not null,member_id uuid not null,request_id uuid not null,
 expected_milli bigint not null,qty_milli bigint not null check(qty_milli>0),cost_xaf bigint not null check(cost_xaf>=0),
 reference text not null check(length(reference) between 4 and 160),reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 unique(member_id,request_id),unique(site_id,receipt_id,reference),foreign key(purchase_id,org_id,site_id) references public.zp_purchases(id,org_id,site_id),
 foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_supplier_refunds(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,purchase_id uuid not null,member_id uuid not null,request_id uuid not null,
 method text not null check(method in ('cash','bank','mtn_momo','orange_money','card')),amount_xaf bigint not null check(amount_xaf between 1 and 2147483647),
 reference text not null check(length(reference) between 4 and 160),reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 unique(member_id,request_id),unique(org_id,method,reference),foreign key(purchase_id,org_id,site_id) references public.zp_purchases(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
alter table public.zp_supplier_returns enable row level security;
alter table public.zp_supplier_refunds enable row level security;
revoke all on public.zp_supplier_returns,public.zp_supplier_refunds from public,anon,authenticated;
grant select,insert on public.zp_supplier_returns,public.zp_supplier_refunds to service_role;
create function public.zp_supplier_balance(p_purchase uuid) returns bigint language sql stable security invoker set search_path=pg_catalog,public as $f$
 select (p.received_cost-p.paid_xaf-coalesce((select sum(r.cost_xaf) from public.zp_supplier_returns r where r.purchase_id=p.id),0)+coalesce((select sum(r.amount_xaf) from public.zp_supplier_refunds r where r.purchase_id=p.id),0))::bigint from public.zp_purchases p where p.id=p_purchase;
$f$;
create function public.zp_supplier_payment_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $f$
begin if new.amount_xaf>greatest(public.zp_supplier_balance(new.purchase_id),0) then raise exception 'PAYMENT_EXCEEDS_DEBT';end if;return new;end $f$;
create trigger zp_supplier_payment_net_debt before insert on public.zp_supplier_payments for each row execute function public.zp_supplier_payment_guard();
create function public.zp_supplier_return(p_access text,p_site uuid,p_receipt uuid,p_request uuid,p_expected bigint,p_qty bigint,p_reference text,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;r public.zp_purchase_receipts;l public.zp_ingredient_lots;x public.zp_supplier_returns;i uuid;cost bigint;ref text:=trim(coalesce(p_reference,''));why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_request is null or p_expected is null or p_qty is null or p_qty not between 1 and 1000000000 or length(ref) not between 4 and 160 or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where org_id=m.org_id and site_id=p_site for update;
 select * into x from public.zp_supplier_returns where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.receipt_id,x.expected_milli,x.qty_milli,x.reference,x.reason) is distinct from (p_site,p_receipt,p_expected,p_qty,ref,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 select * into r from public.zp_purchase_receipts where id=p_receipt and org_id=m.org_id and site_id=p_site;if r.id is null then raise exception 'DENIED';end if;
 select * into l from public.zp_ingredient_lots where id=r.lot_id and org_id=m.org_id and site_id=p_site for update;
 if l.remaining_milli is distinct from p_expected then raise exception 'STALE_INVENTORY_COUNT';end if;
 if l.gain_milli<>0 or l.gain_cost<>0 or p_qty>l.remaining_milli or p_qty+coalesce((select sum(qty_milli) from public.zp_supplier_returns where receipt_id=r.id),0)>r.qty_milli then raise exception 'SUPPLIER_RETURN_REQUIRES_TRACE';end if;
 cost:=case when p_qty=l.remaining_milli then l.remaining_cost else floor(l.remaining_cost::numeric*p_qty/l.remaining_milli)::bigint end;
 if cost+coalesce((select sum(cost_xaf) from public.zp_supplier_returns where receipt_id=r.id),0)>r.cost_xaf then raise exception 'SUPPLIER_RETURN_REQUIRES_TRACE';end if;
 insert into public.zp_supplier_returns(org_id,site_id,purchase_id,receipt_id,lot_id,member_id,request_id,expected_milli,qty_milli,cost_xaf,reference,reason) values(m.org_id,p_site,r.purchase_id,r.id,l.id,m.id,p_request,p_expected,p_qty,cost,ref,why) returning id into i;
 update public.zp_ingredient_lots set remaining_milli=remaining_milli-p_qty,remaining_cost=remaining_cost-cost where id=l.id;
 return i;end $f$;
create function public.zp_supplier_refund(p_access text,p_site uuid,p_purchase uuid,p_request uuid,p_amount bigint,p_method text,p_reference text,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;p public.zp_purchases;x public.zp_supplier_refunds;i uuid;ref text:=trim(coalesce(p_reference,''));why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 if p_request is null or p_amount is null or p_amount not between 1 and 2147483647 or p_method is null or p_method not in ('cash','bank','mtn_momo','orange_money','card') or length(ref) not between 4 and 160 or length(why) not between 5 and 500 then raise exception 'INVALID_INPUT';end if;
 perform 1 from public.zp_site_modes where org_id=m.org_id and site_id=p_site for update;
 select * into x from public.zp_supplier_refunds where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.purchase_id,x.amount_xaf,x.method,x.reference,x.reason) is distinct from (p_site,p_purchase,p_amount,p_method,ref,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 select * into p from public.zp_purchases where id=p_purchase and org_id=m.org_id and site_id=p_site for update;if p.id is null then raise exception 'DENIED';end if;
 if p_amount>greatest(-public.zp_supplier_balance(p.id),0) then raise exception 'SUPPLIER_REFUND_EXCEEDS_CREDIT';end if;
 insert into public.zp_supplier_refunds(org_id,site_id,purchase_id,member_id,request_id,method,amount_xaf,reference,reason) values(m.org_id,p_site,p.id,m.id,p_request,p_method,p_amount,ref,why) returning id into i;return i;
end $f$;
create function public.zp_supplier_return_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $f$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('can_write',m.role_code='promoteur',
 'receipts',coalesce((select jsonb_agg(to_jsonb(x)) from (select r.id,r.purchase_id,l.lot_label,l.remaining_milli,l.remaining_cost,l.gain_milli,p.reference from public.zp_purchase_receipts r join public.zp_ingredient_lots l on l.id=r.lot_id join public.zp_purchases p on p.id=r.purchase_id where r.org_id=m.org_id and r.site_id=p_site and l.remaining_milli>0 and l.gain_milli=0 and l.gain_cost=0 order by r.created_at desc limit 200)x),'[]'::jsonb),
 'credits',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,reference,-public.zp_supplier_balance(id) credit_xaf from public.zp_purchases where org_id=m.org_id and site_id=p_site and public.zp_supplier_balance(id)<0 order by created_at desc limit 200)x),'[]'::jsonb),
 'returns',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,receipt_id,purchase_id,qty_milli,cost_xaf,reference,reason,created_at from public.zp_supplier_returns where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)x),'[]'::jsonb),
 'refunds',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,purchase_id,method,amount_xaf,reference,reason,created_at from public.zp_supplier_refunds where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)x),'[]'::jsonb));
end $f$;
create or replace function public.zp_procurement_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('suppliers',coalesce((select jsonb_agg(to_jsonb(s) order by s.name) from public.zp_suppliers s where s.org_id=m.org_id and s.site_id=p_site),'[]'::jsonb),'purchases',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select id,supplier_id,ingredient_id,reference,qty_milli,total_xaf,received_milli,received_cost,paid_xaf,created_at,public.zp_supplier_balance(id) as net_balance_xaf from public.zp_purchases where org_id=m.org_id and site_id=p_site order by created_at desc limit 200) x),'[]'::jsonb),'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'reference',b.reference,'purchase_ids',b.purchase_ids,'supplier_id',b.supplier_id,'total_xaf',(select coalesce(sum(p.total_xaf),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id),'received_cost',(select coalesce(sum(p.received_cost),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id),'paid_xaf',(select coalesce(sum(p.paid_xaf),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id),'debt_xaf',(select coalesce(sum(greatest(public.zp_supplier_balance(p.id),0)),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id)) order by b.created_at desc) from (select * from public.zp_purchase_batches where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)b),'[]'::jsonb),'debt_xaf',(select coalesce(sum(greatest(public.zp_supplier_balance(id),0)),0) from public.zp_purchases where org_id=m.org_id and site_id=p_site),'supplier_receivable_xaf',(select coalesce(sum(greatest(-public.zp_supplier_balance(id),0)),0) from public.zp_purchases where org_id=m.org_id and site_id=p_site),'loss_cost_xaf',(select coalesce(sum(loss_cost),0) from public.zp_inventory_counts where org_id=m.org_id and site_id=p_site));end $$;

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
 union all select org_id,site_id,'inventory_gain',id,(decided_at at time zone 'Africa/Douala')::date,approved_value,reason from public.zp_inventory_gains where state='approved' and approved_value>0
 union all select org_id,site_id,case when payment_id is null then 'credit_note' else 'credit_refund' end,id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,reason from public.zp_credit_notes
 union all select org_id,site_id,'stock_return',id,(created_at at time zone 'Africa/Douala')::date,restock_cost,reason from public.zp_sale_returns where restock_cost>0
 union all select org_id,site_id,'supplier_return',id,(created_at at time zone 'Africa/Douala')::date,cost_xaf,reason from public.zp_supplier_returns where cost_xaf>0
 union all select org_id,site_id,'supplier_refund',id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,reason from public.zp_supplier_refunds;
alter table public.zp_treasury_reconciliation drop constraint zp_treasury_reconciliation_source_kind_check;
alter table public.zp_treasury_reconciliation add constraint zp_treasury_reconciliation_source_kind_check check(source_kind in ('supplier_payment','container_finance','supplier_refund'));
create or replace view public.zp_treasury_source with (security_invoker=true) as
 select org_id,site_id,'supplier_payment'::text as kind,id as source_id,'out'::text as direction,method,amount_xaf,reference,created_at from public.zp_supplier_payments
 union all select org_id,site_id,'container_finance',id,direction,method,amount_xaf,reference,created_at from public.zp_container_finance
 union all select org_id,site_id,'supplier_refund',id,'in',method,amount_xaf,reference,created_at from public.zp_supplier_refunds;
do $g$ declare n record;begin for n in select p.oid::regprocedure as sig from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname='public' and p.proname in ('zp_supplier_balance','zp_supplier_payment_guard','zp_supplier_return','zp_supplier_refund','zp_supplier_return_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',n.sig);execute format('grant execute on function %s to service_role',n.sig);end loop;end $g$;
commit;
