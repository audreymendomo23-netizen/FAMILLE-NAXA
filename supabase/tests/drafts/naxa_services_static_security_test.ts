// Static security guard for NAXA SERVICES draft SQL.
// Source-level assertions only: this does NOT execute PostgreSQL or prove RLS behaviour.
type DraftSpec = {
  file: string;
  tablesWithoutPolicy: string[];
  restrictedTables: string[];
};

const DRAFTS: DraftSpec[] = [
  {
    file: "naxa_services_v1.sql",
    tablesWithoutPolicy: [
      "ns_accounts",
      "ns_auth_attempts",
      "ns_auth_recovery_requests",
      "ns_devices",
    ],
    restrictedTables: [
      "ns_accounts",
      "ns_auth_attempts",
      "ns_auth_recovery_requests",
      "ns_devices",
      "ns_audit_events",
    ],
  },
  {
    file: "naxa_services_v2_activity_onboarding_management.sql",
    tablesWithoutPolicy: ["ns_legal_acceptances"],
    restrictedTables: ["ns_legal_acceptances"],
  },
  {
    file: "naxa_services_v3_operations_rewards_sync.sql",
    tablesWithoutPolicy: [
      "ns_sync_receipts",
      "ns_sync_conflicts",
      "ns_notification_outbox",
    ],
    restrictedTables: [
      "ns_sync_receipts",
      "ns_sync_conflicts",
      "ns_notification_outbox",
    ],
  },
  {
    file: "naxa_services_v4_supplier_accounting_forecast.sql",
    tablesWithoutPolicy: ["ns_inventory_valuations"],
    restrictedTables: ["ns_inventory_valuations"],
  },
  {
    file: "naxa_services_v5_customer_referrals_promotions.sql",
    tablesWithoutPolicy: [
      "ns_customer_referral_campaigns",
      "ns_customer_referral_codes",
      "ns_customer_referrals",
      "ns_customer_referral_rewards",
      "ns_promotion_campaigns",
      "ns_promotion_prizes",
      "ns_promotion_spins",
    ],
    restrictedTables: [
      "ns_customer_referral_campaigns",
      "ns_customer_referral_codes",
      "ns_customer_referrals",
      "ns_customer_referral_rewards",
      "ns_promotion_campaigns",
      "ns_promotion_prizes",
      "ns_promotion_spins",
    ],
  },
  {
    file: "naxa_services_v6_notifications.sql",
    tablesWithoutPolicy: ["ns_push_tokens", "ns_notification_inbox"],
    restrictedTables: ["ns_push_tokens", "ns_notification_inbox"],
  },
  {
    file: "naxa_services_v7_financial_controls.sql",
    tablesWithoutPolicy: ["ns_payment_provider_accounts", "ns_payment_provider_events"],
    restrictedTables: ["ns_payment_provider_accounts", "ns_payment_provider_events"],
  },
];

const SERVER_ONLY_TABLES = DRAFTS.flatMap((draft) => draft.restrictedTables);

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function stripLineComments(sql: string): string {
  return sql.replace(/--[^\r\n]*/g, "");
}

function tableNamesFromList(targets: string): string[] {
  return [...targets.matchAll(/public\.(ns_[a-z0-9_]+)/gi)].map((match) => match[1]);
}

async function readDraft(file: string): Promise<string> {
  return stripLineComments(
    await Deno.readTextFile(new URL("../../drafts/" + file, import.meta.url)),
  );
}

