package cm.naxa.naxaservices

import cm.naxa.naxaservices.data.LocalOutboxEvent
import java.util.UUID
import org.json.JSONObject
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Test

class SupplierSyncCoordinatorTest {
    private val orgId = "org-1"
    private val siteId = "site-1"

    private fun event(action: String, aggregateType: String, aggregateId: String) = LocalOutboxEvent(
        eventId = UUID.randomUUID().toString(),
        orgId = orgId,
        aggregateType = aggregateType,
        aggregateId = aggregateId,
        actionCode = action,
        payloadJson = "{}",
        deviceSequence = 1L,
        createdAtEpochMs = 1L
    )

    @Test
    fun staffTimeSnapshotRequiresStableMemberUuidAndIdentitySnapshot() {
        val timeEventId = UUID.randomUUID().toString()
        val staffMemberId = UUID.randomUUID().toString()
        val item = event("staff_clock_in.recorded", "staff_clock_in", timeEventId)
        val missingMember = JSONObject()
            .put("org_id", orgId)
            .put("site_id", siteId)
            .put("time_event_id", timeEventId)
            .put("staff_name_snapshot", "Collaborateur")
            .put("occurred_at", "2026-11-22T08:00:00Z")
        assertFalse(SupplierSyncCoordinator.hasRequiredSnapshot(item, missingMember))

        missingMember.put("staff_member_id", staffMemberId)
        assertTrue(SupplierSyncCoordinator.hasRequiredSnapshot(item, missingMember))
    }

    @Test
    fun valuationCreationAllowsVersionZeroButUnknownUpdateVersionIsBlocked() {
        val valuationId = UUID.randomUUID().toString()
        val itemId = UUID.randomUUID().toString()
        val event = event("inventory_valuation.imported", "inventory_valuation", itemId)
        val payload = JSONObject()
            .put("org_id", orgId)
            .put("site_id", siteId)
            .put("valuation_id", valuationId)
            .put("inventory_item_id", itemId)
            .put("unit_cost_xaf", 1000)
            .put("selling_price_xaf", 1500)
            .put("expected_version", 0)
        assertTrue(SupplierSyncCoordinator.hasRequiredSnapshot(event, payload))

        val update = event.copy(actionCode = "inventory_valuation.import_updated")
        payload.put("expected_version", -1)
        assertFalse(SupplierSyncCoordinator.hasRequiredSnapshot(update, payload))
    }

    @Test
    fun mutableMasterDataRequiresPositiveOptimisticVersion() {
        val appointmentId = UUID.randomUUID().toString()
        val item = event("appointment.status_changed", "appointment", appointmentId)
        val payload = JSONObject()
            .put("org_id", orgId)
            .put("site_id", siteId)
            .put("appointment_id", appointmentId)
            .put("from_status", "booked")
            .put("to_status", "cancelled")
            .put("reason", "Annulation demandée")
            .put("expected_version", 0)
        assertFalse(SupplierSyncCoordinator.hasRequiredSnapshot(item, payload))

        payload.put("expected_version", 1)
        assertTrue(SupplierSyncCoordinator.hasRequiredSnapshot(item, payload))
    }


    @Test
    fun manualAndWorkerSyncCallsShareOneExclusiveLock() = runBlocking {
        val active = java.util.concurrent.atomic.AtomicInteger(0)
        val maximum = java.util.concurrent.atomic.AtomicInteger(0)
        kotlinx.coroutines.coroutineScope {
            repeat(2) {
                launch {
                    SupplierSyncCoordinator.withSyncLock {
                        val current = active.incrementAndGet()
                        maximum.updateAndGet { previous -> maxOf(previous, current) }
                        delay(40)
                        active.decrementAndGet()
                    }
                }
            }
        }
        assertEquals(1, maximum.get())
        assertEquals(0, active.get())
    }

    @Test
    fun cancellationIsPropagatedThroughSharedSyncLock() = runBlocking {
        var propagated = false
        try {
            SupplierSyncCoordinator.withSyncLock {
                throw kotlinx.coroutines.CancellationException("test cancellation")
            }
        } catch (_: kotlinx.coroutines.CancellationException) {
            propagated = true
        }
        assertTrue(propagated)
    }

    @Test
    fun unknownActionCannotBeMarkedAsAValidSnapshot() {
        val id = UUID.randomUUID().toString()
        val item = event("unknown.mutation", "unknown", id)
        val payload = JSONObject()
            .put("org_id", orgId)
            .put("site_id", siteId)
            .put("record_id", id)
        assertFalse(SupplierSyncCoordinator.hasRequiredSnapshot(item, payload))
    }
}
