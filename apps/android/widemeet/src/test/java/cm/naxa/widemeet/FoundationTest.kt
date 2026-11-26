package cm.naxa.widemeet
import org.junit.Test
import org.junit.Assert.*
import cm.naxa.widemeet.auth.*

class FoundationTest {
 @Test fun meetingCountdownBoundaryAndPermission(){
  assertFalse(meetingClockView(301000,600000,0,"open",true).warning)
  assertTrue(meetingClockView(300000,600000,0,"open",true).warning)
  assertFalse(meetingClockView(300000,600000,0,"open",false).warning)
  assertTrue(meetingClockView(300000,600000,300000,"open",true).expired)
  assertFalse(meetingClockView(300000,300000,0,"open",true).canExtend)
 }
 @Test fun payerAndTenantPolicy(){
  val id="00000000-0000-4000-8000-000000000001"
  val member="00000000-0000-4000-8000-000000000002"
  val device="00000000-0000-4000-8000-000000000003"
  val w=Workspace(id,"enterprise","Fixture","promoteur",true)
  val s=Session("WIDEMEET","test-token-01234567890",member,device,200000,100000,100000,100,false,id,listOf(w))
  assertTrue(mayPay(s,100000,100));assertFalse(mayPay(s.copy(workspaces=listOf(w.copy(role="staff"))),100000,100))
  assertFalse(validSession(s.copy(appId="BOOTIK")))
  assertFalse(validLease(s,200000,100100));assertFalse(validLease(s,94000,100))
  assertNull(activeWorkspace(s.copy(requirePasswordChange=true),100000,100))
 }
}
