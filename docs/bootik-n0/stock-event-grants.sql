-- Test-only grants for the existing isolated BOOTIK runtime role.
create policy bk_runtime_access on bootik.bk_stock_event_receipts to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_stock_event_receipts to bootik_runtime;
grant execute on function bootik.bk_record_stock_event(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,text,text) to bootik_runtime;
