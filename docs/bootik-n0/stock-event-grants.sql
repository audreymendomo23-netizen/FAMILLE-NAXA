-- Test-only grants for the existing isolated BOOTIK runtime role.
create policy bk_runtime_access on bootik.bk_stock_event_receipts to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_stock_event_receipts to bootik_runtime;
grant execute on function bootik.bk_record_stock_event(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,text,text,bigint) to bootik_runtime;

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
grant execute on function bootik.bk_sell_item(uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,bigint,uuid),bootik.bk_setup_stock(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb) to bootik_runtime;

-- Isolated runtime only: supplier purchases.
do $$ declare t text;begin foreach t in array array['bk_purchase_orders','bk_purchase_receipts','bk_supplier_payments'] loop execute format('create policy bk_runtime_access on bootik.%I to bootik_runtime using(true) with check(true)',t);end loop;end $$;
grant select,insert on bootik.bk_purchase_orders,bootik.bk_purchase_receipts,bootik.bk_supplier_payments to bootik_runtime;
grant update(received_quantity,received_amount_fcfa,paid_amount_fcfa) on bootik.bk_purchase_orders to bootik_runtime;
grant execute on function bootik.bk_purchase_create(uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,numeric,bigint),bootik.bk_purchase_receive(uuid,uuid,uuid,uuid,uuid,uuid,numeric,bigint),bootik.bk_purchase_pay(uuid,uuid,uuid,uuid,uuid,uuid,bigint,text,text) to bootik_runtime;

-- Cash test runtime: all public client access remains revoked.
do $$ declare t text;begin foreach t in array array['bk_registers','bk_cash_sessions','bk_cash_checkouts','bk_cash_movements','bk_cash_operation_receipts'] loop execute format('create policy bk_runtime_access on bootik.%I to bootik_runtime using(true) with check(true)',t);end loop;end $$;
grant select,insert on bootik.bk_registers,bootik.bk_cash_sessions,bootik.bk_cash_checkouts,bootik.bk_cash_movements,bootik.bk_cash_operation_receipts to bootik_runtime;
grant update(closed_at,closed_by,expected_close_fcfa,counted_close_fcfa,variance_reason) on bootik.bk_cash_sessions to bootik_runtime;
grant execute on function bootik.bk_cash_action(uuid,uuid,uuid,uuid,text,jsonb) to bootik_runtime;

create policy bk_runtime_access on bootik.bk_register_workstations for select to bootik_runtime using(true);
create policy bk_security_access on bootik.bk_register_workstations to bootik_security_runtime using(true) with check(true);
create policy bk_security_access on bootik.bk_registers for select to bootik_security_runtime using(true);
grant select on bootik.bk_register_workstations to bootik_runtime;
grant select,insert on bootik.bk_register_workstations to bootik_security_runtime;
grant select on bootik.bk_registers to bootik_security_runtime;
grant execute on function bootik.bk_resource_allowed(uuid,uuid,uuid,uuid,text,uuid),bootik.bk_resource_activity_access(uuid,uuid,uuid,uuid,uuid),bootik.bk_resource_catalog(uuid,uuid,uuid,uuid,uuid,uuid),bootik.bk_resource_gate(uuid,uuid,uuid,uuid,text,jsonb) to bootik_runtime;
grant execute on function bootik.bk_resource_admin(uuid,uuid,uuid,uuid,uuid,jsonb) to bootik_security_runtime;

create policy bk_runtime_approval_policy on bootik.bk_approval_policies for select to bootik_runtime using(true);
create policy bk_runtime_approval_request on bootik.bk_approval_requests to bootik_runtime using(true) with check(state='pending' and approver is null and decided_at is null);
grant select on bootik.bk_approval_policies,bootik.bk_approval_requests to bootik_runtime;
grant insert(id,organization_id,app_id,location_id,activity_id,actor,kind,amount_fcfa,payload) on bootik.bk_approval_requests to bootik_runtime;
grant execute on function bootik.bk_approval_check(uuid,uuid,uuid,uuid,uuid,text,uuid,bigint,jsonb,boolean),bootik.bk_approval_preflight(uuid,uuid,uuid,uuid,text,jsonb) to bootik_runtime;
create policy bk_security_approval_policy on bootik.bk_approval_policies to bootik_security_runtime using(true) with check(true);
create policy bk_security_approval_request on bootik.bk_approval_requests to bootik_security_runtime using(true) with check(true);
grant select,insert on bootik.bk_approval_policies to bootik_security_runtime;grant update(threshold_fcfa) on bootik.bk_approval_policies to bootik_security_runtime;
grant select on bootik.bk_approval_requests to bootik_security_runtime;grant update(state,approver,decided_at,reason) on bootik.bk_approval_requests to bootik_security_runtime;
grant execute on function bootik.bk_approval_admin(uuid,uuid,uuid,uuid,uuid,jsonb) to bootik_security_runtime;

grant execute on function bootik.bk_notification_inbox(uuid,uuid,uuid,uuid),bootik.bk_notification_read(uuid,uuid,uuid,uuid,uuid) to bootik_runtime;

grant execute on function bootik.bk_assert_sale_resource(uuid,uuid,uuid,uuid,uuid) to bootik_runtime;
