-- Recorded outflows only: no API money transfer and no automatic stock return.
begin;
create table public.zp_cash_outflows(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,cash_id uuid not null,member_id uuid not null,request_id uuid not null,
 kind text not null check(kind in ('expense','withdrawal','refund')),source_id uuid,method text not null check(method in ('cash','bank','mtn_momo','orange_money','card')),
 amount_xaf bigint not null check(amount_xaf between 1 and 2147483647),reference text not null check(length(reference) between 4 and 160),
 reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 unique(member_id,request_id),unique(org_id,method,reference),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),
 foreign key(cash_id,org_id,site_id) references public.zp_cash_sessions(id,org_id,site_id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id),
 check((kind='withdrawal' and source_id is null and method='cash') or (kind='expense' and source_id is not null and method='cash') or (kind='refund' and source_id is not null)));
create unique index zp_cash_expense_once on public.zp_cash_outflows(source_id) where kind='expense';
create function public.zp_cash_expected(p_cash uuid) returns bigint language sql stable security invoker set search_path=pg_catalog,public as $$
 select c.opening_xaf+coalesce((select sum(amount_xaf) from public.zp_cash_receipts where cash_id=c.id and method='cash'),0)+coalesce((select sum(t.amount_xaf) from public.zp_cash_tenders t join public.zp_cash_receipts r on r.id=t.receipt_id where r.cash_id=c.id and t.method='cash'),0)+coalesce((select sum(p.amount_xaf) from public.zp_credit_payments p where p.cash_id=c.id and p.method='cash'),0)-coalesce((select sum(amount_xaf) from public.zp_cash_outflows where cash_id=c.id and method='cash'),0) from public.zp_cash_sessions c where c.id=p_cash;
$$;
create function public.zp_cash_outflow_record(p_access text,p_site uuid,p_cash uuid,p_request uuid,p_kind text,p_source uuid,p_method text,p_amount bigint,p_reference text,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;x public.zp_cash_outflows;r public.zp_cash_receipts;e public.zp_expenses;cap bigint;used bigint;i uuid;ref text:=trim(coalesce(p_reference,''));why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_cash_outflows where member_id=m.id and request_id=p_request;
 if x.id is not null then
  if (x.site_id,x.cash_id,x.kind,x.source_id,x.method,x.amount_xaf,x.reference,x.reason) is distinct from (p_site,p_cash,p_kind,p_source,p_method,p_amount,ref,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;
 end if;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;
 if c.id is null then raise exception 'DENIED';end if;if c.closed_at is not null then raise exception 'CASH_CLOSED';end if;
 if p_request is null or p_amount is null or p_amount not between 1 and 2147483647 or length(ref) not between 4 and 160 or length(why) not between 5 and 500 or p_kind is null or p_kind not in ('expense','withdrawal','refund') or p_method is null or p_method not in ('cash','bank','mtn_momo','orange_money','card') then raise exception 'INVALID_CASH_OUTFLOW';end if;
 if p_kind='withdrawal' then
  if p_source is not null or p_method<>'cash' then raise exception 'INVALID_CASH_OUTFLOW';end if;
 elsif p_kind='expense' then
  select * into e from public.zp_expenses where id=p_source and org_id=m.org_id and site_id=p_site;
  if e.id is null then raise exception 'DENIED';end if;
  if e.method<>'cash' or p_method<>'cash' or p_amount<>e.amount_xaf or exists(select 1 from public.zp_cash_outflows where kind='expense' and source_id=e.id) then raise exception 'EXPENSE_CASH_LINK_INVALID';end if;
 else
  select * into r from public.zp_cash_receipts where id=p_source and org_id=m.org_id and site_id=p_site;
  if r.id is null then raise exception 'DENIED';end if;
  if r.method='credit' then raise exception 'REFUND_REQUIRES_CREDIT_REVIEW';end if;
  if r.method='mixed' then select coalesce(sum(amount_xaf),0) into cap from public.zp_cash_tenders where receipt_id=r.id and method=p_method;
  else cap:=case when r.method=p_method then r.amount_xaf else 0 end;end if;
  select coalesce(sum(amount_xaf),0) into used from public.zp_cash_outflows where kind='refund' and source_id=r.id and method=p_method;
  if p_amount>cap-used then raise exception 'REFUND_EXCEEDS_ORIGINAL_METHOD';end if;
  if p_method<>'cash' then insert into public.zp_settlement_references values(m.org_id,p_method,ref);end if;
 end if;
 if p_method='cash' and p_amount>public.zp_cash_expected(c.id) then raise exception 'INSUFFICIENT_CASH_BALANCE';end if;
 insert into public.zp_cash_outflows(org_id,site_id,cash_id,member_id,request_id,kind,source_id,method,amount_xaf,reference,reason) values(m.org_id,p_site,c.id,m.id,p_request,p_kind,p_source,p_method,p_amount,ref,why) returning id into i;return i;end $$;
create function public.zp_cash_outflows_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 return jsonb_build_object('sessions',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'label',coalesce(d.label,'Caisse principale'),'expected_xaf',public.zp_cash_expected(c.id))) from public.zp_cash_sessions c left join public.zp_cash_desks d on d.id=c.desk_id where c.site_id=p_site and c.org_id=m.org_id and c.closed_at is null),'[]'::jsonb),
 'expenses',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'label',e.label,'amount_xaf',e.amount_xaf)) from public.zp_expenses e where e.org_id=m.org_id and e.site_id=p_site and e.method='cash' and not exists(select 1 from public.zp_cash_outflows x where x.kind='expense' and x.source_id=e.id)),'[]'::jsonb),
 'refundable',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select r.id,r.order_id,r.amount_xaf,r.method,r.created_at,coalesce((select sum(x.amount_xaf) from public.zp_cash_outflows x where x.kind='refund' and x.source_id=r.id),0) refunded_xaf from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.method<>'credit' order by r.created_at desc limit 200)q),'[]'::jsonb),
 'outflows',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select id,cash_id,kind,source_id,method,amount_xaf,reference,reason,created_at from public.zp_cash_outflows where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)q),'[]'::jsonb));end $$;
