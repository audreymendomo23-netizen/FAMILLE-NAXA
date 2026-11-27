package cm.naxa.naxaservices.auth
import org.json.JSONObject
import org.json.JSONArray
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
 @Test fun organizationAuthorityForBAndCRequiresExactFreshProof(){
   for(mode in listOf("single_site_multi_workstation","multi_site_network")){
     val ids=if(mode=="multi_site_network") listOf("site","site-b") else listOf("site")
     val manager=account.copy(businessMode=mode,activeSiteIds=ids)
     val scoped=session.copy(account=manager)
     val proof=JSONObject().put("version",1).put("level","organization").put("member_id","member")
       .put("organization_id","org").put("role_code","promoter").put("business_mode",mode)
       .put("session_id","jwt-session").put("site_ids",JSONArray(ids))
     val paid=JSONObject(access.toString()).put("offline_scope",proof)
     assertEquals(wall+30000,OfflineSessionPolicy.expiresAt(scoped,paid,wall+30000,wall,"jwt-session"))
     assertNull(OfflineSessionPolicy.expiresAt(scoped,paid,wall+30000,wall,"other-session"))
     assertNull(OfflineSessionPolicy.expiresAt(scoped,access,wall+30000,wall,"jwt-session"))
     for((field,value) in listOf("level" to "workstation","organization_id" to "other","member_id" to "other","role_code" to "cashier","business_mode" to "solo")){
       val bad=JSONObject(paid.toString()).put("offline_scope",JSONObject(proof.toString()).put(field,value))
       assertNull(OfflineSessionPolicy.expiresAt(scoped,bad,wall+30000,wall,"jwt-session"))
     }
     assertNull(OfflineSessionPolicy.expiresAt(scoped.copy(account=manager.copy(activeSiteIds=ids+"foreign")),paid,wall+30000,wall,"jwt-session"))
     assertNull(OfflineSessionPolicy.expiresAt(scoped,JSONObject(paid.toString()).put("paid_access",false),wall+30000,wall,"jwt-session"))
   }
 }
 @Test fun monotonicClockAndBootFailClosed(){
   assertTrue(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+10000,11000,4))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+30000,31000,4))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall-1,11000,4))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+10000,11000,5))
   assertFalse(OfflineSessionPolicy.valid(wall,1000,4,wall+30000,wall+1000,200000,4))
 }
}
