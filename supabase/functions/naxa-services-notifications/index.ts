import {
  inboxTransition,
  normalizeNotificationPayload,
  normalizePushPlatform,
  normalizePushToken,
  retryablePushFailure,
  safeWorkerLimit,
  shouldRevokePushToken,
} from "./notification_contract.ts";

const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const TOKEN_ENCRYPTION_KEY = Deno.env.get("NS_PUSH_TOKEN_ENCRYPTION_KEY") ?? "";
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";
const WORKER_SECRET = Deno.env.get("NS_NOTIFICATION_WORKER_SECRET") ?? "";
const ALLOWED_ORIGINS = (Deno.env.get("NS_ALLOWED_ORIGINS") ?? "").split(",").map((x) => x.trim()).filter(Boolean);
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const FCM_TOKEN_URL = "https://oauth2.googleapis.com/token";

type Json = Record<string, unknown>;
type Actor = { authUserId: string; accountId: string; memberId: string; orgId: string; roleCode: string; deviceId: string; sessionId: string };
type ClaimedNotification = {
  id: string; org_id: string; site_id: string | null; recipient_member_id: string | null;
  event_code: string; idempotency_key: string; payload_redacted: Json; attempts: number; claim_token: string;
};
type ServiceAccount = { project_id: string; client_email: string; private_key: string; token_uri?: string };

class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}

function reply(status: number, body: Json, origin?: string | null) {
  const allow = origin && (ALLOWED_ORIGINS.includes(origin) || ALLOWED_ORIGINS.includes("*")) ? origin : "null";
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": allow,
      "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-naxa-notification-worker-secret",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });
}

function serviceHeaders(extra: Record<string, string> = {}) {
  return { apikey: SERVICE_ROLE_KEY, Authorization: "Bearer " + SERVICE_ROLE_KEY, "Content-Type": "application/json", ...extra };
}

function pathQuery(path: string, query: Record<string, string>) {
  return path + "?" + new URLSearchParams(query).toString();
}

async function rest(path: string, init: RequestInit = {}): Promise<unknown> {
  const response = await fetch(SUPABASE_URL + "/rest/v1/" + path, {
    ...init,
    headers: { ...serviceHeaders(), ...(init.headers as Record<string, string> ?? {}) },
  });
  const raw = await response.text();
  let data: unknown = null;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = null; }
  if (!response.ok) throw new ApiError(response.status >= 500 ? 503 : 422, "NOTIFICATION_DATABASE_ERROR");
  return data;
}

async function rpc(name: string, args: Json): Promise<unknown> {
  return await rest("rpc/" + name, { method: "POST", body: JSON.stringify(args) });
}

function decodeJwtPayload(token: string): Json | null {
  const pieces = token.split(".");
  if (pieces.length !== 3) return null;
  try {
    const encoded = pieces[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "="))) as Json;
  } catch { return null; }
}

async function actorContext(token: string): Promise<Actor | null> {
  if (!token) return null;
  const claims = decodeJwtPayload(token);
  const sessionId = typeof claims?.session_id === "string" ? claims.session_id : "";
  if (!sessionId) return null;
  const userResponse = await fetch(SUPABASE_URL + "/auth/v1/user", {
    headers: { apikey: ANON_KEY, Authorization: "Bearer " + token },
  });
  if (!userResponse.ok) return null;
  const user = await userResponse.json().catch(() => null) as Json | null;
  if (!user || typeof user.id !== "string") return null;

  const accounts = await rest(pathQuery("ns_accounts", {
    select: "id,status", auth_user_id: "eq." + user.id, limit: "1",
  })) as Json[];
  const account = accounts?.[0];
  if (!account || account.status !== "active" || typeof account.id !== "string") return null;

  const devices = await rest(pathQuery("ns_devices", {
    select: "id", account_id: "eq." + account.id,
    session_id: "eq." + sessionId, revoked_at: "is.null", limit: "1",
  })) as Json[];
  if (!devices?.[0] || typeof devices[0].id !== "string") return null;

  const members = await rest(pathQuery("ns_members", {
    select: "id,org_id,role_code,status", account_id: "eq." + account.id,
    status: "eq.active", limit: "2",
  })) as Json[];
  if (!members || members.length !== 1) return null;
  const member = members[0];
  if (typeof member.id !== "string" || typeof member.org_id !== "string" || typeof member.role_code !== "string") return null;
  const orgs = await rest(pathQuery("ns_organizations", {
    select: "id,status", id: "eq." + member.org_id, status: "eq.active", limit: "1",
  })) as Json[];
  if (!orgs?.length) return null;

  return {
    authUserId: user.id, accountId: account.id, memberId: member.id,
    orgId: member.org_id, roleCode: member.role_code, deviceId: devices[0].id, sessionId,
  };
}

