package cm.naxa.zipple
import androidx.compose.ui.test.*
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.json.JSONArray
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
@RunWith(AndroidJUnit4::class)
class Bulk3DeviceTest {
 @get:Rule val compose=createComposeRule()
 @Test fun nativeSupplierFormAndServerConfirmation(){
  val calls=mutableListOf<Pair<String,JSONObject>>()
  compose.setContent{Column(Modifier.verticalScroll(rememberScrollState())){Bulk3Screen("promoteur",true,false){a,b->calls.add(a to JSONObject(b.toString()));if(a=="supplier_add")"fixture-id" else JSONObject()}}}
  compose.onNodeWithText("Confirmer",substring=false).assertIsNotEnabled()
  compose.waitUntil(10000){compose.onAllNodes(hasText("Nom",substring=false) and isEnabled()).fetchSemanticsNodes().size==1}
  compose.onNodeWithText("Nom",substring=false).performScrollTo().performTextInput("Grossiste test")
  compose.onNodeWithText("Délai en jours").performScrollTo().performTextInput("30")
  compose.onNodeWithText("Confirmer",substring=false).assertIsEnabled().performScrollTo().performClick()
  compose.waitUntil(10000){compose.onAllNodesWithText("Opération confirmée",substring=false).fetchSemanticsNodes().isNotEmpty()}
  compose.onNodeWithText("Opération confirmée",substring=false).performScrollTo().assertIsDisplayed()
  compose.runOnIdle{val saved=calls.single{it.first=="supplier_add"}.second;assertEquals("Grossiste test",saved.getString("name"));assertEquals(30,saved.getInt("terms_days"));assertTrue(saved.getString("request_id").isNotBlank())}
 }
 @Test fun nativeBalancedAllocationAndQuantityValidation(){
  val a="a";val b="b";val source=JSONObject().put("kind","expense").put("source_id","s").put("amount_xaf","2500").put("label","Dépense")
  val ledger=JSONObject().put("accounts",JSONArray().put(JSONObject().put("id",a).put("code","D")).put(JSONObject().put("id",b).put("code","C"))).put("pending",JSONArray().put(source))
  val data=ND(mapOf("ledger_snapshot" to ledger))
  val form=bulk3Groups.first{it.id=="ledger"}.forms.first{it.action=="ledger_post_split"}
  val values=mapOf("source" to "expense:s","journal" to "OD","label" to "Dépense validée")
  val rows=listOf(mapOf("account_id" to a,"side" to "debit","amount_xaf" to "2500"),mapOf("account_id" to b,"side" to "credit","amount_xaf" to "2500"))
  val result=bulk3Body(form,data,values,rows);assertEquals("expense",result.getString("kind"));assertEquals("2500",result.getJSONArray("lines").getJSONObject(0).getString("amount_xaf"))
  assertTrue(runCatching{bulk3Body(form,data,values,listOf(rows[0],rows[1]+("amount_xaf" to "2499")))}.isFailure)
  assertTrue(runCatching{bulk3Body(form,data,values,listOf(rows[0],rows[1]+("account_id" to "other-site")))}.isFailure)
  assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",evidenceHash("abc".toByteArray()))
 }
 @Test fun everyNativeActionHasServerContract(){
  for(g in bulk3Groups){g.loads.forEach{assertTrue(ZippleBusinessPolicy.allowed(it))};g.forms.forEach{assertTrue(ZippleBusinessPolicy.allowed(it.action))}}
 }
}
