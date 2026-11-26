-- Isolated stock-event candidate, inspired by NAXA transactional receipts and inventory adjustments.
begin;
create table bootik.bk_stock_event_receipts (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,
 event_id uuid not null,balance_id uuid not null references bootik.bk_inventory_balances(id),
 kind text not null check(kind in ('receipt','loss','count','opening')),quantity numeric(20,6) not null check(quantity>=0),
 expected_version text not null, reason text not null check(length(reason) between 3 and 500),
 before_qty numeric(20,6) not null,after_qty numeric(20,6) not null,landed_cost_fcfa bigint check(landed_cost_fcfa is null or landed_cost_fcfa>=0),before_unit_cost_fcfa numeric(20,6),after_unit_cost_fcfa numeric(20,6),created_at timestamptz not null default now(),
 unique(organization_id,app_id,event_id),
 foreign key(organization_id,app_id,actor,location_id) references bootik.bk_member_sites(organization_id,app_id,user_id,location_id)
);
alter table bootik.bk_stock_event_receipts enable row level security;
alter table bootik.bk_stock_event_receipts force row level security;
revoke all on bootik.bk_stock_event_receipts from public,anon,authenticated;
create function bootik.bk_record_stock_event(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_balance uuid,p_event uuid,p_kind text,p_qty numeric,p_version text,p_reason text,p_landed_cost bigint default null)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare b bootik.bk_inventory_balances%rowtype;old bootik.bk_stock_event_receipts%rowtype;v_id uuid;v_next numeric;v_delta numeric;v_unit text;v_universe text;v_serial boolean;v_next_cost numeric;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_event is null or p_kind is null or p_kind not in ('receipt','loss','count','opening') or p_qty is null or p_qty<0 or p_qty>1000000000 or p_qty<>round(p_qty,6) or (p_kind<>'count' and p_qty=0) or p_version is null or length(p_version)>100 or p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'BOOTIK_STOCK_EVENT_INVALID';end if;
 if p_landed_cost is not null and (p_kind not in ('receipt','opening') or p_landed_cost<0 or p_landed_cost>9007199254740991) then raise exception 'BOOTIK_STOCK_EVENT_INVALID';end if;
 if not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,(select activity_id from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if not bootik.bk_resource_gate(p_org,p_app,p_actor,p_site,'sync-stock','{}'::jsonb) or not bootik.bk_resource_allowed(p_org,p_app,p_actor,p_site,'storage',(select storage_location_id from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site)) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':stock:'||p_event::text,0));
 select * into old from bootik.bk_stock_event_receipts where organization_id=p_org and app_id=p_app and event_id=p_event;
 if found then
  if (old.actor,old.location_id,old.balance_id,old.kind,old.quantity,old.expected_version,old.reason,old.landed_cost_fcfa) is distinct from (p_actor,p_site,p_balance,p_kind,p_qty,p_version,btrim(p_reason),p_landed_cost) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;
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
 v_next_cost:=case when v_delta<=0 then b.unit_cost_fcfa when p_landed_cost is null or (b.quantity_on_hand>0 and b.unit_cost_fcfa is null) then null else round((b.quantity_on_hand*coalesce(b.unit_cost_fcfa,0)+p_landed_cost)/v_next,6) end;
 insert into bootik.bk_stock_event_receipts(organization_id,app_id,actor,location_id,event_id,balance_id,kind,quantity,expected_version,reason,before_qty,after_qty,landed_cost_fcfa,before_unit_cost_fcfa,after_unit_cost_fcfa)
 values(p_org,p_app,p_actor,p_site,p_event,p_balance,p_kind,p_qty,p_version,btrim(p_reason),b.quantity_on_hand,v_next,p_landed_cost,b.unit_cost_fcfa,v_next_cost) returning id into v_id;
 if v_delta<>0 then
  update bootik.bk_inventory_balances set quantity_on_hand=v_next,unit_cost_fcfa=v_next_cost,updated_at=clock_timestamp() where id=b.id;
  insert into bootik.bk_inventory_movements(app_id,organization_id,activity_id,location_id,item_id,lot_id,movement_code,quantity_delta,unit_code,source_reference,idempotency_key,actor_user_id,reason)
  values(p_app,p_org,b.activity_id,p_site,b.item_id,b.lot_id,case p_kind when 'opening' then 'opening' when 'receipt' then 'purchase_receipt' when 'loss' then 'loss' else 'inventory_adjustment' end,v_delta,v_unit,v_id::text,'stock:'||p_event::text,p_actor,btrim(p_reason));
 end if;
 return v_id;