Deno.test("NAXA SERVICES draft tables all enable RLS and have a scoped policy or server-only boundary", async () => {
  for (const draft of DRAFTS) {
    const sql = await readDraft(draft.file);
    const createdTables = new Set(
      [...sql.matchAll(/create\s+table\s+if\s+not\s+exists\s+public\.(ns_[a-z0-9_]+)/gi)]
        .map((match) => match[1]),
    );
    const rlsTables = new Set(
      [...sql.matchAll(/alter\s+table\s+public\.(ns_[a-z0-9_]+)\s+enable\s+row\s+level\s+security/gi)]
        .map((match) => match[1]),
    );
    const policyStatements = [...sql.matchAll(/create\s+policy\s+[a-z0-9_]+\s+on\s+public\.(ns_[a-z0-9_]+)([\s\S]*?);/gi)];
    const policyTables = new Set(policyStatements.map((match) => match[1]));
    const serverOnly = new Set(draft.tablesWithoutPolicy);

    assert(createdTables.size > 0, draft.file + ": no CREATE TABLE statement was found");
    for (const table of createdTables) {
      assert(rlsTables.has(table), draft.file + ": RLS is not enabled on " + table);
      if (!policyTables.has(table)) {
        assert(serverOnly.has(table), draft.file + ": " + table + " has neither an RLS policy nor an approved server-only classification");
      }
    }
    for (const table of serverOnly) {
      assert(createdTables.has(table), draft.file + ": server-only allowlist entry is not created here: " + table);
      assert(!policyTables.has(table), draft.file + ": server-only table unexpectedly gained a client policy: " + table);
    }
    for (const policy of policyStatements) {
      const nameAndTable = policy[0].slice(0, policy[0].indexOf(policy[2]));
      const body = policy[2];
      assert(/public\.ns_[a-z0-9_]+\s*\(/i.test(body),
        draft.file + ": policy " + nameAndTable.trim() + " must use a server-defined scope helper");
      assert(!/(using|with\s+check)\s*\(\s*true\s*\)/i.test(body),
        draft.file + ": unconditional policy detected: " + nameAndTable.trim());
    }
  }
});

Deno.test("restricted tables revoke PUBLIC/anon/authenticated and grant service_role only", async () => {
  for (const draft of DRAFTS) {
    const sql = await readDraft(draft.file);
    const revokeStatements = [...sql.matchAll(/revoke\s+all\s+on\s+([^;]+?)\s+from\s+([^;]+);/gis)];
    const grantStatements = [...sql.matchAll(/grant\s+([^;]+?)\s+on\s+([^;]+?)\s+to\s+([^;]+);/gis)];

    for (const table of draft.restrictedTables) {
      const revoked = revokeStatements.some((match) => {
        const targets = tableNamesFromList(match[1]);
        const roles = match[2].toLowerCase().split(",").map((role) => role.trim());
        return targets.includes(table) &&
          ["public", "anon", "authenticated"].every((role) => roles.includes(role));
      });
      assert(revoked, draft.file + ": " + table + " must explicitly revoke all from PUBLIC, anon and authenticated");

      const serviceGrant = grantStatements.some((match) => {
        const privileges = match[1].trim().toLowerCase();
        const targets = tableNamesFromList(match[2]);
        const roles = match[3].toLowerCase().split(",").map((role) => role.trim());
        return privileges === "all" && targets.includes(table) && roles.includes("service_role");
      });
      assert(serviceGrant, draft.file + ": " + table + " must explicitly grant service_role access");

      const clientGrant = grantStatements.some((match) => {
        const targets = tableNamesFromList(match[2]);
        const roles = match[3].toLowerCase().split(",").map((role) => role.trim());
        return targets.includes(table) && roles.some((role) => ["public", "anon", "authenticated"].includes(role));
      });
      assert(!clientGrant, draft.file + ": " + table + " must not be granted directly to a client role");
    }
  }
});

Deno.test("every SECURITY DEFINER function pins an empty search_path", async () => {
  for (const draft of DRAFTS) {
    const sql = await readDraft(draft.file);
    const functions = [...sql.matchAll(/security\s+definer/gi)];
    for (const fn of functions) {
      const functionTail = sql.slice(fn.index, fn.index + 260);
      assert(/set\s+search_path\s*=\s*''/i.test(functionTail),
        draft.file + ": SECURITY DEFINER at source offset " + fn.index + " must set search_path = ''");
    }
  }
});

Deno.test("all NAXA SERVICES SQL candidates are transactional and clearly non-production drafts", async () => {
  for (const draft of DRAFTS) {
    const raw = await Deno.readTextFile(new URL("../../drafts/" + draft.file, import.meta.url));
    const sql = stripLineComments(raw).trim();
    assert(/\bbegin\s*;/i.test(sql), draft.file + ": transaction BEGIN is required");
    assert(/\b(rollback|commit)\s*;\s*$/i.test(sql), draft.file + ": explicit transaction end is required");
    assert(/draft/i.test(raw.slice(0, 700)), draft.file + ": the file must identify itself as a draft");
  }
});

Deno.test("server-only classification has unique table names", () => {
  assert(new Set(SERVER_ONLY_TABLES).size === SERVER_ONLY_TABLES.length,
    "SERVER_ONLY_TABLES contains duplicate entries");
});


Deno.test("supplier sync drafts preserve local supplier, purchase and line UUIDs", async () => {
  const sql = await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_save_supplier\s*\(/i.test(sql),
    "Supplier ID-preserving RPC is required");
  assert(/where\s+id\s*=\s*p_supplier_id\s+for\s+update/i.test(sql),
    "Supplier upsert must lock and scope an existing client UUID");
  assert(/insert\s+into\s+public\.ns_purchase_documents\s*\(\s*id\s*,/i.test(sql),
    "Purchase RPC must insert the caller's canonical ID");
  assert(/p_idempotency_key\s*,\s*p_org_id\s*,\s*p_site_id/i.test(sql),
    "Purchase ID must equal the idempotency UUID");
  assert(/jsonb_to_recordset\(p_lines\)[\s\S]{0,250}line_id\s+uuid/i.test(sql),
    "Purchase lines must accept explicit client UUIDs");
  assert(/select\s+x\.line_id\s*,\s*p_org_id\s*,\s*p_site_id\s*,\s*v_purchase_id/i.test(sql),
    "Purchase line UUIDs must be persisted rather than regenerated");
  assert(/grant\s+execute\s+on\s+function\s+public\.ns_save_supplier\([^;]+\)\s+to\s+authenticated,\s*service_role/i.test(sql),
    "Supplier identity RPC must have explicit execution grants");
});

Deno.test("inventory sync RPCs preserve canonical IDs, tenant scope and replay-safe movement writes", async () => {
  const sql = await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_save_inventory_item\s*\(/i.test(sql),
    "Stable inventory item upsert RPC is required");
  assert(/where\s+id\s*=\s*p_inventory_item_id\s+for\s+update/i.test(sql),
    "Inventory item upsert must lock the canonical local UUID");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_record_inventory_movement\s*\(/i.test(sql),
    "Append-only inventory movement RPC is required");
  assert(/v_existing\.idempotency_key\s*<>\s*p_movement_id/i.test(sql),
    "Changed payload under an existing movement ID must be rejected");
  assert(/v_next_quantity\s*<\s*0/i.test(sql),
    "A movement may not create negative stock");
  assert(/grant\s+execute\s+on\s+function\s+public\.ns_save_inventory_item\([^;]+\)\s+to\s+authenticated,\s*service_role/i.test(sql),
    "Inventory item RPC must have explicit scoped grants");
  assert(/grant\s+execute\s+on\s+function\s+public\.ns_record_inventory_movement\([^;]+\)\s+to\s+authenticated,\s*service_role/i.test(sql),
    "Inventory movement RPC must have explicit scoped grants");
});


Deno.test("N2 atomic sync gateway writes the server receipt in the business transaction", async () => {
  const sql = await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_apply_sync_event\s*\(/i.test(sql),
    "Atomic sync dispatch RPC is required");
  assert(/security\s+definer\s+set\s+search_path\s*=\s*''/i.test(sql),
    "Sync dispatch must be SECURITY DEFINER with a pinned empty search_path");
  assert(/pg_advisory_xact_lock/i.test(sql),
    "Event idempotency must be serialized inside the transaction");
  assert(/extensions\.digest\(convert_to\(p_payload::text,\s*'UTF8'\),\s*'sha256'\)/i.test(sql),
    "The canonical payload digest must be calculated server-side");
  assert(/insert\s+into\s+public\.ns_sync_receipts[\s\S]*?case\s+p_action_code[\s\S]*?update\s+public\.ns_sync_receipts[\s\S]*?status\s*=\s*'applied'/i.test(sql),
    "Business dispatch and applied receipt must be enclosed in the same database function transaction");
  assert(/where\s+d\.id\s*=\s*p_device_id[\s\S]{0,250}d\.account_id\s*=\s*v_account_id[\s\S]{0,250}d\.session_id\s*=\s*v_session_id[\s\S]{0,250}d\.revoked_at\s+is\s+null/i.test(sql),
    "A sync event must be bound to the authenticated registered device and session");
  assert(/revoke\s+all\s+on\s+function\s+public\.ns_apply_sync_event\([^;]+\)\s+from\s+public,\s*anon/i.test(sql),
    "Sync dispatch must not be executable by public or anon");
  assert(/grant\s+execute\s+on\s+function\s+public\.ns_apply_sync_event\([^;]+\)\s+to\s+authenticated,\s*service_role/i.test(sql),
    "Sync dispatch must have explicit authenticated and service-role grants");
  for (const action of [
    "supplier.saved","inventory_item.created","inventory_item.imported",
    "inventory_item.import_updated","inventory_item.supplier_whatsapp_updated",
    "inventory_movement.created","inventory_movement.import_initial",
    "inventory_movement.import_adjustment","purchase.ordered",
    "purchase.receipt.confirmed","supplier.payment.recorded",
    "recurring_charge.saved","recurring_charge.deactivated",
    "recurring_charge.payment_recorded","loyalty_program.updated",
    "loyalty_activity.recorded","loyalty_reward.redeemed"
  ]) {
    assert(sql.includes("'" + action + "'"),
      "N2 sync dispatcher missing allowlisted action " + action);
  }
});


Deno.test("N2 service, customer, CRM and support handlers are scoped and server-write-only", async () => {
  const sql = await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  for (const fn of [
    "ns_create_service","ns_update_service","ns_update_service_configuration",
    "ns_create_customer","ns_create_customer_followup",
    "ns_complete_customer_followup","ns_create_support_request"
  ]) {
    assert(new RegExp("create\\s+or\\s+replace\\s+function\\s+public\\."+fn+"\\s*\\(", "i").test(sql),
      "Missing N2 handler " + fn);
  }
  assert(/p_expected_version\s*<>\s*v_service\.revision/i.test(sql),
    "Service catalogue edits must enforce optimistic version checks");
  assert(/p_location_consent_at\s+is\s+null/i.test(sql),
    "Customer GPS must require explicit location consent");
  assert(/insert\s+into\s+public\.ns_customer_followup_events/i.test(sql),
    "Follow-up completion must preserve its append-only completion event");
  assert(/revoke\s+insert,\s*update,\s*delete\s+on\s+public\.ns_services,\s*public\.ns_customers\s+from\s+public,\s*anon,\s*authenticated/i.test(sql),
    "Service and customer writes must be restricted to server-side RPCs");
  for (const table of ["ns_customer_followups","ns_customer_followup_events","ns_support_requests"]) {
    assert(new RegExp("alter\\s+table\\s+public\\."+table+"\\s+enable\\s+row\\s+level\\s+security","i").test(sql),
      table + " must enable RLS");
    assert(new RegExp("create\\s+policy\\s+[^;]+\\s+on\\s+public\\."+table,"i").test(sql),
      table + " must have a scoped read policy");
  }
  assert(/revoke\s+all\s+on\s+function\s+public\.ns_create_service\([^;]+\)\s+from\s+public,\s*anon/i.test(sql),
    "Service RPC must revoke public/anon execution");
  assert(/grant\s+execute\s+on\s+function\s+public\.ns_create_service\([^;]+\)\s+to\s+service_role/i.test(sql),
    "Service RPC must explicitly grant authenticated/service_role execution");
});



Deno.test("N2 inventory valuation handler is versioned, scoped and server-write-only", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_upsert_inventory_valuation\s*\(/i.test(sql),
    "Inventory valuation handler is required");
  assert(/p_expected_version\s*<>\s*v_existing\.revision/i.test(sql),
    "Inventory valuation updates must reject stale revisions");
  assert(/update\s+public\.ns_inventory_items[\s\S]{0,250}average_unit_cost_xaf=p_unit_cost_xaf[\s\S]{0,250}selling_price_xaf=p_selling_price_xaf/i.test(sql),
    "Inventory item reporting projection must update with valuation ledger");
  assert(/revoke\s+all\s+on\s+public\.ns_inventory_valuations\s+from\s+public,anon,authenticated/i.test(sql),
    "Inventory valuation ledger must remain server-only");
  assert(/grant\s+all\s+on\s+public\.ns_inventory_valuations\s+to\s+service_role/i.test(sql),
    "Inventory valuation ledger must be writable by service_role");
  for(const action of ["inventory_valuation.imported","inventory_valuation.import_updated","inventory_valuation.updated"]) {
    assert(sql.includes("'" + action + "'"),"Missing inventory valuation action " + action);
  }
});

Deno.test("N2 pressing and appointment RPCs enforce lifecycle versions and server-side slot locks", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  for(const fn of ["ns_create_pressing_order","ns_transition_pressing_order","ns_create_appointment","ns_transition_appointment","ns_reschedule_appointment"]) {
    assert(new RegExp("create\\s+or\\s+replace\\s+function\\s+public\\."+fn+"\\s*\\(","i").test(sql),
      "Missing pressing/appointment handler "+fn);
  }
  assert(sql.includes("v_order.revision<>p_expected_version"),
    "Pressing transitions require an expected revision");
  assert(sql.includes("p_expected_version<>v_appointment.revision"),
    "Appointment transitions require an expected revision");
  assert(/pg_advisory_xact_lock[\s\S]{0,200}appointment-slots/i.test(sql),
    "Appointment slots must be serialized transactionally");
  assert(/a\.starts_at<p_ends_at\s+and\s+a\.ends_at>p_starts_at/i.test(sql),
    "Server-side appointment overlap detection is required");
  assert(/revoke\s+insert,update,delete\s+on\s+public\.ns_pressing_orders,public\.ns_appointments\s+from\s+public,anon,authenticated/i.test(sql),
    "Pressing/appointment client writes must be RPC-only");
  assert(/revoke\s+insert,update,delete\s+on\s+public\.ns_pressing_status_events,public\.ns_appointment_status_events\s+from\s+public,anon,authenticated/i.test(sql),
    "Pressing/appointment status ledgers must be append-only server writes");
});

