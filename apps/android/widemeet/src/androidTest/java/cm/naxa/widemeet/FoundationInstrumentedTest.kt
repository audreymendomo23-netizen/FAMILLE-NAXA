package cm.naxa.widemeet
import android.content.Context
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.core.app.ApplicationProvider
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*
import cm.naxa.widemeet.auth.SessionVault
import cm.naxa.widemeet.auth.VaultSession
import cm.naxa.widemeet.auth.LocalUnlock

@RunWith(AndroidJUnit4::class)
class FoundationInstrumentedTest {
 @get:Rule val rule=createAndroidComposeRule<MainActivity>()
 @Test fun nativeShellNavigationAndTheme(){
  val context=ApplicationProvider.getApplicationContext<Context>()
  val prefs=context.getSharedPreferences("widemeet.appearance.v1",Context.MODE_PRIVATE)
  rule.onNodeWithContentDescription("WideMeet").assertExists()
  // Start by normalizing the persisted theme and locale from the real UI, not by editing state.
  val isDark=prefs.getBoolean("dark",false)
  if(isDark)rule.onNodeWithTag("wm-theme").performClick()
  for(i in 0..4)rule.onNodeWithTag("wm-tab-$i").performClick().assertIsSelected()
  rule.onNodeWithTag("wm-theme").performClick()
  rule.waitUntil(5000){prefs.getBoolean("dark",false)}
  rule.activityRule.scenario.recreate()
  rule.onNodeWithTag("wm-theme").assertExists()
  assertTrue(prefs.getBoolean("dark",false))
  rule.onNodeWithTag("wm-menu").performClick()
  rule.onNodeWithTag("wm-menu-item-13").performScrollTo().performClick()
  rule.onNodeWithTag("wm-motion").assertExists()
  val before=prefs.getBoolean("motion",true)
  rule.onNodeWithTag("wm-motion").performClick()
  rule.waitUntil(5000){prefs.getBoolean("motion",true)!=before}
  val previousLanguage=prefs.getBoolean("english",false)
  rule.onNodeWithTag("wm-language").performClick()
  rule.waitUntil(5000){prefs.getBoolean("english",false)!=previousLanguage}
  rule.onNodeWithTag("wm-tab-0").performClick()
  rule.onNodeWithTag("wm-login").performScrollTo().performClick()
  rule.onNodeWithTag("wm-signin-title").assertTextEquals(if(previousLanguage)"Connexion" else "Sign in").assertIsDisplayed()
  rule.onNodeWithTag("wm-signin-submit").assertIsNotEnabled()
  rule.onNodeWithTag("wm-photo-signin").assertDoesNotExist()
  rule.onNodeWithTag("wm-signin-background").assertExists()
  rule.onNodeWithTag("wm-signin-background-image").assertExists()
  rule.onNodeWithTag("wm-signin-logo").assertIsDisplayed()
  rule.onNodeWithTag("wm-tab-0").assertDoesNotExist()
  rule.onNodeWithTag("wm-menu").assertDoesNotExist()
  rule.onNodeWithTag("wm-theme").assertExists()
  rule.onNodeWithTag("wm-signin-back").performScrollTo().performClick()
  rule.onNodeWithTag("wm-photo-home").performScrollTo().assertIsDisplayed()
  rule.onNodeWithTag("wm-signin-background").assertDoesNotExist()
  rule.onNodeWithTag("wm-tab-0").assertExists()
 }
 @Test fun nativeFaqNavigation(){
  rule.onNodeWithTag("wm-menu").performClick()
  rule.onNodeWithTag("wm-menu-item-10").performScrollTo().performClick()
  val context=ApplicationProvider.getApplicationContext<Context>()
  val english=context.getSharedPreferences("widemeet.appearance.v1",Context.MODE_PRIVATE).getBoolean("english",false)
  val question=if(english)"How do I secure my account?" else "Comment protéger mon compte ?"
  rule.onNodeWithText(question).performScrollTo().performClick()
  rule.onNodeWithText(if(english)"Open this area" else "Ouvrir cet espace").performScrollTo().performClick()
  rule.onNodeWithTag("wm-signin-title").assertExists()
 }
 @Test fun keystoreRememberMeRoundTrip(){
  val context=ApplicationProvider.getApplicationContext<Context>()
  val vault=SessionVault(context)
  try{
   vault.clear()
   val s=VaultSession("fixture-access-token","fixture-refresh-token","fixture-device")
   vault.save(s,false);assertNull(vault.loadRefreshToken())
   vault.save(s,true)
   assertEquals(s.refreshToken,SessionVault(context).loadRefreshToken())
   assertEquals(s.accessToken,SessionVault(context).loadAccessToken())
   assertEquals(s.deviceId,SessionVault(context).loadDeviceId())
   vault.clear();assertNull(vault.loadAccessToken())
  }finally{vault.clear()}
 }
 @Test fun localPinKeystoreAndPersistentAttemptLimit(){
  val context=ApplicationProvider.getApplicationContext<Context>()
  val gate=LocalUnlock(context);val vault=SessionVault(context)
  try{
   gate.clear();assertFalse(gate.configured());gate.configure("4831")
   vault.save(VaultSession("fixture-access","fixture-refresh","fixture-device"),true)
   assertTrue(LocalUnlock(context).configured())
   assertFalse(LocalUnlock(context).verify("0000"))
   assertTrue(LocalUnlock(context).verify("4831"))
   repeat(4){assertFalse(LocalUnlock(context).verify("0000"));assertTrue(LocalUnlock(context).configured())}
   assertFalse(LocalUnlock(context).verify("0000"))
   assertFalse(LocalUnlock(context).configured())
   assertNull(vault.loadRefreshToken())
   assertFalse(LocalUnlock(context).verify("4831"))
  }finally{gate.clear()}
 }

 @Test fun clearedVaultDisablesBiometricEnvelope(){
  val context=ApplicationProvider.getApplicationContext<Context>()
  val gate=LocalUnlock(context); val gateway=cm.naxa.widemeet.auth.AuthGateway(context,"")
  gate.clear()
  assertFalse(gateway.biometricAvailable())
  assertNull(gateway.prepareBiometric())
 }

 @Test fun originalPhotoAssetsDecodeAndAppear(){
  val context=ApplicationProvider.getApplicationContext<Context>()
  for(name in wideMeetPhotoNames){val b=requireNotNull(context.assets.open("wm-photos/"+name+".jpg").use{android.graphics.BitmapFactory.decodeStream(it)});assertTrue(b.width>0&&b.height>0);b.recycle()}
  rule.onNodeWithTag("wm-tab-0").performClick()
  rule.onNodeWithTag("wm-photo-home").performScrollTo().assertIsDisplayed()
 }
}