end $$;
revoke all on function bootik.bk_record_stock_event(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,text,text,bigint) from public,anon,authenticated;
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
 shipped_by uuid not null,unit_cost_snapshot_fcfa numeric(20,6) check(unit_cost_snapshot_fcfa is null or unit_cost_snapshot_fcfa>=0),quantity numeric(20,6) not null check(quantity>0),received numeric(20,6) not null default 0 check(received>=0 and received<=quantity),reason text not null,expected_version text not null,
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
 insert into bootik.bk_stock_transfers(id,organization_id,app_id,activity_id,item_id,lot_id,source_site,destination_site,source_balance,shipped_by,unit_cost_snapshot_fcfa,quantity,reason,expected_version) values(p_id,p_org,p_app,b.activity_id,b.item_id,b.lot_id,p_site,p_dest,b.id,p_actor,b.unit_cost_fcfa,p_qty,btrim(p_reason),p_version);
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
 update bootik.bk_inventory_balances set unit_cost_fcfa=case when t.unit_cost_snapshot_fcfa is null or (quantity_on_hand>0 and unit_cost_fcfa is null) then null else round((quantity_on_hand*coalesce(unit_cost_fcfa,0)+p_qty*t.unit_cost_snapshot_fcfa)/(quantity_on_hand+p_qty),6) end,quantity_on_hand=quantity_on_hand+p_qty,updated_at=clock_timestamp() where id=v_balance;
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
create function bootik.bk_sell_item(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_item uuid,p_id uuid,p_unit text,p_qty numeric,p_price bigint,p_cash_session uuid default null)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;u text;factor numeric;left_qty numeric;taken numeric;old bootik.bk_item_sale_groups%rowtype;row_data record;line_id uuid;alloc jsonb:='[]'::jsonb;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 perform bootik.bk_assert_sale_resource(p_org,p_app,p_actor,p_site,p_cash_session);
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
 for row_data in select b.id,b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged as available from bootik.bk_inventory_balances b left join bootik.bk_product_lots l on l.id=b.lot_id where b.organization_id=p_org and b.app_id=p_app and b.activity_id=a and b.location_id=p_site and b.item_id=p_item and bootik.bk_resource_catalog(p_org,p_app,p_actor,p_site,b.activity_id,b.storage_location_id) and b.quantity_on_hand-b.quantity_reserved-b.quantity_damaged>0 and (b.lot_id is null or (l.quality_state='available' and (l.expires_at is null or l.expires_at>=current_date))) order by (b.lot_id is null),l.expires_at asc nulls last,l.created_at asc nulls last,l.id asc nulls last,b.id loop
  exit when left_qty=0;taken:=least(left_qty,row_data.available);
  line_id:=bootik.bk_record_sale(p_org,p_app,p_actor,p_site,row_data.id,taken,p_price,'item-sale:'||p_id::text||':'||row_data.id::text,p_cash_session);
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
revoke all on function bootik.bk_sell_item(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,bigint,uuid),bootik.bk_setup_stock(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;

-- NAXA Services purchasing workflow adapted to BOOTIK's versioned stock receipt.
-- One order line per reference in this first connected flow; no financial transfer is executed.
create table bootik.bk_purchase_orders (
 id uuid primary key,organization_id uuid not null,app_id uuid not null,activity_id uuid not null,location_id uuid not null,actor uuid not null,
 supplier_id uuid not null,balance_id uuid not null references bootik.bk_inventory_balances(id),reference text not null,quantity numeric(20,6) not null check(quantity>0),unit_cost_fcfa bigint not null check(unit_cost_fcfa>=0),
 received_quantity numeric(20,6) not null default 0,received_amount_fcfa bigint not null default 0,paid_amount_fcfa bigint not null default 0,created_at timestamptz not null default clock_timestamp(),
 check(received_quantity between 0 and quantity),check(paid_amount_fcfa between 0 and received_amount_fcfa),
 unique(organization_id,app_id,activity_id,location_id,reference),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id),
 foreign key(supplier_id,organization_id,activity_id,app_id) references bootik.bk_suppliers(id,organization_id,activity_id,app_id)
);
create table bootik.bk_purchase_receipts (
 id uuid primary key,order_id uuid not null references bootik.bk_purchase_orders(id),actor uuid not null,quantity numeric(20,6) not null check(quantity>0),amount_fcfa bigint not null check(amount_fcfa>=0),freight_fcfa bigint not null check(freight_fcfa>=0),stock_receipt_id uuid not null references bootik.bk_stock_event_receipts(id),created_at timestamptz not null default clock_timestamp()
);
create table bootik.bk_supplier_payments (
 id uuid primary key,order_id uuid not null references bootik.bk_purchase_orders(id),actor uuid not null,amount_fcfa bigint not null check(amount_fcfa>0),method text not null check(method in ('cash','bank','mobile_money')),reference text not null,created_at timestamptz not null default clock_timestamp(),
 unique(order_id,method,reference)
);
do $$ declare t text;begin foreach t in array array['bk_purchase_orders','bk_purchase_receipts','bk_supplier_payments'] loop execute format('alter table bootik.%I enable row level security',t);execute format('alter table bootik.%I force row level security',t);execute format('revoke all on bootik.%I from public,anon,authenticated',t);end loop;end $$;
create function bootik.bk_purchase_create(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_id uuid,p_supplier uuid,p_balance uuid,p_ref text,p_qty numeric,p_cost bigint)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare b bootik.bk_inventory_balances%rowtype;old bootik.bk_purchase_orders%rowtype;u text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_id is null or p_ref is null or length(btrim(p_ref)) not between 3 and 80 or p_qty is null or p_qty<=0 or p_qty>1000000000 or p_qty<>round(p_qty,6) or p_cost is null or p_cost<0 or p_qty*p_cost<>round(p_qty*p_cost) or p_qty*p_cost>9007199254740991 then raise exception 'BOOTIK_PURCHASE_INVALID';end if;
 select * into b from bootik.bk_inventory_balances where id=p_balance and organization_id=p_org and app_id=p_app and location_id=p_site;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,b.activity_id) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if not exists(select 1 from bootik.bk_suppliers where id=p_supplier and organization_id=p_org and app_id=p_app and activity_id=b.activity_id and status='active') then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select universe_code into u from bootik.bk_activities where id=b.activity_id and organization_id=p_org and app_id=p_app and status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,u) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 select base_unit_code into u from bootik.bk_catalog_items where id=b.item_id and organization_id=p_org and app_id=p_app and activity_id=b.activity_id and status='active' and not is_serialized;
 if not found or (lower(u) in ('unit','unite','unité','piece','pièce','bouteille','carton','pack','sac','casier','palette') and p_qty<>trunc(p_qty)) then raise exception 'BOOTIK_PURCHASE_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':purchase:'||p_id::text,0));
 select * into old from bootik.bk_purchase_orders where id=p_id and organization_id=p_org and app_id=p_app;
 if found then
  if (old.actor,old.location_id,old.supplier_id,old.balance_id,old.reference,old.quantity,old.unit_cost_fcfa) is distinct from (p_actor,p_site,p_supplier,p_balance,btrim(p_ref),p_qty,p_cost) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 insert into bootik.bk_purchase_orders(id,organization_id,app_id,activity_id,location_id,actor,supplier_id,balance_id,reference,quantity,unit_cost_fcfa) values(p_id,p_org,p_app,b.activity_id,p_site,p_actor,p_supplier,p_balance,btrim(p_ref),p_qty,p_cost);
 return p_id;
