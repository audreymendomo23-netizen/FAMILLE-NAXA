// Call only after Supabase Auth has validated the access token and resolved the account.
type DeviceLookup = (path: string) => Promise<unknown>;

export function verifiedTokenSessionId(token: string): string {
  const parts = token.split(".");
  if (parts.length !== 3) return "";
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(payload.padEnd(Math.ceil(payload.length / 4) * 4, "=")));
    const id = claims?.session_id;
    return typeof id === "string" && id.length > 0 && id.length <= 128 ? id : "";
  } catch { return ""; }
}

export async function hasActiveDeviceSession(token: string, accountId: string, lookup: DeviceLookup): Promise<boolean> {
  const sessionId = verifiedTokenSessionId(token);
  if (!sessionId || !accountId) return false;
  const query = "ns_devices?select=id,account_id,session_id,revoked_at&account_id=eq." +
    encodeURIComponent(accountId) + "&session_id=eq." + encodeURIComponent(sessionId) + "&revoked_at=is.null&limit=2";
  const result = await lookup(query);
  if (!Array.isArray(result) || result.length !== 1) return false;
  const device = result[0];
  return Boolean(device && typeof device.id === "string" && device.id.length &&
    device.account_id === accountId && device.session_id === sessionId && device.revoked_at === null);
}
