export type SupplierSyncPayload = {
  supplier_id: string; org_id: string; site_id: string; name: string; phone: string;
  whatsapp: string; email: string; address: string; payment_terms_days: number; notes: string;
};

export type SupplierPurchaseLineSyncPayload = {
  line_id: string;
  inventory_item_id: string | null;
  description: string;
  item_type: "stock" | "operating_expense" | "fixed_asset";
  unit: string;
  quantity_ordered: number;
  unit_cost_xaf: number;
};

export type SupplierPurchaseSyncPayload = {
  purchase_id: string; org_id: string; site_id: string; supplier_id: string;
  reference: string; supplier_invoice_number: string; lines: SupplierPurchaseLineSyncPayload[];
  recoverable_tax_xaf: number; non_recoverable_tax_xaf: number; shipping_xaf: number;
  other_fees_xaf: number; due_at: string | null; notes: string;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function record(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("INVALID_" + label);
  return value as Record<string, unknown>;
}
function uuid(value: unknown, label: string): string {
  if (typeof value !== "string" || !UUID.test(value)) throw new Error("INVALID_" + label);
  return value.toLowerCase();
}
function text(value: unknown, label: string, min: number, max: number, fallback = ""): string {
  const candidate = value === undefined || value === null ? fallback : value;
  if (typeof candidate !== "string" || candidate.trim().length < min || candidate.length > max) throw new Error("INVALID_" + label);
  return candidate.trim();
}
function money(value: unknown, label: string, allowZero: boolean): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < (allowZero ? 0 : 1)) throw new Error("INVALID_" + label);
  return value;
}

export function normalizeSupplierSyncPayload(value: unknown): SupplierSyncPayload {
  const body = record(value, "SUPPLIER_BODY");
  const whatsapp = text(body.whatsapp, "SUPPLIER_WHATSAPP", 0, 32).replace(/\D/g, "");
  if (whatsapp && !/^\d{9,15}$/.test(whatsapp)) throw new Error("INVALID_SUPPLIER_WHATSAPP");
  const paymentTerms = money(body.payment_terms_days ?? 0, "SUPPLIER_PAYMENT_TERMS", true);
  if (paymentTerms > 365) throw new Error("INVALID_SUPPLIER_PAYMENT_TERMS");
  return {
    supplier_id: uuid(body.supplier_id, "SUPPLIER_ID"),
    org_id: uuid(body.org_id, "ORG_ID"),
    site_id: uuid(body.site_id, "SITE_ID"),
    name: text(body.name, "SUPPLIER_NAME", 2, 120),
    phone: text(body.phone, "SUPPLIER_PHONE", 0, 32),
    whatsapp,
    email: text(body.email, "SUPPLIER_EMAIL", 0, 254),
    address: text(body.address, "SUPPLIER_ADDRESS", 0, 200),
    payment_terms_days: paymentTerms,
    notes: text(body.notes, "SUPPLIER_NOTES", 0, 1000),
  };
}

export function normalizeSupplierPurchaseSyncPayload(value: unknown): SupplierPurchaseSyncPayload {
  const body = record(value, "PURCHASE_BODY");
  const purchaseId = uuid(body.purchase_id, "PURCHASE_ID");
  const idempotencyKey = uuid(body.idempotency_key ?? body.purchase_id, "IDEMPOTENCY_KEY");
  if (purchaseId !== idempotencyKey) throw new Error("PURCHASE_ID_MUST_MATCH_IDEMPOTENCY_KEY");
  if (!Array.isArray(body.lines) || body.lines.length < 1 || body.lines.length > 100) throw new Error("INVALID_PURCHASE_LINES");
  const ids = new Set<string>();
  const lines = body.lines.map((raw, index): SupplierPurchaseLineSyncPayload => {
    const line = record(raw, "PURCHASE_LINE_" + index);
    const lineId = uuid(line.line_id, "PURCHASE_LINE_ID");
    if (ids.has(lineId)) throw new Error("DUPLICATE_PURCHASE_LINE_ID");
    ids.add(lineId);
    const kind = line.item_type;
    if (kind !== "stock" && kind !== "operating_expense" && kind !== "fixed_asset") throw new Error("INVALID_PURCHASE_LINE_TYPE");
    const inventoryId = line.inventory_item_id == null ? null : uuid(line.inventory_item_id, "INVENTORY_ITEM_ID");
    if ((kind === "stock" && inventoryId === null) || (kind !== "stock" && inventoryId !== null)) throw new Error("INVALID_PURCHASE_LINE_STOCK_LINK");
    const quantity = line.quantity_ordered;
    if (typeof quantity !== "number" || !Number.isFinite(quantity) || quantity <= 0 || quantity > 100000000) throw new Error("INVALID_PURCHASE_LINE_QUANTITY");
    return {
      line_id: lineId,
      inventory_item_id: inventoryId,
      description: text(line.description, "PURCHASE_LINE_DESCRIPTION", 1, 240),
      item_type: kind,
      unit: text(line.unit, "PURCHASE_LINE_UNIT", 1, 40, "unité"),
      quantity_ordered: quantity,
      unit_cost_xaf: money(line.unit_cost_xaf, "PURCHASE_LINE_UNIT_COST", false),
    };
  });
  const rawDueAt = body.due_at ?? null;
  let dueAt: string | null = null;
  if (rawDueAt !== null) {
    if (typeof rawDueAt !== "string" || !Number.isFinite(Date.parse(rawDueAt))) throw new Error("INVALID_PURCHASE_DUE_AT");
    dueAt = new Date(rawDueAt).toISOString();
  }
  return {
    purchase_id: purchaseId, org_id: uuid(body.org_id, "ORG_ID"),
    site_id: uuid(body.site_id, "SITE_ID"), supplier_id: uuid(body.supplier_id, "SUPPLIER_ID"),
    reference: text(body.reference, "PURCHASE_REFERENCE", 3, 80),
    supplier_invoice_number: text(body.supplier_invoice_number, "SUPPLIER_INVOICE_NUMBER", 0, 120),
    lines,
    recoverable_tax_xaf: money(body.recoverable_tax_xaf ?? 0, "RECOVERABLE_TAX", true),
    non_recoverable_tax_xaf: money(body.non_recoverable_tax_xaf ?? 0, "NON_RECOVERABLE_TAX", true),
    shipping_xaf: money(body.shipping_xaf ?? 0, "SHIPPING", true),
    other_fees_xaf: money(body.other_fees_xaf ?? 0, "OTHER_FEES", true),
    due_at: dueAt,
    notes: text(body.notes, "PURCHASE_NOTES", 0, 1000),
  };
}

