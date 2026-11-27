package cm.naxa.naxaservices
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
class BriefingPayloadInstrumentedTest {
 private fun report()=JSONObject("""{"day":"2026-11-27","generated_at":"2026-11-27T12:00:00Z","scope":"personal","coverage":"partial_confirmed_server_facts","finance":null,"appointments":{"scheduled_count":2,"completed_count":1},"personal_clock_events":{"event_count":3}}""")
 private fun denied(r:JSONObject){assertTrue(runCatching{validateNativeBriefing(r,"2026-11-27")}.isFailure)}
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