end $$;
create function bootik.bk_purchase_receive(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_order uuid,p_id uuid,p_qty numeric,p_freight bigint)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare o bootik.bk_purchase_orders%rowtype;old bootik.bk_purchase_receipts%rowtype;v_version text;v_stock uuid;v_amount numeric;u text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_id is null or p_qty is null or p_qty<=0 or p_qty<>round(p_qty,6) or p_freight is null or p_freight<0 or p_freight>9007199254740991 then raise exception 'BOOTIK_PURCHASE_INVALID';end if;
 select * into o from bootik.bk_purchase_orders where id=p_order and organization_id=p_org and app_id=p_app and location_id=p_site for update;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,o.activity_id) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select * into old from bootik.bk_purchase_receipts where id=p_id and order_id=p_order;
 if found then
  if (old.actor,old.quantity,old.freight_fcfa) is distinct from (p_actor,p_qty,p_freight) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 if o.received_quantity+p_qty>o.quantity then raise exception 'BOOTIK_PURCHASE_OVERRECEIPT';end if;
 v_amount:=p_qty*o.unit_cost_fcfa;if v_amount<>round(v_amount) or v_amount+p_freight>9007199254740991 or o.received_amount_fcfa+v_amount>9007199254740991 then raise exception 'BOOTIK_PURCHASE_INVALID';end if;
 select updated_at::text into v_version from bootik.bk_inventory_balances where id=o.balance_id and organization_id=p_org and app_id=p_app and location_id=p_site and activity_id=o.activity_id for update;
 if not found then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 v_stock:=bootik.bk_record_stock_event(p_org,p_app,p_actor,p_site,o.balance_id,gen_random_uuid(),'receipt',p_qty,v_version,'Commande '||o.reference,(v_amount+p_freight)::bigint);
 insert into bootik.bk_purchase_receipts(id,order_id,actor,quantity,amount_fcfa,freight_fcfa,stock_receipt_id) values(p_id,p_order,p_actor,p_qty,v_amount::bigint,p_freight,v_stock);
 update bootik.bk_purchase_orders set received_quantity=received_quantity+p_qty,received_amount_fcfa=received_amount_fcfa+v_amount::bigint where id=o.id;
 return p_id;
end $$;
create function bootik.bk_purchase_pay(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_order uuid,p_id uuid,p_amount bigint,p_method text,p_ref text)
returns uuid language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare o bootik.bk_purchase_orders%rowtype;old bootik.bk_supplier_payments%rowtype;u text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_id is null or p_amount is null or p_amount<=0 or p_amount>9007199254740991 or p_method is null or p_method not in ('cash','bank','mobile_money') or p_ref is null or length(btrim(p_ref)) not between 3 and 120 then raise exception 'BOOTIK_PURCHASE_INVALID';end if;
 select * into o from bootik.bk_purchase_orders where id=p_order and organization_id=p_org and app_id=p_app and location_id=p_site for update;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,o.activity_id) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select universe_code into u from bootik.bk_activities where id=o.activity_id and organization_id=p_org and app_id=p_app and status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,u) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 select * into old from bootik.bk_supplier_payments where id=p_id and order_id=p_order;
 if found then
  if (old.actor,old.amount_fcfa,old.method,old.reference) is distinct from (p_actor,p_amount,p_method,btrim(p_ref)) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.id;
 end if;
 if p_amount>o.received_amount_fcfa-o.paid_amount_fcfa then raise exception 'BOOTIK_PURCHASE_OVERPAYMENT';end if;
 perform bootik.bk_approval_check(p_org,p_app,p_actor,p_site,o.activity_id,'purchase-pay',p_id,p_amount,jsonb_build_object('order_id',p_order,'method',p_method,'reference',btrim(p_ref)),false);
 insert into bootik.bk_supplier_payments(id,order_id,actor,amount_fcfa,method,reference) values(p_id,p_order,p_actor,p_amount,p_method,btrim(p_ref));
 update bootik.bk_purchase_orders set paid_amount_fcfa=paid_amount_fcfa+p_amount where id=o.id;
 return p_id;
end $$;
revoke all on function bootik.bk_purchase_create(uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,bigint),bootik.bk_purchase_receive(uuid,uuid,uuid,uuid,uuid,uuid,numeric,bigint),bootik.bk_purchase_pay(uuid,uuid,uuid,uuid,uuid,uuid,bigint,text,text) from public,anon,authenticated;