Deno.test("N2 cash session and expense handlers are scoped and compute close balances on server", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  for(const fn of ["ns_open_cash_session","ns_record_expense","ns_close_cash_session"]) {
    assert(new RegExp("create\\s+or\\s+replace\\s+function\\s+public\\."+fn+"\\s*\\(","i").test(sql),
      "Missing cash handler "+fn);
  }
  assert(/ns_cash_sessions_one_open_per_register_uidx/i.test(sql),
    "Only one open cash session per register is allowed");
  assert(/pg_advisory_xact_lock[\s\S]{0,180}cash-open/i.test(sql),
    "Register opening must be serialized");
  assert(/sum\(p\.amount_xaf\)[\s\S]{0,300}payment_method='cash'[\s\S]{0,200}status='confirmed'/i.test(sql),
    "Cash close must total confirmed cash payments only");
  assert(/v_expected:=v_session\.opening_float_xaf\+v_cash_in-v_expenses-v_supplier_out/i.test(sql),
    "Cash close balance must be computed server-side");
  assert(/v_variance:=p_counted_close_xaf-v_expected/i.test(sql),
    "Cash variance must be computed server-side");
  assert(/revoke\s+insert,update,delete\s+on\s+public\.ns_cash_sessions,public\.ns_expenses\s+from\s+public,anon,authenticated/i.test(sql),
    "Cash sessions and expenses must be mutated only by RPC");
});


