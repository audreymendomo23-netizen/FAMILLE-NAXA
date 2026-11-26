package cm.naxa.naxaservices.auth

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.util.Base64
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class OfflineSessionVaultInstrumentedTest {
    @Test fun encryptedSnapshotSurvivesVaultRecreationAndRejectsChangedCredentials(){
        val base=ApplicationProvider.getApplicationContext<Context>()
        val suffix="-offline-qa-"+UUID.randomUUID().toString()
        val context=object:ContextWrapper(base){
            override fun getSharedPreferences(name:String,mode:Int):SharedPreferences=base.getSharedPreferences(name+suffix,mode)
        }
        val vault=SessionVault(context)
        try {
            val now=System.currentTimeMillis()/1000
            val jwt="eyJhbGciOiJIUzI1NiJ9."+Base64.encodeToString(JSONObject().put("iat",now).put("exp",now+600).toString().toByteArray(),Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)+".fixture"
            val account=AuthAccount("fixture-member","Fixture name","promoter","fixture-org","Fixture org","solo","fr",
                listOf("fixture-site"),listOf(AuthSite("fixture-site","S1","Fixture site","","")),"pressing",
                setOf("terms:2026-11-v1","privacy:2026-11-v1"),true,true)
            val session=AuthSession(jwt,"fixture-refresh",600,false,account,"fixture-device")
            val access=JSONObject().put("state","active").put("paid_access",true).put("erp_access",true).put("period_end_exclusive","2099-01-01")
            vault.save(session);vault.saveOfflineSnapshot(session,access)
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
            assertNull(SessionVault(context).loadOfflineSnapshot())
        }finally{vault.clear()}
    }
}
