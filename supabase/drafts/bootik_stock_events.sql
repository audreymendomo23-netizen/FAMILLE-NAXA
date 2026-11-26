-- Isolated stock-event candidate, inspired by NAXA transactional receipts and inventory adjustments.
begin;
create table bootik.bk_stock_event_receipts (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,
 event_id uuid not null,balance_id uuid not null references bootik.bk_inventory_balances(id),
 kind text not null check(kind in ('receipt','loss','count','opening')),quantity numeric(20,6) not null check(quantity>=0),
 expected_version text not null, reason text not null check(length(reason) between 3 and 500),
 before_qty numeric(20,6) not null,after_qty numeric(20,6) not null,created_at timestamptz not null default now(),
 unique(organization_id,app_id,event_id),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
alter table bootik.bk_stock_event_receipts enable row level security;
alter table bootik.bk_stock_event_receipts force row level security;
revoke all on bootik.bk_stock_event_receipts from public,anon,authenticated;
create function bootik.bk_record_stock_event(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_balance uuid,p_event uuid,p_kind text,p_qty numeric,p_version text,p_reason text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare b bootik.bk_inventory_balances%rowtype;old bootik.bk_stock_event_receipts%rowtype;v_id uuid;v_next numeric;v_delta numeric;v_unit text;v_universe text;v_serial boolean;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_event is null or p_kind is null or p_kind not in ('receipt','loss','count','opening') or p_qty is null or p_qty<0 or p_qty>1000000000 or p_qty<>round(p_qty,6) or (p_kind<>'count' and p_qty=0) or p_version is null or length(p_version)>100 or p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'BOOTIK_STOCK_EVENT_INVALID';end if;
 if not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,(select activity_id from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':stock:'||p_event::text,0));
 select * into old from bootik.bk_stock_event_receipts where organization_id=p_org and app_id=p_app and event_id=p_event;
 if found then
  if (old.actor,old.location_id,old.balance_id,old.kind,old.quantity,old.expected_version,old.reason) is distinct from (p_actor,p_site,p_balance,p_kind,p_qty,p_version,btrim(p_reason)) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;
  return old.id;
 end if;
 select * into b from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site for update;
 if not found then raise exception 'BOOTIK_BALANCE_DENIED';end if;
 select universe_code into v_universe from bootik.bk_activities where id=b.activity_id and app_id=p_app and organization_id=p_org and status='active';
 if not found then raise exception 'BOOTIK_ACTIVITY_INACTIVE';end if;
 if not bootik.bk_has_entitlement(p_org,p_app,v_universe) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 select base_unit_code,is_serialized into v_unit,v_serial from bootik.bk_catalog_items where id=b.item_id and organization_id=p_org and app_id=p_app and activity_id=b.activity_id and status='active';
 if not found or v_serial then raise exception 'BOOTIK_ITEM_UNAVAILABLE';end if;
 if lower(v_unit) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and p_qty<>trunc(p_qty) then raise exception 'BOOTIK_STOCK_EVENT_INVALID';end if;
 if b.updated_at::text is distinct from p_version then raise exception 'BOOTIK_STOCK_VERSION_CONFLICT';end if;
 if p_kind='opening' and (b.quantity_on_hand<>0 or exists(select 1 from bootik.bk_inventory_movements m where m.organization_id=p_org and m.app_id=p_app and m.location_id=p_site and m.item_id=b.item_id)) then raise exception 'BOOTIK_OPENING_NOT_EMPTY';end if;
 if p_kind in ('receipt','opening') and b.lot_id is not null and not exists(select 1 from bootik.bk_product_lots l where l.id=b.lot_id and l.quality_state='available' and (l.expires_at is null or l.expires_at>=current_date)) then raise exception 'BOOTIK_LOT_UNAVAILABLE';end if;
 v_next:=case p_kind when 'opening' then p_qty when 'receipt' then b.quantity_on_hand+p_qty when 'loss' then b.quantity_on_hand-p_qty else p_qty end;
 if v_next<b.quantity_reserved+b.quantity_damaged then raise exception 'BOOTIK_STOCK_INSUFFICIENT';end if;
 v_delta:=v_next-b.quantity_on_hand;
 insert into bootik.bk_stock_event_receipts(organization_id,app_id,actor,location_id,event_id,balance_id,kind,quantity,expected_version,reason,before_qty,after_qty)
 values(p_org,p_app,p_actor,p_site,p_event,p_balance,p_kind,p_qty,p_version,btrim(p_reason),b.quantity_on_hand,v_next) returning id into v_id;
 if v_delta<>0 then
  update bootik.bk_inventory_balances set quantity_on_hand=v_next,updated_at=clock_timestamp() where id=b.id;
  insert into bootik.bk_inventory_movements(app_id,organization_id,activity_id,location_id,item_id,lot_id,movement_code,quantity_delta,unit_code,source_reference,idempotency_key,actor_user_id,reason)
  values(p_app,p_org,b.activity_id,p_site,b.item_id,b.lot_id,case p_kind when 'opening' then 'opening' when 'receipt' then 'purchase_receipt' when 'loss' then 'loss' else 'inventory_adjustment' end,v_delta,v_unit,v_id::text,'stock:'||p_event::text,p_actor,btrim(p_reason));
 end if;
 return v_id;
end $$;
revoke all on function bootik.bk_record_stock_event(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,text,text) from public,anon,authenticated;
-- NAXA 194: all-or-nothing inventory count, using BOOTIK's existing per-balance event.
create table bootik.bk_count_batches(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,activity_id uuid not null,
 reason text not null,lines jsonb not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
alter table bootik.bk_count_batches enable row level security;
alter table bootik.bk_count_batches force row level security;
revoke all on bootik.bk_count_batches from public,anon,authenticated;
create function bootik.bk_count_batch(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_batch uuid,p_activity uuid,p_reason text,p_lines jsonb)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare old bootik.bk_count_batches%rowtype; x jsonb; n integer;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,p_activity) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_batch is null or jsonb_typeof(p_lines) is distinct from 'array' or p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'BOOTIK_BATCH_INVALID';end if;
 n:=jsonb_array_length(p_lines);if n not between 1 and 30 then raise exception 'BOOTIK_BATCH_INVALID';end if;
 if (select count(distinct j.value->>'balance_id') from jsonb_array_elements(p_lines) as j(value))<>n or (select count(distinct j.value->>'event_id') from jsonb_array_elements(p_lines) as j(value))<>n then raise exception 'BOOTIK_BATCH_DUPLICATE';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':count-batch:'||p_batch::text,0));
 select * into old from bootik.bk_count_batches where id=p_batch and organization_id=p_org and app_id=p_app;
 if found then
  if (old.actor,old.location_id,old.activity_id,old.reason,old.lines) is distinct from (p_actor,p_site,p_activity,btrim(p_reason),p_lines) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;
  return old.id;
 end if;
 for x in select j from jsonb_array_elements(p_lines) j order by (j->>'balance_id')::uuid loop
  if not exists(select 1 from bootik.bk_inventory_balances b where b.id=(x->>'balance_id')::uuid and b.organization_id=p_org and b.app_id=p_app and b.location_id=p_site and b.activity_id=p_activity) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if exists(select 1 from bootik.bk_stock_event_receipts e where e.organization_id=p_org and e.app_id=p_app and e.event_id=(x->>'event_id')::uuid) then raise exception 'BOOTIK_BATCH_EVENT_REUSED';end if;
  perform bootik.bk_record_stock_event(p_org,p_app,p_actor,p_site,(x->>'balance_id')::uuid,(x->>'event_id')::uuid,'count',(x->>'quantity')::numeric,x->>'expected_version',btrim(p_reason));
 end loop;
 insert into bootik.bk_count_batches values(p_batch,p_org,p_app,p_actor,p_site,p_activity,btrim(p_reason),p_lines);
 return p_batch;
