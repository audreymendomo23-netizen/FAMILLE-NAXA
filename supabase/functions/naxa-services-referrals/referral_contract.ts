export type ReferralCadence = "monthly" | "annual";
export type ReferralRewardKind = "monthly_free_cycle" | "annual_extension_month";

export function normalizeReferralCode(value: string): string {
  return value.trim().toUpperCase();
}
export function isValidReferralCode(value: string): boolean {
  return /^NS-[A-Z0-9]{7}$/.test(normalizeReferralCode(value));
}
export function rewardKindForCadence(cadence: string): ReferralRewardKind | null {
  if (cadence === "monthly") return "monthly_free_cycle";
  if (cadence === "annual") return "annual_extension_month";
  return null;
}
export function completedWaveForQualifiedCount(count: number): number | null {
  if (!Number.isSafeInteger(count) || count < 5 || count % 5 !== 0) return null;
  return count / 5;
}
export function progressWithinWave(count: number): number {
  if (!Number.isSafeInteger(count) || count < 0) return 0;
  return count % 5;
}