function hexBytes(value: string): Uint8Array {
  const hex = value.trim().replace(/^0x/i, "");
  if (!/^[0-9a-f]{64}$/i.test(hex)) throw new ApiError(503, "PUSH_TOKEN_ENCRYPTION_NOT_CONFIGURED");
  return Uint8Array.from(hex.match(/.{2}/g)!, (part) => parseInt(part, 16));
}

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}

function toArrayBuffer(value: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(value.byteLength);
  copy.set(value);
  return copy.buffer;
}

async function digestHex(value: string) {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  return Array.from(bytes, (part) => part.toString(16).padStart(2, "0")).join("");
}

async function encryptPushToken(token: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey("raw", toArrayBuffer(hexBytes(TOKEN_ENCRYPTION_KEY)), { name: "AES-GCM" }, false, ["encrypt"]);
  const ciphertext = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: toArrayBuffer(iv) }, key, toArrayBuffer(new TextEncoder().encode(token))));
  return { token_ciphertext: base64(ciphertext), token_iv: base64(iv), token_fingerprint: await digestHex(token), token_tail: token.slice(-4) };
}

async function decryptPushToken(ciphertext: string, ivText: string) {
  const key = await crypto.subtle.importKey("raw", toArrayBuffer(hexBytes(TOKEN_ENCRYPTION_KEY)), { name: "AES-GCM" }, false, ["decrypt"]);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: toArrayBuffer(fromBase64(ivText)) }, key, toArrayBuffer(fromBase64(ciphertext)));
  return new TextDecoder().decode(plain);
}

async function registerToken(actor: Actor, body: Json) {
  const token = normalizePushToken(body.token);
  const platform = normalizePushPlatform(body.platform);
  const encrypted = await encryptPushToken(token);
  const existing = await rest(pathQuery("ns_push_tokens", {
    select: "id", org_id: "eq." + actor.orgId,
    token_fingerprint: "eq." + encrypted.token_fingerprint, limit: "1",
  })) as Json[];
  const values = {
    org_id: actor.orgId, member_id: actor.memberId, device_id: actor.deviceId, platform,
    ...encrypted, status: "active", revoked_at: null, last_seen_at: new Date().toISOString(),
  };
  if (existing?.[0]?.id) {
    await rest(pathQuery("ns_push_tokens", { id: "eq." + existing[0].id, org_id: "eq." + actor.orgId }), {
      method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify(values),
    });
  } else {
    await rest("ns_push_tokens", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify(values) });
  }
  return { registered: true, platform, token_tail: encrypted.token_tail };
}

async function revokeToken(actor: Actor, body: Json) {
  const id = typeof body.id === "string" ? body.id : "";
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw new ApiError(400, "INVALID_PUSH_TOKEN_ID");
  const rows = await rest(pathQuery("ns_push_tokens", {
    select: "id", id: "eq." + id, org_id: "eq." + actor.orgId,
    member_id: "eq." + actor.memberId, device_id: "eq." + actor.deviceId, limit: "1",
  })) as Json[];
  if (!rows?.length) throw new ApiError(404, "PUSH_TOKEN_NOT_FOUND");
  await rest(pathQuery("ns_push_tokens", { id: "eq." + id, org_id: "eq." + actor.orgId }), {
    method: "PATCH", headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ status: "revoked", revoked_at: new Date().toISOString() }),
  });
  return { revoked: true };
}

async function listInbox(actor: Actor, body: Json) {
  const limit = Math.max(1, Math.min(100, Number.isInteger(body.limit) ? Number(body.limit) : 30));
  const rows = await rest(pathQuery("ns_notification_inbox", {
    select: "id,event_code,payload_redacted,status,sent_at,read_at,actioned_at",
    org_id: "eq." + actor.orgId, member_id: "eq." + actor.memberId,
    order: "sent_at.desc", limit: String(limit),
  })) as Json[];
  return rows ?? [];
}