-- NAXA SERVICES cash register/session lifecycle, BOOTIK's existing FEFO sales are the sole stock mutation.
create table bootik.bk_registers(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,activity_id uuid not null,location_id uuid not null,code text not null,name text not null,actor uuid not null,created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,app_id,activity_id,location_id,code),foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
create table bootik.bk_cash_sessions(
 id uuid primary key,register_id uuid not null references bootik.bk_registers(id),opened_by uuid not null,opening_float_fcfa bigint not null check(opening_float_fcfa>=0),
 opened_at timestamptz not null default clock_timestamp(),closed_at timestamptz,closed_by uuid,expected_close_fcfa bigint,counted_close_fcfa bigint,variance_reason text,
 check(counted_close_fcfa is null or counted_close_fcfa>=0)
);
create unique index bk_register_single_open on bootik.bk_cash_sessions(register_id) where closed_at is null;
create table bootik.bk_cash_checkouts(
 id uuid primary key,session_id uuid not null references bootik.bk_cash_sessions(id),actor uuid not null,total_fcfa bigint not null check(total_fcfa>=0),tender_fcfa bigint not null check(tender_fcfa>=total_fcfa),sale_groups jsonb not null,created_at timestamptz not null default clock_timestamp()
);
create table bootik.bk_cash_movements(
 id uuid primary key,session_id uuid not null references bootik.bk_cash_sessions(id),actor uuid not null,kind text not null check(kind in ('in','out','expense')),amount_fcfa bigint not null check(amount_fcfa>0),reason text not null,created_at timestamptz not null default clock_timestamp()
);
create table bootik.bk_cash_operation_receipts(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,activity_id uuid not null,location_id uuid not null,actor uuid not null,kind text not null,payload jsonb not null,result jsonb not null,created_at timestamptz not null default clock_timestamp()
);
do $$ declare t text;begin foreach t in array array['bk_registers','bk_cash_sessions','bk_cash_checkouts','bk_cash_movements','bk_cash_operation_receipts'] loop execute format('alter table bootik.%I enable row level security',t);execute format('alter table bootik.%I force row level security',t);execute format('revoke all on bootik.%I from public,anon,authenticated',t);end loop;end $$;
create function bootik.bk_cash_action(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_kind text,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;rid uuid;sid uuid;req uuid;u text;reg bootik.bk_registers%rowtype;ses bootik.bk_cash_sessions%rowtype;old bootik.bk_cash_operation_receipts%rowtype;answer jsonb;line jsonb;groups jsonb:='[]'::jsonb;gid uuid;total numeric:=0;amt bigint;expected numeric;why text;category text;
begin
 if p_kind not in ('register','open','checkout','movement','close') or jsonb_typeof(p_data) is distinct from 'object' then raise exception 'BOOTIK_CASH_INVALID';end if;
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,p_kind in ('register','movement','close'));
 a:=(p_data->>'activity_id')::uuid;req:=(p_data->>'request_id')::uuid;
 if req is null or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 select x.universe_code into u from bootik.bk_activities x join bootik.bk_activity_locations l on (l.activity_id,l.organization_id,l.app_id)=(x.id,x.organization_id,x.app_id) where x.id=a and x.organization_id=p_org and x.app_id=p_app and l.location_id=p_site and x.status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,u) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 if not bootik.bk_resource_gate(p_org,p_app,p_actor,p_site,'cash-action',p_data||jsonb_build_object('kind',p_kind)) or not bootik.bk_resource_activity_access(p_org,p_app,p_actor,p_site,a) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 if p_kind='register' then
  if exists(select 1 from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 else
  if p_kind='open' then rid:=(p_data->>'register_id')::uuid;else select s.register_id into rid from bootik.bk_cash_sessions s join bootik.bk_registers r on r.id=s.register_id where s.id=(p_data->>'session_id')::uuid and r.organization_id=p_org and r.app_id=p_app and r.location_id=p_site and r.activity_id=a;end if;
  if not bootik.bk_resource_allowed(p_org,p_app,p_actor,p_site,'register',rid) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':cash:'||req::text,0));
 select * into old from bootik.bk_cash_operation_receipts where id=req and organization_id=p_org and app_id=p_app;
 if found then
  if (old.activity_id,old.location_id,old.actor,old.kind,old.payload) is distinct from (a,p_site,p_actor,p_kind,p_data) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.result;
 end if;
 if p_kind='register' then
  if length(btrim(coalesce(p_data->>'code',''))) not between 1 and 40 or length(btrim(coalesce(p_data->>'name',''))) not between 1 and 120 then raise exception 'BOOTIK_CASH_INVALID';end if;
  insert into bootik.bk_registers(id,organization_id,app_id,activity_id,location_id,code,name,actor) values(req,p_org,p_app,a,p_site,upper(btrim(p_data->>'code')),btrim(p_data->>'name'),p_actor);
  answer:=jsonb_build_object('register_id',req);
 elsif p_kind='open' then
  rid:=(p_data->>'register_id')::uuid;amt:=(p_data->>'opening_float_fcfa')::bigint;
  if rid is null or amt is null or amt<0 or amt>9007199254740991 then raise exception 'BOOTIK_CASH_INVALID';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||':register-open:'||rid::text,0));
  select * into reg from bootik.bk_registers where id=rid and organization_id=p_org and app_id=p_app and activity_id=a and location_id=p_site;
  if not found then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if exists(select 1 from bootik.bk_cash_sessions where register_id=rid and closed_at is null) then raise exception 'BOOTIK_REGISTER_ALREADY_OPEN';end if;
  insert into bootik.bk_cash_sessions(id,register_id,opened_by,opening_float_fcfa) values(req,rid,p_actor,amt);
  answer:=jsonb_build_object('session_id',req);
 else
  sid:=(p_data->>'session_id')::uuid;
  select s.* into ses from bootik.bk_cash_sessions s join bootik.bk_registers r on r.id=s.register_id where s.id=sid and r.organization_id=p_org and r.app_id=p_app and r.activity_id=a and r.location_id=p_site for update of s;
  if not found or (p_kind='checkout' and ses.opened_by<>p_actor) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if ses.closed_at is not null then raise exception 'BOOTIK_CASH_SESSION_CLOSED';end if;
  if p_kind='checkout' then
   if jsonb_typeof(p_data->'lines') is distinct from 'array' or jsonb_array_length(p_data->'lines') not between 1 and 20 then raise exception 'BOOTIK_CASH_INVALID';end if;
   if (select count(distinct x.value->>'item_id') from jsonb_array_elements(p_data->'lines') x)<>jsonb_array_length(p_data->'lines') then raise exception 'BOOTIK_CASH_DUPLICATE_ITEM';end if;
   amt:=(p_data->>'tender_fcfa')::bigint;
   if amt is null or amt<0 or amt>9007199254740991 then raise exception 'BOOTIK_CASH_INVALID';end if;
   for line in select x.value from jsonb_array_elements(p_data->'lines') x order by (x.value->>'item_id')::uuid loop
    if not exists(select 1 from bootik.bk_catalog_items i where i.id=(line->>'item_id')::uuid and i.organization_id=p_org and i.app_id=p_app and i.activity_id=a) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
    gid:=bootik.bk_sell_item(p_org,p_app,p_actor,p_site,(line->>'item_id')::uuid,gen_random_uuid(),line->>'unit_code',(line->>'quantity')::numeric,(line->>'unit_price_fcfa')::bigint,sid);
    select total+g.quantity*g.base_factor*g.base_price into total from bootik.bk_item_sale_groups g where g.id=gid;
    groups:=groups||jsonb_build_array(gid);
   end loop;
   if total is null or total<>round(total) or total>amt then raise exception 'BOOTIK_CASH_TENDER_INSUFFICIENT';end if;
   insert into bootik.bk_cash_checkouts(id,session_id,actor,total_fcfa,tender_fcfa,sale_groups) values(req,sid,p_actor,total::bigint,amt,groups);
   answer:=jsonb_build_object('checkout_id',req,'total_fcfa',total::bigint,'change_fcfa',amt-total::bigint);
  else
   expected:=ses.opening_float_fcfa+(select coalesce(sum(total_fcfa),0) from bootik.bk_cash_checkouts where session_id=sid)+(select coalesce(sum(case when kind='in' then amount_fcfa else -amount_fcfa end),0) from bootik.bk_cash_movements where session_id=sid);
   if expected<0 or expected>9007199254740991 then raise exception 'BOOTIK_CASH_INVALID_BALANCE';end if;
   why:=btrim(coalesce(p_data->>'reason',''));
   if p_kind='movement' then
    category:=p_data->>'movement_kind';amt:=(p_data->>'amount_fcfa')::bigint;
    if category is null or category not in ('in','out','expense') or amt is null or amt<=0 or amt>9007199254740991 or length(why) not between 3 and 500 or (category<>'in' and amt>expected) or (category='in' and expected+amt>9007199254740991) then raise exception 'BOOTIK_CASH_INVALID';end if;
    if category in ('out','expense') then perform bootik.bk_approval_check(p_org,p_app,p_actor,p_site,a,'cash-movement',req,amt,jsonb_build_object('session_id',sid,'movement_kind',category,'reason',why),false);end if;
    insert into bootik.bk_cash_movements(id,session_id,actor,kind,amount_fcfa,reason) values(req,sid,p_actor,category,amt,why);
    answer:=jsonb_build_object('movement_id',req);
   else
    amt:=(p_data->>'counted_close_fcfa')::bigint;
    if amt is null or amt<0 or amt>9007199254740991 or length(why)>500 or (amt<>expected and length(why)<3) then raise exception 'BOOTIK_CASH_VARIANCE_REASON_REQUIRED';end if;
    if amt<>expected or exists(select 1 from bootik.bk_approval_requests where id=req) then perform bootik.bk_approval_check(p_org,p_app,p_actor,p_site,a,'cash-close',req,abs(amt-expected)::bigint,jsonb_build_object('session_id',sid,'counted_close_fcfa',amt,'expected_close_fcfa',expected::bigint,'reason',why),false);end if;
    update bootik.bk_cash_sessions set closed_at=clock_timestamp(),closed_by=p_actor,expected_close_fcfa=expected::bigint,counted_close_fcfa=amt,variance_reason=nullif(why,'') where id=sid;
    answer:=jsonb_build_object('session_id',sid,'expected_close_fcfa',expected::bigint,'counted_close_fcfa',amt,'variance_fcfa',amt-expected::bigint);
   end if;
  end if;
 end if;
 insert into bootik.bk_cash_operation_receipts(id,organization_id,app_id,activity_id,location_id,actor,kind,payload,result) values(req,p_org,p_app,a,p_site,p_actor,p_kind,p_data,answer);
 return answer;