end $$;
revoke all on function bootik.bk_count_batch(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
-- NAXA 207 pattern adapted: shipment and receipt are separate events, no destination increment before receipt.
create table bootik.bk_stock_transfers(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,activity_id uuid not null,item_id uuid not null,lot_id uuid,source_site uuid not null,destination_site uuid not null,source_balance uuid not null,
 shipped_by uuid not null,quantity numeric(20,6) not null check(quantity>0),received numeric(20,6) not null default 0 check(received>=0 and received<=quantity),reason text not null,expected_version text not null,
 shipped_at timestamptz not null default clock_timestamp(),check(source_site<>destination_site),
 foreign key(activity_id,source_site,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id),
 foreign key(activity_id,destination_site,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
create table bootik.bk_transfer_receipts(
 id uuid primary key,transfer_id uuid not null references bootik.bk_stock_transfers(id),actor uuid not null,quantity numeric(20,6) not null check(quantity>0),reason text not null,created_at timestamptz not null default clock_timestamp()
);
alter table bootik.bk_stock_transfers enable row level security;alter table bootik.bk_stock_transfers force row level security;
alter table bootik.bk_transfer_receipts enable row level security;alter table bootik.bk_transfer_receipts force row level security;
revoke all on bootik.bk_stock_transfers,bootik.bk_transfer_receipts from public,anon,authenticated;
create function bootik.bk_ship_transfer(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_dest uuid,p_balance uuid,p_id uuid,p_qty numeric,p_version text,p_reason text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare b bootik.bk_inventory_balances%rowtype;old bootik.bk_stock_transfers%rowtype;u text; universe text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_id is null or p_dest is null or p_dest=p_site or p_qty is null or p_qty<=0 or p_qty>1000000000 or p_qty<>round(p_qty,6) or p_version is null or length(p_version)>100 or p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'BOOTIK_TRANSFER_INVALID';end if;
 select * into b from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,b.activity_id) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if not exists(select 1 from bootik.bk_activity_locations where activity_id=b.activity_id and location_id=p_dest and organization_id=p_org and app_id=p_app) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':transfer:'||p_id::text,0));
 select * into old from bootik.bk_stock_transfers where id=p_id and organization_id=p_org and app_id=p_app;
 if found then
  if (old.shipped_by,old.source_site,old.destination_site,old.source_balance,old.quantity,old.expected_version,old.reason) is distinct from (p_actor,p_site,p_dest,p_balance,p_qty,p_version,btrim(p_reason)) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 select * into b from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site for update;
 if not found or b.updated_at::text is distinct from p_version then raise exception 'BOOTIK_STOCK_VERSION_CONFLICT';end if;
 select universe_code into universe from bootik.bk_activities where id=b.activity_id and organization_id=p_org and app_id=p_app and status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,universe) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 select base_unit_code into u from bootik.bk_catalog_items where id=b.item_id and organization_id=p_org and app_id=p_app and activity_id=b.activity_id and status='active' and not is_serialized;
 if not found then raise exception 'BOOTIK_ITEM_UNAVAILABLE';end if;
 if lower(u) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and p_qty<>trunc(p_qty) then raise exception 'BOOTIK_TRANSFER_INVALID';end if;
 if b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged<p_qty then raise exception 'BOOTIK_STOCK_INSUFFICIENT';end if;
 if b.lot_id is not null and not exists(select 1 from bootik.bk_product_lots where id=b.lot_id and quality_state='available' and (expires_at is null or expires_at>=current_date)) then raise exception 'BOOTIK_LOT_UNAVAILABLE';end if;
 insert into bootik.bk_stock_transfers(id,organization_id,app_id,activity_id,item_id,lot_id,source_site,destination_site,source_balance,shipped_by,quantity,reason,expected_version) values(p_id,p_org,p_app,b.activity_id,b.item_id,b.lot_id,p_site,p_dest,b.id,p_actor,p_qty,btrim(p_reason),p_version);
 update bootik.bk_inventory_balances set quantity_on_hand=quantity_on_hand-p_qty,updated_at=clock_timestamp() where id=b.id;
 insert into bootik.bk_inventory_movements(app_id,organization_id,activity_id,location_id,item_id,lot_id,movement_code,quantity_delta,unit_code,source_reference,idempotency_key,actor_user_id,reason) values(p_app,p_org,b.activity_id,p_site,b.item_id,b.lot_id,'transfer_out',-p_qty,u,p_id::text,'transfer-out:'||p_id::text,p_actor,btrim(p_reason));
 return p_id;
