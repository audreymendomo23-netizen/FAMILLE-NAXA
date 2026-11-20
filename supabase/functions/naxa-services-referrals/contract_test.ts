import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  completedWaveForQualifiedCount,
  isValidReferralCode,
  normalizeReferralCode,
  progressWithinWave,
  rewardKindForCadence,
} from "./referral_contract.ts";

Deno.test("normalizes and validates a generated NAXA referral code", () => {
  assertEquals(normalizeReferralCode(" ns-ab12cd3 "), "NS-AB12CD3");
  assertEquals(isValidReferralCode(" ns-ab12cd3 "), true);
  assertEquals(isValidReferralCode("NS-ABC"), false);
  assertEquals(isValidReferralCode("NS-ABCDEFG!"), false);
});
Deno.test("a reward is unlocked only for each completed block of five", () => {
  assertEquals(completedWaveForQualifiedCount(4), null);
  assertEquals(completedWaveForQualifiedCount(5), 1);
  assertEquals(completedWaveForQualifiedCount(9), null);
  assertEquals(completedWaveForQualifiedCount(10), 2);
  assertEquals(progressWithinWave(8), 3);
});
Deno.test("reward kind follows the referrer's current paid cadence", () => {
  assertEquals(rewardKindForCadence("monthly"), "monthly_free_cycle");
  assertEquals(rewardKindForCadence("annual"), "annual_extension_month");
  assertEquals(rewardKindForCadence("trial"), null);
});
