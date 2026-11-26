-- Isolated candidate: ingredients, lots, production and expense register.
-- Quantity is integer thousandths of the declared base unit; cost is integer XAF.
begin;
create table public.zp_ingredients(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,name text not null check(length(trim(name)) between 1 and 160),sku text not null check(length(sku)<=80),unit text not null check(length(trim(unit)) between 1 and 40),reorder_milli bigint not null check(reorder_milli between 0 and 99999999999),supplier_whatsapp text not null default '' check(supplier_whatsapp='' or supplier_whatsapp~'^[0-9]{9,15}$'),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
create unique index zp_ingredient_sku on public.zp_ingredients(site_id,sku) where sku<>'';
create table public.zp_ingredient_lots(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,ingredient_id uuid not null,member_id uuid not null,request_id uuid not null,lot_label text not null check(length(trim(lot_label)) between 1 and 100),supplier text not null check(length(trim(supplier)) between 1 and 160),received_milli bigint not null check(received_milli between 1 and 1000000000),remaining_milli bigint not null check(remaining_milli>=0 and remaining_milli<=received_milli),received_cost bigint not null check(received_cost>=0 and received_cost<=2147483647),remaining_cost bigint not null check(remaining_cost>=0 and remaining_cost<=received_cost),expires_on date,received_at timestamptz not null default now(),unique(member_id,request_id),unique(id,org_id,site_id),foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_recipe_components(org_id uuid not null,site_id uuid not null,item_id uuid not null,ingredient_id uuid not null,qty_milli bigint not null check(qty_milli between 1 and 1000000000),primary key(item_id,ingredient_id),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id));
create table public.zp_production_batches(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,item_id uuid not null,member_id uuid not null,request_id uuid not null,servings int not null check(servings between 1 and 10000),cost_xaf bigint not null default 0 check(cost_xaf>=0),created_at timestamptz not null default now(),unique(member_id,request_id),unique(id,org_id,site_id),foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_production_consumption(batch_id uuid not null,lot_id uuid not null,org_id uuid not null,site_id uuid not null,qty_milli bigint not null check(qty_milli>0),cost_xaf bigint not null check(cost_xaf>=0),primary key(batch_id,lot_id),foreign key(batch_id,org_id,site_id) references public.zp_production_batches(id,org_id,site_id),foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id));
create table public.zp_expenses(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,member_id uuid not null,request_id uuid not null,category text not null check(category in ('rent','utilities','transport','staff','maintenance','other')),label text not null check(length(trim(label)) between 1 and 160),amount_xaf bigint not null check(amount_xaf between 1 and 2147483647),method text not null check(method in ('cash','mtn_momo','orange_money','bank','card')),reference text not null check(length(trim(reference)) between 4 and 160),expense_date date not null,created_at timestamptz not null default now(),unique(member_id,request_id),unique(org_id,site_id,method,reference),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
-- Existing N1/N2 identity and entitlement boundary; no raw client access.
create function public.zp_erp_actor(p_access text,p_site uuid) returns public.zp_members language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_business_actor(p_access,p_site);if m.role_code not in ('promoteur','manager') then raise exception 'DENIED';end if;return m;end $$;
create function public.zp_add_ingredient(p_access text,p_site uuid,p_name text,p_sku text,p_unit text,p_reorder bigint,p_whatsapp text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 insert into public.zp_ingredients(org_id,site_id,name,sku,unit,reorder_milli,supplier_whatsapp) values(m.org_id,p_site,trim(p_name),upper(trim(p_sku)),trim(p_unit),p_reorder,p_whatsapp) returning id into i;return i;end $$;
create function public.zp_receive_lot(p_access text,p_site uuid,p_ingredient uuid,p_request uuid,p_label text,p_supplier text,p_qty bigint,p_cost bigint,p_expires date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;l public.zp_ingredient_lots;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into l from public.zp_ingredient_lots where member_id=m.id and request_id=p_request;
 if l.id is not null then if (l.site_id,l.ingredient_id,l.lot_label,l.supplier,l.received_milli,l.received_cost,l.expires_on) is distinct from (p_site,p_ingredient,trim(p_label),trim(p_supplier),p_qty,p_cost,p_expires) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return l.id;end if;
 if p_expires is not null and p_expires<(now() at time zone 'Africa/Douala')::date then raise exception 'EXPIRED_LOT';end if;
 if not exists(select 1 from public.zp_ingredients where id=p_ingredient and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 insert into public.zp_ingredient_lots(org_id,site_id,ingredient_id,member_id,request_id,lot_label,supplier,received_milli,remaining_milli,received_cost,remaining_cost,expires_on) values(m.org_id,p_site,p_ingredient,m.id,p_request,trim(p_label),trim(p_supplier),p_qty,p_qty,p_cost,p_cost,p_expires) returning id into i;return i;end $$;
-- Recipe immutable in this initial version. Never silently replace a recipe or mix historical cost.
create function public.zp_define_recipe(p_access text,p_site uuid,p_item uuid,p_components jsonb) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;c record;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 if not exists(select 1 from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site and available_qty=0 and active) then raise exception 'RECIPE_REQUIRES_EMPTY_ITEM';end if;
 if exists(select 1 from public.zp_recipe_components where item_id=p_item) then raise exception 'RECIPE_VERSION_REQUIRED';end if;
 if jsonb_typeof(p_components) is distinct from 'array' or jsonb_array_length(p_components) not between 1 and 30 then raise exception 'INVALID_COMPONENTS';end if;
 for c in select * from jsonb_to_recordset(p_components) as x(ingredient_id uuid,qty_milli bigint) loop
 if c.ingredient_id is null or c.qty_milli is null or c.qty_milli not between 1 and 1000000000 or not exists(select 1 from public.zp_ingredients where id=c.ingredient_id and org_id=m.org_id and site_id=p_site) then raise exception 'INVALID_COMPONENTS';end if;
 insert into public.zp_recipe_components values(m.org_id,p_site,p_item,c.ingredient_id,c.qty_milli);
 end loop;return true;end $$;
create function public.zp_produce(p_access text,p_site uuid,p_item uuid,p_request uuid,p_servings int) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;b public.zp_production_batches;c record;l record;need bigint;take bigint;cost bigint;total bigint:=0;bid uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into b from public.zp_production_batches where member_id=m.id and request_id=p_request;
 if b.id is not null then if (b.site_id,b.item_id,b.servings) is distinct from (p_site,p_item,p_servings) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return jsonb_build_object('id',b.id,'servings',b.servings,'cost_xaf',b.cost_xaf);end if;
 if p_servings is null or p_servings not between 1 and 10000 or not exists(select 1 from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site and active) or not exists(select 1 from public.zp_recipe_components where item_id=p_item and org_id=m.org_id and site_id=p_site) then raise exception 'INVALID_PRODUCTION';end if;
 insert into public.zp_production_batches(org_id,site_id,item_id,member_id,request_id,servings) values(m.org_id,p_site,p_item,m.id,p_request,p_servings) returning id into bid;
 for c in select * from public.zp_recipe_components where item_id=p_item and org_id=m.org_id and site_id=p_site order by ingredient_id loop
 need:=c.qty_milli*p_servings;
 for l in select * from public.zp_ingredient_lots where ingredient_id=c.ingredient_id and org_id=m.org_id and site_id=p_site and remaining_milli>0 and (expires_on is null or expires_on>=(now() at time zone 'Africa/Douala')::date) order by expires_on nulls last,received_at,id for update loop
 exit when need=0;take:=least(need,l.remaining_milli);
 cost:=case when take=l.remaining_milli then l.remaining_cost else floor(l.remaining_cost::numeric*take/l.remaining_milli)::bigint end;
 update public.zp_ingredient_lots set remaining_milli=remaining_milli-take,remaining_cost=remaining_cost-cost where id=l.id;
 insert into public.zp_production_consumption values(bid,l.id,m.org_id,p_site,take,cost);
 total:=total+cost;need:=need-take;
 end loop;
 if need>0 then raise exception 'INGREDIENT_SHORTAGE';end if;
 end loop;
 update public.zp_menu_items set available_qty=available_qty+p_servings where id=p_item;
 update public.zp_production_batches set cost_xaf=total where id=bid;
 return jsonb_build_object('id',bid,'servings',p_servings,'cost_xaf',total);end $$;
-- Expense register is distinct from subscription, stock acquisitions, and drawer cash.
-- No automatic SYSCOHADA account mapping or cash drawer debit without a validated policy.
create function public.zp_record_expense(p_access text,p_site uuid,p_request uuid,p_category text,p_label text,p_amount bigint,p_method text,p_reference text,p_date date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;e public.zp_expenses;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into e from public.zp_expenses where member_id=m.id and request_id=p_request;
 if e.id is not null then if (e.site_id,e.category,e.label,e.amount_xaf,e.method,e.reference,e.expense_date) is distinct from (p_site,p_category,trim(p_label),p_amount,p_method,trim(p_reference),p_date) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return e.id;end if;
 if p_date is null or p_date>(now() at time zone 'Africa/Douala')::date then raise exception 'INVALID_EXPENSE_DATE';end if;
 insert into public.zp_expenses(org_id,site_id,member_id,request_id,category,label,amount_xaf,method,reference,expense_date) values(m.org_id,p_site,m.id,p_request,p_category,trim(p_label),p_amount,p_method,trim(p_reference),p_date) returning id into i;return i;end $$;
create function public.zp_erp_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;ingredients jsonb;lots jsonb;batches jsonb;expenses jsonb;recipes jsonb;begin m:=public.zp_erp_actor(p_access,p_site);
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'sku',i.sku,'unit',i.unit,'reorder_milli',i.reorder_milli,'supplier_whatsapp',i.supplier_whatsapp,'available_milli',coalesce((select sum(l.remaining_milli) from public.zp_ingredient_lots l where l.ingredient_id=i.id and (l.expires_on is null or l.expires_on>=(now() at time zone 'Africa/Douala')::date)),0)) order by i.name),'[]'::jsonb) into ingredients from public.zp_ingredients i where i.org_id=m.org_id and i.site_id=p_site;
 select coalesce(jsonb_agg(to_jsonb(l) order by l.received_at desc),'[]'::jsonb) into lots from (select id,ingredient_id,lot_label,supplier,remaining_milli,remaining_cost,expires_on,received_at from public.zp_ingredient_lots where org_id=m.org_id and site_id=p_site order by received_at desc limit 200) l;
 select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at desc),'[]'::jsonb) into batches from (select id,item_id,servings,cost_xaf,created_at from public.zp_production_batches where org_id=m.org_id and site_id=p_site order by created_at desc limit 100) b;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]'::jsonb) into expenses from (select id,category,label,amount_xaf,method,reference,expense_date,created_at from public.zp_expenses where org_id=m.org_id and site_id=p_site order by created_at desc limit 100) e;
 select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into recipes from (select item_id,ingredient_id,qty_milli from public.zp_recipe_components where org_id=m.org_id and site_id=p_site) c;
 return jsonb_build_object('ingredients',ingredients,'lots',lots,'batches',batches,'expenses',expenses,'recipes',recipes,'recorded_expenses_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_expenses where org_id=m.org_id and site_id=p_site),'recorded_sales_xaf',(select coalesce(sum(amount_xaf),0) from public.zp_cash_receipts where org_id=m.org_id and site_id=p_site),'accounting_status','mapping_required');end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_ingredients','zp_ingredient_lots','zp_recipe_components','zp_production_batches','zp_production_consumption','zp_expenses'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_erp_actor','zp_add_ingredient','zp_receive_lot','zp_define_recipe','zp_produce','zp_record_expense','zp_erp_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;
commit;