end $$;
revoke all on function bootik.bk_cash_action(uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;

-- Register/workstation/stock scopes are explicit intersections; a territory-only scope is closed until B05.
create table bootik.bk_register_workstations(
 register_id uuid primary key references bootik.bk_registers(id),workstation_id uuid not null references bootik.bk_workstations(id)
);
alter table bootik.bk_register_workstations enable row level security;alter table bootik.bk_register_workstations force row level security;revoke all on bootik.bk_register_workstations from public,anon,authenticated;
create function bootik.bk_resource_allowed(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_kind text,p_id uuid)
returns boolean language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare rr bootik.bk_member_resource_rules%rowtype;matched boolean:=false;
begin
 for rr in select * from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site loop
  if rr.resource_kind=p_kind then
   matched:=true;if p_id is null or not(rr.resources ? p_id::text) then return false;end if;
  elsif rr.resource_kind='workstation' and p_kind='register' then
   matched:=true;if p_id is null or not exists(select 1 from bootik.bk_register_workstations rw where rw.register_id=p_id and rr.resources ? rw.workstation_id::text) then return false;end if;
  end if;
 end loop;
 return matched or not exists(select 1 from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site);
end $$;
create function bootik.bk_resource_activity_access(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_activity uuid)
returns boolean language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare rr bootik.bk_member_resource_rules%rowtype;ok boolean;
begin
 for rr in select * from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site loop
  if rr.resource_kind='storage' then select exists(select 1 from bootik.bk_storage_locations l where l.organization_id=p_org and l.app_id=p_app and l.location_id=p_site and l.activity_id=p_activity and rr.resources ? l.id::text) into ok;
  elsif rr.resource_kind='register' then select exists(select 1 from bootik.bk_registers r where r.organization_id=p_org and r.app_id=p_app and r.location_id=p_site and r.activity_id=p_activity and rr.resources ? r.id::text) into ok;
  elsif rr.resource_kind='workstation' then select exists(select 1 from bootik.bk_workstations w where w.organization_id=p_org and w.app_id=p_app and w.location_id=p_site and w.activity_id=p_activity and rr.resources ? w.id::text) into ok;
  elsif rr.resource_kind='territory' then select exists(select 1 from bootik.bk_territories t where t.organization_id=p_org and t.app_id=p_app and t.location_id=p_site and t.activity_id=p_activity and rr.resources ? t.id::text) into ok;
  else return false;end if;
  if not ok then return false;end if;
 end loop;
 return true;
end $$;
create function bootik.bk_resource_catalog(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_activity uuid,p_storage uuid)
returns boolean language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare rr bootik.bk_member_resource_rules%rowtype;
begin
 if not bootik.bk_resource_activity_access(p_org,p_app,p_actor,p_site,p_activity) then return false;end if;
 for rr in select * from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site loop
  if rr.resource_kind='territory' then return false;end if;
  if rr.resource_kind='storage' and (p_storage is null or not(rr.resources ? p_storage::text)) then return false;end if;
 end loop;
 return true;
end $$;
create function bootik.bk_resource_gate(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_action text,p_data jsonb)
returns boolean language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare kinds text[];
begin
 select array_agg(resource_kind) into kinds from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site;
 if kinds is null then return true;end if;
 if p_action in ('entitlement','security-state','support','support-cancel','activities','approval-own-state','approval-execute','notification-list','notification-read','notification-preference') or (p_action='admin-action' and p_data->>'kind'='session-revoke') then return true;end if;
 if 'territory'=any(kinds) then return false;end if;
 if p_action='catalog' then return true;end if;
 -- Stock mutations and checkout preserve the intersection of the delegated resource sets.
 if p_action in ('stock-health','sync-stock','count-batch') then return 'storage'=any(kinds) and cardinality(kinds)=1;end if;
 if p_action='cash-state' or (p_action='cash-action' and p_data->>'kind' in ('open','checkout','movement','close')) then
  return 'register'=any(kinds) or 'workstation'=any(kinds);
 end if;
 return false;
end $$;
create function bootik.bk_resource_admin(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_req uuid,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare k text;target_user uuid;rid uuid;a uuid;w uuid;kind text;ids jsonb;why text;old bootik.bk_admin_receipts%rowtype;previous jsonb;answer jsonb;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not exists(select 1 from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=p_actor and m.role='promoteur' and ms.location_id=p_site and not ms.activity_restricted) or exists(select 1 from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 k:=p_data->>'kind';why:=btrim(coalesce(p_data->>'reason',''));
 if p_req is null or k not in ('workstation','territory','link-register','assign') or length(why) not between 3 and 500 then raise exception 'BOOTIK_RESOURCE_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':resource:'||p_req::text,0));
 select * into old from bootik.bk_admin_receipts where id=p_req and organization_id=p_org and app_id=p_app;
 if found then
  if (old.actor,old.site_id,old.payload) is distinct from (p_actor,p_site,p_data) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.result;
 end if;
 if k in ('workstation','territory') then
  a:=(p_data->>'activity_id')::uuid;
  if not exists(select 1 from bootik.bk_activity_locations where organization_id=p_org and app_id=p_app and location_id=p_site and activity_id=a) or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if coalesce(p_data->>'code','') !~ '^[A-Z0-9][A-Z0-9_-]{1,19}$' or length(btrim(coalesce(p_data->>'label',''))) not between 2 and 120 then raise exception 'BOOTIK_RESOURCE_INVALID';end if;
  if k='workstation' then insert into bootik.bk_workstations values(p_req,p_org,p_app,a,p_site,p_data->>'code',btrim(p_data->>'label'));else insert into bootik.bk_territories values(p_req,p_org,p_app,a,p_site,p_data->>'code',btrim(p_data->>'label'));end if;
  answer:=jsonb_build_object('resource_id',p_req);
 elsif k='link-register' then
  rid:=(p_data->>'register_id')::uuid;w:=(p_data->>'workstation_id')::uuid;
  if not exists(select 1 from bootik.bk_registers r join bootik.bk_workstations ws on (ws.organization_id,ws.app_id,ws.activity_id,ws.location_id)=(r.organization_id,r.app_id,r.activity_id,r.location_id) where r.id=rid and ws.id=w and r.organization_id=p_org and r.app_id=p_app and r.location_id=p_site) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if exists(select 1 from bootik.bk_register_workstations where register_id=rid) then raise exception 'BOOTIK_REGISTER_ALREADY_LINKED';end if;
  insert into bootik.bk_register_workstations values(rid,w);
  answer:=jsonb_build_object('register_id',rid,'workstation_id',w);
 else
  target_user:=(p_data->>'member_id')::uuid;kind:=p_data->>'resource_kind';ids:=p_data->'resources';
  if kind not in ('register','workstation','storage','territory') or jsonb_typeof(ids) is distinct from 'array' or jsonb_array_length(ids)>50 then raise exception 'BOOTIK_RESOURCE_INVALID';end if;
  if not exists(select 1 from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=target_user and m.active and m.role<>'promoteur' and ms.location_id=p_site) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  for rid in select value::uuid from jsonb_array_elements_text(ids) loop
   a:=null;
   if kind='register' then select activity_id into a from bootik.bk_registers where id=rid and organization_id=p_org and app_id=p_app and location_id=p_site;
   elsif kind='storage' then select activity_id into a from bootik.bk_storage_locations where id=rid and organization_id=p_org and app_id=p_app and location_id=p_site;
   elsif kind='workstation' then select activity_id into a from bootik.bk_workstations where id=rid and organization_id=p_org and app_id=p_app and location_id=p_site;
   else select activity_id into a from bootik.bk_territories where id=rid and organization_id=p_org and app_id=p_app and location_id=p_site;end if;
   if a is null or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) or not bootik.bk_can_access_activity(p_org,p_app,target_user,p_site,a) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  end loop;
  select jsonb_build_object('kind',resource_kind,'resources',resources) into previous from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=target_user and location_id=p_site and resource_kind=kind;
  insert into bootik.bk_member_resource_rules(organization_id,app_id,user_id,location_id,resource_kind,resources) values(p_org,p_app,target_user,p_site,kind,ids) on conflict(organization_id,app_id,user_id,location_id,resource_kind) do update set resources=excluded.resources;
  update bootik.bk_sessions set revoked_at=coalesce(revoked_at,clock_timestamp()) where organization_id=p_org and app_id=p_app and user_id=target_user;
  answer:=jsonb_build_object('member_id',target_user,'kind',kind,'resources',ids);
 end if;
 insert into bootik.bk_admin_receipts(id,organization_id,app_id,actor,site_id,payload,result) values(p_req,p_org,p_app,p_actor,p_site,p_data,answer);
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,'resource-'||k,coalesce(target_user,rid,p_req),jsonb_build_object('before',previous,'after',answer,'reason',why));
 return answer;
end $$;
revoke all on function bootik.bk_resource_allowed(uuid,uuid,uuid,uuid,text,uuid),bootik.bk_resource_activity_access(uuid,uuid,uuid,uuid,uuid),bootik.bk_resource_catalog(uuid,uuid,uuid,uuid,uuid,uuid),bootik.bk_resource_gate(uuid,uuid,uuid,uuid,text,jsonb),bootik.bk_resource_admin(uuid,uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;

-- Monetary delegation: configurable per site/activity, immutable request payload and distinct approver.
create table bootik.bk_approval_policies(
 organization_id uuid not null,app_id uuid not null,location_id uuid not null,activity_id uuid not null,kind text not null check(kind in ('purchase-pay','cash-movement','cash-close')),
 threshold_fcfa bigint not null check(threshold_fcfa between 0 and 9007199254740991),primary key(organization_id,app_id,location_id,activity_id,kind),
 foreign key(activity_id,location_id,organization_id,app_id) references bootik.bk_activity_locations(activity_id,location_id,organization_id,app_id)
);
create table bootik.bk_approval_requests(
 id uuid primary key,organization_id uuid not null,app_id uuid not null,location_id uuid not null,activity_id uuid not null,actor uuid not null,
 kind text not null check(kind in ('purchase-pay','cash-movement','cash-close')),amount_fcfa bigint not null check(amount_fcfa>0),payload jsonb not null,
 state text not null default 'pending' check(state in ('pending','approved','refused')),approver uuid,decided_at timestamptz,reason text,created_at timestamptz not null default clock_timestamp(),
 check((state='pending' and approver is null and decided_at is null) or (state<>'pending' and approver is not null and approver<>actor and decided_at is not null))
);
do $$ declare n text;begin foreach n in array array['bk_approval_policies','bk_approval_requests'] loop execute format('alter table bootik.%I enable row level security',n);execute format('alter table bootik.%I force row level security',n);execute format('revoke all on bootik.%I from public,anon,authenticated',n);end loop;end $$;
create function bootik.bk_approval_check(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_activity uuid,p_kind text,p_id uuid,p_amount bigint,p_payload jsonb,p_queue boolean)
returns text language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare lim bigint;old bootik.bk_approval_requests%rowtype;v_role text;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,p_activity) or p_id is null or p_amount is null or p_amount<=0 or p_amount>9007199254740991 or p_kind not in ('purchase-pay','cash-movement','cash-close') then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_app::text||':'||p_site::text||':'||p_activity::text||':'||p_kind,91));
 select * into old from bootik.bk_approval_requests where id=p_id;
 if found then
  if (old.organization_id,old.app_id,old.location_id,old.activity_id,old.actor,old.kind,old.amount_fcfa,old.payload) is distinct from (p_org,p_app,p_site,p_activity,p_actor,p_kind,p_amount,p_payload) then raise exception 'BOOTIK_APPROVAL_CONFLICT';end if;
  if old.state='approved' and exists(select 1 from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=old.approver and m.active and m.role='promoteur' and ms.location_id=p_site and not ms.activity_restricted) then return null;end if;
  if p_queue then return case when old.state='refused' then 'refused' else 'pending' end;end if;
  raise exception 'BOOTIK_APPROVAL_REQUIRED' using errcode='42501';
 end if;
 select role into v_role from bootik.bk_members where organization_id=p_org and app_id=p_app and user_id=p_actor and active;
 select threshold_fcfa into lim from bootik.bk_approval_policies where organization_id=p_org and app_id=p_app and location_id=p_site and activity_id=p_activity and kind=p_kind;
 if v_role='promoteur' or lim is null or p_amount<=lim then return null;end if;
 if not p_queue then raise exception 'BOOTIK_APPROVAL_REQUIRED' using errcode='42501';end if;
 insert into bootik.bk_approval_requests(id,organization_id,app_id,location_id,activity_id,actor,kind,amount_fcfa,payload) values(p_id,p_org,p_app,p_site,p_activity,p_actor,p_kind,p_amount,p_payload);
 return 'pending';
