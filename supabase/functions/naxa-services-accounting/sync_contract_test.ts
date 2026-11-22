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
const SITE_B="88888888-8888-4888-8888-888888888883";
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


Deno.test("atomic sync envelope covers service catalogue versioned mutations", () => {
  const org = ORG_A;
  const site = SITE_A;
  const service = "88888888-8888-4888-8888-888888888889";
  const base = {
    event_id: "88888888-8888-4888-8888-888888888890",
    device_id: SYNC_DEVICE, device_sequence: 10,
    org_id: org, site_id: site, workstation_id: null,
    aggregate_type: "service", aggregate_id: service,
    action_code: "service.updated",
    payload: {
      service_id: service, org_id: org, site_id: site,
      code: "SRV-CI", activity: "pressing", name: "Pressing CI",
      duration_minutes: 30, price_xaf: 1500, active: true, expected_version: 1
    }
  };
  if (normalizeAtomicSyncEvent(base).aggregate_id !== service) throw new Error("Service update not accepted");
  const config = {
    ...base, action_code: "service.configuration_updated",
    payload: {
      service_id: service, org_id: org, site_id: site,
      category: "pressing", description: "", provider_member_ids: [],
      required_workstation_kinds: [], package_sessions: null, expected_version: 2
    }
  };
  if (normalizeAtomicSyncEvent(config).action_code !== "service.configuration_updated") {
    throw new Error("Service configuration update not accepted");
  }
});
Deno.test("atomic sync envelope covers customer, CRM follow-up and support mutations", () => {
  const org = ORG_A, site = SITE_A;
  const cases = [
    ["customer.created","customer","88888888-8888-4888-8888-888888888891","customer_id"],
    ["customer_followup.created","customer_followup","88888888-8888-4888-8888-888888888892","followup_id"],
    ["customer_followup.completed","customer_followup","88888888-8888-4888-8888-888888888892","followup_id"],
    ["support_request.created","support_request","88888888-8888-4888-8888-888888888893","request_id"]
  ] as const;
  for (let index=0; index<cases.length; index++) {
    const [action,aggregate,id,idField]=cases[index];
    const normalized=normalizeAtomicSyncEvent({
      event_id:"88888888-8888-4888-8888-888888888894",
      device_id:SYNC_DEVICE,device_sequence:20+index,
      org_id:org,site_id:site,workstation_id:null,
      aggregate_type:aggregate,aggregate_id:id,action_code:action,
      payload:{[idField]:id,org_id:org,site_id:site}
    });
    if(normalized.action_code!==action) throw new Error("Mutation type not accepted: "+action);
  }
});

Deno.test("support request sync may be organization-scoped when no site is attached", () => {
  const request = "88888888-8888-4888-8888-888888888895";
  const value = {
    event_id: SYNC_EVENT, device_id: SYNC_DEVICE, device_sequence: 30,
    org_id: ORG_A, site_id: null, workstation_id: null,
    aggregate_type: "support_request", aggregate_id: request,
    action_code: "support_request.created",
    payload: { request_id: request, org_id: ORG_A }
  };
  if (normalizeAtomicSyncEvent(value).site_id !== null) {
    throw new Error("Organization-scoped support request should permit null site");
  }
});


Deno.test("atomic sync envelope validates versioned inventory valuation events", () => {
  const item = "88888888-8888-4888-8888-888888888896";
  const valuation = "88888888-8888-4888-8888-888888888897";
  for (const action of ["inventory_valuation.imported","inventory_valuation.import_updated","inventory_valuation.updated"]) {
    const event = normalizeAtomicSyncEvent({
      event_id: SYNC_EVENT, device_id: SYNC_DEVICE, device_sequence: 40,
      org_id: ORG_A, site_id: SITE_A, workstation_id: null,
      aggregate_type: "inventory_valuation", aggregate_id: item, action_code: action,
      payload: {
        valuation_id: valuation, inventory_item_id: item, org_id: ORG_A, site_id: SITE_A,
        unit_cost_xaf: 1500, selling_price_xaf: 3000, expected_version: 0
      }
    });
    if (event.aggregate_type !== "inventory_valuation" || event.aggregate_id !== item) {
      throw new Error("Inventory valuation aggregate identity mismatch");
    }
  }
});

