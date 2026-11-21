import { normalizeInventoryItemSyncPayload, normalizeInventoryMovementSyncPayload, normalizeSupplierPurchaseSyncPayload, normalizeSupplierSyncPayload } from "./sync_contract.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

type JsonObject = Record<string, unknown>;

const EVENT_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function reply(status: number, body: JsonObject): Response {
  return new Response(JSON.stringify(body), { status, headers: CORS });
}

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
  env: { supabaseUrl: string; anonKey: string },
): Promise<Response> {
  if (request.method === "OPTIONS") return new Response("ok", { headers: CORS });
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
      case "save_inventory_item": {
        const payload = normalizeInventoryItemSyncPayload(body);
        result = await postRpc(baseUrl, env.anonKey, token, "ns_save_inventory_item", {
          p_inventory_item_id: payload.inventory_item_id,
          p_org_id: payload.org_id,
          p_site_id: payload.site_id,
          p_sku: payload.sku,
          p_name: payload.name,
          p_unit: payload.unit,
          p_reorder_level: payload.reorder_level,
          p_supplier_whatsapp: payload.supplier_whatsapp,
        });
        break;
      }
      case "record_inventory_movement": {
        const payload = normalizeInventoryMovementSyncPayload(body);
        result = await postRpc(baseUrl, env.anonKey, token, "ns_record_inventory_movement", {
          p_movement_id: payload.movement_id,
          p_org_id: payload.org_id,
          p_site_id: payload.site_id,
          p_inventory_item_id: payload.inventory_item_id,
          p_movement_type: payload.movement_type,
          p_quantity_delta: payload.quantity_delta,
          p_reason: payload.reason,
        });
        break;
      }
      case "save_supplier": {
        const payload = normalizeSupplierSyncPayload(body);
        result = await postRpc(baseUrl, env.anonKey, token, "ns_save_supplier", {
          p_supplier_id: payload.supplier_id,
          p_org_id: payload.org_id,
          p_site_id: payload.site_id,
          p_name: payload.name,
          p_phone: payload.phone,
          p_whatsapp: payload.whatsapp,
          p_email: payload.email,
          p_address: payload.address,
          p_payment_terms_days: payload.payment_terms_days,
          p_notes: payload.notes,
        });
        break;
      }
      case "create_supplier_purchase": {
        const payload = normalizeSupplierPurchaseSyncPayload(body);
        result = await postRpc(baseUrl, env.anonKey, token, "ns_create_supplier_purchase", {
          p_org_id: payload.org_id,
          p_site_id: payload.site_id,
          p_supplier_id: payload.supplier_id,
          p_reference: payload.reference,
          p_supplier_invoice_number: payload.supplier_invoice_number,
          p_idempotency_key: payload.purchase_id,
          p_payload_sha256: await sha256(payload),
          p_lines: payload.lines,
          p_recoverable_tax_xaf: payload.recoverable_tax_xaf,
          p_non_recoverable_tax_xaf: payload.non_recoverable_tax_xaf,
          p_shipping_xaf: payload.shipping_xaf,
          p_other_fees_xaf: payload.other_fees_xaf,
          p_due_at: payload.due_at,
          p_notes: payload.notes,
        });
        break;
      }
      case "receive_supplier_purchase_line": {
        const payload = {
          org_id: requiredString(body.org_id, "org_id"),
          site_id: requiredString(body.site_id, "site_id"),
          purchase_id: requiredString(body.purchase_id, "purchase_id"),
          line_id: requiredString(body.line_id, "line_id"),
          quantity: body.quantity,
        };
        if (typeof payload.quantity !== "number" || !Number.isFinite(payload.quantity) || payload.quantity <= 0) {
          throw new Error("INVALID_RECEIPT_QUANTITY");
        }
        result = await postRpc(baseUrl, env.anonKey, token, "ns_receive_supplier_purchase_line", {
          p_org_id: payload.org_id,
          p_site_id: payload.site_id,
          p_purchase_id: payload.purchase_id,
          p_line_id: payload.line_id,
          p_quantity: payload.quantity,
          p_idempotency_key: requiredString(body.idempotency_key, "idempotency_key"),
          p_payload_sha256: await sha256(payload),
        });
        break;
      }
      case "record_supplier_payment": {
        const payload = {
          org_id: requiredString(body.org_id, "org_id"),
          site_id: requiredString(body.site_id, "site_id"),
          purchase_id: requiredString(body.purchase_id, "purchase_id"),
          amount_xaf: requiredNumber(body.amount_xaf, "amount_xaf"),
          payment_method: requiredString(body.payment_method, "payment_method"),
          cash_session_id: typeof body.cash_session_id === "string" ? body.cash_session_id : null,
          payment_reference: typeof body.payment_reference === "string" ? body.payment_reference.trim() : "",
        };
        result = await postRpc(baseUrl, env.anonKey, token, "ns_record_supplier_payment", {
          p_org_id: payload.org_id,
          p_site_id: payload.site_id,
          p_purchase_id: payload.purchase_id,
          p_amount_xaf: payload.amount_xaf,
          p_payment_method: payload.payment_method,
          p_cash_session_id: payload.cash_session_id,
          p_payment_reference: payload.payment_reference,
          p_idempotency_key: requiredString(body.idempotency_key, "idempotency_key"),
          p_payload_sha256: await sha256(payload),
        });
        break;
      }
      case "post_sale_inventory": {
        result = await postRpc(baseUrl, env.anonKey, token, "ns_post_sale_inventory", {
          p_org_id: requiredString(body.org_id, "org_id"),
          p_site_id: requiredString(body.site_id, "site_id"),
          p_sale_id: requiredString(body.sale_id, "sale_id"),
          p_inventory_posting_key: requiredString(body.idempotency_key, "idempotency_key"),
        });
        break;
      }
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
    if (eventId) responseBody.receipt = { eventId, status: "applied" };
    return reply(200, responseBody);
  } catch (error) {
    const message = error instanceof Error ? error.message : "ACCOUNTING_REQUEST_FAILED";
    const status = message === "AUTHENTICATION_REQUIRED" ? 401 :
      message.startsWith("ERP_") ? 422 : 400;
    return reply(status, { error: message });
  }
}

Deno.serve(async (request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  return await handleAccountingRequest(request, { supabaseUrl, anonKey });
});
