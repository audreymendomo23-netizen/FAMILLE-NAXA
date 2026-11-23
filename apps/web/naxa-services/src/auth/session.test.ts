import { describe, expect, it } from "vitest";
import { parseWebSession } from "./session";

const valid = {
  device_id: "70000000-0000-4000-8000-000000000001",
  access_token: "access-token-with-at-least-twenty-characters",
  refresh_token: "refresh-token-with-at-least-twenty-characters",
  expires_in: 1800,
  require_password_change: false,
  account: {
    member_id: "60000000-0000-4000-8000-000000000001",
    organization_id: "20000000-0000-4000-8000-000000000001",
    organization_name: "NAXA Services CI",
    display_name: "Test member",
    role_code: "site_manager",
    business_mode: "multi_site_network",
    default_locale: "en",
    active_site_ids: ["30000000-0000-4000-8000-000000000001"],
    active_sites: [{
      id: "30000000-0000-4000-8000-000000000001",
      code: "DOU-01",
      name: "Douala principal",
      address_label: "Bonanjo",
      phone_contact: "+237600000000",
    }],
  },
};

describe("Web authentication session", () => {
  it("accepts a complete server session and derives the expiry", () => {
    const session = parseWebSession(valid, 1000);
    expect(session.deviceId).toBe(valid.device_id);
    expect(session.accessToken).toBe(valid.access_token);
    expect(session.refreshToken).toBe(valid.refresh_token);
    expect(session.expiresAt).toBe(1_801_000);
    expect(session.account.active_site_ids).toHaveLength(1);
    expect(session.account.active_sites[0].name).toBe("Douala principal");
    expect(session.account.business_mode).toBe("multi_site_network");
    expect(session.account.default_locale).toBe("en");
    expect(Object.isFrozen(session.account.active_sites)).toBe(true);
  });

  it("rejects missing tokens, account scope and malformed site IDs", () => {
    expect(() => parseWebSession({ ...valid, device_id:"invalid" })).toThrow();
    expect(() => parseWebSession({ ...valid, refresh_token: "" })).toThrow();
    expect(() => parseWebSession({ ...valid, account: { ...valid.account, organization_id: "bad" } })).toThrow();
    expect(() => parseWebSession({ ...valid, account: { ...valid.account, active_site_ids: ["bad"] } })).toThrow();
    expect(() => parseWebSession({
      ...valid,
      account: { ...valid.account, active_sites: [{ ...valid.account.active_sites[0], id: "40000000-0000-4000-8000-000000000001" }] },
    })).toThrow(/WEB_AUTH_SITE_SCOPE_MISMATCH/);
  });

  it("bounds untrusted expiry to one minute minimum and one day maximum", () => {
    expect(parseWebSession({ ...valid, expires_in: 1 }, 1000).expiresAt).toBe(61_000);
    expect(parseWebSession({ ...valid, expires_in: 999_999 }, 1000).expiresAt).toBe(86_401_000);
  });

  it("freezes the returned session and scoped account", () => {
    const session = parseWebSession(valid);
    expect(Object.isFrozen(session)).toBe(true);
    expect(Object.isFrozen(session.account)).toBe(true);
  });
});
