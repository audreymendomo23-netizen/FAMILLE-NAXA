package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class ErpNumbersTest{
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
