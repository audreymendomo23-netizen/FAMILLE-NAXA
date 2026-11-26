-- Isolated stock-event candidate, inspired by NAXA transactional receipts and inventory adjustments.
begin;
create table bootik.bk_stock_event_receipts (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,app_id uuid not null,actor uuid not null,location_id uuid not null,
 event_id uuid not null,balance_id uuid not null references bootik.bk_inventory_balances(id),
 kind text not null check(kind in ('receipt','loss','count')),quantity numeric(20,6) not null check(quantity>=0),
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
 if p_event is null or p_kind is null or p_kind not in ('receipt','loss','count') or p_qty is null or p_qty<0 or p_qty>1000000000 or p_qty<>round(p_qty,6) or (p_kind<>'count' and p_qty=0) or p_version is null or length(p_version)>100 or p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'BOOTIK_STOCK_EVENT_INVALID';end if;
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
 if p_kind='receipt' and b.lot_id is not null and not exists(select 1 from bootik.bk_product_lots l where l.id=b.lot_id and l.quality_state='available' and (l.expires_at is null or l.expires_at>=current_date)) then raise exception 'BOOTIK_LOT_UNAVAILABLE';end if;
 v_next:=case p_kind when 'receipt' then b.quantity_on_hand+p_qty when 'loss' then b.quantity_on_hand-p_qty else p_qty end;
 if v_next<b.quantity_reserved+b.quantity_damaged then raise exception 'BOOTIK_STOCK_INSUFFICIENT';end if;
 v_delta:=v_next-b.quantity_on_hand;
 insert into bootik.bk_stock_event_receipts(organization_id,app_id,actor,location_id,event_id,balance_id,kind,quantity,expected_version,reason,before_qty,after_qty)
 values(p_org,p_app,p_actor,p_site,p_event,p_balance,p_kind,p_qty,p_version,btrim(p_reason),b.quantity_on_hand,v_next) returning id into v_id;
 if v_delta<>0 then
  update bootik.bk_inventory_balances set quantity_on_hand=v_next,updated_at=clock_timestamp() where id=b.id;
  insert into bootik.bk_inventory_movements(app_id,organization_id,activity_id,location_id,item_id,lot_id,movement_code,quantity_delta,unit_code,source_reference,idempotency_key,actor_user_id,reason)
  values(p_app,p_org,b.activity_id,p_site,b.item_id,b.lot_id,case p_kind when 'receipt' then 'purchase_receipt' when 'loss' then 'loss' else 'inventory_adjustment' end,v_delta,v_unit,v_id::text,'stock:'||p_event::text,p_actor,btrim(p_reason));
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
 if (select count(distinct x->>'balance_id') from jsonb_array_elements(p_lines) x)<>n or (select count(distinct x->>'event_id') from jsonb_array_elements(p_lines) x)<>n then raise exception 'BOOTIK_BATCH_DUPLICATE';end if;
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

commit;
