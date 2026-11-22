package cm.naxa.naxaservices

import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthApiException
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalOutboxEvent
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlin.random.Random
import java.util.UUID
import org.json.JSONObject

data class SupplierSyncSummary(
    val applied: Int,
    val retried: Int,
    val blocked: Int,
    val rejected: Int,
    val remaining: Int
)

/**
 * Shared transport for all registry-declared remote ERP mutations (92 action codes).
 * Every event must still pass a typed snapshot, scope and version gate before transmission;
 * incomplete payloads remain blocked at the head of the device sequence. WorkManager uses
 * an explicitly remembered Auth session only. Runtime synchronization remains feature-flagged
 * off by default until the dedicated Famille NAXA project is configured.
 */
object SupplierSyncCoordinator {
    private const val EXISTING_NAXA_PROJECT_REF = "ykgjfindlgseegmznaog"
    private val supportedActions = setOf(
        "supplier.saved",
        "inventory_item.created",
        "inventory_item.imported",
        "inventory_item.import_updated",
        "inventory_item.supplier_whatsapp_updated",
        "inventory_movement.created",
        "inventory_movement.import_initial",
        "inventory_movement.import_adjustment",
        "purchase.ordered",
        "purchase.receipt.confirmed",
        "supplier.payment.recorded",
        "recurring_charge.saved",
        "recurring_charge.payment_recorded",
        "recurring_charge.deactivated",
        "loyalty_program.updated",
        "loyalty_activity.recorded",
        "loyalty_reward.redeemed",
        "pressing_order.created",
        "pressing_order.status_changed:in_progress",
        "pressing_order.status_changed:ready",
        "pressing_order.status_changed:picked_up",
        "appointment.created",
        "appointment.status_changed",
        "appointment.rescheduled",
        "appointment.created_from_waitlist",
        "cash_session.opened",
        "cash_session.closed",
        "sale.created",
        "sale.mobile_money_cancelled",
        "expense.created",
        "service.created",
        "service.updated",
        "service.configuration_updated",
        "customer.created",
        "customer.updated",
        "customer_followup.created",
        "customer_followup.completed",
        "support_request.created",
        "inventory_valuation.imported",
        "inventory_valuation.import_updated",
        "inventory_valuation.updated",
        "staff_clock_in.recorded",
        "staff_break_start.recorded",
        "staff_break_end.recorded",
        "staff_clock_out.recorded",
        "inventory_transfer.requested",
        "inventory_transfer.received_at_destination",
        "inventory_transfer.status_changed",
        "quote.created",
        "invoice.created",
        "credit_note.created",
        "refund_due.created",
        "customer_receivable.created",
        "purchase.created",
        "supplier.created",
        "tax_estimate.created",
        "business_goal.created",
        "subscription_request.created",
        "support_chat.created",
        "work_order.created",
        "repair_order.created",
        "service_order.created",
        "appointment_waitlist.created",
        "staff_clock_in.created",
        "staff_clock_out.created",
        "staff_break_start.created",
        "staff_break_end.created",
        "staff_commission.created",
        "staff_advance.created",
        "staff_bonus.created",
        "quote.status_changed",
        "invoice.status_changed",
        "credit_note.status_changed",
        "refund_due.status_changed",
        "customer_receivable.status_changed",
        "purchase.status_changed",
        "supplier.status_changed",
        "tax_estimate.status_changed",
        "business_goal.status_changed",
        "subscription_request.status_changed",
        "support_chat.status_changed",
        "work_order.status_changed",
        "repair_order.status_changed",
        "service_order.status_changed",
        "appointment_waitlist.status_changed",
        "staff_clock_in.status_changed",
        "staff_clock_out.status_changed",
        "staff_break_start.status_changed",
        "staff_break_end.status_changed",
        "staff_commission.status_changed",
        "staff_advance.status_changed",
        "staff_bonus.status_changed"
    )
    private val organizationScopedActions = setOf("loyalty_program.updated")
    private val siteOptionalActions = setOf("support_request.created")
    private val versionedActions = setOf(
        "pressing_order.status_changed:in_progress",
        "pressing_order.status_changed:ready",
        "pressing_order.status_changed:picked_up",
        "appointment.status_changed","appointment.rescheduled",
        "customer.updated","service.updated","service.configuration_updated",
        "inventory_transfer.received_at_destination",
        "quote.status_changed",
        "invoice.status_changed",
        "credit_note.status_changed",
        "refund_due.status_changed",
        "customer_receivable.status_changed",
        "purchase.status_changed",
        "supplier.status_changed",
        "tax_estimate.status_changed",
        "business_goal.status_changed",
        "subscription_request.status_changed",
        "support_chat.status_changed",
        "work_order.status_changed",
        "repair_order.status_changed",
        "service_order.status_changed",
        "appointment_waitlist.status_changed",
        "staff_clock_in.status_changed",
        "staff_clock_out.status_changed",
        "staff_break_start.status_changed",
        "staff_break_end.status_changed",
        "staff_commission.status_changed",
        "staff_advance.status_changed",
        "staff_bonus.status_changed"
    )

