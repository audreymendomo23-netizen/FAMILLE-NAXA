package cm.naxa.bootik
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class BootikLocalSecurityInstrumentedTest {
 @Test fun memberPinIsolationLockoutResetAndChange(){
  val ctx=InstrumentationRegistry.getInstrumentation().targetContext
  val manager=LocalAccessPinManager(ctx)
  val a="org-a:"+UUID.randomUUID()
  val b="org-b:"+UUID.randomUUID()
  try{
   assertFalse(manager.isConfigured(a))
   assertEquals(LocalAccessPinCode.INVALID_FORMAT,manager.enroll(a,"123").code)
   assertEquals(LocalAccessPinCode.SUCCESS,manager.enroll(a,"1234").code)
   assertEquals(LocalAccessPinCode.ALREADY_CONFIGURED,manager.enroll(a,"5678").code)
   assertEquals(LocalAccessPinCode.NOT_CONFIGURED,manager.verify(b,"1234").code)
   val now=System.currentTimeMillis()
   repeat(4){assertEquals(LocalAccessPinCode.INVALID,manager.verify(a,"9999",now).code)}
   val locked=manager.verify(a,"9999",now)
   assertEquals(LocalAccessPinCode.LOCKED,locked.code)
   assertFalse(manager.canUseBiometric(a,now))
   assertEquals(LocalAccessPinCode.LOCKED,manager.verify(a,"1234",now).code)
   assertEquals(LocalAccessPinCode.SUCCESS,manager.verify(a,"1234",locked.retryAtMillis+1).code)
   assertTrue(manager.canUseBiometric(a,locked.retryAtMillis+1))
   assertEquals(LocalAccessPinCode.SUCCESS,manager.changePin(a,"1234","5678").code)
   assertEquals(LocalAccessPinCode.SUCCESS,manager.verify(a,"5678").code)
   assertTrue(manager.resetAfterValidatedLogin(a))
   assertFalse(manager.isConfigured(a))
   assertFalse(manager.canUseBiometric(a))
  }finally{manager.resetAfterValidatedLogin(a);manager.resetAfterValidatedLogin(b)}
 }
 @Test fun encryptedVaultRoundTripAndClear(){
  val ctx=InstrumentationRegistry.getInstrumentation().targetContext
  val vault=SessionVault(ctx);val original=vault.loadRefreshToken()
  val token=UUID.randomUUID().toString()+UUID.randomUUID().toString()
  try{
   vault.save(token)
   val stored=ctx.getSharedPreferences("bootik_secure_session",0).getString("refresh",null)
   assertNotNull(stored);assertNotEquals(token,stored)
   assertEquals(token,SessionVault(ctx).loadRefreshToken())
   vault.clear();assertNull(SessionVault(ctx).loadRefreshToken())
  }finally{if(original==null)vault.clear()else vault.save(original)}
 }
}
