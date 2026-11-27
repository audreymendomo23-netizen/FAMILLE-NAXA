package cm.naxa.naxaservices.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class SecureLocalDatabaseInstrumentedTest {
    private suspend fun <T> NsServicesDatabase.withDatabase(block: suspend (NsServicesDatabase)->T):T {
        try { return block(this) } finally { close() }
    }

    @Test fun migratesLegacyRoomAndOutboxWithoutDataLossAndRejectsMissingKey()=runBlocking<Unit>(Dispatchers.IO){
        val context=ApplicationProvider.getApplicationContext<Context>()
        val name="secure-local-qa-"+UUID.randomUUID()+".db"
        val file=context.getDatabasePath(name)
        val key=File(context.noBackupFilesDir,"$name.wrapped-key")
        val customer=LocalCustomer("customer","org-a","site-a","PRIVATE-FIXTURE","600000000","private note",true,1)
        val event=LocalOutboxEvent(eventId="event-a",orgId="org-a",aggregateType="customer",aggregateId="customer",
            actionCode="customer.create",payloadJson="{\"fixture\":true}",deviceSequence=1,createdAtEpochMs=1)
        try {
            Room.databaseBuilder(context,NsServicesDatabase::class.java,name).build().withDatabase { legacy ->
                legacy.naxaServicesDao().insertCustomer(customer)
                legacy.naxaServicesDao().insertOutboxEvent(event)
            }
            assertTrue(file.inputStream().use { val h=ByteArray(16);it.read(h);String(h,Charsets.US_ASCII).startsWith("SQLite format 3") })
            SecureLocalDatabase.open(context,name).withDatabase { encrypted ->
                assertEquals(customer,encrypted.naxaServicesDao().findCustomer("customer","org-a","site-a"))
                assertNull(encrypted.naxaServicesDao().findCustomer("customer","org-b","site-a"))
                assertNull(encrypted.naxaServicesDao().findCustomer("customer","org-a","site-b"))
                assertEquals(event,encrypted.naxaServicesDao().loadRetryableOutboxEvents("org-a").single())
            }
            assertFalse(file.inputStream().use { val h=ByteArray(16);it.read(h);String(h,Charsets.US_ASCII).startsWith("SQLite format 3") })
            SecureLocalDatabase.open(context,name).withDatabase { reopened ->
                assertEquals(customer,reopened.naxaServicesDao().findCustomer("customer","org-a","site-a"))
            }
            val wrapped=key.readBytes()
            assertTrue(key.delete())
            val before=file.length()
            assertTrue(runCatching { SecureLocalDatabase.open(context,name).close() }.isFailure)
            assertTrue(file.exists())
            assertEquals(before,file.length())
            key.writeBytes(wrapped)
            SecureLocalDatabase.open(context,name).withDatabase { reopened ->
                assertEquals(event,reopened.naxaServicesDao().loadRetryableOutboxEvents("org-a").single())
            }
        }finally{
            context.deleteDatabase(name)
            key.delete()
        }
    }

    @Test fun workstationProjectionsDoNotExposeOtherPostsSitesOrganizationsOrAssignedStaff()=runBlocking<Unit>(Dispatchers.IO){
        val context=ApplicationProvider.getApplicationContext<Context>()
        val name="secure-scope-qa-"+UUID.randomUUID()+".db"
        try {
            SecureLocalDatabase.open(context,name).withDatabase { db ->
                val dao=db.naxaServicesDao()
                val ticket=LocalPressingOrder(id="t1",orgId="org-a",siteId="site-a",workstationId="post-a",ticketNumber="T1",customerName="private",customerPhone="600000000",itemsSummary="fixture",totalXaf=1000,depositXaf=0,promisedAtMillis=100,actorMemberId="member-a",createdAtMillis=1,updatedAtMillis=1)
                for(row in listOf(ticket,ticket.copy(id="t2",ticketNumber="T2",workstationId="post-b"),ticket.copy(id="t3",ticketNumber="T3",siteId="site-b"),ticket.copy(id="t4",ticketNumber="T4",orgId="org-b"),ticket.copy(id="t5",ticketNumber="T5",workstationId=null)))dao.insertPressingOrder(row)
                val appointment=LocalAppointment("a1","org-a","site-a","post-a","private","service","member-a",1,2,0,actorMemberId="member-a",createdAtMillis=1)
                for(row in listOf(appointment,appointment.copy(id="a2",assignedMemberId="member-b"),appointment.copy(id="a3",workstationId="post-b"),appointment.copy(id="a4",siteId="site-b"),appointment.copy(id="a5",orgId="org-b"),appointment.copy(id="a6",workstationId=null)))dao.insertAppointment(row)
                assertEquals(listOf("t1"),dao.observeWorkstationPressingTickets("org-a","site-a","post-a").first().map{it.id})
                assertTrue(dao.observeWorkstationPressingTickets("org-a","site-a","").first().isEmpty())
                assertEquals(listOf("a1"),dao.observeAssignedWorkstationAppointments("org-a","site-a","post-a","member-a").first().map{it.id})
                assertTrue(dao.observeAssignedWorkstationAppointments("org-a","site-a","post-a","").first().isEmpty())
            }
        }finally{context.deleteDatabase(name);File(context.noBackupFilesDir,"$name.wrapped-key").delete()}
    }

    @Test fun queueOwnershipPreservesLegacyAndSeparatesMembersAndDevices()=runBlocking<Unit>(Dispatchers.IO){
        val context=ApplicationProvider.getApplicationContext<Context>()
        val name="secure-owner-qa-"+UUID.randomUUID()+".db"
        try{
            SecureLocalDatabase.open(context,name).withDatabase{database->
                val dao=database.naxaServicesDao()
                val original=LocalOutboxEvent(eventId="legacy",orgId="org-a",aggregateType="customer",aggregateId="customer",
                    actionCode="customer.created",payloadJson="{\"org_id\":\"org-a\"}",deviceSequence=1,createdAtEpochMs=1)
                dao.insertOutboxEvent(original)
                dao.insertOutboxEvent(original.copy(eventId="a",deviceSequence=2,ownerMemberId="member-a",ownerDeviceId="device-a"))
                dao.insertOutboxEvent(original.copy(eventId="b",deviceSequence=3,ownerMemberId="member-b",ownerDeviceId="device-a"))
                dao.insertOutboxEvent(original.copy(eventId="c",deviceSequence=4,ownerMemberId="member-a",ownerDeviceId="device-b"))
                assertEquals(listOf("a"),dao.loadOwnedRetryableOutboxEvents("org-a","member-a","device-a").map{it.eventId})
                assertEquals(listOf("b"),dao.loadOwnedRetryableOutboxEvents("org-a","member-b","device-a").map{it.eventId})
                assertEquals(listOf("c"),dao.loadOwnedRetryableOutboxEvents("org-a","member-a","device-b").map{it.eventId})
                assertEquals(4,dao.loadRetryableOutboxEvents("org-a").size)
                assertEquals(1,dao.observeOwnedPendingOutboxCount("org-a","member-a","device-a").first())
                val repo=NaxaServicesLocalRepository(database,LocalQueueOwner("org-a","member-a","device-a"))
                val supplier=repo.saveSupplier("org-a","site-a","Test supplier","","","","",0,"","member-a")
                val owned=dao.loadOwnedRetryableOutboxEvents("org-a","member-a","device-a")
                assertTrue(owned.any{it.aggregateId==supplier.id&&it.ownerMemberId=="member-a"&&it.ownerDeviceId=="device-a"})
            }
        }finally{context.deleteDatabase(name);File(context.noBackupFilesDir,"$name.wrapped-key").delete()}
    }

    @Test fun migratesVersion16UnownedEventsWithoutReassignment()=runBlocking<Unit>(Dispatchers.IO){
        val context=ApplicationProvider.getApplicationContext<Context>()
        val name="secure-v16-qa-"+UUID.randomUUID()+".db"
        val original=LocalOutboxEvent(eventId="old",orgId="org-a",aggregateType="customer",aggregateId="c",
            actionCode="customer.created",payloadJson="{\"org_id\":\"org-a\"}",deviceSequence=1,createdAtEpochMs=1)
        try{
            Room.databaseBuilder(context,NsServicesDatabase::class.java,name).build().withDatabase{it.naxaServicesDao().insertOutboxEvent(original)}
            android.database.sqlite.SQLiteDatabase.openDatabase(context.getDatabasePath(name).path,null,android.database.sqlite.SQLiteDatabase.OPEN_READWRITE).use{plain->
                plain.execSQL("ALTER TABLE local_outbox_events DROP COLUMN ownerMemberId")
                plain.execSQL("ALTER TABLE local_outbox_events DROP COLUMN ownerDeviceId")
                plain.version=16
            }
            SecureLocalDatabase.open(context,name).withDatabase{db->
                assertEquals(original,db.naxaServicesDao().loadRetryableOutboxEvents("org-a").single())
                assertTrue(db.naxaServicesDao().loadOwnedRetryableOutboxEvents("org-a","member-a","device-a").isEmpty())
            }
        }finally{context.deleteDatabase(name);File(context.noBackupFilesDir,"$name.wrapped-key").delete()}
    }

    @Test fun newDatabaseIsEncryptedFromFirstWrite()=runBlocking<Unit>(Dispatchers.IO){
        val context=ApplicationProvider.getApplicationContext<Context>()
        val name="secure-fresh-qa-"+UUID.randomUUID()+".db"
        try{
            SecureLocalDatabase.open(context,name).withDatabase { db ->
                db.naxaServicesDao().insertCustomer(LocalCustomer("c","o","s","private","600000000","notes",true,1))
            }
            val header=context.getDatabasePath(name).inputStream().use { val h=ByteArray(16);it.read(h);String(h,Charsets.US_ASCII) }
            assertFalse(header.startsWith("SQLite format 3"))
        }finally{context.deleteDatabase(name);File(context.noBackupFilesDir,"$name.wrapped-key").delete()}
    }
}
