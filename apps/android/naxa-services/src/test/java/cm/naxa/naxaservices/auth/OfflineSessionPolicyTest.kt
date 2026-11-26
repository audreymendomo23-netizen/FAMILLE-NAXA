package cm.naxa.naxaservices.auth
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
class OfflineSessionPolicyTest {
 private val wall=1_800_000_000_000L
 private val account=AuthAccount("member","Test","promoter","org","Org","solo","fr",listOf("site"),emptyList(),"pressing",setOf("terms:2026-11-v1","privacy:2026-11-v1"),true,true)
 private val session=AuthSession("access","refresh",3600,false,account,"device")
 private val access=JSONObject().put("state","active").put("paid_access",true).put("erp_access",true).put("period_end_exclusive","2099-01-01")
 @Test fun boundedByActualSessionAndPaidAccess(){
   assertEquals(wall+30_000,OfflineSessionPolicy.expiresAt(session,access,wall+30_000,wall))
   assertEquals(wall+3_600_000,OfflineSessionPolicy.expiresAt(session,access,wall+7_200_000,wall))
   assertNull(OfflineSessionPolicy.expiresAt(session,access,wall,wall))
   assertNull(OfflineSessionPolicy.expiresAt(session.copy(account=account.copy(businessMode="multi_site_network")),access,wall+30_000,wall))
   assertNull(OfflineSessionPolicy.expiresAt(session.copy(requirePasswordChange=true),access,wall+30_000,wall))
   assertNull(OfflineSessionPolicy.expiresAt(session,JSONObject(access.toString()).put("paid_access",false),wall+30_000,wall))
 }
 @Test fun monotonicClockAndBootFailClosed(){
   assertTrue(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+10000,11000,4))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+30000,31000,4))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall-1,11000,4))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+10000,11000,5))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+1000,200000,4))
 }
}
