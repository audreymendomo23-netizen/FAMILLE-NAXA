import {
  assertSameEventPayload, nextRetryAt, classifySyncReceipt,
  canRetrySyncFailure, normalizeQueueBatchLimit, MAX_QUEUE_ATTEMPTS,
} from "./queue-policy.js";

export type QueueState = "queued" | "sending" | "awaiting_receipt" | "acknowledged" | "retry_wait" | "conflict" | "rejected";
export interface QueueItem {
  eventId: string; payload: string; state: QueueState; createdAt: number;
  attemptCount?: number; nextAttemptAt?: number | null; leaseUntil?: number | null;
  lastErrorCode?: string | null; serverReceipt?: unknown;
}

const DB = "famille-naxa-offline";
const STORE = "events";

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 2);
    request.onupgradeneeded = () => {
      const db = request.result;
      const store = db.objectStoreNames.contains(STORE)
        ? request.transaction!.objectStore(STORE)
        : db.createObjectStore(STORE, { keyPath: "eventId" });
      if (!store.indexNames.contains("state_createdAt")) {
        store.createIndex("state_createdAt", ["state", "createdAt"], { unique: false });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function enqueue(item: QueueItem): Promise<void> {
  if (!item?.eventId || typeof item.payload !== "string" || !item.payload) throw new TypeError("INVALID_QUEUE_EVENT");
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const get = store.get(item.eventId);
      get.onsuccess = () => {
        const existing = get.result as QueueItem | undefined;
        if (existing) {
          try { assertSameEventPayload(existing, item); }
          catch (error) { tx.abort(); reject(error); return; }
        } else {
          store.add({ ...item, state: "queued", attemptCount: 0, nextAttemptAt: null, leaseUntil: null });
        }
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_TRANSACTION_ABORTED"));
    });
  } finally { db.close(); }
}

export async function listQueued(): Promise<QueueItem[]> {
  const db = await openDb();
  try {
    return await new Promise<QueueItem[]>((resolve, reject) => {
      const request = db.transaction(STORE).objectStore(STORE).getAll();
      request.onsuccess = () => resolve((request.result as QueueItem[])
        .filter((item) => item.state === "queued" || item.state === "retry_wait")
        .sort((a, b) => a.createdAt - b.createdAt));
      request.onerror = () => reject(request.error);
    });
  } finally { db.close(); }
}

/** Atomically leases a batch so two open tabs do not upload the same queue rows. */
export async function acquireDueBatch(limit = 50, now = Date.now(), leaseMs = 60_000): Promise<QueueItem[]> {
  const take = normalizeQueueBatchLimit(limit);
  if (!Number.isFinite(now) || !Number.isSafeInteger(leaseMs) || leaseMs < 5_000) throw new RangeError("INVALID_QUEUE_LEASE");
  const db = await openDb();
  try {
    return await new Promise<QueueItem[]>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const request = store.getAll();
      let acquired: QueueItem[] = [];
      request.onsuccess = () => {
        const due = (request.result as QueueItem[])
          .filter((item) => (item.state === "queued" || item.state === "retry_wait" ||
            (item.state === "sending" && (item.leaseUntil ?? 0) <= now)) &&
            (item.nextAttemptAt == null || item.nextAttemptAt <= now) &&
            (item.attemptCount ?? 0) < MAX_QUEUE_ATTEMPTS)
          .sort((a, b) => a.createdAt - b.createdAt)
          .slice(0, take);
        acquired = due.map((item) => ({
          ...item, state: "sending", attemptCount: (item.attemptCount ?? 0) + 1,
          leaseUntil: now + leaseMs,
        }));
        for (const item of acquired) store.put(item);
      };
      tx.oncomplete = () => resolve(acquired);
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_LEASE_ABORTED"));
    });
  } finally { db.close(); }
}

/** Only an explicit server receipt may complete a queue item. HTTP 200/202 is not enough. */
export async function applyServerReceipt(eventId: string, receipt: unknown): Promise<QueueState> {
  if (!eventId) throw new TypeError("INVALID_QUEUE_EVENT_ID");
  const state = classifySyncReceipt(receipt);
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const get = store.get(eventId);
      get.onsuccess = () => {
        if (!get.result) { tx.abort(); reject(new Error("QUEUE_EVENT_NOT_FOUND")); return; }
        store.put({ ...(get.result as QueueItem), state, serverReceipt: receipt, leaseUntil: null, nextAttemptAt: null });
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_RECEIPT_ABORTED"));
    });
  } finally { db.close(); }
  return state;
}

export async function scheduleRetry(eventId: string, failure: { status?: number | null; errorCode?: string }, now = Date.now()): Promise<boolean> {
  if (!eventId) throw new TypeError("INVALID_QUEUE_EVENT_ID");
  const db = await openDb();
  try {
    return await new Promise<boolean>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const get = store.get(eventId);
      let retry = false;
      get.onsuccess = () => {
        const item = get.result as QueueItem | undefined;
        if (!item) { tx.abort(); reject(new Error("QUEUE_EVENT_NOT_FOUND")); return; }
        retry = canRetrySyncFailure({ status: failure.status, attemptCount: item.attemptCount ?? 0, errorCode: failure.errorCode });
        store.put({
          ...item, state: retry ? "retry_wait" : "rejected",
          nextAttemptAt: retry ? nextRetryAt(Math.max(1, item.attemptCount ?? 1), now) : null,
          leaseUntil: null, lastErrorCode: failure.errorCode ?? "REMOTE_REQUEST_FAILED",
        });
      };
      tx.oncomplete = () => resolve(retry);
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_RETRY_ABORTED"));
    });
  } finally { db.close(); }
}

// Compatibility helper. It deliberately cannot mark an item acknowledged.
export async function setQueueState(eventId: string, state: Exclude<QueueState, "acknowledged" | "awaiting_receipt">): Promise<void> {
  if (!eventId || !["queued", "sending", "retry_wait", "conflict", "rejected"].includes(state)) {
    throw new TypeError("INVALID_QUEUE_STATE");
  }
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const get = store.get(eventId);
      get.onsuccess = () => {
        if (!get.result) { tx.abort(); reject(new Error("QUEUE_EVENT_NOT_FOUND")); return; }
        store.put({ ...(get.result as QueueItem), state, leaseUntil: null });
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_STATE_ABORTED"));
    });
  } finally { db.close(); }
}
