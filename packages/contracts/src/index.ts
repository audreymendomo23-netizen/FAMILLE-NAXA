export type AppId =
  | "kiosko" | "bootik" | "zipple" | "naxa-services" | "cotiz"
  | "loyable" | "naxa-hotel" | "campus237" | "naxa-security" | "jobly" | "naxa" | "grillad";

export type DomainKind =
  | "catalog" | "profile" | "inventory" | "inventory_movement"
  | "customer" | "crm" | "sale" | "payment" | "cash_session" | "expense"
  | "subscription" | "booking" | "appointment" | "pressing" | "delivery"
  | "security" | "supplier" | "purchase" | "purchase_receipt" | "supplier_payment"
  | "workforce" | "commission" | "accounting" | "loyalty" | "recurring_charge"
  | "referral" | "notification";

export type ConflictDecision = "accept" | "manual_review" | "compensate";

/**
 * Money-bearing events are never resolved by last-write-wins.
 * Inventory is corrected with a compensating movement, never by overwriting a quantity.
 */
const FINANCIAL_DOMAINS = new Set<DomainKind>([
  "sale", "payment", "subscription", "cash_session", "expense",
  "supplier_payment", "commission", "accounting", "referral",
]);

export function decideConflict(kind: DomainKind, expected: number, actual: number): ConflictDecision {
  if (expected === actual) return "accept";
  if (FINANCIAL_DOMAINS.has(kind)) return "manual_review";
  if (kind === "inventory" || kind === "inventory_movement") return "compensate";
  return "manual_review";
}

export type PaymentState = "initiated" | "pending" | "confirmed" | "failed" | "expired" | "cancelled" | "refunded" | "reversed";
export type NotificationState = "created" | "queued" | "sent" | "received" | "read" | "actioned" | "failed";
export type SyncReceiptState = "accepted" | "applied" | "conflict" | "rejected";

export interface SyncEnvelope<T = unknown> {
  eventId: string;
  appId: AppId;
  organizationId: string;
  locationId?: string;
  actorId: string;
  deviceId: string;
  deviceSessionId?: string;
  aggregateType: DomainKind;
  aggregateId: string;
  aggregateVersion: number;
  deviceSequence: number;
  occurredAt: string;
  schemaVersion: 1;
  payload: T;
}

export type SyncEnvelopeError =
  | "INVALID_EVENT_ID" | "INVALID_APP_ID" | "INVALID_ORGANIZATION_ID"
  | "INVALID_LOCATION_ID" | "INVALID_ACTOR_ID" | "INVALID_DEVICE_ID"
  | "INVALID_DEVICE_SESSION" | "INVALID_AGGREGATE_TYPE" | "INVALID_AGGREGATE_ID"
  | "INVALID_AGGREGATE_VERSION" | "INVALID_DEVICE_SEQUENCE"
  | "INVALID_OCCURRED_AT" | "INVALID_SCHEMA_VERSION" | "INVALID_PAYLOAD"
  | "PAYLOAD_TOO_LARGE";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const APP_IDS = new Set<AppId>([
  "kiosko", "bootik", "zipple", "naxa-services", "cotiz",
  "loyable", "naxa-hotel", "campus237", "naxa-security", "jobly", "naxa", "grillad",
]);
const DOMAIN_KINDS = new Set<DomainKind>([
  "catalog", "profile", "inventory", "inventory_movement", "customer", "crm",
  "sale", "payment", "cash_session", "expense", "subscription", "booking",
  "appointment", "pressing", "delivery", "security", "supplier", "purchase",
  "purchase_receipt", "supplier_payment", "workforce", "commission", "accounting",
  "loyalty", "recurring_charge", "referral", "notification",
]);

export function validateSyncEnvelope<T = unknown>(value: unknown): SyncEnvelope<T> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("INVALID_PAYLOAD");
  const input = value as Record<string, unknown>;

  if (typeof input.eventId !== "string" || !UUID.test(input.eventId)) throw new Error("INVALID_EVENT_ID");
  if (typeof input.appId !== "string" || !APP_IDS.has(input.appId as AppId)) throw new Error("INVALID_APP_ID");
  if (typeof input.organizationId !== "string" || !UUID.test(input.organizationId)) throw new Error("INVALID_ORGANIZATION_ID");
  if (input.locationId !== undefined && (typeof input.locationId !== "string" || !UUID.test(input.locationId))) {
    throw new Error("INVALID_LOCATION_ID");
  }
  if (typeof input.actorId !== "string" || !UUID.test(input.actorId)) throw new Error("INVALID_ACTOR_ID");
  if (typeof input.deviceId !== "string" || !UUID.test(input.deviceId)) throw new Error("INVALID_DEVICE_ID");
  if (input.deviceSessionId !== undefined &&
      (typeof input.deviceSessionId !== "string" || input.deviceSessionId.trim().length < 8 || input.deviceSessionId.length > 200)) {
    throw new Error("INVALID_DEVICE_SESSION");
  }
  if (typeof input.aggregateType !== "string" || !DOMAIN_KINDS.has(input.aggregateType as DomainKind)) {
    throw new Error("INVALID_AGGREGATE_TYPE");
  }
  if (typeof input.aggregateId !== "string" || input.aggregateId.trim().length < 1 || input.aggregateId.length > 128) {
    throw new Error("INVALID_AGGREGATE_ID");
  }
  if (!Number.isSafeInteger(input.aggregateVersion) || Number(input.aggregateVersion) < 0) {
    throw new Error("INVALID_AGGREGATE_VERSION");
  }
  if (!Number.isSafeInteger(input.deviceSequence) || Number(input.deviceSequence) < 1) {
    throw new Error("INVALID_DEVICE_SEQUENCE");
  }
  if (typeof input.occurredAt !== "string" || !Number.isFinite(Date.parse(input.occurredAt))) {
    throw new Error("INVALID_OCCURRED_AT");
  }
  if (input.schemaVersion !== 1) throw new Error("INVALID_SCHEMA_VERSION");
  if (!input.payload || typeof input.payload !== "object" || Array.isArray(input.payload)) {
    throw new Error("INVALID_PAYLOAD");
  }
  const payloadBytes = new TextEncoder().encode(JSON.stringify(input.payload)).byteLength;
  if (payloadBytes > 256_000) throw new Error("PAYLOAD_TOO_LARGE");

  return input as unknown as SyncEnvelope<T>;
}
