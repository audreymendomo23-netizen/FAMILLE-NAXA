import { test } from "node:test";
import assert from "node:assert/strict";
import { validateReleaseConfig, verifyApprovedSigner } from "./release-config.mjs";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
const project = "abcdefghijklmnopqrst";
const valid = {
  NS_PROJECT_REF: project, NS_ANON_KEY: "sb_publishable_ci_fixture",
  NS_FIREBASE_API_KEY: "fixture", NS_FIREBASE_APP_ID: "1:123456:android:fixture",
  NS_FIREBASE_PROJECT_ID: "fixture-project", NS_FIREBASE_SENDER_ID: "123456",
};
const jwt = claims => "eyJhbGciOiJIUzI1NiJ9." + Buffer.from(JSON.stringify(claims)).toString("base64url") + ".fixture";
test("release configuration points every endpoint to the dedicated project and enables synchronization", () => {
  const config = validateReleaseConfig(valid);
  assert.equal(config.NS_SUPABASE_PROJECT_REF, project);
  assert.equal(config.NS_FAMILY_SUPABASE_PROJECT_REF, project);
  assert.equal(config.NS_AUTH_FUNCTION_URL, "https://" + project + ".supabase.co/functions/v1/naxa-services-auth");
  assert.equal(config.NS_ACCOUNTING_FUNCTION_URL, "https://" + project + ".supabase.co/functions/v1/naxa-services-accounting");
  assert.equal(config.NS_ENABLE_SUPPLIER_SYNC, "true");
});
test("release configuration rejects pharmacy project, empty configuration, and privileged keys", () => {
  assert.throws(() => validateReleaseConfig({}), /dedicated/);
  assert.throws(() => validateReleaseConfig({...valid, NS_PROJECT_REF:"ykgjfindlgseegmznaog"}), /dedicated/);
  for (const key of ["", "sb_secret_fixture", jwt({role:"service_role",ref:project}), jwt({role:"anon",ref:"other"})]) {
    assert.throws(() => validateReleaseConfig({...valid,NS_ANON_KEY:key}), /publishable/);
  }
  assert.equal(validateReleaseConfig({...valid,NS_ANON_KEY:jwt({role:"anon",ref:project,exp:Math.floor(Date.now()/1000)+3600})}).NS_ENABLE_SUPPLIER_SYNC,"true");
});
test("release configuration rejects missing or inconsistent Firebase app configuration", () => {
  for (const name of ["NS_FIREBASE_API_KEY","NS_FIREBASE_APP_ID","NS_FIREBASE_PROJECT_ID","NS_FIREBASE_SENDER_ID"]) {
    assert.throws(() => validateReleaseConfig({...valid,[name]:""}), /Missing/);
  }
  assert.throws(() => validateReleaseConfig({...valid,NS_FIREBASE_APP_ID:"1:999:android:fixture"}), /same project/);
});

test("release rejects the historical pharmacy Firebase project", () => {
  assert.throws(() => validateReleaseConfig({...valid,NS_FIREBASE_PROJECT_ID:"naxatechnologie"}), /Dedicated Firebase/);
});

test("approved signer comparison fails closed and accepts only matching independently supplied fingerprint", () => {
  const cert = Buffer.from("fixture certificate - no key material");
  const approved = createHash("sha256").update(cert).digest("hex");
  assert.equal(verifyApprovedSigner(cert, approved.toUpperCase()), approved);
  for (const invalid of [undefined, "", "x".repeat(64), "0".repeat(63), approved+"\n"]) assert.throws(() => verifyApprovedSigner(cert,invalid),/independently approved/);
  assert.throws(() => verifyApprovedSigner(Buffer.from("different certificate"),approved),/differs/);
  assert.throws(() => verifyApprovedSigner(Buffer.alloc(0),approved),/Missing certificate/);
});
test("real release workflow enforces independent certificate check before signing, with explicit release trigger only", () => {
  const release = readFileSync(new URL("../../.github/workflows/naxa-services-release.yml",import.meta.url),"utf8");
  const ready = readFileSync(new URL("../../.github/workflows/naxa-services-release-readiness.yml",import.meta.url),"utf8");
  for (const workflow of [release,ready]) {
    assert.ok(workflow.includes("vars.NAXA_SERVICES_APPROVED_SIGNER_SHA256"));
    assert.ok(workflow.includes("verifyApprovedSigner(readFileSync"));
  }
  assert.ok(release.indexOf("verifyApprovedSigner(readFileSync") < release.indexOf("gradle --no-daemon :naxa-services:assembleRelease"));
  assert.ok(release.includes("workflow_dispatch:") && !release.includes("branches:"));
});

test("Android release rejects expired or undated anon JWTs just like Web preflight",()=>{
 for(const exp of [undefined,null,"9999999999",0,Math.floor(Date.now()/1000)-10])assert.throws(()=>validateReleaseConfig({...valid,NS_ANON_KEY:jwt({role:"anon",ref:project,exp})}),/publishable/);
});
