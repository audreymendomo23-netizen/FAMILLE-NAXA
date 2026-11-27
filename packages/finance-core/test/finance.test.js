import test from "node:test";
import assert from "node:assert/strict";
import {
  normalizePaymentIntent, classifyProviderInitiation, verifyPaymentConfirmation,
  assertPaymentTransition, createPaymentAdapterRegistry, calculateCommission,
  reverseCommission, calculateFiscalQuote, prepareAutomaticCommission, prepareAutomaticCommissionFromDatabase,
} from "../src/index.js";

const intent = {
  provider: "mtn_momo",
  organizationId: "20000000-0000-4000-8000-000000000001",
  siteId: "30000000-0000-4000-8000-000000000001",
  idempotencyKey: "40000000-0000-4000-8000-000000000001",
  merchantReference: "NS-INV-2026-0001",
  amountXaf: 12500,
  currency: "XAF",
  beneficiaryReference: "merchant-cm-001",
};
const confirmation = {
  provider: "mtn_momo", merchantReference: intent.merchantReference,
  providerReference: "provider-ref-2026-001", amountXaf: 12500,
  currency: "XAF", status: "SUCCESSFUL",
};

test("payment initiation acknowledgements never mean paid", () => {
  assert.equal(classifyProviderInitiation("mtn_momo", 202, "SUCCESSFUL"), "pending");
  assert.equal(classifyProviderInitiation("orange_money", 200, "PENDING"), "pending");
  assert.equal(classifyProviderInitiation("mtn_momo", 503), "pending");
  assert.equal(classifyProviderInitiation("orange_money", 200, "DECLINED"), "failed");
});
test("payment intent validates XAF, scope, provider and idempotency", () => {
  assert.equal(normalizePaymentIntent(intent).amountXaf, 12500);
  assert.throws(() => normalizePaymentIntent({ ...intent, currency: "USD" }), /UNSUPPORTED_PAYMENT_CURRENCY/);
  assert.throws(() => normalizePaymentIntent({ ...intent, provider: "unknown" }), /UNSUPPORTED_PAYMENT_PROVIDER/);
  assert.throws(() => normalizePaymentIntent({ ...intent, amountXaf: 0 }), /INVALID_PAYMENT_AMOUNT/);
});
test("payment confirmation requires verified signature and exact amount/reference/currency", () => {
  assert.throws(() => verifyPaymentConfirmation(intent, confirmation, { signatureVerified: false }), /PROVIDER_SIGNATURE_NOT_VERIFIED/);
  assert.throws(() => verifyPaymentConfirmation(intent, { ...confirmation, amountXaf: 12501 }, { signatureVerified: true }), /PAYMENT_AMOUNT_MISMATCH/);
  assert.throws(() => verifyPaymentConfirmation(intent, { ...confirmation, merchantReference: "other-reference" }, { signatureVerified: true }), /PAYMENT_REFERENCE_MISMATCH/);
  const result = verifyPaymentConfirmation(intent, confirmation, { signatureVerified: true, method: "provider_webhook_signature", verifiedAt: "2026-11-21T19:00:00Z" });
  assert.equal(result.status, "confirmed");
  assert.equal(result.amountXaf, 12500);
  assert.equal(result.providerReference, confirmation.providerReference);
  const reversal = verifyPaymentConfirmation(intent, {
    ...confirmation, status: "REVERSED", providerReference: "provider-ref-reversal-001",
  }, { signatureVerified: true, method: "provider_status_poll" });
  assert.equal(reversal.status, "reversed");
});
test("payment state machine aligns with ERP confirmed, refunded and reversed states", () => {
  assert.equal(assertPaymentTransition("pending", "confirmed"), true);
  assert.equal(assertPaymentTransition("pending", "pending"), false);
  assert.equal(assertPaymentTransition("confirmed", "refunded"), true);
  assert.equal(assertPaymentTransition("confirmed", "reversed"), true);
  assert.throws(() => assertPaymentTransition("pending", "refunded"), /PAYMENT_CANNOT_BE_REFUNDED_FROM_STATE/);
  assert.throws(() => assertPaymentTransition("refunded", "confirmed"), /PAYMENT_STATE_IS_TERMINAL/);
});
test("payment provider registry fails closed without an adapter", () => {
  const registry = createPaymentAdapterRegistry([]);
  assert.equal(registry.supports("mtn_momo"), false);
  assert.throws(() => registry.get("orange_money"), /PAYMENT_PROVIDER_ADAPTER_NOT_CONFIGURED/);
  assert.equal(createPaymentAdapterRegistry([{
    provider: "mtn_momo", initiate: async () => ({}), verifyNotification: async () => true,
  }]).supports("mtn_momo"), true);
});

