const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PROVIDERS = new Set(["mtn_momo", "orange_money"]);
const TERMINAL_PAYMENT_STATES = new Set(["failed", "expired", "cancelled", "refunded", "reversed"]);

function record(value, code) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new TypeError(code);
  return value;
}
function positiveInteger(value, code) {
  if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError(code);
  return value;
}
function nonNegativeInteger(value, code) {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError(code);
  return value;
}
function dateOnly(value, code) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new TypeError(code);
  const date = new Date(value + "T00:00:00.000Z");
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) throw new RangeError(code);
  return value;
}

/**
 * A 2xx response from an operator means only that the request was accepted.
 * Settlement requires an independently authenticated callback or status query.
 */
export function normalizePaymentIntent(input) {
  const value = record(input, "INVALID_PAYMENT_INTENT");
  if (!PROVIDERS.has(value.provider)) throw new TypeError("UNSUPPORTED_PAYMENT_PROVIDER");
  if (typeof value.organizationId !== "string" || !UUID.test(value.organizationId)) throw new TypeError("INVALID_ORGANIZATION_ID");
  if (typeof value.siteId !== "string" || !UUID.test(value.siteId)) throw new TypeError("INVALID_SITE_ID");
  if (typeof value.idempotencyKey !== "string" || !UUID.test(value.idempotencyKey)) throw new TypeError("INVALID_IDEMPOTENCY_KEY");
  if (typeof value.merchantReference !== "string" || !/^[A-Za-z0-9._-]{8,80}$/.test(value.merchantReference)) {
    throw new TypeError("INVALID_MERCHANT_REFERENCE");
  }
  positiveInteger(value.amountXaf, "INVALID_PAYMENT_AMOUNT");
  if (value.currency !== "XAF") throw new TypeError("UNSUPPORTED_PAYMENT_CURRENCY");
  if (typeof value.beneficiaryReference !== "string" || value.beneficiaryReference.trim().length < 3) {
    throw new TypeError("INVALID_PAYMENT_BENEFICIARY");
  }
  return Object.freeze({
    provider: value.provider,
    organizationId: value.organizationId,
    siteId: value.siteId,
    idempotencyKey: value.idempotencyKey,
    merchantReference: value.merchantReference,
    amountXaf: value.amountXaf,
    currency: "XAF",
    beneficiaryReference: value.beneficiaryReference.trim(),
  });
}

export function classifyProviderInitiation(provider, httpStatus, providerStatus = "") {
  if (!PROVIDERS.has(provider)) throw new TypeError("UNSUPPORTED_PAYMENT_PROVIDER");
  if (!Number.isInteger(httpStatus) || httpStatus < 100 || httpStatus > 599) throw new RangeError("INVALID_HTTP_STATUS");
  if (httpStatus === 408 || httpStatus === 429 || httpStatus >= 500) return "pending";
  if (httpStatus < 200 || httpStatus >= 300) return "failed";
  const normalized = String(providerStatus).trim().toLowerCase();
  if (["failed", "rejected", "declined"].includes(normalized)) return "failed";
  if (["expired"].includes(normalized)) return "expired";
  if (["cancelled", "canceled"].includes(normalized)) return "cancelled";
  // Never infer a successful payment from a synchronous HTTP acknowledgement.
  return "pending";
}

const PROVIDER_STATUS = Object.freeze({
  success: "confirmed",
  succeeded: "confirmed",
  successful: "confirmed",
  completed: "confirmed",
  failed: "failed",
  rejected: "failed",
  declined: "failed",
  expired: "expired",
  cancelled: "cancelled",
  canceled: "cancelled",
  refunded: "refunded",
  reversed: "reversed",
});

