import { expect, test, type BrowserContext, type Page, type Route } from "@playwright/test";
import { ACTIVITY_WORKFLOWS, type ActivityProfile } from "../src/erp/activity-workflows";
import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";

const AUTH_URL = "https://naxa-services-e2e.invalid/functions/v1/naxa-services-auth";
const ACCOUNTING_URL = "https://naxa-services-e2e.invalid/functions/v1/naxa-services-accounting";
const DEVICE_ID = "70000000-0000-4000-8000-000000000001";
const REMOTE_DEVICE_ID = "70000000-0000-4000-8000-000000000002";
const ORG_A = "20000000-0000-4000-8000-000000000001";
const ORG_B = "20000000-0000-4000-8000-000000000002";
const SITE_ID = "30000000-0000-4000-8000-000000000001";
const SECOND_SITE_ID = "30000000-0000-4000-8000-000000000002";
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

function authSession(organizationId: string, activityProfile = "autre", multiSite = false) {
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
      business_mode: multiSite ? "multi_site_network" : "solo",
      default_locale: "fr",
      active_site_ids: multiSite ? [SITE_ID, SECOND_SITE_ID] : [SITE_ID],
      active_sites: [{
        id: SITE_ID,
        code: "SITE-01",
        name: other ? "Site organisation B" : "Site organisation A",
        address_label: "Site de recette",
        phone_contact: "",
      }, ...(multiSite ? [{ id: SECOND_SITE_ID, code: "SITE-02", name: "Site de recette B", address_label: "Deuxième site de recette", phone_contact: "" }] : [])],
    },
  };
}

async function installBackend(context: BrowserContext, incomingChanges: Record<string, unknown>[] = []) {
  const appliedEvents: Record<string, unknown>[] = [];
  const memberLocales=new Map<string,string>();
  let currentOrg=ORG_A;
  await context.route("https://naxa-services-e2e.invalid/storage/v1/object/**", async route => {
    const headers = {...CORS_HEADERS,"Access-Control-Allow-Methods":"GET, POST, DELETE, OPTIONS","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-upsert, cache-control"};
    await route.fulfill({status:route.request().method()==="OPTIONS"?200:404,headers,body:"{}"});
  });
  await context.route(AUTH_URL, async (route) => {
    if (route.request().method() === "OPTIONS") return json(route, {}, 200);
    const request = route.request().postDataJSON() as Record<string, unknown>;
    if (request.action === "login") {
      const organizationId = request.identifier === "NS-OTHER" ? ORG_B : ORG_A;
      const identifier = typeof request.identifier === "string" ? request.identifier : "";
      const activityProfile = identifier.startsWith("NS-ACT-") ? identifier.slice("NS-ACT-".length).toLowerCase() : "autre";
      currentOrg=organizationId;
      const session=authSession(organizationId, activityProfile, identifier === "NS-MULTISITE");
      if(identifier==="NS-SINGLE")session.account.business_mode="single_site_multi_workstation";
      session.account.default_locale=memberLocales.get(organizationId)??"fr";
      return json(route,session);
    }
    if(request.action==="set_member_locale"){memberLocales.set(currentOrg,String(request.locale));return json(route,{saved:true,locale:request.locale});}
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
      const revision = event.aggregate_type === "customer_followup" ? appliedEvents.filter(item=>item.aggregate_id===event.aggregate_id).length : typeof payload.expected_version === "number" ? payload.expected_version + 1 : 1;
      const actionCode = typeof event.action_code === "string" ? event.action_code : "";
      // Pressing transitions encode the target status in the action suffix, like ns_apply_sync_event.
      const pressingStatus = actionCode.startsWith("pressing_order.status_changed:")
        ? actionCode.slice("pressing_order.status_changed:".length) : null;
      const status = actionCode === "appointment.created" ? "booked"
        : actionCode === "appointment.rescheduled" ? "confirmed"
        : actionCode === "purchase.ordered" ? "ordered"
        : actionCode === "customer_followup.completed" ? (payload.next_due_at_if_repeating ? "active" : "completed")
        : actionCode === "cash_session.opened" ? "open"
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
  await page.getByRole("button", { name: "Enregistrer" }).click();
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
    const currentRecord = page.locator(".activity-record[data-record-id=\"" + event.aggregate_id + "\"]");
    await expect(currentRecord.getByTestId("record-confirmation")).toHaveAttribute("data-version","1");
    await expect(currentRecord.locator(".record strong")).toHaveText("Dossier " + recipe.profile);
    await expect(currentRecord.locator(".status-tag")).toHaveText(workflow.stages.find((stage) => stage.code === "received")!.label);
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
      await expect(currentRecord.getByTestId("record-confirmation")).toHaveAttribute("data-version",String(expectedRevision+1));
      await expect(currentRecord.locator(".record strong")).toHaveText("Dossier " + recipe.profile);
      await expect(currentRecord.locator(".status-tag")).toHaveText(nextStage!.label);
      if (nextStage!.next.length > 0) {
        await expect(currentRecord.locator(".activity-transition input")).toHaveValue("");
      } else {
        await expect(currentRecord.locator(".activity-transition")).toHaveCount(0);
      }
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
  await page.getByRole("button", { name: "Enregistrer" }).click();
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
  await expect(page.locator(".activity-record .activity-transition")).toHaveCount(0);
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
  await page.getByRole("button",{name:/Clients & fidélité/}).first().click();
  await expect(page.locator(".module-layout .module-main-card").last().locator(".record").filter({ hasText: "Client distant Android" })).toBeVisible();

  await context.setOffline(true);
  await createCustomer(page, "Client privé organisation A");
  await expect(page.getByText(/enregistré hors connexion/i)).toBeVisible();
  await expect(page.locator(".module-layout .module-main-card").last().locator(".record").filter({ hasText: "Client privé organisation A" })).toBeVisible();
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
  await expect(page.locator(".record").filter({hasText:"Client privé organisation A"}).getByText("Confirmé",{exact:true}).first()).toBeVisible();
  await expect(page.locator(".module-layout .module-main-card").last().locator(".record").filter({ hasText: "Client distant Android" })).toBeVisible();
  await expect(page.locator(".module-layout .module-main-card").last().locator(".record").filter({ hasText: "Client privé organisation A" })).toBeVisible();
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
  await page.getByRole("button", { name: "Créer le registre" }).click();
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

  await page.getByLabel("Désignation vendue").fill("Prestation Mobile Money externe");
  await page.getByRole("combobox",{name:"Mode d’encaissement reçu"}).selectOption("mobile_money");
  await page.getByLabel("Total encaissé (FCFA)").fill("1000");
  await page.getByRole("button",{name:"Enregistrer la vente comptant"}).click();
  await expect.poll(()=>appliedEvents.length).toBe(4);
  expect((appliedEvents[3].payload as Record<string,unknown>).payment_method).toBe("mobile_money");
  expect((appliedEvents[3].payload as Record<string,unknown>).status).toBe("confirmed");
  await page.getByLabel("Montant compté à la clôture (FCFA)").fill("7500");
  await page.getByRole("button", { name: "Clôturer et calculer l'écart" }).click();
  await expect.poll(() => appliedEvents.length).toBe(5);
  expect(appliedEvents[4].action_code).toBe("cash_session.closed");
  expect((appliedEvents[4].payload as Record<string, unknown>).counted_close_xaf).toBe(7500);
  await expect(page.getByText(/opération\(s\) confirmée/)).toBeVisible();
  await page.close();
});

test("Web N4-C: staff presence transitions follow the server-controlled sequence", async ({ context }) => {
  const appliedEvents = await installBackend(context, [{
    cursor: 1, event_id: "colleague-arrival", source_device_id: REMOTE_DEVICE_ID,
    origin_site_id: SITE_ID, site_id: SITE_ID, visible_site_ids: [SITE_ID], workstation_id: null,
    aggregate_type: "staff_clock_in", aggregate_id: "colleague-clock", aggregate_version: 1,
    action_code: "staff_clock_in.recorded", recorded_at: "2026-11-25T11:00:00.000Z",
    payload: { org_id: ORG_A, site_id: SITE_ID, staff_member_id: MEMBER_B, staff_name_snapshot: "Collègue de recette" },
  }]);
  const page = await context.newPage();
  await signIn(page);
  await page.locator(".side-nav button.nav-item").filter({ hasText: "Équipe & commissions" }).click();
  await expect(page.getByText("Collègue de recette", { exact: true })).toBeVisible();
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
    const nextActionLabel = actions[(index + 1) % actions.length][0];
    await expect(page.locator(".module-main-card .activity-transition-buttons").first().getByRole("button", { name: nextActionLabel })).toBeEnabled();
  }
  await page.close();
});

