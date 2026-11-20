export type PurchaseLineKind = "stock" | "operating_expense" | "fixed_asset";
export type SaleState = "draft" | "pending" | "confirmed" | "cancelled" | "refunded";

export interface RevenueEvent {
  status: SaleState;
  totalXaf: number;
}

export interface DoubleEntryEvent {
  debitAccount: string;
  creditAccount: string;
  amountXaf: number;
}

/** Weighted-average landed cost; nonrecoverable freight/tax belongs in landedCostXaf. */
export function weightedAverageUnitCost(
  previousQuantity: number,
  previousUnitCostXaf: number,
  receivedQuantity: number,
  landedCostXaf: number,
): number {
  if (!Number.isFinite(previousQuantity) || previousQuantity < 0 ||
      !Number.isFinite(receivedQuantity) || receivedQuantity <= 0 ||
      !Number.isSafeInteger(previousUnitCostXaf) || previousUnitCostXaf < 0 ||
      !Number.isSafeInteger(landedCostXaf) || landedCostXaf <= 0) {
    throw new Error("ACCOUNTING_INVALID_INVENTORY_VALUATION_INPUT");
  }
  const totalQuantity = previousQuantity + receivedQuantity;
  if (totalQuantity <= 0) throw new Error("ACCOUNTING_INVALID_TOTAL_QUANTITY");
  return Math.round((previousQuantity * previousUnitCostXaf + landedCostXaf) / totalQuantity);
}

export function supplierPayableBalance(receivedTotalXaf: number, paidTotalXaf: number): number {
  if (!Number.isSafeInteger(receivedTotalXaf) || receivedTotalXaf < 0 ||
      !Number.isSafeInteger(paidTotalXaf) || paidTotalXaf < 0 || paidTotalXaf > receivedTotalXaf) {
    throw new Error("ACCOUNTING_INVALID_SUPPLIER_BALANCE");
  }
  return receivedTotalXaf - paidTotalXaf;
}

/** Supplier purchases are not revenue; only confirmed sale events contribute to gross sales. */
export function confirmedRevenue(events: readonly RevenueEvent[]): number {
  return events.reduce((total, event) => {
    if (event.status !== "confirmed") return total;
    if (!Number.isSafeInteger(event.totalXaf) || event.totalXaf < 0) {
      throw new Error("ACCOUNTING_INVALID_CONFIRMED_SALE");
    }
    return total + event.totalXaf;
  }, 0);
}

export function costOfGoodsSold(quantity: number, weightedAverageUnitCostXaf: number): number {
  if (!Number.isFinite(quantity) || quantity <= 0 ||
      !Number.isSafeInteger(weightedAverageUnitCostXaf) || weightedAverageUnitCostXaf < 0) {
    throw new Error("ACCOUNTING_INVALID_COST_OF_GOODS_INPUT");
  }
  return Math.round(quantity * weightedAverageUnitCostXaf);
}

export function validateBalancedJournal(event: DoubleEntryEvent): boolean {
  return event.amountXaf > 0 &&
    Number.isSafeInteger(event.amountXaf) &&
    event.debitAccount.trim().length > 0 &&
    event.creditAccount.trim().length > 0 &&
    event.debitAccount !== event.creditAccount;
}

/** Reused idempotency key is safe only if the payload fingerprint is identical. */
export function validateIdempotentReplay(existingHash: string, incomingHash: string): "replay" | "conflict" {
  return existingHash === incomingHash ? "replay" : "conflict";
}

export function projectRevenue(actualToDateXaf: number, averageDailyXaf: number, remainingDays: number): number {
  if (!Number.isSafeInteger(actualToDateXaf) || actualToDateXaf < 0 ||
      !Number.isSafeInteger(averageDailyXaf) || averageDailyXaf < 0 ||
      !Number.isSafeInteger(remainingDays) || remainingDays < 0) {
    throw new Error("ACCOUNTING_INVALID_REVENUE_PROJECTION_INPUT");
  }
  return actualToDateXaf + averageDailyXaf * remainingDays;
}

export function dailyRecoveryNeed(targetXaf: number, projectedXaf: number, remainingDays: number): number {
  if (!Number.isSafeInteger(targetXaf) || targetXaf < 0 ||
      !Number.isSafeInteger(projectedXaf) || projectedXaf < 0 ||
      !Number.isSafeInteger(remainingDays) || remainingDays < 0) {
    throw new Error("ACCOUNTING_INVALID_RECOVERY_INPUT");
  }
  if (remainingDays === 0) return Math.max(0, targetXaf - projectedXaf);
  return Math.ceil(Math.max(0, targetXaf - projectedXaf) / remainingDays);
}
