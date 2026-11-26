-- Exact sale quantum in grams; actual weighed yield determines sellable stock, not planned yield.
begin;
create table public.zp_weighted_preparation_rules(
 item_id uuid primary key,org_id uuid not null,site_id uuid not null,quantum_g int not null check(quantum_g between 1 and 10000),
 member_id uuid not null,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),
 foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_weighted_preparations(
 batch_id uuid primary key,org_id uuid not null,site_id uuid not null,item_id uuid not null,member_id uuid not null,request_id uuid not null,
 input_units int not null check(input_units between 1 and 10000),output_units int not null check(output_units between 1 and 10000),
 quantum_g int not null check(quantum_g between 1 and 10000),yield_id uuid not null unique,ingredient_id uuid not null,
 raw_g bigint not null,cooked_g bigint not null,sellable_g bigint not null,note text not null,
 unique(member_id,request_id),check(sellable_g=output_units::bigint*quantum_g),foreign key(batch_id,org_id,site_id) references public.zp_production_batches(id,org_id,site_id),
 foreign key(yield_id,org_id,site_id) references public.zp_braise_yields(id,org_id,site_id),
 foreign key(item_id,org_id,site_id) references public.zp_menu_items(id,org_id,site_id),foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_weighted_rule_set(p_access text,p_site uuid,p_item uuid,p_quantum int,p_reason text) returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i public.zp_menu_items;begin
 m:=public.zp_erp_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into i from public.zp_menu_items where id=p_item and org_id=m.org_id and site_id=p_site for update;if i.id is null then raise exception 'DENIED';end if;
 if p_quantum is null or p_quantum not between 1 and 10000 or length(trim(coalesce(p_reason,''))) not between 5 and 500 or i.kind='formula' or i.available_qty<>0 or exists(select 1 from public.zp_direct_sale_rules where item_id=i.id) or not exists(select 1 from public.zp_recipe_components where item_id=i.id) or exists(select 1 from public.zp_production_batches where item_id=i.id) or exists(select 1 from public.zp_order_lines where item_id=i.id) then raise exception 'INVALID_WEIGHTED_RULE';end if;
 update public.zp_menu_items set sale_unit=p_quantum::text||' g' where id=i.id;
 insert into public.zp_weighted_preparation_rules(item_id,org_id,site_id,quantum_g,member_id,reason) values(i.id,m.org_id,p_site,p_quantum,m.id,trim(p_reason));return true;end $$;
alter function public.zp_produce(text,uuid,uuid,uuid,int) rename to zp_produce_input_units;
create function public.zp_produce(p_access text,p_site uuid,p_item uuid,p_request uuid,p_servings int) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 if exists(select 1 from public.zp_weighted_preparation_rules where item_id=p_item and org_id=m.org_id and site_id=p_site) then raise exception 'WEIGHED_PRODUCTION_REQUIRED';end if;
 return public.zp_produce_input_units(p_access,p_site,p_item,p_request,p_servings);end $$;
create function public.zp_weighted_produce(p_access text,p_site uuid,p_item uuid,p_ingredient uuid,p_request uuid,p_input int,p_raw bigint,p_cooked bigint,p_sellable bigint,p_note text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;r public.zp_weighted_preparation_rules;x public.zp_weighted_preparations;result jsonb;b uuid;y uuid;out_units int;why text:=trim(coalesce(p_note,''));begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_weighted_preparations where member_id=m.id and request_id=p_request;
 if x.batch_id is not null then
  if (x.site_id,x.item_id,x.ingredient_id,x.input_units,x.raw_g,x.cooked_g,x.sellable_g,x.note) is distinct from (p_site,p_item,p_ingredient,p_input,p_raw,p_cooked,p_sellable,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return jsonb_build_object('id',x.batch_id,'yield_id',x.yield_id,'servings',x.output_units,'cost_xaf',(select cost_xaf from public.zp_production_batches where id=x.batch_id));end if;
 select * into r from public.zp_weighted_preparation_rules where item_id=p_item and org_id=m.org_id and site_id=p_site;if r.item_id is null then raise exception 'DENIED';end if;
 if p_request is null or p_input is null or p_input not between 1 and 10000 or p_raw is null or p_cooked is null or p_sellable is null or p_raw not between 1 and 1000000000 or p_cooked not between 1 and p_raw or p_sellable not between 1 and p_cooked or p_sellable%r.quantum_g<>0 or p_sellable/r.quantum_g not between 1 and 10000 or length(why)>500 then raise exception 'INVALID_WEIGHTED_YIELD';end if;
 if exists(select 1 from public.zp_production_batches where member_id=m.id and request_id=p_request) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 out_units:=(p_sellable/r.quantum_g)::int;
 result:=public.zp_produce_input_units(p_access,p_site,p_item,p_request,p_input);b:=(result->>'id')::uuid;
 y:=public.zp_braise_measure(p_access,p_site,b,p_ingredient,p_request,p_raw,p_cooked,p_sellable,why);
 update public.zp_production_batches set servings=out_units,remaining_servings=out_units where id=b;
 update public.zp_menu_items set available_qty=available_qty-p_input+out_units where id=p_item;
 insert into public.zp_weighted_preparations values(b,m.org_id,p_site,p_item,m.id,p_request,p_input,out_units,r.quantum_g,y,p_ingredient,p_raw,p_cooked,p_sellable,why);
 return jsonb_build_object('id',b,'yield_id',y,'servings',out_units,'cost_xaf',result->'cost_xaf');end $$;
create function public.zp_weighted_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('can_configure',m.role_code='promoteur','rules',coalesce((select jsonb_agg(jsonb_build_object('item_id',r.item_id,'name',i.name,'quantum_g',r.quantum_g,'price_xaf',i.price_xaf,'ingredients',(select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'unit',g.unit,'qty_milli',c.qty_milli)) from public.zp_recipe_components c join public.zp_ingredients g on g.id=c.ingredient_id where c.item_id=r.item_id)) order by i.name) from public.zp_weighted_preparation_rules r join public.zp_menu_items i on i.id=r.item_id where r.org_id=m.org_id and r.site_id=p_site),'[]'::jsonb),
 'batches',coalesce((select jsonb_agg(to_jsonb(q) order by q.batch_id) from (select x.batch_id,x.item_id,i.name,x.input_units,x.output_units,x.quantum_g,x.raw_g,x.cooked_g,x.sellable_g,b.remaining_servings*x.quantum_g remaining_g,b.cost_xaf,b.remaining_cost_xaf,(select coalesce(sum(a.qty),0)*x.quantum_g from public.zp_sale_cost_allocations a where a.batch_id=b.id) sold_g from public.zp_weighted_preparations x join public.zp_production_batches b on b.id=x.batch_id join public.zp_menu_items i on i.id=x.item_id where x.org_id=m.org_id and x.site_id=p_site)q),'[]'::jsonb));end $$;
-- Preserve the exact configured sales unit (but allow price changes).
create function public.zp_weighted_unit_guard() returns trigger language plpgsql security invoker set search_path=pg_catalog,public as $$
begin
 if new.sale_unit is distinct from old.sale_unit and (exists(select 1 from public.zp_weighted_preparation_rules where item_id=old.id) or exists(select 1 from public.zp_direct_sale_rules where item_id=old.id)) then raise exception 'SALE_UNIT_IMMUTABLE';end if;
 return new;end $$;
create trigger zp_weighted_unit_guard before update of sale_unit on public.zp_menu_items for each row execute function public.zp_weighted_unit_guard();
do $$ declare t text;f record;begin
 foreach t in array array['zp_weighted_preparation_rules','zp_weighted_preparations'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_weighted_rule_set','zp_produce','zp_produce_input_units','zp_weighted_produce','zp_weighted_snapshot','zp_weighted_unit_guard') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