async function acknowledgeInbox(actor: Actor, body: Json) {
  const id = typeof body.id === "string" ? body.id : "";
  const next = body.status === "actioned" ? "actioned" : body.status === "read" ? "read" : "";
  if (!/^[0-9a-f-]{36}$/i.test(id) || !next) throw new ApiError(400, "INVALID_INBOX_ACKNOWLEDGEMENT");
  const rows = await rest(pathQuery("ns_notification_inbox", {
    select: "id,status", id: "eq." + id, org_id: "eq." + actor.orgId,
    member_id: "eq." + actor.memberId, limit: "1",
  })) as Json[];
  if (!rows?.[0]) throw new ApiError(404, "NOTIFICATION_NOT_FOUND");
  const existing = String(rows[0].status);
  const state = inboxTransition(existing as "sent" | "read" | "actioned", next);
  const now = new Date().toISOString();
  const patch: Json = { status: state };
  if (state === "read" && existing === "sent") patch.read_at = now;
  if (state === "actioned") {
    patch.read_at = now;
    patch.actioned_at = now;
  }
  await rest(pathQuery("ns_notification_inbox", {
    id: "eq." + id, org_id: "eq." + actor.orgId, member_id: "eq." + actor.memberId,
  }), { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify(patch) });
  return { id, status: state };
}

function b64Url(value: string | Uint8Array) {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  return base64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemBytes(pem: string) {
  const raw = pem.replace(/\\n/g, "\n").replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  return fromBase64(raw);
}

async function loadServiceAccount(): Promise<ServiceAccount> {
  let account: ServiceAccount;
  try { account = JSON.parse(FCM_SERVICE_ACCOUNT_JSON) as ServiceAccount; }
  catch { throw new ApiError(503, "FCM_CREDENTIALS_NOT_CONFIGURED"); }
  if (!account.project_id || !account.client_email || !account.private_key) {
    throw new ApiError(503, "FCM_CREDENTIALS_NOT_CONFIGURED");
  }
  return account;
}

async function fcmAccessToken(account: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64Url(JSON.stringify({
    iss: account.client_email, scope: FCM_SCOPE,
    aud: account.token_uri || FCM_TOKEN_URL, iat: now, exp: now + 3600,
  }));
  const unsigned = header + "." + payload;
  const key = await crypto.subtle.importKey(
    "pkcs8", toArrayBuffer(pemBytes(account.private_key)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const assertion = unsigned + "." + b64Url(signature);
  const response = await fetch(account.token_uri || FCM_TOKEN_URL, {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion,
    }),
  });
  const data = await response.json().catch(() => null) as Json | null;
  if (!response.ok || typeof data?.access_token !== "string") throw new ApiError(503, "FCM_AUTH_TEMPORARY");
  return { accessToken: data.access_token, projectId: account.project_id };
}

async function sendFcm(accessToken: string, projectId: string, token: string, eventCode: string, notificationId: string, payload: Json) {
  const safe = normalizeNotificationPayload(payload);
  const data: Record<string, string> = {
    event_code: eventCode.slice(0, 80),
    notification_id: notificationId,
  };
  if (safe.route) data.route = safe.route;
  const response = await fetch("https://fcm.googleapis.com/v1/projects/" + encodeURIComponent(projectId) + "/messages:send", {
    method: "POST",
    headers: { Authorization: "Bearer " + accessToken, "Content-Type": "application/json" },
    body: JSON.stringify({ message: { token, notification: { title: safe.title, body: safe.body }, data } }),
  });
  const result = await response.json().catch(() => null) as Json | null;
  if (!response.ok) {
    const details = Array.isArray((result?.error as Json | undefined)?.details)
      ? (result!.error as Json).details as Json[] : [];
    const fcmCode = details.find((detail) => typeof detail.errorCode === "string")?.errorCode;
    const code = typeof fcmCode === "string" ? fcmCode : response.status >= 500 || response.status === 429
      ? "FCM_TEMPORARY_UNAVAILABLE" : "FCM_REJECTED";
    throw new ApiError(502, code);
  }
  return typeof result?.name === "string" ? result.name : "fcm-accepted";
}

async function revokeProviderToken(id: string, orgId: string) {
  await rest(pathQuery("ns_push_tokens", { id: "eq." + id, org_id: "eq." + orgId }), {
    method: "PATCH", headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ status: "revoked", revoked_at: new Date().toISOString() }),
  });
}

