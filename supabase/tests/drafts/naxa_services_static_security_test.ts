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
    tablesWithoutPolicy: [],
    restrictedTables: [],
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
