package cm.naxa.naxaservices

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.io.File
import java.security.MessageDigest

@RunWith(AndroidJUnit4::class)
class AttendanceProofJournalInstrumentedTest {
 @Test fun durableEncryptedCaptureCannotBeOverwrittenOrReadFromAnotherScope(){
  val c=ApplicationProvider.getApplicationContext<Context>()
  val org=UUID.randomUUID().toString();val id=UUID.randomUUID().toString()
  fun journal(member:String="member",post:String="post")=AttendanceProofJournal(c,org,member,"device","site",post)
  val j=journal()
  try{
   val value=JSONObject().put("id",id).put("occurred_ms",System.currentTimeMillis()).put("event","staff_clock_in").put("stage",JSONObject().put("latitude",4.123456)).put("jpeg","private-test-fixture")
   j.save(value)
   val reopened=journal().read()!!
   assertEquals(id,reopened.getString("id"));assertEquals(value.getLong("occurred_ms"),reopened.getLong("occurred_ms"))
   assertEquals(4.123456,reopened.getJSONObject("stage").getDouble("latitude"),0.0)
   assertTrue(journal().replayable(reopened))
   val aad="ns-attendance-journal-v1|$org|member|device|site|post".toByteArray(Charsets.UTF_8)
   val name="attendance-"+MessageDigest.getInstance("SHA-256").digest(aad).joinToString(""){"%02x".format(it.toInt() and 255)}+".pending"
   val disk=File(c.noBackupFilesDir,name);val original=disk.readBytes()
   assertFalse(String(original,Charsets.ISO_8859_1).contains("private-test-fixture"))
   assertFalse(String(original,Charsets.ISO_8859_1).contains("4.123456"))
   val tampered=original.clone();tampered[tampered.lastIndex]=(tampered.last().toInt() xor 1).toByte()
   try{disk.writeBytes(tampered);assertTrue(runCatching{journal().read()}.isFailure)}finally{disk.writeBytes(original)}
   assertEquals(id,journal().read()!!.getString("id"))
   assertNull(journal("other").read());assertNull(journal(post="other").read())
   assertTrue(runCatching{j.save(value)}.isFailure)
   assertTrue(runCatching{j.remove(UUID.randomUUID().toString())}.isFailure)
   assertEquals(id,j.read()!!.getString("id"))
   j.remove(id);assertNull(journal().read())
  }finally{j.read()?.let{j.remove(it.getString("id"))}}
 }
 @Test fun rejectsExpiredClockRollbackAndReboot(){
  assertTrue(AttendanceProofJournal.valid(1000000,1000,1,999999,1001000,2000,1))
  assertFalse(AttendanceProofJournal.valid(1000000,1000,1,999999,1300000,301000,1))
  assertFalse(AttendanceProofJournal.valid(1000000,1000,1,999999,999999,2000,1))
  assertFalse(AttendanceProofJournal.valid(1000000,1000,1,999999,1001000,2000,2))
  assertFalse(AttendanceProofJournal.valid(1000000,1000,1,999999,1001000,20000,1))
 }
}