Deno.test("N2 sale handlers post cash sale inventory once and keep Mobile Money pending until provider verification", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_create_sale\s*\(/i.test(sql),
    "Sale creation handler is required");
  assert(/create\s+or\s+replace\s+function\s+public\.ns_cancel_pending_mobile_money_sale\s*\(/i.test(sql),
    "Pending Mobile Money cancellation handler is required");
  assert(/p_payment_method='cash'\s+and\s+p_expected_status<>'confirmed'/i.test(sql),
    "Cash sale must be confirmed synchronously");
  assert(/p_payment_method='mobile_money'\s+and\s+p_expected_status<>'pending'/i.test(sql),
    "Mobile Money sale must remain pending on client creation");
  assert(/ns_post_sale_inventory\(p_org_id,p_site_id,p_sale_id,p_event_id\)/i.test(sql),
    "Cash sale must call the existing atomic stock/accounting posting operation");
  assert(/status='failed',confirmation_source='cancelled_before_provider_confirmation'/i.test(sql),
    "Only a pending provider payment can be cancelled before confirmation");
  assert(/revoke\s+insert,update,delete\s+on\s+public\.ns_sales,public\.ns_payments,public\.ns_sale_lines\s+from\s+public,anon,authenticated/i.test(sql),
    "Sale, payment and line writes must be RPC-only");
});


