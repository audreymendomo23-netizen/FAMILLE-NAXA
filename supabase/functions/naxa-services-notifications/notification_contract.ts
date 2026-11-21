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
  if (route !== undefined && !/^\/[A-Za-z0-9/_-]{1,120}$/.test(route)) {
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
