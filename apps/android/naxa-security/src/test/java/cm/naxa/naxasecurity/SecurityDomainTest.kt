package cm.naxa.naxasecurity
import org.junit.Assert.*
import org.junit.Test
class SecurityDomainTest {
 @Test fun siteEligibility() {assertTrue(SecurityDomain.siteEligibility("Essentiel",1));assertFalse(SecurityDomain.siteEligibility("Essentiel",2));assertTrue(SecurityDomain.siteEligibility("Business",2));assertFalse(SecurityDomain.siteEligibility("Professional",0))}
 @Test fun deviceHealth() {assertEquals("online",SecurityDomain.deviceHealth(true,1000L,1000L,"online"));assertEquals("unknown",SecurityDomain.deviceHealth(false,1000L,1000L,"online"));assertEquals("unknown",SecurityDomain.deviceHealth(true,1000L,122000L,"online"))}
 @Test fun fireAlarm() {assertEquals("alarm_acknowledged",SecurityDomain.fireAlarmView(true,"fire_panel","alarm",true));assertEquals("restored_pending_inspection",SecurityDomain.fireAlarmView(true,"smoke_detector","restored"));assertEquals("unknown",SecurityDomain.fireAlarmView(false,"fire_panel","alarm"))}
 @Test fun attendance() {assertEquals("pending_server_review",SecurityDomain.attendanceDraft("arrival",4.0,9.0,10.0,false,1000L,1000L));assertEquals("rejected",SecurityDomain.attendanceDraft("arrival",4.0,9.0,10.0,true,1000L,1000L));assertEquals("rejected",SecurityDomain.attendanceDraft("approve",4.0,9.0,10.0,false,1000L,1000L))}
 @Test fun maintenance() {assertEquals("incomplete",SecurityDomain.maintenanceClosure(true," "));assertEquals("incomplete",SecurityDomain.maintenanceClosure(false,"Report"));assertEquals("ready_for_authorized_review",SecurityDomain.maintenanceClosure(true,"Report"))}
 @Test fun delegation() {val g=listOf("app","org","site","resource","read");assertTrue(SecurityDomain.subjectDelegatedRead(true,0,100,50,g,g,"u","u"));assertFalse(SecurityDomain.subjectDelegatedRead(true,0,100,50,g,g,"u","v"));assertFalse(SecurityDomain.subjectDelegatedRead(true,51,100,50,g,g,"u","u"))}
}
