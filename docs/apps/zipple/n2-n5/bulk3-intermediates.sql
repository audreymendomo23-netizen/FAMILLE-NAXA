-- Value-preserving intermediate preparation conversion; no sale, no second raw consumption.
begin;
create table public.zp_intermediate_conversions(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,batch_id uuid not null,lot_id uuid not null unique,ingredient_id uuid not null,member_id uuid not null,request_id uuid not null,
 servings int not null check(servings>0),qty_milli bigint not null check(qty_milli>0),cost_xaf bigint not null check(cost_xaf>=0),expires_on date not null,reason text not null check(length(reason) between 5 and 500),created_at timestamptz not null default now(),unique(member_id,request_id),
 foreign key(batch_id,org_id,site_id) references public.zp_production_batches(id,org_id,site_id),foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id),foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_intermediate_convert(p_access text,p_site uuid,p_batch uuid,p_ingredient uuid,p_request uuid,p_servings int,p_qty bigint,p_expiry date,p_reason text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;b public.zp_production_batches;i public.zp_menu_items;x public.zp_intermediate_conversions;lot uuid;cost bigint;out_id uuid;deadline timestamptz;why text:=trim(coalesce(p_reason,''));begin
 m:=public.zp_erp_actor(p_access,p_site);perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_intermediate_conversions where member_id=m.id and request_id=p_request;
 if x.id is not null then
  if (x.site_id,x.batch_id,x.ingredient_id,x.servings,x.qty_milli,x.expires_on,x.reason) is distinct from (p_site,p_batch,p_ingredient,p_servings,p_qty,p_expiry,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return jsonb_build_object('id',x.id,'lot_id',x.lot_id,'cost_xaf',x.cost_xaf);
 end if;
 select * into b from public.zp_production_batches where id=p_batch and org_id=m.org_id and site_id=p_site for update;
 if b.id is null or not exists(select 1 from public.zp_ingredients where id=p_ingredient and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 select * into i from public.zp_menu_items where id=b.item_id for update;
 deadline:=least(b.expires_at,(p_expiry+1)::timestamp at time zone 'Africa/Douala');
 if p_request is null or p_servings is null or p_servings not between 1 and b.remaining_servings or p_qty is null or p_qty not between 1 and 1000000000 or p_expiry is null or deadline<=now() or length(why) not between 5 and 500 or i.available_qty<p_servings or i.sale_limit is not null or exists(select 1 from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id where l.item_id=i.id and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts rr where rr.order_id=o.id)) then raise exception 'INTERMEDIATE_REQUIRES_AVAILABLE_BATCH';end if;
 cost:=case when p_servings=b.remaining_servings then b.remaining_cost_xaf else floor(b.remaining_cost_xaf::numeric*p_servings/b.remaining_servings)::bigint end;
 if cost>2147483647 or exists(select 1 from public.zp_ingredient_lots where member_id=m.id and request_id=p_request) then raise exception 'INVALID_INTERMEDIATE_VALUE';end if;
 insert into public.zp_ingredient_lots(org_id,site_id,ingredient_id,member_id,request_id,lot_label,supplier,received_milli,remaining_milli,received_cost,remaining_cost,expires_on,usable_until) values(m.org_id,p_site,p_ingredient,m.id,p_request,'PREP-'||p_request::text,'Production interne',p_qty,p_qty,cost,cost,p_expiry,deadline) returning id into lot;
 update public.zp_production_batches set remaining_servings=remaining_servings-p_servings,remaining_cost_xaf=remaining_cost_xaf-cost where id=b.id;
 update public.zp_menu_items set available_qty=available_qty-p_servings where id=i.id;
 insert into public.zp_intermediate_conversions(org_id,site_id,batch_id,lot_id,ingredient_id,member_id,request_id,servings,qty_milli,cost_xaf,expires_on,reason) values(m.org_id,p_site,b.id,lot,p_ingredient,m.id,p_request,p_servings,p_qty,cost,p_expiry,why) returning id into out_id;
 return jsonb_build_object('id',out_id,'lot_id',lot,'cost_xaf',cost);end $$;
create function public.zp_intermediate_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);return jsonb_build_object('batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',i.name,'remaining_servings',b.remaining_servings,'remaining_cost_xaf',b.remaining_cost_xaf,'expires_at',b.expires_at) order by b.created_at) from public.zp_production_batches b join public.zp_menu_items i on i.id=b.item_id where b.org_id=m.org_id and b.site_id=p_site and b.remaining_servings>0 and (b.expires_at is null or b.expires_at>now())),'[]'::jsonb),'conversions',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc) from (select x.id,x.batch_id,x.lot_id,g.name,x.servings,x.qty_milli,g.unit,x.cost_xaf,x.expires_on,l.usable_until,x.reason,x.created_at from public.zp_intermediate_conversions x join public.zp_ingredients g on g.id=x.ingredient_id join public.zp_ingredient_lots l on l.id=x.lot_id where x.org_id=m.org_id and x.site_id=p_site order by x.created_at desc limit 200)q),'[]'::jsonb));end $$;
alter table public.zp_intermediate_conversions enable row level security;
revoke all on public.zp_intermediate_conversions from public,anon,authenticated;grant select,insert on public.zp_intermediate_conversions to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_intermediate_convert','zp_intermediate_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