    fun isConfigured(): Boolean {
        val configuredRef = BuildConfig.SUPABASE_PROJECT_REF.trim()
        val familyRef = BuildConfig.FAMILY_SUPABASE_PROJECT_REF.trim()
        val endpointRef = Regex("^https://([a-z0-9]+)\\.supabase\\.co/functions/v1/naxa-services-accounting/?$")
            .matchEntire(BuildConfig.ACCOUNTING_FUNCTION_URL.trim())
            ?.groupValues?.getOrNull(1)
        return BuildConfig.SUPPLIER_SYNC_ENABLED &&
            BuildConfig.SUPABASE_ANON_KEY.isNotBlank() &&
            configuredRef.isNotBlank() &&
            configuredRef == familyRef &&
            endpointRef == familyRef &&
            familyRef != EXISTING_NAXA_PROJECT_REF
    }

    private val syncMutex = Mutex()

    internal suspend fun <T> withSyncLock(block: suspend () -> T): T {
        syncMutex.lock()
        return try {
            block()
        } finally {
            syncMutex.unlock()
        }
    }

    suspend fun syncPending(
        repository: NaxaServicesLocalRepository,
        api: AuthApi,
        session: AuthSession
    ): SupplierSyncSummary = withSyncLock {
        syncPendingLocked(repository, api, session)
    }

