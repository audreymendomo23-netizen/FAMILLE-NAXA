// NAXA SERVICES authentication gateway — source only, NOT deployed.
// Required server-side secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
// Never set SUPABASE_SERVICE_ROLE_KEY in Android/Web build variables.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ALLOWED_ORIGINS = (Deno.env.get("NS_ALLOWED_ORIGINS") ?? "").split(",").map((s) => s.trim()).filter(Boolean);

const jsonHeaders = { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" };

function response(status: number, body: Record<string, unknown>, origin?: string | null) {
  const corsOrigin = origin && (ALLOWED_ORIGINS.includes(origin) || ALLOWED_ORIGINS.includes("*")) ? origin : "null";
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...jsonHeaders,
      "Access-Control-Allow-Origin": corsOrigin,
      "Access-Control-Allow-Headers": "authorization, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });
}

function serviceHeaders(extra: Record<string, string> = {}) {
  return { apikey: SERVICE_ROLE_KEY, Authorization: "Bearer " + SERVICE_ROLE_KEY, "Content-Type": "application/json", ...extra };
}
function anonHeaders(extra: Record<string, string> = {}) {
  return { apikey: ANON_KEY, Authorization: "Bearer " + ANON_KEY, "Content-Type": "application/json", ...extra };
}
async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function rest(path: string, init: RequestInit = {}) {
  const res = await fetch(SUPABASE_URL + "/rest/v1/" + path, init);
  const text = await res.text();
  let data: unknown = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = null; }
  if (!res.ok) throw new Error("REST_" + res.status);
  return data;
}
async function authCall(path: string, init: RequestInit = {}, userToken?: string) {
  const headers = userToken
    ? { ...anonHeaders(), Authorization: "Bearer " + userToken, ...(init.headers as Record<string, string> ?? {}) }
    : anonHeaders(init.headers as Record<string, string> ?? {});
  const res = await fetch(SUPABASE_URL + "/auth/v1/" + path, { ...init, headers });
  const text = await res.text();
  let data: Record<string, unknown> = {};
  try { data = text ? JSON.parse(text) : {}; } catch { data = {}; }
  return { ok: res.ok, status: res.status, data };
}
async function accountByLoginId(loginId: string) {
  const q = "ns_accounts?select=id,auth_user_id,auth_alias,status,password_change_required&login_id=eq." + encodeURIComponent(loginId) + "&limit=1";
  const rows = await rest(q, { headers: serviceHeaders() }) as Record<string, unknown>[];
  return rows?.[0] ?? null;
}
async function accountByAuthUser(authUserId: string) {
  const q = "ns_accounts?select=id,auth_user_id,login_id,status,password_change_required&auth_user_id=eq." + encodeURIComponent(authUserId) + "&limit=1";
  const rows = await rest(q, { headers: serviceHeaders() }) as Record<string, unknown>[];
  return rows?.[0] ?? null;
}
async function activeMember(accountId: string) {
  const q = "ns_members?select=id,org_id,display_name,role_code,status&account_id=eq." + encodeURIComponent(accountId) + "&status=eq.active&limit=2";
  const rows = await rest(q, { headers: serviceHeaders() }) as Record<string, unknown>[];
  if (!rows || rows.length !== 1) return null;
  return rows[0];
}
async function activeSiteIds(memberId: string, orgId: string) {
  const q = "ns_member_scopes?select=scope_type,site_id,scope_id&member_id=eq." + encodeURIComponent(memberId) + "&org_id=eq." + encodeURIComponent(orgId) + "&can_read=eq.true";
  const rows = await rest(q, { headers: serviceHeaders() }) as Record<string, unknown>[];
  return [...new Set((rows ?? []).flatMap((row) => row.site_id ? [String(row.site_id)] : []))];
}
async function sessionPayload(authData: Record<string, unknown>, account: Record<string, unknown>) {
  if (account.status !== "active") throw new Error("ACCOUNT_NOT_ACTIVE");
  const member = await activeMember(String(account.id));
  if (!member) throw new Error("MEMBER_SCOPE_INVALID");
  const sites = await activeSiteIds(String(member.id), String(member.org_id));
  return {
    access_token: authData.access_token,
    refresh_token: authData.refresh_token,
    expires_in: authData.expires_in ?? 3600,
    token_type: authData.token_type ?? "bearer",
    require_password_change: account.password_change_required === true,
    account: {
      member_id: member.id,
      display_name: member.display_name,
      role_code: member.role_code,
      organization_id: member.org_id,
      active_site_ids: sites,
    },
  };
}
async function recordAttempt(loginHash: string, ipHash: string, succeeded: boolean) {
  await rest("rpc/ns_auth_record_attempt", {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({ p_login_hash: loginHash, p_ip_hash: ipHash, p_succeeded: succeeded }),
  });
}
async function isLimited(loginHash: string, ipHash: string) {
  const data = await rest("rpc/ns_auth_is_limited", {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({ p_login_hash: loginHash, p_ip_hash: ipHash }),
  });
  return data === true;
}
async function touchDevice(accountId: string, device: Record<string, unknown>, remember: boolean) {
  const installationId = String(device.installation_id ?? "");
  if (!installationId || installationId.length > 160) return;
  await rest("ns_devices?on_conflict=account_id,installation_id", {
    method: "POST",
    headers: serviceHeaders({ Prefer: "resolution=merge-duplicates,return=minimal" }),
    body: JSON.stringify({
      account_id: accountId,
      installation_id: installationId,
      platform: device.platform === "web" ? "web" : "android",
      label: String(device.label ?? "").slice(0, 90),
      remember_device: remember,
      last_seen_at: new Date().toISOString(),
      revoked_at: null,
    }),
  });
}

