import "fake-indexeddb/auto";
import { beforeEach, describe, expect, it } from "vitest";
import {
  enqueue, listAppEvents, acquireDueBatch, applySyncPage, getSyncCursor, listSyncChanges,
} from "@famille/offline-web";

const APP = "naxa-services-web";
const DEVICE_A = "70000000-0000-4000-8000-000000000001";
const DEVICE_B = "70000000-0000-4000-8000-000000000002";
const ORG = "20000000-0000-4000-8000-000000000001";
const SITE = "30000000-0000-4000-8000-000000000001";

async function clearDatabase() {
  await new Promise<void>((resolve, reject) => {
    const request = indexedDB.deleteDatabase("famille-naxa-offline");
    request.onsuccess = () => resolve();
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error("INDEXEDDB_DELETE_BLOCKED"));
  });
}

beforeEach(async () => {
  await clearDatabase();
});

describe("NAXA Services Web IndexedDB sync storage", () => {
  it("assigns a monotone sequence per device and keeps duplicate event IDs idempotent", async () => {
    const event1 = {
      appId: APP, eventId: "event-device-a-1", deviceId: DEVICE_A,
      payload: JSON.stringify({ action_code: "customer.created", customer_id: "customer-1" }),
      state: "queued" as const, createdAt: 100,
    };
    await enqueue(event1);
    await enqueue({ ...event1, createdAt: 200 });
    await enqueue({
      appId: APP, eventId: "event-device-a-2", deviceId: DEVICE_A,
      payload: JSON.stringify({ action_code: "service.created", service_id: "service-1" }),
      state: "queued", createdAt: 300,
    });
    await enqueue({
      appId: APP, eventId: "event-device-b-1", deviceId: DEVICE_B,
      payload: JSON.stringify({ action_code: "customer.created", customer_id: "customer-b" }),
      state: "queued", createdAt: 400,
    });

    const deviceA = await listAppEvents(APP, DEVICE_A);
    const deviceB = await listAppEvents(APP, DEVICE_B);
    const pendingA = await listQueued(APP, DEVICE_A);
    const pendingB = await listQueued(APP, DEVICE_B);
    expect(deviceA.map((item) => item.deviceSequence)).toEqual([1, 2]);
    expect(deviceA).toHaveLength(2);
    expect(deviceB.map((item) => item.deviceSequence)).toEqual([1]);
    expect(deviceA[0].eventId).toBe("event-device-a-1");
    expect(pendingA.map(item => item.deviceId)).toEqual([DEVICE_A, DEVICE_A]);
    expect(pendingB.map(item => item.deviceId)).toEqual([DEVICE_B]);
  });

  it("leases concurrent batches without returning the same outbox row twice", async () => {
    for (let index = 1; index <= 4; index++) {
      await enqueue({
        appId: APP, eventId: "lease-event-" + index, deviceId: DEVICE_A,
        payload: JSON.stringify({ sequence: index }), state: "queued", createdAt: index,
      });
    }
    await enqueue({
      appId: APP, eventId: "lease-event-device-b", deviceId: DEVICE_B,
      payload: JSON.stringify({ sequence: 1 }), state: "queued", createdAt: 5,
    });
    const [left, right] = await Promise.all([
      acquireDueBatch(3, 10_000, 60_000, APP, DEVICE_A),
      acquireDueBatch(3, 10_000, 60_000, APP, DEVICE_A),
    ]);
    const all = [...left, ...right];
    expect(all).toHaveLength(4);
    expect(new Set(all.map((item) => item.eventId)).size).toBe(4);
    expect(all.every((item) => item.state === "sending" && item.deviceId === DEVICE_A)).toBe(true);
    const otherDeviceBatch = await acquireDueBatch(10, 10_000, 60_000, APP, DEVICE_B);
    expect(otherDeviceBatch).toHaveLength(1);
    expect(otherDeviceBatch[0].deviceId).toBe(DEVICE_B);
  });

  it("stores an inbound page and its cursor atomically and replays it idempotently", async () => {
    const change = {
      cursor: 1,
      event_id: "server-event-1",
      source_device_id: DEVICE_B,
      origin_site_id: SITE,
      site_id: SITE,
      visible_site_ids: [SITE],
      workstation_id: null,
      aggregate_type: "customer",
      aggregate_id: "customer-1",
      action_code: "customer.created",
      aggregate_version: 1,
      payload: { customer_id: "customer-1", display_name: "Client test", org_id: ORG, site_id: SITE },
      recorded_at: "2026-11-22T10:00:00.000Z",
    };
    const page = { changes: [change], next_cursor: 1, has_more: false };
    await applySyncPage(APP, DEVICE_A, page);
    await applySyncPage(APP, DEVICE_A, page);

    expect(await getSyncCursor(APP, DEVICE_A)).toBe(1);
    expect(await listSyncChanges(APP, DEVICE_A)).toHaveLength(1);
    await expect(applySyncPage(APP, DEVICE_A, { changes: [], next_cursor: 0, has_more: false }))
      .rejects.toThrow("SYNC_CURSOR_REGRESSION");
    expect(await getSyncCursor(APP, DEVICE_A)).toBe(1);
    expect(await listSyncChanges(APP, DEVICE_B)).toHaveLength(0);
  });

  it("rejects an inbound change outside its page cursor", async () => {
    await expect(applySyncPage(APP, DEVICE_A, {
      changes: [{
        cursor: 2, event_id: "bad-change", source_device_id: DEVICE_B, origin_site_id: null,
        site_id: SITE, visible_site_ids: [SITE], workstation_id: null,
        aggregate_type: "customer", aggregate_id: "customer-2", action_code: "customer.created",
        aggregate_version: 1, payload: { customer_id: "customer-2" }, recorded_at: "2026-11-22T10:00:00.000Z",
      }],
      next_cursor: 1, has_more: false,
    })).rejects.toThrow("INVALID_SYNC_CHANGE");
    expect(await getSyncCursor(APP, DEVICE_A)).toBe(0);
  });
});