end $$;
create function bootik.bk_receive_transfer(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_transfer uuid,p_id uuid,p_qty numeric,p_reason text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare t bootik.bk_stock_transfers%rowtype;old bootik.bk_transfer_receipts%rowtype;u text;universe text;v_balance uuid;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_id is null or p_qty is null or p_qty<=0 or p_qty<>round(p_qty,6) or p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'BOOTIK_TRANSFER_INVALID';end if;
 select * into t from bootik.bk_stock_transfers where id=p_transfer and organization_id=p_org and app_id=p_app and destination_site=p_site for update;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,t.activity_id) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select * into old from bootik.bk_transfer_receipts where id=p_id and transfer_id=p_transfer;
 if found then
  if (old.actor,old.quantity,old.reason) is distinct from (p_actor,p_qty,btrim(p_reason)) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 if t.received+p_qty>t.quantity then raise exception 'BOOTIK_TRANSFER_OVERRECEIPT';end if;
 select universe_code into universe from bootik.bk_activities where id=t.activity_id and organization_id=p_org and app_id=p_app and status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,universe) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 select base_unit_code into u from bootik.bk_catalog_items where id=t.item_id and organization_id=p_org and app_id=p_app and activity_id=t.activity_id and not is_serialized;
 if not found then raise exception 'BOOTIK_ITEM_UNAVAILABLE';end if;
 if lower(u) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and p_qty<>trunc(p_qty) then raise exception 'BOOTIK_TRANSFER_INVALID';end if;
 -- Destination staging balance: no silent merge with a different lot or physical location.
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':incoming:'||p_site::text||':'||t.item_id::text||':'||coalesce(t.lot_id::text,''),0));
 select id into v_balance from bootik.bk_inventory_balances where organization_id=p_org and app_id=p_app and activity_id=t.activity_id and location_id=p_site and item_id=t.item_id and lot_id is not distinct from t.lot_id and storage_location_id is null for update;
 if not found then insert into bootik.bk_inventory_balances(app_id,organization_id,activity_id,location_id,item_id,lot_id) values(p_app,p_org,t.activity_id,p_site,t.item_id,t.lot_id) returning id into v_balance;end if;
 insert into bootik.bk_transfer_receipts(id,transfer_id,actor,quantity,reason) values(p_id,p_transfer,p_actor,p_qty,btrim(p_reason));
 update bootik.bk_stock_transfers set received=received+p_qty where id=t.id;
 update bootik.bk_inventory_balances set quantity_on_hand=quantity_on_hand+p_qty,updated_at=clock_timestamp() where id=v_balance;
 insert into bootik.bk_inventory_movements(app_id,organization_id,activity_id,location_id,item_id,lot_id,movement_code,quantity_delta,unit_code,source_reference,idempotency_key,actor_user_id,reason) values(p_app,p_org,t.activity_id,p_site,t.item_id,t.lot_id,'transfer_in',p_qty,u,t.id::text,'transfer-in:'||p_id::text,p_actor,btrim(p_reason));
 return p_id;
