import { expect, test, type BrowserContext, type Page, type Route } from "@playwright/test";

const AUTH_URL = "https://naxa-services-e2e.invalid/functions/v1/naxa-services-auth";
const ACCOUNTING_URL = "https://naxa-services-e2e.invalid/functions/v1/naxa-services-accounting";
const DEVICE_ID = "70000000-0000-4000-8000-000000000001";
const REMOTE_DEVICE_ID = "70000000-0000-4000-8000-000000000002";
const ORG_A = "20000000-0000-4000-8000-000000000001";
const ORG_B = "20000000-0000-4000-8000-000000000002";
const SITE_ID = "30000000-0000-4000-8000-000000000001";
const MEMBER_A = "60000000-0000-4000-8000-000000000001";
const MEMBER_B = "60000000-0000-4000-8000-000000000002";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

async function json(route: Route, value: unknown, status = 200) {
  await route.fulfill({ status, headers: CORS_HEADERS, body: JSON.stringify(value) });
}

function authSession(organizationId: string) {
  const other = organizationId === ORG_B;
  return {
    device_id: DEVICE_ID,
    access_token: "e2e-access-token-with-more-than-twenty-characters",
    refresh_token: "e2e-refresh-token-with-more-than-twenty-characters",
    expires_in: 3600,
    token_type: "bearer",
    require_password_change: false,
    account: {
      member_id: other ? MEMBER_B : MEMBER_A,
      display_name: other ? "Membre organisation B" : "Membre organisation A",
      role_code: "site_manager",
      organization_id: organizationId,
      organization_name: other ? "Organisation B" : "Organisation A",
      business_mode: "solo",
      default_locale: "fr",
      active_site_ids: [SITE_ID],
      active_sites: [{
        id: SITE_ID,
        code: "SITE-01",
        name: other ? "Site organisation B" : "Site organisation A",
        address_label: "Site de recette",
        phone_contact: "",
      }],
    },
  };
}

async function installBackend(context: BrowserContext, incomingChanges: Record<string, unknown>[] = []) {
  const appliedEvents: Record<string, unknown>[] = [];
  await context.route(AUTH_URL, async (route) => {
    if (route.request().method() === "OPTIONS") return json(route, {}, 200);
    const request = route.request().postDataJSON() as Record<string, unknown>;
    if (request.action === "login") {
      const organizationId = request.identifier === "NS-OTHER" ? ORG_B : ORG_A;
      return json(route, authSession(organizationId));
    }
    if (request.action === "logout") return json(route, { ok: true });
    if (request.action === "refresh") return json(route, authSession(ORG_A));
    if (request.action === "request_recovery") return json(route, { ok: true });
    return json(route, { message: "Unexpected Auth action in browser test." }, 400);
  });

  await context.route(ACCOUNTING_URL, async (route) => {
    if (route.request().method() === "OPTIONS") return json(route, {}, 200);
    const request = route.request().postDataJSON() as Record<string, unknown>;
    if (request.action === "pull_sync_changes") {
      const afterCursor = Number(request.after_cursor ?? 0);
      const changes = incomingChanges.filter((change) => {
        const payload = change.payload as Record<string, unknown> | undefined;
        return Number(change.cursor) > afterCursor && payload?.org_id === request.org_id;
      });
      const nextCursor = changes.length
        ? Math.max(...changes.map((change) => Number(change.cursor)))
        : afterCursor;
      return json(route, { ok: true, result: { changes, next_cursor: nextCursor, has_more: false } });
    }
    if (request.action === "apply_sync_event") {
      const event = request.event as Record<string, unknown>;
      appliedEvents.push(event);
      return json(route, {
        ok: true,
        result: { event_id: event.event_id, status: "applied", recorded_at: "2026-11-23T09:00:00.000Z" },
      });
    }
    if (request.action === "performance") {
      return json(route, { ok: true, result: { daily: [], monthly: [], annual: [] } });
    }
    return json(route, { ok: false, error: "UNEXPECTED_ACCOUNTING_ACTION" }, 400);
  });
  return appliedEvents;
}