end $$;
create function bootik.bk_approval_preflight(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_kind text,p_data jsonb)
returns text language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;rid uuid;sid uuid;req uuid;amt bigint;u text;canonical jsonb;remaining bigint;counted bigint;expected numeric;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if p_kind='purchase-pay' then
  select activity_id,received_amount_fcfa-paid_amount_fcfa into a,remaining from bootik.bk_purchase_orders where id=(p_data->>'order_id')::uuid and organization_id=p_org and app_id=p_app and location_id=p_site;
  if not found then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  req:=(p_data->>'payment_id')::uuid;amt:=(p_data->>'amount_fcfa')::bigint;
  if exists(select 1 from bootik.bk_supplier_payments where id=req and order_id=(p_data->>'order_id')::uuid) then return null;end if;
  if amt>remaining or coalesce(p_data->>'method','') not in ('cash','bank','mobile_money') or length(btrim(coalesce(p_data->>'reference',''))) not between 3 and 120 then raise exception 'BOOTIK_PURCHASE_INVALID';end if;
  canonical:=jsonb_build_object('order_id',(p_data->>'order_id')::uuid,'method',p_data->>'method','reference',btrim(p_data->>'reference'));
 elsif p_kind in ('cash-movement','cash-close') then
  a:=(p_data->>'activity_id')::uuid;sid:=(p_data->>'session_id')::uuid;req:=(p_data->>'request_id')::uuid;amt:=(p_data->>'amount_fcfa')::bigint;
  select r.id into rid from bootik.bk_cash_sessions s join bootik.bk_registers r on r.id=s.register_id where s.id=sid and r.organization_id=p_org and r.app_id=p_app and r.location_id=p_site and r.activity_id=a;
  if not found or not bootik.bk_resource_allowed(p_org,p_app,p_actor,p_site,'register',rid) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if exists(select 1 from bootik.bk_cash_operation_receipts where id=req and organization_id=p_org and app_id=p_app) then return null;end if;
  if p_kind='cash-close' then
   counted:=(p_data->>'counted_close_fcfa')::bigint;
   select s.opening_float_fcfa+(select coalesce(sum(total_fcfa),0) from bootik.bk_cash_checkouts where session_id=sid)+(select coalesce(sum(case when kind='in' then amount_fcfa else -amount_fcfa end),0) from bootik.bk_cash_movements where session_id=sid) into expected from bootik.bk_cash_sessions s where s.id=sid and s.closed_at is null;
   if not found or counted is null or counted<0 or counted>9007199254740991 or expected<0 or expected>9007199254740991 or (counted<>expected and length(btrim(coalesce(p_data->>'reason',''))) not between 3 and 500) then raise exception 'BOOTIK_CASH_INVALID';end if;
   amt:=abs(counted-expected)::bigint;
   if amt=0 and not exists(select 1 from bootik.bk_approval_requests where id=req) then return null;end if;
   canonical:=jsonb_build_object('session_id',sid,'counted_close_fcfa',counted,'expected_close_fcfa',expected::bigint,'reason',btrim(coalesce(p_data->>'reason','')));
  else
   if coalesce(p_data->>'movement_kind','') not in ('out','expense') or length(btrim(coalesce(p_data->>'reason',''))) not between 3 and 500 then raise exception 'BOOTIK_CASH_INVALID';end if;
   canonical:=jsonb_build_object('session_id',sid,'movement_kind',p_data->>'movement_kind','reason',btrim(p_data->>'reason'));
  end if;
 else raise exception 'BOOTIK_APPROVAL_INVALID';end if;
 select universe_code into u from bootik.bk_activities where id=a and organization_id=p_org and app_id=p_app and status='active';
 if not found or not bootik.bk_has_entitlement(p_org,p_app,u) then raise exception 'BOOTIK_ENTITLEMENT_REQUIRED';end if;
 return bootik.bk_approval_check(p_org,p_app,p_actor,p_site,a,p_kind,req,amt,canonical,true);