end $$;
revoke all on function bootik.bk_ship_transfer(uuid,uuid,uuid,uuid,uuid,uuid,uuid,numeric,text,text),bootik.bk_receive_transfer(uuid,uuid,uuid,uuid,uuid,uuid,numeric,text) from public,anon,authenticated;

-- Atomic create-only import; an existing quantity is never overwritten.
create table bootik.bk_stock_imports(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,activity_id uuid not null,
 rows jsonb not null,result jsonb not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
alter table bootik.bk_stock_imports enable row level security;alter table bootik.bk_stock_imports force row level security;
revoke all on bootik.bk_stock_imports from public,anon,authenticated;
create function bootik.bk_apply_stock_import(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_activity uuid,p_batch uuid,p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare previous bootik.bk_stock_imports%rowtype;j jsonb;item uuid;balance uuid;version text;qty numeric;report jsonb:='[]'::jsonb;u text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,p_activity) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select a.universe_code into u from bootik.bk_activities a join bootik.bk_activity_locations al on (al.activity_id,al.organization_id,al.app_id)=(a.id,a.organization_id,a.app_id) where a.id=p_activity and a.organization_id=p_org and a.app_id=p_app and a.status='active' and al.location_id=p_site;
 if not found or not bootik.bk_has_entitlement(p_org,p_app,u) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_batch is null or jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) not between 1 and 30 then raise exception 'BOOTIK_IMPORT_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':import:'||p_batch::text,0));
 select * into previous from bootik.bk_stock_imports where id=p_batch and organization_id=p_org and app_id=p_app;
 if found then
  if (previous.actor,previous.location_id,previous.activity_id,previous.rows) is distinct from (p_actor,p_site,p_activity,p_rows) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;
  return previous.result;
 end if;
 for j in select value from jsonb_array_elements(p_rows) loop
  qty:=(j->>'quantity')::numeric;
  if j->>'status' is distinct from 'create' or qty is null or qty<0 or qty>1000000000 or qty<>round(qty,6) then raise exception 'BOOTIK_IMPORT_INVALID';end if;
  item:=bootik.bk_create_master(p_org,p_app,p_actor,p_site,p_activity,gen_random_uuid(),'item',j->'data');
  select id,updated_at::text into balance,version from bootik.bk_inventory_balances where item_id=item and organization_id=p_org and app_id=p_app and location_id=p_site;
  if not found then raise exception 'BOOTIK_IMPORT_INVALID';end if;
  if qty>0 then perform bootik.bk_record_stock_event(p_org,p_app,p_actor,p_site,balance,gen_random_uuid(),'opening',qty,version,'Import initial '||p_batch::text);end if;
  report:=report||jsonb_build_array(jsonb_build_object('row',j->'row','item_id',item,'balance_id',balance,'quantity',qty));
 end loop;
 insert into bootik.bk_stock_imports(id,organization_id,app_id,actor,location_id,activity_id,rows,result) values(p_batch,p_org,p_app,p_actor,p_site,p_activity,p_rows,report);
 return report;