export function verifyPaymentConfirmation(intentInput, confirmationInput, verification) {
  const intent = normalizePaymentIntent(intentInput);
  const confirmation = record(confirmationInput, "INVALID_PROVIDER_CONFIRMATION");
  if (verification?.signatureVerified !== true) throw new Error("PROVIDER_SIGNATURE_NOT_VERIFIED");
  const status = PROVIDER_STATUS[String(confirmation.status ?? "").trim().toLowerCase()];
  if (!status) throw new Error("UNKNOWN_PROVIDER_PAYMENT_STATUS");
  if (confirmation.provider !== intent.provider) throw new Error("PAYMENT_PROVIDER_MISMATCH");
  if (confirmation.merchantReference !== intent.merchantReference) throw new Error("PAYMENT_REFERENCE_MISMATCH");
  if (confirmation.amountXaf !== intent.amountXaf) throw new Error("PAYMENT_AMOUNT_MISMATCH");
  if (confirmation.currency !== intent.currency) throw new Error("PAYMENT_CURRENCY_MISMATCH");
  if (typeof confirmation.providerReference !== "string" || confirmation.providerReference.trim().length < 4) {
    throw new Error("PROVIDER_REFERENCE_MISSING");
  }
  return Object.freeze({
    status: status === "confirmed" ? "confirmed" : status,
    provider: intent.provider,
    merchantReference: intent.merchantReference,
    providerReference: confirmation.providerReference,
    amountXaf: intent.amountXaf,
    currency: intent.currency,
    verifiedAt: verification.verifiedAt ?? null,
    verificationMethod: verification.method ?? "authenticated_provider_event",
  });
}

export function assertPaymentTransition(currentState, nextState) {
  const states = new Set(["initiated", "pending", "confirmed", "failed", "expired", "cancelled", "refunded", "reversed"]);
  if (!states.has(currentState) || !states.has(nextState)) throw new TypeError("INVALID_PAYMENT_STATE");
  if (currentState === nextState) return false;
  if (TERMINAL_PAYMENT_STATES.has(currentState)) throw new Error("PAYMENT_STATE_IS_TERMINAL");
  if (nextState === "confirmed" && currentState !== "pending" && currentState !== "initiated") {
    throw new Error("PAYMENT_CANNOT_BE_CONFIRMED_FROM_STATE");
  }
  if (nextState === "failed" || nextState === "expired" || nextState === "cancelled") {
    if (currentState !== "initiated" && currentState !== "pending") throw new Error("PAYMENT_CANNOT_BE_CLOSED_FROM_STATE");
  }
  if (nextState === "refunded" && currentState !== "confirmed") {
    throw new Error("PAYMENT_CANNOT_BE_REFUNDED_FROM_STATE");
  }
  if (nextState === "reversed" && currentState !== "confirmed") {
    throw new Error("PAYMENT_CANNOT_BE_REVERSED_FROM_STATE");
  }
  return true;
}

/** Adapter registration is fail-closed. Provider credentials belong to the server. */
export function createPaymentAdapterRegistry(adapters = []) {
  const registry = new Map();
  for (const adapter of adapters) {
    if (!PROVIDERS.has(adapter?.provider) || typeof adapter.initiate !== "function" ||
        typeof adapter.verifyNotification !== "function" || registry.has(adapter.provider)) {
      throw new TypeError("INVALID_OR_DUPLICATE_PAYMENT_ADAPTER");
    }
    registry.set(adapter.provider, Object.freeze(adapter));
  }
  return Object.freeze({
    supports(provider) { return registry.has(provider); },
    get(provider) {
      const adapter = registry.get(provider);
      if (!adapter) throw new Error("PAYMENT_PROVIDER_ADAPTER_NOT_CONFIGURED");
      return adapter;
    },
    list() { return [...registry.keys()]; },
  });
}

// ----- Staff commission policy: approved and effective-dated only -----

export function validateCommissionRule(ruleInput, calculationDate) {
  const rule = record(ruleInput, "INVALID_COMMISSION_RULE");
  const date = dateOnly(calculationDate, "INVALID_CALCULATION_DATE");
  if (rule.status !== "approved" || !rule.approvedBy || !rule.approvedAt) {
    throw new Error("COMMISSION_RULE_NOT_APPROVED");
  }
  const from = dateOnly(rule.effectiveFrom, "INVALID_COMMISSION_EFFECTIVE_FROM");
  const to = rule.effectiveTo == null ? null : dateOnly(rule.effectiveTo, "INVALID_COMMISSION_EFFECTIVE_TO");
  if (to && to < from) throw new RangeError("INVALID_COMMISSION_EFFECTIVE_RANGE");
  if (date < from || (to && date > to)) throw new Error("COMMISSION_RULE_NOT_EFFECTIVE");
  if (!["percent_bps", "fixed_per_completed_line"].includes(rule.method)) throw new TypeError("INVALID_COMMISSION_METHOD");
  if (rule.method === "percent_bps") {
    nonNegativeInteger(rule.rateBps, "INVALID_COMMISSION_RATE");
    if (rule.rateBps > 10000) throw new RangeError("COMMISSION_RATE_EXCEEDS_100_PERCENT");
  } else {
    positiveInteger(rule.fixedAmountXaf, "INVALID_FIXED_COMMISSION");
  }
  return rule;
}

