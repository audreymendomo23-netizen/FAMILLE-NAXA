package cm.naxa.zipple
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.*
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.delay
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class N1LiveDeviceTest {
 @get:Rule val compose=createAndroidComposeRule<MainActivity>()
 @Test fun authenticatedNativeAndPersistedSync(){
  val args=InstrumentationRegistry.getArguments()
  val password=args.getString("zippleFixturePassword")
  assumeTrue("Only the isolated configured CI recipe",password!=null && BuildConfig.ZIPPLE_API_URL=="https://127.0.0.1:4443/gateway")
  val eventId=requireNotNull(args.getString("zippleFixtureEvent"))
  val context=InstrumentationRegistry.getInstrumentation().targetContext
  compose.onNodeWithText("Identifiant").performTextInput("fixture")
  compose.onNodeWithText("Mot de passe",substring=false).performTextInput(requireNotNull(password))
  compose.onNodeWithText("Se connecter").performClick()
  compose.waitUntil(20000){compose.onAllNodesWithText("Configurer votre code local").fetchSemanticsNodes().isNotEmpty()}
  compose.onNodeWithText("PIN",substring=false).performTextInput("1234")
  compose.onNodeWithText("Continuer").performScrollTo().performClick()
  compose.waitUntil(10000){ZippleSyncSession.current!=null}
  compose.onNodeWithText("ZIPPLE fixture").assertExists()
  compose.onNodeWithText("Site A",substring=true).assertExists()
  val session=requireNotNull(ZippleSyncSession.current)
  assertEquals(1,session.sites.size)
  val dao=OfflineQueueDb.get(context).events()
  val event=OfflineEvent(eventId=eventId,organizationId=session.organization,memberId=session.member,siteId=session.sites.single().id,aggregateType="n1_probe",payloadJson="{\"android\":true}",deviceSequence=3,createdAtEpochMs=System.currentTimeMillis())
  runBlocking { assertTrue(dao.enqueue(event)) }
  compose.onNodeWithText("Synchroniser").performScrollTo().performClick()
  val state=runBlocking{
   var state=dao.get(eventId)?.state
   repeat(30){if(state!="acknowledged"){ZippleSyncSession.schedule(context);delay(1000);state=dao.get(eventId)?.state}}
   state
  }
  assertEquals("acknowledged",state)
  compose.onNodeWithText("Déconnexion").performScrollTo().performClick()
  compose.onNodeWithText("Se connecter").assertExists()
  runBlocking {
   var revoked=false
   repeat(10){if(!revoked){delay(1000);revoked=runCatching{ZippleAuth(BuildConfig.ZIPPLE_API_URL).sync(session,event)}.isFailure}}
   assertTrue("Old session rejected after logout",revoked)
  }
  assertNull(ZippleSyncSession.current)
 }
}
