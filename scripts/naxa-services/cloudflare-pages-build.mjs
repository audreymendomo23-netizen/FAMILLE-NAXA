// Cloudflare Pages build guard for the isolated FAMILLE-NAXA backend.
import { spawnSync } from "node:child_process";
const base = "https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/";
const expected = {
  VITE_NAXA_SERVICES_AUTH_URL: base + "naxa-services-auth",
  VITE_NAXA_SERVICES_ACCOUNTING_URL: base + "naxa-services-accounting"
};
for (const [name, value] of Object.entries(expected)) {
  if (process.env[name] !== value) throw new Error("Missing or invalid " + name + " (FAMILLE-NAXA only)");
}
const key = process.env.VITE_SUPABASE_ANON_KEY ?? "";
let claims;
try {
  if (key.split(".").length !== 3) throw new Error();
  claims = JSON.parse(Buffer.from(key.split(".")[1], "base64url").toString("utf8"));
} catch { throw new Error("Expected the dedicated legacy public anon JWT; never use service_role or a secret key"); }
if (claims.role !== "anon" || claims.ref !== "idupfjbkwjcavyisxteo") {
  throw new Error("Public anon key must belong to FAMILLE-NAXA");
}
if (typeof claims.exp !== "number" || claims.exp <= Date.now() / 1000) throw new Error("Expired or invalid anon key");
for (const name of Object.keys(process.env)) {
  if (name.startsWith("VITE_") && /SECRET|SERVICE_ROLE|PRIVATE_KEY/i.test(name)) {
    throw new Error("Private configuration must not be exposed through VITE_ variables");
  }
}
// Hosted owner acceptance only. The exact backend schema is installed; media
// calling remains unavailable and server-side authorization is unchanged.
const acceptanceFlags = {
  VITE_NAXA_SERVICES_ROSTER_ENABLED: "true",
  VITE_NAXA_SERVICES_ATTENDANCE_ENABLED: "true",
  VITE_NAXA_SERVICES_BRIEFING_ENABLED: "true",
  VITE_NAXA_SERVICES_MEETINGS_ENABLED: "true"
};
const result = spawnSync("npm", ["run", "build", "--workspace", "@famille/naxa-services-web"], { stdio: "inherit", shell: false, env: { ...process.env, ...acceptanceFlags } });
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