const approvedRule = {
  version: 3, status: "approved", approvedBy: "member-finance-lead",
  approvedAt: "2026-11-01T09:00:00Z", effectiveFrom: "2026-11-01",
  effectiveTo: null, method: "percent_bps", rateBps: 1000,
};
const saleLine = {
  status: "completed", paymentStatus: "confirmed", confirmedPaidXaf: 50000,
  refundedXaf: 5000, commissionableBaseXaf: 45000,
};
const allocations = [
  { memberId: "50000000-0000-4000-8000-000000000002", shareBps: 3333 },
  { memberId: "50000000-0000-4000-8000-000000000001", shareBps: 6667 },
];

test("commission calculates only after completion and confirmed payment, net of refunds", () => {
  const result = calculateCommission({
    rule: approvedRule, saleLine, allocations,
    calculationDate: "2026-11-21",
    sourceEventId: "60000000-0000-4000-8000-000000000001",
  });
  assert.equal(result.baseXaf, 40000);
  assert.equal(result.totalCommissionXaf, 4000);
  assert.equal(result.entries.reduce((sum, item) => sum + item.amountXaf, 0), 4000);
  assert.ok(result.entries.every((item) => item.status === "pending_approval"));
});
test("commission refuses draft rates and unpaid or incomplete work", () => {
  assert.throws(() => calculateCommission({
    rule: { ...approvedRule, status: "draft" }, saleLine, allocations,
    calculationDate: "2026-11-21", sourceEventId: "60000000-0000-4000-8000-000000000001",
  }), /COMMISSION_RULE_NOT_APPROVED/);
  assert.throws(() => calculateCommission({
    rule: approvedRule, saleLine: { ...saleLine, paymentStatus: "pending" }, allocations,
    calculationDate: "2026-11-21", sourceEventId: "60000000-0000-4000-8000-000000000001",
  }), /SALE_PAYMENT_NOT_CONFIRMED/);
});
test("commission shares must sum exactly to 100 percent", () => {
  assert.throws(() => calculateCommission({
    rule: approvedRule, saleLine, allocations: [{ ...allocations[0], shareBps: 9000 }],
    calculationDate: "2026-11-21", sourceEventId: "60000000-0000-4000-8000-000000000001",
  }), /COMMISSION_SHARES_MUST_TOTAL_10000_BPS/);
});
test("refund reversals are append-only adjustments", () => {
  const reversal = reverseCommission({
    sourceEntryId: "commission-entry-001", originalAmountXaf: 4000,
    refundAmountXaf: 1000, reversalEventId: "70000000-0000-4000-8000-000000000001",
  });
  assert.equal(reversal.amountXaf, -1000);
  assert.equal(reversal.status, "pending_approval");
  assert.throws(() => reverseCommission({
    originalAmountXaf: 1000, refundAmountXaf: 1500,
    reversalEventId: "70000000-0000-4000-8000-000000000001",
  }), /REVERSAL_EXCEEDS_ORIGINAL_COMMISSION/);
});

const approvedTaxPolicy = {
  version: "CGI-CM-2026-v1", status: "approved", approvedBy: "tax-advisor-01",
  approvedAt: "2026-11-01T10:00:00Z", effectiveFrom: "2026-01-01",
  effectiveTo: null, taxType: "output_tax", rateBps: 1925, priceMode: "exclusive",
  sourceReference: "DGI CGI 2026 — tax policy reviewed",
};

