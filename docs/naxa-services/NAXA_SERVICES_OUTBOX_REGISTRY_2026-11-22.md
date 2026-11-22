# NAXA SERVICES — registre exhaustif de l'outbox (N1)

**Version :** 1.0  
**Date :** 22 novembre 2026  
**HEAD applicatif audité :** `ada9bc2fe4986925a6afcc07238c0bbdc11f2073`  
**Fichier source :** `apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/data/LocalErpStore.kt`

## Décision

**55/55 points d'émission classés.** Répartition : REMOTE_MUTATION = 43 ; DERIVED_SERVER_LEDGER = 1 ; COMPOSITE_CHILD = 7 ; SERVER_AUTHORITATIVE_MIRROR = 1 ; API_DIRECT_MIRROR = 1 ; LEGACY_LOCAL_HELPER = 2.

Ce registre est l'inventaire canonique de N1. Il qualifie un appel physique à `enqueue()` et pas simplement un nom d'action : il distingue les mutations à répliquer, les effets enfants d'une commande atomique, les projections de comptabilité, les miroirs d'API directe et les anciens helpers locaux. Les événements enfants et miroirs ne doivent jamais être envoyés comme mutations indépendantes.

## Contrat commun

- Enveloppe versionnée `v1`, `event_id` UUID stable, `app_id=naxa-services`, agrégat/type/ID, action allowlistée et payload typé minimisé.
- `org_id`, `site_id` (nullable uniquement pour les opérations explicitement organisationnelles), `workstation_id` si applicable ; le serveur recalcule les droits depuis la session.
- Acteur dérivé de l'identité authentifiée ; appareil rattaché à une installation enregistrée. La séquence de transport doit être par installation, monotone et conservée lors des reprises.
- Le serveur calcule le hash canonique et écrit mutation + reçu dans la même transaction. Même clé/même contenu = même reçu ; même clé/contenu divergent = rejet audité.
- Paiements, ventes, mouvements, pointages, reçus et transitions financières sont append-only ou à machine d'état ; les données maîtres modifiables utilisent une version optimiste. Aucun last-write-wins financier.
- Réseau/timeout/429/5xx : retry exponentiel avec jitter, même `event_id`. 4xx de validation/scope : rejet terminal. Dépendance absente : `blocked_dependency`, sans perte de la donnée.

## Matrice exacte des 55 call sites