end $$;
create function bootik.bk_approval_admin(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_request uuid,p_data jsonb)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,bootik as $$
declare a uuid;k text;t bigint;why text;rid uuid;d text;old bootik.bk_admin_receipts%rowtype;req bootik.bk_approval_requests%rowtype;prev jsonb;answer jsonb;
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site,true);
 if not exists(select 1 from bootik.bk_members m join bootik.bk_member_sites ms using(organization_id,app_id,user_id) where m.organization_id=p_org and m.app_id=p_app and m.user_id=p_actor and m.active and m.role='promoteur' and ms.location_id=p_site and not ms.activity_restricted) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 why:=btrim(coalesce(p_data->>'reason',''));if p_request is null or length(why) not between 3 and 500 then raise exception 'BOOTIK_APPROVAL_INVALID';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':approval-admin:'||p_request::text,0));
 select * into old from bootik.bk_admin_receipts where id=p_request and organization_id=p_org and app_id=p_app;
 if found then if (old.actor,old.site_id,old.payload) is distinct from (p_actor,p_site,p_data) then raise exception 'BOOTIK_IDEMPOTENCY_CONFLICT';end if;return old.result;end if;
 if p_data->>'kind'='policy' then
  a:=(p_data->>'activity_id')::uuid;k:=p_data->>'operation_kind';t:=(p_data->>'threshold_fcfa')::bigint;
  if k is null or k not in ('purchase-pay','cash-movement','cash-close') or t is null or t<0 or t>9007199254740991 or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) then raise exception 'BOOTIK_APPROVAL_INVALID';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_app::text||':'||p_site::text||':'||a::text||':'||k,91));
  select to_jsonb(x) into prev from bootik.bk_approval_policies x where organization_id=p_org and app_id=p_app and location_id=p_site and activity_id=a and kind=k;
  insert into bootik.bk_approval_policies values(p_org,p_app,p_site,a,k,t) on conflict(organization_id,app_id,location_id,activity_id,kind) do update set threshold_fcfa=excluded.threshold_fcfa;
  answer:=jsonb_build_object('activity_id',a,'operation_kind',k,'threshold_fcfa',t);
 elsif p_data->>'kind'='decide' then
  rid:=(p_data->>'approval_id')::uuid;d:=p_data->>'decision';
  if d is null or d not in ('approved','refused') then raise exception 'BOOTIK_APPROVAL_INVALID';end if;
  select * into req from bootik.bk_approval_requests where id=rid and organization_id=p_org and app_id=p_app and location_id=p_site for update;
  if not found or req.actor=p_actor or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,req.activity_id) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
  if req.state<>'pending' then raise exception 'BOOTIK_APPROVAL_ALREADY_DECIDED';end if;
  prev:=jsonb_build_object('state',req.state);
  update bootik.bk_approval_requests set state=d,approver=p_actor,decided_at=clock_timestamp(),reason=why where id=rid;
  answer:=jsonb_build_object('approval_id',rid,'state',d);
 else raise exception 'BOOTIK_APPROVAL_INVALID';end if;
 insert into bootik.bk_admin_receipts(id,organization_id,app_id,actor,site_id,payload,result) values(p_request,p_org,p_app,p_actor,p_site,p_data,answer);
 insert into bootik.bk_security_audit(organization_id,app_id,actor,site_id,action,target,details) values(p_org,p_app,p_actor,p_site,'approval-'||(p_data->>'kind'),coalesce(rid,p_request),jsonb_build_object('before',prev,'after',answer,'reason',why));
 return answer;