Deno.test("N2 domain mutation helpers cannot bypass the atomic sync receipt gateway", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  for(const fn of [
    "ns_create_pressing_order","ns_transition_pressing_order","ns_create_appointment",
    "ns_transition_appointment","ns_reschedule_appointment","ns_open_cash_session",
    "ns_record_expense","ns_close_cash_session","ns_create_sale",
    "ns_cancel_pending_mobile_money_sale","ns_create_service","ns_update_service",
    "ns_update_service_configuration","ns_create_customer","ns_create_customer_followup",
    "ns_complete_customer_followup","ns_create_support_request",
    "ns_upsert_inventory_valuation","ns_upsert_recurring_charge",
    "ns_deactivate_recurring_charge","ns_upsert_loyalty_program"
  ]) {
    const revokeStart=sql.indexOf("revoke all on function public."+fn+"(");
    const grantStart=sql.indexOf("grant execute on function public."+fn+"(");
    assert(revokeStart>=0 && grantStart>=0,fn+" must have explicit execute privileges");
    const revokeStatement=sql.slice(revokeStart,sql.indexOf(";",revokeStart));
    const grantStatement=sql.slice(grantStart,sql.indexOf(";",grantStart));
    assert(revokeStatement.endsWith("from public, anon, authenticated"),
      fn+" must revoke direct client execution");
    assert(grantStatement.endsWith("to service_role"),
      fn+" must only be directly executable by the server role");
  }
  const gatewayStart=sql.indexOf("grant execute on function public.ns_apply_sync_event(");
  const gatewayGrant=sql.slice(gatewayStart,sql.indexOf(";",gatewayStart));
  assert(gatewayStart>=0 && gatewayGrant.includes("to authenticated, service_role"),
    "Authenticated clients must enter mutations through the atomic sync gateway");
});


