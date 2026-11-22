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
  assert(/grant\s+execute\s+on\s+function\s+public\.ns_create_service\([^;]+\)\s+to\s+authenticated,\s*service_role/i.test(sql),
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
  assert(/(?:p_expected_version\\s*<>\\s*v_order\\.revision|v_order\\.revision\\s*<>\\s*p_expected_version)/i.test(sql),
    "Pressing transitions require an expected revision");
  assert(/(?:p_expected_version\\s*<>\\s*v_appointment\\.revision|v_appointment\\.revision\\s*<>\\s*p_expected_version)/i.test(sql),
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
