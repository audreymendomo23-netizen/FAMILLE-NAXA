-- A direct-sale item uses a configured exact stock quantum. Raw stock is reserved by order, consumed only when sale is confirmed.
begin;
create table public.zp_direct_sale_rules(
 item_id uuid primary key,org_id uuid not null,site_id uuid not null,ingredient_id uuid not null,qty_milli bigint not null check(qty_milli between 1 and 1000000000),
 member_id uuid not null,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_direct_sale_allocations(
 receipt_id uuid not null,item_id uuid not null,lot_id uuid not null,org_id uuid not null,site_id uuid not null,qty_milli bigint not null check(qty_milli>0),cost_xaf bigint not null check(cost_xaf>=0),
 primary key(receipt_id,item_id,lot_id),foreign key(receipt_id,item_id) references public.zp_sale_costs(receipt_id,item_id),foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id),foreign key(receipt_id,org_id,site_id) references public.zp_cash_receipts(id,org_id,site_id));
create function public.zp_direct_free(p_ingredient uuid) returns numeric language sql stable security invoker set search_path=pg_catalog,public as $$
 select coalesce((select sum(remaining_milli) from public.zp_ingredient_lots where ingredient_id=p_ingredient and (expires_on is null or expires_on>=(now() at time zone 'Africa/Douala')::date)),0)-coalesce((select sum(l.qty::numeric*r.qty_milli) from public.zp_direct_sale_rules r join public.zp_order_lines l on l.item_id=r.item_id join public.zp_orders o on o.id=l.order_id where r.ingredient_id=p_ingredient and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts x where x.order_id=o.id)),0);
