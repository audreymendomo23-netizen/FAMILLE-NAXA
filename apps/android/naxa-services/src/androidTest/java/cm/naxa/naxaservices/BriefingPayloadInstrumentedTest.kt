package cm.naxa.naxaservices
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
class BriefingPayloadInstrumentedTest {
 private fun report()=JSONObject("""{"day":"2026-11-27","generated_at":"2026-11-27T12:00:00Z","scope":"personal","coverage":"partial_confirmed_server_facts","finance":null,"appointments":{"scheduled_count":2,"completed_count":1},"personal_clock_events":{"event_count":3}}""")
 private fun denied(r:JSONObject){assertTrue(runCatching{validateNativeBriefing(r,"2026-11-27")}.isFailure)}
 @Test fun annualPeriodPreservesEveryDayAndRejectsGaps(){
  val end=java.time.LocalDate.parse("2024-12-31");val rows=(0 until 366).map{i->report().put("day",end.minusDays((365-i).toLong()).toString())};val result=nativeBriefingPeriod(rows,end,366);assertEquals(732L,result["appointments"]);assertTrue(runCatching{nativeBriefingPeriod(rows.drop(1),end,366)}.isFailure)
 }
 @Test fun voiceQuestionsOnlyUseAuthorizedKnownValues(){
  val labels=mapOf("appointments" to "Appointments","revenue" to "Revenue","clocks" to "Clock events")
  val values=mapOf("appointments" to 2L,"clocks" to null)
  assertEquals("Appointments: 2",nativeBriefingQuestion(" appointments? ",labels,values))
  assertNull(nativeBriefingQuestion("Revenue",labels,values))
  assertNull(nativeBriefingQuestion("Clock events",labels,values))
  assertNull(nativeBriefingQuestion("Show customer names",labels,values))
  assertEquals("Revenue: 0",nativeBriefingQuestion("Revenue",labels,mapOf("revenue" to 0L)))
 }
 @Test fun periodPreservesScopeAndUnknownFinance(){
  val a=report().put("day","2026-11-26");val b=report()
  val result=nativeBriefingPeriod(listOf(a,b),java.time.LocalDate.parse("2026-11-27"),2)
  assertEquals(4L,result["appointments"]);assertEquals(6L,result["clocks"]);assertFalse(result.containsKey("revenue"))
  assertTrue(runCatching{nativeBriefingPeriod(listOf(a,b.put("scope","site")),java.time.LocalDate.parse("2026-11-27"),2)}.isFailure)
 }
 @Test fun acceptsConfirmedAndRejectsLeaksAndMalformedCounts(){
  validateNativeBriefing(report(),"2026-11-27")
  denied(report().put("finance",JSONObject("""{"revenue_xaf":200,"confirmed_sales_count":1,"uncosted_sales_count":0}""")))
  denied(report().put("day","2026-11-26"))
  denied(report().put("appointments",JSONObject("""{"scheduled_count":"2","completed_count":1}""")))
  denied(report().put("appointments",JSONObject("""{"scheduled_count":1,"completed_count":2}""")))
  denied(report().put("personal_clock_events",JSONObject("""{"event_count":-1}""")))
  denied(report().put("generated_at","invalid"))
 }
}
