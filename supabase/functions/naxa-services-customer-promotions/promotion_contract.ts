export const CUSTOMER_PROMOTION_ACTIONS = [
  "create_customer_referral_campaign",
  "create_customer_referral_code",
  "apply_customer_referral_code",
  "customer_referral_dashboard",
  "customer_sale_first_paid",
  "create_wheel_campaign",
  "add_wheel_prize",
  "spin_wheel",
] as const;

export type CustomerPromotionAction = typeof CUSTOMER_PROMOTION_ACTIONS[number];
export type BeneficiaryMode = "referrer" | "both";
export type CustomerRewardKind = "points" | "discount_xaf" | "credit_xaf" | "free_service";
export type WheelPrizeKind = "no_prize" | "points" | "discount_xaf" | "credit_xaf" | "free_service" | "product";

export interface CustomerReferralCampaignDraft {
  org_id: string;
  site_id: string | null;
  name: string;
  starts_at: string;
  ends_at: string | null;
  beneficiary_mode: BeneficiaryMode;
  reward_kind: CustomerRewardKind;
  reward_value: number;
  minimum_paid_sale_xaf: number;
  reward_expiry_days: number | null;
  terms_version: string;
}

export interface WheelPrizeDraft {
  label: string;
  prize_kind: WheelPrizeKind;
  reward_value: number;
  weight: number;
  max_awards: number | null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REFERRAL_CODE = /^CREF-[A-F0-9]{10}$/;

export function normalizeCustomerReferralCode(value: unknown): string {
  return typeof value === "string" ? value.trim().toUpperCase() : "";
}

export function isCustomerReferralCode(value: unknown): value is string {
  return typeof value === "string" && REFERRAL_CODE.test(normalizeCustomerReferralCode(value));
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}

function safeText(value: unknown, min: number, max: number): string {
  if (typeof value !== "string") throw new Error("INVALID_TEXT");
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max) throw new Error("INVALID_TEXT");
  return normalized;
}

function safeInteger(value: unknown, min: number, max: number, code: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new Error(code);
  }
  return value;
}

export function normalizeCustomerReferralCampaignDraft(
  input: Record<string, unknown>,
  orgId: string,
): CustomerReferralCampaignDraft {
  if (!isUuid(orgId)) throw new Error("INVALID_ORG_ID");
  const siteId = input.site_id === null || input.site_id === undefined || input.site_id === ""
    ? null
    : input.site_id;
  if (siteId !== null && !isUuid(siteId)) throw new Error("INVALID_SITE_ID");
  const beneficiaryMode = input.beneficiary_mode;
  if (beneficiaryMode !== "referrer" && beneficiaryMode !== "both") {
    throw new Error("INVALID_BENEFICIARY_MODE");
  }
  const rewardKind = input.reward_kind;
  if (!["points", "discount_xaf", "credit_xaf", "free_service"].includes(String(rewardKind))) {
    throw new Error("INVALID_REWARD_KIND");
  }
  const startsAt = safeText(input.starts_at, 10, 40);
  const start = Date.parse(startsAt);
  if (!Number.isFinite(start)) throw new Error("INVALID_START_DATE");
  const endsAt = input.ends_at === null || input.ends_at === undefined || input.ends_at === ""
    ? null
    : safeText(input.ends_at, 10, 40);
  if (endsAt !== null && (!Number.isFinite(Date.parse(endsAt)) || Date.parse(endsAt) <= start)) {
    throw new Error("INVALID_END_DATE");
  }
  const expiry = input.reward_expiry_days === null || input.reward_expiry_days === undefined || input.reward_expiry_days === ""
    ? null
    : safeInteger(input.reward_expiry_days, 1, 3650, "INVALID_REWARD_EXPIRY");
  return {
    org_id: orgId,
    site_id: siteId as string | null,
    name: safeText(input.name, 2, 100),
    starts_at: new Date(start).toISOString(),
    ends_at: endsAt === null ? null : new Date(Date.parse(endsAt)).toISOString(),
    beneficiary_mode: beneficiaryMode,
    reward_kind: rewardKind as CustomerRewardKind,
    reward_value: safeInteger(input.reward_value, 1, 1_000_000_000, "INVALID_REWARD_VALUE"),
    minimum_paid_sale_xaf: safeInteger(input.minimum_paid_sale_xaf ?? 0, 0, 1_000_000_000_000, "INVALID_MINIMUM_SALE"),
    reward_expiry_days: expiry,
    terms_version: safeText(input.terms_version, 1, 80),
  };
}

export function normalizeWheelPrizeDraft(input: Record<string, unknown>): WheelPrizeDraft {
  const prizeKind = input.prize_kind;
  if (!["no_prize", "points", "discount_xaf", "credit_xaf", "free_service", "product"].includes(String(prizeKind))) {
    throw new Error("INVALID_PRIZE_KIND");
  }
  const rewardValue = safeInteger(input.reward_value, 0, 1_000_000_000, "INVALID_PRIZE_VALUE");
  if (prizeKind === "no_prize" ? rewardValue !== 0 : rewardValue <= 0) {
    throw new Error("INVALID_PRIZE_VALUE_FOR_KIND");
  }
  const maxAwards = input.max_awards === null || input.max_awards === undefined || input.max_awards === ""
    ? null
    : safeInteger(input.max_awards, 1, 1_000_000, "INVALID_PRIZE_CAP");
  return {
    label: safeText(input.label, 1, 100),
    prize_kind: prizeKind as WheelPrizeKind,
    reward_value: rewardValue,
    weight: safeInteger(input.weight, 1, 1_000_000, "INVALID_PRIZE_WEIGHT"),
    max_awards: maxAwards,
  };
}

export function isAllowedPromotionTransition(nextStatus: unknown): nextStatus is "draft" | "legal_review" {
  // There is deliberately no API transition to approved/active. Written legal proof
  // and explicit business authorization are external release gates.
  return nextStatus === "draft" || nextStatus === "legal_review";
}
