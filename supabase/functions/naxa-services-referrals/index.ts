import { hasActiveDeviceSession } from "../_shared/naxa-services-device-session.ts";
import { isValidReferralCode, normalizeReferralCode } from "./referral_contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("NS_REFERRAL_WEBHOOK_SECRET") ?? "";
const ALLOWED_ORIGINS = (Deno.env.get("NS_ALLOWED_ORIGINS") ?? "").split(",").map((value) => value.trim()).filter(Boolean);

function json(status: number, body: Record<string, unknown>, origin?: string | null) {
  const allowed = origin && (ALLOWED_ORIGINS.includes(origin) || ALLOWED_ORIGINS.includes("*")) ? origin : "null";
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": allowed,
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-naxa-referral-signature",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });
}
function serviceHeaders(extra: Record<string, string> = {}) {
  return { apikey: SERVICE_ROLE_KEY, Authorization: "Bearer " + SERVICE_ROLE_KEY, "Content-Type": "application/json", ...extra };
}
async function rest(path: string, init: RequestInit = {}) {
  const headers = { ...serviceHeaders(), ...(init.headers as Record<string, string> ?? {}) };
  const response = await fetch(SUPABASE_URL + "/rest/v1/" + path, { ...init, headers });
  const text = await response.text();
  let payload: unknown = null;
  try { payload = text ? JSON.parse(text) : null; } catch { payload = null; }
  if (!response.ok) throw new Error("REFERRAL_DB_" + response.status);
  return payload;
}
async function actorContext(token: string) {
  if (!token) return null;
  const authResponse = await fetch(SUPABASE_URL + "/auth/v1/user", {
    headers: { apikey: ANON_KEY, Authorization: "Bearer " + token },
  });
  if (!authResponse.ok) return null;
  const auth = await authResponse.json() as Record<string, unknown>;
  if (!auth.id) return null;
  const accounts = await rest("ns_accounts?select=id,status,password_change_required&auth_user_id=eq." + encodeURIComponent(String(auth.id)) + "&limit=1") as Record<string, unknown>[];
  const account = accounts?.[0];
  if (!account || account.status !== "active" || account.password_change_required !== false) return null;
  if (!await hasActiveDeviceSession(token, String(account.id), path => rest(path))) return null;
  const members = await rest("ns_members?select=id,org_id,display_name,role_code,status&account_id=eq." + encodeURIComponent(String(account.id)) + "&status=eq.active&limit=2") as Record<string, unknown>[];
  if (!members || members.length !== 1) return null;
  const member = members[0];
  const organizations = await rest("ns_organizations?select=id,display_name,status&id=eq." + encodeURIComponent(String(member.org_id)) + "&limit=1") as Record<string, unknown>[];
  const organization = organizations?.[0];
  if (!organization || organization.status !== "active") return null;
  return { authUserId: String(auth.id), account, member, organization };
}
type Actor = NonNullable<Awaited<ReturnType<typeof actorContext>>>;
function isPromoter(actor: Actor) { return String(actor.member.role_code) === "promoter"; }
function generateCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(7));
  return "NS-" + Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
}
async function activeCode(orgId: string) {
  const rows = await rest("ns_referral_codes?select=id,org_id,code,status&org_id=eq." + encodeURIComponent(orgId) + "&status=eq.active&limit=1") as Record<string, unknown>[];
  return rows?.[0] ?? null;
}
async function createCode(actor: Actor) {
  if (!isPromoter(actor)) return { status: 403, body: { message: "Seul le Promoteur peut générer le code de l’organisation." } };
  const existing = await activeCode(String(actor.member.org_id));
  if (existing) return { status: 200, body: { code: existing.code, reused: true } };
  const code = generateCode();
  try {
    const rows = await rest("ns_referral_codes", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ org_id: actor.member.org_id, code, status: "active", created_by_member: actor.member.id }),
    }) as Record<string, unknown>[];
    const saved = rows?.[0];
    if (!saved?.code) throw new Error("REFERRAL_CODE_NOT_RETURNED");
    return { status: 200, body: { code: saved.code, reused: false } };
  } catch {
    const winner = await activeCode(String(actor.member.org_id));
    if (winner) return { status: 200, body: { code: winner.code, reused: true } };
    throw new Error("REFERRAL_CODE_CREATE_FAILED");
  }
}
async function applyCode(actor: Actor, rawCode: string) {
  if (!isPromoter(actor)) return { status: 403, body: { message: "Seul le Promoteur peut enregistrer un code pour la PME." } };
  const code = normalizeReferralCode(rawCode);
  if (!isValidReferralCode(code)) return { status: 400, body: { message: "Format de code de parrainage invalide." } };
  const codes = await rest("ns_referral_codes?select=id,org_id,code&code=eq." + encodeURIComponent(code) + "&status=eq.active&limit=1") as Record<string, unknown>[];
  const selected = codes?.[0];
  if (!selected) return { status: 404, body: { message: "Code de parrainage introuvable ou révoqué." } };
  if (String(selected.org_id) === String(actor.member.org_id)) return { status: 409, body: { message: "Une PME ne peut pas se parrainer elle-même." } };
  const previous = await rest("ns_referrals?select=id,status&referred_org_id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&limit=1") as Record<string, unknown>[];
  if (previous?.length) return { status: 409, body: { message: "Un code a déjà été associé à cette PME. Le parrainage est non transférable." } };
  const rows = await rest("ns_referrals", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({
      referrer_org_id: selected.org_id,
      referred_org_id: actor.member.org_id,
      referral_code_id: selected.id,
      referred_org_name_snapshot: actor.organization.display_name,
      status: "pending",
    }),
  }) as Record<string, unknown>[];
  if (!rows?.[0]?.id) throw new Error("REFERRAL_LINK_NOT_CREATED");
  return { status: 200, body: { linked: true, message: "Code associé. L’activation sera comptée après le premier abonnement payé confirmé." } };
}
async function dashboard(actor: Actor) {
  if (!isPromoter(actor)) return { status: 403, body: { message: "La consultation du parrainage est réservée au Promoteur." } };
  const orgId = String(actor.member.org_id);
  const [code, referrals, rewards] = await Promise.all([
    activeCode(orgId),
    rest("ns_referrals?select=id,referred_org_name_snapshot,status,created_at,first_subscription_paid_at,referrer_plan_cadence&referrer_org_id=eq." + encodeURIComponent(orgId) + "&order=created_at.desc&limit=1000") as Promise<Record<string, unknown>[]>,
    rest("ns_referral_rewards?select=id,wave_number,reward_kind,subscription_cadence,status,created_at,applied_at&org_id=eq." + encodeURIComponent(orgId) + "&order=wave_number.asc") as Promise<Record<string, unknown>[]>,
  ]);
  const activatedCount = referrals.filter((row) => row.status === "qualified").length;
  return {
    status: 200,
    body: {
      code: code?.code ?? null,
      counts: {
        referred_count: referrals.length,
        activated_count: activatedCount,
        progress_in_current_wave: activatedCount % 5,
        next_wave_number: Math.floor(activatedCount / 5) + 1,
      },
      referrals: referrals.map((row) => ({
        organization_name: row.referred_org_name_snapshot,
        status: row.status,
        created_at: row.created_at,
        first_subscription_paid_at: row.first_subscription_paid_at,
        referrer_plan_cadence: row.referrer_plan_cadence,
      })),
      rewards,
    },
  };
}
function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return diff === 0;
}
async function hmacSha256Hex(secret: string, value: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value)));
  return Array.from(signature, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
async function recordFirstPaidSubscription(body: Record<string, unknown>) {
  if (!WEBHOOK_SECRET) return { status: 503, body: { message: "Secret du webhook de parrainage non configuré." } };
  const referredOrgId = String(body.referred_org_id ?? "");
  const providerEventId = String(body.provider_event_id ?? "");
  const subscriptionId = String(body.subscription_id ?? "");
  const paidAt = String(body.paid_at ?? "");
  const cadence = String(body.referrer_plan_cadence ?? "");
  if (body.is_first_paid_subscription !== true || !referredOrgId || !providerEventId || !subscriptionId || !paidAt || !["monthly", "annual"].includes(cadence)) {
    return { status: 400, body: { message: "Événement de première souscription incomplet ou non qualifié." } };
  }
  const result = await rest("rpc/ns_record_referral_first_subscription", {
    method: "POST",
    body: JSON.stringify({
      p_referred_org_id: referredOrgId,
      p_provider_event_id: providerEventId,
      p_subscription_id: subscriptionId,
      p_paid_at: paidAt,
      p_referrer_plan_cadence: cadence,
    }),
  });
  return { status: 200, body: { result } };
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": origin && (ALLOWED_ORIGINS.includes(origin) || ALLOWED_ORIGINS.includes("*")) ? origin : "null",
        "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-naxa-referral-signature",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Vary": "Origin",
      },
    });
  }
  if (request.method !== "POST") return json(405, { message: "Méthode non autorisée." }, origin);
  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE_KEY) return json(503, { message: "Service de parrainage non configuré côté serveur." }, origin);
  try {
    const rawBody = await request.text();
    const body = JSON.parse(rawBody) as Record<string, unknown>;
    if (body.app_code !== "naxa-services") return json(400, { message: "Application non autorisée." }, origin);
    const action = String(body.action ?? "");
    if (action === "subscription_first_paid") {
      if (!WEBHOOK_SECRET) return json(503, { message: "Webhook de facturation non raccordé." }, origin);
      const supplied = (request.headers.get("x-naxa-referral-signature") ?? "").replace(/^sha256=/, "").toLowerCase();
      const expected = await hmacSha256Hex(WEBHOOK_SECRET, rawBody);
      if (!constantTimeEqual(supplied, expected)) return json(401, { message: "Signature du webhook invalide." }, origin);
      const result = await recordFirstPaidSubscription(body);
      return json(result.status, result.body, origin);
    }
    const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    const actor = await actorContext(token);
    if (!actor) return json(401, { message: "Session expirée." }, origin);
    let result;
    if (action === "dashboard") result = await dashboard(actor);
    else if (action === "create_code") result = await createCode(actor);
    else if (action === "apply_code") result = await applyCode(actor, String(body.referral_code ?? ""));
    else result = { status: 400, body: { message: "Action non reconnue." } };
    return json(result.status, result.body, origin);
  } catch (_error) {
    return json(503, { message: "Service momentanément indisponible. Réessaie plus tard." }, origin);
  }
});
