-- Adapted NAXA Services supplier / purchase / receipt / supplier payment workflow.
-- Candidate only; all operations scoped, append-only events, no automatic external payment.
begin;
create table public.zp_suppliers(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,name text not null check(length(trim(name)) between 2 and 160),phone text not null check(length(phone)<=32),whatsapp text not null check(whatsapp='' or whatsapp~'^[0-9]{9,15}$'),terms_days int not null check(terms_days between 0 and 365),unique(id,org_id,site_id),foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id));
create table public.zp_purchases(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,supplier_id uuid not null,ingredient_id uuid not null,member_id uuid not null,request_id uuid not null,reference text not null check(length(trim(reference)) between 1 and 100),qty_milli bigint not null check(qty_milli between 1 and 1000000000),total_xaf bigint not null check(total_xaf between 1 and 2147483647),received_milli bigint not null default 0 check(received_milli between 0 and qty_milli),received_cost bigint not null default 0 check(received_cost between 0 and total_xaf),paid_xaf bigint not null default 0 check(paid_xaf between 0 and received_cost),created_at timestamptz not null default now(),unique(id,org_id,site_id),unique(site_id,reference),unique(member_id,request_id),foreign key(supplier_id,org_id,site_id) references public.zp_suppliers(id,org_id,site_id),foreign key(ingredient_id,org_id,site_id) references public.zp_ingredients(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_purchase_receipts(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,purchase_id uuid not null,lot_id uuid not null unique,member_id uuid not null,request_id uuid not null,qty_milli bigint not null check(qty_milli>0),cost_xaf bigint not null check(cost_xaf>=0),lot_label text not null,expires_on date,created_at timestamptz not null default now(),unique(member_id,request_id),foreign key(purchase_id,org_id,site_id) references public.zp_purchases(id,org_id,site_id),foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_supplier_payments(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,purchase_id uuid not null,member_id uuid not null,request_id uuid not null,amount_xaf bigint not null check(amount_xaf between 1 and 2147483647),method text not null check(method in ('cash','bank','mtn_momo','orange_money','card')),reference text not null check(length(trim(reference)) between 4 and 160),created_at timestamptz not null default now(),unique(member_id,request_id),unique(org_id,method,reference),foreign key(purchase_id,org_id,site_id) references public.zp_purchases(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create table public.zp_inventory_counts(id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,lot_id uuid not null,member_id uuid not null,request_id uuid not null,before_milli bigint not null check(before_milli>=0),counted_milli bigint not null check(counted_milli between 0 and before_milli),loss_cost bigint not null check(loss_cost>=0),reason text not null check(length(trim(reason)) between 5 and 500),created_at timestamptz not null default now(),unique(member_id,request_id),foreign key(lot_id,org_id,site_id) references public.zp_ingredient_lots(id,org_id,site_id),foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_supplier_add(p_access text,p_site uuid,p_name text,p_phone text,p_whatsapp text,p_terms int) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 insert into public.zp_suppliers(org_id,site_id,name,phone,whatsapp,terms_days) values(m.org_id,p_site,trim(p_name),trim(p_phone),p_whatsapp,p_terms) returning id into i;return i;end $$;
create function public.zp_purchase_create(p_access text,p_site uuid,p_supplier uuid,p_ingredient uuid,p_request uuid,p_reference text,p_qty bigint,p_total bigint) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_purchases;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_purchases where member_id=m.id and request_id=p_request;
 if x.id is not null then if (x.site_id,x.supplier_id,x.ingredient_id,x.reference,x.qty_milli,x.total_xaf) is distinct from (p_site,p_supplier,p_ingredient,trim(p_reference),p_qty,p_total) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return x.id;end if;
 if not exists(select 1 from public.zp_suppliers where id=p_supplier and org_id=m.org_id and site_id=p_site) or not exists(select 1 from public.zp_ingredients where id=p_ingredient and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_purchase_batches where site_id=p_site and reference=trim(p_reference)) then raise exception 'INVALID_PURCHASE_LINES';end if;
 insert into public.zp_purchases(org_id,site_id,supplier_id,ingredient_id,member_id,request_id,reference,qty_milli,total_xaf) values(m.org_id,p_site,p_supplier,p_ingredient,m.id,p_request,trim(p_reference),p_qty,p_total) returning id into i;return i;end $$;
create function public.zp_purchase_receive(p_access text,p_site uuid,p_purchase uuid,p_request uuid,p_qty bigint,p_label text,p_expires date) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_purchases;y public.zp_purchase_receipts;cost bigint;lot uuid;i uuid;sup text;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into y from public.zp_purchase_receipts where member_id=m.id and request_id=p_request;
 if y.id is not null then if (y.site_id,y.purchase_id,y.qty_milli,y.lot_label,y.expires_on) is distinct from (p_site,p_purchase,p_qty,trim(p_label),p_expires) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return y.id;end if;
 select * into x from public.zp_purchases where id=p_purchase and org_id=m.org_id and site_id=p_site for update;
 if x.id is null then raise exception 'DENIED';end if;
 if p_qty is null or p_qty<=0 or p_qty>x.qty_milli-x.received_milli then raise exception 'RECEIPT_EXCEEDS_PURCHASE';end if;
 if exists(select 1 from public.zp_ingredient_lots where member_id=m.id and request_id=p_request) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
 cost:=floor(x.total_xaf::numeric*(x.received_milli+p_qty)/x.qty_milli)::bigint-x.received_cost;
 select name into sup from public.zp_suppliers where id=x.supplier_id and org_id=m.org_id and site_id=p_site;
 lot:=public.zp_receive_lot(p_access,p_site,x.ingredient_id,p_request,p_label,sup,p_qty,cost,p_expires);
 insert into public.zp_purchase_receipts(org_id,site_id,purchase_id,lot_id,member_id,request_id,qty_milli,cost_xaf,lot_label,expires_on) values(m.org_id,p_site,x.id,lot,m.id,p_request,p_qty,cost,trim(p_label),p_expires) returning id into i;
 update public.zp_purchases set received_milli=received_milli+p_qty,received_cost=received_cost+cost where id=x.id;return i;end $$;
create function public.zp_supplier_pay(p_access text,p_site uuid,p_purchase uuid,p_request uuid,p_amount bigint,p_method text,p_reference text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_purchases;y public.zp_supplier_payments;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into y from public.zp_supplier_payments where member_id=m.id and request_id=p_request;
 if y.id is not null then if (y.site_id,y.purchase_id,y.amount_xaf,y.method,y.reference) is distinct from (p_site,p_purchase,p_amount,p_method,trim(p_reference)) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return y.id;end if;
 select * into x from public.zp_purchases where id=p_purchase and org_id=m.org_id and site_id=p_site for update;if x.id is null then raise exception 'DENIED';end if;
 if p_amount is null or p_amount<=0 or p_amount>x.received_cost-x.paid_xaf then raise exception 'PAYMENT_EXCEEDS_DEBT';end if;
 insert into public.zp_supplier_payments(org_id,site_id,purchase_id,member_id,request_id,amount_xaf,method,reference) values(m.org_id,p_site,x.id,m.id,p_request,p_amount,p_method,trim(p_reference)) returning id into i;
 update public.zp_purchases set paid_xaf=paid_xaf+p_amount where id=x.id;return i;end $$;
-- Physical count / loss: optimistic expected quantity prevents stale counts. Positive discrepancies require reviewed acquisition with cost.
create function public.zp_count_lot(p_access text,p_site uuid,p_lot uuid,p_request uuid,p_expected bigint,p_counted bigint,p_reason text) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;l public.zp_ingredient_lots;y public.zp_inventory_counts;c bigint;i uuid;begin m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into y from public.zp_inventory_counts where member_id=m.id and request_id=p_request;
 if y.id is not null then if (y.site_id,y.lot_id,y.before_milli,y.counted_milli,y.reason) is distinct from (p_site,p_lot,p_expected,p_counted,trim(p_reason)) then raise exception 'IDEMPOTENCY_CONFLICT';end if;return y.id;end if;
 select * into l from public.zp_ingredient_lots where id=p_lot and org_id=m.org_id and site_id=p_site for update;if l.id is null then raise exception 'DENIED';end if;
 if p_expected is distinct from l.remaining_milli then raise exception 'STALE_INVENTORY_COUNT';end if;
 if p_counted is null or p_counted<0 or p_counted>l.remaining_milli then raise exception 'COUNT_REQUIRES_REVIEW';end if;
 c:=case when p_counted=l.remaining_milli then 0 when p_counted=0 then l.remaining_cost else floor(l.remaining_cost::numeric*(l.remaining_milli-p_counted)/l.remaining_milli)::bigint end;
 insert into public.zp_inventory_counts(org_id,site_id,lot_id,member_id,request_id,before_milli,counted_milli,loss_cost,reason) values(m.org_id,p_site,l.id,m.id,p_request,l.remaining_milli,p_counted,c,trim(p_reason)) returning id into i;
 update public.zp_ingredient_lots set remaining_milli=p_counted,remaining_cost=remaining_cost-c where id=l.id;return i;end $$;
create function public.zp_procurement_snapshot(p_access text,p_site uuid) returns jsonb language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;begin m:=public.zp_erp_actor(p_access,p_site);
 return jsonb_build_object('suppliers',coalesce((select jsonb_agg(to_jsonb(s) order by s.name) from public.zp_suppliers s where s.org_id=m.org_id and s.site_id=p_site),'[]'::jsonb),'purchases',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (select id,supplier_id,ingredient_id,reference,qty_milli,total_xaf,received_milli,received_cost,paid_xaf,created_at from public.zp_purchases where org_id=m.org_id and site_id=p_site order by created_at desc limit 200) x),'[]'::jsonb),'batches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'reference',b.reference,'purchase_ids',b.purchase_ids,'supplier_id',b.supplier_id,'total_xaf',(select coalesce(sum(p.total_xaf),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id),'received_cost',(select coalesce(sum(p.received_cost),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id),'paid_xaf',(select coalesce(sum(p.paid_xaf),0) from public.zp_purchases p where p.id=any(b.purchase_ids) and p.site_id=b.site_id and p.org_id=b.org_id)) order by b.created_at desc) from (select * from public.zp_purchase_batches where org_id=m.org_id and site_id=p_site order by created_at desc limit 200)b),'[]'::jsonb),'debt_xaf',(select coalesce(sum(received_cost-paid_xaf),0) from public.zp_purchases where org_id=m.org_id and site_id=p_site),'loss_cost_xaf',(select coalesce(sum(loss_cost),0) from public.zp_inventory_counts where org_id=m.org_id and site_id=p_site));end $$;
do $$ declare t text;f record;begin
 foreach t in array array['zp_suppliers','zp_purchases','zp_purchase_receipts','zp_supplier_payments','zp_inventory_counts'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select,insert,update,delete on public.%I to service_role',t);end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('zp_supplier_add','zp_purchase_create','zp_purchase_receive','zp_supplier_pay','zp_count_lot','zp_procurement_snapshot') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);execute format('grant execute on function %s to service_role',f.sig);end loop;
end $$;

-- Bulk 3: a multi-line purchase reuses the existing atomic per-line receipt, lot,
-- supplier debt and payment primitives. No duplicate stock or financial engine.
create table public.zp_purchase_batches(
 id uuid primary key default gen_random_uuid(),org_id uuid not null,site_id uuid not null,
 supplier_id uuid not null,member_id uuid not null,request_id uuid not null,
 reference text not null check(length(trim(reference)) between 1 and 100),
 lines jsonb not null,purchase_ids uuid[] not null default '{}',created_at timestamptz not null default now(),
 unique(member_id,request_id),unique(site_id,reference),
 foreign key(site_id,org_id) references public.zp_site_modes(site_id,org_id),
 foreign key(supplier_id,org_id,site_id) references public.zp_suppliers(id,org_id,site_id),
 foreign key(member_id,org_id) references public.zp_members(id,org_id));
create function public.zp_purchase_batch_create(p_access text,p_site uuid,p_supplier uuid,p_request uuid,p_reference text,p_lines jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $$
declare m public.zp_members;x public.zp_purchase_batches;line jsonb;ids uuid[]:='{}';n int:=0;batch_id uuid;
begin
 m:=public.zp_erp_actor(p_access,p_site);
 perform 1 from public.zp_site_modes where site_id=p_site for update;
 select * into x from public.zp_purchase_batches where member_id=m.id and request_id=p_request;
 if x.id is not null then
  if (x.site_id,x.supplier_id,x.reference,x.lines) is distinct from (p_site,p_supplier,trim(p_reference),p_lines) then raise exception 'IDEMPOTENCY_CONFLICT';end if;
  return jsonb_build_object('id',x.id,'purchase_ids',x.purchase_ids);
 end if;
 if p_lines is null or jsonb_typeof(p_lines)<>'array' then raise exception 'INVALID_PURCHASE_LINES';end if;
 if jsonb_array_length(p_lines) not between 2 and 50 then raise exception 'INVALID_PURCHASE_LINES';end if;
 if not exists(select 1 from public.zp_suppliers where id=p_supplier and org_id=m.org_id and site_id=p_site) then raise exception 'DENIED';end if;
 if exists(select 1 from public.zp_purchases where site_id=p_site and reference=trim(p_reference)) then raise exception 'INVALID_PURCHASE_LINES';end if;
 insert into public.zp_purchase_batches(org_id,site_id,supplier_id,member_id,request_id,reference,lines)
 values(m.org_id,p_site,p_supplier,m.id,p_request,trim(p_reference),p_lines) returning id into batch_id;
 for line in select value from jsonb_array_elements(p_lines) loop
  if jsonb_typeof(line)<>'object' or not (line ?& array['ingredient_id','qty_milli','total_xaf']) then raise exception 'INVALID_PURCHASE_LINES';end if;
  if coalesce(line->>'qty_milli','') !~ '^[1-9][0-9]{0,9} or coalesce(line->>'total_xaf','') !~ '^[1-9][0-9]{0,9} then raise exception 'INVALID_PURCHASE_LINES';end if;
  if (line->>'qty_milli')::bigint>1000000000 or (line->>'total_xaf')::bigint>2147483647 then raise exception 'INVALID_PURCHASE_LINES';end if;
  n:=n+1;
  ids:=array_append(ids,public.zp_purchase_create(p_access,p_site,p_supplier,(line->>'ingredient_id')::uuid,gen_random_uuid(),'ML-'||batch_id::text||'-'||n::text,(line->>'qty_milli')::bigint,(line->>'total_xaf')::bigint));
 end loop;
 update public.zp_purchase_batches set purchase_ids=ids where id=batch_id;
 return jsonb_build_object('id',batch_id,'purchase_ids',ids);
end $$;
alter table public.zp_purchase_batches enable row level security;
revoke all on public.zp_purchase_batches from public,anon,authenticated;
grant select,insert,update,delete on public.zp_purchase_batches to service_role;
revoke all on function public.zp_purchase_batch_create(text,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.zp_purchase_batch_create(text,uuid,uuid,uuid,text,jsonb) to service_role;

commit;