export type InventoryItemSyncPayload = {
  inventory_item_id:string; org_id:string; site_id:string; sku:string;
  name:string; unit:string; reorder_level:number; supplier_whatsapp:string;
};
export type InventoryMovementSyncPayload = {
  movement_id:string; org_id:string; site_id:string; inventory_item_id:string;
  movement_type:"in"|"consumption"|"loss"|"adjustment"; quantity_delta:number; reason:string;
};
export function normalizeInventoryItemSyncPayload(value:unknown):InventoryItemSyncPayload {
  const body=record(value,"INVENTORY_ITEM_BODY");
  const sku=text(body.sku,"INVENTORY_ITEM_SKU",0,80).toUpperCase();
  const name=text(body.name,"INVENTORY_ITEM_NAME",1,160);
  const unit=text(body.unit,"INVENTORY_ITEM_UNIT",1,40);
  const reorder=body.reorder_level;
  if(typeof reorder!=="number"||!Number.isFinite(reorder)||reorder<0||reorder>99999999999.999||
     Math.abs(reorder*1000-Math.round(reorder*1000))>0.000001) throw new Error("INVALID_INVENTORY_ITEM_REORDER_LEVEL");
  const whatsapp=text(body.supplier_whatsapp,"INVENTORY_ITEM_WHATSAPP",0,32).replace(/\D/g,"");
  if(whatsapp&&!/^\d{9,15}$/.test(whatsapp)) throw new Error("INVALID_INVENTORY_ITEM_WHATSAPP");
  return {
    inventory_item_id:uuid(body.inventory_item_id,"INVENTORY_ITEM_ID"),
    org_id:uuid(body.org_id,"ORG_ID"),site_id:uuid(body.site_id,"SITE_ID"),
    sku,name,unit,reorder_level:reorder,supplier_whatsapp:whatsapp
  };
}
export function normalizeInventoryMovementSyncPayload(value:unknown):InventoryMovementSyncPayload {
  const body=record(value,"INVENTORY_MOVEMENT_BODY");
  const kind=body.movement_type;
  if(kind!=="in"&&kind!=="consumption"&&kind!=="loss"&&kind!=="adjustment") throw new Error("INVALID_INVENTORY_MOVEMENT_TYPE");
  const delta=body.quantity_delta;
  if(typeof delta!=="number"||!Number.isFinite(delta)||delta===0||Math.abs(delta)>99999999999.999||
     Math.abs(delta*1000-Math.round(delta*1000))>0.000001||
     (kind==="in"&&delta<0)||((kind==="consumption"||kind==="loss")&&delta>0)) {
    throw new Error("INVALID_INVENTORY_MOVEMENT_QUANTITY");
  }
  return {
    movement_id:uuid(body.movement_id,"MOVEMENT_ID"),
    org_id:uuid(body.org_id,"ORG_ID"),site_id:uuid(body.site_id,"SITE_ID"),
    inventory_item_id:uuid(body.inventory_item_id,"INVENTORY_ITEM_ID"),
    movement_type:kind,quantity_delta:delta,
    reason:text(body.reason,"INVENTORY_MOVEMENT_REASON",3,240)
  };
}
