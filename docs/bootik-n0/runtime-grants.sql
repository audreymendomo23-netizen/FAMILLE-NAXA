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

-- Master data: isolated runtime only, append-only creation receipts.
do $$ declare n text;begin foreach n in array array['bk_activity_locations','bk_item_units','bk_customers','bk_suppliers','bk_master_creation_receipts'] loop execute format('create policy bk_runtime_access on bootik.%I to bootik_runtime using (true) with check (true)',n);end loop;end $$;
grant select on bootik.bk_activity_locations,bootik.bk_customers,bootik.bk_suppliers,bootik.bk_master_creation_receipts to bootik_runtime;
grant insert on bootik.bk_catalog_items,bootik.bk_item_units,bootik.bk_inventory_balances,bootik.bk_sale_prices,bootik.bk_customers,bootik.bk_suppliers,bootik.bk_master_creation_receipts to bootik_runtime;
grant execute on function bootik.bk_create_master(uuid,uuid,uuid,uuid,uuid,uuid,text,jsonb) to bootik_runtime;

-- Catalog metadata grants for isolated BOOTIK runtime; no direct client rights.
create policy bk_runtime_access on bootik.bk_storage_locations to bootik_runtime using (true) with check (true);
create policy bk_runtime_access on bootik.bk_reorder_policies to bootik_runtime using (true) with check (true);
grant select,insert on bootik.bk_storage_locations,bootik.bk_reorder_policies to bootik_runtime;
grant insert on bootik.bk_product_lots to bootik_runtime;

grant select on bootik.bk_item_units to bootik_runtime;

grant update(unit_cost_fcfa) on bootik.bk_inventory_balances to bootik_runtime;

-- B01: distinct trusted admin connection. The ordinary ERP runtime never writes assignments.
create role bootik_security_runtime login password 'bootik-security-test-only';
grant usage on schema bootik to bootik_security_runtime;
do $$ declare n text;begin foreach n in array array['bk_security_settings','bk_security_audit','bk_member_functions'] loop execute format('create policy bk_runtime_access on bootik.%I to bootik_runtime using(true) with check(true)',n);end loop;end $$;
grant select on bootik.bk_security_settings,bootik.bk_security_audit,bootik.bk_member_functions to bootik_runtime;
grant insert on bootik.bk_security_audit to bootik_runtime;
grant execute on function bootik.bk_effective_plan(uuid,uuid,text),bootik.bk_has_capability(uuid,uuid,text,text),bootik.bk_issue_session(uuid,uuid,uuid,text,text,bigint,uuid,text),bootik.bk_permits_operation(uuid,uuid,uuid,text,jsonb) to bootik_runtime;
do $$ declare n text;begin foreach n in array array['bk_security_settings','bk_security_audit','bk_admin_receipts','bk_members','bk_member_sites','bk_member_activity_scopes','bk_member_functions','bk_locations','bk_activity_locations','bk_sessions'] loop execute format('create policy bk_security_access on bootik.%I to bootik_security_runtime using(true) with check(true)',n);end loop;end $$;
grant select on bootik.bk_security_settings,bootik.bk_security_audit,bootik.bk_admin_receipts,bootik.bk_members,bootik.bk_member_sites,bootik.bk_member_activity_scopes,bootik.bk_member_functions,bootik.bk_locations,bootik.bk_activity_locations,bootik.bk_sessions to bootik_security_runtime;
grant insert on bootik.bk_security_settings,bootik.bk_security_audit,bootik.bk_admin_receipts,bootik.bk_member_activity_scopes,bootik.bk_member_functions to bootik_security_runtime;
grant delete on bootik.bk_member_activity_scopes to bootik_security_runtime;
grant update(max_member_sessions) on bootik.bk_security_settings to bootik_security_runtime;
grant update(active,role) on bootik.bk_members to bootik_security_runtime;
grant update(activity_restricted) on bootik.bk_member_sites to bootik_security_runtime;
grant update(function_code) on bootik.bk_member_functions to bootik_security_runtime;
grant update(revoked_at) on bootik.bk_sessions to bootik_security_runtime;
grant execute on function bootik.bk_assert_scope(uuid,uuid,uuid,uuid,boolean),bootik.bk_can_access_activity(uuid,uuid,uuid,uuid,uuid),bootik.bk_admin_action(uuid,uuid,uuid,uuid,uuid,jsonb) to bootik_security_runtime;

-- Credential recovery: administration reads only identity columns, never the stored verifier/salt.
create policy bk_runtime_access on bootik.bk_password_controls for select to bootik_runtime using(true);
grant select on bootik.bk_password_controls to bootik_runtime;
create policy bk_security_access on bootik.bk_password_controls to bootik_security_runtime using(true) with check(true);
grant select,insert on bootik.bk_password_controls to bootik_security_runtime;
grant update(version,requires_change) on bootik.bk_password_controls to bootik_security_runtime;
create policy bk_security_access on bootik.bk_credentials to bootik_security_runtime using(true) with check(true);
grant select(organization_id,app_id,user_id,identifier) on bootik.bk_credentials to bootik_security_runtime;
grant update(salt_hex,verifier_hex) on bootik.bk_credentials to bootik_security_runtime;
create policy bk_security_access on bootik.bk_recovery_requests to bootik_security_runtime using(true) with check(true);
grant select on bootik.bk_recovery_requests to bootik_security_runtime;
grant update(processed_at,handled_by) on bootik.bk_recovery_requests to bootik_security_runtime;
grant execute on function bootik.bk_complete_recovery(uuid,uuid,uuid,uuid,uuid,text,text,text,text),bootik.bk_change_password(uuid,uuid,uuid,text,bigint,text,text) to bootik_security_runtime;

