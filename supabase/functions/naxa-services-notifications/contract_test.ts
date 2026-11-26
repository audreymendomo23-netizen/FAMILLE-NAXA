import {
  inboxTransition,
  normalizeNotificationPayload,
  normalizePushPlatform,
  normalizePushToken,
  retryablePushFailure,
  safeWorkerLimit,
  shouldRevokePushToken,
  validateFcmServiceAccount,
  FCM_OAUTH_TOKEN_URL,
} from "./notification_contract.ts";

Deno.test("push registration accepts only known platforms and bounded tokens", () => {
  if (normalizePushPlatform("android") !== "android" || normalizePushPlatform("web") !== "web") {
    throw new Error("PUSH_PLATFORM_NORMALIZATION_FAILED");
  }
  const token = "fcm_" + "x".repeat(60);
  if (normalizePushToken(token) !== token) throw new Error("PUSH_TOKEN_NORMALIZATION_FAILED");
  let rejectedPlatform = false;
  let rejectedToken = false;
  try { normalizePushPlatform("ios"); } catch { rejectedPlatform = true; }
  try { normalizePushToken("too-short"); } catch { rejectedToken = true; }
  if (!rejectedPlatform || !rejectedToken) throw new Error("INVALID_PUSH_REGISTRATION_ACCEPTED");
});

Deno.test("remote notification payload is reduced to safe title, body and app route", () => {
  const payload = normalizeNotificationPayload({
    title: "Nouvelle tâche",
    body: "Une action attend votre validation.",
    route: "/operations/tasks",
    customer_phone: "+237000000000",
    card_number: "secret",
  });
  if (Object.keys(payload).length !== 3 || payload.title !== "Nouvelle tâche") {
    throw new Error("NOTIFICATION_PAYLOAD_NOT_REDACTED");
  }
  let rejected = false;
  try {
    normalizeNotificationPayload({ title: "x", body: "y", route: "https://evil.example" });
  } catch { rejected = true; }
  if (!rejected) throw new Error("EXTERNAL_ROUTE_ACCEPTED");
});

Deno.test("FCM token errors and retryable errors are classified without exposing provider secrets", () => {
  if (!shouldRevokePushToken("UNREGISTERED") || !shouldRevokePushToken("SENDER_ID_MISMATCH")) {
    throw new Error("INVALID_FCM_TOKEN_NOT_REVOKED");
  }
  if (!retryablePushFailure("FCM_TEMPORARY_UNAVAILABLE") || retryablePushFailure("INVALID_ARGUMENT")) {
    throw new Error("FCM_RETRY_POLICY_FAILED");
  }
});

Deno.test("notification inbox state is monotonic and worker batch is bounded", () => {
  if (inboxTransition("sent", "read") !== "read") throw new Error("READ_TRANSITION_FAILED");
  if (inboxTransition("read", "actioned") !== "actioned") throw new Error("ACTION_TRANSITION_FAILED");
  if (inboxTransition("actioned", "read") !== "actioned") throw new Error("INBOX_STATE_REGRESSION");
  if (safeWorkerLimit(1000) !== 100 || safeWorkerLimit(-1) !== 1 || safeWorkerLimit("10") !== 25) {
    throw new Error("WORKER_BATCH_LIMIT_FAILED");
  }
});

Deno.test("FCM accepts only credentials from the dedicated project and trusted OAuth endpoint", () => {
  const project = "naxa-services-qa";
  const fixture = { project_id: project, client_email: "fcm@" + project + ".iam.gserviceaccount.com", private_key: "-----BEGIN PRIVATE KEY-----\nFIXTURE\n-----END PRIVATE KEY-----", token_uri: FCM_OAUTH_TOKEN_URL };
  if (validateFcmServiceAccount(JSON.stringify(fixture), project).project_id !== project) throw new Error("VALID_PROJECT_REJECTED");
  const invalid: Array<[string, string]> = [
    [JSON.stringify(fixture), ""],
    [JSON.stringify({...fixture, project_id:"naxatechnologie"}), "naxatechnologie"],
    [JSON.stringify({...fixture, project_id:"naxatechnologie"}), project],
    [JSON.stringify({...fixture, token_uri:"https://example.invalid/token"}), project],
    [JSON.stringify({...fixture, client_email:"fcm@other-project.iam.gserviceaccount.com"}), project],
    [JSON.stringify({...fixture, private_key:""}), project],
    ["null", project],
  ];
  for (const [raw, expected] of invalid) {
    let rejected = false;
    try { validateFcmServiceAccount(raw, expected); } catch { rejected = true; }
    if (!rejected) throw new Error("UNSAFE_FCM_CREDENTIALS_ACCEPTED");
  }
});