Deno.test("atomic sync envelope accepts versioned inventory valuation lifecycle commands", () => {
  const item="88888888-8888-4888-8888-888888888896";
  const valuation="88888888-8888-4888-8888-888888888897";
  for(const action of ["inventory_valuation.imported","inventory_valuation.import_updated","inventory_valuation.updated"]) {
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:41,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:"inventory_valuation",aggregate_id:item,action_code:action,
      payload:{valuation_id:valuation,inventory_item_id:item,org_id:ORG_A,site_id:SITE_A,
        unit_cost_xaf:1500,selling_price_xaf:3000,expected_version:0}
    });
    if(normalized.aggregate_id!==item)throw new Error("Valuation aggregate must follow the item identity from the event source");
  }
});


Deno.test("atomic sync envelope validates pressing order lifecycle actions", () => {
  const id="88888888-8888-4888-8888-888888888898";
  for(const action of ["pressing_order.created","pressing_order.status_changed:in_progress",
    "pressing_order.status_changed:ready","pressing_order.status_changed:picked_up"]) {
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:50,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:"pressing_order",aggregate_id:id,action_code:action,
      payload:{order_id:id,org_id:ORG_A,site_id:SITE_A}
    });
    if(normalized.aggregate_id!==id||normalized.action_code!==action)throw new Error("Pressing action mismatch: "+action);
  }
});
Deno.test("atomic sync envelope validates appointment create, transition and reschedule actions", () => {
  const id="88888888-8888-4888-8888-888888888899";
  for(const action of ["appointment.created","appointment.status_changed","appointment.rescheduled"]) {
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:51,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:"appointment",aggregate_id:id,action_code:action,
      payload:{appointment_id:id,org_id:ORG_A,site_id:SITE_A}
    });
    if(normalized.aggregate_id!==id||normalized.action_code!==action)throw new Error("Appointment action mismatch: "+action);
  }
});


Deno.test("atomic sync validates pressing order creation and versioned status commands", () => {
  const id="88888888-8888-4888-8888-888888888898";
  for(const action of ["pressing_order.created","pressing_order.status_changed:in_progress",
    "pressing_order.status_changed:ready","pressing_order.status_changed:picked_up"]) {
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:50,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:"pressing_order",aggregate_id:id,action_code:action,
      payload:{order_id:id,org_id:ORG_A,site_id:SITE_A}
    });
    if(normalized.aggregate_id!==id||normalized.action_code!==action)throw new Error("Pressing action mismatch");
  }
});
Deno.test("atomic sync validates appointment create, status and reschedule commands", () => {
  const id="88888888-8888-4888-8888-888888888899";
  for(const action of ["appointment.created","appointment.status_changed","appointment.rescheduled"]) {
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:51,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:"appointment",aggregate_id:id,action_code:action,
      payload:{appointment_id:id,org_id:ORG_A,site_id:SITE_A}
    });
    if(normalized.aggregate_id!==id||normalized.action_code!==action)throw new Error("Appointment action mismatch");
  }
});


Deno.test("atomic sync envelope validates cash session open/close and expense commands", () => {
  const cash="88888888-8888-4888-8888-888888888900";
  const expense="88888888-8888-4888-8888-888888888901";
  const actions=[
    ["cash_session.opened","cash_session",cash,"cash_session_id"],
    ["expense.created","expense",expense,"expense_id"],
    ["cash_session.closed","cash_session",cash,"cash_session_id"]
  ] as const;
  for(const [action,aggregate,id,idField] of actions){
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:70,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:aggregate,aggregate_id:id,action_code:action,
      payload:{[idField]:id,org_id:ORG_A,site_id:SITE_A}
    });
    if(normalized.aggregate_id!==id||normalized.action_code!==action)throw new Error("Cash action mismatch: "+action);
  }
});


Deno.test("atomic sync validates cash and pending Mobile Money sale commands", () => {
  const sale="88888888-8888-4888-8888-888888888902";
  for(const action of ["sale.created","sale.mobile_money_cancelled"]) {
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:80,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:"sale",aggregate_id:sale,action_code:action,
      payload:{sale_id:sale,org_id:ORG_A,site_id:SITE_A}
    });
    if(normalized.aggregate_id!==sale||normalized.action_code!==action) {
      throw new Error("Sale action mismatch: "+action);
    }
  }
});


