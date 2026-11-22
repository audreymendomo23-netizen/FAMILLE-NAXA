package cm.naxa.naxaservices

import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthApiException
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalOutboxEvent
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.flow.first
import kotlin.random.Random
import org.json.JSONObject

data class SupplierSyncSummary(
    val applied: Int,
    val retried: Int,
    val blocked: Int,
    val rejected: Int,
    val remaining: Int
)

/**
 * Shared transport for the currently snapshot-complete inventory/supplier event slice.
 * WorkManager supplies automatic retries when an explicitly remembered session is available;
 * the dashboard action remains available while a session is active. This is not yet universal:
 * the other outbox call sites stay queued until their full versioned snapshots are implemented.
 * The build flag is false by default.
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
        "supplier.payment.recorded"
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

    suspend fun syncPending(
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
        val events = dao.loadRetryableOutboxEvents(orgId, supportedActions.toList(), System.currentTimeMillis(), 250)
            .filter { it.actionCode in supportedActions }
            .sortedBy { it.deviceSequence }
        var applied = 0
        var retried = 0
        var blocked = 0
        var rejected = 0

        for (event in events) {
            val payload = runCatching { JSONObject(event.payloadJson) }.getOrNull()
            if (payload == null || !hasRequiredSnapshot(event, payload)) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "rejected", System.currentTimeMillis(), null,
                    "OUTBOX_SNAPSHOT_INCOMPLETE"
                )
                rejected++
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
            val eventSiteId = payload.optString("site_id")
            if (eventSiteId.isBlank() || eventSiteId !in session.account.activeSiteIds) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "ACTIVE_MEMBER_SITE_SCOPE_NOT_AVAILABLE"
                )
                blocked++
                continue
            }

            if (session.deviceId.isBlank()) {
                dao.updateOutboxAttempt(
                    event.eventId, orgId, "blocked_dependency", System.currentTimeMillis(), null,
                    "REGISTERED_DEVICE_ID_REQUIRED"
                )
                blocked++
                continue
            }

            val siteId = payload.optString("site_id").takeIf { it.isNotBlank() && it != "null" }
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
                    "purchase.receipt.confirmed" -> result.optString("receipt_id")
                    "supplier.payment.recorded" -> result.optString("payment_id")
                    else -> ""
                }.takeIf { it.isNotBlank() && it != "null" } ?: event.aggregateId
                val updated = dao.markOutboxEventSynced(event.eventId, orgId, remoteId)
                if (updated == 0) throw IllegalStateException("OUTBOX_STATE_UPDATE_FAILED")
                applied++
            } catch (failure: Exception) {
                val status = (failure as? AuthApiException)?.statusCode
                val transient = status == null || status == 429 || status >= 500
                val attempts = event.attemptCount + 1
                val baseDelay = (30_000L * (1L shl attempts.coerceAtMost(6))).coerceAtMost(30L * 60L * 1000L)
                val jitter = if (baseDelay > 4_000L) Random.nextLong(baseDelay / 4L + 1L) else 0L
                val delay = baseDelay + jitter
                val now = System.currentTimeMillis()
                val state = if (transient) "retry_wait" else "rejected"
                val errorCode = when {
                    status == 401 -> "AUTHENTICATION_REQUIRED"
                    status == 403 -> "REMOTE_SCOPE_FORBIDDEN"
                    status == 422 -> "REMOTE_VALIDATION_FAILED"
                    transient -> "REMOTE_TEMPORARY_FAILURE"
                    else -> "REMOTE_REQUEST_REJECTED"
                }
                dao.updateOutboxAttempt(
                    event.eventId, orgId, state, now,
                    if (transient) now + delay else null,
                    errorCode
                )
                if (transient) retried++ else rejected++
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

    private fun hasRequiredSnapshot(event: LocalOutboxEvent, payload: JSONObject): Boolean {
        val common = payload.optString("org_id").isNotBlank() &&
            payload.optString("site_id").isNotBlank()
        if (!common || event.schemaVersion < 1) return false
        return when (event.actionCode) {
            "supplier.saved" -> payload.optString("supplier_id").isNotBlank() &&
                payload.optString("name").isNotBlank()
            "inventory_item.created",
            "inventory_item.imported",
            "inventory_item.import_updated",
            "inventory_item.supplier_whatsapp_updated" ->
                payload.optString("inventory_item_id") == event.aggregateId &&
                    payload.optString("name").isNotBlank() &&
                    payload.optString("unit").isNotBlank() &&
                    payload.optDouble("reorder_level", -1.0) >= 0.0
            "inventory_movement.created",
            "inventory_movement.import_initial",
            "inventory_movement.import_adjustment" ->
                payload.optString("movement_id") == event.aggregateId &&
                    payload.optString("inventory_item_id").isNotBlank() &&
                    payload.optString("movement_type") in setOf("in", "consumption", "loss", "adjustment") &&
                    payload.optDouble("quantity_delta", 0.0) != 0.0 &&
                    payload.optString("reason").isNotBlank()
            "purchase.ordered" -> payload.optString("purchase_id").isNotBlank() &&
                payload.optString("supplier_id").isNotBlank() &&
                payload.optJSONArray("lines")?.length()?.let { it > 0 } == true
            "purchase.receipt.confirmed" -> payload.optString("purchase_id").isNotBlank() &&
                payload.optString("line_id").isNotBlank() &&
                payload.optString("idempotency_key").isNotBlank() &&
                payload.optDouble("quantity", 0.0) > 0.0
            "supplier.payment.recorded" -> payload.optString("purchase_id").isNotBlank() &&
                payload.optString("idempotency_key").isNotBlank() &&
                payload.optLong("amount_xaf", 0L) > 0L
            else -> false
        }
    }
}
