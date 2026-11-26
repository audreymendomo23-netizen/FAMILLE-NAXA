// ZIPPLE-only Cloudflare Pages build. No Supabase admin key belongs in this frontend.
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
export const endpoint = "https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-n1";
export function validate(env) {
  if (env.VITE_ZIPPLE_API_URL !== endpoint) throw new Error("Missing or invalid VITE_ZIPPLE_API_URL (ZIPPLE N1 only)");
  for (const [name, value] of Object.entries(env)) {
    if (!name.startsWith("VITE_")) continue;
    if (/SECRET|SERVICE_ROLE|PRIVATE_KEY|PASSWORD|TOKEN/i.test(name) || /^sb_secret_/i.test(value ?? "")) throw new Error("Private configuration cannot be exposed to ZIPPLE Web");
    if (/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value ?? "")) {
      let claims;
      try { claims = JSON.parse(Buffer.from(value.split(".")[1], "base64url").toString("utf8")); } catch {}
      if (claims?.role === "service_role") throw new Error("Service role cannot be exposed to ZIPPLE Web");
    }
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  validate(process.env);
  const result = spawnSync("npm", ["run","build","--workspace","@famille/zipple-web"], {stdio:"inherit",shell:false});
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
}