end $$;
revoke all on function bootik.bk_approval_check(uuid,uuid,uuid,uuid,uuid,text,uuid,bigint,jsonb,boolean),bootik.bk_approval_preflight(uuid,uuid,uuid,uuid,text,jsonb),bootik.bk_approval_admin(uuid,uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;

-- No secrets, notes, or raw audit payload in notification responses.
create function bootik.bk_notification_inbox(p_org uuid,p_app uuid,p_actor uuid,p_site uuid)
returns table(id uuid,event_code text,created_at timestamptz,read_at timestamptz) language sql stable security invoker set search_path=pg_catalog,bootik as $$
 select e.id,e.action,e.created_at,r.read_at
 from bootik.bk_security_audit e
 join bootik.bk_members m on m.organization_id=p_org and m.app_id=p_app and m.user_id=p_actor and m.active
 join bootik.bk_member_sites ms on ms.organization_id=p_org and ms.app_id=p_app and ms.user_id=p_actor and ms.location_id=p_site
 left join bootik.bk_notification_reads r on r.organization_id=p_org and r.app_id=p_app and r.user_id=p_actor and r.event_id=e.id
 left join bootik.bk_notification_preferences pref on pref.organization_id=p_org and pref.app_id=p_app and pref.user_id=p_actor
 left join bootik.bk_approval_requests q on q.id=e.target and q.organization_id=p_org and q.app_id=p_app and q.location_id=p_site
 where e.organization_id=p_org and e.app_id=p_app and (e.site_id=p_site or e.site_id is null and e.actor=p_actor)
 and (
 (e.action='new-site-device' and (e.actor=p_actor or m.role='promoteur' and not ms.activity_restricted))
 or (e.action in ('password-change','recovery-complete','family-provision-promoter-recovery','member-role','member-scope','member-period','member-disable','resource-assign') and (e.target=p_actor or m.role='promoteur' and not ms.activity_restricted))
 or (e.action='approval-decide' and coalesce(pref.approval_enabled,true) and (q.actor=p_actor or m.role='promoteur' and not ms.activity_restricted))
 )
 order by e.created_at desc,e.id;
$$;
create function bootik.bk_notification_read(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_event uuid)
returns boolean language plpgsql security invoker set search_path=pg_catalog,bootik as $$
begin
 perform bootik.bk_assert_scope(p_org,p_app,p_actor,p_site);
 if not exists(select 1 from bootik.bk_notification_inbox(p_org,p_app,p_actor,p_site) i where i.id=p_event) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
 insert into bootik.bk_notification_reads(organization_id,app_id,user_id,event_id) values(p_org,p_app,p_actor,p_event) on conflict do nothing;return true;
end $$;
revoke all on function bootik.bk_notification_inbox(uuid,uuid,uuid,uuid),bootik.bk_notification_read(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;

-- A scoped sale may only run inside its own open, authorized register session.
create function bootik.bk_assert_sale_resource(p_org uuid,p_app uuid,p_actor uuid,p_site uuid,p_session uuid)
returns void language plpgsql stable security invoker set search_path=pg_catalog,bootik as $$
declare rid uuid;a uuid;scoped boolean;
begin
 select exists(select 1 from bootik.bk_member_resource_rules where organization_id=p_org and app_id=p_app and user_id=p_actor and location_id=p_site) into scoped;
 if p_session is null then
  if scoped then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;return;
 end if;
 select r.id,r.activity_id into rid,a from bootik.bk_cash_sessions s join bootik.bk_registers r on r.id=s.register_id where s.id=p_session and s.opened_by=p_actor and s.closed_at is null and r.organization_id=p_org and r.app_id=p_app and r.location_id=p_site;
 if not found or not bootik.bk_can_access_activity(p_org,p_app,p_actor,p_site,a) or not bootik.bk_resource_activity_access(p_org,p_app,p_actor,p_site,a) or not bootik.bk_resource_allowed(p_org,p_app,p_actor,p_site,'register',rid) or not bootik.bk_resource_gate(p_org,p_app,p_actor,p_site,'cash-action','{"kind":"checkout"}'::jsonb) then raise exception 'BOOTIK_SCOPE_DENIED' using errcode='42501';end if;
end $$;
revoke all on function bootik.bk_assert_sale_resource(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;

commit;