| ID | Ligne source | Méthode | Agrégat | Expression action | Variantes concrètes | Qualification | Routage |
|---|---:|---|---|---|---|---|---|
| OBX-001 | 1295 | `saveSupplier` | `supplier` | `"supplier.saved"` | supplier.saved | **REMOTE_MUTATION** | `save_supplier` |
| OBX-002 | 1374 | `createSupplierPurchase` | `purchase` | `"purchase.ordered"` | purchase.ordered | **REMOTE_MUTATION** | `create_supplier_purchase` |
| OBX-003 | 1489 | `receiveSupplierPurchaseLine` | `purchase_receipt` | `"purchase.receipt.confirmed"` | purchase.receipt.confirmed | **REMOTE_MUTATION** | `receive_supplier_purchase_line` |
| OBX-004 | 1554 | `recordSupplierPayment` | `supplier_payment` | `"supplier.payment.recorded"` | supplier.payment.recorded | **REMOTE_MUTATION** | `record_supplier_payment` |
| OBX-005 | 1592 | `postAccountingEntry` | `accounting_entry` | `"accounting.entry.posted"` | accounting.entry.posted | **DERIVED_SERVER_LEDGER** | Server-side ledger posting inside the canonical parent RPC; no accounting.entry.posted RPC. |
| OBX-006 | 1601 | `saveSupplierWhatsApp` | `inventory_item` | `"inventory_item.supplier_whatsapp_updated"` | inventory_item.supplier_whatsapp_updated | **REMOTE_MUTATION** | `save_inventory_item` |
| OBX-007 | 1621 | `saveRecurringCharge` | `recurring_charge` | `"recurring_charge.saved"` | recurring_charge.saved | **REMOTE_MUTATION** | `upsert_recurring_charge` |
| OBX-008 | 1654 | `recordRecurringChargePayment` | `recurring_charge` | `"recurring_charge.payment_recorded"` | recurring_charge.payment_recorded | **REMOTE_MUTATION** | `record_recurring_charge_payment` |
| OBX-009 | 1668 | `deactivateRecurringCharge` | `recurring_charge` | `"recurring_charge.deactivated"` | recurring_charge.deactivated | **REMOTE_MUTATION** | `deactivate_recurring_charge` |
| OBX-010 | 1720 | `saveLoyaltyProgram` | `loyalty_program` | `"loyalty_program.updated"` | loyalty_program.updated | **REMOTE_MUTATION** | `upsert_loyalty_program` |
| OBX-011 | 1764 | `recordLoyaltyActivity` | `loyalty_activity` | `"loyalty_activity.recorded"` | loyalty_activity.recorded | **REMOTE_MUTATION** | `record_loyalty_activity` |
| OBX-012 | 1771 | `redeemLoyaltyReward` | `loyalty_reward` | `"loyalty_reward.redeemed"` | loyalty_reward.redeemed | **REMOTE_MUTATION** | `redeem_loyalty_reward` |
| OBX-013 | 1814 | `createPressingOrder` | `pressing_order` | `"pressing_order.created"` | pressing_order.created | **REMOTE_MUTATION** | `create_pressing_order` |
| OBX-014 | 1844 | `advancePressingOrder` | `pressing_order` | `"pressing_order.status_changed:" + next` | pressing_order.status_changed | **REMOTE_MUTATION** | `transition_pressing_order` |
| OBX-015 | 1886 | `createAppointment` | `appointment` | `"appointment.created"` | appointment.created | **REMOTE_MUTATION** | `create_appointment` |
| OBX-016 | 1912 | `openCashSession` | `cash_session` | `"cash_session.opened"` | cash_session.opened | **REMOTE_MUTATION** | `open_cash_session` |
| OBX-017 | 1984 | `recordSale` | `inventory_movement` | `"inventory_movement.sale_out"` | inventory_movement.sale_out | **COMPOSITE_CHILD** | Enfant de `sale.created` |
| OBX-018 | 1987 | `recordSale` | `sale` | `"sale.created"` | sale.created | **REMOTE_MUTATION** | `record_sale` |
| OBX-019 | 2028 | `cancelPendingMobileMoneySale` | `sale` | `"sale.mobile_money_cancelled"` | sale.mobile_money_cancelled | **REMOTE_MUTATION** | `cancel_pending_mobile_money_sale` |
| OBX-020 | 2072 | `applyServerConfirmedMobileMoneySale` | `inventory_movement` | `"inventory_movement.mobile_money_sale_out"` | inventory_movement.mobile_money_sale_out | **COMPOSITE_CHILD** | Enfant de `sale.payment_confirmed_server` |
| OBX-021 | 2091 | `applyServerConfirmedMobileMoneySale` | `sale` | `"sale.payment_confirmed_server"` | sale.payment_confirmed_server | **SERVER_AUTHORITATIVE_MIRROR** | Mobile Money webhook/Edge confirmation owns this transition; Android only mirrors the confirmed state. |
| OBX-022 | 2124 | `addExpense` | `expense` | `"expense.created"` | expense.created | **REMOTE_MUTATION** | `record_expense` |
| OBX-023 | 2152 | `closeCashSession` | `cash_session` | `"cash_session.closed"` | cash_session.closed | **REMOTE_MUTATION** | `close_cash_session` |
| OBX-024 | 2166 | `saveOrganizationProfile` | `organization` | `"organization.profile_saved"` | organization.profile_saved | **API_DIRECT_MIRROR** | AuthApi.updateOrganizationProfile (existing direct endpoint) |
| OBX-025 | 2173 | `createLocalSite` | `site` | `"site.created"` | site.created | **LEGACY_LOCAL_HELPER** | AuthApi.createSite (existing direct endpoint) |
| OBX-026 | 2227 | `createLocalWorkstation` | `workstation` | `"workstation.created"` | workstation.created | **LEGACY_LOCAL_HELPER** | AuthApi.createWorkstation (existing direct endpoint) |
| OBX-027 | 2269 | `createLocalService` | `service` | `"service.created"` | service.created | **REMOTE_MUTATION** | `create_service` |
| OBX-028 | 2318 | `createLocalCustomer` | `customer` | `"customer.created"` | customer.created | **REMOTE_MUTATION** | `upsert_customer` |
| OBX-029 | 2369 | `updateLocalCustomer` | `customer` | `"customer.updated"` | customer.updated | **REMOTE_MUTATION** | `upsert_customer` |
| OBX-030 | 2418 | `createCustomerFollowUp` | `customer_followup` | `"customer_followup.created"` | customer_followup.created | **REMOTE_MUTATION** | `create_customer_followup` |
| OBX-031 | 2447 | `completeCustomerFollowUp` | `customer_followup` | `"customer_followup.completed"` | customer_followup.completed | **REMOTE_MUTATION** | `complete_customer_followup` |
| OBX-032 | 2458 | `createInventoryItem` | `inventory_item` | `"inventory_item.created"` | inventory_item.created | **REMOTE_MUTATION** | `save_inventory_item` |
| OBX-033 | 2517 | `importInventoryBatch` | `inventory_movement` | `"inventory_movement.import_adjustment"` | inventory_movement.import_adjustment | **REMOTE_MUTATION** | `record_inventory_movement` |
| OBX-034 | 2534 | `importInventoryBatch` | `inventory_valuation` | `"inventory_valuation.import_updated"` | inventory_valuation.import_updated | **REMOTE_MUTATION** | `upsert_inventory_valuation` |
| OBX-035 | 2536 | `importInventoryBatch` | `inventory_item` | `"inventory_item.import_updated"` | inventory_item.import_updated | **REMOTE_MUTATION** | `save_inventory_item` |
| OBX-036 | 2552 | `importInventoryBatch` | `inventory_item` | `"inventory_item.imported"` | inventory_item.imported | **REMOTE_MUTATION** | `save_inventory_item` |
| OBX-037 | 2567 | `importInventoryBatch` | `inventory_movement` | `"inventory_movement.import_initial"` | inventory_movement.import_initial | **REMOTE_MUTATION** | `record_inventory_movement` |
| OBX-038 | 2581 | `importInventoryBatch` | `inventory_valuation` | `"inventory_valuation.imported"` | inventory_valuation.imported | **REMOTE_MUTATION** | `upsert_inventory_valuation` |
| OBX-039 | 2612 | `recordInventoryMovement` | `inventory_movement` | `"inventory_movement.created"` | inventory_movement.created | **REMOTE_MUTATION** | `record_inventory_movement` |
| OBX-040 | 2621 | `createSupportRequest` | `support_request` | `"support_request.created"` | support_request.created | **REMOTE_MUTATION** | `create_support_request` |
| OBX-041 | 2655 | `transitionAppointmentStatus` | `appointment` | `"appointment.status_changed"` | appointment.status_changed | **REMOTE_MUTATION** | `transition_appointment` |
| OBX-042 | 2689 | `rescheduleAppointment` | `appointment` | `"appointment.rescheduled"` | appointment.rescheduled | **REMOTE_MUTATION** | `reschedule_appointment` |
| OBX-043 | 2729 | `updateServiceCatalogItem` | `service` | `"service.updated"` | service.updated | **REMOTE_MUTATION** | `update_service` |
| OBX-044 | 2761 | `saveServiceConfiguration` | `service` | `"service.configuration_updated"` | service.configuration_updated | **REMOTE_MUTATION** | `update_service_configuration` |
| OBX-045 | 2825 | `convertWaitlistToAppointment` | `appointment` | `"appointment.created_from_waitlist"` | appointment.created_from_waitlist | **REMOTE_MUTATION** | `convert_waitlist_to_appointment` |
| OBX-046 | 2826 | `convertWaitlistToAppointment` | `appointment_waitlist` | `"appointment_waitlist.converted"` | appointment_waitlist.converted | **COMPOSITE_CHILD** | Enfant de `appointment.created_from_waitlist` |
| OBX-047 | 2907 | `recordStaffTimeEvent` | `eventType` | `eventType + ".recorded"` | staff_clock_in.recorded, staff_break_start.recorded, staff_break_end.recorded, staff_clock_out.recorded | **REMOTE_MUTATION** | `record_staff_time_event` |
| OBX-048 | 2947 | `createManagementRecord` | `recordType` | `recordType + ".created"` | quote.created, invoice.created, credit_note.created, refund_due.created, customer_receivable.created, purchase.created, supplier.created, tax_estimate.created, business_goal.created, subscription_request.created, support_chat.created, work_order.created, repair_order.created, service_order.created, appointment_waitlist.created, staff_clock_in.created, staff_clock_out.created, staff_break_start.created, staff_break_end.created, staff_commission.created, staff_advance.created, staff_bonus.created | **REMOTE_MUTATION** | `create_management_record` |
| OBX-049 | 3023 | `createInventoryTransfer` | `inventory_transfer` | `"inventory_transfer.requested"` | inventory_transfer.requested | **REMOTE_MUTATION** | `create_inventory_transfer` |
| OBX-050 | 3188 | `transitionManagementRecord` | `inventory_movement` | `"inventory_movement.purchase_received"` | inventory_movement.purchase_received | **COMPOSITE_CHILD** | Enfant de `management_record.status_changed` |
| OBX-051 | 3274 | `transitionManagementRecord` | `inventory_movement` | `"inventory_movement.transfer_out"` | inventory_movement.transfer_out | **COMPOSITE_CHILD** | Enfant de `inventory_transfer.received_at_destination` |
| OBX-052 | 3275 | `transitionManagementRecord` | `inventory_movement` | `"inventory_movement.transfer_in"` | inventory_movement.transfer_in | **COMPOSITE_CHILD** | Enfant de `inventory_transfer.received_at_destination` |
| OBX-053 | 3295 | `transitionManagementRecord` | `inventory_transfer` | `"inventory_transfer.received_at_destination"` | inventory_transfer.received_at_destination | **COMPOSITE_CHILD** | Enfant de `receive_inventory_transfer` |
| OBX-054 | 3313 | `transitionManagementRecord` | `current.recordType` | `current.recordType + ".status_changed"` | quote.status_changed, invoice.status_changed, credit_note.status_changed, refund_due.status_changed, customer_receivable.status_changed, purchase.status_changed, supplier.status_changed, tax_estimate.status_changed, business_goal.status_changed, subscription_request.status_changed, support_chat.status_changed, work_order.status_changed, repair_order.status_changed, service_order.status_changed, appointment_waitlist.status_changed, staff_clock_in.status_changed, staff_clock_out.status_changed, staff_break_start.status_changed, staff_break_end.status_changed, staff_commission.status_changed, staff_advance.status_changed, staff_bonus.status_changed, inventory_transfer.status_changed | **REMOTE_MUTATION** | `transition_management_record` |
| OBX-055 | 3334 | `saveInventoryValuation` | `inventory_valuation` | `"inventory_valuation.updated"` | inventory_valuation.updated | **REMOTE_MUTATION** | `upsert_inventory_valuation` |

