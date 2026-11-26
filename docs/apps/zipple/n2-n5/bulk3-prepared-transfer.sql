-- Same family transfer scope/approval pattern, with exact cost of prepared portions.
begin;
create table public.zp_prepared_transfers(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,source_site uuid not null,destination_site uuid not null,
 source_batch uuid not null,destination_item uuid not null,requested_by uuid not null,request_id uuid not null,
 servings int not null check(servings between 1 and 10000),state text not null default 'requested' check(state in ('requested','approved','in_transit','received','cancelled')),
 transferred_cost bigint check(transferred_cost>=0),received_servings int check(received_servings between 0 and servings),received_cost bigint check(received_cost between 0 and transferred_cost),
 destination_batch uuid unique,reason text,approved_by uuid,dispatched_by uuid,received_by uuid,cancelled_by uuid,
 approved_at timestamptz,dispatched_at timestamptz,received_at timestamptz,cancelled_at timestamptz,created_at timestamptz not null default now(),
 check(source_site<>destination_site),unique(requested_by,request_id),
 foreign key(source_site,org_id) references public.zp_site_modes(site_id,org_id),foreign key(destination_site,org_id) references public.zp_site_modes(site_id,org_id),
 foreign key(source_batch,org_id,source_site) references public.zp_production_batches(id,org_id,site_id),
 foreign key(destination_item,org_id,destination_site) references public.zp_menu_items(id,org_id,site_id),
 foreign key(destination_batch,org_id,destination_site) references public.zp_production_batches(id,org_id,site_id),
 foreign key(requested_by,org_id) references public.zp_members(id,org_id),foreign key(approved_by,org_id) references public.zp_members(id,org_id),
 foreign key(dispatched_by,org_id) references public.zp_members(id,org_id),foreign key(received_by,org_id) references public.zp_members(id,org_id),foreign key(cancelled_by,org_id) references public.zp_members(id,org_id));
create function public.zp_prepared_match(p_source uuid,p_destination uuid,p_org uuid,p_src_site uuid,p_dst_site uuid) returns boolean language sql stable security invoker set search_path=pg_catalog,public as $$
 select exists(select 1 from public.zp_production_batches b join public.zp_menu_items s on s.id=b.item_id join public.zp_menu_items d on d.id=p_destination where b.id=p_source and b.org_id=p_org and b.site_id=p_src_site and d.org_id=p_org and d.site_id=p_dst_site and s.sku<>'' and s.sku=d.sku and s.sale_unit=d.sale_unit and s.kind<>'formula' and d.kind<>'formula' and d.active and exists(select 1 from public.zp_recipe_components c where c.item_id=d.id and c.org_id=p_org and c.site_id=p_dst_site));
$$;
create function public.zp_prepared_transfer_request(p_access text,p_site uuid,p_destination uuid,p_batch uuid,p_item uuid,p_request uuid,p_servings int) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;d public.zp_members;x public.zp_prepared_transfers;i uuid;begin
 m:=public.zp_transfer_actor(p_access,p_site);d:=public.zp_transfer_actor(p_access,p_destination);
 if m.id<>d.id or p_site=p_destination then raise exception 'DENIED';end if;
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_prepared_transfers where requested_by=m.id and request_id=p_request;
 if x.id is not null then
  if (x.source_site,x.destination_site,x.source_batch,x.destination_item,x.servings) is distinct from (p_site,p_destination,p_batch,p_item,p_servings) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;
 end if;
 if p_request is null or p_servings is null or p_servings not between 1 and 10000 or not public.zp_prepared_match(p_batch,p_item,m.org_id,p_site,p_destination) then raise exception 'TRANSFER_ITEM_MISMATCH';end if;
 insert into public.zp_prepared_transfers(org_id,source_site,destination_site,source_batch,destination_item,requested_by,request_id,servings) values(m.org_id,p_site,p_destination,p_batch,p_item,m.id,p_request,p_servings) returning id into i;return i;end $$;
create function public.zp_prepared_transfer_decide(p_access text,p_site uuid,p_id uuid,p_decision text) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_prepared_transfers;begin m:=public.zp_transfer_actor(p_access,p_site);if m.role_code<>'promoteur' then raise exception 'DENIED';end if;
 select * into x from public.zp_prepared_transfers where id=p_id and org_id=m.org_id and source_site=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if p_decision='approved' then if x.state='approved' then return x.state;end if;if x.state<>'requested' then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_prepared_transfers set state='approved',approved_by=m.id,approved_at=now() where id=x.id;
 elsif p_decision='cancelled' then if x.state='cancelled' then return x.state;end if;if x.state not in ('requested','approved') then raise exception 'INVALID_TRANSITION';end if;
 update public.zp_prepared_transfers set state='cancelled',cancelled_by=m.id,cancelled_at=now() where id=x.id;
 else raise exception 'INVALID_TRANSITION';end if;return p_decision;end $$;
