import {
  assertSameEventPayload, assertReceiptMatchesEvent, nextRetryAt, classifySyncReceipt,
  canRetrySyncFailure, normalizeQueueBatchLimit, nextDeviceSequence, MAX_QUEUE_ATTEMPTS,
} from "./queue-policy.js";

export type QueueState = "queued" | "sending" | "awaiting_receipt" | "acknowledged" | "retry_wait" | "conflict" | "rejected";
export interface QueueItem {
  appId?: string; eventId: string; payload: string; state: QueueState; createdAt: number;
  deviceId?: string; deviceSequence?: number;
  attemptCount?: number; nextAttemptAt?: number | null; leaseUntil?: number | null;
  lastErrorCode?: string | null; serverReceipt?: unknown;
}

const DB = "famille-naxa-offline";
const STORE = "events";
const META = "meta";
const CHANGES = "changes";
export interface WebSyncChange {
  cursor:number; event_id:string; source_device_id:string; origin_site_id:string|null; site_id:string|null;
  visible_site_ids:string[]; workstation_id:string|null; aggregate_type:string; aggregate_id:string;
  action_code:string; aggregate_version:number; payload:Record<string,unknown>; recorded_at:string;
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 3);
    request.onupgradeneeded = () => {
      const db = request.result;
      const store = db.objectStoreNames.contains(STORE)
        ? request.transaction!.objectStore(STORE)
        : db.createObjectStore(STORE, { keyPath: "eventId" });
      if (!store.indexNames.contains("state_createdAt")) {
        store.createIndex("state_createdAt", ["state", "createdAt"], { unique: false });
      }
      if (!db.objectStoreNames.contains(META)) db.createObjectStore(META, { keyPath: "key" });
      if (!db.objectStoreNames.contains(CHANGES)) db.createObjectStore(CHANGES, { keyPath: "key" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function enqueue(item: QueueItem): Promise<void> {
  if (!item?.eventId || typeof item.payload !== "string" || !item.payload) throw new TypeError("INVALID_QUEUE_EVENT");
  if (item.deviceId !== undefined && (typeof item.deviceId !== "string" || !item.deviceId.trim())) throw new TypeError("INVALID_QUEUE_DEVICE_ID");
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction([STORE, META], "readwrite"), store = tx.objectStore(STORE), meta = tx.objectStore(META);
      const get = store.get(item.eventId);
      get.onsuccess = () => {
        const existing = get.result as QueueItem | undefined;
        if (existing) { try { assertSameEventPayload(existing,item); } catch(e) { tx.abort(); reject(e); } return; }
        const appId = item.appId ?? "default";
        const base = { ...item, appId, state:"queued" as const, attemptCount:0, nextAttemptAt:null, leaseUntil:null };
        if (!item.deviceId) { store.add(base); return; }
        const key = appId + ":" + item.deviceId, current = meta.get(key);
        current.onsuccess = () => {
          try { const sequence = nextDeviceSequence(Number(current.result?.value ?? 0)); meta.put({key,value:sequence}); store.add({...base,deviceSequence:sequence}); }
          catch(e) { tx.abort(); reject(e); }
        };
        current.onerror = () => { tx.abort(); reject(current.error ?? new Error("QUEUE_SEQUENCE_READ_FAILED")); };
      };
      get.onerror = () => { tx.abort(); reject(get.error ?? new Error("QUEUE_EVENT_READ_FAILED")); };
      tx.oncomplete = () => resolve(); tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error ?? new Error("QUEUE_TRANSACTION_ABORTED"));
    });
  } finally { db.close(); }
}
function cursorKey(appId:string,deviceId:string):string {
  if (!appId.trim() || !deviceId.trim()) throw new TypeError("INVALID_SYNC_IDENTITY");
  return appId+":"+deviceId+":cursor";
}
export async function applySyncPage(appId:string,deviceId:string,page:{changes:WebSyncChange[];next_cursor:number;has_more:boolean}):Promise<void> {
  if (!Array.isArray(page?.changes) || !Number.isSafeInteger(page.next_cursor) || page.next_cursor<0 || typeof page.has_more!=="boolean") throw new TypeError("INVALID_SYNC_PAGE");
  for (const c of page.changes) if (!Number.isSafeInteger(c.cursor)||c.cursor<1||c.cursor>page.next_cursor||typeof c.event_id!=="string"||typeof c.action_code!=="string"||typeof c.aggregate_type!=="string"||!c.payload||typeof c.payload!=="object"||Array.isArray(c.payload)) throw new TypeError("INVALID_SYNC_CHANGE");
  const db=await openDb();
  try { await new Promise<void>((resolve,reject)=>{
    const tx=db.transaction([META,CHANGES],"readwrite"),meta=tx.objectStore(META),store=tx.objectStore(CHANGES),key=cursorKey(appId,deviceId),read=meta.get(key);
    read.onsuccess=()=>{if(page.next_cursor<Number(read.result?.value??0)){tx.abort();reject(new Error("SYNC_CURSOR_REGRESSION"));return;}
      for(const c of page.changes)store.put({...c,appId,deviceId,key:appId+":"+deviceId+":"+c.cursor});
      meta.put({key,value:page.next_cursor});};
    read.onerror=()=>{tx.abort();reject(read.error??new Error("SYNC_CURSOR_READ_FAILED"));};
    tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error??new Error("SYNC_PAGE_APPLY_ABORTED"));
  });} finally {db.close();}
}
export async function listAppEvents(appId:string,deviceId:string):Promise<QueueItem[]>{
  const db=await openDb();
  try{return await new Promise<QueueItem[]>((resolve,reject)=>{
    const r=db.transaction(STORE).objectStore(STORE).getAll();
    r.onsuccess=()=>resolve((r.result as QueueItem[]).filter(item=>item.appId===appId&&item.deviceId===deviceId).sort((x,y)=>x.createdAt-y.createdAt));
    r.onerror=()=>reject(r.error);
  });}finally{db.close();}
}
export async function getSyncCursor(appId:string,deviceId:string):Promise<number>{
  const db=await openDb();try{return await new Promise<number>((resolve,reject)=>{const r=db.transaction(META).objectStore(META).get(cursorKey(appId,deviceId));r.onsuccess=()=>resolve(Number(r.result?.value??0));r.onerror=()=>reject(r.error);});}finally{db.close();}
}
export async function listSyncChanges(appId:string,deviceId:string):Promise<WebSyncChange[]>{
  const db=await openDb();try{return await new Promise<WebSyncChange[]>((resolve,reject)=>{const r=db.transaction(CHANGES).objectStore(CHANGES).getAll();r.onsuccess=()=>resolve((r.result as (WebSyncChange&{appId:string;deviceId:string})[]).filter(c=>c.appId===appId&&c.deviceId===deviceId).sort((a,b)=>a.cursor-b.cursor));r.onerror=()=>reject(r.error);});}finally{db.close();}
}

