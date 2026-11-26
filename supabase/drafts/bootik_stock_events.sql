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
commit;