test("Web: a peer transition preserves the original job and its activity fields", async ({ context }) => {
  const job = "a5000000-0000-4000-8000-000000000077";
  const change = {
    source_device_id: REMOTE_DEVICE_ID, origin_site_id: SITE_ID, site_id: SITE_ID,
    visible_site_ids: [SITE_ID], workstation_id: null, aggregate_type: "repair_order",
    aggregate_id: job, recorded_at: "2026-11-25T10:00:00.000Z",
  };
  const scope = { org_id: ORG_A, site_id: SITE_ID, record_id: job };
  await installBackend(context, [
    { ...change, cursor: 1, event_id: "peer-create", action_code: "repair_order.created", aggregate_version: 1,
      payload: { ...scope, title: "Entretien véhicule atelier", counterparty: "Client de recette",
        metadata_json: { activity_profile: "garage", fields: { vehicle: "Véhicule de recette" } },
        server_result: { status: "received", revision: 1 } } },
    { ...change, cursor: 2, event_id: "peer-transition", action_code: "repair_order.status_changed", aggregate_version: 2,
      payload: { ...scope, from_status: "received", to_status: "diagnostic", server_result: { status: "diagnostic", revision: 2 } } },
  ]);
  const page = await context.newPage();
  await signIn(page, "NS-ACT-GARAGE");
  await page.getByRole("button", { name: "Dossiers métier" }).click();
  const record = page.locator(".activity-record").filter({ hasText: "Entretien véhicule atelier" });
  await expect(record.getByTestId("record-confirmation")).toHaveAttribute("data-version","2");
  await expect(record).toContainText("Véhicule de recette");
  await expect(record).toContainText("Client de recette");
  await expect(record.locator(".status-tag")).toHaveText(ACTIVITY_WORKFLOWS.garage.stages.find(s => s.code === "diagnostic")!.label);
});


test("Web: métier and Pressing registers follow the selected site", async ({ context }) => {
  const scenarios = [
    { site: SITE_ID, name: "Atelier A", kind: "work_order", id: "a5000000-0000-4000-8000-000000000081" },
    { site: SECOND_SITE_ID, name: "Atelier B", kind: "work_order", id: "a5000000-0000-4000-8000-000000000082" },
    { site: SITE_ID, name: "Ticket site A", kind: "pressing_order", id: "a5000000-0000-4000-8000-000000000083" },
    { site: SECOND_SITE_ID, name: "Ticket site B", kind: "pressing_order", id: "a5000000-0000-4000-8000-000000000084" },
  ];
  await installBackend(context, scenarios.map((scenario, index) => ({
    source_device_id: REMOTE_DEVICE_ID, origin_site_id: scenario.site, site_id: scenario.site,
    visible_site_ids: [scenario.site], workstation_id: null, aggregate_type: scenario.kind,
    aggregate_id: scenario.id, recorded_at: "2026-11-25T10:00:00.000Z",
    cursor: index + 1, event_id: "multisite-" + index, action_code: scenario.kind + ".created",
    aggregate_version: 1, payload: {
      org_id: ORG_A, site_id: scenario.site, title: scenario.name,
      ticket_number: scenario.name, customer_name: "Client de recette",
      metadata_json: { activity_profile: scenario.kind === "pressing_order" ? "pressing" : "autre", fields: {} },
      server_result: { status: "received", revision: 1 },
    },
  })));
  const page = await context.newPage();
  await signIn(page, "NS-MULTISITE");
  await page.getByRole("button", { name: "Dossiers métier" }).click();
  await expect(page.locator(".activity-record").filter({ hasText: "Atelier A" })).toBeVisible();
  await expect(page.locator(".activity-record").filter({ hasText: "Atelier B" })).toHaveCount(0);
  await page.getByLabel("Point de vente actif").selectOption(SECOND_SITE_ID);
  await expect(page.locator(".activity-record").filter({ hasText: "Atelier B" })).toBeVisible();
  await expect(page.locator(".activity-record").filter({ hasText: "Atelier A" })).toHaveCount(0);
  await page.locator(".side-nav button.nav-item").filter({ hasText: "Pressing" }).click();
  await expect(page.locator(".activity-record").filter({ hasText: "Ticket site B" })).toBeVisible();
  await expect(page.locator(".activity-record").filter({ hasText: "Ticket site A" })).toHaveCount(0);
  await page.getByLabel("Point de vente actif").selectOption(SITE_ID);
  await expect(page.locator(".activity-record").filter({ hasText: "Ticket site A" })).toBeVisible();
  await expect(page.locator(".activity-record").filter({ hasText: "Ticket site B" })).toHaveCount(0);
});