$$;
create function public.zp_direct_capacity(p_item uuid) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select coalesce((select least(2147483647,greatest(0,floor(public.zp_direct_free(r.ingredient_id)/r.qty_milli)))::int from public.zp_direct_sale_rules r where r.item_id=p_item),2147483647);
$$;
create function public.zp_direct_sale_set(p_access text,p_site uuid,p_item uuid,p_ingredient uuid,p_qty bigint,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i public.zp_menu_items;g public.zp_ingredients;u text;begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into i from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;
 select * into g from public.zp_ingredients where id=p_ingredient and org_id=m.org_id and site_id=p_site;
 if i.id is null or g.id is null then raise exception 'DENIED';end if;
 if p_qty is null or p_qty not between 1 and 1000000000 or length(trim(coalesce(p_reason,''))) not between 5 and 500 or i.kind='formula' or exists(select 1 from public.zp_recipe_components where item_id=i.id) or exists(select 1 from public.zp_production_batches where item_id=i.id) or exists(select 1 from public.zp_order_lines where item_id=i.id) then raise exception 'DIRECT_RULE_REQUIRES_UNUSED_ITEM';end if;
 if lower(trim(g.unit))='kg' then u:=p_qty::text||' g';elsif lower(trim(g.unit))='g' and p_qty%1000=0 then u:=(p_qty/1000)::text||' g';else u:=trim(to_char(p_qty::numeric/1000,'FM9999999990.999'))||' '||g.unit;end if;
 update public.zp_menu_items set sale_unit=u where id=i.id;
 insert into public.zp_direct_sale_rules(item_id,org_id,site_id,ingredient_id,qty_milli,member_id,reason) values(i.id,m.org_id,p_site,g.id,p_qty,m.id,trim(p_reason));
 return true;end $$;
create function public.zp_direct_recipe_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin if exists(select 1 from public.zp_direct_sale_rules where item_id=new.item_id) then raise exception 'DIRECT_ITEM_NO_PRODUCTION';end if;return new;end $$;
create trigger zp_direct_recipe_guard before insert or update on public.zp_recipe_components for each row execute function public.zp_direct_recipe_guard();
create function public.zp_direct_reservation_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
declare g uuid;begin
 select ingredient_id into g from public.zp_direct_sale_rules where item_id=new.item_id;
 if g is not null and public.zp_direct_free(g)<0 then raise exception 'DIRECT_STOCK_SHORTAGE';end if;return new;end $$;
create trigger zp_direct_reservation_guard after insert on public.zp_order_lines for each row execute function public.zp_direct_reservation_guard();
create function public.zp_direct_lot_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin if (new.remaining_milli<old.remaining_milli or new.expires_on is distinct from old.expires_on) and exists(select 1 from public.zp_direct_sale_rules where ingredient_id=new.ingredient_id) and public.zp_direct_free(new.ingredient_id)<0 then raise exception 'DIRECT_STOCK_RESERVED';end if;return new;end $$;
create trigger zp_direct_lot_guard after update of remaining_milli,expires_on on public.zp_ingredient_lots for each row execute function public.zp_direct_lot_guard();
create or replace function public.zp_component_capacity(p_item uuid,p_channel text,p_qty int) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select case when i.kind<>'formula' and public.zp_item_open(i.id,p_channel) then least(i.available_qty,coalesce(i.sale_limit,i.available_qty),public.zp_direct_capacity(i.id))/p_qty else 0 end from public.zp_menu_items i where i.id=p_item
$$;
create or replace function public.zp_sellable_channel_qty(p_item uuid,p_channel text) returns int language sql stable security invoker set search_path=pg_catalog,public as $$
 select case when not public.zp_item_open(i.id,p_channel) then 0 when i.kind<>'formula' then least(i.available_qty,coalesce(i.sale_limit,i.available_qty),public.zp_direct_capacity(i.id)) else
 least(coalesce((select min(public.zp_component_capacity(f.component_id,p_channel,f.qty)) from public.zp_formula_components f where f.formula_id=i.id),0),
 coalesce((select min(coalesce((select max(public.zp_component_capacity(o.component_id,p_channel,g.qty)) from public.zp_formula_options o where o.group_id=g.id),0)) from public.zp_formula_groups g where g.formula_id=i.id and g.required),2147483647)) end
 from public.zp_menu_items i where i.id=p_item
$$;
create or replace function public.zp_allocate_sale_cost() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
declare l record;b record;raw record;lot record;raw_need bigint;raw_take bigint;need int;take int;cost bigint;total bigint;begin
 for l in select * from public.zp_order_lines where order_id=new.order_id and org_id=new.org_id and site_id=new.site_id order by item_id loop
 insert into public.zp_sale_costs(receipt_id,org_id,site_id,item_id,qty,cost_xaf) values(new.id,new.org_id,new.site_id,l.item_id,l.qty,null);
 select * into raw from public.zp_direct_sale_rules where item_id=l.item_id and org_id=new.org_id and site_id=new.site_id;
 if found then
  raw_need:=raw.qty_milli*l.qty;total:=0;
  for lot in select * from public.zp_ingredient_lots where ingredient_id=raw.ingredient_id and org_id=new.org_id and site_id=new.site_id and remaining_milli>0 and (expires_on is null or expires_on>=(now() at time zone 'Africa/Douala')::date) order by expires_on nulls last,received_at,id for update loop
   exit when raw_need=0;raw_take:=least(raw_need,lot.remaining_milli);
   cost:=case when raw_take=lot.remaining_milli then lot.remaining_cost else floor(lot.remaining_cost::numeric*raw_take/lot.remaining_milli)::bigint end;
   update public.zp_ingredient_lots set remaining_milli=remaining_milli-raw_take,remaining_cost=remaining_cost-cost where id=lot.id;
   insert into public.zp_direct_sale_allocations values(new.id,l.item_id,lot.id,new.org_id,new.site_id,raw_take,cost);
   total:=total+cost;raw_need:=raw_need-raw_take;
  end loop;
  if raw_need>0 then raise exception 'DIRECT_STOCK_SHORTAGE';end if;
  update public.zp_sale_costs set cost_xaf=total where receipt_id=new.id and item_id=l.item_id;continue;
 end if;
 if not exists(select 1 from public.zp_recipe_components where item_id=l.item_id and org_id=new.org_id and site_id=new.site_id) then continue;end if;
 need:=l.qty;total:=0;
 for b in select * from public.zp_production_batches where item_id=l.item_id and org_id=new.org_id and site_id=new.site_id and remaining_servings>0 order by created_at,id for update loop
 exit when need=0;take:=least(need,b.remaining_servings);
 cost:=case when take=b.remaining_servings then b.remaining_cost_xaf else floor(b.remaining_cost_xaf::numeric*take/b.remaining_servings)::bigint end;
 update public.zp_production_batches set remaining_servings=remaining_servings-take,remaining_cost_xaf=remaining_cost_xaf-cost where id=b.id;
 insert into public.zp_sale_cost_allocations values(new.id,l.item_id,b.id,new.org_id,new.site_id,take,cost);
 total:=total+cost;need:=need-take;
 end loop;
 if need>0 then raise exception 'PRODUCTION_COST_SHORTAGE';end if;
 update public.zp_sale_costs set cost_xaf=total where receipt_id=new.id and item_id=l.item_id;
 end loop;return new;end $$;
create function public.zp_direct_sale_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);return jsonb_build_object('rules',coalesce((select jsonb_agg(jsonb_build_object('item_id',r.item_id,'name',i.name,'unit',i.sale_unit,'price_xaf',i.price_xaf,'ingredient',g.name,'qty_milli',r.qty_milli,'available',public.zp_direct_capacity(i.id)) order by i.name) from public.zp_direct_sale_rules r join public.zp_menu_items i on i.id=r.item_id join public.zp_ingredients g on g.id=r.ingredient_id where r.org_id=m.org_id and r.site_id=p_site),'[]'::jsonb),'can_configure',m.role_code='promoteur');end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_direct_sale_rules','zp_direct_sale_allocations'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_direct_free','zp_direct_capacity','zp_direct_sale_set','zp_direct_recipe_guard','zp_direct_reservation_guard','zp_direct_lot_guard','zp_direct_sale_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