Deno.test("N2 customer, waitlist, staff, management and transfer handlers are fully server-gated", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  const required=[
    "ns_update_customer","ns_convert_waitlist_to_appointment","ns_record_staff_time_event",
    "ns_create_management_record","ns_transition_management_record",
    "ns_create_inventory_transfer","ns_receive_inventory_transfer"
  ];
  for(const fn of required) {
    assert(sql.includes("create or replace function public."+fn+"("),"Missing N2 handler "+fn);
    const revokeStart=sql.indexOf("revoke all on function public."+fn+"(");
    const grantStart=sql.indexOf("grant execute on function public."+fn+"(");
    assert(revokeStart>=0&&grantStart>=0,fn+" must define execute privileges");
    const revokeStatement=sql.slice(revokeStart,sql.indexOf(";",revokeStart));
    const grantStatement=sql.slice(grantStart,sql.indexOf(";",grantStart));
    assert(revokeStatement.endsWith("from public,anon,authenticated") ||
      revokeStatement.endsWith("from public, anon, authenticated"),
      fn+" must revoke direct client execution");
    assert(grantStatement.endsWith("to service_role"),
      fn+" must only be directly executable by the server role");
  }
  for(const table of [
    "ns_management_records","ns_management_record_events","ns_staff_time_events","ns_inventory_transfers"
  ]) {
    assert(new RegExp("alter table public\\."+table+" enable row level security","i").test(sql),
      table+" must enable RLS");
    assert(sql.includes("revoke all on public.ns_management_records,public.ns_management_record_events,") ||
      sql.includes("revoke all on public.ns_management_records, public.ns_management_record_events,"),
      "Management and HR ledgers must be server-write-only");
  }
  assert(sql.includes("p_expected_version is null"),
    "Versioned management/customer mutations must require a revision");
  assert(sql.includes(":staff-time"),
    "Staff time sequence must serialize per employee and site");
  assert(sql.includes("create table if not exists public.ns_management_record_events") &&
    sql.includes("from_status text not null default ''") && sql.includes("to_status text not null"),
  assert(sql.includes("'transfer_out'") && sql.includes("'transfer_in'"),
    "Transfer receipt must write both stock movement legs");
  assert(/NAXA_INVENTORY_TRANSFER_RECEIVE_REQUIRES_COMPOSITE_ACTION/i.test(sql),
    "Generic transfer status transition must not duplicate stock posting");
});

