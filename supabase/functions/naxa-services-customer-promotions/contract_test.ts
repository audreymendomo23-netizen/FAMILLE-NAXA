import {
  promotionHttpResponse,
  isAllowedPromotionTransition,
  isCustomerReferralCode,
  normalizeCustomerPhone,
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

Deno.test("customer phone normalization is strict and deterministic", () => {
  if (normalizeCustomerPhone("+237 699 00 11 22") !== "237699001122") throw new Error("PHONE_NORMALIZATION_FAILED");
  let rejected = false;
  try { normalizeCustomerPhone("12-34"); } catch { rejected = true; }
  if (!rejected) throw new Error("INVALID_PHONE_ACCEPTED");
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
    terms_text: "Le parrain reçoit un avantage après le premier achat entièrement encaissé du filleul. Les conditions de validité, exclusions et expiration sont affichées au client.",
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
      terms_text: "Conditions explicites suffisamment détaillées pour une campagne de test.",
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

Deno.test("promotion preflight is bodyless and restricts browser origins", async () => {
  const origin = "https://famille-naxa.pages.dev";
  const response = promotionHttpResponse(204, {}, origin, [origin]);
  if (response.status !== 204 || await response.text() !== "" || response.headers.get("Access-Control-Allow-Origin") !== origin) throw new Error("PREFLIGHT_FAILED");
  const foreign = promotionHttpResponse(204, {}, "https://untrusted.invalid", [origin, "*"]);
  if (foreign.headers.get("Access-Control-Allow-Origin") !== "null") throw new Error("FOREIGN_ORIGIN_ALLOWED");
  const error = promotionHttpResponse(401, {error:"AUTHENTICATION_REQUIRED"}, origin, [origin]);
  if (error.status !== 401 || (await error.json()).error !== "AUTHENTICATION_REQUIRED") throw new Error("JSON_ERROR_CHANGED");
});