## Décompte des routes

| Qualification | Nombre | Traitement |
|---|---:|---|
| REMOTE_MUTATION | 44 | Envoi indépendant avec contrat versionné et reçu idempotent. 11 codes sont déjà couverts par le coordinateur borné ; le reste est contrat N1 pour les gates de réalisation suivants. |
| COMPOSITE_CHILD | 7 | Pas d'envoi indépendant ; effet enfant inclus atomiquement dans la commande parente. |
| DERIVED_SERVER_LEDGER | 1 | Pas de replay ERP générique ; API directe, projection dérivée, miroir serveur ou helper local obsolète selon le détail JSON. |
| SERVER_AUTHORITATIVE_MIRROR | 1 | Pas de replay ERP générique ; API directe, projection dérivée, miroir serveur ou helper local obsolète selon le détail JSON. |
| API_DIRECT_MIRROR | 1 | Pas de replay ERP générique ; API directe, projection dérivée, miroir serveur ou helper local obsolète selon le détail JSON. |
| LEGACY_LOCAL_HELPER | 2 | Pas de replay ERP générique ; API directe, projection dérivée, miroir serveur ou helper local obsolète selon le détail JSON. |

## Contrats action par action et exclusions

### OBX-001 — supplier.saved

- Source : ligne 1295, `saveSupplier`, agrégat `supplier`, expression `"supplier.saved"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Supplier master data (one organisation/site); UUID supplier.id shared local/server.
- Handler / route : `save_supplier`.
- Champs du contrat : supplier_id, org_id, site_id, name, phone, whatsapp, email, address, payment_terms_days, notes.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; duplicate supplier name/code policy enforced by server
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-002 — purchase.ordered

- Source : ligne 1374, `createSupplierPurchase`, agrégat `purchase`, expression `"purchase.ordered"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Supplier purchase document and its ordered lines.
- Handler / route : `create_supplier_purchase`.
- Champs du contrat : purchase_id, idempotency_key, org_id, site_id, supplier_id, reference, supplier_invoice_number, lines[line_id,inventory_item_id,item_type,description,unit,quantity_ordered,unit_cost_xaf], recoverable_tax_xaf, non_recoverable_tax_xaf, shipping_xaf, other_fees_xaf, due_at, notes.
- Dépendances : supplier_id; every stock line inventory_item_id must resolve to a server-confirmed item on same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; immutable ordered document; changes require explicit amendment action
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-003 — purchase.receipt.confirmed

- Source : ligne 1489, `receiveSupplierPurchaseLine`, agrégat `purchase_receipt`, expression `"purchase.receipt.confirmed"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Supplier receipt event; server purchase/line balances and accounting are authoritative after receipt.
- Handler / route : `receive_supplier_purchase_line`.
- Champs du contrat : receipt_id, org_id, site_id, purchase_id, line_id, quantity, idempotency_key.
- Dépendances : purchase_id and line_id already exist remotely; received quantity does not exceed remaining ordered quantity
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; concurrent partial receipts serialize against server remaining quantity
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-004 — supplier.payment.recorded

- Source : ligne 1554, `recordSupplierPayment`, agrégat `supplier_payment`, expression `"supplier.payment.recorded"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Supplier payment ledger linked to supplier purchase and treasury session.
- Handler / route : `record_supplier_payment`.
- Champs du contrat : payment_id, org_id, site_id, purchase_id, amount_xaf, payment_method, cash_session_id, payment_reference, idempotency_key.
- Dépendances : purchase receipt exists remotely; cash_session_id must resolve to a server-open session when payment_method=cash
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; never merge or last-write-wins a payment
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-005 — accounting.entry.posted

- Source : ligne 1592, `postAccountingEntry`, agrégat `accounting_entry`, expression `"accounting.entry.posted"`.
- Classe : **DERIVED_SERVER_LEDGER** ; disposition : `DO_NOT_SEND`.
- Source de vérité : Local derived accounting journal projection; server must derive its own ledger from accepted source transactions, not trust client-selected account labels.
- Handler / route : `Server-side ledger posting inside the canonical parent RPC; no accounting.entry.posted RPC.`.
- Champs du contrat : batch_id, source_type, source_id, event_code, debit_account, credit_account, amount_xaf, description, actor_member_id, occurred_at.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : No remote idempotency receipt because no remote mutation is issued. Keep local deduplication according to the source aggregate.
- Conflits : No remote conflict resolution; parent canonical server transaction owns any replicated effect.
- Reprise : Do not retry to ERP; local retention and local diagnostics only.
- Motif d'exclusion : This event is emitted by postAccountingEntry() after local business mutations. Sending it separately would trust client-side symbolic accounts and double-post entries. The remote ledger is derived atomically from the canonical accepted sale/purchase/payment/expense/charge operation.
- Tests de sortie : event is classified and not selected by the sync coordinator; no duplicate remote mutation is generated by the canonical parent/API pathway.

### OBX-006 — inventory_item.supplier_whatsapp_updated

