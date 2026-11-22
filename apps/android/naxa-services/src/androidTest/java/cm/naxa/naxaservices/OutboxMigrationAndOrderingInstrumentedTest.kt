package cm.naxa.naxaservices

import android.content.Context
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import cm.naxa.naxaservices.data.LocalOutboxEvent
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_13_14
import cm.naxa.naxaservices.data.NS_SERVICES_MIGRATION_15_16
import cm.naxa.naxaservices.data.LocalLoyaltyEvent
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import cm.naxa.naxaservices.data.NsServicesDatabase
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OutboxMigrationAndOrderingInstrumentedTest {
    private val context: Context
        get() = ApplicationProvider.getApplicationContext()


    @Test
    fun roomMigration15To16AddsPendingApplicationStateWithoutLosingRemoteChange() {
        val databaseName = "remote-change-migration-${UUID.randomUUID()}.db"
        val configuration = SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(databaseName)
            .callback(object : SupportSQLiteOpenHelper.Callback(15) {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    db.execSQL(
                        "CREATE TABLE local_remote_changes (" +
                            "eventId TEXT NOT NULL PRIMARY KEY, orgId TEXT NOT NULL, changeCursor INTEGER NOT NULL, " +
                            "sourceDeviceId TEXT NOT NULL, siteId TEXT, workstationId TEXT, " +
                            "aggregateType TEXT NOT NULL, aggregateId TEXT NOT NULL, actionCode TEXT NOT NULL, " +
                            "aggregateVersion INTEGER NOT NULL, projectionJson TEXT NOT NULL, recordedAt TEXT NOT NULL, " +
                            "receivedAtEpochMs INTEGER NOT NULL)"
                    )
                    db.execSQL(
                        "INSERT INTO local_remote_changes VALUES (" +
                            "'aaaaaaaa-0000-4000-8000-000000000001','org-1',7," +
                            "'bbbbbbbb-0000-4000-8000-000000000002','site-1',NULL," +
                            "'supplier','supplier-1','supplier.saved',1,'{}','2026-11-22T10:00:00Z',100)"
                    )
                }
                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
            })
            .build()
        val helper = FrameworkSQLiteOpenHelperFactory().create(configuration)
        try {
            val db = helper.writableDatabase
            NS_SERVICES_MIGRATION_15_16.migrate(db)
            val cursor = db.query(
                "SELECT applicationStatus,lastErrorCode,changeCursor FROM local_remote_changes WHERE eventId='aaaaaaaa-0000-4000-8000-000000000001'"
            )
            cursor.use {
                assertTrue(it.moveToFirst())
                assertEquals("pending", it.getString(0))
                assertTrue(it.isNull(1))
                assertEquals(7L, it.getLong(2))
            }
        } finally {
            helper.close()
            context.deleteDatabase(databaseName)
        }
    }

    @Test
    fun roomMigration13To14OnlyReclassifiesUnsentDerivedEvents() {
        val databaseName = "outbox-migration-${UUID.randomUUID()}.db"
        val configuration = SupportSQLiteOpenHelper.Configuration.builder(context)
            .name(databaseName)
            .callback(object : SupportSQLiteOpenHelper.Callback(13) {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    db.execSQL(
                        "CREATE TABLE local_outbox_events (" +
                            "eventId TEXT NOT NULL PRIMARY KEY, " +
                            "actionCode TEXT NOT NULL, " +
                            "state TEXT NOT NULL, " +
                            "nextAttemptAtEpochMs INTEGER, " +
                            "lastErrorCode TEXT)"
                    )
                    db.execSQL(
                        "INSERT INTO local_outbox_events VALUES " +
                            "('derived-queued','appointment_waitlist.converted','queued',100,'OLD_RETRY')," +
                            "('derived-blocked','accounting.entry.posted','blocked_dependency',200,'OLD_BLOCK')," +
                            "('remote-pending','supplier.saved','queued',300,'KEEP_RETRY')," +
                            "('derived-synced','inventory_movement.transfer_in','synced',400,'KEEP_SYNCED')"
                    )
                }

                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
            })
            .build()
        val helper = FrameworkSQLiteOpenHelperFactory().create(configuration)
        try {
            val database = helper.writableDatabase
            NS_SERVICES_MIGRATION_13_14.migrate(database)
            val cursor = database.query(
                "SELECT eventId,state,nextAttemptAtEpochMs,lastErrorCode FROM local_outbox_events ORDER BY eventId"
            )
            cursor.use {
                val rows = mutableMapOf<String, List<String?>>()
                while (it.moveToNext()) {
                    val id = it.getString(0)
                    val state = it.getString(1)
                    val nextAttempt = if (it.isNull(2)) null else it.getLong(2).toString()
                    val error = if (it.isNull(3)) null else it.getString(3)
                    rows[id] = listOf(state, nextAttempt, error)
                }
                assertEquals(listOf("not_applicable", null, null), rows["derived-queued"])
                assertEquals(listOf("not_applicable", null, null), rows["derived-blocked"])
                assertEquals(listOf("queued", "300", "KEEP_RETRY"), rows["remote-pending"])
                assertEquals(listOf("synced", "400", "KEEP_SYNCED"), rows["derived-synced"])
            }
        } finally {
            helper.close()
            context.deleteDatabase(databaseName)
        }
    }


    @Test
    fun twoIndependentAndroidInstallationsReplicatePeerMutationsBothDirectionsWithoutEcho() = runBlocking<Unit> {
        val orgId = UUID.randomUUID().toString()
        val siteId = UUID.randomUUID().toString()
        val supplierId = UUID.randomUUID().toString()
        val deviceA = UUID.randomUUID().toString()
        val deviceB = UUID.randomUUID().toString()
        val actorId = UUID.randomUUID().toString()
        val eventA = UUID.randomUUID().toString()
        val eventB = UUID.randomUUID().toString()
        val databaseAName = "peer-device-a-${UUID.randomUUID()}.db"
        val databaseBName = "peer-device-b-${UUID.randomUUID()}.db"
        val databaseA = Room.databaseBuilder(context, NsServicesDatabase::class.java, databaseAName).build()
        val databaseB = Room.databaseBuilder(context, NsServicesDatabase::class.java, databaseBName).build()

        fun page(receiverDeviceId: String, cursor: Long, eventId: String, sourceDeviceId: String, supplierName: String) =
            JSONObject()
                .put("device_id", receiverDeviceId)
                .put("next_cursor", cursor)
                .put("has_more", false)
                .put("changes", JSONArray().put(
                    JSONObject()
                        .put("cursor", cursor)
                        .put("event_id", eventId)
                        .put("source_device_id", sourceDeviceId)
                        .put("site_id", siteId)
                        .put("visible_site_ids", JSONArray().put(siteId))
                        .put("workstation_id", JSONObject.NULL)
                        .put("aggregate_type", "supplier")
                        .put("aggregate_id", supplierId)
                        .put("action_code", "supplier.saved")
                        .put("aggregate_version", cursor)
                        .put("recorded_at", "2026-11-22T14:00:00Z")
                        .put("payload", JSONObject()
                            .put("supplier_id", supplierId)
                            .put("org_id", orgId)
                            .put("site_id", siteId)
                            .put("actor_member_id", actorId)
                            .put("name", supplierName)
                            .put("phone", "")
                            .put("whatsapp", "")
                            .put("email", "")
                            .put("address", "")
                            .put("payment_terms_days", 0)
                            .put("notes", "")
                            .put("active", true)
                        )
                ))

        try {
            val repositoryA = NaxaServicesLocalRepository(databaseA)
            val repositoryB = NaxaServicesLocalRepository(databaseB)

            // Device A publishes; the independent Room database on device B pulls and applies it.
            assertEquals(1, repositoryB.persistRemoteSyncPage(
                orgId, deviceB, page(deviceB, 1L, eventA, deviceA, "Grossiste depuis A"), 100L
            ))
            assertEquals("Grossiste depuis A", repositoryB.dao.findSupplier(supplierId, orgId, siteId)?.name)

            // Device B publishes a later revision; device A independently pulls and applies it.
            val reversePage = page(deviceA, 2L, eventB, deviceB, "Grossiste mis à jour depuis B")
            assertEquals(1, repositoryA.persistRemoteSyncPage(orgId, deviceA, reversePage, 200L))
            assertEquals("Grossiste mis à jour depuis B", repositoryA.dao.findSupplier(supplierId, orgId, siteId)?.name)

            // Lost responses and page replays are safe; remote writes never create a new outbox mutation.
            assertEquals(0, repositoryA.persistRemoteSyncPage(orgId, deviceA, reversePage, 300L))
            assertEquals(0, repositoryA.dao.countOutboxActions(orgId, "supplier", supplierId, listOf("supplier.saved")))
            assertEquals(0, repositoryB.dao.countOutboxActions(orgId, "supplier", supplierId, listOf("supplier.saved")))
            assertEquals(1, repositoryA.dao.countRemoteChanges(orgId))
            assertEquals(1, repositoryB.dao.countRemoteChanges(orgId))
        } finally {
            databaseA.close()
            databaseB.close()
            context.deleteDatabase(databaseAName)
            context.deleteDatabase(databaseBName)
        }
    }

    @Test
    fun remotePeerChangesPersistAtomicallyIdempotentlyAndWithoutOutboxEcho() = runBlocking<Unit> {
        val orgId = "org-${UUID.randomUUID()}"
        val deviceId = "device-${UUID.randomUUID()}"
        val supplierId = "supplier-${UUID.randomUUID()}"
        val eventId = UUID.randomUUID().toString()
        val databaseName = "remote-sync-${UUID.randomUUID()}.db"
        val database = Room.databaseBuilder(context, NsServicesDatabase::class.java, databaseName).build()
        try {
            val repository = NaxaServicesLocalRepository(database)
            val first = JSONObject()
                .put("cursor", 1)
                .put("event_id", eventId)
                .put("source_device_id", "aaaaaaaa-0000-4000-8000-000000000001")
                .put("site_id", "site-1")
                .put("workstation_id", JSONObject.NULL)
                .put("aggregate_type", "supplier")
                .put("aggregate_id", supplierId)
                .put("action_code", "supplier.saved")
                .put("aggregate_version", 1)
                .put("payload", JSONObject()
                    .put("supplier_id", supplierId)
                    .put("org_id", orgId)
                    .put("site_id", "site-1")
                    .put("actor_member_id", "dddddddd-0000-4000-8000-000000000004")
                    .put("name", "Grossiste A"))
                .put("recorded_at", "2026-11-22T10:00:00Z")
            val second = JSONObject()
                .put("cursor", 2)
                .put("event_id", UUID.randomUUID().toString())
                .put("source_device_id", "bbbbbbbb-0000-4000-8000-000000000002")
                .put("site_id", "site-1")
                .put("workstation_id", JSONObject.NULL)
                .put("aggregate_type", "supplier")
                .put("aggregate_id", supplierId)
                .put("action_code", "supplier.saved")
                .put("aggregate_version", 2)
                .put("payload", JSONObject()
                    .put("supplier_id", supplierId)
                    .put("org_id", orgId)
                    .put("site_id", "site-1")
                    .put("actor_member_id", "dddddddd-0000-4000-8000-000000000004")
                    .put("name", "Grossiste A actualisé")
                    .put("phone", "690000000"))
                .put("recorded_at", "2026-11-22T10:01:00Z")
            val changes = JSONArray().put(first).put(second)
            val page = JSONObject()
                .put("device_id", deviceId)
                .put("changes", changes)
                .put("next_cursor", 2)
                .put("has_more", false)

            assertEquals(2, repository.persistRemoteSyncPage(orgId, deviceId, page, 100L))
            assertEquals(0, repository.persistRemoteSyncPage(orgId, deviceId, page, 200L))
            assertEquals(2, repository.dao.countRemoteChanges(orgId))
            assertEquals(2L, repository.dao.findSyncCheckpoint(orgId, deviceId)?.cursor)

            val projection = repository.dao.findRemoteAggregate(orgId, "supplier", supplierId)
            assertEquals("Grossiste A actualisé", JSONObject(projection!!.projectionJson).optString("name"))
            assertEquals("690000000", JSONObject(projection.projectionJson).optString("phone"))
            assertEquals(2L, projection.lastChangeCursor)
            val typedSupplier = repository.dao.findSupplier(supplierId, orgId, "site-1")
            assertEquals("Grossiste A actualisé", typedSupplier?.name)
            assertEquals("applied", repository.dao.findRemoteChange(eventId)?.applicationStatus)

            assertEquals(0, repository.dao.countOutboxActions(
                orgId, "supplier", supplierId, listOf("supplier.saved")
            ))

            val divergent = JSONObject(first.toString())
                .put("cursor", 4)
                .put("payload", JSONObject(first.getJSONObject("payload").toString()).put("name", "Payload divergent"))
            val invalidPage = JSONObject()
                .put("device_id", deviceId)
                .put("changes", JSONArray().put(
                    JSONObject()
                        .put("cursor", 3)
                        .put("event_id", UUID.randomUUID().toString())
                        .put("source_device_id", "cccccccc-0000-4000-8000-000000000003")
                        .put("site_id", "site-1")
                        .put("aggregate_type", "supplier")
                        .put("aggregate_id", supplierId)
                        .put("action_code", "supplier.saved")
                        .put("aggregate_version", 3)
                        .put("payload", JSONObject().put("supplier_id", supplierId).put("name", "Must rollback"))
                        .put("recorded_at", "2026-11-22T10:02:00Z")
                ).put(divergent))
                .put("next_cursor", 4)
                .put("has_more", false)
            var rejected = false
            try {
                repository.persistRemoteSyncPage(orgId, deviceId, invalidPage, 300L)
            } catch (_: IllegalArgumentException) {
                rejected = true
            }
            assertTrue(rejected)
            assertEquals(2, repository.dao.countRemoteChanges(orgId))
            assertEquals(2L, repository.dao.findSyncCheckpoint(orgId, deviceId)?.cursor)
            assertEquals("Grossiste A actualisé",
                JSONObject(repository.dao.findRemoteAggregate(orgId, "supplier", supplierId)!!.projectionJson).optString("name"))
        } finally {
            database.close()
            context.deleteDatabase(databaseName)
        }
    }


    @Test
    fun sourceDeviceReconcilesCanonicalServerRewardIdsWithoutDuplicateLedgerRows() = runBlocking<Unit> {
        val orgId = "org-${UUID.randomUUID()}"
        val siteId = "site-${UUID.randomUUID()}"
        val activityId = UUID.randomUUID().toString()
        val programId = UUID.randomUUID().toString()
        val customerId = UUID.randomUUID().toString()
        val localRewardId = UUID.randomUUID().toString()
        val serverRewardId = UUID.randomUUID().toString()
        val databaseName = "canonical-reward-${UUID.randomUUID()}.db"
        val database = Room.databaseBuilder(context, NsServicesDatabase::class.java, databaseName).build()
        try {
            val repository = NaxaServicesLocalRepository(database)
            val dao = repository.dao
            dao.insertLoyaltyEvent(
                LocalLoyaltyEvent(
                    activityId, orgId, siteId, programId, customerId,
                    "activity", 2500L, 1L, null, null, null,
                    "Achat validé", "member-1", 100L
                )
            )
            dao.insertLoyaltyEvent(
                LocalLoyaltyEvent(
                    localRewardId, orgId, siteId, programId, customerId,
                    "reward_earned", 0L, 0L, 1, activityId, "available",
                    "Récompense locale provisoire", "member-1", 100L
                )
            )
            val event = LocalOutboxEvent(
                eventId = activityId,
                orgId = orgId,
                aggregateType = "loyalty_activity",
                aggregateId = activityId,
                actionCode = "loyalty_activity.recorded",
                payloadJson = """{"activity_event_id":"$activityId"}""",
                deviceSequence = 1L,
                createdAtEpochMs = 100L
            )
            val payload = JSONObject()
                .put("activity_event_id", activityId)
                .put("org_id", orgId)
                .put("site_id", siteId)
                .put("program_id", programId)
                .put("customer_id", customerId)
            val result = JSONObject()
                .put("metric_delta", 3)
                .put("rewards_earned", 1)
                .put("reward_events", JSONArray().put(
                    JSONObject()
                        .put("event_id", serverRewardId)
                        .put("wave_number", 1)
                        .put("reward_status", "available")
                        .put("description", "Récompense serveur")
                ))

            assertTrue(repository.applyCanonicalServerEffects(event, payload, result))
            assertEquals(3L, dao.findLoyaltyEventById(orgId, activityId)?.metricDelta)
            assertEquals(null, dao.findLoyaltyEventById(orgId, localRewardId))
            assertEquals("Récompense serveur", dao.findLoyaltyEventById(orgId, serverRewardId)?.description)
            assertEquals(1, dao.countLoyaltyRewardsForActivity(orgId, siteId, activityId))

            // A repeated accepted receipt must replace, not duplicate, canonical reward rows.
            assertTrue(repository.applyCanonicalServerEffects(event, payload, result))
            assertEquals(1, dao.countLoyaltyRewardsForActivity(orgId, siteId, activityId))
        } finally {
            database.close()
            context.deleteDatabase(databaseName)
        }
    }

    @Test
    fun retryableOutboxLoadsUnsupportedAndBlockedEventsInDeviceSequenceOrder() = runBlocking<Unit> {
        val orgId = "org-${UUID.randomUUID()}"
        val databaseName = "outbox-recovery-${UUID.randomUUID()}.db"
        var database = Room.databaseBuilder<NsServicesDatabase>(context, databaseName).build()
        try {
            val dao = database.naxaServicesDao()
            dao.insertOutboxEvent(
                LocalOutboxEvent(
                    eventId = "earlier-unsupported",
                    orgId = orgId,
                    aggregateType = "legacy_child",
                    aggregateId = "child-1",
                    actionCode = "appointment_waitlist.converted",
                    payloadJson = "{}",
                    deviceSequence = 1,
                    createdAtEpochMs = 1,
                    state = "blocked_dependency"
                )
            )
            dao.insertOutboxEvent(
                LocalOutboxEvent(
                    eventId = "later-supported",
                    orgId = orgId,
                    aggregateType = "supplier",
                    aggregateId = "supplier-1",
                    actionCode = "supplier.saved",
                    payloadJson = "{}",
                    deviceSequence = 2,
                    createdAtEpochMs = 2,
                    state = "queued"
                )
            )
            dao.insertOutboxEvent(
                LocalOutboxEvent(
                    eventId = "other-organization-higher-sequence",
                    orgId = "another-org",
                    aggregateType = "device",
                    aggregateId = "device-global-sequence",
                    actionCode = "old.event",
                    payloadJson = "{}",
                    deviceSequence = 10,
                    createdAtEpochMs = 10,
                    state = "synced"
                )
            )
            dao.insertOutboxEvent(
                LocalOutboxEvent(
                    eventId = "not-applicable",
                    orgId = orgId,
                    aggregateType = "ledger",
                    aggregateId = "ledger-1",
                    actionCode = "accounting.entry.posted",
                    payloadJson = "{}",
                    deviceSequence = 3,
                    createdAtEpochMs = 3,
                    state = "not_applicable"
                )
            )
            val futureOrg = "future-retry-org-${UUID.randomUUID()}"
            val now = System.currentTimeMillis()
            dao.insertOutboxEvent(
                LocalOutboxEvent(
                    eventId = "future-retry-head",
                    orgId = futureOrg,
                    aggregateType = "supplier",
                    aggregateId = "supplier-retry",
                    actionCode = "supplier.saved",
                    payloadJson = "{}",
                    deviceSequence = 1,
                    createdAtEpochMs = now,
                    nextAttemptAtEpochMs = now + 60_000,
                    state = "retry_wait"
                )
            )
            dao.insertOutboxEvent(
                LocalOutboxEvent(
                    eventId = "later-event-after-retry",
                    orgId = futureOrg,
                    aggregateType = "supplier",
                    aggregateId = "supplier-later",
                    actionCode = "supplier.saved",
                    payloadJson = "{}",
                    deviceSequence = 2,
                    createdAtEpochMs = now + 1,
                    state = "queued"
                )
            )
            database.close()
            database = Room.databaseBuilder(context, NsServicesDatabase::class.java, databaseName).build()
            val recoveredDao = database.naxaServicesDao()
            val pending = recoveredDao.loadRetryableOutboxEvents(orgId, 20)
            assertEquals(listOf("earlier-unsupported", "later-supported"), pending.map { it.eventId })
            assertEquals(1L, pending.first().deviceSequence)
            assertEquals(11L, recoveredDao.nextOutboxSequence())

            val retryQueue = recoveredDao.loadRetryableOutboxEvents(futureOrg, 20)
            assertEquals(listOf("future-retry-head", "later-event-after-retry"), retryQueue.map { it.eventId })
            assertTrue(SupplierSyncCoordinator.isRetryDelayPending(retryQueue.first(), now))
        } finally {
            database.close()
            context.deleteDatabase(databaseName)
        }
    }
}