async function login(body: Record<string, unknown>, request: Request) {
  const identifier = String(body.identifier ?? "").trim().toUpperCase();
  const password = String(body.password ?? "");
  if (!/^NS-[A-Z0-9]{4,12}$/.test(identifier) || password.length < 1 || password.length > 256) {
    return { status: 401, body: { message: "Identifiant ou mot de passe incorrect." } };
  }
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const loginHash = await sha256("naxa-services:" + identifier);
  const ipHash = await sha256("naxa-services-ip:" + ip);
  if (await isLimited(loginHash, ipHash)) return { status: 429, body: { message: "Trop de tentatives. Réessaie plus tard ou contacte ton responsable." } };

  const account = await accountByLoginId(identifier);
  if (!account || account.status !== "active") {
    await recordAttempt(loginHash, ipHash, false);
    return { status: 401, body: { message: "Identifiant ou mot de passe incorrect." } };
  }

  // Internal alias is only a technical Auth identifier. No mail is sent here.
  const auth = await authCall("token?grant_type=password", {
    method: "POST",
    body: JSON.stringify({ email: account.auth_alias, password }),
  });
  if (!auth.ok) {
    await recordAttempt(loginHash, ipHash, false);
    return { status: 401, body: { message: "Identifiant ou mot de passe incorrect." } };
  }
  await recordAttempt(loginHash, ipHash, true);
  await rest("ns_accounts?id=eq." + encodeURIComponent(String(account.id)), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({ last_login_at: new Date().toISOString() }),
  });
  await touchDevice(String(account.id), (body.device as Record<string, unknown>) ?? {}, body.remember_device === true);
  return { status: 200, body: await sessionPayload(auth.data, account) };
}

async function refreshSession(body: Record<string, unknown>, device: Record<string, unknown>) {
  const refreshToken = String(body.refresh_token ?? "");
  if (!refreshToken) return { status: 401, body: { message: "Session expirée." } };
  const auth = await authCall("token?grant_type=refresh_token", { method: "POST", body: JSON.stringify({ refresh_token: refreshToken }) });
  if (!auth.ok) return { status: 401, body: { message: "Session expirée. Connecte-toi à nouveau." } };
  const userId = String((auth.data.user as Record<string, unknown> | undefined)?.id ?? "");
  const account = await accountByAuthUser(userId);
  if (!account || account.status !== "active") return { status: 403, body: { message: "Accès suspendu." } };
  await touchDevice(String(account.id), device, true);
  return { status: 200, body: await sessionPayload(auth.data, account) };
}

