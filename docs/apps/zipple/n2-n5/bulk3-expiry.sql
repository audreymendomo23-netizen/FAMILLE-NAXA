-- Configured shelf life, never an assumed food-safety duration. Prevent sale/service of expired preparations.
begin;
alter table public.zp_production_batches add column expires_at timestamptz;
create table public.zp_preparation_expiry_policies(
 item_id uuid primary key,org_id uuid not null,site_id uuid not null,hours int not null check(hours between 1 and 720),
 member_id uuid not null,reason text not null check(length(reason) between 5 and 500),updated_at timestamptz not null default now(),
 foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_expired_preparation_losses(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,batch_id uuid not null unique,
 member_id uuid not null,request_id uuid not null,servings int not null check(servings>0),loss_cost bigint not null check(loss_cost>=0),
 reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),unique(member_id,request_id),
 foreign key(batch_id,org_id,site_id) references public.zp_production_batches(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_preparation_expiry_set(p_access text,p_site uuid,p_item uuid,p_hours int,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 if p_hours is null or p_hours not between 1 and 720 or length(trim(coalesce(p_reason,''))) not between 5 and 500 or not exists(select 1 from public.zp_recipe_components where item_id=p_item and org_id=m.org_id and site_id=p_site) then raise exception 'INVALID_EXPIRY_POLICY';end if;
 insert into public.zp_preparation_expiry_policies(item_id,org_id,site_id,hours,member_id,reason) values(p_item,m.org_id,p_site,p_hours,m.id,trim(p_reason))
 on conflict(item_id) do update set hours=excluded.hours,member_id=excluded.member_id,reason=excluded.reason,updated_at=now();return true;end $$;
create function public.zp_preparation_expiry_apply() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
declare h int;begin
 if new.recipe_version_id is not null and new.expires_at is null then
 select hours into h from public.zp_preparation_expiry_policies where item_id=new.item_id and org_id=new.org_id and site_id=new.site_id;
 if h is not null then new.expires_at:=new.created_at+make_interval(hours=>h);end if;
 end if;return new;end $$;
create trigger zp_preparation_expiry_apply before insert on public.zp_production_batches for each row execute function public.zp_preparation_expiry_apply();
create or replace function public.zp_item_open(p_item uuid,p_channel text) returns boolean language sql stable security invoker set search_path=pg_catalog,public as $$
 select i.active and p_channel=any(i.available_channels) and public.zp_item_in_window(i.available_from,i.available_until,now()) and coalesce((select c.active from public.zp_category_controls c where c.site_id=i.site_id and c.category=i.category),true) and not exists(select 1 from public.zp_production_batches b where b.item_id=i.id and b.remaining_servings>0 and b.expires_at<=now()) from public.zp_menu_items i where i.id=p_item
$$;
create or replace function public.zp_advance_line(p_access text,p_site uuid,p_order uuid,p_item uuid,p_next text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;o public.zp_orders;current_state text;overall text;begin m:=public.zp_business_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into o from public.zp_orders where id=p_order and org_id=m.org_id and site_id=p_site for update;if o.id is null or o.status='cancelled' then raise exception 'DENIED';end if;
 select state into current_state from public.zp_order_lines where order_id=p_order and item_id=p_item;if current_state is null or (m.role_code not in ('promoteur','manager') and not (p_next='served' and public.zp_can_operate(m.id,p_site,'serve')) and not exists(select 1 from public.zp_station_grants g join public.zp_order_lines l on l.post=g.post where g.site_id=p_site and g.member_id=m.id and l.order_id=p_order and l.item_id=p_item)) then raise exception 'DENIED';end if;
 if current_state=p_next then return o.status;end if;
 if exists(select 1 from public.zp_production_batches b where b.item_id=p_item and b.site_id=p_site and b.org_id=m.org_id and b.remaining_servings>0 and b.expires_at<=now()) then raise exception 'EXPIRED_PREPARATION_REVIEW';end if;
 if not ((current_state='received' and p_next='preparing') or (current_state='preparing' and p_next='ready') or (current_state='ready' and p_next='served')) then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_order_lines set state=p_next where order_id=p_order and item_id=p_item;
 select case when bool_and(state='served') then 'served' when bool_and(state in ('ready','served')) then 'ready' when bool_and(state='received') then 'received' else 'preparing' end into overall from public.zp_order_lines where order_id=p_order;
 update public.zp_orders set status=overall,served_at=case when overall='served' then clock_timestamp() else served_at end where id=p_order;
 insert into public.zp_order_events(order_id,org_id,site_id,member_id,event_type,payload) values(p_order,m.org_id,p_site,m.id,'line_state',jsonb_build_object('item_id',p_item,'state',p_next));return overall;end $$;
create or replace function public.zp_prepared_transfer_dispatch(p_access text,p_site uuid,p_id uuid) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_prepared_transfers;b public.zp_production_batches;item public.zp_menu_items;c bigint;begin m:=public.zp_transfer_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_prepared_transfers where id=p_id and org_id=m.org_id and source_site=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if x.state='in_transit' then return x.state;end if;if x.state<>'approved' then raise exception 'INVALID_TRANSITION';end if;
 if not public.zp_prepared_match(x.source_batch,x.destination_item,m.org_id,p_site,x.destination_site) then raise exception 'TRANSFER_ITEM_MISMATCH';end if;
 select * into b from public.zp_production_batches where id=x.source_batch and org_id=m.org_id and site_id=p_site for update;
 select * into item from public.zp_menu_items where id=b.item_id and org_id=m.org_id and site_id=p_site for update;
 if b.expires_at<=now() then raise exception 'EXPIRED_PREPARATION_REVIEW';end if;
 if b.remaining_servings<x.servings or item.available_qty<x.servings or item.sale_limit is not null or exists(select 1 from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id where l.item_id=item.id and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)) then raise exception 'PREPARED_TRANSFER_STOCK_RESERVED';end if;
 c:=case when b.remaining_servings=x.servings then b.remaining_cost_xaf else floor(b.remaining_cost_xaf::numeric*x.servings/b.remaining_servings)::bigint end;
 update public.zp_production_batches set remaining_servings=remaining_servings-x.servings,remaining_cost_xaf=remaining_cost_xaf-c where id=b.id;
 update public.zp_menu_items set available_qty=available_qty-x.servings where id=item.id;
 update public.zp_prepared_transfers set state='in_transit',transferred_cost=c,dispatched_at=now(),dispatched_by=m.id where id=x.id;return 'in_transit';end $$;
create or replace function public.zp_prepared_transfer_receive(p_access text,p_site uuid,p_id uuid,p_servings int,p_reason text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_prepared_transfers;b uuid;c bigint;why text:=trim(coalesce(p_reason,''));begin m:=public.zp_transfer_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_prepared_transfers where id=p_id and org_id=m.org_id and destination_site=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if x.state='received' then if (x.received_servings,x.reason) is distinct from (p_servings,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return jsonb_build_object('id',x.id,'received_cost',x.received_cost,'loss_cost',x.transferred_cost-x.received_cost);end if;
 if x.state<>'in_transit' then raise exception 'INVALID_TRANSITION';end if;
 if p_servings is null or p_servings not between 0 and x.servings or length(why)>500 or (p_servings<>x.servings and length(why)<5) then raise exception 'TRANSFER_COUNT_REVIEW';end if;
 if not public.zp_prepared_match(x.source_batch,x.destination_item,m.org_id,x.source_site,p_site) then raise exception 'TRANSFER_ITEM_MISMATCH';end if;
 c:=case when p_servings=x.servings then x.transferred_cost else floor(x.transferred_cost::numeric*p_servings/x.servings)::bigint end;
 if p_servings>0 and exists(select 1 from public.zp_production_batches where id=x.source_batch and expires_at<=now()) then raise exception 'EXPIRED_PREPARATION_REVIEW';end if;
 if p_servings>0 then
  insert into public.zp_production_batches(org_id,site_id,item_id,member_id,request_id,servings,cost_xaf,remaining_servings,remaining_cost_xaf,expires_at) values(m.org_id,p_site,x.destination_item,m.id,gen_random_uuid(),p_servings,c,p_servings,c,(select expires_at from public.zp_production_batches where id=x.source_batch)) returning id into b;
  update public.zp_menu_items set available_qty=available_qty+p_servings where id=x.destination_item and org_id=m.org_id and site_id=p_site;
 end if;
 update public.zp_prepared_transfers set state='received',received_servings=p_servings,received_cost=c,destination_batch=b,reason=why,received_at=now(),received_by=m.id where id=x.id;
 return jsonb_build_object('id',x.id,'received_cost',c,'loss_cost',x.transferred_cost-c);end $$;
create function public.zp_expired_preparation_discard(p_access text,p_site uuid,p_batch uuid,p_request uuid,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;b public.zp_production_batches;x public.zp_expired_preparation_losses;i public.zp_menu_items;out_id uuid;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_expired_preparation_losses where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.batch_id,x.reason) is distinct from (p_site,p_batch,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 select * into b from public.zp_production_batches where id=p_batch and org_id=m.org_id and site_id=p_site for update;
 if b.id is null then raise exception 'DENIED';end if;
 select * into i from public.zp_menu_items where id=b.item_id for update;
 if p_request is null or length(why) not between 5 and 500 or b.expires_at is null or b.expires_at>now() or b.remaining_servings<=0 or i.available_qty<b.remaining_servings or i.sale_limit is not null or exists(select 1 from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id where l.item_id=i.id and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)) then raise exception 'EXPIRED_PREPARATION_REVIEW';end if;
 insert into public.zp_expired_preparation_losses(org_id,site_id,batch_id,member_id,request_id,servings,loss_cost,reason) values(m.org_id,p_site,b.id,m.id,p_request,b.remaining_servings,b.remaining_cost_xaf,why) returning id into out_id;
 update public.zp_production_batches set remaining_servings=0,remaining_cost_xaf=0 where id=b.id;
 update public.zp_menu_items set available_qty=available_qty-b.remaining_servings where id=i.id;
 return out_id;end $$;
create function public.zp_preparation_expiry_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'hours',p.hours,'reason',p.reason) order by i.name) from public.zp_menu_items i left join public.zp_preparation_expiry_policies p on p.item_id=i.id where i.org_id=m.org_id and i.site_id=p_site and exists(select 1 from public.zp_recipe_components c where c.item_id=i.id)),'[]'::jsonb),
 'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',i.name,'remaining_servings',b.remaining_servings,'remaining_cost_xaf',b.remaining_cost_xaf,'expires_at',b.expires_at,'expired',b.expires_at<=now()) order by b.expires_at nulls last) from public.zp_production_batches b join public.zp_menu_items i on i.id=b.item_id where b.org_id=m.org_id and b.site_id=p_site and b.remaining_servings>0),'[]'::jsonb),
 'losses',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select id,batch_id,servings,loss_cost,reason,created_at from public.zp_expired_preparation_losses where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)q),'[]'::jsonb));end $$;
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
 union all select org_id,site_id,'prepared_expiry_loss',id,(created_at at time zone 'Africa/Douala')::date,loss_cost,reason from public.zp_expired_preparation_losses where loss_cost>0;
do $$ declare t text;f record;begin
 foreach t in array array['zp_preparation_expiry_policies','zp_expired_preparation_losses'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 grant update on public.zp_preparation_expiry_policies to service_role;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_preparation_expiry_set','zp_preparation_expiry_apply','zp_expired_preparation_discard','zp_preparation_expiry_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
