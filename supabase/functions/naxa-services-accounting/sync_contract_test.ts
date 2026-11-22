import {
  normalizeSupplierPurchaseSyncPayload,
  normalizeSupplierSyncPayload,
} from "./sync_contract.ts";

const ORG = "11111111-1111-4111-8111-111111111111";
const SITE = "22222222-2222-4222-8222-222222222222";
const SUPPLIER = "33333333-3333-4333-8333-333333333333";
const PURCHASE = "44444444-4444-4444-8444-444444444444";
const LINE_A = "55555555-5555-4555-8555-555555555555";
const LINE_B = "66666666-6666-4666-8666-666666666666";

Deno.test("supplier sync preserves client UUID and normalizes the WhatsApp number", () => {
  const payload = normalizeSupplierSyncPayload({
    supplier_id: SUPPLIER, org_id: ORG, site_id: SITE, name: " Grossiste Central ",
    phone: "+237 699 000 000", whatsapp: "+237 699 000 000", email: "contact@example.cm",
    address: "", payment_terms_days: 30, notes: "",
  });
  if (payload.supplier_id !== SUPPLIER || payload.whatsapp !== "237699000000" || payload.name !== "Grossiste Central") {
    throw new Error("Supplier identity or normalization mismatch");
  }
});

Deno.test("purchase sync preserves purchase and line UUIDs already stored in Room", () => {
  const payload = normalizeSupplierPurchaseSyncPayload({
    purchase_id: PURCHASE, idempotency_key: PURCHASE, org_id: ORG, site_id: SITE,
    supplier_id: SUPPLIER, reference: "PO-2026-001",
    lines: [
      { line_id: LINE_A, inventory_item_id: LINE_B, description: "Savon", item_type: "stock", unit: "pièce", quantity_ordered: 2.5, unit_cost_xaf: 500 },
      { line_id: "77777777-7777-4777-8777-777777777777", inventory_item_id: null, description: "Transport", item_type: "operating_expense", unit: "forfait", quantity_ordered: 1, unit_cost_xaf: 2000 },
    ],
    recoverable_tax_xaf: 0, non_recoverable_tax_xaf: 100, shipping_xaf: 500, other_fees_xaf: 0,
    due_at: null, notes: "",
  });
  if (payload.purchase_id !== PURCHASE || payload.lines[0].line_id !== LINE_A || payload.lines.length !== 2) {
    throw new Error("Stable purchase/line identities were not preserved");
  }
});

Deno.test("purchase UUID must also be the idempotency key", () => {
  let rejected = false;
  try {
    normalizeSupplierPurchaseSyncPayload({
      purchase_id: PURCHASE, idempotency_key: SUPPLIER, org_id: ORG, site_id: SITE,
      supplier_id: SUPPLIER, reference: "PO-001",
      lines: [{ line_id: LINE_A, inventory_item_id: LINE_B, description: "x", item_type: "stock", unit: "u", quantity_ordered: 1, unit_cost_xaf: 1 }],
    });
  } catch { rejected = true; }
  if (!rejected) throw new Error("Mismatched purchase and idempotency IDs must be rejected");
});

Deno.test("duplicate line UUID and invalid stock reference are rejected", () => {
  const base = {
    purchase_id: PURCHASE, idempotency_key: PURCHASE, org_id: ORG, site_id: SITE,
    supplier_id: SUPPLIER, reference: "PO-002", lines: [
      { line_id: LINE_A, inventory_item_id: LINE_B, description: "A", item_type: "stock", unit: "u", quantity_ordered: 1, unit_cost_xaf: 10 },
      { line_id: LINE_A, inventory_item_id: null, description: "B", item_type: "operating_expense", unit: "u", quantity_ordered: 1, unit_cost_xaf: 20 },
    ],
  };
  let duplicateRejected = false;
  try { normalizeSupplierPurchaseSyncPayload(base); } catch { duplicateRejected = true; }
  if (!duplicateRejected) throw new Error("Duplicate local line IDs must be rejected");
  let stockLinkRejected = false;
  try {
    normalizeSupplierPurchaseSyncPayload({
      ...base,
      lines: [{ line_id: LINE_A, inventory_item_id: null, description: "Stock", item_type: "stock", unit: "u", quantity_ordered: 1, unit_cost_xaf: 10 }],
    });
  } catch { stockLinkRejected = true; }
  if (!stockLinkRejected) throw new Error("Stock line without item must be rejected");
});

Deno.test("invalid due date and unsafe integer amount are rejected", () => {
  const base = {
    purchase_id: PURCHASE, idempotency_key: PURCHASE, org_id: ORG, site_id: SITE,
    supplier_id: SUPPLIER, reference: "PO-003",
    lines: [{ line_id: LINE_A, inventory_item_id: LINE_B, description: "Stock", item_type: "stock", unit: "u", quantity_ordered: 1, unit_cost_xaf: 10 }],
  };
  let dateRejected = false;
  try { normalizeSupplierPurchaseSyncPayload({ ...base, due_at: "not-a-date" }); } catch { dateRejected = true; }
  if (!dateRejected) throw new Error("Invalid due date must be rejected");
  let amountRejected = false;
  try {
    normalizeSupplierPurchaseSyncPayload({
      ...base,
      lines: [{ line_id: LINE_A, inventory_item_id: LINE_B, description: "Stock", item_type: "stock", unit: "u", quantity_ordered: 1, unit_cost_xaf: Number.MAX_SAFE_INTEGER + 1 }],
    });
  } catch { amountRejected = true; }
  if (!amountRejected) throw new Error("Unsafe integer amounts must be rejected");
});

