package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class ErpNumbersTest{
 @Test fun exactScanRejectsAmbiguity(){
  val ingredients=listOf("i1" to "00123","i2" to "BAR")
  val lots=listOf(Triple("l1","LOT-A","i1"),Triple("l2","LOT-B","i1"),Triple("l3","LOT-C","i2"))
  assertEquals("l1",resolveInventoryScan(" lot-a ",lots,ingredients))
  assertEquals("l3",resolveInventoryScan("BAR",lots,ingredients))
  assertNull(resolveInventoryScan("00123",lots,ingredients))
  assertNull(resolveInventoryScan("123",lots,ingredients))
  assertEquals("l2",resolveInventoryScan("l2",lots,ingredients))
  assertNull(resolveInventoryScan("OTHER",lots,ingredients))
  assertNull(resolveInventoryScan("",lots,ingredients))
  assertNull(resolveInventoryScan("BAR",lots+Triple("l4","BAR","i1"),ingredients))
 }
 @Test fun exactQuantitiesAndMoney(){
  assertEquals(1250L,ZippleErpNumbers.milli("1.250"))
  assertEquals(1L,ZippleErpNumbers.milli("0.001"))
  assertNull(ZippleErpNumbers.milli("0.0001"))
  assertNull(ZippleErpNumbers.milli("-1"))
  assertNull(ZippleErpNumbers.milli("1e3"))
  assertEquals(2500L,ZippleErpNumbers.integer("2500"))
  assertNull(ZippleErpNumbers.integer("2.5"))
  assertNull(ZippleErpNumbers.integer("2147483648"))
 }
}
