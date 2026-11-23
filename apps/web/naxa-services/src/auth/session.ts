import { normalizeActivityProfile, type ActivityProfile } from "../erp/activity-workflows";
export type WebBusinessMode = "solo" | "single_site_multi_workstation" | "multi_site_network";
export type WebLocale = "fr" | "en" | "ff-CM";

export interface WebAuthSite {
  id: string;
  code: string;
  name: string;
  address_label: string;
  phone_contact: string;
}

export interface WebAuthAccount {
  member_id: string;
  display_name: string;
  role_code: string;
  activity_profile: ActivityProfile;
  organization_id: string;
  organization_name: string;
  business_mode: WebBusinessMode;
  default_locale: WebLocale;
  active_site_ids: string[];
  active_sites: WebAuthSite[];
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
const BUSINESS_MODES = new Set<WebBusinessMode>(["solo", "single_site_multi_workstation", "multi_site_network"]);
const LOCALES = new Set<WebLocale>(["fr", "en", "ff-CM"]);

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

  const allowedSiteIds = new Set(activeSites as string[]);
  const rawSiteRecords = rawAccount.active_sites;
  const siteRecords: WebAuthSite[] = [];
  if (rawSiteRecords !== undefined && !Array.isArray(rawSiteRecords)) {
    throw new Error("WEB_AUTH_SITE_RECORDS_INVALID");
  }
  for (const value of (rawSiteRecords ?? []) as unknown[]) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("WEB_AUTH_SITE_RECORDS_INVALID");
    }
    const site = value as Record<string, unknown>;
    if (typeof site.id !== "string" || !UUID.test(site.id) || !allowedSiteIds.has(site.id)) {
      throw new Error("WEB_AUTH_SITE_SCOPE_MISMATCH");
    }
    siteRecords.push(Object.freeze({
      id: site.id,
      code: typeof site.code === "string" ? site.code : "",
      name: typeof site.name === "string" ? site.name : "",
      address_label: typeof site.address_label === "string" ? site.address_label : "",
      phone_contact: typeof site.phone_contact === "string" ? site.phone_contact : "",
    }));
  }

  const requestedLifetime = Number(data.expires_in);
  const lifetimeSeconds = Math.min(86_400, Math.max(60, Number.isFinite(requestedLifetime) && requestedLifetime > 0 ? requestedLifetime : 3600));
  const requestedMode = rawAccount.business_mode;
  const requestedLocale = rawAccount.default_locale;
  const displayName = typeof rawAccount.display_name === "string" && rawAccount.display_name.trim()
    ? rawAccount.display_name.trim() : "Membre NAXA Services";

  return Object.freeze({
    deviceId: data.device_id,
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: now + lifetimeSeconds * 1000,
    account: Object.freeze({
      member_id: rawAccount.member_id,
      display_name: displayName,
      role_code: typeof rawAccount.role_code === "string" ? rawAccount.role_code : "",
      activity_profile: normalizeActivityProfile(rawAccount.activity_profile),
      organization_id: rawAccount.organization_id,
      organization_name: typeof rawAccount.organization_name === "string" ? rawAccount.organization_name : "",
      business_mode: BUSINESS_MODES.has(requestedMode as WebBusinessMode) ? requestedMode as WebBusinessMode : "solo",
      default_locale: LOCALES.has(requestedLocale as WebLocale) ? requestedLocale as WebLocale : "fr",
      active_site_ids: [...activeSites] as string[],
      active_sites: Object.freeze(siteRecords) as unknown as WebAuthSite[],
    }),
    requirePasswordChange: data.require_password_change === true,
  });
}
