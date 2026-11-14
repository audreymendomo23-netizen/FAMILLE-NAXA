import test from "node:test";
import assert from "node:assert/strict";
import { verifyArtifactDigest, isVersionAllowed } from "../src/release/verifyManifest.js";
import { isSafeMessage, buildWaMeUrl } from "../src/whatsapp/safeMessage.js";
import { createHash } from "node:crypto";

test("artifact digest accepts exact bytes only", () => {
  const bytes = Buffer.from("apk-fixture");
  const digest = createHash("sha256").update(bytes).digest("hex");
  assert.equal(verifyArtifactDigest(bytes, digest), true);
  assert.equal(verifyArtifactDigest(Buffer.from("tampered"), digest), false);
});

test("minimum version blocks obsolete build", () => {
  assert.equal(isVersionAllowed(12, 12), true);
  assert.equal(isVersionAllowed(11, 12), false);
});

test("WhatsApp text rejects PIN/OTP and numeric codes", () => {
  assert.equal(isSafeMessage("Votre rapport est prêt."), true);
  assert.equal(isSafeMessage("Votre OTP est 123456"), false);
  assert.equal(isSafeMessage("Code secret: 1234"), false);
});

test("wa.me URL encodes French text and rejects unsafe content", () => {
  const url = buildWaMeUrl("237690000000", "Bonjour, votre rapport est prêt.");
  assert.match(url, /^https:\/\/wa\.me\/237690000000\?text=/);
  assert.throws(() => buildWaMeUrl("237690000000", "PIN 1234"), /unsafe_message_content/);
});