create or replace function public.zp_close_cash(p_access text,p_site uuid,p_cash uuid,p_counted bigint) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c public.zp_cash_sessions;expected bigint;begin m:=public.zp_business_actor(p_access,p_site);if not public.zp_can_operate(m.id,p_site,'cash') or p_counted<0 or p_counted is null then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into c from public.zp_cash_sessions where id=p_cash and site_id=p_site and org_id=m.org_id for update;if c.id is null or not public.zp_cash_desk_access(m.id,c.id) then raise exception 'DENIED';end if;
 if c.closed_at is not null then if c.counted_xaf<>p_counted then raise exception 'CASH_CLOSED';end if;expected:=c.expected_xaf;
 else expected:=public.zp_cash_expected(c.id);
 update public.zp_cash_sessions set closed_at=clock_timestamp(),closed_by=m.id,counted_xaf=p_counted,expected_xaf=expected where id=p_cash;end if;
 return jsonb_build_object('expected_xaf',expected,'counted_xaf',p_counted,'variance_xaf',p_counted-expected);end $$;
create or replace function public.zp_erp_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;ingredients jsonb;lots jsonb;batches jsonb;expenses jsonb;recipes jsonb;begin m:=public.zp_erp_actor(p_access,p_site);
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'sku',i.sku,'unit',i.unit,'reorder_milli',i.reorder_milli,'supplier_whatsapp',i.supplier_whatsapp,'available_milli',coalesce((select sum(l.remaining_milli) from public.zp_ingredient_lots l where l.ingredient_id=i.id and (l.expires_on is null or l.expires_on>=(now() at time zone 'Africa/Douala')::date)),0)) order by i.name),'[]'::jsonb) into ingredients from public.zp_ingredients i where i.org_id=m.org_id and i.site_id=p_site;
 select coalesce(jsonb_agg(to_jsonb(l) order by l.received_at desc),'[]'::jsonb) into lots from (select id,ingredient_id,lot_label,supplier,remaining_milli,remaining_cost,expires_on,received_at from public.zp_ingredient_lots where org_id=m.org_id and site_id=p_site order by received_at desc limit 200) l;
 select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at desc),'[]'::jsonb) into batches from (select id,item_id,servings,cost_xaf,recipe_version_id,created_at from public.zp_production_batches where org_id=m.org_id and site_id=p_site order by created_at desc limit 100) b;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]'::jsonb) into expenses from (select id,category,label,amount_xaf,method,reference,expense_date,created_at from public.zp_expenses where org_id=m.org_id and site_id=p_site order by created_at desc limit 100) e;
 select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into recipes from (select item_id,ingredient_id,qty_milli from public.zp_recipe_components where org_id=m.org_id and site_id=p_site) c;
 return jsonb_build_object('ingredients',ingredients,'lots',lots,'batches',batches,'expenses',expenses,'recipes',recipes,'conversions',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'ingredient_id',c.ingredient_id,'label',c.label,'base_milli_per_unit',c.base_milli_per_unit) order by c.label) from public.zp_unit_conversions c where c.org_id=m.org_id and c.site_id=p_site),'[]'::jsonb),'recipe_versions',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'item_id',v.item_id,'version',v.version,'components',v.components,'reason',v.reason,'created_at',v.created_at) order by v.version desc) from public.zp_recipe_versions v where v.org_id=m.org_id and v.site_id=p_site),'[]'::jsonb),'recorded_expenses_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_expenses where org_id=m.org_id and site_id=p_site),'recorded_receipts_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site and method<>'credit')+(select coalesce(sum(amount_xaf),0) from public.zp_credit_payments where org_id=m.org_id and site_id=p_site),'refunds_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_cash_outflows where org_id=m.org_id and site_id=p_site and kind='refund'),'recorded_sales_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site),'recorded_cost_xaf',case when exists(select 1 from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site)
 and not exists(select 1 from public.zp_cash_receipts r join public.zp_order_lines l on l.order_id=r.order_id left join public.zp_sale_costs c on c.receipt_id=r.id and c.item_id=l.item_id where r.org_id=m.org_id and r.site_id=p_site and c.cost_xaf is null)
 then (select sum(cost_xaf) from public.zp_sale_costs where org_id=m.org_id and site_id=p_site) else null end,'accounting_status','mapping_required');end $$;