- Source : ligne 1601, `saveSupplierWhatsApp`, agrégat `inventory_item`, expression `"inventory_item.supplier_whatsapp_updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory item master record; WhatsApp contact is item/supplier metadata, not an automated message instruction.
- Handler / route : `save_inventory_item`.
- Champs du contrat : inventory_item_id, org_id, site_id, sku, name, unit, reorder_level, supplier_whatsapp.
- Dépendances : inventory_item_id exists remotely within same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : OPTIMISTIC_VERSIONED; never silently overwrite. Return conflict with server/client versions; user or approved business rule resolves.
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-007 — recurring_charge.saved

- Source : ligne 1621, `saveRecurringCharge`, agrégat `recurring_charge`, expression `"recurring_charge.saved"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Recurring charge schedule and its current state.
- Handler / route : `upsert_recurring_charge`.
- Champs du contrat : charge_id, org_id, site_id, name, category, amount_xaf, recurrence, next_due_at, reminder_days, active, created_by_member_id, created_at, updated_at.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; server revision controls concurrent edits
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-008 — recurring_charge.payment_recorded

- Source : ligne 1654, `recordRecurringChargePayment`, agrégat `recurring_charge`, expression `"recurring_charge.payment_recorded"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Charge payment ledger; each partial/full payment is immutable; charge next due date is server-derived.
- Handler / route : `record_recurring_charge_payment`.
- Champs du contrat : payment_id, charge_id, org_id, site_id, reference_due_at, paid_at, amount_xaf.
- Dépendances : recurring_charge exists remotely; remaining balance for this due cycle is at least amount_xaf
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; server serializes partial payments and advances recurrence only after full settlement
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-009 — recurring_charge.deactivated

- Source : ligne 1668, `deactivateRecurringCharge`, agrégat `recurring_charge`, expression `"recurring_charge.deactivated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Recurring charge schedule and versioned active state.
- Handler / route : `deactivate_recurring_charge`.
- Champs du contrat : charge_id, org_id, site_id, deactivated_at, reason_or_actor_context.
- Dépendances : recurring_charge exists remotely
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; duplicate deactivation idempotent
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-010 — loyalty_program.updated

- Source : ligne 1720, `saveLoyaltyProgram`, agrégat `loyalty_program`, expression `"loyalty_program.updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Organisation-level activity loyalty policy; site_id is intentionally null.
- Handler / route : `upsert_loyalty_program`.
- Champs du contrat : program_id, org_id, activity_profile, program_code, name, description, metric_code, unit_amount_xaf, target_value, reward_description, window_days, active, updated_at.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; promoter/owner permission required
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-011 — loyalty_activity.recorded

- Source : ligne 1764, `recordLoyaltyActivity`, agrégat `loyalty_activity`, expression `"loyalty_activity.recorded"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Loyalty activity ledger; server recomputes metric delta and reward waves from approved program and confirmed qualifying activity.
- Handler / route : `record_loyalty_activity`.
- Champs du contrat : activity_event_id, org_id, site_id, program_id, customer_id, amount_xaf, occurred_at.
- Dépendances : loyalty_program exists and active; customer belongs to same org/site; qualifying paid sale/service reference should be attached when caisse integration is enabled
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; same source sale/activity cannot earn twice
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-012 — loyalty_reward.redeemed

- Source : ligne 1771, `redeemLoyaltyReward`, agrégat `loyalty_reward`, expression `"loyalty_reward.redeemed"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Commande parente : `redeem_loyalty_reward`.
- Source de vérité : Loyalty reward ledger and redemption state.
- Handler / route : `redeem_loyalty_reward`.
- Champs du contrat : reward_event_id, org_id, site_id, program_id, customer_id, wave_number, related_event_id, redemption_status, redeemed_at.
- Dépendances : reward must exist and be available; customer and program belong to same org
- Idempotence : Stable event_id UUID; one redemption per reward event; duplicate returns same receipt.
- Conflits : APPEND_ONLY; reject if reward is not available or has already been redeemed by another event.
- Reprise : Network/429/5xx backoff same event id; 4xx terminal; missing reward blocked.
- Tests de sortie : available reward redeemed; already redeemed rejected/idempotent duplicate; cross-tenant/site denied; concurrent redemption yields exactly one winner.

### OBX-013 — pressing_order.created

- Source : ligne 1814, `createPressingOrder`, agrégat `pressing_order`, expression `"pressing_order.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Pressing ticket/order table and its status history.
- Handler / route : `create_pressing_order`.
- Champs du contrat : order_id, org_id, site_id, workstation_id, ticket_number, customer_name, customer_phone, items_summary, total_xaf, deposit_xaf, promised_at, status, created_at.
- Dépendances : workstation_id if present must belong to site; ticket number unique within the organisation
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; ticket is immutable after creation except explicit status/adjustment commands
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-014 — pressing_order.status_changed

- Source : ligne 1843, `advancePressingOrder`, agrégat `pressing_order`, expression `"pressing_order.status_changed:" + next`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Pressing order and append-only LocalPressingStatusEvent history.
- Handler / route : `transition_pressing_order`.
- Champs du contrat : order_id, org_id, site_id, from_status, to_status, reason, expected_version, transitioned_at.
- Dépendances : pressing_order exists; transition allowed by pressing lifecycle
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY_VERSIONED; server validates state machine and expected version
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-015 — appointment.created

- Source : ligne 1886, `createAppointment`, agrégat `appointment`, expression `"appointment.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Appointment schedule.
- Handler / route : `create_appointment`.
- Champs du contrat : appointment_id, org_id, site_id, workstation_id, customer_reference_or_name, service_reference_or_name, assigned_member_id, starts_at, ends_at, deposit_xaf, status, created_at.
- Dépendances : site active; workstation and assigned member belong to site; no overlapping appointment for workstation/member
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : SLOT_UNIQUENESS; server rechecks overlap at commit
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-016 — cash_session.opened

- Source : ligne 1912, `openCashSession`, agrégat `cash_session`, expression `"cash_session.opened"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Cash register session and authoritative opening float.
- Handler / route : `open_cash_session`.
- Champs du contrat : cash_session_id, org_id, site_id, register_id, register_name, opening_float_xaf, opened_by_member_id, opened_at.
- Dépendances : register belongs to site; no other open session for same register
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY_STATE_MACHINE; one open session per register
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-017 — inventory_movement.sale_out

- Source : ligne 1984, `recordSale`, agrégat `inventory_movement`, expression `"inventory_movement.sale_out"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `sale.created`.
- Source de vérité : Server sale posting derives its inventory movement from the sale lines and cost snapshot.
- Handler / route : `Included atomically in sale.created`.
- Champs du contrat : movement_id, inventory_item_id, quantity_delta, movement_type, reason, sale_id.
- Dépendances : sale.created accepted and paid/confirmed; stock item mapping present
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : This movement is inserted in the same local transaction as sale.created; it must be created server-side within sale posting, never replayed independently.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-018 — sale.created

- Source : ligne 1987, `recordSale`, agrégat `sale`, expression `"sale.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Sale record, tender state and associated line/cost snapshot.
- Handler / route : `record_sale`.
- Champs du contrat : sale_id, org_id, site_id, cash_session_id, sale_number, description, total_xaf, payment_method, status, inventory_item_id, stock_quantity, unit_cost_at_sale_xaf, cost_of_goods_xaf, cost_snapshot_complete, created_at.
- Dépendances : cash_session exists remotely and is open; inventory_item exists remotely if stock is sold; mobile_money stays pending until signed provider confirmation
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; one sale ID and one server posting
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-019 — sale.mobile_money_cancelled