Deno.test("atomic sync envelope validates customer update and waitlist conversion", () => {
  const customer="88888888-8888-4888-8888-888888888910";
  const appointment="88888888-8888-4888-8888-888888888911";
  const common={event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:100,
    org_id:ORG_A,site_id:SITE_A,workstation_id:null};
  const customerEvent=normalizeAtomicSyncEvent({
    ...common,aggregate_type:"customer",aggregate_id:customer,action_code:"customer.updated",
    payload:{customer_id:customer,org_id:ORG_A,site_id:SITE_A,expected_version:1}
  });
  const appointmentEvent=normalizeAtomicSyncEvent({
    ...common,aggregate_type:"appointment",aggregate_id:appointment,action_code:"appointment.created_from_waitlist",
    payload:{appointment_id:appointment,org_id:ORG_A,site_id:SITE_A,waitlist_record_id:"88888888-8888-4888-8888-888888888912"}
  });
  if(customerEvent.aggregate_id!==customer||appointmentEvent.aggregate_id!==appointment) {
    throw new Error("Customer/waitlist aggregate identity mismatch");
  }
});
Deno.test("atomic sync envelope validates staff time events as immutable time-event aggregates", () => {
  const id="88888888-8888-4888-8888-888888888913";
  for(const action of ["staff_clock_in.recorded","staff_break_start.recorded","staff_break_end.recorded","staff_clock_out.recorded"]) {
    const aggregate=action.split(".")[0];
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:101,
      org_id:ORG_A,site_id:SITE_A,workstation_id:null,
      aggregate_type:aggregate,aggregate_id:id,action_code:action,
      payload:{time_event_id:id,org_id:ORG_A,site_id:SITE_A,staff_member_id:SYNC_DEVICE}
    });
    if(normalized.action_code!==action||normalized.aggregate_type!==aggregate) {
      throw new Error("Staff time action mismatch: "+action);
    }
  }
});
Deno.test("atomic sync envelope validates the full management register action catalogue", () => {
  const types=[
    "quote","invoice","credit_note","refund_due","customer_receivable","purchase",
    "supplier","tax_estimate","business_goal","subscription_request","support_chat",
    "work_order","repair_order","service_order","appointment_waitlist",
    "staff_clock_in","staff_clock_out","staff_break_start","staff_break_end",
    "staff_commission","staff_advance","staff_bonus"
  ];
  for(let index=0;index<types.length;index++){
    const type=types[index],id="88888888-8888-4888-8888-"+String(8920+index).padStart(12,"0");
    for(const action of [type+".created",type+".status_changed"]){
      const normalized=normalizeAtomicSyncEvent({
        event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:110+index,
        org_id:ORG_A,site_id:SITE_A,workstation_id:null,
        aggregate_type:type,aggregate_id:id,action_code:action,
        payload:{record_id:id,org_id:ORG_A,site_id:SITE_A,record_type:type}
      });
      if(normalized.aggregate_id!==id||normalized.aggregate_type!==type){
        throw new Error("Management record action mismatch: "+action);
      }
    }
  }
});
Deno.test("atomic sync envelope validates both source and destination transfer commands", () => {
  const transfer="88888888-8888-4888-8888-888888888914";
  for(const [action,site,destination] of [
    ["inventory_transfer.requested",SITE_A,SITE_B],
    ["inventory_transfer.received_at_destination",SITE_B,SITE_B],
    ["inventory_transfer.status_changed",SITE_A,SITE_B]
  ] as const){
    const normalized=normalizeAtomicSyncEvent({
      event_id:SYNC_EVENT,device_id:SYNC_DEVICE,device_sequence:150,
      org_id:ORG_A,site_id:site,workstation_id:null,
      aggregate_type:"inventory_transfer",aggregate_id:transfer,action_code:action,
      payload:{transfer_id:transfer,record_id:transfer,org_id:ORG_A,site_id:site,
        source_site_id:SITE_A,destination_site_id:destination,inventory_item_id:"88888888-8888-4888-8888-888888888915"}
    });
    if(normalized.aggregate_type!=="inventory_transfer"||normalized.aggregate_id!==transfer){
      throw new Error("Transfer action aggregate mismatch: "+action);
    }
  }
});
