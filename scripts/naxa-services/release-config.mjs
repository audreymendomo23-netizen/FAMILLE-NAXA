import { createHash, timingSafeEqual } from "node:crypto";
// Validate only publishable app configuration; never print key material.
export function validateReleaseConfig(env) {
  const get = name => (env[name] || "").trim();
  const project = get("NS_PROJECT_REF");
  if (!/^[a-z0-9]{20}$/.test(project) || project === "ykgjfindlgseegmznaog") {
    throw new Error("NS_PROJECT_REF must identify the dedicated NAXA SERVICES project, not historical NAXA.");
  }
  const key = get("NS_ANON_KEY");
  let publishable = /^sb_publishable_[A-Za-z0-9_-]+$/.test(key);
  if (!publishable && /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(key)) {
    try {
      const claims = JSON.parse(Buffer.from(key.split(".")[1], "base64url").toString("utf8"));
      publishable = claims.role === "anon" && claims.ref === project && Number.isFinite(claims.exp) && claims.exp > Date.now()/1000;
    } catch { /* malformed JWT */ }
  }
  if (!publishable) throw new Error("NS_ANON_KEY must be a publishable key or matching anon JWT, never a privileged key.");
  for (const name of ["NS_FIREBASE_API_KEY", "NS_FIREBASE_APP_ID", "NS_FIREBASE_PROJECT_ID", "NS_FIREBASE_SENDER_ID"]) {
    if (!get(name)) throw new Error("Missing " + name);
  }
  const firebaseProject = get("NS_FIREBASE_PROJECT_ID");
  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(firebaseProject) || firebaseProject === "naxatechnologie") {
    throw new Error("Dedicated Firebase project required; historical NAXA is forbidden.");
  }
  const sender = get("NS_FIREBASE_SENDER_ID");
  if (!/^\d+$/.test(sender) || !get("NS_FIREBASE_APP_ID").startsWith("1:" + sender + ":android:")) {
    throw new Error("Firebase Android app ID and sender ID must belong to the same project.");
  }
  const endpoint = "https://" + project + ".supabase.co/functions/v1/";
  return {
    NS_SUPABASE_PROJECT_REF: project, NS_FAMILY_SUPABASE_PROJECT_REF: project,
    NS_SUPABASE_ANON_KEY: key,
    NS_AUTH_FUNCTION_URL: endpoint + "naxa-services-auth",
    NS_REFERRALS_FUNCTION_URL: endpoint + "naxa-services-referrals",
    NS_ACCOUNTING_FUNCTION_URL: endpoint + "naxa-services-accounting",
    NS_ENABLE_SUPPLIER_SYNC: "true",
    NS_FIREBASE_API_KEY: get("NS_FIREBASE_API_KEY"), NS_FIREBASE_APP_ID: get("NS_FIREBASE_APP_ID"),
    NS_FIREBASE_PROJECT_ID: get("NS_FIREBASE_PROJECT_ID"), NS_FIREBASE_SENDER_ID: sender,
  };
}

// The expected SHA-256 is supplied independently by the approved certificate holder.
export function verifyApprovedSigner(certificate, expectedFingerprint) {
  if (typeof expectedFingerprint !== "string" || !/^[a-fA-F0-9]{64}$/.test(expectedFingerprint)) throw new Error("Missing or invalid independently approved signer fingerprint");
  if (!Buffer.isBuffer(certificate) || certificate.length === 0) throw new Error("Missing certificate");
  const actual = createHash("sha256").update(certificate).digest();
  if (!timingSafeEqual(actual, Buffer.from(expectedFingerprint, "hex"))) throw new Error("Signer differs from independently approved certificate");
  return actual.toString("hex");
}
