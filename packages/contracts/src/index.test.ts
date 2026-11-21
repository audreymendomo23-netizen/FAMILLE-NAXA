import { it, expect } from "vitest";
import { decideConflict, validateSyncEnvelope } from "./index";

const envelope = {
  eventId: "10000000-0000-4000-8000-000000000001",
  appId: "naxa-services",
  organizationId: "20000000-0000-4000-8000-000000000001",
  locationId: "30000000-0000-4000-8000-000000000001",
  actorId: "40000000-0000-4000-8000-000000000001",
  deviceId: "50000000-0000-4000-8000-000000000001",
  deviceSessionId: "server-session-fixture",
  aggregateType: "customer",
  aggregateId: "customer-001",
  aggregateVersion: 0,
  deviceSequence: 1,
  occurredAt: "2026-11-21T07:00:00.000Z",
  schemaVersion: 1,
  payload: { display_name: "Fixture customer" },
} as const;

it("requires review for money-bearing domain conflicts", () => {
  for (const kind of ["sale", "payment", "subscription", "cash_session", "expense", "supplier_payment", "commission", "accounting", "referral"] as const) {
    expect(decideConflict(kind, 1, 2)).toBe("manual_review");
  }
});
it("compensates stock conflicts and accepts identical versions", () => {
  expect(decideConflict("inventory", 1, 2)).toBe("compensate");
  expect(decideConflict("inventory_movement", 1, 2)).toBe("compensate");
  expect(decideConflict("customer", 2, 2)).toBe("accept");
});
it("validates complete cross-application synchronization envelope", () => {
  expect(validateSyncEnvelope(envelope)).toEqual(envelope);
});
it("rejects invalid tenant, sequence, device and timestamp metadata", () => {
  for (const invalid of [
    { ...envelope, organizationId: "not-a-uuid" },
    { ...envelope, deviceSequence: 0 },
    { ...envelope, deviceId: "not-a-uuid" },
    { ...envelope, occurredAt: "not-a-date" },
    { ...envelope, aggregateType: "unknown" },
  ]) {
    expect(() => validateSyncEnvelope(invalid)).toThrow();
  }
});
it("rejects oversized and non-object payloads", () => {
  expect(() => validateSyncEnvelope({ ...envelope, payload: "not-object" })).toThrow("INVALID_PAYLOAD");
  expect(() => validateSyncEnvelope({ ...envelope, payload: { notes: "x".repeat(256_001) } })).toThrow("PAYLOAD_TOO_LARGE");
});
