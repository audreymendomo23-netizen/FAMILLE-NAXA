import { normalizeAtomicSyncEvent, normalizeSyncPullRequest } from "./sync_contract.ts";

import { accountingCorsHeaders } from "./accounting_contract.ts";

type JsonObject = Record<string, unknown>;

const EVENT_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;


function requiredString(value: unknown, key: string): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > 512) {
    throw new Error("INVALID_" + key.toUpperCase());
  }
  return value.trim();
}

function requiredNumber(value: unknown, key: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new Error("INVALID_" + key.toUpperCase());
  }
  return value;
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return "[" + value.map(stableJson).join(",") + "]";
  if (value && typeof value === "object") {
    const object = value as Record<string, unknown>;
    return "{" + Object.keys(object).sort().map((key) => JSON.stringify(key) + ":" + stableJson(object[key])).join(",") + "}";
  }
  return JSON.stringify(value);
}

async function sha256(value: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(stableJson(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function verifyAccessToken(baseUrl: string, anonKey: string, token: string): Promise<void> {
  const response = await fetch(baseUrl + "/auth/v1/user", {
    headers: { apikey: anonKey, Authorization: "Bearer " + token },
  });
  if (!response.ok) throw new Error("AUTHENTICATION_REQUIRED");
  const user = await response.json().catch(() => null) as JsonObject | null;
  if (!user || typeof user.id !== "string" || user.id.length < 10) throw new Error("AUTHENTICATION_REQUIRED");
}

async function postRpc(
  baseUrl: string,
  anonKey: string,
  token: string,
  functionName: string,
  args: JsonObject,
): Promise<unknown> {
  const response = await fetch(baseUrl + "/rest/v1/rpc/" + functionName, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: "Bearer " + token,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(args),
  });
  const text = await response.text();
  let result: unknown = null;
  try { result = text ? JSON.parse(text) : null; } catch { result = null; }
  if (!response.ok) {
    const code = result && typeof result === "object" && "code" in result
      ? String((result as JsonObject).code).slice(0, 80)
      : "RPC_FAILED";
    if (code === "42501" && (result as JsonObject).message === "NS_SUBSCRIPTION_ACCESS_REQUIRED") throw new Error("NS_SUBSCRIPTION_ACCESS_REQUIRED");
    throw new Error("ERP_" + code);
  }
  return result;
}

async function readView(
  baseUrl: string,
  anonKey: string,
  token: string,
  view: "ns_performance_daily" | "ns_performance_monthly" | "ns_performance_annual",
  orgId: string,
  siteIds: string[],
  fromDate: string,
): Promise<unknown> {
  if (siteIds.length < 1 || siteIds.length > 50 ||
      !siteIds.every((id) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(fromDate) ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(orgId)) {
    throw new Error("INVALID_PERFORMANCE_FILTER");
  }
  const query = new URLSearchParams();
  query.set("select", "*");
  query.set("org_id", "eq." + orgId);
  query.set("site_id", "in.(" + siteIds.join(",") + ")");
  const dateColumn = view === "ns_performance_daily" ? "performance_day"
    : view === "ns_performance_monthly" ? "performance_month" : "performance_year";
  query.set(dateColumn, "gte." + fromDate);
  query.set("order", dateColumn + ".asc");
  const response = await fetch(baseUrl + "/rest/v1/" + view + "?" + query.toString(), {
    headers: { apikey: anonKey, Authorization: "Bearer " + token },
  });
  const body = await response.text();
  if (!response.ok) throw new Error("ERP_PERFORMANCE_READ_FAILED");
  try { return body ? JSON.parse(body) : []; } catch { throw new Error("ERP_PERFORMANCE_INVALID_RESPONSE"); }
}

export async function handleAccountingRequest(
  request: Request,
  env: { supabaseUrl: string; anonKey: string; allowedOrigins?: readonly string[] },
): Promise<Response> {
  const cors = accountingCorsHeaders(request.headers.get("origin"), env.allowedOrigins ?? []);
  const reply = (status: number, body: JsonObject) => new Response(JSON.stringify(body), { status, headers: cors });
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
  if (!token) return reply(401, { error: "AUTHENTICATION_REQUIRED" });
  let body: JsonObject;
  try {
    const raw = await request.json();
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return reply(400, { error: "INVALID_BODY" });
    body = raw as JsonObject;
  } catch {
    return reply(400, { error: "INVALID_JSON" });
  }
  const eventId = typeof body.event_id === "string" ? body.event_id.trim() : "";
  if (body.event_id !== undefined && !EVENT_UUID.test(eventId)) {
    return reply(400, { error: "INVALID_EVENT_ID" });
  }

  const baseUrl = env.supabaseUrl.replace(/\/+$/, "");
  if (!/^https:\/\/[^/]+$/.test(baseUrl) || env.anonKey.length < 20) {
    return reply(503, { error: "ACCOUNTING_SERVICE_NOT_CONFIGURED" });
  }

  try {
    await verifyAccessToken(baseUrl, env.anonKey, token);
    const action = requiredString(body.action, "action");
    let result: unknown;

    switch (action) {
      case "pull_sync_changes": {
        const pull = normalizeSyncPullRequest(body);
        result = await postRpc(baseUrl, env.anonKey, token, "ns_pull_sync_changes", {
          p_org_id: pull.org_id,
          p_device_id: pull.device_id,
          p_after_cursor: pull.after_cursor,
          p_limit: pull.limit,
        });
        if (!result || typeof result !== "object" || Array.isArray(result)) {
          throw new Error("ERP_SYNC_PULL_INVALID_RESPONSE");
        }
        const page = result as JsonObject;
        if (!Array.isArray(page.changes) ||
            typeof page.next_cursor !== "number" ||
            !Number.isSafeInteger(page.next_cursor) ||
            typeof page.has_more !== "boolean" ||
            page.next_cursor < pull.after_cursor) {
          throw new Error("ERP_SYNC_PULL_INVALID_PAGE");
        }
        break;
      }
      case "apply_sync_event": {
        const event = normalizeAtomicSyncEvent(body.event);
        result = await postRpc(baseUrl, env.anonKey, token, "ns_apply_sync_event", {
          p_org_id: event.org_id,
          p_site_id: event.site_id,
          p_workstation_id: event.workstation_id,
          p_device_id: event.device_id,
          p_event_id: event.event_id,
          p_device_sequence: event.device_sequence,
          p_aggregate_type: event.aggregate_type,
          p_aggregate_id: event.aggregate_id,
          p_action_code: event.action_code,
          p_payload: event.payload,
        });
        if (!result || typeof result !== "object" || Array.isArray(result) ||
            (result as JsonObject).status !== "applied") {
          throw new Error("ERP_SYNC_RECEIPT_NOT_APPLIED");
        }
        break;
      }
      // These old direct mutations have no authenticated grant. Never widen those grants.
      // Current Android/Web use the atomic event gateway with device and receipt binding.
      case "save_inventory_item":
      case "record_inventory_movement":
      case "save_supplier":
      case "create_supplier_purchase":
      case "receive_supplier_purchase_line":
      case "record_supplier_payment":
      case "post_sale_inventory":
        return reply(409, { error: "ATOMIC_SYNC_REQUIRED", required_action: "apply_sync_event" });
      case "create_performance_objective": {
        result = await postRpc(baseUrl, env.anonKey, token, "ns_create_performance_objective", {
          p_org_id: requiredString(body.org_id, "org_id"),
          p_site_id: requiredString(body.site_id, "site_id"),
          p_period_type: requiredString(body.period_type, "period_type"),
          p_period_start: requiredString(body.period_start, "period_start"),
          p_period_end: requiredString(body.period_end, "period_end"),
          p_target_revenue_xaf: requiredNumber(body.target_revenue_xaf, "target_revenue_xaf"),
          p_reason: typeof body.reason === "string" ? body.reason : "",
        });
        break;
      }
      case "performance": {
        const orgId = requiredString(body.org_id, "org_id");
        if (!Array.isArray(body.site_ids) || !body.site_ids.every((x) => typeof x === "string")) {
          throw new Error("INVALID_SITE_FILTER");
        }
        const fromDate = requiredString(body.from_date, "from_date");
        const siteIds = body.site_ids as string[];
        const [daily, monthly, annual] = await Promise.all([
          readView(baseUrl, env.anonKey, token, "ns_performance_daily", orgId, siteIds, fromDate),
          readView(baseUrl, env.anonKey, token, "ns_performance_monthly", orgId, siteIds, fromDate.slice(0, 7) + "-01"),
          readView(baseUrl, env.anonKey, token, "ns_performance_annual", orgId, siteIds, fromDate.slice(0, 4) + "-01-01"),
        ]);
        result = { daily, monthly, annual };
        break;
      }
      default:
        return reply(400, { error: "UNSUPPORTED_ACCOUNTING_ACTION" });
    }
    const responseBody: JsonObject = { ok: true, result };
    return reply(200, responseBody);
  } catch (error) {
    const message = error instanceof Error ? error.message : "ACCOUNTING_REQUEST_FAILED";
    const status = message === "NS_SUBSCRIPTION_ACCESS_REQUIRED" ? 402 : message === "AUTHENTICATION_REQUIRED" ? 401 :
      message.startsWith("ERP_") ? 422 : 400;
    return reply(status, { error: message });
  }
}

Deno.serve(async (request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const allowedOrigins = (Deno.env.get("NS_ALLOWED_ORIGINS") ?? "").split(",").map((value) => value.trim()).filter(Boolean);
  return await handleAccountingRequest(request, { supabaseUrl, anonKey, allowedOrigins });
});