create or replace function public.zp_pilotage(p_access text,p_site uuid,p_start date,p_end date) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;today date:=(now() at time zone 'Africa/Douala')::date;lo timestamptz;hi timestamptz;revenue bigint;cost bigint;unknown_count bigint;receipt_count bigint;history jsonb;first_day date;expense bigint;low_count bigint;late_count bigint;feedback_count bigint;feedback_avg numeric;variance bigint;post_metrics jsonb;begin
 m:=public.zp_erp_actor(p_access,p_site);
 if p_start is null or p_end is null or p_start>p_end or p_end>today or p_end-p_start>365 then raise exception 'INVALID_PERIOD';end if;
 lo:=p_start::timestamp at time zone 'Africa/Douala';hi:=(p_end+1)::timestamp at time zone 'Africa/Douala';
 select coalesce(sum(r.amount_xaf),0),count(*) into revenue,receipt_count from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;
 select count(*) into unknown_count from public.zp_cash_receipts r where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi and exists(select 1 from public.zp_order_lines l left join public.zp_sale_costs c on c.receipt_id=r.id and c.item_id=l.item_id where l.order_id=r.order_id and c.cost_xaf is null);
 if receipt_count>0 and unknown_count=0 then select coalesce(sum(c.cost_xaf),0) into cost from public.zp_sale_costs c join public.zp_cash_receipts r on r.id=c.receipt_id where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi;end if;
 select coalesce(sum(amount_xaf),0) into expense from public.zp_expenses where org_id=m.org_id and site_id=p_site and expense_date between p_start and p_end;
 select count(*) into low_count from public.zp_ingredients i where i.org_id=m.org_id and i.site_id=p_site and i.reorder_milli>=coalesce((select sum(l.remaining_milli) from public.zp_ingredient_lots l where l.ingredient_id=i.id and (l.expires_on is null or l.expires_on>=today)),0);
 select count(*) into late_count from public.zp_orders o where o.org_id=m.org_id and o.site_id=p_site and o.status not in ('served','cancelled') and o.guest_served_at is null and o.promised_at<now();
 select count(*),round(avg(rating),2) into feedback_count,feedback_avg from public.zp_feedback where org_id=m.org_id and site_id=p_site and created_at>=lo and created_at<hi;
 select coalesce(sum(abs(counted_xaf-expected_xaf)),0) into variance from public.zp_cash_sessions where org_id=m.org_id and site_id=p_site and closed_at>=lo and closed_at<hi;
 select min((created_at at time zone 'Africa/Douala')::date) into first_day from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site;
 select coalesce(jsonb_agg(jsonb_build_object('day',x.receipt_day,'recorded_xaf',x.amount) order by x.receipt_day),'[]'::jsonb) into history from (select (created_at at time zone 'Africa/Douala')::date as receipt_day,sum(amount_xaf) as amount from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site and created_at>=((today-28)::timestamp at time zone 'Africa/Douala') and created_at<(today::timestamp at time zone 'Africa/Douala') group by 1)x;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.post),'[]'::jsonb) into post_metrics from (select l.post,sum(l.qty) portions,sum(l.line_total_xaf) recorded_xaf from public.zp_cash_receipts r join public.zp_order_lines l on l.order_id=r.order_id where r.org_id=m.org_id and r.site_id=p_site and r.created_at>=lo and r.created_at<hi group by l.post)x;
 return jsonb_build_object('start',p_start,'end',p_end,'as_of',now(),'today',today,'first_recorded_sale_day',first_day,'refunds_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_cash_outflows where org_id=m.org_id and site_id=p_site and kind='refund' and created_at>=lo and created_at<hi),'recorded_xaf',revenue,'collected_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site and method<>'credit' and created_at>=lo and created_at<hi)+(select coalesce(sum(amount_xaf),0) from public.zp_credit_payments where org_id=m.org_id and site_id=p_site and created_at>=lo and created_at<hi),'receipts',receipt_count,'uncosted_receipts',unknown_count,'known_cost_xaf',cost,'gross_margin_xaf',case when cost is not null then revenue-cost else null end,'expenses_xaf',expense,'current_low_stock',low_count,'current_late_orders',late_count,'feedback_count',feedback_count,'feedback_average',feedback_avg,'absolute_cash_variance_xaf',variance,'history_28',history,'posts',post_metrics);
end $$;
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
 union all select org_id,site_id,kind,id,(created_at at time zone 'Africa/Douala')::date,amount_xaf,reason from public.zp_cash_outflows where kind in ('refund','withdrawal');
alter table public.zp_cash_outflows enable row level security;
revoke all on public.zp_cash_outflows from public,anon,authenticated;
grant select,insert on public.zp_cash_outflows to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_cash_expected','zp_cash_outflow_record','zp_cash_outflows_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
