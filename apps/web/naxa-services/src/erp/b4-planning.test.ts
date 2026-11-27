import {describe,it,expect} from "vitest";
import {mergeB4Data,staleChargeReceipt,objectivePeriod,chargeReceiptCursor} from "./b4-planning";
describe("B4 recurring charge projection and objective calendar",()=>{
 const due="2027-01-10T00:00:00Z",next="2027-02-10T00:00:00Z",initial={amount_xaf:1000,next_due_at:due,active:true};
 it("does not overwrite the contractual charge amount with the pending payment",()=>{
  expect(mergeB4Data(initial,{amount_xaf:400,reference_due_at:due},{},"recurring_charge.payment_recorded")).toMatchObject({amount_xaf:1000,last_payment_xaf:400,next_due_at:due});
 });
 it("uses confirmed balance and advances a fully settled cycle",()=>{
  const p=mergeB4Data(initial,{amount_xaf:400,reference_due_at:due},{remaining_xaf:600,next_due_at:due,active:true},"recurring_charge.payment_recorded");
  expect(p).toMatchObject({amount_xaf:1000,remaining_xaf:600});
  expect(mergeB4Data(p,{amount_xaf:600,reference_due_at:due},{remaining_xaf:0,next_due_at:next,active:true},"recurring_charge.payment_recorded")).toMatchObject({amount_xaf:1000,remaining_xaf:1000,next_due_at:next});
 });
 it("does not invent a charge amount on a payment-only record or reactivate a one-time charge",()=>{
  expect(mergeB4Data(undefined,{amount_xaf:400,reference_due_at:due},{},"recurring_charge.payment_recorded").amount_xaf).toBeUndefined();
  expect(mergeB4Data(initial,{amount_xaf:1000,reference_due_at:due},{remaining_xaf:0,next_due_at:due,active:false},"recurring_charge.payment_recorded")).toMatchObject({active:false,remaining_xaf:0});
 });
 it("rejects older replay receipts and calculates Douala period boundaries",()=>{
  expect(staleChargeReceipt("recurring_charge.saved",{server_recorded_at:next},due)).toBe(true);
  expect(staleChargeReceipt("recurring_charge.saved",{server_sync_cursor:19},undefined,18)).toBe(true);
  expect(staleChargeReceipt("recurring_charge.payment_recorded",{server_sync_cursor:19},due,20)).toBe(false);
  expect(chargeReceiptCursor("recurring_charge.payment_recorded",20)).toEqual({server_sync_cursor:20});
  expect(objectivePeriod("monthly",new Date("2028-02-29T12:00:00Z"))).toEqual({period_start:"2028-02-01",period_end:"2028-02-29",due_at:"2028-02-29T22:59:59.999Z"});
  expect(objectivePeriod("daily",new Date("2026-12-31T23:30:00Z")).period_start).toBe("2027-01-01");
 });
});
