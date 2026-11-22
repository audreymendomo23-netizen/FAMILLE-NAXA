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
import cm.naxa.naxaservices.data.NsServicesDatabase
import java.util.UUID
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
