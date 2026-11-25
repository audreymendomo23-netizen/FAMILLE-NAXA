import { expect, test, type BrowserContext, type Page, type Route } from "@playwright/test";
import { ACTIVITY_WORKFLOWS, type ActivityProfile } from "../src/erp/activity-workflows";

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

function authSession(organizationId: string, activityProfile = "autre") {
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
      activity_profile: activityProfile,
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
      const identifier = typeof request.identifier === "string" ? request.identifier : "";
      const activityProfile = identifier.startsWith("NS-ACT-") ? identifier.slice("NS-ACT-".length).toLowerCase() : "autre";
      return json(route, authSession(organizationId, activityProfile));
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
      const payload = event.payload as Record<string, unknown>;
      appliedEvents.push(event);
      const revision = typeof payload.expected_version === "number" ? payload.expected_version + 1 : 1;
      const actionCode = typeof event.action_code === "string" ? event.action_code : "";
      // Pressing transitions encode the target status in the action suffix, like ns_apply_sync_event.
      const pressingStatus = actionCode.startsWith("pressing_order.status_changed:")
        ? actionCode.slice("pressing_order.status_changed:".length) : null;
      const status = actionCode === "cash_session.opened" ? "open"
        : actionCode === "cash_session.closed" ? "closed"
        : typeof payload.to_status === "string" ? payload.to_status
        : typeof payload.status === "string" ? payload.status
        : pressingStatus ?? "received";
      return json(route, {
        ok: true,
        result: {
          event_id: event.event_id, status: "applied", recorded_at: "2026-11-23T09:00:00.000Z",
          result: { record_id: event.aggregate_id, status, revision },
        },
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


function activityCompletionPath(profile: ActivityProfile): string[] {
  const workflow = ACTIVITY_WORKFLOWS[profile];
  const destination = profile === "pressing" ? "picked_up" : "closed";
  const queue: Array<{ code: string; path: string[] }> = [{ code: "received", path: ["received"] }];
  const visited = new Set<string>(["received"]);
  while (queue.length) {
    const current = queue.shift()!;
    if (current.code === destination) return current.path;
    const stage = workflow.stages.find((item) => item.code === current.code);
    for (const next of stage?.next ?? []) {
      if (visited.has(next)) continue;
      visited.add(next);
      queue.push({ code: next, path: [...current.path, next] });
    }
  }
  throw new Error("No complete path from received to " + destination + " for " + profile);
}
const ACTIVITY_RECIPES = [
  { profile: "coiffure", aggregate: "service_order", fields: { style: "tresses", technique: "Tresses protectrices, longueur épaules" } },
  { profile: "couture", aggregate: "work_order", fields: { garment: "Robe sur mesure", measurements: "Poitrine 92 cm; taille 76 cm; hanches 100 cm" } },
  { profile: "beaute", aggregate: "service_order", fields: { treatment: "soin_visage", protocol: "Nettoyage et hydratation non médicaux" } },
  { profile: "parfumerie", aggregate: "work_order", fields: { product: "Eau de parfum test", format: "50ml" } },
  { profile: "reparation", aggregate: "repair_order", fields: { device: "Ordinateur portable, série TEST-001", fault: "Ne démarre plus" } },
  { profile: "menuiserie", aggregate: "work_order", fields: { piece: "Armoire 3 portes", dimensions: "180 × 120 × 55 cm, plan client version 1" } },
  { profile: "garage", aggregate: "repair_order", fields: { vehicle: "Toyota Corolla, immatriculation TEST-237", fault: "Révision et bruit au freinage" } },
  { profile: "nettoyage", aggregate: "service_order", fields: { site: "Bureau test, Bonamoussadi", tasks: "Sols, sanitaires, vitres et déchets" } },
  { profile: "domicile", aggregate: "service_order", fields: { address: "Douala, Bonapriso, repère test", service: "Installation d'un ventilateur au domicile" } },
  { profile: "impression", aggregate: "work_order", fields: { format: "A4", quantity: "250" } },
  { profile: "photo_evenementiel", aggregate: "work_order", fields: { event: "Cérémonie familiale test", date: "2026-11-28", deliverables: "1 album photo et 150 fichiers numériques" } },
  { profile: "autre", aggregate: "work_order", fields: { service: "Prestation personnalisée", specifications: "Description métier configurable à valider avec le client" } },
] as const;

test("Web: every non-Pressing activity completes its own server-backed métier journey", async ({ context }) => {
  test.setTimeout(120_000);
  const appliedEvents = await installBackend(context);
  let expectedEventCount = 0;
  for (const recipe of ACTIVITY_RECIPES) {
    const page = await context.newPage();
    await signIn(page, "NS-ACT-" + recipe.profile.toUpperCase());
    await page.getByRole("button", { name: "Dossiers métier" }).click();
    await expect(page.getByText("PARCOURS MÉTIER · " + recipe.profile.toUpperCase(), { exact: true })).toBeVisible();
    await page.getByLabel("Client / donneur d'ordre").fill("Client recette " + recipe.profile);
    await page.getByLabel("Intitulé du dossier").fill("Dossier " + recipe.profile);
    for (const [key, value] of Object.entries(recipe.fields)) {
      const control = page.locator('[data-activity-field="' + key + '"]').locator("input,textarea,select");
      const tag = await control.evaluate((element) => element.tagName.toLowerCase());
      const type = await control.getAttribute("type");
      if (tag === "select") await control.selectOption(value);
      else await control.fill(value);
      expect(type === "number" || tag === "select" || tag === "textarea" || type === "date" || type === "text").toBe(true);
    }
    await page.getByRole("button", { name: "Créer et synchroniser le dossier" }).click();
    expectedEventCount += 1;
    await expect.poll(() => appliedEvents.length).toBe(expectedEventCount);
    const event = appliedEvents[expectedEventCount - 1];
    expect(event.aggregate_type).toBe(recipe.aggregate);
    expect(event.action_code).toBe(recipe.aggregate + ".created");
    expect((event.payload as Record<string, unknown>).status).toBe("received");
    expect(((event.payload as Record<string, unknown>).metadata_json as Record<string, unknown>).activity).toBe(recipe.profile);
    const workflow = ACTIVITY_WORKFLOWS[recipe.profile];
    const path = activityCompletionPath(recipe.profile);
    let currentStatus = "received";
    let expectedRevision = 1;
    for (const nextStatus of path.slice(1)) {
      const nextStage = workflow.stages.find((stage) => stage.code === nextStatus);
      expect(nextStage, recipe.profile + " missing stage " + nextStatus).toBeTruthy();
      await page.getByLabel("Motif du changement d'étape").fill("Recette métier — " + nextStatus);
      await page.getByRole("button", { name: nextStage!.label, exact: true }).click();
      expectedEventCount += 1;
      await expect.poll(() => appliedEvents.length).toBe(expectedEventCount);
      const transition = appliedEvents[expectedEventCount - 1];
      expect(transition.aggregate_type).toBe(recipe.aggregate);
      expect(transition.action_code).toBe(recipe.aggregate + ".status_changed");
      const transitionPayload = transition.payload as Record<string, unknown>;
      expect(transitionPayload.from_status).toBe(currentStatus);
      expect(transitionPayload.to_status).toBe(nextStatus);
      expect(transitionPayload.expected_version).toBe(expectedRevision);
      currentStatus = nextStatus;
      expectedRevision += 1;
    }
    expect(currentStatus).toBe("closed");
    await page.close();
  }
});

test("Web: Pressing keeps its dedicated ticket journey and waits for a server receipt before status transition", async ({ context }) => {
  const appliedEvents = await installBackend(context);
  const page = await context.newPage();
  await signIn(page, "NS-ACT-PRESSING");
  await page.locator(".side-nav button.nav-item").filter({ hasText: "Pressing" }).click();
  await page.getByRole("button", { name: "Créer un ticket" }).click();
  await page.getByLabel("Nom du client").fill("Client pressing test");
  await page.getByLabel("Téléphone client").fill("+237699000111");
  await page.getByLabel("Articles déposés").fill("2 chemises — lavage et repassage; 1 costume — nettoyage à sec");
  await page.getByLabel("Montant total FCFA").fill("3500");
  await page.getByLabel("Date promise").fill("2026-11-25T17:00");
  await page.getByRole("button", { name: "Mettre en file & synchroniser" }).click();
  await expect.poll(() => appliedEvents.length).toBe(1);
  expect(appliedEvents[0].action_code).toBe("pressing_order.created");
  expect(appliedEvents[0].aggregate_type).toBe("pressing_order");
  await expect(page.getByText("Client pressing test")).toBeVisible();
  await page.getByLabel("Motif du changement d'étape").fill("Tri et traitement démarrés");
  await page.getByRole("button", { name: "Passer à En cours" }).click();
  await expect.poll(() => appliedEvents.length).toBe(2);
  expect(appliedEvents[1].action_code).toBe("pressing_order.status_changed:in_progress");
  expect((appliedEvents[1].payload as Record<string, unknown>).expected_version).toBe(1);
  const pressingStatusBadge = page.locator(".activity-record .record .status-tag");
  await expect(pressingStatusBadge).toHaveText("En cours");
  const pressingSteps = [
    { label: "Passer à Prêt", action: "pressing_order.status_changed:ready", status: "ready", revision: 2 },
    { label: "Passer à Retiré", action: "pressing_order.status_changed:picked_up", status: "picked_up", revision: 3 },
  ];
  for (const step of pressingSteps) {
    await page.getByLabel("Motif du changement d'étape").fill("Recette pressing — " + step.status);
    await page.getByRole("button", { name: step.label, exact: true }).click();
    await expect.poll(() => appliedEvents.length).toBe(step.revision + 1);
    const transition = appliedEvents[step.revision];
    expect(transition.action_code).toBe(step.action);
    expect((transition.payload as Record<string, unknown>).expected_version).toBe(step.revision);
    await expect(pressingStatusBadge).toHaveText(step.status === "ready" ? "Prêt" : "Retiré");
  }
  await page.close();
});

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
  await page.getByRole("button", { name: /Clients & fidélité/ }).first().click();
  await expect(page.getByText("Confirmé par le serveur")).toBeVisible();
  await expect(page.locator(".module-layout .module-main-card").last().locator(".record").filter({ hasText: "Client distant Android" })).toBeVisible();
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


test("Web N4-C: cash register, cash session, cash sale and close require server receipts", async ({ context }) => {
  const appliedEvents = await installBackend(context);
  const page = await context.newPage();
  await signIn(page);
  await page.locator(".side-nav button.nav-item").filter({ hasText: "Caisse & ventes" }).click();

  await page.getByLabel("Code unique").fill("E2E-CAISSE");
  await page.getByLabel("Nom du registre").fill("Caisse recette");
  await page.getByRole("button", { name: "Créer le registre avec reçu serveur" }).click();
  await expect.poll(() => appliedEvents.length).toBe(1);
  expect(appliedEvents[0].action_code).toBe("cash_register.created");
  expect(appliedEvents[0].aggregate_type).toBe("cash_register");
  await expect(page.getByRole("heading", { name: "Ouvrir une session" })).toBeVisible();

  await page.getByLabel("Fonds d'ouverture (FCFA)").fill("5000");
  await page.getByRole("button", { name: "Ouvrir la caisse" }).click();
  await expect.poll(() => appliedEvents.length).toBe(2);
  expect(appliedEvents[1].action_code).toBe("cash_session.opened");
  expect((appliedEvents[1].payload as Record<string, unknown>).opening_float_xaf).toBe(5000);
  await expect(page.getByRole("heading", { name: "Session actuellement ouverte" })).toBeVisible();

  await page.getByLabel("Désignation vendue").fill("Prestation recette");
  await page.getByLabel("Total encaissé (FCFA)").fill("2500");
  await page.getByRole("button", { name: "Enregistrer la vente comptant" }).click();
  await expect.poll(() => appliedEvents.length).toBe(3);
  expect(appliedEvents[2].action_code).toBe("sale.created");
  expect((appliedEvents[2].payload as Record<string, unknown>).payment_method).toBe("cash");
  expect((appliedEvents[2].payload as Record<string, unknown>).status).toBe("confirmed");

  await page.getByLabel("Montant compté à la clôture (FCFA)").fill("7500");
  await page.getByRole("button", { name: "Clôturer et calculer l'écart serveur" }).click();
  await expect.poll(() => appliedEvents.length).toBe(4);
  expect(appliedEvents[3].action_code).toBe("cash_session.closed");
  expect((appliedEvents[3].payload as Record<string, unknown>).counted_close_xaf).toBe(7500);
  await expect(page.getByText(/opération\(s\) confirmée/)).toBeVisible();
  await page.close();
});

test("Web N4-C: staff presence transitions follow the server-controlled sequence", async ({ context }) => {
  const appliedEvents = await installBackend(context);
  const page = await context.newPage();
  await signIn(page);
  await page.locator(".side-nav button.nav-item").filter({ hasText: "Équipe & commissions" }).click();
  const actions = [
    ["Pointer mon arrivée", "staff_clock_in.recorded"],
    ["Commencer une pause", "staff_break_start.recorded"],
    ["Terminer la pause", "staff_break_end.recorded"],
    ["Pointer mon départ", "staff_clock_out.recorded"],
  ] as const;
  for (let index = 0; index < actions.length; index++) {
    const [label, actionCode] = actions[index];
    await page.locator(".module-main-card .activity-transition-buttons").first().getByRole("button", { name: label }).click();
    await expect.poll(() => appliedEvents.length).toBe(index + 1);
    expect(appliedEvents[index].action_code).toBe(actionCode);
    expect(appliedEvents[index].aggregate_type).toBe(actionCode.replace(".recorded", ""));
  }
  await page.close();
});
