package cm.naxa.naxaservices.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
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