export async function listQueued(appId?: string, deviceId?: string): Promise<QueueItem[]> {
  const db = await openDb();
  try {
    return await new Promise<QueueItem[]>((resolve, reject) => {
      const request = db.transaction(STORE).objectStore(STORE).getAll();
      request.onsuccess = () => resolve((request.result as QueueItem[])
        .filter((item) => (appId == null || item.appId === appId) &&
          (deviceId == null || item.deviceId === deviceId) &&
          (item.state === "queued" || item.state === "retry_wait"))
        .sort((a, b) => a.createdAt - b.createdAt));
      request.onerror = () => reject(request.error);
    });
  } finally { db.close(); }
}

/** Atomically leases a batch so two open tabs do not upload the same queue rows. */
export async function acquireDueBatch(limit = 50, now = Date.now(), leaseMs = 60_000, appId?: string, deviceId?: string): Promise<QueueItem[]> {
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
          .filter((item) => (appId == null || item.appId === appId) &&
            (deviceId == null || item.deviceId === deviceId) &&
            (item.state === "queued" || item.state === "retry_wait" ||
            (item.state === "sending" && (item.leaseUntil ?? 0) <= now)) &&
            (item.nextAttemptAt == null || item.nextAttemptAt <= now) &&
            (item.attemptCount ?? 0) < MAX_QUEUE_ATTEMPTS)
          .sort((a, b) => a.createdAt - b.createdAt)
          .slice(0, take);
        const exhausted = (request.result as QueueItem[]).filter((item) =>
          (appId == null || item.appId === appId) && (deviceId == null || item.deviceId === deviceId) &&
          item.state === "sending" && (item.leaseUntil ?? 0) <= now &&
          (item.attemptCount ?? 0) >= MAX_QUEUE_ATTEMPTS
        );
        for (const item of exhausted) {
          store.put({ ...item, state: "rejected", leaseUntil: null, nextAttemptAt: null,
            lastErrorCode: "MAX_RETRY_ATTEMPTS_EXCEEDED" });
        }
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
export async function applyServerReceipt(eventId: string, receipt: unknown, appId?: string): Promise<QueueState> {
  if (!eventId) throw new TypeError("INVALID_QUEUE_EVENT_ID");
  assertReceiptMatchesEvent(eventId, receipt);
  const state = classifySyncReceipt(receipt);
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      const store = tx.objectStore(STORE);
      const get = store.get(eventId);
      get.onsuccess = () => {
        if (!get.result) { tx.abort(); reject(new Error("QUEUE_EVENT_NOT_FOUND")); return; }
        if (appId != null && (get.result as QueueItem).appId !== appId) { tx.abort(); reject(new Error("QUEUE_APP_SCOPE_MISMATCH")); return; }
        store.put({ ...(get.result as QueueItem), state, serverReceipt: receipt, leaseUntil: null, nextAttemptAt: null });
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_RECEIPT_ABORTED"));
    });
  } finally { db.close(); }
  return state;
}

export async function scheduleRetry(eventId: string, failure: { status?: number | null; errorCode?: string }, now = Date.now(), appId?: string): Promise<boolean> {
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
        if (appId != null && item.appId !== appId) { tx.abort(); reject(new Error("QUEUE_APP_SCOPE_MISMATCH")); return; }
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
export async function setQueueState(eventId: string, state: Exclude<QueueState, "acknowledged" | "awaiting_receipt">, appId?: string): Promise<void> {
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
        if (appId != null && (get.result as QueueItem).appId !== appId) { tx.abort(); reject(new Error("QUEUE_APP_SCOPE_MISMATCH")); return; }
        store.put({ ...(get.result as QueueItem), state, leaseUntil: null });
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error ?? new Error("QUEUE_STATE_ABORTED"));
    });
  } finally { db.close(); }
}