test("Web: delayed tenant A pull cannot repaint tenant B after logout", async ({ context }) => {
  await installBackend(context);
  let releaseA!: () => void;
  let receivedA!: () => void;
  const blocked = new Promise<void>(resolve => { releaseA = resolve; });
  const started = new Promise<void>(resolve => { receivedA = resolve; });
  await context.route(ACCOUNTING_URL, async route => {
    if (route.request().method() === "OPTIONS") return route.fallback();
    const request = route.request().postDataJSON() as Record<string, unknown>;
    if (request.action !== "pull_sync_changes" || request.org_id !== ORG_A) return route.fallback();
    receivedA();
    await blocked;
    return json(route, { ok: true, result: { changes: [{
      cursor: 1, source_device_id: REMOTE_DEVICE_ID, origin_site_id: SITE_ID, site_id: SITE_ID,
      visible_site_ids: [SITE_ID], workstation_id: null, aggregate_type: "customer",
      aggregate_id: "a5000000-0000-4000-8000-000000000099",
      recorded_at: "2026-11-25T10:00:00.000Z", event_id: "late-tenant-a",
      action_code: "customer.created", aggregate_version: 1,
      payload: { org_id: ORG_A, site_id: SITE_ID, display_name: "Client confidentiel A" }
    }], next_cursor: 1, has_more: false } });
  });
  const page = await context.newPage();
  try {
    await signIn(page);
    await started;
    await page.getByRole("button", { name: "Déconnexion" }).click();
    await expect(page.getByLabel("Identifiant NAXA Services")).toBeVisible();
    // Stay in the same document: a navigation would cancel the delayed request.
    await page.getByLabel("Identifiant NAXA Services").fill("NS-OTHER");
    await page.getByLabel("Mot de passe").fill("E2E-Password-Only-For-Test");
    await page.getByRole("button", {name:"Se connecter"}).click();
    await expect(page.getByRole("heading", {name:"Une journée bien organisée commence ici."})).toBeVisible();
    const oldResponse = page.waitForResponse(response => response.url()===ACCOUNTING_URL &&
      response.request().method()==="POST" && response.request().postDataJSON().org_id===ORG_A);
    releaseA();
    await oldResponse;
    const harness = await context.newPage();
    await harness.goto("/e2e/queue-harness.html");
    await harness.waitForFunction(() => document.querySelector("#ready")?.textContent === "ready");
    await expect.poll(() => harness.evaluate(({deviceId,orgId}) =>
      (window as any).__naxaQueueHarness.cursor("naxa-services-web",deviceId,orgId),
      {deviceId:DEVICE_ID,orgId:ORG_A})).toBe(1);
    await harness.close();
    await page.getByRole("button", { name: /Clients & fidélité/ }).first().click();
    await expect(page.getByText("Client confidentiel A")).toHaveCount(0);
    await expect(page.getByText("customer.created", {exact:true})).toHaveCount(0);
    await expect(page.getByText("Aucune fiche client dans le site actif.")).toBeVisible();
  } finally { releaseA(); }
});


test("Web security: list only own devices and revoke another device after explicit confirmation", async ({context}) => {
  await installBackend(context);
  const current={id:DEVICE_ID,installation_id:"current-fixture",platform:"web",label:"Navigateur courant",last_seen_at:"2026-11-25T10:00:00Z",revoked_at:null,current:true};
  const other={id:REMOTE_DEVICE_ID,installation_id:"other-fixture",platform:"android",label:"Téléphone de recette",last_seen_at:"2026-11-25T10:00:00Z",revoked_at:null as string|null,current:false};
  let revocations=0;
  await context.route(AUTH_URL,async route=>{
    if(route.request().method()==="OPTIONS")return route.fallback();
    const request=route.request().postDataJSON() as Record<string,unknown>;
    if(request.action==="list_own_devices"){
      expect(request.account_id).toBeUndefined();
      return json(route,{devices:[current,other]});
    }
    if(request.action==="revoke_device"){
      expect(request.installation_id).toBe(other.installation_id);
      expect(request.account_id).toBeUndefined();
      revocations++;
      other.revoked_at="2026-11-25T10:01:00Z";
      return json(route,{revoked:true});
    }
    return route.fallback();
  });
  const page=await context.newPage();
  await signIn(page);
  await page.locator(".side-nav button.nav-item").filter({hasText:"Sécurité & appareils"}).click();
  await page.getByRole("button",{name:"Charger mes appareils"}).click();
  const currentRow=page.locator(".record").filter({hasText:"Navigateur courant"});
  const otherRow=page.locator(".record").filter({hasText:"Téléphone de recette"});
  await expect(currentRow).toContainText("Cet appareil");
  await expect(currentRow.getByRole("button",{name:"Révoquer"})).toHaveCount(0);
  await otherRow.getByRole("button",{name:"Révoquer"}).click();
  expect(revocations).toBe(0);
  await page.getByRole("button",{name:"Confirmer la révocation"}).click();
  await expect(otherRow).toContainText("Révoqué");
  expect(revocations).toBe(1);
});


