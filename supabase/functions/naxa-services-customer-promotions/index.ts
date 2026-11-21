import {
  isCustomerReferralCode,
  isUuid,
  normalizeCustomerReferralCampaignDraft,
  normalizeCustomerReferralCode,
  normalizeWheelPrizeDraft,
} from "./promotion_contract.ts";

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("NS_CUSTOMER_PROMOTIONS_WEBHOOK_SECRET") ?? "";
const ALLOWED_ORIGINS = (Deno.env.get("NS_ALLOWED_ORIGINS") ?? "")
  .split(",").map((x) => x.trim()).filter(Boolean);

type Json = Record<string, unknown>;
type Actor = {
  authUserId: string;
  accountId: string;
  memberId: string;
  orgId: string;
  roleCode: string;
};

class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}

function reply(status: number, body: Json, origin?: string | null) {
  const allowed = origin && (ALLOWED_ORIGINS.includes(origin) || ALLOWED_ORIGINS.includes("*")) ? origin : "null";
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": allowed,
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-naxa-promotions-signature",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });
}

function serviceHeaders(extra: Record<string, string> = {}) {
  return {
    apikey: SERVICE_ROLE_KEY,
    Authorization: "Bearer " + SERVICE_ROLE_KEY,
    "Content-Type": "application/json",
    ...extra,
  };
}

function query(path: string, values: Record<string, string>) {
  const params = new URLSearchParams(values);
  return path + "?" + params.toString();
}

async function rest(path: string, init: RequestInit = {}): Promise<unknown> {
  const response = await fetch(SUPABASE_URL + "/rest/v1/" + path, {
    ...init,
    headers: { ...serviceHeaders(), ...(init.headers as Record<string, string> ?? {}) },
  });
  const raw = await response.text();
  let data: unknown = null;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = null; }
  if (!response.ok) throw new ApiError(response.status >= 500 ? 503 : 422, "PROMOTIONS_DATABASE_ERROR");
  return data;
}

async function rpc(name: string, args: Json): Promise<unknown> {
  return await rest("rpc/" + name, { method: "POST", body: JSON.stringify(args) });
}

async function actorContext(token: string): Promise<Actor | null> {
  if (!token) return null;
  const response = await fetch(SUPABASE_URL + "/auth/v1/user", {
    headers: { apikey: ANON_KEY, Authorization: "Bearer " + token },
  });
  if (!response.ok) return null;
  const user = await response.json().catch(() => null) as Json | null;
  if (!user || typeof user.id !== "string") return null;

  const accounts = await rest(query("ns_accounts", {
    select: "id,status", auth_user_id: "eq." + user.id, limit: "1",
  })) as Json[];
  const account = accounts?.[0];
  if (!account || account.status !== "active" || typeof account.id !== "string") return null;

  // Match the Supabase JWT session to a live, non-revoked NAXA device.
  // This keeps the Edge gateway aligned with ns_current_account_id() in SQL.
  const jwtParts = token.split(".");
  if (jwtParts.length !== 3) return null;
  let claims: Json;
  try {
    const encoded = jwtParts[1].replace(/-/g, "+").replace(/_/g, "/");
    claims = JSON.parse(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "="))) as Json;
  } catch {
    return null;
  }
  const sessionId = typeof claims.session_id === "string" ? claims.session_id : "";
  if (!sessionId) return null;
  const devices = await rest(query("ns_devices", {
    select: "id",
    account_id: "eq." + account.id,
    session_id: "eq." + sessionId,
    revoked_at: "is.null",
    limit: "1",
  })) as Json[];
  if (!devices?.length) return null;

  const members = await rest(query("ns_members", {
    select: "id,org_id,role_code,status",
    account_id: "eq." + account.id, status: "eq.active", limit: "2",
  })) as Json[];
  if (!members || members.length !== 1) return null;
  const member = members[0];
  if (typeof member.id !== "string" || typeof member.org_id !== "string" || typeof member.role_code !== "string") return null;

  const orgs = await rest(query("ns_organizations", {
    select: "id,status", id: "eq." + member.org_id, status: "eq.active", limit: "1",
  })) as Json[];
  if (!orgs?.length) return null;
  return { authUserId: user.id, accountId: account.id, memberId: member.id, orgId: member.org_id, roleCode: member.role_code };
}