async function requestRecovery(body: Record<string, unknown>) {
  const identifier = String(body.identifier ?? "").trim().toUpperCase();
  if (/^NS-[A-Z0-9]{4,12}$/.test(identifier)) {
    const account = await accountByLoginId(identifier);
    const loginHash = await sha256("naxa-services-recovery:" + identifier);
    if (account) {
      await rest("ns_auth_recovery_requests", {
        method: "POST",
        headers: serviceHeaders({ Prefer: "return=minimal" }),
        body: JSON.stringify({
          account_id: account.id,
          login_hint_hash: loginHash,
          request_note: String(body.request_note ?? "").slice(0, 500),
          status: "pending",
        }),
      });
    }
  }
  return { status: 200, body: { accepted: true, message: "Demande reçue si le compte peut être retrouvé. Le responsable effectuera le contrôle d'identité." } };
}

async function changePassword(body: Record<string, unknown>, token: string) {
  const currentPassword = String(body.current_password ?? "");
  const newPassword = String(body.new_password ?? "");
  if (newPassword.length < 10 || newPassword.length > 256 || !currentPassword) {
    return { status: 400, body: { message: "Le nouveau mot de passe doit contenir au moins 10 caractères." } };
  }
  const user = await authCall("user", { method: "GET" }, token);
  if (!user.ok || !user.data.id) return { status: 401, body: { message: "Session expirée." } };
  const account = await accountByAuthUser(String(user.data.id));
  if (!account || account.status !== "active") return { status: 403, body: { message: "Accès suspendu." } };

  // Re-check the current/temporary password without revealing the technical alias.
  const aliasRows = await rest("ns_accounts?select=auth_alias&id=eq." + encodeURIComponent(String(account.id)) + "&limit=1", { headers: serviceHeaders() }) as Record<string, unknown>[];
  const alias = String(aliasRows?.[0]?.auth_alias ?? "");
  const verified = await authCall("token?grant_type=password", { method: "POST", body: JSON.stringify({ email: alias, password: currentPassword }) });
  if (!verified.ok) return { status: 400, body: { message: "Le mot de passe actuel est incorrect." } };

  const updated = await authCall("user", { method: "PUT", body: JSON.stringify({ password: newPassword }) }, token);
  if (!updated.ok) return { status: 400, body: { message: "Le mot de passe n'a pas pu être modifié." } };
  await rest("ns_accounts?id=eq." + encodeURIComponent(String(account.id)), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({ password_change_required: false }),
  });
  return {
    status: 200,
    body: {
      access_token: token,
      refresh_token: body.refresh_token,
      expires_in: 1800,
      token_type: "bearer",
      require_password_change: false,
      account: await accountSummary(account),
    },
  };
}

async function accountSummary(account: Record<string, unknown>) {
  const member = await activeMember(String(account.id));
  if (!member) throw new Error("MEMBER_SCOPE_INVALID");
  return {
    member_id: member.id,
    display_name: member.display_name,
    role_code: member.role_code,
    organization_id: member.org_id,
    active_site_ids: await activeSiteIds(String(member.id), String(member.org_id)),
  };
}

async function logout(token: string) {
  const result = await authCall("logout?scope=global", { method: "POST" }, token);
  if (!result.ok) return { status: 401, body: { message: "La session n'a pas pu être révoquée." } };
  return { status: 200, body: { signed_out: true } };
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return response(204, {}, origin);
  if (request.method !== "POST") return response(405, { message: "Méthode non autorisée." }, origin);
  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE_KEY) return response(503, { message: "Service Auth non configuré côté serveur." }, origin);

  try {
    const body = await request.json() as Record<string, unknown>;
    if (body.app_code !== "naxa-services") return response(400, { message: "Application non autorisée." }, origin);
    const action = String(body.action ?? "");
    const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    let result: { status: number; body: Record<string, unknown> };

    if (action === "login") result = await login(body, request);
    else if (action === "refresh") result = await refreshSession(body, (body.device as Record<string, unknown>) ?? {});
    else if (action === "request_recovery") result = await requestRecovery(body);
    else if (action === "change_password") result = await changePassword(body, bearer);
    else if (action === "logout") result = await logout(bearer);
    else result = { status: 400, body: { message: "Action non reconnue." } };

    return response(result.status, result.body, origin);
  } catch (_error) {
    // Do not expose internal aliases, account existence, SQL errors or tokens.
    return response(503, { message: "Service indisponible. Réessaie plus tard ou contacte le support." }, origin);
  }
});