end $$;
revoke all on function bootik.bk_apply_stock_import(uuid,uuid,uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;

-- NAXA FEFO allocation with BOOTIK scope, base-unit conversions and immutable grouped receipt.
create table bootik.bk_item_sale_groups(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,activity_id uuid not null,item_id uuid not null,
 unit_code text not null,quantity numeric(20,6) not null,base_factor numeric(20,6) not null,base_price bigint not null,allocations jsonb not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
create table bootik.bk_stock_setup_receipts(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,item_id uuid not null,kind text not null,payload jsonb not null,result_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
alter table bootik.bk_item_sale_groups enable row level security;alter table bootik.bk_item_sale_groups force row level security;
alter table bootik.bk_stock_setup_receipts enable row level security;alter table bootik.bk_stock_setup_receipts force row level security;
revoke all on bootik.bk_item_sale_groups,bootik.bk_stock_setup_receipts from public,anon,authenticated;
create function bootik.bk_sell_item(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_item uuid,p_id uuid,p_unit text,p_qty numeric,p_price bigint)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;u text;factor numeric;left_qty numeric;taken numeric;old bootik.bk_item_sale_groups%rowtype;row_data record;line_id uuid;alloc jsonb:='[]'::jsonb;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 if p_id is null or p_unit is null or length(p_unit)>40 or p_qty is null or p_qty<=0 or p_qty>1000000000 or p_qty<>round(p_qty,6) or p_price is null or p_price<0 then raise exception 'BOOTIK_INVALID_SALE';end if;
 select activity_id,base_unit_code into a,u from bootik.bk_catalog_items where id=p_item and organization_id=p_org and app_id=p_app and status='active' and not is_serialized;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) or not exists(select 1 from bootik.bk_activity_locations where activity_id=a and location_id=p_site and organization_id=p_org and app_id=p_app) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':item-sale:'||p_id::text,0));
 select * into old from bootik.bk_item_sale_groups where id=p_id and organization_id=p_org and app_id=p_app;
 if found then
  if (old.actor,old.location_id,old.item_id,old.unit_code,old.quantity,old.base_price) is distinct from (p_actor,p_site,p_item,p_unit,p_qty,p_price) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 select to_base_factor into factor from bootik.bk_item_units where item_id=p_item and organization_id=p_org and app_id=p_app and activity_id=a and unit_code=p_unit and unit_role in ('base','sale');
 if not found then raise exception 'BOOTIK_INVALID_UNIT';end if;
 if lower(p_unit) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and p_qty<>trunc(p_qty) then raise exception 'BOOTIK_INVALID_SALE';end if;
 left_qty:=p_qty*factor;if left_qty>1000000000 or left_qty<>round(left_qty,6) then raise exception 'BOOTIK_INVALID_SALE';end if;
 if lower(u) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and left_qty<>trunc(left_qty) then raise exception 'BOOTIK_INVALID_UNIT';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':sale-item:'||p_site::text||':'||p_item::text,0));
 -- Stable locking order across all candidate balances before allocation.
 perform 1 from bootik.bk_inventory_balances b where b.organization_id=p_org and b.app_id=p_app and b.activity_id=a and b.location_id=p_site and b.item_id=p_item order by b.id for update;
 for row_data in select b.id,b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged as available from bootik.bk_inventory_balances b left join bootik.bk_product_lots l on l.id=b.lot_id where b.organization_id=p_org and b.app_id=p_app and b.activity_id=a and b.location_id=p_site and b.item_id=p_item and b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged>0 and (b.lot_id is null or (l.quality_state='available' and (l.expires_at is null or l.expires_at>=current_date))) order by (b.lot_id is null),l.expires_at asc nulls last,l.created_at asc nulls last,l.id asc nulls last,b.id loop
  exit when left_qty=0;taken:=least(left_qty,row_data.available);
  line_id:=bootik.bk_record_sale(p_org,p_app,p_actor,p_site,row_data.id,taken,p_price,'item-sale:'||p_id::text||':'||row_data.id::text);
  alloc:=alloc||jsonb_build_array(jsonb_build_object('balance_id',row_data.id,'sale_id',line_id,'base_quantity',taken));left_qty:=left_qty-taken;
 end loop;
 if left_qty<>0 then raise exception 'BOOTIK_STOCK_INSUFFICIENT';end if;
 insert into bootik.bk_item_sale_groups(id,organization_id,app_id,actor,location_id,activity_id,item_id,unit_code,quantity,base_factor,base_price,allocations) values(p_id,p_org,p_app,p_actor,p_site,a,p_item,p_unit,p_qty,factor,p_price,alloc);
 return p_id;