async function signIn(page: Page, identifier = "NS-ORG-A") {
  await page.goto("/");
  await page.getByLabel("Identifiant NAXA Services").fill(identifier);
  await page.getByLabel("Mot de passe").fill("E2E-Password-Only-For-Test");
  await page.getByRole("button", { name: "Se connecter" }).click();
  await expect(page.getByRole("heading", { name: "Une journée bien organisée commence ici." })).toBeVisible();
}

async function createCustomer(page: Page, name: string) {
  await page.getByRole("button", { name: /Clients & fidélité/ }).first().click();
  await page.getByRole("button", { name: "Créer une fiche client" }).click();
  await page.getByLabel("Nom du client").fill(name);
  await page.getByLabel("Téléphone facultatif").fill("+237699000111");
  await page.getByRole("button", { name: "Mettre en file & synchroniser" }).click();
}

test("Web: offline outbox survives tab closure, keeps tenant data isolated and converges after server receipt", async ({ context }) => {
  const incoming = [{
    cursor: 1,
    event_id: "server-event-from-android",
    source_device_id: REMOTE_DEVICE_ID,
    origin_site_id: SITE_ID,
    site_id: SITE_ID,
    visible_site_ids: [SITE_ID],
    workstation_id: null,
    aggregate_type: "customer",
    aggregate_id: "customer-from-another-device",
    action_code: "customer.created",
    aggregate_version: 1,
    payload: {
      customer_id: "customer-from-another-device",
      display_name: "Client distant Android",
      org_id: ORG_A,
      site_id: SITE_ID,
    },
    recorded_at: "2026-11-23T09:00:00.000Z",
  }];
  const appliedEvents = await installBackend(context, incoming);

  let page = await context.newPage();
  await signIn(page);
  await expect(page.getByText("customer.created").first()).toBeVisible();

  await context.setOffline(true);
  await createCustomer(page, "Client privé organisation A");
  await expect(page.getByText(/mise en file hors ligne/i)).toBeVisible();
  await expect(page.getByText("Client privé organisation A")).toBeVisible();
  await page.close();

  // Re-authenticate as a different organization on the same browser/device ID.
  await context.setOffline(false);
  page = await context.newPage();
  await signIn(page, "NS-OTHER");
  await page.getByRole("button", { name: /Clients & fidélité/ }).first().click();
  await expect(page.getByText("Client privé organisation A")).toHaveCount(0);
  await expect(page.getByText("Client distant Android")).toHaveCount(0);
  await expect(page.getByRole("button", { name: /Synchroniser \(/ })).toHaveCount(0);
  await page.close();

  // The original organization can still recover its own queued event after re-authentication.
  page = await context.newPage();
  await signIn(page);
  await expect(page.getByRole("button", { name: "Synchroniser (1)" })).toBeVisible();
  await page.getByRole("button", { name: "Synchroniser (1)" }).click();
  await expect.poll(() => appliedEvents.length).toBe(1);
  expect(appliedEvents[0].action_code).toBe("customer.created");
  expect(appliedEvents[0].org_id).toBe(ORG_A);
  await expect(page.getByText("Confirmé par le serveur")).toBeVisible();
  await page.getByRole("button", { name: /Clients & fidélité/ }).first().click();
  await expect(page.getByText("Client distant Android")).toBeVisible();
  await expect(page.getByText("Client privé organisation A")).toBeVisible();
  await page.close();
});

test("IndexedDB real browser: tenant partitions, atomic two-tab leases and independent inbound cursors", async ({ context }) => {
  const pageA = await context.newPage();
  const pageB = await context.newPage();
  await Promise.all([pageA.goto("/e2e/queue-harness.html"), pageB.goto("/e2e/queue-harness.html")]);
  await Promise.all([
    pageA.waitForFunction(() => document.querySelector("#ready")?.textContent === "ready"),
    pageB.waitForFunction(() => document.querySelector("#ready")?.textContent === "ready"),
  ]);

  const appId = "naxa-services-e2e-" + Date.now();
  const item = (eventId: string, organizationId: string) => ({
    appId,
    eventId,
    deviceId: DEVICE_ID,
    organizationId,
    payload: JSON.stringify({ org_id: organizationId, action_code: "customer.created", customer_id: eventId }),
    state: "queued",
    createdAt: Date.now(),
  });
  await pageA.evaluate((value) => (window as any).__naxaQueueHarness.enqueue(value), item("event-org-a", ORG_A));
  await pageA.evaluate((value) => (window as any).__naxaQueueHarness.enqueue(value), item("event-org-b", ORG_B));

  const [batchA, batchB] = await Promise.all([
    pageA.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.acquire(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_A }),
    pageB.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.acquire(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_B }),
  ]);
  expect(batchA.map((event: { eventId: string }) => event.eventId)).toEqual(["event-org-a"]);
  expect(batchB.map((event: { eventId: string }) => event.eventId)).toEqual(["event-org-b"]);

  const [competingA, competingB] = await Promise.all([
    pageA.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.acquire(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_A }),
    pageB.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.acquire(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_A }),
  ]);
  expect(competingA.length + competingB.length).toBe(0);

  const change = (id: string, organizationId: string) => ({
    cursor: 1,
    event_id: "inbound-" + id,
    source_device_id: REMOTE_DEVICE_ID,
    origin_site_id: SITE_ID,
    site_id: SITE_ID,
    visible_site_ids: [SITE_ID],
    workstation_id: null,
    aggregate_type: "customer",
    aggregate_id: id,
    action_code: "customer.created",
    aggregate_version: 1,
    payload: { customer_id: id, display_name: id, org_id: organizationId, site_id: SITE_ID },
    recorded_at: "2026-11-23T09:00:00.000Z",
  });
  await pageA.evaluate(({ appId, deviceId, orgId, change }) =>
    (window as any).__naxaQueueHarness.applyPage(appId, deviceId, { changes: [change], next_cursor: 1, has_more: false }, orgId),
    { appId, deviceId: DEVICE_ID, orgId: ORG_A, change: change("inbound-org-a", ORG_A) },
  );
  await pageB.evaluate(({ appId, deviceId, orgId, change }) =>
    (window as any).__naxaQueueHarness.applyPage(appId, deviceId, { changes: [change], next_cursor: 1, has_more: false }, orgId),
    { appId, deviceId: DEVICE_ID, orgId: ORG_B, change: change("inbound-org-b", ORG_B) },
  );
  const [cursorA, cursorB, visibleA, visibleB] = await Promise.all([
    pageA.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.cursor(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_A }),
    pageB.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.cursor(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_B }),
    pageA.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.changes(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_A }),
    pageB.evaluate(({ appId, deviceId, orgId }) => (window as any).__naxaQueueHarness.changes(appId, deviceId, orgId), { appId, deviceId: DEVICE_ID, orgId: ORG_B }),
  ]);
  expect(cursorA).toBe(1);
  expect(cursorB).toBe(1);
  expect(visibleA.map((change: { aggregate_id: string }) => change.aggregate_id)).toEqual(["inbound-org-a"]);
  expect(visibleB.map((change: { aggregate_id: string }) => change.aggregate_id)).toEqual(["inbound-org-b"]);
  await Promise.all([pageA.close(), pageB.close()]);
});

