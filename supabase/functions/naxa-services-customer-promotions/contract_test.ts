import {
  isAllowedPromotionTransition,
  isCustomerReferralCode,
  normalizeCustomerReferralCampaignDraft,
  normalizeCustomerReferralCode,
  normalizeWheelPrizeDraft,
} from "./promotion_contract.ts";

const ORG = "20000000-0000-4000-8000-000000000001";
const SITE = "30000000-0000-4000-8000-000000000001";

Deno.test("customer referral code normalization is deterministic", () => {
  const code = normalizeCustomerReferralCode("  cref-ABCDEF1234 ");
  if (code !== "CREF-ABCDEF1234" || !isCustomerReferralCode(code)) {
    throw new Error("CUSTOMER_REFERRAL_CODE_NORMALIZATION_FAILED");
  }
  if (isCustomerReferralCode("CREF-TOO-SHORT")) throw new Error("INVALID_CODE_ACCEPTED");
});

Deno.test("customer referral campaigns require explicit reward values and valid dates", () => {
  const draft = normalizeCustomerReferralCampaignDraft({
    site_id: SITE,
    name: "Fidélité test",
    starts_at: "2026-12-01T00:00:00Z",
    ends_at: "2026-12-31T23:59:59Z",
    beneficiary_mode: "both",
    reward_kind: "points",
    reward_value: 100,
    minimum_paid_sale_xaf: 500,
    reward_expiry_days: 30,
    terms_version: "ci-v1",
  }, ORG);
  if (draft.reward_value !== 100 || draft.beneficiary_mode !== "both" || draft.org_id !== ORG) {
    throw new Error("CUSTOMER_REFERRAL_CAMPAIGN_NORMALIZATION_FAILED");
  }
  let rejected = false;
  try {
    normalizeCustomerReferralCampaignDraft({
      name: "No reward",
      starts_at: "2026-12-01T00:00:00Z",
      beneficiary_mode: "both",
      reward_kind: "points",
      reward_value: 0,
      terms_version: "ci-v1",
    }, ORG);
  } catch { rejected = true; }
  if (!rejected) throw new Error("ZERO_VALUE_REWARD_ACCEPTED");
});

Deno.test("wheel prize validation respects kind, positive weight and finite stock", () => {
  const prize = normalizeWheelPrizeDraft({
    label: "Bon de réduction",
    prize_kind: "discount_xaf",
    reward_value: 500,
    weight: 25,
    max_awards: 100,
  });
  if (prize.weight !== 25 || prize.max_awards !== 100) throw new Error("PRIZE_NORMALIZATION_FAILED");
  let rejected = false;
  try {
    normalizeWheelPrizeDraft({
      label: "Invalid no-prize",
      prize_kind: "no_prize",
      reward_value: 100,
      weight: 10,
      max_awards: null,
    });
  } catch { rejected = true; }
  if (!rejected) throw new Error("NO_PRIZE_WITH_VALUE_ACCEPTED");
});

Deno.test("Edge API cannot activate wheel campaigns or approve legal status", () => {
  if (!isAllowedPromotionTransition("draft") || !isAllowedPromotionTransition("legal_review")) {
    throw new Error("SAFE_DRAFT_TRANSITION_REJECTED");
  }
  for (const status of ["approved", "active", "suspended", "expired"]) {
    if (isAllowedPromotionTransition(status)) throw new Error("PRODUCTION_TRANSITION_EXPOSED");
  }
});
