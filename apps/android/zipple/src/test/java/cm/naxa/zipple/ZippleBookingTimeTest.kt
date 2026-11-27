package cm.naxa.zipple
import org.junit.Assert.*
import org.junit.Test
class ZippleBookingTimeTest {
 @Test fun convertsDoualaTimeToUtc(){
  assertEquals("2027-02-01T11:00:00Z",zippleBookingTime("2027-02-01 12:00"))
  assertEquals("2026-12-31T23:15:00Z",zippleBookingTime("2027-01-01 00:15"))
 }
 @Test fun rejectsInvalidDateAndUnexpectedFormat(){
  for(value in listOf("2027-02-30 12:00","2027-01-01 24:00","2027-01-01T12:00","2027-01-01 12:00Z",""))assertNull(zippleBookingTime(value))
 }
}
