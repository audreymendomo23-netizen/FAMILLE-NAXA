package cm.naxa.naxaservices.auth

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.util.Base64
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking

@RunWith(AndroidJUnit4::class)
class OfflineSessionVaultInstrumentedTest {
    @Test fun concurrentRefreshesUseLatestTokenAndLateResponseCannotRestoreLoggedOutSession()=runBlocking<Unit>{
        val base=ApplicationProvider.getApplicationContext<Context>()
        val suffix="-refresh-qa-"+UUID.randomUUID().toString()
        val context=object:ContextWrapper(base){
            override fun getSharedPreferences(name:String,mode:Int):SharedPreferences=base.getSharedPreferences(name+suffix,mode)
        }
        val vault=SessionVault(context)
        val account=AuthAccount("member","Member","promoter","org","Org","solo","fr",listOf("site"),emptyList())
        val original=AuthSession("access-1","refresh-1",600,false,account,"device")
        try{
            vault.save(original)
            val binding=vault.binding()!!
            val entered=CompletableDeferred<Unit>();val release=CompletableDeferred<Unit>()
            val first=async{
                vault.refreshRemembered(binding){token->
                    assertEquals("refresh-1",token);entered.complete(Unit);release.await()
                    original.copy(accessToken="access-2",refreshToken="refresh-2")
                }
            }
            entered.await()
            val second=async{
                SessionVault(context).refreshRemembered(binding){token->
                    assertEquals("refresh-2",token)
                    original.copy(accessToken="access-3",refreshToken="refresh-3")
                }
            }
            release.complete(Unit);first.await();second.await()
            assertEquals("refresh-3",vault.loadRefreshToken())
            val lateEntered=CompletableDeferred<Unit>();val lateRelease=CompletableDeferred<Unit>()
            val late=async{
                runCatching{vault.refreshRemembered(binding){lateEntered.complete(Unit);lateRelease.await();original.copy(refreshToken="late-old-token")}}.exceptionOrNull()
            }
            lateEntered.await();vault.clear();vault.save(original.copy(refreshToken="new-login"))
            lateRelease.complete(Unit)
            assertTrue(late.await() is RememberedSessionChanged)
            assertEquals("new-login",vault.loadRefreshToken())
            assertNotEquals(binding,vault.binding())
            val newBinding=vault.binding()!!
            assertTrue(runCatching{vault.refreshRemembered(newBinding){throw AuthApiException("unavailable",503)}}.exceptionOrNull() is AuthApiException)
            assertEquals("new-login",vault.loadRefreshToken())
            assertTrue(runCatching{vault.refreshRemembered(newBinding){throw AuthApiException("revoked",401)}}.exceptionOrNull() is AuthApiException)
            assertNull(vault.loadRefreshToken())
        }finally{vault.clear()}
    }

    @Test fun encryptedSnapshotSurvivesVaultRecreationAndRejectsChangedCredentials(){
        val base=ApplicationProvider.getApplicationContext<Context>()
        val suffix="-offline-qa-"+UUID.randomUUID().toString()
        val context=object:ContextWrapper(base){
            override fun getSharedPreferences(name:String,mode:Int):SharedPreferences=base.getSharedPreferences(name+suffix,mode)
        }
        val vault=SessionVault(context)
        try {
            val now=System.currentTimeMillis()/1000
            val jwt="eyJhbGciOiJIUzI1NiJ9."+Base64.encodeToString(JSONObject().put("iat",now).put("exp",now+600).put("session_id","fixture-session").toString().toByteArray(),Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)+".fixture"
            val account=AuthAccount("fixture-member","Fixture name","promoter","fixture-org","Fixture org","solo","fr",
                listOf("fixture-site"),listOf(AuthSite("fixture-site","S1","Fixture site","","")),"pressing",
                setOf("terms:2026-11-v1","privacy:2026-11-v1"),true,true)
            val session=AuthSession(jwt,"fixture-refresh",600,false,account,"fixture-device")
            val access=JSONObject().put("state","active").put("paid_access",true).put("erp_access",true).put("period_end_exclusive","2099-01-01")
            vault.save(session);val originalBinding=vault.binding()!!;vault.saveOfflineSnapshot(session,access,originalBinding)
            val restored=SessionVault(context).loadOfflineSnapshot()
            assertNotNull(restored)
            assertEquals(account,restored!!.account)
            assertEquals(session.deviceId,restored.deviceId)
            assertTrue(restored.expiresIn in 1..600)
            val cipher=context.getSharedPreferences("naxa_services_secure_session",Context.MODE_PRIVATE).getString("offline_snapshot","").orEmpty()
            assertTrue(cipher.isNotEmpty())
            assertFalse(cipher.contains("fixture-refresh"))
            assertFalse(cipher.contains("Fixture name"))
            vault.save(session.copy(refreshToken="rotated-fixture"))
            assertNull(SessionVault(context).loadOfflineSnapshot())
            vault.clear()
            vault.save(session) // Same fixture tokens and account, but a different login generation.
            vault.saveOfflineSnapshot(session,access,originalBinding)
            assertNull(SessionVault(context).loadOfflineSnapshot())
            vault.saveOfflineSnapshot(session,access,vault.binding())
            assertNotNull(SessionVault(context).loadOfflineSnapshot())
            assertFalse(vault.invalidateOfflineSnapshot(originalBinding))
            assertNotNull(SessionVault(context).loadOfflineSnapshot())
            assertTrue(vault.invalidateOfflineSnapshot(vault.binding()!!))
            assertNull(SessionVault(context).loadOfflineSnapshot())
            assertEquals(session.refreshToken,vault.loadRefreshToken())
            vault.clear()
            assertNull(SessionVault(context).loadOfflineSnapshot())
            for(mode in listOf("single_site_multi_workstation","multi_site_network")){
                val sites=if(mode=="multi_site_network") account.activeSites+AuthSite("second-site","S2","Second site","","") else account.activeSites
                val scoped=session.copy(account=account.copy(businessMode=mode,activeSites=sites,activeSiteIds=sites.map{it.id}))
                val proof=JSONObject().put("version",1).put("level","organization").put("member_id",account.memberId)
                    .put("organization_id",account.organizationId).put("role_code","promoter").put("business_mode",mode)
                    .put("session_id","fixture-session").put("site_ids",JSONArray(sites.map{it.id}))
                vault.save(scoped)
                vault.saveOfflineSnapshot(scoped,access)
                assertNull(vault.loadOfflineSnapshot())
                val paid=JSONObject(access.toString()).put("offline_scope",proof)
                vault.saveOfflineSnapshot(scoped,paid)
                assertEquals(scoped.account,SessionVault(context).loadOfflineSnapshot()?.account)
                vault.clear()
            }
        }finally{vault.clear()}
    }
}