create function public.zp_prepared_transfer_dispatch(p_access text,p_site uuid,p_id uuid) returns text language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_prepared_transfers;b public.zp_production_batches;item public.zp_menu_items;c bigint;begin m:=public.zp_transfer_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_prepared_transfers where id=p_id and org_id=m.org_id and source_site=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if x.state='in_transit' then return x.state;end if;if x.state<>'approved' then raise exception 'INVALID_TRANSITION';end if;
 if not public.zp_prepared_match(x.source_batch,x.destination_item,m.org_id,p_site,x.destination_site) then raise exception 'TRANSFER_ITEM_MISMATCH';end if;
 select * into b from public.zp_production_batches where id=x.source_batch and org_id=m.org_id and site_id=p_site for update;
 select * into item from public.zp_menu_items where id=b.item_id and org_id=m.org_id and site_id=p_site for update;
 if b.remaining_servings<x.servings or item.available_qty<x.servings or item.sale_limit is not null or exists(select 1 from public.zp_order_lines l join public.zp_orders o on o.id=l.order_id where l.item_id=item.id and o.status<>'cancelled' and not exists(select 1 from public.zp_cash_receipts r where r.order_id=o.id)) then raise exception 'PREPARED_TRANSFER_STOCK_RESERVED';end if;
 c:=case when b.remaining_servings=x.servings then b.remaining_cost_xaf else floor(b.remaining_cost_xaf::numeric*x.servings/b.remaining_servings)::bigint end;
 update public.zp_production_batches set remaining_servings=remaining_servings-x.servings,remaining_cost_xaf=remaining_cost_xaf-c where id=b.id;
 update public.zp_menu_items set available_qty=available_qty-x.servings where id=item.id;
 update public.zp_prepared_transfers set state='in_transit',transferred_cost=c,dispatched_at=now(),dispatched_by=m.id where id=x.id;return 'in_transit';end $$;
create function public.zp_prepared_transfer_receive(p_access text,p_site uuid,p_id uuid,p_servings int,p_reason text) returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_prepared_transfers;b uuid;c bigint;why text:=trim(coalesce(p_reason,''));begin m:=public.zp_transfer_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_prepared_transfers where id=p_id and org_id=m.org_id and destination_site=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if x.state='received' then if (x.received_servings,x.reason) is distinct from (p_servings,why) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return jsonb_build_object('id',x.id,'received_cost',x.received_cost,'loss_cost',x.transferred_cost-x.received_cost);end if;
 if x.state<>'in_transit' then raise exception 'INVALID_TRANSITION';end if;
 if p_servings is null or p_servings not between 0 and x.servings or length(why)>500 or (p_servings<>x.servings and length(why)<5) then raise exception 'TRANSFER_COUNT_REVIEW';end if;
 if not public.zp_prepared_match(x.source_batch,x.destination_item,m.org_id,x.source_site,p_site) then raise exception 'TRANSFER_ITEM_MISMATCH';end if;
 c:=case when p_servings=x.servings then x.transferred_cost else floor(x.transferred_cost::numeric*p_servings/x.servings)::bigint end;
 if p_servings>0 then
  insert into public.zp_production_batches(org_id,site_id,item_id,member_id,request_id,servings,cost_xaf,remaining_servings,remaining_cost_xaf) values(m.org_id,p_site,x.destination_item,m.id,gen_random_uuid(),p_servings,c,p_servings,c) returning id into b;
  update public.zp_menu_items set available_qty=available_qty+p_servings where id=x.destination_item and org_id=m.org_id and site_id=p_site;
 end if;
 update public.zp_prepared_transfers set state='received',received_servings=p_servings,received_cost=c,destination_batch=b,reason=why,received_at=now(),received_by=m.id where id=x.id;
 return jsonb_build_object('id',x.id,'received_cost',c,'loss_cost',x.transferred_cost-c);end $$;
create function public.zp_prepared_transfer_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_transfer_actor(p_access,p_site);
 return jsonb_build_object('site_id',p_site,'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'item_id',i.id,'name',i.name,'sku',i.sku,'unit',i.sale_unit,'remaining_servings',b.remaining_servings,'remaining_cost_xaf',b.remaining_cost_xaf)) from public.zp_production_batches b join public.zp_menu_items i on i.id=b.item_id where b.org_id=m.org_id and b.site_id=p_site and b.remaining_servings>0 and i.sku<>''),'[]'::jsonb),
 'sites',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'items',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.name,'sku',i.sku,'unit',i.sale_unit)) from public.zp_menu_items i where i.org_id=m.org_id and i.site_id=s.id and i.sku<>'' and i.active and i.kind<>'formula' and exists(select 1 from public.zp_recipe_components c where c.item_id=i.id)),'[]'::jsonb))) from public.zp_sites s join public.zp_site_scopes sc on sc.site_id=s.id and sc.org_id=s.org_id and sc.member_id=m.id join public.zp_site_modes sm on sm.site_id=s.id and sm.org_id=s.org_id where s.org_id=m.org_id and s.active and s.id<>p_site),'[]'::jsonb),
 'transfers',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select t.id,t.source_site,t.destination_site,t.source_batch,t.destination_item,t.servings,t.state,t.transferred_cost,t.received_servings,t.received_cost,t.reason,t.created_at,b.recipe_version_id as source_recipe_version_id from public.zp_prepared_transfers t join public.zp_production_batches b on b.id=t.source_batch where t.org_id=m.org_id and (t.source_site=p_site or t.destination_site=p_site) order by t.created_at desc limit 200)x),'[]'::jsonb));end $$;
alter table public.zp_prepared_transfers enable row level security;
revoke all on public.zp_prepared_transfers from public,anon,authenticated;
grant select,insert,update,delete on public.zp_prepared_transfers to service_role;
do $$ declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_prepared_match','zp_prepared_transfer_request','zp_prepared_transfer_decide','zp_prepared_transfer_dispatch','zp_prepared_transfer_receive','zp_prepared_transfer_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;end $$;
commit;