test("Web CRM: create a follow-up, reschedule it with a confirmed completion and close it", async ({context}) => {
  const events=await installBackend(context);
  const page=await context.newPage();
  await signIn(page);
  await createCustomer(page,"Client suivi ERP");
  await expect.poll(()=>events.length).toBe(1);
  const customerId=String(events[0].aggregate_id);
  await expect(page.getByRole("dialog")).toHaveCount(0);
  const customerSelect=page.getByRole("combobox",{name:"Client du suivi",exact:true});
  await expect(customerSelect.locator("option",{hasText:"Client suivi ERP"})).toHaveAttribute("value",customerId);
  await customerSelect.selectOption(customerId);
  await page.getByLabel("Objet du suivi").fill("Contrôle satisfaction");
  await page.getByLabel("Prochaine échéance",{exact:true}).fill("2030-01-01T10:00");
  await page.getByRole("button",{name:"Créer le suivi client"}).click();
  await expect.poll(()=>events.length).toBe(2);
  expect(events[1].action_code).toBe("customer_followup.created");
  const followupId=events[1].aggregate_id;
  const record=page.locator(".activity-record").filter({hasText:"Contrôle satisfaction"});
  await record.getByLabel("Note de réalisation").fill("Premier contact effectué");
  await record.getByLabel("Prochaine échéance (facultative, suivi récurrent)").fill("2030-02-01T10:00");
  await record.getByRole("button",{name:"Terminer et reprogrammer"}).click();
  await expect.poll(()=>events.length).toBe(3);
  expect(events[2].aggregate_id).toBe(followupId);
  expect(events[2].action_code).toBe("customer_followup.completed");
  expect((events[2].payload as Record<string,unknown>).next_due_at_if_repeating).toBeTruthy();
  await expect(record.getByRole("button",{name:"Clôturer le suivi"})).toBeEnabled();
  await record.getByRole("button",{name:"Clôturer le suivi"}).click();
  await expect.poll(()=>events.length).toBe(4);
  expect(events[3].aggregate_id).toBe(followupId);
  expect((events[3].payload as Record<string,unknown>).next_due_at_if_repeating).toBeNull();
  await expect(record.locator(".status-tag")).toHaveText("Terminé");
  await expect(record).toContainText("Confirmé");
  await expect(record.getByRole("button",{name:"Clôturer le suivi"})).toHaveCount(0);
});


test("Web subscriptions: member sees server paid state without gaining payment authority", async ({context}) => {
  await installBackend(context);
  let state="active";
  let reads=0;
  await context.route(AUTH_URL,async route=>{
    if(route.request().method()==="OPTIONS")return route.fallback();
    const request=route.request().postDataJSON() as Record<string,unknown>;
    if(request.action==="subscription_access"){
      expect(request.org_id).toBeUndefined();
      reads++;
      return json(route,{subscription_access:{state,paid_access:state==="active",plan_code:"ACCESS",period_end_exclusive:"2026-12-01"}});
    }
    return route.fallback();
  });
  const page=await context.newPage();
  await signIn(page);
  await page.locator(".side-nav button.nav-item").filter({hasText:"PME & organisation"}).click();
  await page.getByRole("button",{name:"Vérifier les droits payés"}).click();
  await expect(page.getByText("Période payée active",{exact:false})).toBeVisible();
  await expect(page.getByRole("button",{name:"Obtenir le montant et la destination"})).toHaveCount(0);
  state="expired";
  await page.getByRole("button",{name:"Vérifier les droits payés"}).click();
  await expect(page.getByText("Période payée expirée",{exact:false})).toBeVisible();
  expect(reads).toBe(2);
});

test("Web profile photo: private authenticated upload, read, deletion and account isolation",async({context})=>{
  await installBackend(context);
  const objects=new Map<string,Buffer>();
  const requests:string[]=[];
  const base="https://naxa-services-e2e.invalid/storage/v1/object/";
  const headers={...CORS_HEADERS,"Access-Control-Allow-Methods":"GET, POST, DELETE, OPTIONS","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-upsert, cache-control"};
  await context.route(base+"**",async route=>{
    const req=route.request(),method=req.method();
    if(method==="OPTIONS")return route.fulfill({status:200,headers,body:""});
    expect(req.headers().authorization).toBe("Bearer e2e-access-token-with-more-than-twenty-characters");
    const path=new URL(req.url()).pathname.replace(/^\/storage\/v1\/object\/(authenticated\/)?ns-profile-photos\/?/,"");
    requests.push(method+" "+path);
    if(method==="GET"){
      const photo=objects.get(path);
      return route.fulfill(photo?{status:200,headers:{...headers,"Content-Type":"image/jpeg"},body:photo}:{status:404,headers,body:"{}"});
    }
    if(method==="POST"){
      expect(req.headers()["x-upsert"]).toBe("true");
      expect(req.headers()["content-type"]).toBe("image/jpeg");
      const data=req.postDataBuffer();expect(data?.subarray(0,2).toString("hex")).toBe("ffd8");
      objects.set(path,data!);
      return route.fulfill({status:200,headers,body:"{}"});
    }
    if(method==="DELETE"){
      const paths=req.postDataJSON().prefixes as string[];
      expect(paths).toHaveLength(1);objects.delete(paths[0]);
      return route.fulfill({status:200,headers,body:"[]"});
    }
    return route.fulfill({status:405,headers,body:"{}"});
  });
  const page=await context.newPage();
  await signIn(page);
  await expect(page.getByRole("button",{name:"Photo de profil",exact:true})).toBeEnabled();
  await page.getByLabel("Fichier photo de profil").setInputFiles({name:"test.png",mimeType:"image/png",buffer:Buffer.from("iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGOsbvFjIAUwkaR6VMOohiGlAQAtrwFtmi6mgwAAAABJRU5ErkJggg==","base64")});
  await expect(page.getByText("Photo enregistrée.",{exact:true})).toBeVisible();
  await expect(page.getByAltText("Photo de profil")).toBeVisible();
  expect(objects.has(ORG_A+"/"+MEMBER_A+"/avatar.jpg")).toBe(true);
  await page.getByRole("button",{name:"Déconnexion"}).click();
  await signIn(page,"NS-OTHER");
  await expect(page.getByRole("button",{name:"Photo de profil",exact:true})).toBeEnabled();
  await expect(page.getByAltText("Photo de profil")).toHaveCount(0);
  expect(requests).toContain("GET "+ORG_B+"/"+MEMBER_B+"/avatar.jpg");
  await page.getByRole("button",{name:"Déconnexion"}).click();
  await signIn(page);
  await expect(page.getByAltText("Photo de profil")).toBeVisible();
  page.once("dialog",dialog=>dialog.accept());
  await page.getByRole("button",{name:"Supprimer la photo"}).click();
  await expect(page.getByText("Photo supprimée.",{exact:true})).toBeVisible();
  expect(objects.size).toBe(0);
});