- Source : ligne 2028, `cancelPendingMobileMoneySale`, agrégat `sale`, expression `"sale.mobile_money_cancelled"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Pending sale state; no money received until provider confirmation is verified.
- Handler / route : `cancel_pending_mobile_money_sale`.
- Champs du contrat : sale_id, org_id, site_id, cancelled_at, reason, expected_status.
- Dépendances : sale exists remotely with payment_method=mobile_money and status=pending
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_STATE_MACHINE; cancellation only before payment confirmation
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-020 — inventory_movement.mobile_money_sale_out

- Source : ligne 2072, `applyServerConfirmedMobileMoneySale`, agrégat `inventory_movement`, expression `"inventory_movement.mobile_money_sale_out"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `sale.payment_confirmed_server`.
- Source de vérité : Server-confirmed Mobile Money sale; movement is a server-side consequence.
- Handler / route : `Included atomically in sale.payment_confirmed_server`.
- Champs du contrat : movement_id, sale_id, inventory_item_id, quantity_delta, cost_snapshot.
- Dépendances : verified provider webhook has confirmed matching amount/currency/reference; sale is still pending
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : The local method applies an already server-confirmed payment result; the stock out must be produced by the authoritative payment-confirmation transaction.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-021 — sale.payment_confirmed_server

- Source : ligne 2091, `applyServerConfirmedMobileMoneySale`, agrégat `sale`, expression `"sale.payment_confirmed_server"`.
- Classe : **SERVER_AUTHORITATIVE_MIRROR** ; disposition : `DO_NOT_ECHO_TO_SERVER`.
- Source de vérité : Server-side signed Mobile Money confirmation and sale ledger; the Android method receives/applies this authoritative result locally.
- Handler / route : `Mobile Money webhook/Edge confirmation owns this transition; Android only mirrors the confirmed state.`.
- Champs du contrat : sale_id, provider, provider_reference, amount_xaf, currency, confirmed_at, server_transaction_id.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : No remote idempotency receipt because no remote mutation is issued. Keep local deduplication according to the source aggregate.
- Conflits : No remote conflict resolution; parent canonical server transaction owns any replicated effect.
- Reprise : Do not retry to ERP; local retention and local diagnostics only.
- Motif d'exclusion : This action is a local application of server confirmation. Echoing it as a client mutation would falsely claim authority over provider payment confirmation.
- Tests de sortie : event is classified and not selected by the sync coordinator; no duplicate remote mutation is generated by the canonical parent/API pathway.

### OBX-022 — expense.created

- Source : ligne 2124, `addExpense`, agrégat `expense`, expression `"expense.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Expense ledger linked to a cash session or an explicitly supported non-cash treasury account.
- Handler / route : `record_expense`.
- Champs du contrat : expense_id, org_id, site_id, cash_session_id, category, description, amount_xaf, occurred_at.
- Dépendances : cash_session exists remotely and open when cash; category/policy permits expense
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; corrections via reversal/adjustment, never overwrite
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-023 — cash_session.closed

- Source : ligne 2152, `closeCashSession`, agrégat `cash_session`, expression `"cash_session.closed"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Cash session close count, variance and close audit.
- Handler / route : `close_cash_session`.
- Champs du contrat : cash_session_id, org_id, site_id, closed_by_member_id, closed_at, counted_close_xaf, variance_xaf, variance_reason.
- Dépendances : cash_session open remotely; all accepted cash movements for session applied
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY_STATE_MACHINE; server computes expected balance and variance
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-024 — organization.profile_saved

- Source : ligne 2166, `saveOrganizationProfile`, agrégat `organization`, expression `"organization.profile_saved"`.
- Classe : **API_DIRECT_MIRROR** ; disposition : `DO_NOT_SEND`.
- Source de vérité : Auth/organization profile is authoritative through AuthApi.updateOrganizationProfile; LocalOrganizationProfile is a UI cache and offline draft.
- Handler / route : `AuthApi.updateOrganizationProfile (existing direct endpoint)`.
- Champs du contrat : org_id, display_name, business_mode, default_locale, updated_at.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : No remote idempotency receipt because no remote mutation is issued. Keep local deduplication according to the source aggregate.
- Conflits : No remote conflict resolution; parent canonical server transaction owns any replicated effect.
- Reprise : Do not retry to ERP; local retention and local diagnostics only.
- Motif d'exclusion : The active UI invokes the direct authenticated AuthApi endpoint first; Room write mirrors success or preserves a clearly labelled local-only draft after failure. This outbox pointer is not an ERP replay contract.
- Tests de sortie : AuthApi endpoint acknowledged before server-confirmed UI state; fallback is explicitly local draft and never marked server-confirmed.

### OBX-025 — site.created

- Source : ligne 2173, `createLocalSite`, agrégat `site`, expression `"site.created"`.
- Classe : **LEGACY_LOCAL_HELPER** ; disposition : `DO_NOT_SEND`.
- Source de vérité : Server-managed site directory via AuthApi.createSite; LocalSite legacy cache helper has no active UI caller.
- Handler / route : `AuthApi.createSite (existing direct endpoint)`.
- Champs du contrat : site_id, org_id, code, name, address_label, phone_contact, status.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : No remote idempotency receipt because no remote mutation is issued. Keep local deduplication according to the source aggregate.
- Conflits : No remote conflict resolution; parent canonical server transaction owns any replicated effect.
- Reprise : Do not retry to ERP; local retention and local diagnostics only.
- Motif d'exclusion : The current site creation screen calls AuthApi.createSite directly and does not call createLocalSite; the latter is a legacy local helper. Its queue event must not be mistaken for a valid API mutation.
- Tests de sortie : static repository scan confirms there is no active createLocalSite caller; AuthApi.createSite is the sole live site-create UI path.

### OBX-026 — workstation.created

- Source : ligne 2227, `createLocalWorkstation`, agrégat `workstation`, expression `"workstation.created"`.
- Classe : **LEGACY_LOCAL_HELPER** ; disposition : `DO_NOT_SEND`.
- Source de vérité : Server-managed workstation directory via AuthApi.createWorkstation; LocalWorkstation local draft helper has no active UI caller.
- Handler / route : `AuthApi.createWorkstation (existing direct endpoint)`.
- Champs du contrat : workstation_id, org_id, site_id, code, name, kind, capacity, status.
- Dépendances : aucune dépendance métier préalable.
- Idempotence : No remote idempotency receipt because no remote mutation is issued. Keep local deduplication according to the source aggregate.
- Conflits : No remote conflict resolution; parent canonical server transaction owns any replicated effect.
- Reprise : Do not retry to ERP; local retention and local diagnostics only.
- Motif d'exclusion : The current workstation screen calls AuthApi.createWorkstation directly and caches the returned server row; createLocalWorkstation is not called by active UI.
- Tests de sortie : static repository scan confirms there is no active createLocalWorkstation caller; AuthApi.createWorkstation is the sole live workstation-create UI path.

