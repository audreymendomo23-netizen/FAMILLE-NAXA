import { test } from "node:test";
import assert from "node:assert/strict";
import { validateReleaseConfig } from "./release-config.mjs";
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
  assert.equal(validateReleaseConfig({...valid,NS_ANON_KEY:jwt({role:"anon",ref:project})}).NS_ENABLE_SUPPLIER_SYNC,"true");
});
test("release configuration rejects missing or inconsistent Firebase app configuration", () => {
  for (const name of ["NS_FIREBASE_API_KEY","NS_FIREBASE_APP_ID","NS_FIREBASE_PROJECT_ID","NS_FIREBASE_SENDER_ID"]) {
    assert.throws(() => validateReleaseConfig({...valid,[name]:""}), /Missing/);
  }
  assert.throws(() => validateReleaseConfig({...valid,NS_FIREBASE_APP_ID:"1:999:android:fixture"}), /same project/);
});
