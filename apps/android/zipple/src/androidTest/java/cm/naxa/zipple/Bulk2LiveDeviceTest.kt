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
import org.json.JSONObject
import org.json.JSONArray
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.delay
import java.util.UUID
import java.time.LocalDate
import java.time.ZoneId

@RunWith(AndroidJUnit4::class)
class Bulk2LiveDeviceTest {
 @get:Rule val compose=createAndroidComposeRule<MainActivity>()
 @Test fun nativeSharedBillPersistsEachPayment(){
  val args=InstrumentationRegistry.getArguments()
  assumeTrue("Dedicated disposable business recipe",args.getString("zippleBulk2Local")=="1")
  assertEquals("https://127.0.0.1:4443/zipple-business",BuildConfig.ZIPPLE_BUSINESS_API_URL)
  val password=requireNotNull(args.getString("zippleFixturePassword"));val login=requireNotNull(args.getString("zippleFixtureLogin"))
  val itemNo=requireNotNull(args.getString("zippleSplitNumber"));val amountNo=requireNotNull(args.getString("zippleAmountNumber"));val mixedNo=requireNotNull(args.getString("zippleMixedNumber"))
  fun step(label:String,block:()->Unit){try{block();android.util.Log.i("ZIPPLE_BULK2_TEST","PASS "+label)}catch(e:Throwable){throw AssertionError("ZIPPLE_BULK2_STEP_FAILED: "+label,e)}}
  fun awaitText(text:String)=step("await "+text){compose.waitUntil(30000){compose.onAllNodesWithText(text,substring=false).fetchSemanticsNodes().isNotEmpty()}}
  fun click(text:String)=step("click "+text){val matcher=hasText(text,substring=false) and hasClickAction() and isEnabled();compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1};compose.onNode(matcher).performScrollTo().performClick()}
  fun input(text:String,value:String)=step("input "+text){val matcher=hasText(text,substring=false) and hasSetTextAction();compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1};compose.onNode(matcher).performScrollTo().performTextInput(value)}
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
  click("Confirmer le règlement partiel reçu")
  step("socket-loss recovery or already confirmed"){val confirmed=hasText("Règlement confirmé — solde : 500 FCFA",substring=false);val retry=hasText("Réessayer le même règlement",substring=false) and hasClickAction() and isEnabled();compose.waitUntil(30000){compose.onAllNodes(confirmed).fetchSemanticsNodes().isNotEmpty()||compose.onAllNodes(retry).fetchSemanticsNodes().size==1};if(compose.onAllNodes(confirmed).fetchSemanticsNodes().isEmpty()){click("Réessayer le même règlement")};awaitText("Règlement confirmé — solde : 500 FCFA")}

  input("Personne ou groupe","Groupe B");input("Montant partiel FCFA","500")
  click("Confirmer le règlement partiel reçu");awaitText("Règlement confirmé — solde : 0 FCFA")
  click("#"+mixedNo+" · 1000 FCFA");click("Paiement complet multi-moyens")
  input("Montant du règlement 1","200");input("Montant du règlement 2","300");click("Ajouter un règlement");input("Montant du règlement 3","500");click("Confirmer le paiement complet reçu");awaitText("Règlement confirmé — solde : 0 FCFA")
  // Reuse the same authenticated UI/session and local Edge stack from Bulk 2.
  click("ERP 360° — gestion complète")
  input("Nom","Fournisseur ERP natif")
  input("Délai en jours","30")
  click("Confirmer");awaitText("Opération confirmée")
  val session=checkNotNull(ZippleSyncSession.current);val site=session.sites.single().id
  val business=ZippleBusiness(BuildConfig.ZIPPLE_BUSINESS_API_URL,true)
  fun body(vararg fields:Pair<String,Any?>)=JSONObject().also{j->fields.forEach{(k,v)->j.put(k,v?:JSONObject.NULL)}}
  fun uid()=UUID.randomUUID().toString()
  val ctx=InstrumentationRegistry.getInstrumentation().targetContext
  val dao=OfflineQueueDb.get(ctx).events()
  lateinit var eventId:String;lateinit var nextEventId:String
  step("ERP live procurement, recipe, production, ledger and evidence"){runBlocking{
   suspend fun api(action:String,vararg fields:Pair<String,Any?>)=business.call(session,site,action,body(*fields))
   val suppliers=(api("procurement_snapshot") as JSONObject).rows("suppliers")
   val supplier=suppliers.single{it.optString("name")=="Fournisseur ERP natif"}.getString("id")
   val ingredient=api("ingredient_add","name" to "Farine ERP native","sku" to "NATIVE-ERP","unit" to "kg","reorder_milli" to 100L,"supplier_whatsapp" to "") as String
   val purchase=api("purchase_create","supplier_id" to supplier,"ingredient_id" to ingredient,"request_id" to uid(),"reference" to "NATIVE-PURCHASE","qty_milli" to 3000L,"total_xaf" to 3000L) as String
   api("purchase_receive","purchase_id" to purchase,"request_id" to uid(),"qty_milli" to 2000L,"label" to "NATIVE-LOT-A","expires_on" to null)
   api("purchase_receive","purchase_id" to purchase,"request_id" to uid(),"qty_milli" to 1000L,"label" to "NATIVE-LOT-B","expires_on" to null)
   api("supplier_pay","purchase_id" to purchase,"request_id" to uid(),"amount_xaf" to 1000L,"method" to "bank","reference" to "NATIVE-SUPPLIER")
   val p=(api("procurement_snapshot") as JSONObject).rows("purchases").single{it.getString("id")==purchase}
   assertEquals(3000L,p.getLong("received_milli"));assertEquals(1000L,p.getLong("paid_xaf"))
   val product=api("menu_add","name" to "Pain ERP natif","post" to "kitchen","price_xaf" to 1500,"qty" to 0) as String
   api("recipe_define","item_id" to product,"components" to JSONArray().put(body("ingredient_id" to ingredient,"qty_milli" to 500L)))
   val produced=api("produce","item_id" to product,"request_id" to uid(),"servings" to 2) as JSONObject
   assertEquals(1000L,produced.getLong("cost_xaf"))
   val stock=api("erp_snapshot") as JSONObject
   assertEquals(2000L,stock.rows("ingredients").single{it.getString("id")==ingredient}.getLong("available_milli"))
   val lot=stock.rows("lots").first{it.optString("lot_label")=="NATIVE-LOT-A"}
   val today=LocalDate.now(ZoneId.of("Africa/Douala")).toString()
   val expense=api("expense_record","request_id" to uid(),"category" to "rent","label" to "Dépense ERP native","amount_xaf" to 750L,"method" to "bank","reference" to "NATIVE-EXPENSE","expense_date" to today) as String
   val debit=api("ledger_account_add","code" to "NATIVE-D","label" to "Charges natives","section" to "Charges") as String
   val credit=api("ledger_account_add","code" to "NATIVE-C","label" to "Banque native","section" to "Trésorerie") as String
   api("ledger_classify","account_id" to debit,"kind" to "expense","reason" to "Classification validée test")
   api("ledger_classify","account_id" to credit,"kind" to "asset","reason" to "Classification validée test")
   val mapping=api("ledger_mapping_set","request_id" to uid(),"kind" to "expense","expected_version" to 0,"debit_account" to debit,"credit_account" to credit,"journal" to "OD","reason" to "Affectation comptable test") as String
   val request=uid()
   val entry=api("ledger_post_mapped","mapping_id" to mapping,"source_id" to expense,"request_id" to request,"label" to "Charge native justifiée") as String
   assertEquals(entry,api("ledger_post_mapped","mapping_id" to mapping,"source_id" to expense,"request_id" to request,"label" to "Charge native justifiée"))
   val statement=api("ledger_statement","from" to today,"to" to today) as JSONObject
   assertEquals("750",statement.getString("expenses_xaf"));assertEquals("0",statement.getString("journal_gap_xaf"))
   val png="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="
   val document=api("finance_document_add","request_id" to uid(),"kind" to "expense","source_id" to expense,"label" to "Justificatif ERP natif","mime" to "image/png","base64" to png) as String
   val proof=api("finance_document_read","document_id" to document) as JSONObject
   assertEquals(png,proof.getString("base64"));assertEquals(evidenceHash(android.util.Base64.decode(png,android.util.Base64.DEFAULT)),proof.getString("sha256_hex"))
   // Stale physical count and a second valid expense. The actual Room/WorkManager queue must stop at conflict.
   eventId=uid();nextEventId=uid();val now=System.currentTimeMillis()
   val stale=body("lot_id" to lot.getString("id"),"expected_milli" to (lot.getLong("remaining_milli")+100),"counted_milli" to lot.getLong("remaining_milli"),"reason" to "Ancien comptage hors ligne")
   val second=body("category" to "other","label" to "Dépense après revue native","amount_xaf" to 100L,"method" to "bank","reference" to "NATIVE-AFTER-REVIEW","expense_date" to today)
   dao.enqueue(OfflineEvent(eventId=eventId,organizationId=session.organization,memberId=session.member,siteId=site,aggregateType="erp_count_lot",payloadJson=stale.toString(),deviceSequence=now,createdAtEpochMs=now))
   dao.enqueue(OfflineEvent(eventId=nextEventId,organizationId=session.organization,memberId=session.member,siteId=site,aggregateType="erp_expense_record",payloadJson=second.toString(),deviceSequence=now+1,createdAtEpochMs=now))
   ZippleSyncSession.schedule(ctx)
   repeat(120){if(dao.get(eventId)?.state=="conflict")return@repeat;delay(250)}
   assertEquals("conflict",dao.get(eventId)?.state);assertEquals("queued",dao.get(nextEventId)?.state)
  }}
  click("Revue hors connexion")
  input("Motif de l’abandon","Stock actualisé, comptage à refaire")
  click("Abandonner après vérification");awaitText("Revue confirmée.")
  step("ERP native Room review unblocks ordered queue"){runBlocking{
   repeat(120){if(dao.get(nextEventId)?.state=="acknowledged")return@repeat;delay(250)}
   assertEquals("reviewed",dao.get(eventId)?.state);assertEquals("acknowledged",dao.get(nextEventId)?.state)
   val review=business.call(session,site,"erp_review_snapshot") as JSONObject
   assertTrue(review.rows("events").any{it.getString("event_id")==eventId&&!it.isNull("reviewed_at")&&it.getString("state")=="conflict"})
  }}
  // Actual Compose UI and persisted Edge response, not a mock view.
  click("Profil")
  step("profile edit"){val matcher=hasText("Nom affiché",substring=false) and hasSetTextAction();compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1};compose.onNode(matcher).performScrollTo().performTextReplacement("Profil ERP natif")}
  input("Téléphone professionnel","699123456");click("Enregistrer le profil");awaitText("Opération enregistrée")
  click("Support professionnel");input("Intitulé","Ticket ERP natif");input("Description","Demande interne native");input("Catégorie","technical");click("Créer");awaitText("Ticket ERP natif · Ouvert")
  click("Ouvrir le dossier");input("Message ou observation","Réponse native");click("Envoyer");awaitText("Opération enregistrée")
  click("En cours");awaitText("Ticket ERP natif · En cours");click("Terminé");awaitText("Ticket ERP natif · Terminé")
  click("Notifications");awaitText("Ticket ERP natif · Nouveau")
  click("Équipe");awaitText("Employé : —")
  click("Plannings");awaitText("Historique")
  click("Objectifs");awaitText("Historique")
  click("Formation");awaitText("Historique")
  click("Feedback interne");awaitText("Historique")
  click("Absences et rémunérations");input("Début AAAA-MM-JJ","2027-02-01");input("Fin AAAA-MM-JJ","2027-02-02");input("Motif professionnel","Congé ERP natif");click("Soumettre la demande");awaitText("Absence · Profil ERP natif · À valider");input("Motif de décision","Planning natif contrôlé");click("Approuvé");awaitText("Absence · Profil ERP natif · Approuvé")
  click("Filtrer par statut : Tous");click("À valider");awaitText("Aucune demande correspondante.")
  click("Réinitialiser les filtres");awaitText("Absence · Profil ERP natif · Approuvé")
  click("Type de demande : Absence");click("Prime")
  input("Montant FCFA","4500");input("Motif professionnel","Prime ERP native");click("Soumettre la demande");awaitText("Prime · Profil ERP natif · À valider")
  input("Motif de décision","Prime contrôlée native");click("Approuvé");awaitText("Prime · Profil ERP natif · Approuvé")
  click("Filtrer par type : Tous");click("Prime");awaitText("Montants approuvés dans cette sélection (hors absences, non versés automatiquement) : 4500 FCFA")
  click("Réinitialiser les filtres")
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_QA_CASE_PARTIAL B5-005 B5-007 NATIVE_HR_FILTERS_PASS")
  click("ZIPPLE Intelligence");awaitText("Analyse explicable, sans assistant génératif connecté.")
  step("create native loyalty fixture through Edge"){runBlocking{
   business.call(session,site,"customer_add",body("name" to "Client QR natif","phone" to ""))
  }}
  click("Tables");input("Nom de la table ou du point","Table QR native");click("Créer un point de commande")
  step("native order QR creation and rotation"){
   val matcher=hasContentDescription("QR de commande",substring=false)
   compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1}
   compose.onNode(matcher).performScrollTo().assertIsDisplayed()
   awaitText("Enregistrer le QR de commande");awaitText("Partager le QR de commande")
   click("Renouveler le QR : Table QR native")
   compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1}
   compose.onNode(matcher).performScrollTo().assertIsDisplayed()
  }
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_NATIVE_TABLE_QR_PASS")
  click("Salles et réservations")
  input("Nom de la zone","Salle native test");click("Créer la zone");awaitText("Configuration enregistrée")
  click("Table à configurer : —");click("Table QR native")
  click("Zone de la table : —");click("Salle native test")
  step("native seating capacity input"){val matcher=hasText("Nombre de places",substring=false) and hasSetTextAction();compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1};compose.onNode(matcher).performScrollTo().performTextReplacement("6")}
  click("Enregistrer la table");awaitText("Table QR native · 6 places")
  val tomorrow=LocalDate.now(ZoneId.of("Africa/Douala")).plusDays(1).toString()
  input("Nom de réservation","Réservation native");input("Début AAAA-MM-JJ HH:mm",tomorrow+" 12:00");input("Fin AAAA-MM-JJ HH:mm",tomorrow+" 13:00")
  click("Réserver la table");awaitText("Réservation native · Réservée")
  input("Nom de réservation","Conflit natif");click("Réserver la table");awaitText("Conflit de disponibilité ou de capacité — vérifiez la table et le créneau.")
  click("Annuler : Réservation native");awaitText("Réservation native · Annulée")
  step("prepare imminent booking through live Edge"){runBlocking{
   val rooms=business.call(session,site,"floor_snapshot") as JSONObject
   val table=rooms.rows("tables").single{it.optString("label")=="Table QR native"}
   val now=java.time.Instant.now()
   business.call(session,site,"reserve_table",body("table_id" to table.getString("id"),"guest_name" to "Accueil natif","party_size" to 2,"starts_at" to now.plusSeconds(600).toString(),"ends_at" to now.plusSeconds(3600).toString(),"request_id" to uid()))
  }}
  click("Actualiser les salles");awaitText("Accueil natif · Réservée")
  click("Accueillir : Accueil natif");awaitText("Accueil natif · Installée")
  step("seated booking opened actual session"){runBlocking{
   val snap=business.call(session,site,"snapshot") as JSONObject
   val table=snap.rows("tables").single{it.optString("label")=="Table QR native"}
   assertFalse("reservation must open session",table.isNull("session_id"))
   val openRooms=business.call(session,site,"floor_snapshot") as JSONObject
   assertTrue("booking is seated before closing",openRooms.rows("reservations").any{it.optString("guest_name")=="Accueil natif"&&it.optString("state")=="seated"})
   assertEquals("close reservation table",true,business.call(session,site,"table_close",body("table_session_id" to table.getString("session_id"))))
  }}
  input("Nom en attente","Attente native");click("Ajouter à l’attente");awaitText("Attente native · 2");click("Retirer de l’attente : Attente native")
  step("wait for cancelled waiting entry"){compose.waitUntil(30000){compose.onAllNodesWithText("Attente native · 2",substring=false).fetchSemanticsNodes().isEmpty()}}
  input("Nom en attente","Installation native");click("Ajouter à l’attente");awaitText("Installation native · 2");click("Installer : Installation native")
  step("waitlist seated opens actual table"){compose.waitUntil(30000){compose.onAllNodesWithText("Installation native · 2",substring=false).fetchSemanticsNodes().isEmpty()};runBlocking{
    val snap=business.call(session,site,"snapshot") as JSONObject
    val table=snap.rows("tables").single{it.optString("label")=="Table QR native"}
    assertFalse("waitlist must open session",table.isNull("session_id"))
    assertEquals("close waiting table",true,business.call(session,site,"table_close",body("table_session_id" to table.getString("session_id"))))
  }}
  step("native room persistence"){runBlocking{
   val rooms=business.call(session,site,"floor_snapshot") as JSONObject
   val zone=rooms.rows("zones").single{it.optString("name")=="Salle native test"}
   val table=rooms.rows("tables").single{it.optString("label")=="Table QR native"}
   assertEquals("persisted table zone",zone.getString("id"),table.getString("zone_id"));assertEquals("persisted seating capacity",6,table.getInt("seats"))
   assertTrue("cancelled booking must persist",rooms.rows("reservations").any{it.optString("guest_name")=="Réservation native"&&it.optString("state")=="cancelled"})
   assertFalse("cancelled waiting entry must disappear",rooms.rows("waitlist").any{it.optString("guest_name")=="Attente native"})
   assertTrue("completed booking must persist after table close",rooms.rows("reservations").any{it.optString("guest_name")=="Accueil natif"&&it.optString("state")=="completed"})
   assertFalse("completed waiting entry must disappear",rooms.rows("waitlist").any{it.optString("guest_name")=="Installation native"})
  }}
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_NATIVE_FLOOR_RESERVATIONS_WAITLIST_PASS")
  var firstNumber="";var secondNumber=""
  step("prepare two served table bills through real Edge"){runBlocking{
    val source=(business.call(session,site,"table_create",body("label" to "Addition source native")) as JSONObject).getString("id")
    val target=(business.call(session,site,"table_create",body("label" to "Addition cible native")) as JSONObject).getString("id")
    val sourceSession=business.call(session,site,"table_open",body("table_id" to source)) as String
    val targetSession=business.call(session,site,"table_open",body("table_id" to target)) as String
    val item=business.call(session,site,"menu_add",body("name" to "Addition test natif","post" to "kitchen","price_xaf" to 500,"qty" to 2)) as String
    suspend fun served(tableSession:String):String{
      val order=business.call(session,site,"order_create",body("channel" to "table","table_session_id" to tableSession,"request_id" to uid(),"lines" to org.json.JSONArray().put(body("item_id" to item,"qty" to 1)))) as JSONObject
      for(next in listOf("preparing","ready","served"))business.call(session,site,"line_advance",body("order_id" to order.getString("id"),"item_id" to item,"next" to next))
      val bill=business.call(session,site,"table_bill",body("table_session_id" to tableSession)) as JSONObject
      return bill.rows("orders").single().getString("number")
    }
    firstNumber=served(sourceSession);secondNumber=served(targetSession)
  }}
  click("Additions de table");click("Table source : —");click("Addition source native")
  awaitText("Reste à régler : 500 FCFA")
  click("Commande à transférer : —");click("#"+firstNumber)
  click("Table destinataire : —");click("Addition cible native");input("Motif du transfert","Transfert natif contrôlé")
  click("Transférer l’addition");awaitText("Transfert confirmé");awaitText("Reste à régler : 0 FCFA")
  click("Table source : Addition source native");click("Addition cible native");awaitText("Reste à régler : 1000 FCFA")
  click("Sélectionner #"+firstNumber);click("Sélectionner #"+secondNumber);awaitText("Total sélectionné : 1000 FCFA")
  click("Confirmer le règlement groupé reçu");awaitText("Règlement groupé confirmé");awaitText("Reste à régler : 0 FCFA")
  step("close settled transferred table sessions"){runBlocking{
    val snap=business.call(session,site,"snapshot") as JSONObject
    for(label in listOf("Addition source native","Addition cible native")){
      val table=snap.rows("tables").single{it.optString("label")==label}
      assertEquals(true,business.call(session,site,"table_close",body("table_session_id" to table.getString("session_id"))))
    }
  }}
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_NATIVE_TABLE_BILL_TRANSFER_AND_GROUP_PASS")
  click("Fidélité et parrainage");awaitText("Points non monétaires ; avantages sur commande ultérieure réglée.")
  click("Client : —");click("Client QR natif")
  click("Générer la carte de fidélité");awaitText("Opération enregistrée")
  step("native loyalty card QR displayed"){val matcher=hasContentDescription("QR de carte de fidélité",substring=false);compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1};compose.onNode(matcher).performScrollTo().assertIsDisplayed()}
  click("Générer le code personnel");awaitText("Opération enregistrée")
  step("native referral QR displayed"){val matcher=hasContentDescription("QR de parrainage",substring=false);compose.waitUntil(30000){compose.onAllNodes(matcher).fetchSemanticsNodes().size==1};compose.onNode(matcher).performScrollTo().assertIsDisplayed()}
  step("distinct persisted opaque card and referral"){runBlocking{
   val snap=business.call(session,site,"loyalty_snapshot") as JSONObject
   val client=snap.rows("customers").single{it.optString("label")=="Client QR natif"}
   val card=client.getString("card");val code=client.getString("code")
   assertNotEquals(card,code);assertEquals(card,UUID.fromString(card).toString());assertEquals(code,UUID.fromString(code).toString())
  }}
  awaitText("Enregistrer la carte QR");awaitText("Partager la carte QR")
  awaitText("Enregistrer le QR de parrainage");awaitText("Partager le QR de parrainage")
  step("native QR PNG and limited content URI share"){runBlocking{
   val snap=business.call(session,site,"loyalty_snapshot") as JSONObject
   val client=snap.rows("customers").single{it.optString("label")=="Client QR natif"}
   fun decoded(bytes:ByteArray):String{
    val bmp=checkNotNull(android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.size))
    try{val pixels=IntArray(bmp.width*bmp.height);bmp.getPixels(pixels,0,bmp.width,0,0,bmp.width,bmp.height)
     return com.google.zxing.qrcode.QRCodeReader().decode(com.google.zxing.BinaryBitmap(com.google.zxing.common.HybridBinarizer(com.google.zxing.RGBLuminanceSource(bmp.width,bmp.height,pixels)))).text
    }finally{bmp.recycle()}
   }
   for(token in listOf(client.getString("card"),client.getString("code"))){
    assertEquals(token,decoded(zippleQrPng(token)))
    val intent=zippleQrShareIntent(ctx,token)
    assertEquals(android.content.Intent.ACTION_SEND,intent.action);assertEquals("image/png",intent.type)
    assertTrue(intent.flags and android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
    assertEquals(0,intent.flags and android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    val uri=checkNotNull(intent.clipData).getItemAt(0).uri
    assertEquals("content",uri.scheme);assertEquals(ctx.packageName+".qrshare",uri.authority)
    assertFalse(uri.toString().contains(token))
    assertEquals(token,decoded(checkNotNull(ctx.contentResolver.openInputStream(uri)).use{it.readBytes()}))
   }
  }}
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_NATIVE_QR_PNG_SHARE_CONTRACT_PASS")
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_NATIVE_LOYALTY_QR_DISPLAY_PASS")
  click("Livraison Restaurant");awaitText("Préparation des zones et livreurs ; commande externe non activée.")
  input("Nom de zone","Zone ERP native");input("Périmètre et consignes","Secteur test");input("Frais FCFA","500");click("Enregistrer la zone");awaitText("Opération enregistrée")
  click("Modifier la zone : Zone ERP native")
  input("Frais FCFA","750");click("Zone active dans le projet : Oui");click("Non");click("Enregistrer la zone");awaitText("Zone ERP native · 750 FCFA · Secteur test · Inactive")
  click("Livreur de l'établissement : —");click("Profil ERP natif");click("Enregistrer le livreur");awaitText("Livreur affecté : Profil ERP natif")
  click("Retirer l’affectation : Profil ERP natif");awaitText("Opération enregistrée")
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_QA_CASE_PARTIAL B4-017 NATIVE_ZONE_AND_COURIER_PASS")
  click("NAXA SECURITY et partenaires");awaitText("Demande enregistrée localement ; aucun flux vidéo ou accès externe ouvert.")
  step("actual native workspace persistence"){runBlocking{
   val profile=business.call(session,site,"workspace_snapshot",body("page" to "profile")) as JSONObject
   assertEquals("Profil ERP natif",profile.getJSONObject("profile").getString("display_name"))
   val tickets=business.call(session,site,"workspace_snapshot",body("page" to "tickets")) as JSONObject
   assertTrue(tickets.rows("rows").any{it.optString("title")=="Ticket ERP natif"&&it.optString("state")=="done"})
   val delivery=business.call(session,site,"connection_snapshot",body("page" to "delivery")) as JSONObject
   assertTrue(delivery.rows("zones").any{it.optString("label")=="Zone ERP native"&&it.optInt("fee_xaf")==750&&!it.optBoolean("active")})
   assertFalse(delivery.optBoolean("service_active"))
   assertFalse(delivery.rows("members").single{it.optString("id")==session.member}.optBoolean("enabled"))
  }}
  android.util.Log.i("ZIPPLE_BULK2_TEST","ZIPPLE_BULK45_NATIVE_WORKSPACES_PASS")
  click("Déconnexion")
  awaitText("Se connecter")
 }
}
