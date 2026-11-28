package cm.naxa.naxaservices
import org.junit.Assert.*
import org.junit.Test
class CommissionReconciliationInstrumentedTest {
 private val line="85000000-0000-4000-8000-000000000247"
 private val appointment="82000000-0000-4000-8000-000000000247"
 private val a="60000000-0000-4000-8000-000000000241"
 private val b="60000000-0000-4000-8000-000000000242"
 @Test fun explicitSharesAndRefundsAreCanonical(){
  val v=nativeCommissionAllocation("$line $appointment $b:6000 $a:4000").getJSONObject(0).getJSONArray("shares")
  assertEquals(a,v.getJSONObject(0).getString("member_id"))
  assertEquals(4000,v.getJSONObject(0).getInt("share_bps"))
  assertTrue(runCatching{nativeCommissionAllocation("$line $appointment $a:4000 $b:5999")}.isFailure)
  assertTrue(runCatching{nativeCommissionAllocation("$line $appointment $a:4000 $a:6000")}.isFailure)
  assertEquals(50L,nativeCommissionRefund("$a 1200 50").getJSONObject(0).getLong("commission_xaf"))
  assertTrue(runCatching{nativeCommissionRefund("$a 0 50")}.isFailure)
 }
}