create policy bk_runtime_access on bootik.bk_site_device_policy for select to bootik_runtime using(true);
create policy bk_runtime_access on bootik.bk_device_site_bindings to bootik_runtime using(true) with check(true);
grant select on bootik.bk_site_device_policy,bootik.bk_device_site_bindings to bootik_runtime;
grant insert on bootik.bk_device_site_bindings to bootik_runtime;
grant execute on function bootik.bk_bind_device_site(uuid,uuid,uuid,uuid,uuid) to bootik_runtime;
create policy bk_security_access on bootik.bk_site_device_policy to bootik_security_runtime using(true) with check(true);
create policy bk_security_access on bootik.bk_device_site_bindings for select to bootik_security_runtime using(true);
grant select,insert on bootik.bk_site_device_policy to bootik_security_runtime;
grant update(max_devices) on bootik.bk_site_device_policy to bootik_security_runtime;
grant select on bootik.bk_device_site_bindings to bootik_security_runtime;

-- A separate Family NAXA provisioner may attach pre-existing Auth identities, never create them.
create role bootik_provision_runtime login password 'bootik-provision-test-only';
grant usage on schema bootik to bootik_provision_runtime;
do $$ declare n text;begin foreach n in array array['bk_app_registration','bk_organizations','bk_locations','bk_activities','bk_activity_locations','bk_members','bk_member_sites','bk_member_activity_scopes','bk_member_functions','bk_credentials','bk_password_controls','bk_member_profiles','bk_member_requests','bk_family_provision_events','bk_security_audit'] loop execute format('create policy bk_provision_access on bootik.%I to bootik_provision_runtime using(true) with check(true)',n);end loop;end $$;
grant select on bootik.bk_app_registration,bootik.bk_organizations,bootik.bk_locations,bootik.bk_activities,bootik.bk_activity_locations,bootik.bk_members,bootik.bk_member_sites,bootik.bk_member_requests,bootik.bk_family_provision_events to bootik_provision_runtime;
grant insert on bootik.bk_organizations,bootik.bk_locations,bootik.bk_activities,bootik.bk_activity_locations,bootik.bk_members,bootik.bk_member_sites,bootik.bk_member_activity_scopes,bootik.bk_member_functions,bootik.bk_credentials,bootik.bk_password_controls,bootik.bk_member_profiles,bootik.bk_family_provision_events,bootik.bk_security_audit to bootik_provision_runtime;
grant update(state,completed_at,member_id) on bootik.bk_member_requests to bootik_provision_runtime;
grant execute on function bootik.bk_family_provision(uuid,uuid,jsonb,text,text) to bootik_provision_runtime;
create policy bk_security_access on bootik.bk_member_requests to bootik_security_runtime using(true) with check(true);
create policy bk_security_access on bootik.bk_activities for select to bootik_security_runtime using(true);
grant select on bootik.bk_activities to bootik_security_runtime;
grant select,insert on bootik.bk_member_requests to bootik_security_runtime;
grant execute on function bootik.bk_request_member(uuid,uuid,uuid,uuid,uuid,text,text,jsonb,text) to bootik_security_runtime;
create policy bk_runtime_access on bootik.bk_member_profiles for select to bootik_runtime using(true);
grant select on bootik.bk_member_profiles to bootik_runtime;

grant update(offline_minutes) on bootik.bk_security_settings to bootik_security_runtime;
grant execute on function bootik.bk_scope_stamp(uuid,uuid,uuid) to bootik_runtime;

do $$ declare n text;begin foreach n in array array['bk_member_resource_rules','bk_workstations','bk_territories'] loop execute format('create policy bk_runtime_access on bootik.%I for select to bootik_runtime using(true)',n);execute format('create policy bk_security_access on bootik.%I to bootik_security_runtime using(true) with check(true)',n);end loop;end $$;
grant select on bootik.bk_member_resource_rules,bootik.bk_workstations,bootik.bk_territories to bootik_runtime;
grant select,insert on bootik.bk_member_resource_rules,bootik.bk_workstations,bootik.bk_territories to bootik_security_runtime;
grant update(resource_kind,resources) on bootik.bk_member_resource_rules to bootik_security_runtime;
create policy bk_security_access on bootik.bk_storage_locations for select to bootik_security_runtime using(true);
grant select on bootik.bk_storage_locations to bootik_security_runtime;

-- Central expansion and verified promoteur recovery: no read of password verifier and no auth.users write.
create policy bk_provision_access on bootik.bk_sessions to bootik_provision_runtime using(true) with check(true);
grant select(organization_id,app_id,user_id,revoked_at) on bootik.bk_sessions to bootik_provision_runtime;
grant update(revoked_at) on bootik.bk_sessions to bootik_provision_runtime;
grant select(organization_id,app_id,user_id) on bootik.bk_credentials to bootik_provision_runtime;
grant update(salt_hex,verifier_hex) on bootik.bk_credentials to bootik_provision_runtime;
grant select on bootik.bk_password_controls to bootik_provision_runtime;
grant update(version,requires_change) on bootik.bk_password_controls to bootik_provision_runtime;

create policy bk_runtime_access on bootik.bk_notification_reads to bootik_runtime using(true) with check(true);
create policy bk_runtime_access on bootik.bk_notification_preferences to bootik_runtime using(true) with check(true);
grant select,insert on bootik.bk_notification_reads,bootik.bk_notification_preferences to bootik_runtime;
grant update(approval_enabled) on bootik.bk_notification_preferences to bootik_runtime;
