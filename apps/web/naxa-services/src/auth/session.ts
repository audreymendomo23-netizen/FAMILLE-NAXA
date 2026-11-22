export interface WebAuthAccount {
  member_id: string;
  display_name: string;
  role_code: string;
  organization_id: string;
  organization_name?: string;
  active_site_ids: string[];
}

export interface WebAuthSession {
  deviceId: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  account: WebAuthAccount;
  requirePasswordChange: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Parse the server response. Never persist access or refresh tokens in browser storage. */
export function parseWebSession(value: unknown, now = Date.now()): WebAuthSession {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError("INVALID_WEB_AUTH_RESPONSE");
  }
  const data = value as Record<string, unknown>;
  const account = data.account;
  if (!account || typeof account !== "object" || Array.isArray(account)) {
    throw new Error("WEB_AUTH_ACCOUNT_MISSING");
  }
  const rawAccount = account as Record<string, unknown>;
  const activeSites = rawAccount.active_site_ids;
  if (
    typeof data.device_id !== "string" || !UUID.test(data.device_id) ||
    typeof data.access_token !== "string" || data.access_token.length < 20 ||
    typeof data.refresh_token !== "string" || data.refresh_token.length < 20 ||
    typeof rawAccount.member_id !== "string" || !UUID.test(rawAccount.member_id) ||
    typeof rawAccount.organization_id !== "string" || !UUID.test(rawAccount.organization_id) ||
    !Array.isArray(activeSites) || !activeSites.every((site) => typeof site === "string" && UUID.test(site))
  ) {
    throw new Error("WEB_AUTH_SESSION_SCOPE_INCOMPLETE");
  }
  const requestedLifetime = Number(data.expires_in);
  const lifetimeSeconds = Math.min(86_400, Math.max(60, Number.isFinite(requestedLifetime) && requestedLifetime > 0 ? requestedLifetime : 3600));
  return Object.freeze({
    deviceId: data.device_id,
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: now + lifetimeSeconds * 1000,
    account: Object.freeze({
      member_id: rawAccount.member_id,
      display_name: typeof rawAccount.display_name === "string" && rawAccount.display_name.trim()
        ? rawAccount.display_name.trim() : "Membre NAXA Services",
      role_code: typeof rawAccount.role_code === "string" ? rawAccount.role_code : "",
      organization_id: rawAccount.organization_id,
      organization_name: typeof rawAccount.organization_name === "string" ? rawAccount.organization_name : "",
      active_site_ids: [...activeSites] as string[],
    }),
    requirePasswordChange: data.require_password_change === true,
  });
}