end $$;
create function bootik.bk_setup_stock(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_item uuid,p_id uuid,p_kind text,p_data jsonb)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;u text;universe text;old bootik.bk_stock_setup_receipts%rowtype;v uuid;v_lot_id uuid;v_lot_code text;expiry date;origin text;v_unit_code text;factor numeric;prior bootik.bk_product_lots%rowtype;prior_unit bootik.bk_item_units%rowtype;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_id is null or p_kind is null or p_kind not in ('lot','unit') or jsonb_typeof(p_data) is distinct from 'object' then raise exception 'BOOTIK_SETUP_INVALID';end if;
 select activity_id,base_unit_code into a,u from bootik.bk_catalog_items where id=p_item and organization_id=p_org and app_id=p_app and status='active' and not is_serialized;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) or not exists(select 1 from bootik.bk_activity_locations where activity_id=a and location_id=p_site and organization_id=p_org and app_id=p_app) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select universe_code into universe from bootik.bk_activities where id=a and organization_id=p_org and app_id=p_app and status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,universe) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':setup:'||p_id::text,0));
 select * into old from bootik.bk_stock_setup_receipts where id=p_id and organization_id=p_org and app_id=p_app;
 if found then
  if (old.actor,old.location_id,old.item_id,old.kind,old.payload) is distinct from (p_actor,p_site,p_item,p_kind,p_data) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.result_id;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':setup-item:'||p_item::text,0));
 if p_kind='lot' then
  v_lot_code:=btrim(p_data->>'lot_code');expiry:=nullif(p_data->>'expiry','')::date;origin:=nullif(btrim(p_data->>'origin'),'');
  if v_lot_code is null or length(v_lot_code) not between 1 and 80 or length(coalesce(origin,''))>160 or (expiry is not null and expiry<current_date) then raise exception 'BOOTIK_SETUP_INVALID';end if;
  select * into prior from bootik.bk_product_lots l where l.item_id=p_item and l.organization_id=p_org and l.app_id=p_app and l.activity_id=a and l.lot_code=v_lot_code;
  if found then
   if (prior.expires_at,prior.origin_label) is distinct from (expiry,origin) or prior.quality_state<>'available' then raise exception 'BOOTIK_LOT_UNAVAILABLE';end if;v_lot_id:=prior.id;
  else
   insert into bootik.bk_product_lots(app_id,organization_id,activity_id,item_id,lot_code,expires_at,origin_label) values(p_app,p_org,a,p_item,v_lot_code,expiry,origin) returning id into v_lot_id;
  end if;
  select id into v from bootik.bk_inventory_balances b where b.organization_id=p_org and b.app_id=p_app and b.activity_id=a and b.location_id=p_site and b.item_id=p_item and b.lot_id=v_lot_id and b.storage_location_id is null;
  if not found then insert into bootik.bk_inventory_balances(app_id,organization_id,activity_id,location_id,item_id,lot_id) values(p_app,p_org,a,p_site,p_item,v_lot_id) returning id into v;end if;
 else
  -- Units belong to the item across sites: do not widen an assignment at one site.
  if exists(select 1 from bootik.bk_activity_locations al where al.activity_id=a and al.organization_id=p_org and al.app_id=p_app and not bootik.bk_can_access_activity(p_org,p_app,p_actor,al.location_id,a)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  v_unit_code:=btrim(p_data->>'unit_code');factor:=(p_data->>'factor')::numeric;
  if v_unit_code is null or length(v_unit_code) not between 1 and 40 or v_unit_code=u or factor is null or factor<=0 or factor>1000000 or factor<>round(factor,6) then raise exception 'BOOTIK_SETUP_INVALID';end if;
  if lower(u) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and factor<>trunc(factor) then raise exception 'BOOTIK_INVALID_UNIT';end if;
  select * into prior_unit from bootik.bk_item_units i where i.item_id=p_item and i.organization_id=p_org and i.app_id=p_app and i.activity_id=a and i.unit_code=v_unit_code;
  if found then
   if prior_unit.to_base_factor<>factor or prior_unit.unit_role<>'sale' then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;v:=prior_unit.id;
  else insert into bootik.bk_item_units(app_id,organization_id,activity_id,item_id,unit_code,unit_role,to_base_factor) values(p_app,p_org,a,p_item,v_unit_code,'sale',factor) returning id into v;end if;
 end if;
 insert into bootik.bk_stock_setup_receipts(id,organization_id,app_id,actor,location_id,item_id,kind,payload,result_id) values(p_id,p_org,p_app,p_actor,p_site,p_item,p_kind,p_data,v);
 return v;
end $$;
revoke all on function bootik.bk_sell_item(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,bigint),bootik.bk_setup_stock(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;

commit;
