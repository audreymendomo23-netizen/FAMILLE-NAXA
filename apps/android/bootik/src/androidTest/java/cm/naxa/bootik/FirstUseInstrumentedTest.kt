package cm.naxa.bootik
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FirstUseInstrumentedTest{
 @get:Rule val rule=createComposeRule()
 private fun state(discovery:Boolean,tour:Boolean)=JSONObject().put("discovery_completed",discovery).put("tour_completed",tour).put("documents",JSONArray())
 @Test fun walksAllDiscoveryAndTourCardsAndConfirmsOnce(){
  val completed=mutableListOf<String>()
  rule.setContent{
   var done by remember{mutableStateOf(false)}
   Column(Modifier.verticalScroll(rememberScrollState())){
    if(done)androidx.compose.material3.Text("Espace ouvert") else BootikFirstUseContent("fixture","manager",{state(false,false)},{p->
     val step=p.getString("step");completed.add(step);if(step=="discovery")state(true,false) else state(true,true)
    },{done=true},{})
   }
  }
  rule.onNodeWithText("Votre activité, votre gestion").assertExists()
  for(title in listOf("Opérations et stocks","Pilotage au quotidien","Votre organisation reste protégée")){
   rule.onNodeWithText("Suivant").performScrollTo().performClick();rule.onNodeWithText(title).assertExists()
  }
  rule.onNodeWithText("Commencer").performScrollTo().performClick()
  rule.onNodeWithText("Tableau de bord").assertExists()
  for(title in listOf("Caisse et ventes","Stock et achats","Sécurité et abonnement","Assistance")){
   rule.onNodeWithText("J’ai compris").performScrollTo().performClick();rule.onNodeWithText(title).assertExists()
  }
  rule.onNodeWithText("Terminer").performScrollTo().performClick()
  rule.onNodeWithText("Espace ouvert").assertExists()
  rule.runOnIdle{assertEquals(listOf("discovery","tour"),completed)}
 }
 @Test fun completedServerStateDoesNotReplayTour(){
  rule.setContent{
   var done by remember{mutableStateOf(false)}
   Column{if(done)androidx.compose.material3.Text("Espace ouvert") else BootikFirstUseContent("completed","staff",{state(true,true)},{error("Unexpected write")},{done=true},{})}
  }
  rule.onNodeWithText("Espace ouvert").assertExists()
 }
}
