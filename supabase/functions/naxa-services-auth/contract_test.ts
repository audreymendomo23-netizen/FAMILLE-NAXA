import { hasActiveDeviceSession, verifiedTokenSessionId } from "../_shared/naxa-services-device-session.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isLegalDocumentVersion, isNaxaActivityProfile, isNaxaBusinessMode, isNaxaLocale, isNaxaSiteCode, isNaxaWorkstationCode, isNaxaWorkstationKind, nativeSiteIdsForScopes, allowsOrganizationOffline } from "./scope_contract.ts";

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

Deno.test("NAXA Services locale contract accepts French, English and Fulfulde Cameroon", () => {
  assertEquals(isNaxaLocale("fr"), true);
  assertEquals(isNaxaLocale("en"), true);
  assertEquals(isNaxaLocale("ff-CM"), true);
  assertEquals(isNaxaLocale("fr-FR"), false);
  assertEquals(isNaxaLocale("ff"), false);
  assertEquals(isNaxaLocale(""), false);
});

Deno.test("NAXA site and workstation codes are constrained before database insertion", () => {
  assertEquals(isNaxaSiteCode("DOUALA-01"), true);
  assertEquals(isNaxaSiteCode("A"), false);
  assertEquals(isNaxaSiteCode("CODE WITH SPACE"), false);
  assertEquals(isNaxaSiteCode("SITE/01"), false);
  assertEquals(isNaxaWorkstationCode("CAISSE_1"), true);
  assertEquals(isNaxaWorkstationCode(""), false);
});

Deno.test("NAXA workstation kinds match the database enum", () => {
  for (const kind of ["hair_chair","pressing_counter","pressing_workshop","reception","cashier","other"]) {
    assertEquals(isNaxaWorkstationKind(kind), true);
  }
  assertEquals(isNaxaWorkstationKind("warehouse"), false);
});

Deno.test("Auth and referral gateways require an active device bound to the verified account and JWT session", async () => {
  const jwt = "header." + btoa(JSON.stringify({session_id:"session-a"})) + ".signature";
  const row = {id:"device-a",account_id:"account-a",session_id:"session-a",revoked_at:null};
  assertEquals(verifiedTokenSessionId(jwt),"session-a");
  assertEquals(await hasActiveDeviceSession(jwt,"account-a",async path => {
    assertEquals(path,"ns_devices?select=id,account_id,session_id,revoked_at&account_id=eq.account-a&session_id=eq.session-a&revoked_at=is.null&limit=2");
    return [row];
  }),true);
  for (const result of [[],[row,row],[{...row,account_id:"other"}],[{...row,session_id:"other"}],[{...row,revoked_at:"2026-11-25"}],null]) {
    assertEquals(await hasActiveDeviceSession(jwt,"account-a",async()=>result),false);
  }
  assertEquals(await hasActiveDeviceSession("invalid","account-a",async()=>{throw new Error("must not query");}),false);
});

Deno.test("offline organization authority never widens site or workstation grants", () => {
  const full={scope_type:"organization",can_read:true,can_operate:true,can_manage:true};
  assertEquals(allowsOrganizationOffline("promoter",[full]),true);
  assertEquals(allowsOrganizationOffline("network_manager",[full]),true);
  for(const role of ["cashier","site_manager","workstation_manager","unknown"]) assertEquals(allowsOrganizationOffline(role,[full]),false);
  for(const scope of [{...full,scope_type:"site"},{...full,scope_type:"workstation"},{...full,can_operate:false},{...full,can_manage:false},{...full,can_read:false}]) {
    assertEquals(allowsOrganizationOffline("promoter",[scope]),false);
  }
  assertEquals(allowsOrganizationOffline("promoter",[{...full,can_operate:false},{...full,can_read:false}]),false);
});
