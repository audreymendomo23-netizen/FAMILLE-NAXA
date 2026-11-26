import { hasActiveDeviceSession, verifiedTokenSessionId } from "../_shared/naxa-services-device-session.ts";
import { parseSubscriptionCredit } from "./subscription_credit_contract.ts";
import { isLegalDocumentVersion, isNaxaActivityProfile, isNaxaBusinessMode, isNaxaLocale, isNaxaSiteCode, isNaxaWorkstationCode, isNaxaWorkstationKind, nativeSiteIdsForScopes } from "./scope_contract.ts";
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
  const encodedId = encodeURIComponent(accountId);
  let rows: Record<string, unknown>[];
  try {
    rows = await rest(
      "ns_members?select=id,org_id,display_name,role_code,status,preferred_locale,discovery_completed_at,tour_completed_at&account_id=eq." + encodedId + "&status=eq.active&limit=2",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
  } catch {
    // Keep authentication usable until the additive v2 migration is applied.
    rows = await rest(
      "ns_members?select=id,org_id,display_name,role_code,status&account_id=eq." + encodedId + "&status=eq.active&limit=2",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
  }
  if (!rows || rows.length !== 1) return null;
  return rows[0];
}
async function activeSiteIds(memberId: string, orgId: string) {
  const q = "ns_member_scopes?select=scope_type,site_id,scope_id&member_id=eq." + encodeURIComponent(memberId) + "&org_id=eq." + encodeURIComponent(orgId) + "&can_read=eq.true";
  const rows = await rest(q, { headers: serviceHeaders() }) as Record<string, unknown>[];
  // The current native ERP operates at site scope. Workstation-only assignments
  // must not be widened to the whole site until workstation-level filters exist.
  const hasOrganizationScope = (rows ?? []).some((row) => row.scope_type === "organization");
  if (!hasOrganizationScope) return nativeSiteIdsForScopes(rows ?? []);
  const sites = await rest("ns_sites?select=id&org_id=eq." + encodeURIComponent(orgId) + "&status=eq.active", { headers: serviceHeaders() }) as Record<string, unknown>[];
  return nativeSiteIdsForScopes(rows ?? [], (sites ?? []).map((site) => String(site.id)));
}
async function sessionPayload(authData: Record<string, unknown>, account: Record<string, unknown>) {
  if (account.status !== "active") throw new Error("ACCOUNT_NOT_ACTIVE");
  const member = await activeMember(String(account.id));
  if (!member) throw new Error("MEMBER_SCOPE_INVALID");
  const scopedSiteIds = await activeSiteIds(String(member.id), String(member.org_id));
  const siteRows = scopedSiteIds.length
    ? await rest(
      "ns_sites?select=id,code,name,address_label,phone_contact&org_id=eq." +
        encodeURIComponent(String(member.org_id)) + "&status=eq.active",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[]
    : [];
  const activeSites = (siteRows ?? [])
    .filter((site) => scopedSiteIds.includes(String(site.id)))
    .map((site) => ({
      id: String(site.id),
      code: String(site.code ?? ""),
      name: String(site.name ?? ""),
      address_label: String(site.address_label ?? ""),
      phone_contact: String(site.phone_contact ?? ""),
    }));
  // Return only active site records; never expose inactive or workstation-only scopes.
  const sites = activeSites.map((site) => site.id);
  let organizationRows: Record<string, unknown>[];
  try {
    organizationRows = await rest(
      "ns_organizations?select=display_name,business_mode,default_locale,activity_profile&id=eq." +
        encodeURIComponent(String(member.org_id)) + "&status=eq.active&limit=1",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
  } catch {
    // Backward-compatible session response before the v2 activity migration is installed.
    organizationRows = await rest(
      "ns_organizations?select=display_name,business_mode,default_locale&id=eq." +
        encodeURIComponent(String(member.org_id)) + "&status=eq.active&limit=1",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
  }
  const organization = organizationRows?.[0] ?? {};
  let legalRows: Record<string, unknown>[] = [];
  try {
    legalRows = await rest(
      "ns_legal_acceptances?select=document_type,document_version&member_id=eq." +
        encodeURIComponent(String(member.id)),
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
  } catch {
    // Missing v2 acceptance table means the client must show the legal acceptance flow.
  }
  const acceptedLegalDocuments = (legalRows ?? []).map((item) =>
    String(item.document_type) + ":" + String(item.document_version)
  );
  const sessionId = jwtClaim(String(authData.access_token ?? ""), "session_id");
  const deviceRows = sessionId ? await rest(
    "ns_devices?select=id&account_id=eq." + encodeURIComponent(String(account.id)) +
      "&session_id=eq." + encodeURIComponent(sessionId) + "&revoked_at=is.null&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[] : [];
  const deviceId = String(deviceRows?.[0]?.id ?? "");
  if (!deviceId) throw new Error("DEVICE_SESSION_BINDING_REQUIRED");
  return {
    device_id: deviceId,
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
      organization_name: organization.display_name ?? "",
      business_mode: organization.business_mode ?? "solo",
      default_locale: member.preferred_locale ?? organization.default_locale ?? "fr",
      activity_profile: organization.activity_profile ?? null,
      accepted_legal_documents: acceptedLegalDocuments,
      discovery_completed: Boolean(member.discovery_completed_at),
      tour_completed: Boolean(member.tour_completed_at),
      active_site_ids: sites,
      active_sites: activeSites,
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
function jwtClaim(token: string, claim: string): string {
  try {
    const encoded = token.split(".")[1];
    if (!encoded) return "";
    const normalized = encoded.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
    const payload = JSON.parse(atob(padded)) as Record<string, unknown>;
    return String(payload[claim] ?? "");
  } catch {
    return "";
  }
}
async function touchDevice(
  accountId: string,
  device: Record<string, unknown>,
  remember: boolean,
  allowReenroll: boolean,
  previousRefreshTokenHash: string,
  nextRefreshTokenHash: string,
  sessionId: string,
) {
  const installationId = String(device.installation_id ?? "");
  if (!installationId || installationId.length > 160 || !nextRefreshTokenHash || !sessionId) {
    throw new Error("DEVICE_SESSION_BINDING_REQUIRED");
  }
  const now = new Date().toISOString();
  const rows = await rest(
    "ns_devices?select=id,revoked_at,refresh_token_hash&account_id=eq." + encodeURIComponent(accountId) +
      "&installation_id=eq." + encodeURIComponent(installationId) + "&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  const existing = rows?.[0];
  if (existing?.revoked_at && !allowReenroll) throw new Error("DEVICE_REVOKED");
  if (existing?.id && !allowReenroll && existing.refresh_token_hash !== previousRefreshTokenHash) {
    throw new Error("DEVICE_REFRESH_TOKEN_MISMATCH");
  }
  if (existing?.id) {
    await rest("ns_devices?id=eq." + encodeURIComponent(String(existing.id)), {
      method: "PATCH",
      headers: serviceHeaders({ Prefer: "return=minimal" }),
      body: JSON.stringify({
        label: String(device.label ?? "").slice(0, 90),
        remember_device: remember,
        refresh_token_hash: nextRefreshTokenHash,
        session_id: sessionId,
        last_seen_at: now,
        ...(allowReenroll ? { revoked_at: null } : {}),
      }),
    });
    return;
  }
  if (!allowReenroll) throw new Error("DEVICE_NOT_ENROLLED");
  await rest("ns_devices", {
    method: "POST",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({
      account_id: accountId,
      installation_id: installationId,
      platform: device.platform === "web" ? "web" : "android",
      label: String(device.label ?? "").slice(0, 90),
      remember_device: remember,
      refresh_token_hash: nextRefreshTokenHash,
      session_id: sessionId,
      first_seen_at: now,
      last_seen_at: now,
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
  const refreshToken = String(auth.data.refresh_token ?? "");
  const accessToken = String(auth.data.access_token ?? "");
  await touchDevice(
    String(account.id),
    (body.device as Record<string, unknown>) ?? {},
    body.remember_device === true,
    true,
    "",
    await sha256(refreshToken),
    jwtClaim(accessToken, "session_id"),
  );
  await rest("ns_accounts?id=eq." + encodeURIComponent(String(account.id)), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({ last_login_at: new Date().toISOString() }),
  });
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
  try {
    await touchDevice(
      String(account.id),
      device,
      body.remember_device === true,
      false,
      await sha256(refreshToken),
      await sha256(String(auth.data.refresh_token ?? "")),
      jwtClaim(String(auth.data.access_token ?? ""), "session_id"),
    );
  } catch (_error) {
    // Auth has already rotated the refresh token, but it is never returned
    // to a revoked installation or one presenting a mismatched token.
    return { status: 401, body: { message: "Cet appareil ou cette session a été révoqué. Reconnecte-toi." } };
  }
  return { status: 200, body: await sessionPayload(auth.data, account) };
}

async function requestRecovery(body: Record<string, unknown>, request: Request) {
  const identifier = String(body.identifier ?? "").trim().toUpperCase();
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const loginHash = await sha256("naxa-services-recovery:" + identifier);
  const ipHash = await sha256("naxa-services-recovery-ip:" + ip);
  if (await isLimited(loginHash, ipHash)) {
    return { status: 429, body: { accepted: true, message: "Demande reçue. Réessaie plus tard ou contacte le responsable." } };
  }
  const account = /^NS-[A-Z0-9]{4,12}$/.test(identifier) ? await accountByLoginId(identifier) : null;
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
  // Record both existing and unknown identifiers identically to prevent enumeration.
  await recordAttempt(loginHash, ipHash, false);
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

  if (!await hasActiveDeviceSession(token, String(account.id), path => rest(path, { headers: serviceHeaders() }))) {
    return { status: 401, body: { message: "Cet appareil ou cette session a été révoqué." } };
  }

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
  const refreshedSession = await sessionPayload({
    access_token: token,
    refresh_token: body.refresh_token,
    expires_in: 1800,
    token_type: "bearer",
  }, { ...account, password_change_required: false });
  return { status: 200, body: { ...refreshedSession, require_password_change: false } };
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

async function logout(body: Record<string, unknown>, token: string) {
  const user = await authCall("user", { method: "GET" }, token);
  if (!user.ok || !user.data.id) return { status: 401, body: { message: "Session expirée." } };
  const account = await accountByAuthUser(String(user.data.id));
  const installationId = String((body.device as Record<string, unknown> | undefined)?.installation_id ?? "");
  const sessionId = jwtClaim(token, "session_id");
  if (account && installationId && sessionId) {
    await rest(
      "ns_devices?account_id=eq." + encodeURIComponent(String(account.id)) +
        "&installation_id=eq." + encodeURIComponent(installationId) +
        "&session_id=eq." + encodeURIComponent(sessionId),
      {
        method: "PATCH",
        headers: serviceHeaders({ Prefer: "return=minimal" }),
        body: JSON.stringify({ revoked_at: new Date().toISOString(), remember_device: false }),
      },
    );
    const member = await activeMember(String(account.id));
    if (member) {
      await auditAction(String(member.org_id), String(user.data.id), String(member.id), "session.logout", "device", installationId, "Déconnexion de l'appareil");
    }
  }
  const result = await authCall("logout?scope=local", { method: "POST" }, token);
  if (!result.ok) return { status: 401, body: { message: "La session n'a pas pu être révoquée." } };
  return { status: 200, body: { signed_out: true } };
}


function secureRandom(length: number) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}
function temporaryPassword() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  const chars = Array.from(bytes, (b) => alphabet[b % alphabet.length]);
  chars[0] = "N";
  chars[1] = "a";
  chars[2] = "7";
  chars[3] = "!";
  return chars.join("");
}
async function actorContext(token: string) {
  const auth = await authCall("user", { method: "GET" }, token);
  if (!auth.ok || !auth.data.id) return null;
  const account = await accountByAuthUser(String(auth.data.id));
  if (!account || account.status !== "active") return null;
  if (!await hasActiveDeviceSession(token, String(account.id), path => rest(path, { headers: serviceHeaders() }))) return null;
  const member = await activeMember(String(account.id));
  if (!member) return null;
  const scopes = await rest(
    "ns_member_scopes?select=scope_type,scope_id,site_id,workstation_id,can_read,can_operate,can_manage&member_id=eq." +
      encodeURIComponent(String(member.id)) + "&org_id=eq." + encodeURIComponent(String(member.org_id)),
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  return { authUserId: String(auth.data.id), account, member, scopes: scopes ?? [] };
}
function actorCanManageSite(actor: NonNullable<Awaited<ReturnType<typeof actorContext>>>, siteId: string) {
  // A workstation grant is never sufficient to manage an entire site.
  return actor.scopes.some((s) =>
    s.can_manage === true &&
    (s.scope_type === "organization" ||
      (s.scope_type === "site" && String(s.site_id) === siteId))
  );
}
function actorCanReadSite(actor: NonNullable<Awaited<ReturnType<typeof actorContext>>>, siteId: string) {
  return actor.scopes.some((s) =>
    s.can_read === true &&
    (s.scope_type === "organization" ||
      ((s.scope_type === "site" || s.scope_type === "workstation") && String(s.site_id) === siteId))
  );
}

async function createSite(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const canManageOrganization = actor.member.role_code === "promoter" &&
    actor.scopes.some((scope) => scope.scope_type === "organization" && scope.can_manage === true);
  if (!canManageOrganization) {
    return { status: 403, body: { message: "Seul le Promoteur avec périmètre Organisation peut créer un point de vente." } };
  }
  const code = String(body.code ?? "").trim().toUpperCase();
  const name = String(body.name ?? "").trim();
  const addressLabel = String(body.address_label ?? "").trim();
  const phoneContact = String(body.phone_contact ?? "").trim();
  if (!isNaxaSiteCode(code) || !name || name.length > 120 || addressLabel.length > 200 || phoneContact.length > 32) {
    return { status: 400, body: { message: "Code, nom ou coordonnées du point de vente invalides." } };
  }
  const organizations = await rest(
    "ns_organizations?select=id,business_mode,status&id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  const organization = organizations?.[0];
  if (!organization || organization.status !== "active") {
    return { status: 404, body: { message: "Organisation introuvable ou inactive." } };
  }
  if (organization.business_mode !== "multi_site_network") {
    return { status: 409, body: { message: "Le modèle multi-sites doit être activé avant de créer plusieurs points de vente." } };
  }
  const existing = await rest(
    "ns_sites?select=id&org_id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&code=eq." + encodeURIComponent(code) + "&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  if (existing?.length) return { status: 409, body: { message: "Ce code de point de vente existe déjà dans l’organisation." } };

  const rows = await rest("ns_sites", {
    method: "POST",
    headers: serviceHeaders({ Prefer: "return=representation" }),
    body: JSON.stringify({
      org_id: actor.member.org_id,
      code,
      name,
      address_label: addressLabel || null,
      phone_contact: phoneContact || null,
      status: "active",
      settings: {},
    }),
  }) as Record<string, unknown>[];
  const site = rows?.[0];
  if (!site?.id) throw new Error("SITE_INSERT_FAILED");
  await auditAction(
    String(actor.member.org_id), actor.authUserId, String(actor.member.id),
    "site.created", "site", String(site.id), "Création du point de vente " + code,
  );
  return {
    status: 201,
    body: {
      saved: true,
      site: {
        id: String(site.id), code: String(site.code), name: String(site.name),
        address_label: String(site.address_label ?? ""), phone_contact: String(site.phone_contact ?? ""),
      },
    },
  };
}

async function createWorkstation(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  if (!["promoter", "network_manager", "site_manager"].includes(String(actor.member.role_code))) {
    return { status: 403, body: { message: "Ce rôle ne peut pas créer un emplacement de travail." } };
  }
  const siteId = String(body.site_id ?? "");
  if (!siteId || !actorCanManageSite(actor, siteId)) {
    return { status: 403, body: { message: "Périmètre du point de vente insuffisant pour créer cet emplacement." } };
  }
  const code = String(body.code ?? "").trim().toUpperCase();
  const name = String(body.name ?? "").trim();
  const kind = String(body.kind ?? "");
  const capacity = Number(body.capacity);
  if (!isNaxaWorkstationCode(code) || !name || name.length > 120 ||
      !isNaxaWorkstationKind(kind) || !Number.isInteger(capacity) || capacity < 1 || capacity > 100) {
    return { status: 400, body: { message: "Code, nom, type ou capacité de l’emplacement invalide." } };
  }
  const sites = await rest(
    "ns_sites?select=id&org_id=eq." + encodeURIComponent(String(actor.member.org_id)) +
      "&id=eq." + encodeURIComponent(siteId) + "&status=eq.active&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  if (!sites?.length) return { status: 404, body: { message: "Point de vente absent ou inactif." } };
  const existing = await rest(
    "ns_workstations?select=id&org_id=eq." + encodeURIComponent(String(actor.member.org_id)) +
      "&site_id=eq." + encodeURIComponent(siteId) + "&code=eq." + encodeURIComponent(code) + "&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  if (existing?.length) return { status: 409, body: { message: "Ce code d’emplacement existe déjà dans ce point de vente." } };

  const rows = await rest("ns_workstations", {
    method: "POST",
    headers: serviceHeaders({ Prefer: "return=representation" }),
    body: JSON.stringify({
      org_id: actor.member.org_id, site_id: siteId, code, name, kind,
      capacity, status: "active",
    }),
  }) as Record<string, unknown>[];
  const workstation = rows?.[0];
  if (!workstation?.id) throw new Error("WORKSTATION_INSERT_FAILED");
  await auditAction(
    String(actor.member.org_id), actor.authUserId, String(actor.member.id),
    "workstation.created", "workstation", String(workstation.id),
    "Création de l’emplacement " + code + " sur le point de vente " + siteId,
  );
  return {
    status: 201,
    body: {
      saved: true,
      workstation: {
        id: String(workstation.id), site_id: String(workstation.site_id),
        code: String(workstation.code), name: String(workstation.name),
        kind: String(workstation.kind), capacity: Number(workstation.capacity),
        status: String(workstation.status),
      },
    },
  };
}

async function listWorkstations(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const siteId = String(body.site_id ?? "");
  if (!siteId || !actorCanReadSite(actor, siteId)) {
    return { status: 403, body: { message: "Ce compte ne dispose pas d’un accès à ce point de vente." } };
  }
  const rows = await rest(
    "ns_workstations?select=id,site_id,code,name,kind,capacity,status&org_id=eq." +
      encodeURIComponent(String(actor.member.org_id)) + "&site_id=eq." + encodeURIComponent(siteId) + "&status=eq.active&order=created_at.asc",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  const hasSiteWideRead = actor.scopes.some((scope) =>
    scope.can_read === true &&
    (scope.scope_type === "organization" ||
      (scope.scope_type === "site" && String(scope.site_id) === siteId))
  );
  const allowedWorkstationIds = new Set(actor.scopes
    .filter((scope) => scope.scope_type === "workstation" && scope.can_read === true && String(scope.site_id) === siteId)
    .map((scope) => String(scope.workstation_id ?? scope.scope_id)));
  const visible = hasSiteWideRead ? (rows ?? []) : (rows ?? []).filter((row) => allowedWorkstationIds.has(String(row.id)));
  return {
    status: 200,
    body: {
      workstations: visible.map((row) => ({
        id: String(row.id), site_id: String(row.site_id), code: String(row.code),
        name: String(row.name), kind: String(row.kind), capacity: Number(row.capacity),
        status: String(row.status),
      })),
    },
  };
}

async function adminCreateAuthUser(alias: string, password: string) {
  const res = await fetch(SUPABASE_URL + "/auth/v1/admin/users", {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify({
      email: alias,
      password,
      email_confirm: true,
      app_metadata: { app_code: "naxa-services" },
      user_metadata: { app_code: "naxa-services", password_change_required: true },
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.id) throw new Error("AUTH_PROVISION_FAILED");
  return String(data.id);
}
async function adminDeleteAuthUser(userId: string) {
  await fetch(SUPABASE_URL + "/auth/v1/admin/users/" + encodeURIComponent(userId), {
    method: "DELETE",
    headers: serviceHeaders(),
  });
}
async function adminSetPassword(userId: string, password: string) {
  const res = await fetch(SUPABASE_URL + "/auth/v1/admin/users/" + encodeURIComponent(userId), {
    method: "PUT",
    headers: serviceHeaders(),
    body: JSON.stringify({ password, user_metadata: { app_code: "naxa-services", password_change_required: true } }),
  });
  if (!res.ok) throw new Error("AUTH_RESET_FAILED");
}
async function auditAction(orgId: string, actorUserId: string, actorMemberId: string, action: string, objectType: string, objectId: string, reason: string) {
  await rest("ns_audit_events", {
    method: "POST",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({
      org_id: orgId,
      actor_auth_user_id: actorUserId,
      actor_member_id: actorMemberId,
      action_code: action,
      object_type: objectType,
      object_id: objectId,
      reason,
      metadata_redacted: { app_code: "naxa-services" },
    }),
  });
}

async function updateOrganizationProfile(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const canManageOrg = actor.member.role_code === "promoter" &&
    actor.scopes.some((scope) => scope.scope_type === "organization" && scope.can_manage === true);
  if (!canManageOrg) {
    return { status: 403, body: { message: "Seul le Promoteur disposant du périmètre Organisation peut modifier ce profil." } };
  }
  const displayName = String(body.display_name ?? "").trim().slice(0, 120);
  const businessMode = String(body.business_mode ?? "");
  const defaultLocale = String(body.default_locale ?? "fr");
  if (!displayName || !isNaxaBusinessMode(businessMode) || !isNaxaLocale(defaultLocale)) {
    return { status: 400, body: { message: "Profil d'organisation invalide." } };
  }
  const organizationRows = await rest(
    "ns_organizations?select=id&status=eq.active&id=eq." +
      encodeURIComponent(String(actor.member.org_id)) + "&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  if (!organizationRows?.length) {
    return { status: 404, body: { message: "Organisation introuvable ou inactive." } };
  }
  await rest("ns_organizations?id=eq." + encodeURIComponent(String(actor.member.org_id)), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=representation" }),
    body: JSON.stringify({
      display_name: displayName,
      business_mode: businessMode,
      default_locale: defaultLocale,
    }),
  });
  await auditAction(
    String(actor.member.org_id),
    actor.authUserId,
    String(actor.member.id),
    "organization.profile_updated",
    "organization",
    String(actor.member.org_id),
    "Mise à jour du modèle d'exploitation et de la langue",
  );
  return { status: 200, body: { saved: true, business_mode: businessMode, default_locale: defaultLocale } };
}

async function setOrganizationActivityProfile(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const allowed = actor.member.role_code === "promoter" &&
    actor.scopes.some((scope) => scope.scope_type === "organization" && scope.can_manage === true);
  if (!allowed) return { status: 403, body: { message: "Le Promoteur doit choisir l’activité principale de l’organisation." } };
  const activityProfile = String(body.activity_profile ?? "");
  if (!isNaxaActivityProfile(activityProfile)) return { status: 400, body: { message: "Profil d’activité non reconnu." } };
  const rows = await rest(
    "ns_organizations?select=id,activity_profile&id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&status=eq.active&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  const organization = rows?.[0];
  if (!organization) return { status: 404, body: { message: "Organisation introuvable." } };
  const current = organization.activity_profile;
  if (current) {
    if (current === activityProfile) return { status: 200, body: { saved: true, activity_profile: current, already_selected: true } };
    return { status: 409, body: { message: "L’activité de cette organisation a déjà été choisie. Une modification exige une procédure administrée." } };
  }
  const updatedRows = await rest(
    "ns_organizations?id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&activity_profile=is.null",
    {
      method: "PATCH",
      headers: serviceHeaders({ Prefer: "return=representation" }),
      body: JSON.stringify({
        activity_profile: activityProfile,
        activity_profile_selected_at: new Date().toISOString(),
        activity_profile_selected_by: actor.member.id,
      }),
    },
  ) as Record<string, unknown>[];
  if (!updatedRows?.length) {
    const latestRows = await rest(
      "ns_organizations?select=activity_profile&id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&limit=1",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
    const latest = latestRows?.[0]?.activity_profile;
    if (latest === activityProfile) {
      return { status: 200, body: { saved: true, activity_profile: activityProfile, already_selected: true } };
    }
    return { status: 409, body: { message: "Un autre choix d’activité vient d’être enregistré. Recharge l’application." } };
  }
  await auditAction(
    String(actor.member.org_id), actor.authUserId, String(actor.member.id),
    "organization.activity_profile_selected", "organization", String(actor.member.org_id),
    "Premier choix du profil d’activité : " + activityProfile,
  );
  return { status: 200, body: { saved: true, activity_profile: activityProfile, already_selected: false } };
}

async function acceptLegalDocument(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const documentType = String(body.document_type ?? "");
  const documentVersion = String(body.document_version ?? "");
  const locale = String(body.locale ?? "fr");
  if (!["terms", "privacy"].includes(documentType) || !isLegalDocumentVersion(documentType, documentVersion) || !["fr", "en"].includes(locale)) {
    return { status: 400, body: { message: "Acceptation légale invalide." } };
  }
  await rest("ns_legal_acceptances?on_conflict=member_id,document_type,document_version", {
    method: "POST",
    headers: serviceHeaders({ Prefer: "resolution=ignore-duplicates,return=minimal" }),
    body: JSON.stringify({
      org_id: actor.member.org_id,
      member_id: actor.member.id,
      document_type: documentType,
      document_version: documentVersion,
      locale,
      accepted_at: new Date().toISOString(),
    }),
  });
  await auditAction(
    String(actor.member.org_id), actor.authUserId, String(actor.member.id),
    "legal.document_accepted", "legal_document", documentType + ":" + documentVersion,
    "Acceptation du document légal " + documentType + " (" + locale + ")",
  );
  return { status: 200, body: { saved: true, document_type: documentType, document_version: documentVersion } };
}

async function setMemberPreferredLocale(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const locale = String(body.locale ?? "");
  if (!isNaxaLocale(locale)) return { status: 400, body: { message: "Langue non prise en charge." } };
  await rest(
    "ns_members?id=eq." + encodeURIComponent(String(actor.member.id)),
    {
      method: "PATCH",
      headers: serviceHeaders({ Prefer: "return=minimal" }),
      body: JSON.stringify({ preferred_locale: locale }),
    },
  );
  await auditAction(
    String(actor.member.org_id), actor.authUserId, String(actor.member.id),
    "member.preferred_locale_changed", "member", String(actor.member.id),
    "Langue utilisateur : " + locale,
  );
  return { status: 200, body: { saved: true, locale } };
}

async function completeOnboardingStep(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const step = String(body.step ?? "");
  if (!["discovery", "tour"].includes(step)) return { status: 400, body: { message: "Étape d’intégration invalide." } };
  const organizationRows = await rest(
    "ns_organizations?select=activity_profile&id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&limit=1",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  if (!organizationRows?.[0]?.activity_profile) {
    return { status: 409, body: { message: "L’activité de l’organisation doit être définie avant de terminer l’intégration." } };
  }
  const legalRows = await rest(
    "ns_legal_acceptances?select=document_type,document_version&member_id=eq." + encodeURIComponent(String(actor.member.id)),
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  const accepted = new Set((legalRows ?? []).map((row) => String(row.document_type) + ":" + String(row.document_version)));
  if (!accepted.has("terms:2026-11-v1") || !accepted.has("privacy:2026-11-v1")) {
    return { status: 409, body: { message: "Les conditions et la politique de confidentialité doivent être acceptées." } };
  }
  const column = step === "discovery" ? "discovery_completed_at" : "tour_completed_at";
  await rest(
    "ns_members?id=eq." + encodeURIComponent(String(actor.member.id)) + "&" + column + "=is.null",
    {
      method: "PATCH",
      headers: serviceHeaders({ Prefer: "return=minimal" }),
      body: JSON.stringify({ [column]: new Date().toISOString() }),
    },
  );
  await auditAction(
    String(actor.member.org_id), actor.authUserId, String(actor.member.id),
    "member.onboarding_completed", "member", String(actor.member.id),
    "Étape de découverte terminée : " + step,
  );
  return { status: 200, body: { saved: true, step } };
}

async function provisionMember(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const aliasDomain = (Deno.env.get("NS_AUTH_ALIAS_DOMAIN") ?? "").trim().toLowerCase();
  if (!aliasDomain || aliasDomain.includes("@") || aliasDomain.includes("/") || aliasDomain.includes(" ")) {
    return { status: 503, body: { message: "Le domaine d'alias Auth attend sa preuve technique locale." } };
  }

  const role = String(body.role_code ?? "");
  const siteScopes = Array.isArray(body.scopes) ? body.scopes as Record<string, unknown>[] : [];
  const name = String(body.display_name ?? "").trim().slice(0, 120);
  const contactPhone = String(body.contact_phone ?? "").trim().slice(0, 32);
  if (!name || !siteScopes.length || siteScopes.length > 20) {
    return { status: 400, body: { message: "Nom et périmètre d'affectation requis." } };
  }

  const promoterRoles = ["network_manager", "site_manager", "workstation_manager", "cashier", "receptionist", "hair_stylist", "pressing_operator", "stock_manager", "accountant"];
  const networkRoles = ["site_manager", "workstation_manager", "cashier", "receptionist", "hair_stylist", "pressing_operator", "stock_manager", "accountant"];
  const siteRoles = ["workstation_manager", "cashier", "receptionist", "hair_stylist", "pressing_operator", "stock_manager", "accountant"];
  const allowed = actor.member.role_code === "promoter" ? promoterRoles
    : actor.member.role_code === "network_manager" ? networkRoles
    : actor.member.role_code === "site_manager" ? siteRoles : [];
  if (!allowed.includes(role)) return { status: 403, body: { message: "Tu n'as pas le droit de créer ce rôle." } };

  const normalizedScopes: Record<string, unknown>[] = [];
  for (const scope of siteScopes) {
    const scopeType = String(scope.scope_type ?? "");
    const siteId = String(scope.site_id ?? "");
    if (!siteId || !actorCanManageSite(actor, siteId)) return { status: 403, body: { message: "Périmètre d'affectation non autorisé." } };
    const siteRows = await rest("ns_sites?select=id&org_id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&id=eq." + encodeURIComponent(siteId) + "&limit=1", { headers: serviceHeaders() }) as Record<string, unknown>[];
    if (!siteRows?.length) return { status: 400, body: { message: "Point de vente invalide." } };
    if (scopeType === "workstation") {
      const workstationId = String(scope.workstation_id ?? "");
      const workstationRows = await rest("ns_workstations?select=id&org_id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&site_id=eq." + encodeURIComponent(siteId) + "&id=eq." + encodeURIComponent(workstationId) + "&limit=1", { headers: serviceHeaders() }) as Record<string, unknown>[];
      if (!workstationRows?.length) return { status: 400, body: { message: "Emplacement invalide." } };
      normalizedScopes.push({ org_id: actor.member.org_id, scope_type: "workstation", scope_id: workstationId, site_id: siteId, workstation_id: workstationId, can_read: true, can_operate: true, can_manage: role === "workstation_manager" });
    } else if (scopeType === "site") {
      normalizedScopes.push({ org_id: actor.member.org_id, scope_type: "site", scope_id: siteId, site_id: siteId, can_read: true, can_operate: true, can_manage: ["network_manager", "site_manager"].includes(role) });
    } else {
      return { status: 400, body: { message: "Type de périmètre non valide." } };
    }
  }

  let loginId = "";
  for (let attempt = 0; attempt < 6; attempt++) {
    const number = Array.from(crypto.getRandomValues(new Uint8Array(4))).reduce((n, b) => (n * 256 + b) % 1000000, 0);
    loginId = "NS-" + String(number).padStart(6, "0");
    const exists = await accountByLoginId(loginId);
    if (!exists) break;
    loginId = "";
  }
  if (!loginId) return { status: 503, body: { message: "Impossible de générer un identifiant disponible." } };

  const password = temporaryPassword();
  const authAlias = "ns-" + secureRandom(28).toLowerCase() + "@" + aliasDomain;
  let authUserId = "";
  let createdAccountId = "";
  let createdMemberId = "";
  try {
    authUserId = await adminCreateAuthUser(authAlias, password);
    const accounts = await rest("ns_accounts", {
      method: "POST",
      headers: serviceHeaders({ Prefer: "return=representation" }),
      body: JSON.stringify({
        auth_user_id: authUserId,
        login_id: loginId,
        auth_alias: authAlias,
        status: "active",
        password_change_required: true,
      }),
    }) as Record<string, unknown>[];
    const account = accounts?.[0];
    if (!account?.id) throw new Error("ACCOUNT_INSERT_FAILED");
    createdAccountId = String(account.id);
    const members = await rest("ns_members", {
      method: "POST",
      headers: serviceHeaders({ Prefer: "return=representation" }),
      body: JSON.stringify({
        org_id: actor.member.org_id,
        account_id: account.id,
        display_name: name,
        contact_phone: contactPhone || null,
        role_code: role,
        status: "active",
      }),
    }) as Record<string, unknown>[];
    const member = members?.[0];
    if (!member?.id) throw new Error("MEMBER_INSERT_FAILED");
    createdMemberId = String(member.id);
    await rest("ns_member_scopes", {
      method: "POST",
      headers: serviceHeaders({ Prefer: "return=minimal" }),
      body: JSON.stringify(normalizedScopes.map((s) => ({ ...s, member_id: member.id }))),
    });
    await auditAction(String(actor.member.org_id), actor.authUserId, String(actor.member.id), "member.provisioned", "member", String(member.id), "Création d'un compte et remise initiale de l'identifiant");
    return {
      status: 200,
      body: {
        account_created: true,
        login_id: loginId,
        temporary_password: password,
        display_name: name,
        role_code: role,
        password_change_required: true,
        one_time_secret_notice: "Afficher puis remettre en main propre. Ne pas copier dans un canal public. Le serveur ne renverra plus ce mot de passe.",
      },
    };
  } catch (_error) {
    // Best-effort compensation: remove any partially written membership rows
    // before deleting the Auth identity. No partial account is reported as active.
    if (createdMemberId) await rest("ns_member_scopes?member_id=eq." + encodeURIComponent(createdMemberId), {
      method: "DELETE", headers: serviceHeaders({ Prefer: "return=minimal" }),
    }).catch(() => null);
    if (createdMemberId) await rest("ns_members?id=eq." + encodeURIComponent(createdMemberId), {
      method: "DELETE", headers: serviceHeaders({ Prefer: "return=minimal" }),
    }).catch(() => null);
    if (createdAccountId) await rest("ns_accounts?id=eq." + encodeURIComponent(createdAccountId), {
      method: "DELETE", headers: serviceHeaders({ Prefer: "return=minimal" }),
    }).catch(() => null);
    if (authUserId) await adminDeleteAuthUser(authUserId);
    return { status: 503, body: { message: "La création du compte n'a pas abouti. Aucune activation n'est confirmée." } };
  }
}

async function listRecoveryRequests(token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  if (!["promoter", "network_manager", "site_manager"].includes(String(actor.member.role_code))) {
    return { status: 403, body: { message: "Consultation non autorisée." } };
  }
  const rows = await rest(
    "ns_auth_recovery_requests?select=id,account_id,request_note,status,requested_at&status=eq.pending&order=requested_at.asc&limit=50",
    { headers: serviceHeaders() },
  ) as Record<string, unknown>[];
  const requests: Record<string, unknown>[] = [];
  for (const item of rows ?? []) {
    if (!item.account_id) continue;
    const memberRows = await rest(
      "ns_members?select=id,org_id,display_name,role_code&account_id=eq." +
        encodeURIComponent(String(item.account_id)) + "&org_id=eq." +
        encodeURIComponent(String(actor.member.org_id)) + "&status=eq.active&limit=1",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
    const member = memberRows?.[0];
    if (!member) continue;
    const scopes = await rest(
      "ns_member_scopes?select=site_id&member_id=eq." + encodeURIComponent(String(member.id)),
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
    const inScope = actor.member.role_code === "promoter" ||
      (scopes ?? []).some((scope) => scope.site_id && actorCanManageSite(actor, String(scope.site_id)));
    if (!inScope) continue;
    const account = await rest(
      "ns_accounts?select=login_id&id=eq." + encodeURIComponent(String(item.account_id)) + "&limit=1",
      { headers: serviceHeaders() },
    ) as Record<string, unknown>[];
    requests.push({
      id: item.id,
      requested_at: item.requested_at,
      request_note: item.request_note,
      display_name: member.display_name,
      role_code: member.role_code,
      login_id: account?.[0]?.login_id ?? "NS-••••••",
    });
  }
  return { status: 200, body: { requests } };
}

async function completeRecovery(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  if (!["promoter", "network_manager", "site_manager"].includes(String(actor.member.role_code))) {
    return { status: 403, body: { message: "Réinitialisation non autorisée pour ce rôle." } };
  }
  const requestId = String(body.recovery_request_id ?? "");
  const method = String(body.identity_check_method ?? "").trim().slice(0, 80);
  const note = String(body.identity_check_note ?? "").trim().slice(0, 500);
  if (!requestId || !method || note.length < 12) return { status: 400, body: { message: "Méthode et note de vérification d'identité obligatoires." } };
  const requests = await rest("ns_auth_recovery_requests?select=id,account_id,status&status=eq.pending&id=eq." + encodeURIComponent(requestId) + "&limit=1", { headers: serviceHeaders() }) as Record<string, unknown>[];
  const recovery = requests?.[0];
  if (!recovery?.account_id) return { status: 404, body: { message: "Demande introuvable ou déjà traitée." } };
  const target = await rest("ns_accounts?select=id,auth_user_id,login_id,status&id=eq." + encodeURIComponent(String(recovery.account_id)) + "&limit=1", { headers: serviceHeaders() }) as Record<string, unknown>[];
  const account = target?.[0];
  if (!account || account.status !== "active") return { status: 403, body: { message: "Le compte cible n'est pas actif." } };
  const targetMember = await activeMember(String(account.id));
  if (!targetMember || targetMember.org_id !== actor.member.org_id) return { status: 403, body: { message: "Périmètre de récupération non autorisé." } };
  const targetScopes = await rest("ns_member_scopes?select=site_id&member_id=eq." + encodeURIComponent(String(targetMember.id)), { headers: serviceHeaders() }) as Record<string, unknown>[];
  const canManageTarget = actor.member.role_code === "promoter" || (targetScopes ?? []).some((s) => s.site_id && actorCanManageSite(actor, String(s.site_id)));
  if (!canManageTarget) return { status: 403, body: { message: "Tu ne peux pas réinitialiser ce compte." } };

  const tempPassword = temporaryPassword();
  await adminSetPassword(String(account.auth_user_id), tempPassword);
  await rest("ns_accounts?id=eq." + encodeURIComponent(String(account.id)), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({ password_change_required: true }),
  });
  await rest("ns_devices?account_id=eq." + encodeURIComponent(String(account.id)), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({ revoked_at: new Date().toISOString(), remember_device: false }),
  });
  await rest("ns_auth_recovery_requests?id=eq." + encodeURIComponent(requestId), {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=minimal" }),
    body: JSON.stringify({ status: "completed", identity_check_method: method, identity_check_note: note, assigned_to: actor.authUserId, resolved_at: new Date().toISOString() }),
  });
  await auditAction(String(actor.member.org_id), actor.authUserId, String(actor.member.id), "account.password_reset", "account", String(account.id), "Contrôle d'identité hors bande : " + method);
  return { status: 200, body: { login_id: account.login_id, temporary_password: tempPassword, password_change_required: true, revoked_devices: true } };
}

async function listOwnDevices(token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const rows = await rest("ns_devices?select=id,installation_id,platform,label,last_seen_at,revoked_at,session_id&account_id=eq." +
    encodeURIComponent(String(actor.account.id)) + "&order=last_seen_at.desc&limit=100",
    { headers: serviceHeaders() }) as Record<string, unknown>[];
  const currentSessionId = jwtClaim(token, "session_id");
  const devices = (rows ?? []).map(device => ({
    id: device.id, installation_id: device.installation_id, platform: device.platform, label: device.label,
    last_seen_at: device.last_seen_at, revoked_at: device.revoked_at,
    current: device.session_id === currentSessionId && device.revoked_at === null,
  }));
  return { status: 200, body: { devices } };
}

async function revokeDevice(body: Record<string, unknown>, token: string) {
  const actor = await actorContext(token);
  if (!actor) return { status: 401, body: { message: "Session expirée." } };
  const targetAccountId = String(body.account_id ?? actor.account.id);
  const installationId = String(body.installation_id ?? "");
  if (!installationId) return { status: 400, body: { message: "Appareil non précisé." } };
  if (targetAccountId !== String(actor.account.id)) {
    if (!["promoter", "network_manager", "site_manager"].includes(String(actor.member.role_code))) {
      return { status: 403, body: { message: "Révocation non autorisée." } };
    }
    const targetMembers = await rest("ns_members?select=id,org_id&account_id=eq." + encodeURIComponent(targetAccountId) + "&org_id=eq." + encodeURIComponent(String(actor.member.org_id)) + "&status=eq.active&limit=1", { headers: serviceHeaders() }) as Record<string, unknown>[];
    if (!targetMembers?.[0]) return { status: 403, body: { message: "Périmètre de révocation non autorisé." } };
    if (actor.member.role_code !== "promoter") {
      const targetScopes = await rest("ns_member_scopes?select=site_id&member_id=eq." + encodeURIComponent(String(targetMembers[0].id)), { headers: serviceHeaders() }) as Record<string, unknown>[];
      const allowed = (targetScopes ?? []).some((scope) => scope.site_id && actorCanManageSite(actor, String(scope.site_id)));
      if (!allowed) return { status: 403, body: { message: "Périmètre de révocation non autorisé." } };
    }
  }
  const revoked = await rest("ns_devices?select=id&account_id=eq." + encodeURIComponent(targetAccountId) + "&installation_id=eq." + encodeURIComponent(installationId) + "&revoked_at=is.null", {
    method: "PATCH",
    headers: serviceHeaders({ Prefer: "return=representation" }),
    body: JSON.stringify({ revoked_at: new Date().toISOString(), remember_device: false }),
  }) as Record<string, unknown>[];
  if (!revoked?.length) return { status: 404, body: { message: "Appareil introuvable ou déjà révoqué." } };
  await auditAction(String(actor.member.org_id), actor.authUserId, String(actor.member.id), "device.revoked", "device", targetAccountId, "Révocation d'un appareil");
  return { status: 200, body: { revoked: true } };
}

// Restricted to a central beneficiary device explicitly enrolled out of band.
async function subscriptionAdminCapture(body:Record<string,unknown>,token:string) {
  const auth=await authCall("user",{method:"GET"},token);
  const sessionId=verifiedTokenSessionId(token);
  if(!auth.ok||!auth.data.id||!sessionId||body.capture_source!=="sms_receiver")return {status:403,body:{message:"Capture SMS bénéficiaire autorisée uniquement."}};
  const id=String(body.device_id??"");
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))return {status:403,body:{message:"Appareil non autorisé."}};
  const rows=await rest("ns_subscription_admin_devices?select=id,auth_user_id,channel,session_id,destination_reference&id=eq."+encodeURIComponent(id)+"&auth_user_id=eq."+encodeURIComponent(String(auth.data.id))+"&session_id=eq."+encodeURIComponent(sessionId)+"&active=eq.true&sms_capture_allowed=eq.true&limit=2",{headers:serviceHeaders()}) as Record<string,unknown>[];
  if(!Array.isArray(rows)||rows.length!==1)return {status:403,body:{message:"Appareil non autorisé."}};
  const device=rows[0],channel=device.channel;
  if(channel!=="mtn_momo"&&channel!=="orange_money")return {status:403,body:{message:"Canal non autorisé."}};
  const sender=channel==="mtn_momo"?"MobileMoney":"OrangeMoney";
  const captured=typeof body.captured_at==="string"?new Date(body.captured_at):new Date(NaN);
  if(body.sender_origin_id!==sender||!Number.isFinite(captured.getTime())||captured.getTime()>Date.now()+300000||captured.getTime()<Date.now()-86400000)return {status:422,body:{message:"Capture hors fenêtre ou origine non reconnue ; revue requise."}};
  const proof=parseSubscriptionCredit(body.sms,channel,String(device.destination_reference),captured.toISOString());
  if(!proof)return {status:422,body:{message:"SMS crédit incomplet ou non reconnu ; revue requise."}};
  try {
    const data=await rest("rpc/ns_subscription_ingest_credit",{method:"POST",headers:serviceHeaders(),body:JSON.stringify({p_device:id,p_admin:auth.data.id,p_session:sessionId,p_channel:channel,p_ref:proof.ref,p_destination:proof.destination,p_amount:proof.amount,p_payer:proof.payer,p_occurred:proof.occurredAt,p_captured:captured.toISOString(),p_sha:await sha256(String(body.sms)),p_sender:sender})});
    return {status:200,body:{capture_result:data}};
  }catch{return {status:409,body:{message:"Capture non acceptée ; rapprochement manuel nécessaire."}};}
}

async function subscriptionAdminDeviceStatus(body:Record<string,unknown>,token:string) {
  const auth=await authCall("user",{method:"GET"},token);
  const sessionId=verifiedTokenSessionId(token);
  const id=String(body.device_id??"");
  if(!auth.ok||!auth.data.id||!sessionId||!(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)))return {status:403,body:{message:"Appareil non autorisé."}};
  const rows=await rest("ns_subscription_admin_devices?select=id,channel&id=eq."+encodeURIComponent(id)+"&auth_user_id=eq."+encodeURIComponent(String(auth.data.id))+"&session_id=eq."+encodeURIComponent(sessionId)+"&active=eq.true&sms_capture_allowed=eq.true&limit=2",{headers:serviceHeaders()}) as Record<string,unknown>[];
  if(!Array.isArray(rows)||rows.length!==1||!["mtn_momo","orange_money"].includes(String(rows[0].channel)))return {status:403,body:{message:"Appareil non autorisé."}};
  return {status:200,body:{device_status:{id:rows[0].id,channel:rows[0].channel}}};
}

async function subscriptionAdminReview(action:string,body:Record<string,unknown>,token:string) {
  const auth=await authCall("user",{method:"GET"},token);
  const sessionId=verifiedTokenSessionId(token);
  const id=String(body.device_id??"");
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if(!auth.ok||!auth.data.id||!sessionId||!uuid.test(id))return {status:403,body:{message:"Appareil administrateur non autorisé."}};
  const reject=action==="subscription_admin_review_reject";
  if(reject&&(!uuid.test(String(body.candidate_id??""))||!["wrong_amount","wrong_payer","wrong_destination","ambiguous_reference","outside_window","other"].includes(String(body.reason_code??""))))return {status:422,body:{message:"Motif et référence de revue requis."}};
  try{
    const payload={p_device:id,p_admin:auth.data.id,p_session:sessionId,...(reject?{p_candidate:body.candidate_id,p_reason:body.reason_code}:{})};
    const data=await rest("rpc/"+(reject?"ns_subscription_review_reject":"ns_subscription_review_list"),{method:"POST",headers:serviceHeaders(),body:JSON.stringify(payload)});
    return {status:200,body:{review_result:data}};
  }catch{return {status:403,body:{message:"Revue refusée ou preuve non admissible."}};}
}
async function subscriptionAccess(token:string) {
  const actor=await actorContext(token);
  if(!actor)return {status:403,body:{message:"Session non autorisée."}};
  const data=await rest("rpc/ns_subscription_access_state",{method:"POST",headers:{...anonHeaders(),Authorization:"Bearer "+token},body:JSON.stringify({p_org:actor.member.org_id})});
  return {status:200,body:{subscription_access:data}};
}
async function subscriptionAction(action:string,body:Record<string,unknown>,token:string) {
  const actor=await actorContext(token);
  if(!actor || actor.member.role_code!=="promoter") return {status:403,body:{message:"Gestionnaire de l’organisation requis."}};
  const org=String(actor.member.org_id);
  let rpc:string; let payload:Record<string,unknown>;
  if(action==="subscription_list"){rpc="ns_subscription_list";payload={p_org:org};}
  else if(action==="subscription_create"){rpc="ns_subscription_create";payload={p_org:org,p_plan:body.plan_code,p_months:body.months,p_channel:body.channel};}
  else if(action==="subscription_cancel"){rpc="ns_subscription_cancel";payload={p_id:body.intent_id,p_not_paid:body.not_paid===true};}
  else {rpc="ns_subscription_declare_sms";payload={p_id:body.intent_id,p_sms:body.sms,p_payer:body.payer_number,p_occurred:body.occurred_at??null};}
  try {
    const data=await rest("rpc/"+rpc,{method:"POST",headers:{...anonHeaders(),Authorization:"Bearer "+token},body:JSON.stringify(payload)});
    return {status:200,body:{subscription_result:data}};
  } catch {return {status:409,body:{message:"Paiement non accepté. Vérifiez le SMS, le montant et la destination, ou contactez le support. Aucun abonnement activé sur cette demande."}};}
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: { "Access-Control-Allow-Origin": origin && (ALLOWED_ORIGINS.includes(origin) || ALLOWED_ORIGINS.includes("*")) ? origin : "null", "Access-Control-Allow-Headers": "authorization, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin" } });
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
    else if (action === "request_recovery") result = await requestRecovery(body, request);
    else if (action === "list_recovery_requests") result = await listRecoveryRequests(bearer);
    else if (action === "change_password") result = await changePassword(body, bearer);
    else if (action === "logout") result = await logout(body, bearer);
    else if (action === "provision_member") result = await provisionMember(body, bearer);
    else if (action === "create_site") result = await createSite(body, bearer);
    else if (action === "create_workstation") result = await createWorkstation(body, bearer);
    else if (action === "list_workstations") result = await listWorkstations(body, bearer);
    else if (action === "update_organization_profile") result = await updateOrganizationProfile(body, bearer);
    else if (action === "set_activity_profile") result = await setOrganizationActivityProfile(body, bearer);
    else if (action === "set_member_locale") result = await setMemberPreferredLocale(body, bearer);
    else if (action === "accept_legal_document") result = await acceptLegalDocument(body, bearer);
    else if (action === "complete_onboarding_step") result = await completeOnboardingStep(body, bearer);
    else if (action === "complete_recovery") result = await completeRecovery(body, bearer);
    else if (action === "list_own_devices") result = await listOwnDevices(bearer);
    else if (action === "revoke_device") result = await revokeDevice(body, bearer);
    else if (["subscription_list","subscription_create","subscription_declare","subscription_cancel"].includes(action)) result = await subscriptionAction(action,body,bearer);
    else if (action === "subscription_admin_device_status") result = await subscriptionAdminDeviceStatus(body,bearer);
    else if (action === "subscription_admin_capture") result = await subscriptionAdminCapture(body,bearer);
    else if (["subscription_admin_review_list","subscription_admin_review_reject"].includes(action)) result = await subscriptionAdminReview(action,body,bearer);
    else if (action === "subscription_access") result = await subscriptionAccess(bearer);
    else result = { status: 400, body: { message: "Action non reconnue." } };

    return response(result.status, result.body, origin);
  } catch (_error) {
    // Do not expose internal aliases, account existence, SQL errors or tokens.
    return response(503, { message: "Service indisponible. Réessaie plus tard ou contacte le support." }, origin);
  }
});