test("fiscal calculation blocks when policy is absent, draft or stale", () => {
  assert.equal(calculateFiscalQuote({ amountXaf: 10000, transactionDate: "2026-11-21" }).status, "blocked_unvalidated_policy");
  assert.equal(calculateFiscalQuote({ amountXaf: 10000, transactionDate: "2026-11-21", policy: { ...approvedTaxPolicy, status: "draft" } }).status, "blocked_unvalidated_policy");
  assert.equal(calculateFiscalQuote({ amountXaf: 10000, transactionDate: "2025-12-31", policy: approvedTaxPolicy }).status, "blocked_unvalidated_policy");
});
test("fiscal engine applies only the approved effective-dated policy supplied", () => {
  const result = calculateFiscalQuote({
    amountXaf: 10000, transactionDate: "2026-11-21", policy: approvedTaxPolicy,
  });
  assert.equal(result.status, "calculated_by_approved_policy");
  assert.equal(result.taxXaf, 1925);
  assert.equal(result.totalXaf, 11925);
  const exempt = calculateFiscalQuote({
    amountXaf: 10000, transactionDate: "2026-11-21", policy: approvedTaxPolicy, exempt: true,
  });
  assert.equal(exempt.taxXaf, 0);
  assert.equal(exempt.exempt, true);
});

test("zero-share allocation cannot receive rounding remainder and UUID casing cannot duplicate a member", () => {
  const member = "50000000-0000-4000-8000-00000000000a";
  const other = "50000000-0000-4000-8000-00000000000b";
  const zero = "50000000-0000-4000-8000-000000000001";
  const input = {rule:{...approvedRule, method:"fixed_per_completed_line", fixedAmountXaf:1}, saleLine, calculationDate:"2026-11-21", sourceEventId:"60000000-0000-4000-8000-00000000000A"};
  const shares = [{memberId:zero,shareBps:0},{memberId:member.toUpperCase(),shareBps:5000},{memberId:other,shareBps:5000}];
  const result = calculateCommission({...input,allocations:shares});
  assert.equal(result.entries.find(e=>e.memberId===zero).amountXaf,0);
  assert.equal(result.entries.find(e=>e.memberId===member).amountXaf,1);
  assert.deepEqual(result,calculateCommission({...input,sourceEventId:input.sourceEventId.toLowerCase(),allocations:shares.slice().reverse()}));
  assert.throws(()=>calculateCommission({...input,allocations:[{memberId:member,shareBps:5000},{memberId:member.toUpperCase(),shareBps:5000}]}),/COMMISSION_SHARES_MUST_TOTAL_10000_BPS/);
});
test("cumulative commission reversals cannot exceed original posted amount", () => {
  const input = {sourceEntryId:"entry-1",originalAmountXaf:1000,alreadyReversedXaf:700,reversalEventId:"70000000-0000-4000-8000-000000000001"};
  assert.equal(reverseCommission({...input,refundAmountXaf:300}).amountXaf,-300);
  assert.throws(()=>reverseCommission({...input,refundAmountXaf:301}),/REVERSAL_EXCEEDS_ORIGINAL_COMMISSION/);
  assert.throws(()=>reverseCommission({...input,alreadyReversedXaf:-1,refundAmountXaf:1}),/INVALID_PRIOR_COMMISSION_REVERSAL/);
  assert.throws(()=>reverseCommission({...input,sourceEntryId:"",refundAmountXaf:1}),/INVALID_COMMISSION_SOURCE_ENTRY/);
});

test("commission engine never supplies a missing policy or rate and rejects unfinished work", () => {
  const input={rule:approvedRule,saleLine,allocations,calculationDate:"2026-11-21",sourceEventId:"60000000-0000-4000-8000-000000000001"};
  assert.throws(()=>calculateCommission({...input,rule:undefined}),/INVALID_COMMISSION_RULE/);
  assert.throws(()=>calculateCommission({...input,rule:{...approvedRule,rateBps:undefined}}),/INVALID_COMMISSION_RATE/);
  assert.throws(()=>calculateCommission({...input,saleLine:{...saleLine,status:"scheduled"}}),/SERVICE_NOT_COMPLETED/);
  assert.throws(()=>calculateCommission({...input,rule:{...approvedRule,effectiveFrom:"2026-11-22"}}),/COMMISSION_RULE_NOT_EFFECTIVE/);
  const fullyRefunded=calculateCommission({...input,saleLine:{...saleLine,refundedXaf:saleLine.confirmedPaidXaf}});
  assert.equal(fullyRefunded.status,"no_commission");assert.deepEqual(fullyRefunded.entries,[]);
});

