package cm.naxa.zipple
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.*
import org.junit.Assume.assumeTrue
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class Bulk2LiveDeviceTest {
 @get:Rule val compose=createAndroidComposeRule<MainActivity>()
 @Test fun nativeSharedBillPersistsEachPayment(){
  val args=InstrumentationRegistry.getArguments()
  assumeTrue("Dedicated disposable business recipe",args.getString("zippleBulk2Local")=="1")
  assertEquals("https://127.0.0.1:4443/zipple-business",BuildConfig.ZIPPLE_BUSINESS_API_URL)
  val password=requireNotNull(args.getString("zippleFixturePassword"));val login=requireNotNull(args.getString("zippleFixtureLogin"))
  val itemNo=requireNotNull(args.getString("zippleSplitNumber"));val amountNo=requireNotNull(args.getString("zippleAmountNumber"));val mixedNo=requireNotNull(args.getString("zippleMixedNumber"))
  fun awaitText(text:String){compose.waitUntil(30000){compose.onAllNodesWithText(text,substring=false).fetchSemanticsNodes().isNotEmpty()}}
  fun click(text:String){awaitText(text);compose.onNodeWithText(text,substring=false).performScrollTo().performClick()}
  fun input(text:String,value:String){awaitText(text);compose.onNodeWithText(text,substring=false).performScrollTo().performTextInput(value)}
  input("Identifiant",login);input("Mot de passe",password);click("Se connecter")
  awaitText("Configurer votre code local");input("PIN","1234");click("Continuer")
  awaitText("Addition fractionnée");click("Addition fractionnée")
  click("Caisse principale");click("#"+itemNo+" · 3000 FCFA")
  input("Personne ou groupe","Personne A");input("Assiette native · 3 · 1000 FCFA","1")
  click("Confirmer le règlement partiel reçu");awaitText("Réessayer le même règlement")
  click("Commandes");click("Addition fractionnée");click("Réessayer le même règlement");awaitText("Règlement confirmé — solde : 2000 FCFA")
  awaitText("Assiette native · 2 · 1000 FCFA")
  input("Personne ou groupe","Personne B");input("Assiette native · 2 · 1000 FCFA","2")
  click("Confirmer le règlement partiel reçu");awaitText("Règlement confirmé — solde : 0 FCFA")
  click("#"+amountNo+" · 800 FCFA");click("Montant libre")
  input("Personne ou groupe","Groupe A");input("Montant partiel FCFA","300")
  click("Confirmer le règlement partiel reçu");awaitText("Règlement confirmé — solde : 500 FCFA")
  input("Personne ou groupe","Groupe B");input("Montant partiel FCFA","500")
  click("Confirmer le règlement partiel reçu");awaitText("Règlement confirmé — solde : 0 FCFA")
  click("#"+mixedNo+" · 1000 FCFA");click("Paiement complet multi-moyens")
  input("Montant du règlement 1","200");input("Montant du règlement 2","300");click("Ajouter un règlement");input("Montant du règlement 3","500");click("Confirmer le paiement complet reçu");awaitText("Règlement confirmé — solde : 0 FCFA")
  click("Déconnexion")
  awaitText("Se connecter")
 }
}