async function requireSiteOperation(actor: Actor, siteId: string, manage = false) {
  if (!isUuid(siteId)) throw new ApiError(400, "INVALID_SITE_ID");
  const scopes = await rest(query("ns_member_scopes", {
    select: "scope_type,site_id,can_operate,can_manage",
    member_id: "eq." + actor.memberId,
    org_id: "eq." + actor.orgId,
    can_read: "eq.true",
  })) as Json[];
  const scopeOk = scopes.some((scope) =>
    (scope.scope_type === "organization" || (scope.scope_type === "site" && scope.site_id === siteId)) &&
    (manage ? scope.can_manage === true : scope.can_operate === true || scope.can_manage === true)
  );
  if (!scopeOk) throw new ApiError(403, "SITE_SCOPE_FORBIDDEN");
}

function requirePromoter(actor: Actor) {
  if (actor.roleCode !== "promoter") throw new ApiError(403, "PROMOTER_REQUIRED");
}

function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(5));
  return "CREF-" + Array.from(bytes, (x) => x.toString(16).padStart(2, "0")).join("").toUpperCase();
}

async function createCustomerCode(actor: Actor, body: Json) {
  const siteId = String(body.site_id ?? "");
  const campaignId = String(body.campaign_id ?? "");
  const customerId = String(body.customer_id ?? "");
  if (!isUuid(campaignId) || !isUuid(customerId)) throw new ApiError(400, "INVALID_REFERRAL_TARGET");
  await requireSiteOperation(actor, siteId);
  const customers = await rest(query("ns_customers", {
    select: "id,site_id,org_id",
    id: "eq." + customerId,
    org_id: "eq." + actor.orgId,
    site_id: "eq." + siteId,
    limit: "1",
  })) as Json[];
  if (!customers?.length) throw new ApiError(404, "CUSTOMER_NOT_FOUND");

  const campaigns = await rest(query("ns_customer_referral_campaigns", {
    select: "id,status,site_id,starts_at,ends_at",
    id: "eq." + campaignId, org_id: "eq." + actor.orgId, status: "eq.active", limit: "1",
  })) as Json[];
  const campaign = campaigns?.[0];
  if (!campaign) throw new ApiError(409, "REFERRAL_CAMPAIGN_NOT_ACTIVE");
  if (campaign.site_id && campaign.site_id !== siteId) throw new ApiError(403, "CAMPAIGN_SITE_SCOPE_MISMATCH");
  const now = Date.now();
  if (Date.parse(String(campaign.starts_at)) > now ||
      (campaign.ends_at && Date.parse(String(campaign.ends_at)) <= now)) {
    throw new ApiError(409, "REFERRAL_CAMPAIGN_OUT_OF_PERIOD");
  }

  const existing = await rest(query("ns_customer_referral_codes", {
    select: "id,code,status",
    org_id: "eq." + actor.orgId,
    campaign_id: "eq." + campaignId,
    customer_id: "eq." + customerId,
    limit: "1",
  })) as Json[];
  if (existing?.[0]) return { code: existing[0].code, reused: true };

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const rows = await rest("ns_customer_referral_codes", {
        method: "POST",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          org_id: actor.orgId, site_id: siteId, campaign_id: campaignId,
          customer_id: customerId, code: randomCode(), status: "active",
        }),
      }) as Json[];
      if (rows?.[0]?.code) return { code: rows[0].code, reused: false };
    } catch {
      const winner = await rest(query("ns_customer_referral_codes", {
        select: "id,code,status", org_id: "eq." + actor.orgId,
        campaign_id: "eq." + campaignId, customer_id: "eq." + customerId, limit: "1",
      })) as Json[];
      if (winner?.[0]?.code) return { code: winner[0].code, reused: true };
    }
  }
  throw new ApiError(503, "REFERRAL_CODE_CREATE_FAILED");
}

async function applyCustomerCode(actor: Actor, body: Json) {
  const siteId = String(body.site_id ?? "");
  const customerId = String(body.customer_id ?? "");
  const code = normalizeCustomerReferralCode(body.referral_code);
  if (!isUuid(customerId) || !isCustomerReferralCode(code)) throw new ApiError(400, "INVALID_REFERRAL_INPUT");
  await requireSiteOperation(actor, siteId);
  const customers = await rest(query("ns_customers", {
    select: "id", id: "eq." + customerId, org_id: "eq." + actor.orgId, site_id: "eq." + siteId, limit: "1",
  })) as Json[];
  if (!customers?.length) throw new ApiError(404, "CUSTOMER_NOT_FOUND");
  return await rpc("ns_apply_customer_referral_code", {
    p_org_id: actor.orgId, p_referred_site_id: siteId,
    p_referred_customer_id: customerId, p_code: code,
  });
}

