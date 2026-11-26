export type PushPlatform = "android" | "web";
export type InboxState = "sent" | "read" | "actioned";

export interface SafeNotificationPayload {
  title: string;
  body: string;
  route?: string;
}

export function normalizePushPlatform(value: unknown): PushPlatform {
  if (value === "android" || value === "web") return value;
  throw new Error("INVALID_PUSH_PLATFORM");
}

export function normalizePushToken(value: unknown): string {
  if (typeof value !== "string") throw new Error("INVALID_PUSH_TOKEN");
  const token = value.trim();
  if (token.length < 30 || token.length > 4096 || /\s/.test(token)) {
    throw new Error("INVALID_PUSH_TOKEN");
  }
  return token;
}

export function normalizeNotificationPayload(input: Record<string, unknown>): SafeNotificationPayload {
  const title = typeof input.title === "string" ? input.title.trim() : "";
  const body = typeof input.body === "string" ? input.body.trim() : "";
  const route = typeof input.route === "string" ? input.route.trim() : undefined;
  if (title.length < 1 || title.length > 80) throw new Error("INVALID_NOTIFICATION_TITLE");
  if (body.length < 1 || body.length > 180) throw new Error("INVALID_NOTIFICATION_BODY");
  if (route !== undefined && (!/^\/[A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*\/?$/.test(route) || route.length > 121)) {
    throw new Error("INVALID_NOTIFICATION_ROUTE");
  }
  return route === undefined ? { title, body } : { title, body, route };
}

export function shouldRevokePushToken(errorCode: string): boolean {
  return errorCode === "UNREGISTERED" || errorCode === "SENDER_ID_MISMATCH";
}

export function retryablePushFailure(errorCode: string): boolean {
  return errorCode === "FCM_TEMPORARY_UNAVAILABLE" ||
    errorCode === "FCM_AUTH_TEMPORARY" ||
    errorCode === "NO_ACTIVE_PUSH_TOKEN";
}

export function inboxTransition(current: InboxState, next: "read" | "actioned"): InboxState {
  if (current === "actioned") return "actioned";
  if (next === "actioned") return "actioned";
  return current === "sent" ? "read" : current;
}

export function safeWorkerLimit(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value)) return 25;
  return Math.min(100, Math.max(1, value));
}

export type FcmServiceAccount = { project_id: string; client_email: string; private_key: string; token_uri: string };
export const FCM_OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";

// NAXA Pharmacy's project is intentionally excluded from this application.
export function validateFcmServiceAccount(raw: string, expectedProject: string): FcmServiceAccount {
  const project = expectedProject.trim();
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project) || project === "naxatechnologie") {
    throw new Error("FCM_DEDICATED_PROJECT_REQUIRED");
  }
  let account: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error();
    account = parsed as Record<string, unknown>;
  } catch { throw new Error("FCM_CREDENTIALS_NOT_CONFIGURED"); }
  if (account.project_id !== project) throw new Error("FCM_PROJECT_MISMATCH");
  if (typeof account.client_email !== "string" || !account.client_email.endsWith("@" + project + ".iam.gserviceaccount.com") ||
      typeof account.private_key !== "string" || !account.private_key.includes("-----BEGIN PRIVATE KEY-----") ||
      !account.private_key.includes("-----END PRIVATE KEY-----")) throw new Error("FCM_CREDENTIALS_NOT_CONFIGURED");
  if (account.token_uri !== undefined && account.token_uri !== FCM_OAUTH_TOKEN_URL) throw new Error("FCM_OAUTH_ENDPOINT_INVALID");
  return { project_id: project, client_email: account.client_email, private_key: account.private_key, token_uri: FCM_OAUTH_TOKEN_URL };
}

/** FCM HTTP 200 alone is not a device acceptance receipt. */
export function confirmedFcmReference(result:unknown,projectId:string):string {
  const name=result&&typeof result==="object"&&!Array.isArray(result)?(result as Record<string,unknown>).name:undefined;
  const prefix="projects/"+projectId+"/messages/";
  if(typeof name!=="string"||!name.startsWith(prefix)||!/^[A-Za-z0-9_:%.-]{1,256}$/.test(name.slice(prefix.length)))throw Error("FCM_TEMPORARY_UNAVAILABLE");
  return name;
}