Deno.test("N2 atomic dispatcher exposes all newly implemented event codes fail-closed", async () => {
  const sql=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  const actions=[
    "customer.updated","appointment.created_from_waitlist",
    "staff_clock_in.recorded","staff_break_start.recorded","staff_break_end.recorded","staff_clock_out.recorded",
    "quote.created","invoice.created","credit_note.created","refund_due.created",
    "customer_receivable.created","purchase.created","supplier.created","tax_estimate.created",
    "business_goal.created","subscription_request.created","support_chat.created","work_order.created",
    "repair_order.created","service_order.created","appointment_waitlist.created",
    "staff_clock_in.created","staff_clock_out.created","staff_break_start.created","staff_break_end.created",
    "staff_commission.created","staff_advance.created","staff_bonus.created",
    "quote.status_changed","invoice.status_changed","credit_note.status_changed","refund_due.status_changed",
    "customer_receivable.status_changed","purchase.status_changed","supplier.status_changed",
    "tax_estimate.status_changed","business_goal.status_changed","subscription_request.status_changed",
    "support_chat.status_changed","work_order.status_changed","repair_order.status_changed",
    "service_order.status_changed","appointment_waitlist.status_changed","staff_clock_in.status_changed",
    "staff_clock_out.status_changed","staff_break_start.status_changed","staff_break_end.status_changed",
    "staff_commission.status_changed","staff_advance.status_changed","staff_bonus.status_changed",
    "inventory_transfer.requested","inventory_transfer.received_at_destination","inventory_transfer.status_changed"
  ];
  for(const action of actions) {
    assert(sql.includes("'"+action+"'"),"Atomic SQL dispatcher missing "+action);
  }
  assert(sql.includes("NAXA_SYNC_ACTION_NOT_SUPPORTED"),
    "Unmapped actions must stay rejected by default");
});


Deno.test("N2 legacy supplier stock loyalty and sale helpers are server-role-only", async () => {
  const v3=await readDraft("naxa_services_v3_operations_rewards_sync.sql");
  const v4=await readDraft("naxa_services_v4_supplier_accounting_forecast.sql");
  const check=(sql:string,fn:string)=>{
    const revokeStart=sql.indexOf("revoke all on function public."+fn+"(");
    const grantStart=sql.indexOf("grant execute on function public."+fn+"(");
    assert(revokeStart>=0&&grantStart>=0,fn+" must define execute privilege boundaries");
    const revoke=sql.slice(revokeStart,sql.indexOf(";",revokeStart)).replace(/\\s+/g," ").replace(/,\\s*/g,", ");
    const grant=sql.slice(grantStart,sql.indexOf(";",grantStart)).replace(/\\s+/g," ").replace(/,\\s*/g,", ");
    assert(revoke.endsWith("from public, anon, authenticated"),fn+" must not be client-callable");
    assert(grant.endsWith("to service_role"),fn+" must be callable only by the server role");
  };
  for(const fn of [
    "ns_save_inventory_item","ns_record_inventory_movement","ns_post_sale_inventory",
    "ns_save_supplier","ns_create_supplier_purchase","ns_receive_supplier_purchase_line",
    "ns_record_supplier_payment"
  ]) check(v4,fn);
  for(const fn of ["ns_record_charge_payment","ns_record_loyalty_activity","ns_redeem_loyalty_reward"]) {
    check(v3,fn);
  }
});