async function createReferralCampaign(actor: Actor, body: Json) {
  requirePromoter(actor);
  const draft = normalizeCustomerReferralCampaignDraft(body, actor.orgId);
  if (draft.site_id) await requireSiteOperation(actor, draft.site_id, true);
  const rows = await rest("ns_customer_referral_campaigns", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ ...draft, status: "draft", created_by: actor.memberId }),
  }) as Json[];
  if (!rows?.[0]?.id) throw new ApiError(503, "REFERRAL_CAMPAIGN_CREATE_FAILED");
  return { id: rows[0].id, status: "draft", message: "Campagne créée en brouillon. Les récompenses ne sont pas activées." };
}

async function createWheelCampaign(actor: Actor, body: Json) {
  requirePromoter(actor);
  const title = typeof body.title === "string" ? body.title.trim() : "";
  const startsAt = typeof body.starts_at === "string" ? Date.parse(body.starts_at) : NaN;
  const endsAt = body.ends_at === null || body.ends_at === undefined || body.ends_at === ""
    ? null : (typeof body.ends_at === "string" ? Date.parse(body.ends_at) : NaN);
  const siteId = body.site_id === null || body.site_id === undefined || body.site_id === "" ? null : body.site_id;
  if (title.length < 2 || title.length > 120 || !Number.isFinite(startsAt) ||
      (endsAt !== null && (!Number.isFinite(endsAt) || endsAt <= startsAt)) ||
      (siteId !== null && !isUuid(siteId))) throw new ApiError(400, "INVALID_WHEEL_CAMPAIGN");
  if (siteId) await requireSiteOperation(actor, String(siteId), true);
  const rows = await rest("ns_promotion_campaigns", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({
      org_id: actor.orgId, site_id: siteId, title,
      campaign_type: "wheel", status: "draft",
      starts_at: new Date(startsAt).toISOString(),
      ends_at: endsAt === null ? null : new Date(endsAt).toISOString(),
      created_by: actor.memberId,
    }),
  }) as Json[];
  if (!rows?.[0]?.id) throw new ApiError(503, "WHEEL_CAMPAIGN_CREATE_FAILED");
  return { id: rows[0].id, status: "draft", activation_locked: true };
}

async function addWheelPrize(actor: Actor, body: Json) {
  requirePromoter(actor);
  const campaignId = String(body.campaign_id ?? "");
  if (!isUuid(campaignId)) throw new ApiError(400, "INVALID_CAMPAIGN_ID");
  const campaigns = await rest(query("ns_promotion_campaigns", {
    select: "id,status,org_id",
    id: "eq." + campaignId, org_id: "eq." + actor.orgId, limit: "1",
  })) as Json[];
  if (!campaigns?.[0] || !["draft", "legal_review"].includes(String(campaigns[0].status))) {
    throw new ApiError(409, "WHEEL_CAMPAIGN_LOCKED");
  }
  const prize = normalizeWheelPrizeDraft(body);
  const rows = await rest("ns_promotion_prizes", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ org_id: actor.orgId, campaign_id: campaignId, ...prize, active: true }),
  }) as Json[];
  if (!rows?.[0]?.id) throw new ApiError(503, "WHEEL_PRIZE_CREATE_FAILED");
  return { id: rows[0].id, campaign_status: campaigns[0].status };
}

async function spinWheel(actor: Actor, body: Json) {
  const campaignId = String(body.campaign_id ?? "");
  const customerId = String(body.customer_id ?? "");
  const attemptId = String(body.attempt_id ?? "");
  if (!isUuid(campaignId) || !isUuid(customerId) || !isUuid(attemptId)) {
    throw new ApiError(400, "INVALID_SPIN_INPUT");
  }
  const customers = await rest(query("ns_customers", {
    select: "id,site_id",
    id: "eq." + customerId, org_id: "eq." + actor.orgId, limit: "1",
  })) as Json[];
  if (!customers?.[0] || typeof customers[0].site_id !== "string") throw new ApiError(404, "CUSTOMER_NOT_FOUND");
  await requireSiteOperation(actor, customers[0].site_id);
  const campaigns = await rest(query("ns_promotion_campaigns", {
    select: "id,status",
    id: "eq." + campaignId, org_id: "eq." + actor.orgId,
    campaign_type: "eq.wheel", status: "eq.active", limit: "1",
  })) as Json[];
  if (!campaigns?.length) throw new ApiError(409, "WHEEL_CAMPAIGN_NOT_ACTIVE_OR_NOT_AUTHORIZED");
  return await rpc("ns_spin_promotion_wheel", {
    p_campaign_id: campaignId, p_customer_id: customerId, p_attempt_id: attemptId,
  });
}

