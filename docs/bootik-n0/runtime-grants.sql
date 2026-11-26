-- Test-only dedicated runtime role, NOT a production migration.
create role bootik_runtime login password 'bootik-test-only';
grant usage on schema bootik to bootik_runtime;
do $$ declare n text;begin foreach n in array array['bk_credentials','bk_sessions','bk_recovery_requests','bk_members','bk_member_sites','bk_locations','bk_activities','bk_trials','bk_paid_periods','bk_sale_prices','bk_sales','bk_catalog_items','bk_inventory_balances','bk_product_lots','bk_inventory_movements','bk_support_requests'] loop
 execute format('create policy bk_runtime_access on bootik.%I to bootik_runtime using (true) with check (true)',n);
 end loop;end $$;
grant select on bootik.bk_credentials,bootik.bk_sessions,bootik.bk_members,bootik.bk_member_sites,bootik.bk_locations,bootik.bk_activities,bootik.bk_trials,bootik.bk_paid_periods,bootik.bk_sale_prices,bootik.bk_sales,bootik.bk_catalog_items,bootik.bk_inventory_balances,bootik.bk_product_lots,bootik.bk_support_requests to bootik_runtime;
grant insert on bootik.bk_sessions,bootik.bk_recovery_requests,bootik.bk_trials,bootik.bk_sales,bootik.bk_inventory_movements,bootik.bk_support_requests to bootik_runtime;
grant update(revoked_at,token_hash,expires_at,refresh_hash,refresh_expires_at) on bootik.bk_sessions to bootik_runtime;
grant update(quantity_on_hand,updated_at) on bootik.bk_inventory_balances to bootik_runtime;
grant update(state,revoked_at) on bootik.bk_support_requests to bootik_runtime;
grant execute on function bootik.bk_assert_scope(uuid,uuid,uuid,uuid,boolean),bootik.bk_quote(text,text,integer),bootik.bk_start_trial(uuid,uuid,uuid,uuid,text,text),bootik.bk_has_entitlement(uuid,uuid,text),bootik.bk_record_sale(uuid,uuid,uuid,uuid,uuid,numeric,bigint,text),bootik.bk_request_support(uuid,uuid,uuid,uuid,text,boolean),bootik.bk_cancel_support(uuid,uuid,uuid,uuid,uuid) to bootik_runtime;

-- Dedicated runtime can inspect scopes, never change assignments.
create policy bk_runtime_access on bootik.bk_member_activity_scopes for select to bootik_runtime using (true);
grant select on bootik.bk_member_activity_scopes to bootik_runtime;
grant execute on function bootik.bk_can_access_activity(uuid,uuid,uuid,uuid,uuid) to bootik_runtime;