    private suspend fun syncPendingLocked(
        repository: NaxaServicesLocalRepository,
        api: AuthApi,
        session: AuthSession
    ): SupplierSyncSummary {
        require(session.account.organizationId.isNotBlank()) { "Organisation active manquante." }
        check(isConfigured()) {
            "Synchronisation bloquée : configure une passerelle Famille NAXA dédiée, différente du projet NAXA historique."
        }

        val dao = repository.dao
        val orgId = session.account.organizationId
        val events = dao.loadRetryableOutboxEvents(orgId, 250)
            .sortedBy { it.deviceSequence }
        var applied = 0
        var retried = 0
        var blocked = 0
        var rejected = 0

        for (event in events) {
            if (isRetryDelayPending(event, System.currentTimeMillis())) {
                retried++
                break
            }
            if (event.actionCode !in supportedActions) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "SYNC_ACTION_NOT_YET_SUPPORTED"
                )
                blocked++
                break
            }
            val payload = runCatching { JSONObject(event.payloadJson) }.getOrNull()
            if (payload == null || !hasRequiredSnapshot(event, payload)) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "OUTBOX_SNAPSHOT_OR_VERSION_NOT_READY"
                )
                blocked++
                break
            }
            if (payload.optString("org_id") != orgId) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "rejected", System.currentTimeMillis(), null,
                    "OUTBOX_ORGANIZATION_SCOPE_MISMATCH"
                )
                rejected++
                break
            }
            val eventSiteId = payload.optString("site_id").takeUnless { it.isBlank() || it == "null" }
            val organizationScoped = event.actionCode in organizationScopedActions
            val siteOptional = event.actionCode in siteOptionalActions
            if (
                (organizationScoped && eventSiteId != null) ||
                (!organizationScoped && !siteOptional && eventSiteId == null) ||
                (eventSiteId != null && eventSiteId !in session.account.activeSiteIds)
            ) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "ACTIVE_MEMBER_SITE_SCOPE_NOT_AVAILABLE"
                )
                blocked++
                break
            }

            if (session.deviceId.isBlank()) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "REGISTERED_DEVICE_ID_REQUIRED"
                )
                blocked++
                break
            }

            if (event.actionCode == "purchase.ordered" && hasStockLineWithoutRemoteMapping(payload, dao, orgId)) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "STOCK_LINE_SERVER_MAPPING_REQUIRED"
                )
                blocked++
                break
            }
            val siteId = eventSiteId
            val workstationId = payload.optString("workstation_id").takeIf { it.isNotBlank() && it != "null" }
            val envelope = JSONObject()
                .put("event_id", event.eventId)
                .put("device_id", session.deviceId)
                .put("device_sequence", event.deviceSequence)
                .put("org_id", orgId)
                .put("site_id", siteId)
                .put("workstation_id", workstationId)
                .put("aggregate_type", event.aggregateType)
                .put("aggregate_id", event.aggregateId)
                .put("action_code", event.actionCode)
                .put("payload", payload)

            try {
                val response = api.accountingRequest(
                    session.accessToken,
                    JSONObject()
                        .put("action", "apply_sync_event")
                        .put("app_code", "naxa-services")
                        .put("event", envelope)
                )
                if (!response.optBoolean("ok", false)) {
                    throw IllegalStateException("ACCOUNTING_RESPONSE_NOT_CONFIRMED")
                }
                val receipt = response.optJSONObject("result")
                    ?: throw IllegalStateException("SYNC_RECEIPT_MISSING")
                val receiptHash = receipt.optString("payload_sha256")
                if (
                    receipt.optString("status") != "applied" ||
                    receipt.optString("event_id") != event.eventId ||
                    receipt.optString("action_code") != event.actionCode ||
                    receipt.optString("aggregate_type") != event.aggregateType ||
                    receipt.optString("aggregate_id") != event.aggregateId ||
                    !Regex("^[a-f0-9]{64}$", RegexOption.IGNORE_CASE).matches(receiptHash)
                ) {
                    throw IllegalStateException("SYNC_RECEIPT_MISMATCH")
                }
                val result = receipt.optJSONObject("result") ?: JSONObject()
                val remoteId = when (event.actionCode) {
                    "supplier.saved" -> result.optString("supplier_id")
                    "inventory_item.created",
                    "inventory_item.imported",
                    "inventory_item.import_updated",
                    "inventory_item.supplier_whatsapp_updated" -> result.optString("inventory_item_id")
                    "inventory_movement.created",
                    "inventory_movement.import_initial",
                    "inventory_movement.import_adjustment" -> result.optString("movement_id")
                    "purchase.ordered" -> result.optString("purchase_id")
                    "purchase.receipt.confirmed" -> result.optString("receipt_id").ifBlank { payload.optString("receipt_id") }
                    "supplier.payment.recorded" -> result.optString("payment_id").ifBlank { payload.optString("payment_id") }
                    else -> ""
                }.takeIf { it.isNotBlank() && it != "null" } ?: event.aggregateId
                val updated = dao.markOutboxEventSynced(event.eventId, orgId, remoteId)
                if (updated == 0) throw IllegalStateException("OUTBOX_STATE_UPDATE_FAILED")
                applied++
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                val status = (failure as? AuthApiException)?.statusCode
                val remoteCode = failure.message.orEmpty().uppercase()
                val dependencyBlocked = remoteCode.contains("DEPENDENCY") ||
                    remoteCode.contains("NOT_FOUND") ||
                    remoteCode.contains("NOT_AVAILABLE") ||
                    remoteCode.contains("NOT_READY")
                val transient = status == null || status == 401 || status == 429 || status >= 500
                val attempts = event.attemptCount + 1
                val baseDelay = (30_000L * (1L shl attempts.coerceAtMost(6))).coerceAtMost(30L * 60L * 1000L)
                val jitter = if (baseDelay > 4_000L) Random.nextLong(baseDelay / 4L + 1L) else 0L
                val delay = baseDelay + jitter
                val now = System.currentTimeMillis()
                val state = when {
                    transient -> "retry_wait"
                    dependencyBlocked -> "blocked_dependency"
                    else -> "rejected"
                }
                val errorCode = when {
                    status == 401 -> "AUTHENTICATION_REQUIRED"
                    status == 403 -> "REMOTE_SCOPE_FORBIDDEN"
                    dependencyBlocked -> remoteCode.take(100).ifBlank { "REMOTE_DEPENDENCY_NOT_READY" }
                    status == 422 -> "REMOTE_VALIDATION_FAILED"
                    transient -> "REMOTE_TEMPORARY_FAILURE"
                    else -> "REMOTE_REQUEST_REJECTED"
                }
                dao.updateOutboxAttempt(
                    event.eventId, orgId, state, now,
                    if (transient) now + delay else null,
                    errorCode
                )
                if (transient) retried++ else if (dependencyBlocked) blocked++ else rejected++
                break
            }
        }
        val remaining = dao.observePendingOutboxCount(orgId).first()
        return SupplierSyncSummary(applied, retried, blocked, rejected, remaining)
    }

    private suspend fun hasStockLineWithoutRemoteMapping(
        payload: JSONObject,
        dao: cm.naxa.naxaservices.data.NaxaServicesDao,
        orgId: String
    ): Boolean {
        val lines = payload.optJSONArray("lines") ?: return true
        for (index in 0 until lines.length()) {
            val line = lines.optJSONObject(index) ?: return true
            if (line.optString("item_type") != "stock") continue
            val itemId = line.optString("inventory_item_id")
            if (itemId.isBlank() || dao.countSyncedInventoryItemMapping(orgId, itemId) == 0) return true
        }
        return false
    }

    internal fun isRetryDelayPending(event: LocalOutboxEvent, nowEpochMs: Long): Boolean =
        event.nextAttemptAtEpochMs?.let { it > nowEpochMs } == true

    internal fun hasRequiredSnapshot(event: LocalOutboxEvent, payload: JSONObject): Boolean {
        val action = event.actionCode
        val site = payload.optString("site_id").takeUnless { it.isBlank() || it == "null" }
        val common = payload.optString("org_id").isNotBlank() &&
            (action in organizationScopedActions && site == null ||
                action in siteOptionalActions ||
                action !in organizationScopedActions && action !in siteOptionalActions && site != null)
        if (!common || event.schemaVersion < 1) return false

        val aggregateField = when {
            action == "purchase.receipt.confirmed" -> "idempotency_key"
            action == "supplier.payment.recorded" -> "idempotency_key"
            action == "supplier.saved" -> "supplier_id"
            action.startsWith("inventory_item.") -> "inventory_item_id"
            action.startsWith("inventory_movement.") -> "movement_id"
            action == "purchase.ordered" -> "purchase_id"
            action.startsWith("recurring_charge.") -> "charge_id"
            action == "loyalty_program.updated" -> "program_id"
            action == "loyalty_activity.recorded" -> "activity_event_id"
            action == "loyalty_reward.redeemed" -> "reward_event_id"
            action.startsWith("pressing_order.") -> "order_id"
            action.startsWith("appointment.") && action != "appointment_waitlist.converted" -> "appointment_id"
            action.startsWith("cash_session.") -> "cash_session_id"
            action.startsWith("sale.") -> "sale_id"
            action == "expense.created" -> "expense_id"
            action.startsWith("service.") -> "service_id"
            action.startsWith("customer_followup.") -> "followup_id"
            action == "customer.created" || action == "customer.updated" -> "customer_id"
            action == "support_request.created" -> "request_id"
            action.startsWith("inventory_valuation.") -> "inventory_item_id"
            action.startsWith("staff_") && action.endsWith(".recorded") -> "time_event_id"
            action.startsWith("inventory_transfer.") -> if (action == "inventory_transfer.status_changed") "record_id" else "transfer_id"
            action.endsWith(".created") || action.endsWith(".status_changed") -> "record_id"
            else -> return false
        }
        if (payload.optString(aggregateField) != event.aggregateId) return false
        if (action in versionedActions && payload.optInt("expected_version", -1) < 1) return false

        return when (action) {
            "supplier.saved" -> payload.optString("name").isNotBlank()
            "inventory_item.created","inventory_item.imported","inventory_item.import_updated","inventory_item.supplier_whatsapp_updated" ->
                payload.optString("name").isNotBlank() && payload.optString("unit").isNotBlank() &&
                    payload.optDouble("reorder_level", -1.0) >= 0.0
            "inventory_movement.created","inventory_movement.import_initial","inventory_movement.import_adjustment" ->
                payload.optString("inventory_item_id").isNotBlank() &&
                    payload.optString("movement_type") in setOf("in","consumption","loss","adjustment") &&
                    payload.optDouble("quantity_delta", 0.0) != 0.0 && payload.optString("reason").isNotBlank()
            "purchase.ordered" -> payload.optString("supplier_id").isNotBlank() &&
                payload.optString("idempotency_key") == event.aggregateId &&
                payload.optJSONArray("lines")?.length()?.let { it > 0 } == true
            "purchase.receipt.confirmed" -> payload.optString("purchase_id").isNotBlank() &&
                payload.optString("line_id").isNotBlank() &&
                payload.optString("idempotency_key") == event.aggregateId &&
                payload.optString("receipt_id") == event.aggregateId &&
                payload.optDouble("quantity", 0.0) > 0.0
            "supplier.payment.recorded" -> payload.optString("purchase_id").isNotBlank() &&
                payload.optString("idempotency_key") == event.aggregateId &&
                payload.optString("payment_id") == event.aggregateId && payload.optLong("amount_xaf", 0L) > 0L
            "recurring_charge.saved" -> payload.optString("name").isNotBlank() &&
                payload.optString("category").isNotBlank() && payload.optLong("amount_xaf", 0L) > 0L &&
                payload.optString("next_due_at").isNotBlank()
            "recurring_charge.payment_recorded" -> payload.optLong("amount_xaf", 0L) > 0L &&
                payload.optString("payment_id").isNotBlank()
            "recurring_charge.deactivated" -> payload.optString("deactivated_at").isNotBlank()
            "loyalty_program.updated" -> payload.optString("name").isNotBlank() &&
                payload.optString("metric_code").isNotBlank() && payload.optLong("target_value",0L) > 0L
            "loyalty_activity.recorded" -> payload.optString("program_id").isNotBlank() &&
                payload.optString("customer_id").isNotBlank() && payload.optLong("amount_xaf",-1L) >= 0L
            "loyalty_reward.redeemed" -> payload.optString("program_id").isNotBlank() &&
                payload.optString("customer_id").isNotBlank() && payload.optString("redemption_status") == "redeemed"
            "pressing_order.created" -> payload.optString("ticket_number").isNotBlank() &&
                payload.optString("customer_name").isNotBlank() && payload.optLong("total_xaf",0L) > 0L &&
                payload.optString("status").isNotBlank() && payload.optString("created_at").isNotBlank()
            "pressing_order.status_changed:in_progress","pressing_order.status_changed:ready","pressing_order.status_changed:picked_up" ->
                payload.optString("from_status").isNotBlank() && payload.optString("reason").isNotBlank()
            "appointment.created" -> payload.optString("customer_reference_or_name").isNotBlank() &&
                payload.optString("service_reference_or_name").isNotBlank() &&
                payload.optString("assigned_member_id").isNotBlank() &&
                payload.optString("starts_at").isNotBlank() && payload.optString("ends_at").isNotBlank()
            "appointment.status_changed" -> payload.optString("from_status").isNotBlank() &&
                payload.optString("to_status").isNotBlank() && payload.optString("reason").isNotBlank()
            "appointment.rescheduled" -> payload.optString("starts_at").isNotBlank() &&
                payload.optString("ends_at").isNotBlank() && payload.optString("assigned_member_id").isNotBlank() &&
                payload.optString("reason").isNotBlank()
            "appointment.created_from_waitlist" -> payload.optString("waitlist_record_id").isNotBlank() &&
                payload.optString("starts_at").isNotBlank() && payload.optInt("duration_minutes",0) in 5..600 &&
                payload.optString("assigned_member_id").isNotBlank() && payload.optString("reason").isNotBlank()
            "cash_session.opened" -> payload.optString("register_id").isNotBlank() &&
                payload.optString("register_name").isNotBlank() && payload.optString("opened_at").isNotBlank()
            "cash_session.closed" -> payload.optString("closed_at").isNotBlank() &&
                payload.optLong("counted_close_xaf",-1L) >= 0L
            "sale.created" -> payload.optString("cash_session_id").isNotBlank() &&
                payload.optString("sale_number").isNotBlank() && payload.optLong("total_xaf",0L) > 0L &&
                payload.optString("payment_method") in setOf("cash","mobile_money") &&
                payload.optString("status") in setOf("confirmed","pending")
            "sale.mobile_money_cancelled" -> payload.optString("expected_status") == "pending" &&
                payload.optString("reason").isNotBlank() && payload.optString("cancelled_at").isNotBlank()
            "expense.created" -> payload.optString("category").isNotBlank() &&
                payload.optString("description").isNotBlank() && payload.optLong("amount_xaf",0L) > 0L &&
                payload.optString("idempotency_key").isNotBlank()
            "service.created" -> payload.optString("code").isNotBlank() &&
                payload.optString("activity").isNotBlank() && payload.optString("name").isNotBlank() &&
                payload.optJSONArray("provider_member_ids") != null &&
                payload.optJSONArray("required_workstation_kinds") != null
            "service.updated" -> payload.optString("code").isNotBlank() && payload.optString("name").isNotBlank() &&
                payload.optLong("price_xaf",-1L) >= 0L
            "service.configuration_updated" -> payload.optString("category").isNotBlank() &&
                payload.optJSONArray("provider_member_ids") != null &&
                payload.optJSONArray("required_workstation_kinds") != null
            "customer.created","customer.updated" -> payload.optString("display_name").isNotBlank() &&
                payload.optString("phone_contact").length <= 32 &&
                (payload.isNull("latitude") == payload.isNull("longitude"))
            "customer_followup.created" -> payload.optString("customer_id").isNotBlank() &&
                payload.optString("title").isNotBlank() && payload.optString("next_due_at").isNotBlank()
            "customer_followup.completed" -> payload.optString("completed_at").isNotBlank()
            "support_request.created" -> payload.optString("subject").isNotBlank() &&
                payload.optString("description").length >= 10 && payload.optString("priority") in setOf("low","normal","high")
            "inventory_valuation.imported","inventory_valuation.import_updated","inventory_valuation.updated" ->
                payload.optString("valuation_id").isNotBlank() &&
                payload.optLong("unit_cost_xaf",-1L) >= 0L && payload.optLong("selling_price_xaf",-1L) >= 0L &&
                payload.optInt("expected_version",-1) >= 0
            "staff_clock_in.recorded","staff_break_start.recorded","staff_break_end.recorded","staff_clock_out.recorded" ->
                runCatching { UUID.fromString(payload.optString("staff_member_id")) }.isSuccess &&
                payload.optString("staff_name_snapshot").length in 2..120 &&
                payload.optString("occurred_at").isNotBlank()
            "inventory_transfer.requested" -> payload.optString("source_site_id").isNotBlank() &&
                payload.optString("destination_site_id").isNotBlank() && payload.optString("inventory_item_id").isNotBlank() &&
                payload.optString("sku_snapshot").isNotBlank() && payload.optDouble("quantity",0.0) > 0.0
            "inventory_transfer.received_at_destination" -> payload.optString("source_site_id").isNotBlank() &&
                payload.optString("destination_site_id").isNotBlank() && payload.optString("inventory_item_id").isNotBlank() &&
                payload.optString("sku_snapshot").isNotBlank() && payload.optDouble("quantity",0.0) > 0.0 &&
                payload.optString("reason").isNotBlank()
            "inventory_transfer.status_changed" -> payload.optString("from_status").isNotBlank() &&
                payload.optString("to_status").isNotBlank() && payload.optString("reason").isNotBlank()
            else -> if (action.endsWith(".created")) {
                payload.optString("record_type").isNotBlank() && payload.optString("reference").isNotBlank() &&
                    payload.optString("title").isNotBlank() && payload.optString("status").isNotBlank()
            } else if (action.endsWith(".status_changed")) {
                payload.optString("record_type").isNotBlank() && payload.optString("from_status").isNotBlank() &&
                    payload.optString("to_status").isNotBlank() && payload.optString("reason").isNotBlank()
            } else false
        }
    }
}