### OBX-027 — service.created

- Source : ligne 2269, `createLocalService`, agrégat `service`, expression `"service.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Service catalogue entry and activity configuration.
- Handler / route : `create_service`.
- Champs du contrat : service_id, org_id, site_id, code, activity, name, duration_minutes, price_xaf, active, category, description, provider_member_ids, required_workstation_kinds, package_sessions.
- Dépendances : site exists; provider members and required workstation kinds belong to same site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; unique service code per site
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-028 — customer.created

- Source : ligne 2318, `createLocalCustomer`, agrégat `customer`, expression `"customer.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Customer master and consent record.
- Handler / route : `upsert_customer`.
- Champs du contrat : customer_id, org_id, site_id, display_name, phone_contact, contact_consent, address_line, neighborhood, landmark, location_if_location_consent, notes_private_only_if_role_authorized.
- Dépendances : site active; consent policy checked; precise location omitted unless location_consent_at is present
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; customer merge/deduplication requires explicit review
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-029 — customer.updated

- Source : ligne 2369, `updateLocalCustomer`, agrégat `customer`, expression `"customer.updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Customer master and consent record.
- Handler / route : `upsert_customer`.
- Champs du contrat : customer_id, org_id, site_id, display_name, phone_contact, contact_consent, address_line, neighborhood, landmark, location_if_location_consent, notes_private_only_if_role_authorized.
- Dépendances : customer exists in same org/site; location payload only with explicit consent
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; concurrent edits return conflict, no silent overwrite
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-030 — customer_followup.created

- Source : ligne 2418, `createCustomerFollowUp`, agrégat `customer_followup`, expression `"customer_followup.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : CRM follow-up schedule; no message is sent by this operation.
- Handler / route : `create_customer_followup`.
- Champs du contrat : followup_id, org_id, site_id, customer_id, title, frequency, channel, notes, next_due_at, status, created_at.
- Dépendances : customer exists same org/site; whatsapp/phone channel only records planned channel; no outbound message without user action/authorization
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; schedule revision controls changes
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-031 — customer_followup.completed

- Source : ligne 2447, `completeCustomerFollowUp`, agrégat `customer_followup`, expression `"customer_followup.completed"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : CRM follow-up schedule and completion ledger.
- Handler / route : `complete_customer_followup`.
- Champs du contrat : followup_id, org_id, site_id, completed_at, next_due_at_if_repeating, completion_note.
- Dépendances : follow-up exists and active
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY_COMPLETION; same follow-up cycle cannot complete twice
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-032 — inventory_item.created

- Source : ligne 2458, `createInventoryItem`, agrégat `inventory_item`, expression `"inventory_item.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory item master (quantity on hand comes from movement ledger, not master snapshot).
- Handler / route : `save_inventory_item`.
- Champs du contrat : inventory_item_id, org_id, site_id, sku, name, unit, reorder_level, supplier_whatsapp.
- Dépendances : UUID stable; SKU uniqueness policy applied within site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : OPTIMISTIC_VERSIONED; never silently overwrite. Return conflict with server/client versions; user or approved business rule resolves.
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-033 — inventory_movement.import_adjustment

- Source : ligne 2517, `importInventoryBatch`, agrégat `inventory_movement`, expression `"inventory_movement.import_adjustment"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Imported adjustment movement; never overwrite historical movements.
- Handler / route : `record_inventory_movement`.
- Champs du contrat : movement_id, org_id, site_id, inventory_item_id, movement_type, quantity_delta, reason, import_batch_id.
- Dépendances : inventory_item mapping exists; import batch and row validation passed
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; import row idempotency per batch and row ID
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-034 — inventory_valuation.import_updated

- Source : ligne 2534, `importInventoryBatch`, agrégat `inventory_valuation`, expression `"inventory_valuation.import_updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory valuation is a distinct value entity (unit cost and selling price); not represented by inventory_item snapshot.
- Handler / route : `upsert_inventory_valuation`.
- Champs du contrat : valuation_id, inventory_item_id, org_id, site_id, unit_cost_xaf, selling_price_xaf, updated_at, import_batch_id.
- Dépendances : inventory_item exists same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; reject stale revision or explicit conflict
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-035 — inventory_item.import_updated

- Source : ligne 2536, `importInventoryBatch`, agrégat `inventory_item`, expression `"inventory_item.import_updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory item master metadata.
- Handler / route : `save_inventory_item`.
- Champs du contrat : inventory_item_id, org_id, site_id, sku, name, unit, reorder_level, supplier_whatsapp.
- Dépendances : inventory_item exists same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : OPTIMISTIC_VERSIONED; never silently overwrite. Return conflict with server/client versions; user or approved business rule resolves.
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-036 — inventory_item.imported

- Source : ligne 2552, `importInventoryBatch`, agrégat `inventory_item`, expression `"inventory_item.imported"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory item master metadata.
- Handler / route : `save_inventory_item`.
- Champs du contrat : inventory_item_id, org_id, site_id, sku, name, unit, reorder_level, supplier_whatsapp.
- Dépendances : UUID stable; duplicate batch rows rejected/deduped
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : OPTIMISTIC_VERSIONED; never silently overwrite. Return conflict with server/client versions; user or approved business rule resolves.
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-037 — inventory_movement.import_initial

- Source : ligne 2567, `importInventoryBatch`, agrégat `inventory_movement`, expression `"inventory_movement.import_initial"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Opening stock quantity as immutable initial movement.
- Handler / route : `record_inventory_movement`.
- Champs du contrat : movement_id, org_id, site_id, inventory_item_id, movement_type, quantity_delta, reason, import_batch_id.
- Dépendances : inventory_item mapping exists; import batch row unique
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; opening stock event applied once
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-038 — inventory_valuation.imported

- Source : ligne 2581, `importInventoryBatch`, agrégat `inventory_valuation`, expression `"inventory_valuation.imported"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory valuation created by stock import.
- Handler / route : `upsert_inventory_valuation`.
- Champs du contrat : valuation_id, inventory_item_id, org_id, site_id, unit_cost_xaf, selling_price_xaf, updated_at, import_batch_id.
- Dépendances : inventory_item exists same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-039 — inventory_movement.created

- Source : ligne 2612, `recordInventoryMovement`, agrégat `inventory_movement`, expression `"inventory_movement.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory movement ledger; stock on hand is derived by summing accepted movements.
- Handler / route : `record_inventory_movement`.
- Champs du contrat : movement_id, org_id, site_id, inventory_item_id, movement_type, quantity_delta, reason, occurred_at.
- Dépendances : inventory_item mapping exists; movement type/quantity sign valid; no negative stock where policy forbids
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; corrections are new adjustment movements
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-040 — support_request.created

- Source : ligne 2621, `createSupportRequest`, agrégat `support_request`, expression `"support_request.created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Support inbox case; local draft remains unsubmitted until remote receipt.
- Handler / route : `create_support_request`.
- Champs du contrat : request_id, org_id, site_id, subject, description, priority, created_at.
- Dépendances : authenticated organization/member; site must be valid when supplied
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY; support case immutable except explicit reply/status actions
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-041 — appointment.status_changed

