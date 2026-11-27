package cm.naxa.naxaservices

import java.time.Instant
import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test

class BriefingDatePolicyTest {
 @Test fun usesDoualaMidnightAndServerWindow(){
  val today=briefingToday(Instant.parse("2026-11-26T23:30:00Z"))
  assertEquals(LocalDate.parse("2026-11-27"),today)
  assertTrue(briefingDateAllowed(today,today))
  assertTrue(briefingDateAllowed(today.minusDays(366),today))
  assertFalse(briefingDateAllowed(today.minusDays(367),today))
  assertFalse(briefingDateAllowed(today.plusDays(1),today))
 }
}