export function calculateCommission(input) {
  const value = record(input, "INVALID_COMMISSION_INPUT");
  const rule = validateCommissionRule(value.rule, value.calculationDate);
  const saleLine = record(value.saleLine, "INVALID_COMMISSION_SALE_LINE");
  if (saleLine.status !== "completed") throw new Error("SERVICE_NOT_COMPLETED");
  if (saleLine.paymentStatus !== "confirmed") throw new Error("SALE_PAYMENT_NOT_CONFIRMED");
  if (typeof value.sourceEventId !== "string" || !UUID.test(value.sourceEventId)) throw new TypeError("INVALID_COMMISSION_SOURCE_EVENT");
  const paid = nonNegativeInteger(saleLine.confirmedPaidXaf, "INVALID_CONFIRMED_PAYMENT");
  const refunded = nonNegativeInteger(saleLine.refundedXaf ?? 0, "INVALID_REFUND_AMOUNT");
  const eligible = nonNegativeInteger(saleLine.commissionableBaseXaf, "INVALID_COMMISSIONABLE_BASE");
  if (refunded > paid) throw new RangeError("REFUND_EXCEEDS_CONFIRMED_PAYMENT");
  const base = Math.max(0, Math.min(eligible, paid) - refunded);
  if (base === 0) return Object.freeze({ status: "no_commission", baseXaf: 0, totalCommissionXaf: 0, entries: [] });

  const total = rule.method === "percent_bps"
    ? Number((BigInt(base) * BigInt(rule.rateBps)) / 10000n)
    : rule.fixedAmountXaf;
  if (!Number.isSafeInteger(total) || total < 0) throw new RangeError("COMMISSION_TOTAL_OUT_OF_RANGE");

  const allocations = value.allocations;
  if (!Array.isArray(allocations) || allocations.length === 0 || allocations.length > 20) {
    throw new TypeError("INVALID_COMMISSION_ALLOCATIONS");
  }
  const normalized = allocations.map((allocation) => {
    record(allocation, "INVALID_COMMISSION_ALLOCATION");
    if (typeof allocation.memberId !== "string" || !UUID.test(allocation.memberId)) throw new TypeError("INVALID_COMMISSION_MEMBER");
    nonNegativeInteger(allocation.shareBps, "INVALID_COMMISSION_SHARE");
    return { memberId: allocation.memberId.toLowerCase(), shareBps: allocation.shareBps };
  }).sort((a, b) => a.memberId.localeCompare(b.memberId));
  if (new Set(normalized.map((x) => x.memberId)).size !== normalized.length ||
      normalized.reduce((sum, x) => sum + x.shareBps, 0) !== 10000) {
    throw new Error("COMMISSION_SHARES_MUST_TOTAL_10000_BPS");
  }

  const entries = normalized.map((allocation) => ({
    memberId: allocation.memberId,
    amountXaf: Number((BigInt(total) * BigInt(allocation.shareBps)) / 10000n),
    status: "pending_approval",
    sourceEventId: value.sourceEventId.toLowerCase(),
    idempotencyKey: value.sourceEventId.toLowerCase() + ":" + allocation.memberId,
    ruleVersion: rule.version,
  }));
  let remainder = total - entries.reduce((sum, entry) => sum + entry.amountXaf, 0);
  for (const [index, entry] of entries.entries()) {
    if (remainder <= 0) break;
    if (normalized[index].shareBps === 0) continue;
    entry.amountXaf += 1;
    remainder -= 1;
  }
  return Object.freeze({
    status: "pending_approval",
    baseXaf: base,
    totalCommissionXaf: total,
    currency: "XAF",
    entries: entries.map((entry) => Object.freeze(entry)),
  });
}

