-- Test-only grants for the existing isolated BOOTIK runtime role.
create policy bk_runtime_access on bootik.bk_stock_event_receipts to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_stock_event_receipts to bootik_runtime;
grant execute on function bootik.bk_record_stock_event(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,text,text) to bootik_runtime;

-- Isolated runtime for count batches and transfer receipts; no client grants.
create policy bk_runtime_access on bootik.bk_count_batches to bootik_runtime using(true) with check(true);
create policy bk_runtime_access on bootik.bk_stock_transfers to bootik_runtime using(true) with check(true);
create policy bk_runtime_access on bootik.bk_transfer_receipts to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_count_batches,bootik.bk_stock_transfers,bootik.bk_transfer_receipts to bootik_runtime;
grant update(received) on bootik.bk_stock_transfers to bootik_runtime;
grant execute on function bootik.bk_count_batch(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb),bootik.bk_ship_transfer(uuid,uuid,uuid,uuid,uuid,uuid,uuid,numeric,text,text),bootik.bk_receive_transfer(uuid,uuid,uuid,uuid,uuid,uuid,numeric,text) to bootik_runtime;

create policy bk_runtime_access on bootik.bk_stock_imports to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_stock_imports to bootik_runtime;
grant execute on function bootik.bk_apply_stock_import(uuid,uuid,uuid,uuid,uuid,uuid,jsonb) to bootik_runtime;
grant select on bootik.bk_inventory_movements to bootik_runtime;

create policy bk_runtime_access on bootik.bk_item_sale_groups to bootik_runtime using(true) with check(true);
create policy bk_runtime_access on bootik.bk_stock_setup_receipts to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_item_sale_groups,bootik.bk_stock_setup_receipts to bootik_runtime;
grant execute on function bootik.bk_sell_item(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,bigint),bootik.bk_setup_stock(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb) to bootik_runtime;