test("Commercial login: photos load, alternate after four seconds and technical copy is absent",async({context})=>{
  const page=await context.newPage();await page.goto("/");
  const photos=page.getByTestId("auth-photos");
  await expect(photos).toBeVisible();
  await expect.poll(()=>photos.locator("img.current").evaluate((img:HTMLImageElement)=>img.complete&&img.naturalWidth>0)).toBe(true);
  await expect(photos).toHaveAttribute("data-photo-index","0");
  await expect(photos).toHaveAttribute("data-photo-index","1",{timeout:6500});
  await expect(page.getByText(/Session Web conservée|Pas d'inscription libre|jetons restent en mémoire/)).toHaveCount(0);
  await page.getByRole("button",{name:"Mode clair",exact:true}).click();
  await expect(page.locator(".auth-app")).toHaveClass(/light/);
  await page.getByRole("button",{name:"Mode nuit",exact:true}).click();
  await expect(page.getByTestId("night-torch")).toBeVisible();
  await expect(page.getByTestId("night-torch")).toHaveCount(0,{timeout:3000});
  await expect(page.getByLabel("Identifiant NAXA Services")).toBeEditable();
});
test("Commercial responsiveness: all modules are reachable on a 320px screen",async({context})=>{
  test.setTimeout(90_000);await installBackend(context);
  const page=await context.newPage();await page.setViewportSize({width:320,height:720});
  await signIn(page);
  const labels=await page.locator(".side-nav .nav-item").allTextContents();
  expect(labels.length).toBeGreaterThan(12);
  for(let i=0;i<labels.length;i++){
    await page.getByRole("button",{name:"Tous les modules"}).click();
    const link=page.locator(".side-nav .nav-item").nth(i);
    await expect(link).toBeVisible();await link.click();
    await expect(page.locator(".sidebar")).not.toBeVisible();
    await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
    await expect(page.locator("main")).not.toContainText(/détermine les scopes|entitlements indépendants|dans la liste locale|session Auth|avec Auth|profil Auth|postes Auth|cross-site|Enregistrement côté serveur|reçu serveur/i);
  }
  for(const width of [390,768,1024,1440]){
    await page.setViewportSize({width,height:900});
    await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
  }
  await page.setViewportSize({width:390,height:844});
  await page.getByRole("button",{name:"Tous les modules"}).click();
  await expect(page.locator(".sidebar")).toBeVisible();
  await page.keyboard.press("Escape");await expect(page.locator(".sidebar")).not.toBeVisible();
});
test("Reduced motion: photos stay still and torch is suppressed",async({context})=>{
  const page=await context.newPage();await page.emulateMedia({reducedMotion:"reduce"});await page.goto("/");
  await expect(page.getByTestId("auth-photos")).toHaveAttribute("data-photo-index","0");
  await page.getByRole("button",{name:"Mode clair",exact:true}).click();
  await page.getByRole("button",{name:"Mode nuit",exact:true}).click();
  await expect(page.getByTestId("night-torch")).toHaveCount(0);
});

test("Web stock: create item and supplier, movement, order, receipt then supplier payment",async({context})=>{
  test.setTimeout(60_000);const events=await installBackend(context);
  const page=await context.newPage();await signIn(page);
  await page.locator(".side-nav .nav-item").filter({hasText:"Consommables"}).click();
  await page.getByRole("button",{name:"Ajouter un article",exact:true}).click();
  await page.getByLabel("Nom / référence").fill("Lessive de recette");
  await page.getByRole("button",{name:"Enregistrer",exact:true}).click();
  await expect.poll(()=>events.length).toBe(1);
  expect(events[0].action_code).toBe("inventory_item.created");
  const item=String(events[0].aggregate_id);
  await page.getByLabel("Nom du fournisseur").fill("Fournisseur recette");
  await page.getByRole("button",{name:"Enregistrer le fournisseur"}).click();
  await expect.poll(()=>events.length).toBe(2);
  expect(events[1].action_code).toBe("supplier.saved");
  const supplier=String(events[1].aggregate_id);
  await page.getByRole("combobox",{name:"Article",exact:true}).selectOption(item);
  await page.getByLabel("Quantité",{exact:true}).fill("10");
  await page.getByLabel("Motif",{exact:true}).fill("Stock initial");
  await page.getByRole("button",{name:"Enregistrer le mouvement",exact:true}).click();
  await expect.poll(()=>events.length).toBe(3);
  expect(events[2].action_code).toBe("inventory_movement.created");
  await page.getByRole("combobox",{name:"Fournisseur",exact:true}).selectOption(supplier);
  await page.getByRole("combobox",{name:"Article commandé",exact:true}).selectOption(item);
  await page.getByLabel("Référence de commande").fill("CMD-RECETTE-01");
  await page.getByLabel("Quantité commandée").fill("5");
  await page.getByLabel("Coût unitaire (FCFA)").fill("1000");
  await page.getByRole("button",{name:"Valider la commande fournisseur"}).click();
  await expect.poll(()=>events.length).toBe(4);
  expect(events[3].action_code).toBe("purchase.ordered");
  const order=String(events[3].aggregate_id);
  await page.getByRole("combobox",{name:"Commande à réceptionner",exact:true}).selectOption(order);
  const pay=page.getByRole("button",{name:"Enregistrer un règlement bancaire"});
  await expect(pay).toBeDisabled();
  await page.getByLabel("Quantité reçue").fill("5");
  await page.getByRole("button",{name:"Enregistrer la réception partielle ou complète"}).click();
  await expect.poll(()=>events.length).toBe(5);
  expect(events[4].action_code).toBe("purchase.receipt.confirmed");
  expect((events[4].payload as Record<string,unknown>).purchase_id).toBe(order);
  await expect(pay).toBeEnabled();
  await page.getByLabel("Montant du règlement bancaire (FCFA)").fill("5000");
  await page.getByLabel("Référence bancaire").fill("VIR-RECETTE-01");
  await pay.click();
  await expect.poll(()=>events.length).toBe(6);
  expect(events[5].action_code).toBe("supplier.payment.recorded");
  expect((events[5].payload as Record<string,unknown>).amount_xaf).toBe(5000);
  await expect(page.getByText("Règlement fournisseur",{exact:true})).toBeVisible();
});
test("Web access: failed login and recovery stay in the customer journey",async({context})=>{
  await installBackend(context);
  let recovery=false;
  await context.route(AUTH_URL,async route=>{
    if(route.request().method()==="OPTIONS")return route.fallback();
    const body=route.request().postDataJSON();
    if(body.action==="login")return json(route,{message:"Identifiant ou mot de passe incorrect."},401);
    if(body.action==="request_recovery"){recovery=true;return json(route,{accepted:true});}
    return route.fallback();
  });
  const page=await context.newPage();await page.goto("/");
  await page.getByLabel("Identifiant NAXA Services").fill("NS-INVALID");
  await page.getByLabel("Mot de passe").fill("Wrong-test-password");
  await page.getByRole("button",{name:"Se connecter"}).click();
  await expect(page.getByText("Identifiant ou mot de passe incorrect.",{exact:true})).toBeVisible();
  await page.getByRole("button",{name:"Mot de passe oublié ?"}).click();
  await page.getByLabel("Note au responsable (facultatif)").fill("Demande de recette");
  await page.getByRole("button",{name:"Envoyer la demande"}).click();
  await expect.poll(()=>recovery).toBe(true);
  await page.getByRole("button",{name:"Retour à la connexion"}).click();
  await expect(page.getByLabel("Mot de passe")).toBeVisible();
});


test("Commercial languages: FR, EN and Fulfulde change login, dashboard and menu; member choice survives login",async({context})=>{
  await installBackend(context);
  const page=await context.newPage();await page.goto("/");
  await page.getByRole("combobox",{name:"Langue",exact:true}).selectOption("en");
  await expect(page.getByLabel("NAXA Services ID")).toBeVisible();await expect(page.getByRole("button",{name:"Sign in",exact:true})).toBeVisible();
  await page.reload();await expect(page.getByRole("button",{name:"Sign in",exact:true})).toBeVisible();
  await page.getByRole("combobox",{name:"Language",exact:true}).selectOption("ff-CM");
  await expect(page.getByLabel("Innol NAXA Services")).toBeVisible();await expect(page.getByRole("button",{name:"Naatu",exact:true})).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("lang","ff-CM");
  await page.getByRole("combobox",{name:"Ɗemngal",exact:true}).selectOption("fr");
  await signIn(page);
  await page.getByRole("combobox",{name:"Langue",exact:true}).selectOption("en");
  await expect(page.getByRole("heading",{name:"A well-organized day starts here."})).toBeVisible();
  await expect(page.locator(".side-nav")).toContainText("Cash & sales");
  await page.getByRole("combobox",{name:"Language",exact:true}).selectOption("ff-CM");
  await expect(page.getByRole("heading",{name:"Ñalawma moƴƴo fuɗɗata ɗoo."})).toBeVisible();
  await expect(page.locator(".side-nav")).toContainText("Ceede e jaaygol");
  await page.getByRole("button",{name:/Yaltu/}).click();
  await page.getByLabel("Innol NAXA Services").fill("NS-ORG-A");await page.getByLabel("Finnde",{exact:true}).fill("E2E-Password-Only-For-Test");await page.getByRole("button",{name:"Naatu",exact:true}).click();
  await expect(page.getByRole("heading",{name:"Ñalawma moƴƴo fuɗɗata ɗoo."})).toBeVisible();
  await page.getByRole("combobox",{name:"Ɗemngal",exact:true}).selectOption("fr");
  await expect(page.getByRole("heading",{name:"Une journée bien organisée commence ici."})).toBeVisible();
});


test("Commercial languages: shared ERP screens render translated controls in FR EN and Fulfulde",async({context})=>{
  await installBackend(context);const page=await context.newPage();await signIn(page);
  const cases=[
    {nav:["Agenda & rendez-vous","Calendar & appointments","Ɗaɓɓitanɗe e sahaa"],heading:["Rendez-vous et disponibilité","Appointments and availability","Sahaaaji e heɓugol"]},
    {nav:["Caisse & ventes","Cash & sales","Ceede e jaaygol"],heading:["Registres et sessions","Registers and shifts","Keesuuji ceede"]},
    {nav:["Consommables","Supplies","Jawdi golle"],heading:["Référentiel fournisseur","Supplier directory","Doggol hokkooɓe jawdi"]},
    {nav:["Équipe & commissions","Team & commissions","Golluɓe e ceede"],heading:["Pointage de l'utilisateur connecté","Your attendance","Naatugol maa"]},
    {nav:["Clients & fidélité","Customers & loyalty","Soottotooɓe"],heading:["Créer un suivi","Create follow-up","Sos rewindo"]},
  ];
  const langs=["fr","en","ff-CM"],labels=["Langue","Language","Ɗemngal"];
  for(let i=0;i<langs.length;i++){
    if(i>0){await page.getByRole("combobox",{name:labels[i-1],exact:true}).selectOption(langs[i]);await expect(page.locator("html")).toHaveAttribute("lang",langs[i]);}
    for(const c of cases){await page.locator(".side-nav").getByRole("button",{name:new RegExp(c.nav[i])}).click();await expect(page.getByRole("heading",{name:c.heading[i],exact:true})).toBeVisible();}
  }
});


// Every permitted edge is actually clicked on a separately projected record, including
// alternative branches, rework loops and cancellation. Peer fixtures are simulated;
// server enforcement is qualified independently by PostgreSQL and real Replay.
for(const profile of Object.keys(ACTIVITY_WORKFLOWS) as ActivityProfile[]){
 if(profile==="pressing")continue; // Dedicated complete ticket journey above.
 test("Interaction matrix: "+profile+" all permitted transitions and terminal restrictions",async({context})=>{
  test.setTimeout(150_000);
  const workflow=ACTIVITY_WORKFLOWS[profile],kind=workflow.recordType==="retail"?"work_order":workflow.recordType;
  const paths=new Map<string,string[]>([["received",["received"]]]);
  const queue=["received"];while(queue.length){const state=queue.shift()!;for(const next of workflow.stages.find(s=>s.code===state)!.next){if(!paths.has(next)){paths.set(next,[...paths.get(state)!,next]);queue.push(next);}}}
  const fixtures:Record<string,unknown>[]=[],cases:{id:string;title:string;from:string;to:string|null;revision:number}[]=[];
  let cursor=0;
  for(const stage of workflow.stages){
   for(const target of stage.next.length?stage.next:[null]){
    const id=randomUUID(),title="REC-"+profile+"-"+stage.code+"-"+(target??"terminal");
    const journey=paths.get(stage.code)!;
    const common={source_device_id:REMOTE_DEVICE_ID,origin_site_id:SITE_ID,site_id:SITE_ID,visible_site_ids:[SITE_ID],workstation_id:null,aggregate_type:kind,aggregate_id:id,recorded_at:"2026-11-25T10:00:00.000Z"};
    journey.forEach((state,index)=>{
     const revision=index+1;
     fixtures.push({...common,cursor:++cursor,event_id:randomUUID(),action_code:kind+(index?".status_changed":".created"),aggregate_version:revision,
      payload:{org_id:ORG_A,site_id:SITE_ID,record_id:id,...(index?{from_status:journey[index-1],to_status:state}:{title,counterparty:"Client matrice",metadata_json:{activity_profile:profile,fields:{}}}),server_result:{status:state,revision}}});
    });
    cases.push({id,title,from:stage.code,to:target,revision:journey.length});
   }
  }
  const events=await installBackend(context,fixtures),page=await context.newPage();
  await signIn(page,"NS-ACT-"+profile.toUpperCase());
  const nav=page.locator('.side-nav button[data-module-id="workOrders"]');
  await expect(nav).toHaveAccessibleName("Dossiers métier");
  await nav.click({timeout:8_000});await expect(nav).toHaveAttribute("aria-current","page");
  await expect(page.locator(".activity-record")).toHaveCount(cases.length);
  let sent=0;
  for(const c of cases){
   const record=page.locator(".activity-record[data-record-id=\"" + c.id + "\"]");
   await expect(record.locator(".record strong")).toHaveText(c.title);
   const stage=workflow.stages.find(s=>s.code===c.from)!;
   await expect(record.getByTestId("record-confirmation")).toHaveAttribute("data-version",String(c.revision));
   await expect(record.locator(".status-tag")).toHaveText(stage.label);
   const buttons=record.locator(".activity-transition-buttons button");
   await expect(buttons).toHaveCount(stage.next.length);
   if(c.to===null){await expect(record.locator(".activity-transition")).toHaveCount(0);continue;}
   await expect(buttons).toHaveText(stage.next.map(n=>workflow.stages.find(s=>s.code===n)!.label));
   for(const button of await buttons.all())await expect(button).toBeDisabled();
   await record.getByLabel("Motif du changement d'étape").fill("xy");
   for(const button of await buttons.all())await expect(button).toBeDisabled();
   await record.getByLabel("Motif du changement d'étape").fill("Recette matrice "+c.from+" vers "+c.to);
   const next=workflow.stages.find(s=>s.code===c.to)!;
   await record.getByRole("button",{name:next.label,exact:true}).click({timeout:8_000});
   await expect.poll(()=>events.length).toBe(++sent);
   const event=events[sent-1],payload=event.payload as Record<string,unknown>;
   expect(event.aggregate_id).toBe(c.id);expect(event.action_code).toBe(kind+".status_changed");
   expect(payload.from_status).toBe(c.from);expect(payload.to_status).toBe(c.to);expect(payload.expected_version).toBe(c.revision);
   await expect(record.getByTestId("record-confirmation")).toHaveAttribute("data-version",String(c.revision+1));
   await expect(record.locator(".status-tag")).toHaveText(next.label);
  }
  expect(sent).toBe(workflow.stages.reduce((n,s)=>n+s.next.length,0));
 });
}

// Cross the three operating modes with all three interface languages and two
// screen classes, checking every reachable navigation entry.
for(const mode of ["NS-ORG-A","NS-SINGLE","NS-MULTISITE"]){
 for(const locale of ["fr","en","ff-CM"]){
  test("Navigation matrix: "+mode+" / "+locale+" desktop and mobile",async({context})=>{
   test.setTimeout(90_000);await installBackend(context);
   const page=await context.newPage();await page.setViewportSize({width:1440,height:900});await signIn(page,mode);
   if(locale!=="fr"){await page.locator(".language-picker select").selectOption(locale);await expect(page.locator("html")).toHaveAttribute("lang",locale);}
   const sites=page.locator(".site-select select");await expect(sites.locator("option")).toHaveCount(mode==="NS-MULTISITE"?2:1);
   if(mode==="NS-MULTISITE"){await sites.selectOption(SECOND_SITE_ID);await expect(sites).toHaveValue(SECOND_SITE_ID);await sites.selectOption(SITE_ID);}
   const nav=page.locator(".side-nav button.nav-item");await expect(nav).toHaveCount(17);
   await expect(nav.filter({has:page.locator(".nav-glyph[aria-hidden=true]")})).toHaveCount(17);
   for(const width of [1440,320]){
    await page.setViewportSize({width,height:900});
    for(let i=0;i<17;i++){
     if(width===320)await page.locator(".mobile-menu-trigger").click();
     const item=nav.nth(i);await expect(item).toBeVisible();await item.click();await expect(item).toHaveAttribute("aria-current","page");
     await expect(page.locator(".page-heading h1")).toBeVisible();
     await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
    }
   }
  });
 }
}

test("Financial interactions: report scopes, actual XLSX download and print view; stale report is cleared",async({context})=>{
 await installBackend(context);let reports=0;
 await context.route(ACCOUNTING_URL,async route=>{
  if(route.request().method()==="OPTIONS")return route.fallback();
  const request=route.request().postDataJSON();if(request.action!=="performance")return route.fallback();
  expect(request.org_id).toBe(ORG_A);expect(request.site_ids).toEqual([SITE_ID]);reports++;
  return json(route,{ok:true,result:{daily:[{performance_day:"2026-11-26",revenue_xaf:3500,known_cost_of_goods_xaf:0,gross_profit_xaf:null,confirmed_sales_count:2,uncosted_sales_count:2}],monthly:[],annual:[]}});
 });
 const page=await context.newPage();await signIn(page);
 await page.locator(".side-nav button.nav-item").filter({hasText:"Rapports & comptabilité"}).click();
 const excel=page.getByRole("button",{name:"Exporter Excel",exact:true});
 await expect(excel).toHaveCount(0);
 await page.getByRole("button",{name:"Charger les rapports",exact:true}).click();await expect(excel).toBeVisible();expect(reports).toBe(1);
 const downloadPromise=page.waitForEvent("download");await excel.click();const download=await downloadPromise;expect(download.suggestedFilename()).toBe("naxa-services-performance.xlsx");
 const bytes=await readFile((await download.path())!);expect(bytes.readUInt32LE(0)).toBe(0x04034b50);expect(bytes.readUInt32LE(bytes.length-22)).toBe(0x06054b50);
 expect(bytes.toString("utf8")).toContain('<v>3500</v>');expect(bytes.toString("utf8")).toContain('<c r="D2"><v>0</v></c>');expect(bytes.toString("utf8")).toContain('<c r="E2"/>');
 // Browser printing is intercepted only to prevent a native print dialog in CI.
 await page.evaluate(()=>{const original=window.open.bind(window);window.open=((...args:Parameters<typeof window.open>)=>{const popup=original(...args);if(popup)popup.print=()=>{popup.document.body.dataset.printInvoked="true";};return popup;}) as typeof window.open;});
 const popupPromise=page.waitForEvent("popup");await page.getByRole("button",{name:"Imprimer / enregistrer en PDF",exact:true}).click();const popup=await popupPromise;
 await expect(popup.locator("body")).toHaveAttribute("data-print-invoked","true");await expect(popup.locator("table")).toContainText("3500");await popup.close();
 await page.getByLabel("À partir du").fill("2026-11-25");await expect(excel).toHaveCount(0);
});


test("Financial interactions: delayed period response cannot restore an obsolete export",async({context})=>{
 await installBackend(context);
 let release!:()=>void,started!:()=>void;
 const pending=new Promise<void>(r=>{release=r;}),observed=new Promise<void>(r=>{started=r;});
 await context.route(ACCOUNTING_URL,async route=>{
  if(route.request().method()==="OPTIONS")return route.fallback();
  const request=route.request().postDataJSON();if(request.action!=="performance")return route.fallback();
  const old=request.from_date==="2026-11-24";
  if(old){started();await pending;}
  return json(route,{ok:true,result:{daily:[{performance_day:request.from_date,revenue_xaf:old?999999:2000}],monthly:[],annual:[]}});
 });
 const page=await context.newPage();await signIn(page);await page.locator(".side-nav button.nav-item").filter({hasText:"Rapports & comptabilité"}).click();
 const date=page.getByLabel("À partir du"),load=page.getByRole("button",{name:"Charger les rapports",exact:true});
 try{
  await date.fill("2026-11-24");await load.click();await observed;
  await date.fill("2026-11-25");await expect(load).toBeEnabled();await load.click();
  await expect(page.getByRole("table").first()).toContainText("2026-11-25");
  const oldResponse=page.waitForResponse(r=>r.url()===ACCOUNTING_URL&&r.request().method()==="POST"&&r.request().postDataJSON()?.from_date==="2026-11-24");
  release();await oldResponse;await page.evaluate(()=>new Promise<void>(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve()))));
  await expect(page.getByRole("table").first()).toContainText("2026-11-25");await expect(page.getByRole("table").first()).not.toContainText("2026-11-24");
  await expect(page.getByRole("button",{name:"Exporter Excel",exact:true})).toBeEnabled();
 }finally{release();}
});