import {
  normalizeInventoryItemSyncPayload,
  normalizeInventoryMovementSyncPayload,
} from "./sync_contract.ts";
const INVENTORY_ITEM_A="88888888-8888-4888-8888-888888888881";
const INVENTORY_MOVE_A="88888888-8888-4888-8888-888888888882";
const ORG_A="88888888-8888-4888-8888-888888888883";
const SITE_A="88888888-8888-4888-8888-888888888884";
Deno.test("inventory item sync validates stable UUID and metadata",()=>{
  const item=normalizeInventoryItemSyncPayload({
    inventory_item_id:INVENTORY_ITEM_A,org_id:ORG_A,site_id:SITE_A,
    sku:" sku-001 ",name:"Savon",unit:"pièce",reorder_level:2.5,
    supplier_whatsapp:"+237 690 00 00 00"
  });
  if(item.sku!=="SKU-001"||item.reorder_level!==2.5||item.supplier_whatsapp!=="237690000000")
    throw new Error("Inventory item normalization mismatch");
  let failed=false;
  try {
    normalizeInventoryItemSyncPayload({
      inventory_item_id:INVENTORY_ITEM_A,org_id:ORG_A,site_id:SITE_A,
      sku:"",name:"Savon",unit:"pièce",reorder_level:-1,supplier_whatsapp:""
    });
  } catch { failed=true; }
  if(!failed) throw new Error("Negative reorder level must be rejected");
});
Deno.test("inventory movement sync enforces signed quantity semantics",()=>{
  const move=normalizeInventoryMovementSyncPayload({
    movement_id:INVENTORY_MOVE_A,org_id:ORG_A,site_id:SITE_A,
    inventory_item_id:INVENTORY_ITEM_A,movement_type:"consumption",
    quantity_delta:-1.25,reason:"Consommation validée"
  });
  if(move.quantity_delta!==-1.25) throw new Error("Signed movement delta must be preserved");
  let failed=false;
  try {
    normalizeInventoryMovementSyncPayload({
      movement_id:INVENTORY_MOVE_A,org_id:ORG_A,site_id:SITE_A,
      inventory_item_id:INVENTORY_ITEM_A,movement_type:"consumption",
      quantity_delta:1.25,reason:"Consommation invalide"
    });
  } catch { failed=true; }
  if(!failed) throw new Error("Positive consumption must be rejected");
});


import { normalizeAtomicSyncEvent } from "./sync_contract.ts";
const SYNC_DEVICE = "88888888-8888-4888-8888-888888888885";
const SYNC_EVENT = "88888888-8888-4888-8888-888888888886";
const SYNC_SUPPLIER = "88888888-8888-4888-8888-888888888887";
const atomicSupplierEvent = () => ({
  event_id: SYNC_EVENT, device_id: SYNC_DEVICE, device_sequence: 1,
  org_id: ORG_A, site_id: SITE_A, workstation_id: null,
  aggregate_type: "supplier", aggregate_id: SYNC_SUPPLIER,
  action_code: "supplier.saved",
  payload: {
    supplier_id: SYNC_SUPPLIER, org_id: ORG_A, site_id: SITE_A,
    name: "Fournisseur test", phone: "", whatsapp: "", email: "",
    address: "", payment_terms_days: 0, notes: ""
  }
});
Deno.test("atomic sync envelope validates scoped aggregate and stable identifiers", () => {
  const normalized = normalizeAtomicSyncEvent(atomicSupplierEvent());
  if (normalized.event_id !== SYNC_EVENT || normalized.aggregate_id !== SYNC_SUPPLIER ||
      normalized.action_code !== "supplier.saved" || normalized.device_sequence !== 1) {
    throw new Error("Atomic sync event was not normalized");
  }
});
Deno.test("atomic sync envelope rejects unsupported actions and aggregate spoofing", () => {
  let unsupported = false;
  try { normalizeAtomicSyncEvent({ ...atomicSupplierEvent(), action_code: "sale.created" }); }
  catch { unsupported = true; }
  if (!unsupported) throw new Error("Unsupported action must be rejected");
  let aggregate = false;
  try { normalizeAtomicSyncEvent({ ...atomicSupplierEvent(), aggregate_type: "customer" }); }
  catch { aggregate = true; }
  if (!aggregate) throw new Error("Aggregate/action mismatch must be rejected");
});
Deno.test("atomic sync envelope rejects cross-site and cross-organization payloads", () => {
  let site = false;
  try {
    const body = atomicSupplierEvent();
    normalizeAtomicSyncEvent({ ...body, site_id: "88888888-8888-4888-8888-888888888888" });
  } catch { site = true; }
  if (!site) throw new Error("Payload site mismatch must be rejected");
  let org = false;
  try {
    const body = atomicSupplierEvent();
    normalizeAtomicSyncEvent({ ...body, payload: { ...body.payload, org_id: "88888888-8888-4888-8888-888888888888" } });
  } catch { org = true; }
  if (!org) throw new Error("Payload organization mismatch must be rejected");
});
Deno.test("organization-scoped loyalty program event cannot carry a site or workstation", () => {
  const value = {
    event_id: SYNC_EVENT, device_id: SYNC_DEVICE, device_sequence: 2,
    org_id: ORG_A, site_id: null, workstation_id: null,
    aggregate_type: "loyalty_program", aggregate_id: SYNC_SUPPLIER,
    action_code: "loyalty_program.updated",
    payload: { program_id: SYNC_SUPPLIER, org_id: ORG_A, activity_profile: "pressing" }
  };
  const normalized = normalizeAtomicSyncEvent(value);
  if (normalized.site_id !== null) throw new Error("Loyalty program must be organization-scoped");
  let rejected = false;
  try { normalizeAtomicSyncEvent({ ...value, site_id: SITE_A }); }
  catch { rejected = true; }
  if (!rejected) throw new Error("Organization-scoped action must reject site IDs");
});