test("automatic commissions remain disabled without explicit activation and no policy is invented",()=>{
 const context={organizationId:"org-a",siteId:"site-a",serviceId:"service-a",activityCode:"coiffure"};
 const input={context,allocations,saleLine,calculationDate:"2026-11-21",sourceEventId:"60000000-0000-4000-8000-000000000001"};
 assert.deepEqual(prepareAutomaticCommission(input),{status:"disabled",entries:[]});
 assert.deepEqual(prepareAutomaticCommission({...input,enabled:true,policies:[]}),{status:"no_applicable_policy",entries:[]});
 const policy={...approvedRule,id:"policy-a",organizationId:"org-a",siteId:"site-a",serviceId:"service-a",activityCode:"coiffure"};
 for(const invalid of [{organizationId:"org-b"},{siteId:"site-b"},{serviceId:"service-b"},{activityCode:"pressing"},{status:"draft"},{effectiveFrom:"2026-11-22"}]){
  assert.equal(prepareAutomaticCommission({...input,enabled:true,policies:[{...policy,...invalid}]}).status,"no_applicable_policy");
 }
 const active={...input,enabled:true,policies:[policy]};
 assert.equal(prepareAutomaticCommission(active).totalCommissionXaf,4000);
 assert.equal(prepareAutomaticCommission({...active,saleLine:{...saleLine,status:"scheduled"}}).status,"awaiting_completed_and_confirmed");
 assert.equal(prepareAutomaticCommission({...active,saleLine:{...saleLine,paymentStatus:"pending"}}).status,"awaiting_completed_and_confirmed");
 assert.equal(prepareAutomaticCommission({...active,policies:[policy,{...policy,id:"policy-b",siteId:null}]}).status,"blocked_ambiguous_policy");
 const fixed={...policy,method:"fixed_xaf",fixedAmountXaf:500};
 assert.equal(prepareAutomaticCommission({...active,policies:[fixed]}).totalCommissionXaf,500);
 assert.equal(prepareAutomaticCommission({...active,policies:[{...policy,memberId:allocations[0].memberId}]}).status,"blocked_ambiguous_policy");
 const single={...active,allocations:[{memberId:allocations[0].memberId,shareBps:10000}],policies:[{...policy,memberId:allocations[0].memberId}]};
 assert.equal(prepareAutomaticCommission(single).entries.length,1);
});

test("database automatic commission adapter rejects legacy policy activation and maps real v24 fields",()=>{
 const context={organizationId:"org-a",siteId:"site-a",serviceId:"service-a",activityCode:"coiffure"};
 const row={id:"policy-a",org_id:"org-a",site_id:"site-a",member_id:null,service_id:"service-a",activity_profile:"coiffure",version:1,method:"percent_bps",rate_bps:1000,fixed_amount_xaf:null,effective_from:"2026-11-01",effective_until:null,status:"approved",approved_by:"qa",approved_at:"2026-11-01T00:00:00Z"};
 const input={settings:{enabled:true},context,allocations,saleLine,calculationDate:"2026-11-21",sourceEventId:"60000000-0000-4000-8000-000000000001",policyRows:[row]};
 assert.equal(prepareAutomaticCommissionFromDatabase(input).status,"no_applicable_policy");
 const enabled={...input,policyRows:[{...row,automatic_scope:true}]};
 assert.equal(prepareAutomaticCommissionFromDatabase(enabled).status,"pending_approval");
 assert.equal(prepareAutomaticCommissionFromDatabase({...enabled,settings:{enabled:false}}).status,"disabled");
 assert.equal(prepareAutomaticCommissionFromDatabase({...enabled,policyRows:[{...row,automatic_scope:true,org_id:"other"}]}).status,"no_applicable_policy");
});
