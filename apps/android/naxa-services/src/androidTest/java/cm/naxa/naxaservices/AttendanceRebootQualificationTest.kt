package cm.naxa.naxaservices

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AttendanceRebootQualificationTest {
 @Test fun preserveEncryptedJournalAcrossActualReboot() {
  val c=ApplicationProvider.getApplicationContext<Context>()
  val phase=InstrumentationRegistry.getArguments().getString("nsRebootPhase") ?: "single"
  val id="d5b25fae-716b-497a-93db-32633e0e5ef3"
  val j=AttendanceProofJournal(c,"qa-reboot-org","qa-reboot-member","qa-reboot-device","qa-reboot-site","qa-reboot-post")
  fun create(){
   assertNull(j.read())
   j.save(JSONObject().put("id",id).put("occurred_ms",System.currentTimeMillis())
    .put("event","staff_clock_in").put("stage",JSONObject().put("latitude",4.05))
    .put("jpeg","synthetic-reboot-fixture"))
  }
  fun checkPayload(p:JSONObject){
   assertEquals(id,p.getString("id"))
   assertEquals("staff_clock_in",p.getString("event"))
   assertEquals(4.05,p.getJSONObject("stage").getDouble("latitude"),0.0)
   assertEquals("synthetic-reboot-fixture",p.getString("jpeg"))
   assertNull(AttendanceProofJournal(c,"qa-reboot-org","foreign","qa-reboot-device","qa-reboot-site","qa-reboot-post").read())
  }
  when(phase){
   "prepare" -> {create();val p=j.read()!!;checkPayload(p);assertTrue(j.replayable(p));assertEquals(j.boot(),p.getInt("boot"))}
   "verify" -> {
    val p=j.read()!!
    try {checkPayload(p);assertTrue("OS must actually have rebooted",j.boot()>p.getInt("boot"));assertFalse("No retroactive validation after reboot",j.replayable(p));assertEquals(id,j.read()!!.getString("id"))}
    finally{j.remove(id)}
    assertNull(j.read())
   }
   "single" -> {
    create()
    try {val p=j.read()!!;checkPayload(p);assertTrue(j.replayable(p))}
    finally{j.remove(id)}
    assertNull(j.read())
   }
   else -> fail("Unknown reboot qualification phase")
  }
 }
}