- Source : ligne 2655, `transitionAppointmentStatus`, agrégat `appointment`, expression `"appointment.status_changed"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Appointment state and immutable status transition log.
- Handler / route : `transition_appointment`.
- Champs du contrat : appointment_id, org_id, site_id, from_status, to_status, reason, expected_version, transitioned_at.
- Dépendances : appointment exists; transition allowed from current server status
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : OPTIMISTIC_VERSIONED; status conflicts require refresh/review
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-042 — appointment.rescheduled

- Source : ligne 2689, `rescheduleAppointment`, agrégat `appointment`, expression `"appointment.rescheduled"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Appointment schedule and resource reservation.
- Handler / route : `reschedule_appointment`.
- Champs du contrat : appointment_id, org_id, site_id, workstation_id, starts_at, ends_at, assigned_member_id, expected_version, reason.
- Dépendances : site and workstation/assigned member valid; new slot has no overlap
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : SLOT_UNIQUENESS; server locks/checks slot atomically
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-043 — service.updated

- Source : ligne 2729, `updateServiceCatalogItem`, agrégat `service`, expression `"service.updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Service catalogue entry.
- Handler / route : `update_service`.
- Champs du contrat : service_id, org_id, site_id, code, activity, name, duration_minutes, price_xaf, active, expected_version.
- Dépendances : service exists in same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-044 — service.configuration_updated

- Source : ligne 2761, `saveServiceConfiguration`, agrégat `service`, expression `"service.configuration_updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Service catalogue provider/workstation/package configuration.
- Handler / route : `update_service_configuration`.
- Champs du contrat : service_id, org_id, site_id, category, description, provider_member_ids, required_workstation_kinds, package_sessions, expected_version.
- Dépendances : service exists; provider/workstation references belong to site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-045 — appointment.created_from_waitlist

- Source : ligne 2825, `convertWaitlistToAppointment`, agrégat `appointment`, expression `"appointment.created_from_waitlist"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Atomic conversion of one waitlist record into one appointment.
- Handler / route : `convert_waitlist_to_appointment`.
- Champs du contrat : appointment_id, org_id, site_id, waitlist_record_id, workstation_id, starts_at, duration_minutes, deposit_xaf, reason, assigned_member_id.
- Dépendances : waitlist entry is open/contacted; no appointment slot conflict; site/workstation/member valid
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : ATOMIC_COMPOSITE; waitlist and appointment change in one transaction
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-046 — appointment_waitlist.converted

- Source : ligne 2826, `convertWaitlistToAppointment`, agrégat `appointment_waitlist`, expression `"appointment_waitlist.converted"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `appointment.created_from_waitlist`.
- Source de vérité : Waitlist record state is changed to booked/converted by the same conversion transaction.
- Handler / route : `Included atomically in appointment.created_from_waitlist`.
- Champs du contrat : waitlist_id, appointment_id, from_status, to_status, reason, converted_at.
- Dépendances : parent waitlist entry exists
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : The waitlist status and appointment are one atomic domain command. This event is only a child notification of the conversion and is not separately dispatched.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-047 — staff_clock_in.recorded / staff_break_start.recorded / staff_break_end.recorded / staff_clock_out.recorded

- Source : ligne 2907, `recordStaffTimeEvent`, agrégat `eventType`, expression `eventType + ".recorded"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Staff timekeeping event ledger; staff identity must be a stable organisation-scoped staff UUID, not display name alone.
- Handler / route : `record_staff_time_event`.
- Champs du contrat : time_event_id, org_id, site_id, workstation_id, staff_member_id, staff_name_snapshot, event_type, occurred_at.
- Dépendances : staff_member_id must resolve to an active staff/person record in org; clock sequence valid on server
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY_SEQUENCE; server serializes clock/break sequence per staff member
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-048 — quote.created / invoice.created / credit_note.created / refund_due.created / customer_receivable.created / purchase.created / supplier.created / tax_estimate.created / business_goal.created / subscription_request.created / support_chat.created / work_order.created / repair_order.created / service_order.created / appointment_waitlist.created / staff_clock_in.created / staff_clock_out.created / staff_break_start.created / staff_break_end.created / staff_commission.created / staff_advance.created / staff_bonus.created

- Source : ligne 2947, `createManagementRecord`, agrégat `recordType`, expression `recordType + ".created"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Polymorphic management register for documents/work orders/HR variables and drafts; exact record_type is validated against the allowlist.
- Handler / route : `create_management_record`.
- Champs du contrat : record_id, org_id, site_id, workstation_id, record_type, reference, title, counterparty, amount_xaf, paid_xaf, due_at, status, metadata_json, created_at.
- Dépendances : record type and status allowlist; workstation belongs to site when present; payment/entitlement/commission is not finalized from draft status
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : APPEND_ONLY_CREATE; UUID and record_type stable
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-049 — inventory_transfer.requested

- Source : ligne 3023, `createInventoryTransfer`, agrégat `inventory_transfer`, expression `"inventory_transfer.requested"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory transfer between two sites; this command creates the transfer request only.
- Handler / route : `create_inventory_transfer`.
- Champs du contrat : transfer_id, org_id, source_site_id, destination_site_id, inventory_item_id, sku_snapshot, quantity, requested_by, requested_at, reference, status.
- Dépendances : actor role promoter; both sites active and in same org; source item exists and sufficient stock
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_STATE_MACHINE; request ID unique
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-050 — inventory_movement.purchase_received

- Source : ligne 3188, `transitionManagementRecord`, agrégat `inventory_movement`, expression `"inventory_movement.purchase_received"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `management_record.status_changed`.
- Source de vérité : Stock movement created by receiving a legacy management_record purchase; include the movement as part of the parent transition transaction.
- Handler / route : `Included atomically in management_record.status_changed`.
- Champs du contrat : movement_id, inventory_item_id, quantity_delta, reason, purchase_record_id.
- Dépendances : parent management_record type=purchase transitions to received; item belongs to same org/site and quantity > 0
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : The movement is produced inside transitionManagementRecord() for the generic/legacy purchase record. It must be included in the parent status-transition command, not sent as a second stock movement.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-051 — inventory_movement.transfer_out