test("PWA: production service worker keeps the app shell available after offline navigation", async ({ context }) => {
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:4174/");
  await expect(page).toHaveTitle(/NAXA Services/);
  await page.evaluate(async () => {
    if (!("serviceWorker" in navigator)) throw new Error("SERVICE_WORKER_UNSUPPORTED");
    await navigator.serviceWorker.ready;
  });
  await page.waitForFunction(() => Boolean(navigator.serviceWorker.controller));
  await page.reload();
  await page.waitForFunction(() => Boolean(navigator.serviceWorker.controller));
  const manifest = await page.evaluate(async () => {
    const response = await fetch("/manifest.webmanifest");
    if (!response.ok) throw new Error("MANIFEST_NOT_AVAILABLE");
    return response.json();
  });
  expect(manifest.name).toBe("NAXA Services");
  expect(manifest.icons).toEqual(expect.arrayContaining([
    expect.objectContaining({ src: "/naxa-services-icon.svg" }),
  ]));

  await context.setOffline(true);
  await page.close();
  const offlinePage = await context.newPage();
  await offlinePage.goto("http://127.0.0.1:4174/");
  await expect(offlinePage).toHaveTitle(/NAXA Services/);
  await expect(offlinePage.getByLabel("Identifiant NAXA Services")).toBeVisible();
  await expect(offlinePage.getByLabel("Mot de passe")).toBeVisible();
  await offlinePage.close();
});
