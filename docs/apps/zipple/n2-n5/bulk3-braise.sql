-- Measure braising yield on the existing production and cost allocations; no duplicate consumption.
begin;
create table public.zp_braise_yields(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,batch_id uuid not null unique,ingredient_id uuid not null,
 member_id uuid not null,request_id uuid not null,raw_g bigint not null check(raw_g between 1 and 1000000000),
 cooked_g bigint not null check(cooked_g between 1 and raw_g),sellable_g bigint not null check(sellable_g between 1 and cooked_g),
 primary_qty_milli bigint not null check(primary_qty_milli>0),primary_unit text not null,weight_verified boolean not null,
 note text not null check(length(note)<=500),created_at timestamptz not null default now(),unique(member_id,request_id),unique(id,org_id,site_id),
 foreign key(batch_id,org_id,site_id) references public.zp_production_batches(id,org_id,site_id),
 foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_braise_losses(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,yield_id uuid not null,
 member_id uuid not null,request_id uuid not null,servings int not null check(servings between 1 and 10000),
 reason text not null check(length(reason) between 5 and 500),loss_cost bigint not null check(loss_cost>=0),
 created_at timestamptz not null default now(),unique(member_id,request_id),
 foreign key(yield_id,org_id,site_id) references public.zp_braise_yields(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_braise_measure(p_access text,p_site uuid,p_batch uuid,p_ingredient uuid,p_request uuid,p_raw bigint,p_cooked bigint,p_sellable bigint,p_note text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_braise_yields;b public.zp_production_batches;qty bigint;u text;verified boolean;i uuid;note_text text:=trim(coalesce(p_note,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_braise_yields where member_id=m.id and request_id=p_request;
 if x.id is not null then
  if (x.site_id,x.batch_id,x.ingredient_id,x.raw_g,x.cooked_g,x.sellable_g,x.note) is distinct from (p_site,p_batch,p_ingredient,p_raw,p_cooked,p_sellable,note_text) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;
 end if;
 select * into b from public.zp_production_batches where id=p_batch and org_id=m.org_id and site_id=p_site;
 if b.id is null then raise exception 'DENIED';end if;
 select sum(c.qty_milli),lower(trim(g.unit)) into qty,u from public.zp_production_consumption c join public.zp_ingredient_lots l on l.id=c.lot_id join public.zp_ingredients g on g.id=l.ingredient_id where c.batch_id=b.id and c.org_id=m.org_id and c.site_id=p_site and g.id=p_ingredient group by g.unit;
 if qty is null or qty<=0 or p_request is null or p_raw is null or p_cooked is null or p_sellable is null or p_raw not between 1 and 1000000000 or p_cooked not between 1 and p_raw or p_sellable not between 1 and p_cooked or length(note_text)>500 then raise exception 'INVALID_BRAISE_YIELD';end if;
 verified:=u in ('kg','g');
 if (u='kg' and p_raw<>qty) or (u='g' and p_raw::numeric*1000<>qty) then raise exception 'BRAISE_INPUT_MISMATCH';end if;
 if not verified and length(note_text)<5 then raise exception 'BRAISE_WEIGHT_EVIDENCE_REQUIRED';end if;
 if exists(select 1 from public.zp_braise_yields where batch_id=b.id) then raise exception 'BRAISE_ALREADY_MEASURED';end if;
 insert into public.zp_braise_yields(org_id,site_id,batch_id,ingredient_id,member_id,request_id,raw_g,cooked_g,sellable_g,primary_qty_milli,primary_unit,weight_verified,note)
 values(m.org_id,p_site,b.id,p_ingredient,m.id,p_request,p_raw,p_cooked,p_sellable,qty,u,verified,note_text) returning id into i;return i;end $$;
create function public.zp_braise_discard(p_access text,p_site uuid,p_yield uuid,p_request uuid,p_servings int,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_braise_losses;y public.zp_braise_yields;b public.zp_production_batches;item public.zp_menu_items;c bigint;i uuid;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_braise_losses where member_id=m.id and request_id=p_request;
 if x.id is not null then
  if (x.site_id,x.yield_id,x.servings,x.reason) is distinct from (p_site,p_yield,p_servings,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;
 end if;
 select * into y from public.zp_braise_yields where id=p_yield and org_id=m.org_id and site_id=p_site;if y.id is null then raise exception 'DENIED';end if;
 select * into b from public.zp_production_batches where id=y.batch_id and org_id=m.org_id and site_id=p_site for update;
 select * into item from public.zp_menu_items where id=b.item_id and org_id=m.org_id and site_id=p_site for update;
 if p_request is null or p_servings is null or p_servings not between 1 and least(b.remaining_servings,item.available_qty) or item.sale_limit is not null or length(why) not between 5 and 500 or exists(select 1 from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id where l.item_id=item.id and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)) then raise exception 'BRAISE_LOSS_REVIEW';end if;
 c:=case when p_servings=b.remaining_servings then b.remaining_cost_xaf else floor(b.remaining_cost_xaf::numeric*p_servings/b.remaining_servings)::bigint end;
 update public.zp_production_batches set remaining_servings=remaining_servings-p_servings,remaining_cost_xaf=remaining_cost_xaf-c where id=b.id;
 update public.zp_menu_items set available_qty=available_qty-p_servings where id=item.id;
 insert into public.zp_braise_losses(org_id,site_id,yield_id,member_id,request_id,servings,reason,loss_cost) values(m.org_id,p_site,y.id,m.id,p_request,p_servings,why,c) returning id into i;return i;end $$;
create function public.zp_braise_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',i.name,'servings',b.servings,'remaining_servings',b.remaining_servings,'ingredients',(select coalesce(jsonb_agg(to_jsonb(g)),'[]'::jsonb) from (select x.id,x.name,x.unit,sum(c.qty_milli) qty_milli from public.zp_production_consumption c join public.zp_ingredient_lots l on l.id=c.lot_id join public.zp_ingredients x on x.id=l.ingredient_id where c.batch_id=b.id group by x.id,x.name,x.unit)g)) order by b.created_at desc) from public.zp_production_batches b join public.zp_menu_items i on i.id=b.item_id where b.org_id=m.org_id and b.site_id=p_site and exists(select 1 from public.zp_production_consumption c where c.batch_id=b.id) and not exists(select 1 from public.zp_braise_yields y where y.batch_id=b.id)),'[]'::jsonb),
 'yields',coalesce((select jsonb_agg(jsonb_build_object('id',y.id,'name',i.name,'raw_g',y.raw_g,'cooked_g',y.cooked_g,'sellable_g',y.sellable_g,'weight_verified',y.weight_verified,'servings',b.servings,'remaining_servings',b.remaining_servings,'sold_servings',(select coalesce(sum(qty),0) from public.zp_sale_cost_allocations where batch_id=b.id),'discarded_servings',(select coalesce(sum(servings),0) from public.zp_braise_losses where yield_id=y.id),'loss_cost',(select coalesce(sum(loss_cost),0) from public.zp_braise_losses where yield_id=y.id),'created_at',y.created_at) order by y.created_at desc) from public.zp_braise_yields y join public.zp_production_batches b on b.id=y.batch_id join public.zp_menu_items i on i.id=b.item_id where y.org_id=m.org_id and y.site_id=p_site),'[]'::jsonb));end $$;
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
 union all select org_id,destination_site,'prepared_transfer_loss',id,(received_at at time zone 'Africa/Douala')::date,transferred_cost-received_cost,'Preparation transfer loss' from public.zp_prepared_transfers where state='received' and transferred_cost>received_cost;
do $$ declare t text;f record;begin
 foreach t in array array['zp_braise_yields','zp_braise_losses'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_braise_measure','zp_braise_discard','zp_braise_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
