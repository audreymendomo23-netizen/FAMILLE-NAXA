const RETRYABLE_HTTP = new Set([408, 425, 429]);
export const MAX_QUEUE_ATTEMPTS = 12;
export const MAX_RETRY_DELAY_MS = 30 * 60 * 1000;

export function assertSameEventPayload(existing, incoming) {
  if (!existing || existing.eventId !== incoming?.eventId) throw new TypeError("INVALID_QUEUE_EVENT");
  if (existing.appId && incoming.appId && existing.appId !== incoming.appId) throw new Error("QUEUE_APP_SCOPE_MISMATCH");
  if ((existing.deviceId || incoming.deviceId) && existing.deviceId !== incoming.deviceId) throw new Error("QUEUE_DEVICE_SCOPE_MISMATCH");
  if ((existing.memberId || incoming.memberId) && existing.memberId !== incoming.memberId) throw new Error("QUEUE_MEMBER_SCOPE_MISMATCH");
  if ((existing.organizationId || incoming.organizationId) && existing.organizationId !== incoming.organizationId) throw new Error("QUEUE_ORGANIZATION_MISMATCH");
  if (existing.payload !== incoming.payload) throw new Error("IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD");
  return true;
}

export function nextRetryAt(attemptCount, now = Date.now(), random = Math.random) {
  if (!Number.isSafeInteger(attemptCount) || attemptCount < 1) throw new RangeError("INVALID_RETRY_ATTEMPT");
  if (!Number.isFinite(now) || typeof random !== "function") throw new TypeError("INVALID_RETRY_CLOCK");
  const base = Math.min(1000 * (2 ** Math.min(attemptCount, 11)), MAX_RETRY_DELAY_MS);
  const jitter = Math.floor(base * 0.2 * Math.max(0, Math.min(1, random())));
  return now + Math.min(MAX_RETRY_DELAY_MS, base + jitter);
}

export function assertReceiptMatchesEvent(eventId, receipt) {
  const receivedId = receipt && typeof receipt === "object" ? (receipt.eventId ?? receipt.event_id) : undefined;
  if (typeof eventId !== "string" || !eventId || typeof receivedId !== "string" || receivedId !== eventId) throw new Error("SERVER_RECEIPT_EVENT_MISMATCH");
  return true;
}
export function nextDeviceSequence(current = 0) {
  if (!Number.isSafeInteger(current) || current < 0 || current >= Number.MAX_SAFE_INTEGER) throw new RangeError("INVALID_DEVICE_SEQUENCE_COUNTER");
  return current + 1;
}

export function classifySyncReceipt(receipt) {
  const state = receipt?.status;
  if (state === "applied") return "acknowledged";
  if (state === "accepted") return "awaiting_receipt";
  if (state === "conflict") return "conflict";
  if (state === "rejected") return "rejected";
  throw new TypeError("INVALID_SERVER_SYNC_RECEIPT");
}

export function canRetrySyncFailure({ status, attemptCount, errorCode }) {
  if (!Number.isSafeInteger(attemptCount) || attemptCount >= MAX_QUEUE_ATTEMPTS) return false;
  if (status == null || RETRYABLE_HTTP.has(status) || status >= 500) return true;
  return ["NETWORK_UNAVAILABLE", "TIMEOUT", "REMOTE_TEMPORARY_FAILURE"].includes(errorCode);
}

export function normalizeQueueBatchLimit(value = 50) {
  if (!Number.isInteger(value)) throw new TypeError("INVALID_QUEUE_BATCH_LIMIT");
  return Math.max(1, Math.min(100, value));
}

export function queueItemBelongsToApp(item, appId) {
  if (typeof appId !== "string" || !appId.trim()) throw new TypeError("INVALID_QUEUE_APP_ID");
  return item?.appId === appId;
}
