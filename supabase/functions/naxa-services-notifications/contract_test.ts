import {
  inboxTransition,
  confirmedFcmReference,
  classifyFcmFailure,
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
  for (const route of ["https://evil.example", "//evil", "///evil", "/\\evil", "/%2f%2fevil", "/operations/../admin", "/operations//tasks", "/operations?next=evil", "/" + "a".repeat(121)]) {
    let rejected = false;
    try { normalizeNotificationPayload({ title: "x", body: "y", route }); } catch { rejected = true; }
    if (!rejected) throw new Error("EXTERNAL_OR_AMBIGUOUS_ROUTE_ACCEPTED");
  }
  for (const route of ["/operations/tasks", "/operations/tasks/", "/dashboard", "/meetings/abc-123"]) {
    if (normalizeNotificationPayload({title:"x",body:"y",route}).route !== route) throw new Error("INTERNAL_ROUTE_REJECTED");
  }
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

Deno.test("FCM acceptance requires a genuine scoped provider message reference",()=>{
 const project="naxa-services";const valid="projects/"+project+"/messages/0:1234567890%abcd";
 if(confirmedFcmReference({name:valid},project)!==valid)throw Error("VALID_RECEIPT_REJECTED");
 for(const payload of [null,{},[],{name:""},{name:"fcm-accepted"},{name:"projects/other/messages/123"},{name:"projects/"+project+"/messages/"},{name:"projects/"+project+"/messages/../../other"},{name:"projects/"+project+"/messages/a b"},{name:123}]){
  let rejected=false;try{confirmedFcmReference(payload,project);}catch(e){rejected=e instanceof Error&&retryablePushFailure(e.message);}
  if(!rejected)throw Error("FALSE_ACCEPTANCE");
 }
});

Deno.test("explicit FCM provider transient codes remain retryable and are not marked permanent",()=>{
 for(const [status,code] of [[429,"QUOTA_EXCEEDED"],[503,"UNAVAILABLE"],[500,"INTERNAL"],[429,"RESOURCE_EXHAUSTED"],[401,"UNAUTHENTICATED"],[401,"THIRD_PARTY_AUTH_ERROR"]] as const){
  const mapped=classifyFcmFailure(status,{error:{details:[{errorCode:code}]}});
  if(!retryablePushFailure(mapped)||shouldRevokePushToken(mapped))throw Error("TRANSIENT_FAILURE_MISCLASSIFIED");
 }
 for(const code of ["UNREGISTERED","SENDER_ID_MISMATCH"])if(!shouldRevokePushToken(classifyFcmFailure(404,{error:{details:[{errorCode:code}]}})))throw Error("REVOKE_FAILED");
 if(retryablePushFailure(classifyFcmFailure(400,{error:{status:"INVALID_ARGUMENT"}})))throw Error("INVALID_RETRIED");
 if(!retryablePushFailure(classifyFcmFailure(503,null)))throw Error("UNAVAILABLE_NOT_RETRIED");
 if(classifyFcmFailure(400,{error:{details:[null,{}, {errorCode:"arbitrary-provider-text"}]}})!=="FCM_REJECTED")throw Error("UNTRUSTED_ERROR_FORWARDED");
});
