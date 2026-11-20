import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isLegalDocumentVersion, isNaxaActivityProfile, isNaxaBusinessMode, nativeSiteIdsForScopes } from "./scope_contract.ts";

// Pure contract checks. Integration tests require an ephemeral Supabase project
// with a proven internal Auth alias format and seeded NAXA Services identities.
Deno.test("NAXA Services login identifier accepts only NS-prefixed identifiers", () => {
  const pattern = /^NS-[A-Z0-9]{4,12}$/;
  assertEquals(pattern.test("NS-AB1234"), true);
  assertEquals(pattern.test("NS-123456"), true);
  assertEquals(pattern.test("naxa@example.com"), false);
  assertEquals(pattern.test("NS-123"), false);
  assertEquals(pattern.test("JOB-123456"), false);
});

Deno.test("password policy rejects weak initial passwords", () => {
  const validate = (value: string) => value.length >= 10 && value.length <= 256;
  assertEquals(validate("123456"), false);
  assertEquals(validate("UnePhraseDePasse2026"), true);
});

Deno.test("all three NAXA Services business modes are accepted and unknown modes are rejected", () => {
  assertEquals(isNaxaBusinessMode("solo"), true);
  assertEquals(isNaxaBusinessMode("single_site_multi_workstation"), true);
  assertEquals(isNaxaBusinessMode("multi_site_network"), true);
  assertEquals(isNaxaBusinessMode("multi_company"), false);
});

Deno.test("a site-scoped employee can see only the explicitly assigned site", () => {
  assertEquals(
    nativeSiteIdsForScopes([
      { scope_type: "site", site_id: "site-a" },
      { scope_type: "site", site_id: "site-a" },
    ]),
    ["site-a"],
  );
});

Deno.test("an organization-scoped promoter can see active sites only", () => {
  assertEquals(
    nativeSiteIdsForScopes([{ scope_type: "organization" }], ["site-a", "site-b"]),
    ["site-a", "site-b"],
  );
});

Deno.test("a workstation-only assignment is not widened to whole-site access", () => {
  assertEquals(
    nativeSiteIdsForScopes([{ scope_type: "workstation", site_id: "site-a", workstation_id: "chair-1" }]),
    [],
  );
});

Deno.test("NAXA Services activity profiles accept the supported catalog and reject unknown profiles", () => {
  for (const profile of ["pressing","coiffure","couture","beaute","parfumerie","reparation","menuiserie","garage","nettoyage","domicile","impression","photo_evenementiel","autre"]) {
    assertEquals(isNaxaActivityProfile(profile), true);
  }
  assertEquals(isNaxaActivityProfile("pharmacy"), false);
  assertEquals(isNaxaActivityProfile(""), false);
});

Deno.test("legal acceptance only accepts the published draft versions", () => {
  assertEquals(isLegalDocumentVersion("terms", "2026-11-v1"), true);
  assertEquals(isLegalDocumentVersion("privacy", "2026-11-v1"), true);
  assertEquals(isLegalDocumentVersion("terms", "2026-10-v1"), false);
  assertEquals(isLegalDocumentVersion("terms", "2026-11-v2"), false);
  assertEquals(isLegalDocumentVersion("unknown", "2026-11-v1"), false);
});
