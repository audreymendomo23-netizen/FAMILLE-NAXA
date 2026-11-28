package cm.naxa.grillad
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class NativeConnectedRecipeTest {
 @get:Rule val ui=createAndroidComposeRule<MainActivity>()
 private fun id()=UUID.randomUUID().toString()
 @Test fun realNativeLoginPinRolesAndDurableFifo(){
  check(BuildConfig.DEBUG&&BuildConfig.GRILLAD_LOCAL_RECIPE&&BuildConfig.GRILLAD_API_URL=="http://127.0.0.1:4182/functions/v1/grillad")
  val context=InstrumentationRegistry.getInstrumentation().targetContext
  val accounts=JSONObject(File(context.filesDir,"grillad-recipe-accounts.json").readText())
  ui.onNodeWithText("English",substring=false).performClick()
  ui.onNodeWithText("Professional sign in",substring=false).assertExists()
  ui.onNodeWithText("Fulfulde",substring=false).performClick()
  ui.onNodeWithText("Naatugol e kisal",substring=false).assertExists()
  ui.onNodeWithText("Naatu",substring=false).assertExists()
  ui.onNodeWithText("Français",substring=false).performClick()
  ui.onNodeWithText("Connexion professionnelle",substring=false).assertExists()
  val seller=accounts.getJSONObject("seller")
  ui.onAllNodes(hasSetTextAction())[0].performTextInput(seller.getString("phone"))
  ui.onAllNodes(hasSetTextAction())[1].performTextInput(seller.getString("password"))
  ui.onNodeWithText("Se connecter").performClick()
  ui.waitUntil(60000){ui.onAllNodesWithText("Créer votre code local").fetchSemanticsNodes().isNotEmpty()}
  ui.onAllNodes(hasSetTextAction())[0].performTextInput("1357");ui.onAllNodes(hasSetTextAction())[1].performTextInput("1357")
  ui.onNodeWithText("Enregistrer et ouvrir").performClick()
  ui.waitUntil(60000){ui.onAllNodesWithText("Nouvelle vente").fetchSemanticsNodes().isNotEmpty()}
  ui.onNodeWithText("Verrouiller").performClick()
  ui.waitUntil(10000){ui.onAllNodesWithText("Déverrouiller GRILLAD").fetchSemanticsNodes().isNotEmpty()}
  ui.onAllNodes(hasSetTextAction())[0].performTextInput("1357");ui.onNodeWithText("Déverrouiller",substring=false).performClick()
  ui.waitUntil(60000){ui.onAllNodesWithText("Nouvelle vente").fetchSemanticsNodes().isNotEmpty()}
  ui.onNodeWithText("Déconnexion").performClick()
  ui.waitUntil(30000){ui.onAllNodesWithText("Connexion professionnelle").fetchSemanticsNodes().isNotEmpty()}
  val api=ConnectedApi(BuildConfig.GRILLAD_API_URL,BuildConfig.GRILLAD_PUBLIC_KEY)
  val org="d2000000-0000-0000-0000-000000000001";val site="d3000000-0000-0000-0000-000000000001";val other="d3000000-0000-0000-0000-000000000002"
  runBlocking {
   val sessions=mutableMapOf<String,JSONObject>()
   try{
    for(role in listOf("owner","manager","seller")){
     val a=accounts.getJSONObject(role);val s=api.call(obj("action" to "login","phone" to a.getString("phone"),"password" to a.getString("password"),"installation" to id(),"platform" to "android")) as JSONObject
     assertEquals(a.getString("id"),s.getString("user_id"));assertTrue(rows(s.getJSONArray("sites")).any{it.optString("site")==site&&it.optString("role")==role});assertEquals(role=="owner",rows(s.getJSONArray("sites")).any{it.optString("site")==other});sessions[role]=s
    }
    suspend fun call(role:String,b:JSONObject)=api.call(b,sessions.getValue(role).getString("access"))
    suspend fun mutate(role:String,op:String,p:JSONObject,event:String=id())=call(role,obj("action" to "mutate","org" to org,"site" to site,"event" to event,"operation" to op,"payload" to p))
    val item=id();mutate("owner","add_item",obj("name" to "Native CI","family" to "Poulet","price" to 1000,"cost" to 400),item);mutate("manager","prepare",obj("item" to item,"qty" to 3));mutate("manager","open_cash",obj("opening" to 0))
    val user=sessions.getValue("seller").getString("user_id");val journal=GrilladUncertainJournal(context)
    val day=dayKey();val snapshot=call("owner",obj("action" to "snapshot","org" to org,"site" to site,"from" to day,"to" to day)) as JSONObject
    val cash=snapshot.getJSONObject("cash").getString("id")
    fun batch()=obj("action" to "offline_batch","org" to org,"site" to site,"event" to id(),"day" to day,"cash" to cash,"lines" to JSONArray().put(obj("event" to id(),"operation" to "sell","payload" to obj("item" to item,"qty" to 1,"price" to 1000,"received" to 1000))))
    val first=batch();val second=batch();journal.appendDraft(user,first);journal.appendDraft(user,second);journal.appendDraft(user,second);assertEquals(2,journal.count(user));val reopened=GrilladUncertainJournal(context);assertEquals(first.toString(),reopened.read(user).toString());assertNull(reopened.read(sessions.getValue("manager").getString("user_id")))
    assertTrue(runCatching{reopened.clear(user,second.getString("event"))}.isFailure)
    assertTrue(runCatching{reopened.appendDraft(user,batch().put("site",other))}.isFailure)
    for(req in listOf(first,second)){val x=call("seller",req) as JSONObject;assertEquals(1,x.getInt("count"));assertEquals(x.toString(),call("seller",req).toString());reopened.clear(user,req.getString("event"))}
    assertEquals(0,reopened.count(user));val final=call("owner",obj("action" to "snapshot","org" to org,"site" to site,"from" to day,"to" to day)) as JSONObject;assertEquals(2000L,final.getJSONObject("finance").getLong("ca"))
    val denied=runCatching{call("seller",obj("action" to "snapshot","org" to org,"site" to other,"from" to day,"to" to day))}.exceptionOrNull();assertEquals(403,(denied as GrilladApiError).status)
   }finally{for(s in sessions.values)runCatching{api.call(obj("action" to "logout"),s.getString("access"))}}
  }
 }
}