async function customerReferralDashboard(actor: Actor) {
  requirePromoter(actor);
  const orgId = actor.orgId;
  const [campaigns, referrals, rewards] = await Promise.all([
    rest(query("ns_customer_referral_campaigns", {
      select: "id,name,status,starts_at,ends_at,beneficiary_mode,reward_kind,reward_value,minimum_paid_sale_xaf,terms_version",
      org_id: "eq." + orgId, order: "created_at.desc", limit: "200",
    })) as Promise<Json[]>,
    rest(query("ns_customer_referrals", {
      select: "id,campaign_id,referrer_customer_id,referred_customer_id,status,created_at,first_paid_at,rejection_reason",
      org_id: "eq." + orgId, order: "created_at.desc", limit: "500",
    })) as Promise<Json[]>,
    rest(query("ns_customer_referral_rewards", {
      select: "id,campaign_id,referral_id,beneficiary_customer_id,reward_kind,reward_value,status,issued_at,expires_at",
      org_id: "eq." + orgId, order: "created_at.desc", limit: "500",
    })) as Promise<Json[]>,
  ]);
  return { campaigns, referrals, rewards };
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i++) mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return mismatch === 0;
}

async function hmac(secret: string, value: string) {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const bytes = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value)));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function handleWebhook(body: Json) {
  const saleId = String(body.sale_id ?? "");
  const providerEventId = String(body.provider_event_id ?? "");
  if (!isUuid(saleId) || providerEventId.length < 6 || providerEventId.length > 200) {
    throw new ApiError(400, "INVALID_PAID_SALE_EVENT");
  }
  return await rpc("ns_record_customer_referral_first_paid_sale", {
    p_sale_id: saleId, p_provider_event_id: providerEventId,
  });
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return reply(204, {}, origin);
  if (request.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" }, origin);
  if (!SUPABASE_URL || ANON_KEY.length < 20 || SERVICE_ROLE_KEY.length < 20) {
    return reply(503, { error: "PROMOTIONS_SERVICE_NOT_CONFIGURED" }, origin);
  }

  try {
    const raw = await request.text();
    if (raw.length > 32_000) return reply(413, { error: "REQUEST_TOO_LARGE" }, origin);
    const body = JSON.parse(raw) as Json;
    if (!body || typeof body !== "object" || Array.isArray(body) || body.app_code !== "naxa-services") {
      return reply(400, { error: "INVALID_BODY_OR_APP" }, origin);
    }
    const action = String(body.action ?? "");
    if (action === "customer_sale_first_paid") {
      if (!WEBHOOK_SECRET) return reply(503, { error: "PROMOTION_WEBHOOK_NOT_CONFIGURED" }, origin);
      const signature = (request.headers.get("x-naxa-promotions-signature") ?? "").replace(/^sha256=/i, "").toLowerCase();
      const expected = await hmac(WEBHOOK_SECRET, raw);
      if (!constantTimeEqual(signature, expected)) return reply(401, { error: "INVALID_WEBHOOK_SIGNATURE" }, origin);
      return reply(200, { ok: true, result: await handleWebhook(body) }, origin);
    }

    const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim() ?? "";
    const actor = await actorContext(token);
    if (!actor) return reply(401, { error: "AUTHENTICATION_REQUIRED" }, origin);

    let result: unknown;
    switch (action) {
      case "create_customer_referral_campaign":
        result = await createReferralCampaign(actor, body);
        break;
      case "create_customer_referral_code":
        result = await createCustomerCode(actor, body);
        break;
      case "apply_customer_referral_code":
        result = await applyCustomerCode(actor, body);
        break;
      case "customer_referral_dashboard":
        result = await customerReferralDashboard(actor);
        break;
      case "create_wheel_campaign":
        result = await createWheelCampaign(actor, body);
        break;
      case "add_wheel_prize":
        result = await addWheelPrize(actor, body);
        break;
      case "spin_wheel":
        result = await spinWheel(actor, body);
        break;
      default:
        return reply(400, { error: "UNSUPPORTED_PROMOTION_ACTION" }, origin);
    }
    return reply(200, { ok: true, result }, origin);
  } catch (error) {
    if (error instanceof ApiError) return reply(error.status, { error: error.code }, origin);
    const message = error instanceof Error ? error.message : "";
    if (message === "INVALID_TEXT" || message.startsWith("INVALID_")) return reply(400, { error: message }, origin);
    return reply(503, { error: "PROMOTIONS_REQUEST_FAILED" }, origin);
  }
});
