import { accountingCorsHeaders } from "./accounting_contract.ts";
import {
  confirmedRevenue,
  costOfGoodsSold,
  dailyRecoveryNeed,
  projectRevenue,
  supplierPayableBalance,
  validateBalancedJournal,
  validateIdempotentReplay,
  weightedAverageUnitCost,
} from "./accounting_contract.ts";

Deno.test("supplier receipt updates weighted average landed cost", () => {
  const unitCost = weightedAverageUnitCost(10, 1000, 5, 7500);
  if (unitCost !== 1167) throw new Error("Expected 1,167 XAF weighted average, got " + unitCost);
});

Deno.test("recoverable tax is not silently included in inventory landed cost", () => {
  const landedCost = 50000 + 3000; // base plus non-recoverable freight/tax only
  const average = weightedAverageUnitCost(0, 0, 10, landedCost);
  if (average !== 5300) throw new Error("Expected recoverable tax excluded from inventory cost");
});

Deno.test("supplier payable is received invoice less allocated payments", () => {
  if (supplierPayableBalance(125000, 45000) !== 80000) throw new Error("Payable balance mismatch");
});

Deno.test("pending or cancelled sales do not inflate turnover", () => {
  const revenue = confirmedRevenue([
    { status: "confirmed", totalXaf: 100000 },
    { status: "pending", totalXaf: 25000 },
    { status: "cancelled", totalXaf: 5000 },
    { status: "refunded", totalXaf: 10000 },
  ]);
  if (revenue !== 100000) throw new Error("Only confirmed turnover should be counted");
});

Deno.test("cost of goods sold uses the sale-time weighted average", () => {
  if (costOfGoodsSold(3.5, 1250) !== 4375) throw new Error("COGS must use the sale-time cost snapshot");
});

Deno.test("journal entry is balanced by a single debit/credit pair", () => {
  if (!validateBalancedJournal({ debitAccount: "INVENTORY_ASSET", creditAccount: "SUPPLIER_PAYABLE", amountXaf: 50000 })) {
    throw new Error("Valid purchase receipt pair should be accepted");
  }
  if (validateBalancedJournal({ debitAccount: "BANK", creditAccount: "BANK", amountXaf: 50000 })) {
    throw new Error("Self-offsetting journal accounts must be rejected");
  }
});

Deno.test("reused idempotency key accepts only identical payload", () => {
  if (validateIdempotentReplay("abc", "abc") !== "replay") throw new Error("Expected safe replay");
  if (validateIdempotentReplay("abc", "def") !== "conflict") throw new Error("Expected changed payload conflict");
});

Deno.test("monthly projection and recovery effort are deterministic", () => {
  if (projectRevenue(200000, 10000, 10) !== 300000) throw new Error("Projection mismatch");
  if (dailyRecoveryNeed(500000, 300000, 10) !== 20000) throw new Error("Daily recovery effort mismatch");
  if (dailyRecoveryNeed(500000, 300000, 0) !== 200000) throw new Error("Closed-period gap mismatch");
});

Deno.test("accounting browser allowlist is exact and never wildcard", () => {
  const origin = "https://famille-naxa.pages.dev";
  if (accountingCorsHeaders(origin, [origin])["Access-Control-Allow-Origin"] !== origin) throw new Error("OFFICIAL_ORIGIN_REJECTED");
  for (const other of [null, "https://untrusted.invalid", origin + ".invalid"]) {
    const headers = accountingCorsHeaders(other, [origin, "*"]);
    if (headers["Access-Control-Allow-Origin"] !== "null" || headers["Vary"] !== "Origin") throw new Error("FOREIGN_ORIGIN_ALLOWED");
  }
});
