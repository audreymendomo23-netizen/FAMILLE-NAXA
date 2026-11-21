import test from "node:test";
import assert from "node:assert/strict";
import {
  assertSameEventPayload, assertReceiptMatchesEvent, nextRetryAt, classifySyncReceipt,
  canRetrySyncFailure, normalizeQueueBatchLimit,
} from "../src/queue-policy.js";

test("same event ID with same payload is idempotent, changed payload is rejected", () => {
  const item = { eventId: "event-1", payload: "{\"amount\":10}" };
  assert.equal(assertSameEventPayload(item, item), true);
  assert.throws(() => assertSameEventPayload(item, { ...item, payload: "{\"amount\":11}" }), /IDEMPOTENCY_KEY_REUSED/);
});
test("only an applied server receipt acknowledges an event", () => {
  assert.equal(classifySyncReceipt({ status: "applied" }), "acknowledged");
  assert.equal(classifySyncReceipt({ status: "accepted" }), "awaiting_receipt");
  assert.equal(classifySyncReceipt({ status: "conflict" }), "conflict");
  assert.equal(classifySyncReceipt({ status: "rejected" }), "rejected");
  assert.throws(() => classifySyncReceipt({ status: "http_200" }));
});
test("a receipt must be tied to the exact event it acknowledges", () => {
  assert.equal(assertReceiptMatchesEvent("event-1", { eventId: "event-1", status: "applied" }), true);
  assert.throws(() => assertReceiptMatchesEvent("event-1", { eventId: "event-2", status: "applied" }), /SERVER_RECEIPT_EVENT_MISMATCH/);
});
test("retry schedule is bounded and deterministic with injected jitter", () => {
  assert.equal(nextRetryAt(1, 1000, () => 0), 3000);
  assert.equal(nextRetryAt(20, 1000, () => 1), 1801000);
  assert.throws(() => nextRetryAt(0, 1000));
});
test("transient network/provider failures retry but auth and validation failures stop", () => {
  assert.equal(canRetrySyncFailure({ status: null, attemptCount: 1 }), true);
  assert.equal(canRetrySyncFailure({ status: 503, attemptCount: 1 }), true);
  assert.equal(canRetrySyncFailure({ status: 403, attemptCount: 1 }), false);
  assert.equal(canRetrySyncFailure({ status: 422, attemptCount: 1 }), false);
  assert.equal(canRetrySyncFailure({ status: 503, attemptCount: 12 }), false);
});
test("batch sizes are safely clamped", () => {
  assert.equal(normalizeQueueBatchLimit(0), 1);
  assert.equal(normalizeQueueBatchLimit(250), 100);
  assert.throws(() => normalizeQueueBatchLimit(2.5));
});