test("Activity confirmation: rejected transition cannot present a confirmed new stage or allow a second transition",async({context})=>{
 const id=randomUUID();
 await installBackend(context,[{source_device_id:REMOTE_DEVICE_ID,origin_site_id:SITE_ID,site_id:SITE_ID,visible_site_ids:[SITE_ID],workstation_id:null,aggregate_type:"work_order",aggregate_id:id,recorded_at:"2026-11-25T10:00:00.000Z",cursor:1,event_id:randomUUID(),action_code:"work_order.created",aggregate_version:1,payload:{org_id:ORG_A,site_id:SITE_ID,record_id:id,title:"Dossier refus recette",metadata_json:{activity_profile:"autre",fields:{service:"Service",specifications:"Recette"}},server_result:{status:"received",revision:1}}}]);
 let rejected=0;
 await context.route(ACCOUNTING_URL,async route=>{
  if(route.request().method()==="OPTIONS")return route.fallback();
  const request=route.request().postDataJSON();
  if(request.action!=="apply_sync_event")return route.fallback();
  if(request.event.aggregate_id!==id)return route.fallback();
  rejected++;return json(route,{ok:false,error:"NAXA_ACTIVITY_VERSION_CONFLICT"},409);
 });
 const page=await context.newPage();await signIn(page,"NS-ACT-AUTRE");await page.locator('.side-nav button[data-module-id="workOrders"]').click();
 const record=page.locator('.activity-record[data-record-id="'+id+'"]');
 await expect(record.getByTestId("record-confirmation")).toHaveAttribute("data-version","1");
 await record.getByLabel("Motif du changement d'étape").fill("Recette conflit");
 await record.getByRole("button",{name:"Annulée",exact:true}).click();
 await expect.poll(()=>rejected).toBe(1);
 await expect(record.getByTestId("record-confirmation")).toHaveAttribute("data-version","0");
 await expect(record.locator(".activity-transition")).toHaveCount(0);
});


test("Hierarchical attendance: disabling the proof module cannot fall back to unproved clock-in",async({context})=>{
 const events=await installBackend(context);
 for(const mode of ["NS-SINGLE","NS-MULTISITE"]){
  const page=await context.newPage();await signIn(page,mode);
  await page.locator('.side-nav button[data-module-id="team"]').click();
  await page.getByRole("button",{name:"Pointer mon arrivée",exact:true}).click();
  await expect(page.getByText("Le pointage sécurisé est temporairement indisponible.",{exact:true})).toBeVisible();
  expect(events.filter(x=>x.action_code==="staff_clock_in.recorded")).toHaveLength(0);
  await page.close();
 }
});
