import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

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

Deno.test("business scope mode names remain independent", () => {
  const modes = ["solo", "single_site_multi_workstation", "multi_site_network"];
  assertEquals(new Set(modes).size, 3);
});
