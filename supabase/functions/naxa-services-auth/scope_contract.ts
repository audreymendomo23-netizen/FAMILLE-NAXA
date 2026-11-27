export type NaxaBusinessMode =
  | "solo"
  | "single_site_multi_workstation"
  | "multi_site_network";

const BUSINESS_MODES: readonly NaxaBusinessMode[] = [
  "solo",
  "single_site_multi_workstation",
  "multi_site_network",
];

export const NAXA_ACTIVITY_PROFILES = [
  "pressing", "coiffure", "couture", "beaute", "parfumerie", "reparation",
  "menuiserie", "garage", "nettoyage", "domicile", "impression",
  "photo_evenementiel", "autre",
] as const;
export type NaxaActivityProfile = typeof NAXA_ACTIVITY_PROFILES[number];

export function isNaxaActivityProfile(value: string): value is NaxaActivityProfile {
  return NAXA_ACTIVITY_PROFILES.includes(value as NaxaActivityProfile);
}

export const NAXA_WORKSTATION_KINDS = [
  "hair_chair", "pressing_counter", "pressing_workshop", "reception", "cashier", "other",
] as const;
export type NaxaWorkstationKind = typeof NAXA_WORKSTATION_KINDS[number];

export function isNaxaWorkstationKind(value: string): value is NaxaWorkstationKind {
  return NAXA_WORKSTATION_KINDS.includes(value as NaxaWorkstationKind);
}

export function isNaxaSiteCode(value: string): boolean {
  return /^[A-Z0-9][A-Z0-9_-]{1,19}$/.test(value.trim().toUpperCase());
}

export function isNaxaWorkstationCode(value: string): boolean {
  return /^[A-Z0-9][A-Z0-9_-]{1,19}$/.test(value.trim().toUpperCase());
}

export function isNaxaLocale(value: string): value is "fr" | "en" | "ff-CM" {
  return value === "fr" || value === "en" || value === "ff-CM";
}

export function isLegalDocumentVersion(type: string, version: string): boolean {
  const versions: Record<string, string> = {
    terms: "2026-11-v1",
    privacy: "2026-11-v1",
  };
  return versions[type] === version;
}

export function isNaxaBusinessMode(value: string): value is NaxaBusinessMode {
  return BUSINESS_MODES.includes(value as NaxaBusinessMode);
}

/**
 * The current Android ERP reads and writes at site scope. A workstation-only
 * assignment must never be promoted to whole-site visibility. Organization
 * scope receives only the active site IDs supplied by the trusted server.
 */
export function nativeSiteIdsForScopes(
  scopes: readonly Record<string, unknown>[],
  activeOrganizationSiteIds: readonly string[] = [],
): string[] {
  const hasOrganizationScope = scopes.some((scope) => scope.scope_type === "organization");
  if (hasOrganizationScope) return [...new Set(activeOrganizationSiteIds)];
  const explicitSiteIds = scopes.flatMap((scope) =>
    scope.scope_type === "site" && scope.site_id ? [String(scope.site_id)] : []
  );
  return [...new Set(explicitSiteIds)];
}

/** Only a genuine organization-wide manager grant may authorize the shared offline ERP. */
export function allowsOrganizationOffline(role: string, scopes: readonly Record<string, unknown>[]): boolean {
  return ["promoter", "network_manager"].includes(role) && scopes.some(s =>
    s.scope_type === "organization" && s.can_read === true &&
    s.can_operate === true && s.can_manage === true
  );
}