async function dispatchBatch(limit: number) {
  const account = await loadServiceAccount();
  const { accessToken, projectId } = await fcmAccessToken(account);
  const claims = await rpc("ns_claim_notification_batch", { p_limit: limit }) as ClaimedNotification[];
  const result = { claimed: claims?.length ?? 0, sent: 0, retried: 0, failed: 0 };
  for (const item of claims ?? []) {
    try {
      if (!item.recipient_member_id) throw new ApiError(422, "NO_MEMBER_RECIPIENT");
      const tokens = await rest(pathQuery("ns_push_tokens", {
        select: "id,token_ciphertext,token_iv",
        org_id: "eq." + item.org_id, member_id: "eq." + item.recipient_member_id,
        status: "eq.active", order: "last_seen_at.desc", limit: "20",
      })) as Json[];
      if (!tokens?.length) throw new ApiError(503, "NO_ACTIVE_PUSH_TOKEN");
      let acceptedReference = "";
      let lastError = "FCM_REJECTED";
      for (const tokenRow of tokens) {
        try {
          const token = await decryptPushToken(String(tokenRow.token_ciphertext), String(tokenRow.token_iv));
          acceptedReference = await sendFcm(accessToken, projectId, token, item.event_code, item.id, item.payload_redacted ?? {});
          break;
        } catch (error) {
          const code = error instanceof ApiError ? error.code : "FCM_TEMPORARY_UNAVAILABLE";
          lastError = code;
          if (shouldRevokePushToken(code) && typeof tokenRow.id === "string") {
            await revokeProviderToken(tokenRow.id, item.org_id);
            continue;
          }
          if (!retryablePushFailure(code)) continue;
        }
      }
      if (acceptedReference) {
        const completed = await rpc("ns_finish_notification_send", {
          p_notification_id: item.id, p_claim_token: item.claim_token,
          p_provider_reference: acceptedReference,
        }) as boolean;
        if (completed) result.sent++;
        else result.failed++;
      } else {
        const status = await rpc("ns_fail_notification_send", {
          p_notification_id: item.id, p_claim_token: item.claim_token,
          p_error_code: lastError, p_retryable: retryablePushFailure(lastError),
        }) as string;
        if (status === "pending") result.retried++;
        else result.failed++;
      }
    } catch (error) {
      const code = error instanceof ApiError ? error.code : "FCM_TEMPORARY_UNAVAILABLE";
      const status = await rpc("ns_fail_notification_send", {
        p_notification_id: item.id, p_claim_token: item.claim_token,
        p_error_code: code, p_retryable: retryablePushFailure(code),
      }) as string;
      if (status === "pending") result.retried++;
      else result.failed++;
    }
  }
  return result;
}

function constantTimeEqual(left: string, right: string) {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i++) mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return mismatch === 0;
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return reply(204, {}, origin);
  if (request.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" }, origin);
  if (!SUPABASE_URL || ANON_KEY.length < 20 || SERVICE_ROLE_KEY.length < 20) {
    return reply(503, { error: "NOTIFICATIONS_SERVICE_NOT_CONFIGURED" }, origin);
  }

  try {
    const raw = await request.text();
    if (raw.length > 20_000) return reply(413, { error: "REQUEST_TOO_LARGE" }, origin);
    const body = JSON.parse(raw) as Json;
    if (!body || typeof body !== "object" || Array.isArray(body) || body.app_code !== "naxa-services") {
      return reply(400, { error: "INVALID_BODY_OR_APP" }, origin);
    }
    const action = String(body.action ?? "");
    if (action === "dispatch") {
      if (!WORKER_SECRET || !constantTimeEqual(
        request.headers.get("x-naxa-notification-worker-secret") ?? "",
        WORKER_SECRET,
      )) return reply(401, { error: "WORKER_AUTHENTICATION_FAILED" }, origin);
      const limit = safeWorkerLimit(body.limit);
      return reply(200, { ok: true, result: await dispatchBatch(limit) }, origin);
    }

    const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim() ?? "";
    const actor = await actorContext(token);
    if (!actor) return reply(401, { error: "AUTHENTICATION_REQUIRED" }, origin);

    let result: unknown;
    switch (action) {
      case "register_push_token":
        result = await registerToken(actor, body);
        break;
      case "revoke_push_token":
        result = await revokeToken(actor, body);
        break;
      case "list_inbox":
        result = await listInbox(actor, body);
        break;
      case "acknowledge_inbox":
        result = await acknowledgeInbox(actor, body);
        break;
      default:
        return reply(400, { error: "UNSUPPORTED_NOTIFICATION_ACTION" }, origin);
    }
    return reply(200, { ok: true, result }, origin);
  } catch (error) {
    if (error instanceof ApiError) return reply(error.status, { error: error.code }, origin);
    const message = error instanceof Error ? error.message : "";
    if (message.startsWith("INVALID_")) return reply(400, { error: message }, origin);
    return reply(503, { error: "NOTIFICATIONS_REQUEST_FAILED" }, origin);
  }
});