- Source : ligne 3274, `transitionManagementRecord`, agrégat `inventory_movement`, expression `"inventory_movement.transfer_out"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `inventory_transfer.received_at_destination`.
- Source de vérité : Source-site deduction movement created atomically when a transfer is received.
- Handler / route : `Included atomically in inventory_transfer.received_at_destination`.
- Champs du contrat : movement_id, inventory_item_id, source_site_id, quantity_delta, transfer_id, reason.
- Dépendances : approved transfer exists; source stock still sufficient
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : The source movement is one leg of the atomic transfer receipt; no independent send.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-052 — inventory_movement.transfer_in

- Source : ligne 3275, `transitionManagementRecord`, agrégat `inventory_movement`, expression `"inventory_movement.transfer_in"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `inventory_transfer.received_at_destination`.
- Source de vérité : Destination-site addition movement created atomically when a transfer is received.
- Handler / route : `Included atomically in inventory_transfer.received_at_destination`.
- Champs du contrat : movement_id, inventory_item_id, destination_site_id, quantity_delta, transfer_id, reason.
- Dépendances : approved transfer exists; destination SKU/unit compatibility verified
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : The destination movement is the second leg of the atomic transfer receipt; no independent send.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-053 — inventory_transfer.received_at_destination

- Source : ligne 3295, `transitionManagementRecord`, agrégat `inventory_transfer`, expression `"inventory_transfer.received_at_destination"`.
- Classe : **COMPOSITE_CHILD** ; disposition : `DO_NOT_SEND_INDEPENDENTLY`.
- Commande parente : `receive_inventory_transfer`.
- Source de vérité : Atomic receive command owns transfer state plus both source/destination movements; this event is a local projection marker.
- Handler / route : `Included atomically in receive_inventory_transfer`.
- Champs du contrat : transfer_id, source_site_id, destination_site_id, destination_inventory_item_id, received_at, received_by, reason.
- Dépendances : transfer status approved; cross-site permissions validated; source stock and destination SKU/unit checks pass
- Idempotence : Parent event_id is the only idempotency key; child row IDs are stable and unique within org.
- Conflits : Resolve at the parent aggregate. Child projections are created in the same transaction or none are.
- Reprise : Retry parent with same event_id; never retry the child as a standalone event.
- Note de qualification : The specialized receipt is the canonical transfer receive command at the server. The local movement rows are child effects; this outbox entry is classified as the event marker for the same command.
- Tests de sortie : parent and all children commit atomically; retry creates no duplicate child; failed parent leaves no child mutation; scope/dependency violation rejects the whole command.

### OBX-054 — quote.status_changed / invoice.status_changed / credit_note.status_changed / refund_due.status_changed / customer_receivable.status_changed / purchase.status_changed / supplier.status_changed / tax_estimate.status_changed / business_goal.status_changed / subscription_request.status_changed / support_chat.status_changed / work_order.status_changed / repair_order.status_changed / service_order.status_changed / appointment_waitlist.status_changed / staff_clock_in.status_changed / staff_clock_out.status_changed / staff_break_start.status_changed / staff_break_end.status_changed / staff_commission.status_changed / staff_advance.status_changed / staff_bonus.status_changed / inventory_transfer.status_changed

- Source : ligne 3313, `transitionManagementRecord`, agrégat `current.recordType`, expression `current.recordType + ".status_changed"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Management record lifecycle and append-only workflow history. For inventory_transfer, dispatch the specialised receive command and suppress the generic duplicate transition event.
- Handler / route : `transition_management_record`.
- Champs du contrat : record_id, org_id, site_id, workstation_id, record_type, from_status, to_status, reason, expected_version, metadata_json_delta, transitioned_at.
- Dépendances : record exists and belongs to org/site; transition allowed by record-type state machine; special composite dependencies for purchase receipt or inventory transfer are included
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : OPTIMISTIC_VERSIONED_APPEND; transition event append-only; aggregate revision checked
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

### OBX-055 — inventory_valuation.updated

- Source : ligne 3334, `saveInventoryValuation`, agrégat `inventory_valuation`, expression `"inventory_valuation.updated"`.
- Classe : **REMOTE_MUTATION** ; disposition : `SEND_AS_CANONICAL_MUTATION`.
- Source de vérité : Inventory valuation record distinct from item master and movement ledger.
- Handler / route : `upsert_inventory_valuation`.
- Champs du contrat : valuation_id, org_id, site_id, inventory_item_id, unit_cost_xaf, selling_price_xaf, updated_at.
- Dépendances : inventory item exists same org/site
- Idempotence : Stable event_id UUID + org_id; same event_id/same canonical payload returns original receipt; same event_id/different payload is rejected and audited.
- Conflits : VERSIONED_ENTITY; valuation revision check
- Reprise : Network/timeouts/429/5xx: exponential backoff with jitter, same event_id. 4xx validation/scope: terminal rejected. Missing parent: blocked_dependency; keep row.
- Tests de sortie : valid mutation; wrong organisation/site/workstation/role; same event duplicate idempotence; same event ID with divergent payload rejected; missing parent dependency blocked; offline retry preserves event ID and ordering; crash/restart does not lose or double-apply.

## Contrôle de complétude

- Le script `scripts/naxa-services/verify-outbox-registry.mjs` extrait les appels réels au helper `enqueue()` de `LocalErpStore.kt` et compare les triples méthode/agrégat/expression action au registre.
- Il échoue si un appel manque, si une ligne apparaît deux fois, si un événement nouveau n'est pas qualifié, si un contrat de mutation est incomplet, si les miroirs/helpers directs ne correspondent plus aux API Android, ou si la liste du coordinateur borné diverge.
- La liste `current_coordinator_supported_action_codes` dans le JSON est recalculée contre les 11 actions réellement déclarées par `SupplierSyncCoordinator.kt`.

## Limite de portée (non bloquante pour N1)

Ce registre clôt **l'inventaire et la qualification N1**. Il ne prétend pas que tous les handlers N2, les coordinateurs Android N3, la parité Web N4 ou les intégrations N6 sont déjà implémentés. Les handlers marqués `CONTRACT_DEFINED_HANDLER_NOT_YET_IMPLEMENTED` demeurent explicitement attribués à leur gate de réalisation, sans extension du périmètre de N1.


## Observations techniques du transport source (à préserver pour N2/N3)

- `LocalOutboxEvent` conserve un identifiant d'événement, organisation, agrégat, action, payload, séquence locale, date, version et états/reprises ; la ligne ne porte pas directement un `actor_member_id` ni un `device_id`. Le serveur doit tirer l'acteur et l'installation depuis la session authentifiée.
- `nextOutboxSequence(orgId)` calcule la séquence dans la base Room locale pour l'organisation. Le contrat de transport doit associer la séquence à l'installation enregistrée côté serveur et empêcher les doublons par appareil.
- `loyalty_program.updated` est une mutation à portée organisation avec `site_id=null`. Le coordinateur borné exige aujourd'hui un site non vide et ne la transporte pas ; cette limite est consignée, sans la transformer en faux statut vert de synchronisation.
- La qualification N1 porte sur 55/55 call sites et leurs décisions de routage. Elle n'affirme pas que les 44 mutations indépendantes (11 supportées actuellement + 33 contrats non encore implémentés après ajout de la réception de transfert) sont toutes déployées.
