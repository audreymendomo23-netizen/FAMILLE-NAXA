import { createHash } from "node:crypto";

/**
 * Validates a release manifest's content digest and minimum-version gate.
 * The manifest itself must arrive over HTTPS from the official NAXA origin.
 * This digest is integrity evidence, not APK signing verification: Android
 * must additionally verify the installed package signing certificate.
 */
export function verifyArtifactDigest(bytes, expectedSha256) {
  if (!/^[a-f0-9]{64}$/i.test(expectedSha256)) return false;
  const actual = createHash("sha256").update(bytes).digest("hex");
  return actual === expectedSha256.toLowerCase();
}

export function isVersionAllowed(installedCode, minimumCode) {
  if (!Number.isSafeInteger(installedCode) || !Number.isSafeInteger(minimumCode)) {
    throw new TypeError("version_code_must_be_integer");
  }
  return installedCode >= minimumCode;
}