/** A refund never edits a posted commission; it creates a linked negative adjustment. */
export function reverseCommission(input) {
  const value = record(input, "INVALID_COMMISSION_REVERSAL");
  positiveInteger(value.originalAmountXaf, "INVALID_ORIGINAL_COMMISSION");
  positiveInteger(value.refundAmountXaf, "INVALID_COMMISSION_REFUND");
  if (typeof value.reversalEventId !== "string" || !UUID.test(value.reversalEventId)) {
    throw new TypeError("INVALID_REVERSAL_EVENT");
  }
  // The caller must obtain prior adjustments from the authoritative ledger under lock.
  const alreadyReversedXaf = nonNegativeInteger(value.alreadyReversedXaf ?? 0, "INVALID_PRIOR_COMMISSION_REVERSAL");
  if (alreadyReversedXaf > value.originalAmountXaf || value.refundAmountXaf > value.originalAmountXaf - alreadyReversedXaf) {
    throw new RangeError("REVERSAL_EXCEEDS_ORIGINAL_COMMISSION");
  }
  if (typeof value.sourceEntryId !== "string" || !value.sourceEntryId.trim()) throw new TypeError("INVALID_COMMISSION_SOURCE_ENTRY");
  return Object.freeze({
    sourceEntryId: value.sourceEntryId,
    reversalEventId: value.reversalEventId,
    amountXaf: -value.refundAmountXaf,
    status: "pending_approval",
    idempotencyKey: value.reversalEventId + ":commission-reversal",
  });
}

// ----- Fiscal parameter engine: no universal or unvalidated default rates -----

export function validateFiscalPolicy(policyInput, transactionDate) {
  const policy = record(policyInput, "INVALID_FISCAL_POLICY");
  const date = dateOnly(transactionDate, "INVALID_TRANSACTION_DATE");
  if (policy.status !== "approved" || !policy.approvedBy || !policy.approvedAt ||
      typeof policy.sourceReference !== "string" || policy.sourceReference.trim().length < 8) {
    throw new Error("FISCAL_POLICY_NOT_PROFESSIONALLY_APPROVED");
  }
  const from = dateOnly(policy.effectiveFrom, "INVALID_FISCAL_EFFECTIVE_FROM");
  const to = policy.effectiveTo == null ? null : dateOnly(policy.effectiveTo, "INVALID_FISCAL_EFFECTIVE_TO");
  if (to && to < from) throw new RangeError("INVALID_FISCAL_EFFECTIVE_RANGE");
  if (date < from || (to && date > to)) throw new Error("FISCAL_POLICY_NOT_EFFECTIVE");
  if (!["output_tax", "input_tax", "withholding"].includes(policy.taxType)) throw new TypeError("INVALID_FISCAL_TAX_TYPE");
  nonNegativeInteger(policy.rateBps, "INVALID_FISCAL_RATE");
  if (policy.rateBps > 10000) throw new RangeError("FISCAL_RATE_EXCEEDS_100_PERCENT");
  if (!["exclusive", "inclusive"].includes(policy.priceMode)) throw new TypeError("INVALID_FISCAL_PRICE_MODE");
  return policy;
}

export function calculateFiscalQuote(input) {
  const value = record(input, "INVALID_FISCAL_QUOTE");
  const base = positiveInteger(value.amountXaf, "INVALID_FISCAL_BASE");
  if (value.policy == null) return Object.freeze({ status: "blocked_unvalidated_policy", amountXaf: null, totalXaf: null, reason: "FISCAL_POLICY_NOT_PROFESSIONALLY_APPROVED" });
  let policy;
  try {
    policy = validateFiscalPolicy(value.policy, value.transactionDate);
  } catch (error) {
    if (["FISCAL_POLICY_NOT_PROFESSIONALLY_APPROVED", "FISCAL_POLICY_NOT_EFFECTIVE"].includes(error.message)) {
      return Object.freeze({ status: "blocked_unvalidated_policy", amountXaf: null, totalXaf: null, reason: error.message });
    }
    throw error;
  }
  if (value.exempt === true) {
    return Object.freeze({ status: "calculated_by_approved_policy", taxType: policy.taxType, baseXaf: base, taxXaf: 0, totalXaf: base, exempt: true, policyVersion: policy.version });
  }
  let taxableBase = base;
  let tax;
  if (policy.priceMode === "inclusive") {
    taxableBase = Number((BigInt(base) * 10000n) / (10000n + BigInt(policy.rateBps)));
    tax = base - taxableBase;
  } else {
    tax = Number((BigInt(base) * BigInt(policy.rateBps)) / 10000n);
  }
  const totalXaf = policy.priceMode === "inclusive" ? base : base + tax;
  if (!Number.isSafeInteger(totalXaf)) throw new RangeError("FISCAL_TOTAL_OUT_OF_RANGE");
  return Object.freeze({
    status: "calculated_by_approved_policy",
    taxType: policy.taxType,
    baseXaf: taxableBase,
    taxXaf: tax,
    totalXaf,
    exempt: false,
    policyVersion: policy.version,
    sourceReference: policy.sourceReference,
  });
}
