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
