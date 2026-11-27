package cm.naxa.naxaservices

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Bundle
import org.json.JSONObject
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.content.ClipData
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import androidx.compose.foundation.Image
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalManagementRecord
import cm.naxa.naxaservices.data.LocalSale
import cm.naxa.naxaservices.data.LocalRecurringCharge
import cm.naxa.naxaservices.data.LocalChargePayment
import cm.naxa.naxaservices.data.LocalLoyaltyProgram
import cm.naxa.naxaservices.data.LocalLoyaltyEvent
import cm.naxa.naxaservices.data.LocalSupplier
import cm.naxa.naxaservices.data.LocalPurchaseDocument
import cm.naxa.naxaservices.data.LocalPurchaseLine
import cm.naxa.naxaservices.data.SupplierPurchaseLineDraft
import cm.naxa.naxaservices.data.LocalCashSession
import cm.naxa.naxaservices.data.LocalAccountingEntry
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.Calendar
import java.time.ZoneId
import java.time.LocalDate
import kotlin.math.roundToLong

private fun xaf(v: Long): String = "%,d F".format(v).replace(',', ' ')

@Composable
fun BillingContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) { repository.dao.observeManagementRecords(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    var type by rememberSaveable { mutableStateOf("invoice") }
    var customer by rememberSaveable { mutableStateOf("") }
    var title by rememberSaveable { mutableStateOf("") }
    var total by rememberSaveable { mutableStateOf("") }
    var paid by rememberSaveable { mutableStateOf("0") }
    var selectedRecord by remember { mutableStateOf<String?>(null) }
    var settlement by remember { mutableStateOf("") }
    var reason by remember { mutableStateOf("") }
    val canSettle=BuildConfig.BILLING_SETTLEMENT_ENABLED && type in setOf("invoice","customer_receivable","refund_due")
    var dueDays by rememberSaveable { mutableStateOf("7") }
    var notice by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var receiptToSave by remember { mutableStateOf<LocalManagementRecord?>(null) }
    val pdfLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        val item = receiptToSave
        if (uri != null && item != null) {
            runCatching { writeReceiptPdf(context, uri, item, session.account.organizationName) }
                .onSuccess { notice = "Reçu PDF enregistré dans l’emplacement choisi." }
                .onFailure { error = "Impossible de générer le PDF : " + (it.message ?: "erreur") }
        }
        receiptToSave = null
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(localizedLabel("Facturation, crédits et remboursements","Invoicing, credit and refunds","Facture, ñaawoore e ruttugol ceede"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Devis, factures, créances à recevoir du client et remboursements que la PME doit au client : deux soldes distincts. Les écritures restent rattachées au site.","Quotes, invoices, customer receivables and refunds owed to customers are tracked separately by location.","Devis, facture, ceede soottotooɓe foti yoɓde e ceede golle foti ruttude: limooje ɗiɗi seertiiɗe e nokkuure."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Documents en attente de confirmation.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(localizedLabel("Nouvelle pièce commerciale","New business document","Kayit jaaygol kesol"), fontWeight = FontWeight.Bold)
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            listOf("quote", "invoice", "credit_note").forEach { item ->
                                OutlinedButton(onClick = { type = item }) { Text(if (type == item) "✓ " + labelRecord(item) else labelRecord(item)) }
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            listOf("customer_receivable", "refund_due").forEach { item ->
                                OutlinedButton(onClick = { type = item }) { Text(if (type == item) "✓ " + labelRecord(item) else labelRecord(item)) }
                            }
                        }
                    }
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Client / tiers","Customer / third party","Soottotooɗo / goɗɗo")) }, singleLine = true)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Détail de la prestation ou du remboursement","Service or refund details","Humpito golle walla ruttugol ceede")) }, singleLine = true)
                    OutlinedTextField(total, { total = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Montant total (FCFA)","Total amount (XAF)","Ceede fof (FCFA)")) }, singleLine = true)
                    if (canSettle) OutlinedTextField(paid, { paid = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (type == "customer_receivable") "Déjà encaissé par la PME (FCFA)" else if (type == "refund_due") "Déjà remboursé au client (FCFA)" else "Déjà réglé / encaissé (FCFA)") }, singleLine = true)
                    OutlinedTextField(dueDays, { dueDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Échéance dans (jours)","Due in (days)","Yoɓde caggal (balɗe)")) }, singleLine = true)
                    Button(
                        onClick = {
                            val amount = total.toLongOrNull() ?: 0L
                            val settled = if (canSettle) paid.toLongOrNull() ?: -1L else 0L
                            if (customer.isBlank() || title.isBlank() || amount <= 0 || settled < 0 || settled > amount || siteId !in siteIds) {
                                error = "Vérifie le client, le libellé et les montants."
                                return@Button
                            }
                            scope.launch {
                                runCatching {
                                    repository.createManagementRecord(
                                        session.account.organizationId, siteId, type,
                                        type.uppercase() + "-" + System.currentTimeMillis().toString(),
                                        title, customer, amount, settled,
                                        System.currentTimeMillis() + (dueDays.toLongOrNull() ?: 0L) * 86_400_000L,
                                        if (settled == amount) "paid" else if (settled > 0) "partial" else "open",
                                        "{\"source\":\"android-local\",\"currency\":\"XAF\"}",
                                        session.account.memberId
                                    )
                                }.onSuccess {
                                    notice = labelRecord(type) + " enregistré localement — synchronisation requise."
                                    customer = ""; title = ""; total = ""; paid = "0"; error = null
                                }.onFailure { error = it.message ?: "Enregistrement impossible." }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(localizedLabel("Enregistrer la pièce","Save document","Danndu kayit")) }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                    Text(localizedLabel("Les factures et remboursements en attente ne sont pas encore confirmés.","Pending invoices and refunds are not yet confirmed.","Facture e ruttugol ceede nana fadi tabbitinol."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item { Text(localizedLabel("Historique des pièces","Document history","Jaŋtol kayite"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(records.filter { it.recordType in setOf("quote", "invoice", "credit_note", "customer_receivable", "refund_due") }) { item ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(labelRecord(item.recordType) + " · " + item.reference, fontWeight = FontWeight.Bold)
                    Text(item.title + " · " + item.counterparty)
                    Text(localizedLabel("Total ","Total ","Fof ") + xaf(item.amountXaf) + " · réglé " + xaf(item.paidXaf) + " · restant " + xaf(item.amountXaf - item.paidXaf))
                    Text(statusRecord(item.status), color = MaterialTheme.colorScheme.secondary)
                    if (BuildConfig.BILLING_SETTLEMENT_ENABLED && item.status in setOf("draft","open","partial")) {
                        TextButton(onClick = { selectedRecord = item.id; settlement = ""; reason = "" }) { Text("Traiter la pièce") }
                        if (selectedRecord == item.id) {
                            OutlinedTextField(reason,{ reason=it },label={Text("Motif (3 caractères minimum)")},modifier=Modifier.fillMaxWidth())
                            val payable=item.recordType in setOf("invoice","customer_receivable","refund_due")
                            if(payable) OutlinedTextField(settlement,{settlement=it.filter(Char::isDigit)},label={Text("Total effectivement réglé (FCFA)")},modifier=Modifier.fillMaxWidth())
                            val cumulative=settlement.toLongOrNull()
                            val target=if(payable && cumulative!=null && cumulative==item.amountXaf) "paid" else if(payable) "partial" else "approved"
                            Button(enabled=reason.trim().length in 3..500 && (!payable || (cumulative!=null && cumulative>item.paidXaf && cumulative<=item.amountXaf)),onClick={
                                scope.launch { runCatching { repository.transitionManagementRecord(session.account.organizationId,siteId,item.id,target,reason,session.account.memberId,if(payable)cumulative else null) }.onSuccess { selectedRecord=null; notice="Déclaration locale — synchronisation requise." }.onFailure { error=it.message } }
                            }) { Text(if(payable) "Déclarer le règlement externe" else "Approuver") }
                            if(item.paidXaf==0L) TextButton(enabled=reason.trim().length in 3..500,onClick={
                                scope.launch { runCatching { repository.transitionManagementRecord(session.account.organizationId,siteId,item.id,"cancelled",reason,session.account.memberId) }.onSuccess { selectedRecord=null; notice="Annulation locale — synchronisation requise." }.onFailure { error=it.message } }
                            }) { Text("Annuler") }
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = { receiptToSave = item; pdfLauncher.launch("NAXA-" + item.reference + ".pdf") }) { Text(localizedLabel("Télécharger le reçu PDF","Download PDF receipt","Heɓ kayit njoɓdi PDF")) }
                        TextButton(onClick = { shareRecord(context, item) }) { Text(localizedLabel("Partager WhatsApp","Share on WhatsApp","Lollin e WhatsApp")) }
                    }
                }
            }
        }
        if (records.none { it.recordType in setOf("quote", "invoice", "credit_note", "customer_receivable", "refund_due") }) {
            item { Text(localizedLabel("Aucune pièce commerciale enregistrée.","No business documents recorded.","Alaa kayit jaaygol danndaangol."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

@Composable
fun SubscriptionsContent(modifier: Modifier, api: AuthApi, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val fr = session.account.defaultLocale != "en"
    val org = session.account.organizationId
    var access by remember(org, session.account.memberId, session.deviceId) { mutableStateOf<JSONObject?>(null) }
    var snapshot by remember(org, session.deviceId) { mutableStateOf<JSONObject?>(null) }
    var intent by remember(org, session.deviceId) { mutableStateOf<JSONObject?>(null) }
    val requiresPremium = session.account.businessMode != "solo"
    var plan by remember(org, requiresPremium) { mutableStateOf(if (requiresPremium) "PREMIUM" else "ACCESS") }
    var months by remember(org) { mutableStateOf(1) }
    var channel by remember(org) { mutableStateOf("") }
    var payer by remember(org, session.deviceId) { mutableStateOf("") }
    var sms by remember(org, session.deviceId) { mutableStateOf("") }
    var date by remember(org, session.deviceId) { mutableStateOf("") }
    var notPaid by remember(org, session.deviceId) { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    fun arrayObjects(value: org.json.JSONArray?): List<JSONObject> =
        (0 until (value?.length() ?: 0)).mapNotNull { value?.optJSONObject(it) }
    suspend fun loadAccess() {
        access = null
        access = api.subscriptionAccess(session.accessToken)
    }
    suspend fun load() {
        access = null
        notPaid = false
        val result = api.subscriptionRequest(session.accessToken, JSONObject().put("action", "subscription_list"))
        snapshot = result
        intent = arrayObjects(result.optJSONArray("intents")).firstOrNull { it.optString("status") in setOf("pending","submitted") }
        val available = arrayObjects(result.optJSONArray("destinations")).map { it.optString("channel") }
        if (channel !in available) channel = available.firstOrNull().orEmpty()
    }
    fun runAction(action: suspend () -> Unit) {
        scope.launch {
            busy = true
            error = null
            runCatching { action() }.onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Operation failed."; "ff-CM" -> "Golle ɗee waawataa."; else -> "Opération impossible." } }
            busy = false
        }
    }
    val current = intent
    val destinations = arrayObjects(snapshot?.optJSONArray("destinations"))
    val ussd = current?.let {
        val code = it.optString("merchant_code")
        val amount = it.optLong("amount_xaf", 0L)
        if (!code.matches(Regex("^[0-9]{6}$")) || amount <= 0) "" else when(it.optString("channel")) {
            "mtn_momo" -> "*126*4*" + code + "*" + amount + "#"
            "orange_money" -> "#150*47#"
            else -> ""
        }
    }.orEmpty()
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(when (session.account.defaultLocale) { "en" -> "NAXA SERVICES subscription"; "ff-CM" -> "Abonman NAXA SERVICES"; else -> "Abonnement NAXA SERVICES" }, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(when (session.account.defaultLocale) { "en" -> "One subscription per organization. Your business collects payments outside the app."; "ff-CM" -> "Abonman gooto ngam fedde kala. Ceede golle maa keɓetee tawa aplikasiyoŋ alaa."; else -> "Un abonnement par organisation. Les encaissements de votre entreprise sont réalisés hors application." })
            OutlinedButton(enabled = !busy, onClick = { runAction { loadAccess() } }) {
                Text(when (session.account.defaultLocale) { "en" -> "Check paid access"; "ff-CM" -> "Ƴeewto abonman maa"; else -> "Vérifier les droits payés" })
            }
            access?.let { paid ->
                Text(when (paid.optString("state")) {
                    "active" -> when (session.account.defaultLocale) { "en" -> "Active paid period"; "ff-CM" -> "Sahaa yoɓaaɗo nana golla"; else -> "Période payée active" }
                    "expired" -> when (session.account.defaultLocale) { "en" -> "Paid period expired"; "ff-CM" -> "Sahaa yoɓaaɗo timmii"; else -> "Période payée expirée" }
                    "cancelled" -> when (session.account.defaultLocale) { "en" -> "Subscription cancelled"; "ff-CM" -> "Abonman haaytaama"; else -> "Abonnement annulé" }
                    "not_started" -> when (session.account.defaultLocale) { "en" -> "Upcoming paid period"; "ff-CM" -> "Sahaa yoɓaaɗo aroowo"; else -> "Période payée à venir" }
                    else -> when (session.account.defaultLocale) { "en" -> "No paid period recorded"; "ff-CM" -> "Alaa sahaa yoɓaaɗo danndaaɗo"; else -> "Aucune période payée enregistrée" }
                })
                paid.optString("period_end_exclusive").takeIf { it.isNotBlank() && it != "null" }?.let {
                    Text((when (session.account.defaultLocale) { "en" -> "Exclusive end date: "; "ff-CM" -> "Ñalnde timmugol : "; else -> "Échéance exclusive : " }) + it)
                }
            }
            access?.let { paid ->
                if (paid.has("erp_access")) Text(when (paid.optString("access_reason")) {
                    "trial" -> when (session.account.defaultLocale) { "en" -> "72-hour trial"; "ff-CM" -> "Ƴeewndugol waktuuji 72 nana golla"; else -> "Essai de 72 h en cours" }
                    "provisional" -> when (session.account.defaultLocale) { "en" -> "24-hour provisional access; payment not confirmed"; "ff-CM" -> "Naatugol waktuuji 24, njoɓdi tabbitinaaka"; else -> "Accès provisoire de 24 h, paiement non confirmé" }
                    "paid" -> when (session.account.defaultLocale) { "en" -> "Your subscription is active"; "ff-CM" -> "Abonman maa nana golla"; else -> "Votre abonnement est actif" }
                    else -> when (session.account.defaultLocale) { "en" -> "Subscription suspended. Available records remain accessible."; "ff-CM" -> "Abonman dartinaama. A waawi yiyde humpito keɓeteeɗo."; else -> "Abonnement suspendu. Vos données disponibles restent consultables." }
                })
            }
            if (session.account.roleCode != "promoter") {
                Text(when (session.account.defaultLocale) { "en" -> "Payment reserved for the promoter."; "ff-CM" -> "Jom golle tan waawi yoɓde."; else -> "Règlement réservé au Promoteur." })
            } else {
                OutlinedButton(enabled = !busy, onClick = { runAction { load() } }) { Text(when (session.account.defaultLocale) { "en" -> "Load / refresh"; "ff-CM" -> "Yiy / hesɗitin"; else -> "Consulter / actualiser" }) }
                snapshot?.optJSONObject("subscription")?.let { sub ->
                    Text(sub.optString("plan_code") + " · " + sub.optString("status") + " · " + (when (session.account.defaultLocale) { "en" -> "End date (exclusive): "; "ff-CM" -> "Ñalnde timmugol : "; else -> "Échéance (exclusive) : " }) + sub.optString("period_end_exclusive"))
                }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
        if (session.account.roleCode == "promoter" && snapshot != null && current == null) item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Choose plan"; "ff-CM" -> "Suɓo fannu abonman"; else -> "Choisir une formule" }, fontWeight = FontWeight.Bold)
                    if (requiresPremium) Text(when (session.account.defaultLocale) { "en" -> "PREMIUM required for multiple workstations or sites."; "ff-CM" -> "PREMIUM soklaa ngam nokkuuji keewɗi."; else -> "PREMIUM requis pour le réseau ou plusieurs postes." })
                    (if (requiresPremium) listOf("PREMIUM") else listOf("ACCESS","PREMIUM")).forEach { value ->
                        OutlinedButton(onClick = { plan = value }, enabled = !busy) { Text((if (plan == value) "✓ " else "") + value) }
                    }
                    listOf(1,12).forEach { value ->
                        OutlinedButton(onClick = { months = value }, enabled = !busy) { Text((if (months == value) "✓ " else "") + if (value == 1) (when (session.account.defaultLocale) { "en" -> "Monthly"; "ff-CM" -> "Lewru"; else -> "Mensuel" }) else (when (session.account.defaultLocale) { "en" -> "Annual"; "ff-CM" -> "Hitaande"; else -> "Annuel" })) }
                    }
                    destinations.forEach { d ->
                        val value = d.optString("channel")
                        OutlinedButton(onClick = { channel = value }, enabled = !busy) { Text((if (channel == value) "✓ " else "") + if (value == "mtn_momo") "MTN MoMo" else "Orange Money") }
                    }
                    if (destinations.isEmpty()) Text(when (session.account.defaultLocale) { "en" -> "No NAXA payment destination is enabled."; "ff-CM" -> "Alaa nokkuure yoɓde NAXA. Hoto yoɓ konte goɗɗo."; else -> "Aucune destination NAXA activée. Ne payez pas sur un autre compte." })
                    Button(enabled = !busy && destinations.any { it.optString("channel") == channel }, onClick = {
                        runAction {
                            intent = api.subscriptionRequest(session.accessToken, JSONObject().put("action","subscription_create").put("plan_code",plan).put("months",months).put("channel",channel))
                        }
                    }) { Text(when (session.account.defaultLocale) { "en" -> "Get amount and destination"; "ff-CM" -> "Yiy ceede e nokkuure yoɓde"; else -> "Obtenir le montant et la destination" }) }
                }
            }
        }
        if (session.account.roleCode == "promoter" && current != null) item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(xaf(current.optLong("amount_xaf")) + " · " + current.optString("plan_code"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text((when (session.account.defaultLocale) { "en" -> "Beneficiary: "; "ff-CM" -> "Heɓoowo : "; else -> "Bénéficiaire : " }) + current.optString("beneficiary") + " · " + current.optString("merchant_code"))
                    if (current.optString("status") == "pending") {
                        Text(when (session.account.defaultLocale) { "en" -> "Check the merchant and amount with the operator. Never share your PIN."; "ff-CM" -> "Ƴeewto heɓoowo e ceede e hokkooɗo njoɓdi. Hoto hokku PIN maa."; else -> "Vérifiez le bénéficiaire et le montant chez l'opérateur. Ne communiquez jamais votre PIN." })
                        if (ussd.isNotEmpty()) {
                            Text(ussd)
                            OutlinedButton(enabled = !busy, onClick = {
                                runCatching { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel",ussd,null))) }.onFailure { error = it.message }
                            }) { Text(when (session.account.defaultLocale) { "en" -> "Open dialer"; "ff-CM" -> "Uddit telefon"; else -> "Ouvrir le composeur" }) }
                        }
                        OutlinedTextField(payer, { payer = it.take(20) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Payer phone"; "ff-CM" -> "Tonngoode telefon yoɓooɗo"; else -> "Numéro du payeur" }) }, singleLine = true)
                        if (current.optString("channel") == "orange_money") OutlinedTextField(date, { date = it.take(16) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Cameroon time (YYYY-MM-DD HH:mm)"; "ff-CM" -> "Ñalnde e sahaa Kameruun (AAAA-MM-JJ HH:mm)"; else -> "Date et heure Cameroun (AAAA-MM-JJ HH:mm)" }) }, singleLine = true)
                        OutlinedTextField(sms, { sms = it.take(8000) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Debit SMS for this transaction"; "ff-CM" -> "SMS njoɓdi ɗee"; else -> "SMS de débit de cette transaction" }) })
                        Button(enabled = !busy && payer.isNotBlank() && sms.isNotBlank() && (current.optString("channel") != "orange_money" || date.length == 16), onClick = {
                            runAction {
                                val payload = JSONObject().put("action","subscription_declare").put("intent_id",current.optString("id")).put("sms",sms).put("payer_number",payer)
                                if (current.optString("channel") == "orange_money") payload.put("occurred_at",java.time.OffsetDateTime.parse(date.replace(' ','T') + ":00+01:00").toString())
                                api.subscriptionRequest(session.accessToken,payload)
                                sms = ""; payer = ""; date = ""; load()
                            }
                        }) { Text(when (session.account.defaultLocale) { "en" -> "Declare payment"; "ff-CM" -> "Hollu njoɓdi"; else -> "Déclarer le paiement" }) }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            androidx.compose.material3.Checkbox(checked = notPaid, onCheckedChange = { notPaid = it }, enabled = !busy)
                            Text(when (session.account.defaultLocale) { "en" -> "I confirm no payment was made."; "ff-CM" -> "Mi tabbitinii mi yoɓaani."; else -> "Je confirme n’avoir effectué aucun paiement." })
                        }
                        OutlinedButton(enabled = !busy && notPaid, onClick = {
                            runAction {
                                api.subscriptionRequest(session.accessToken, JSONObject().put("action","subscription_cancel").put("intent_id",current.optString("id")).put("not_paid",true))
                                sms = ""; payer = ""; date = ""; load()
                            }
                        }) { Text(when (session.account.defaultLocale) { "en" -> "Cancel unpaid request"; "ff-CM" -> "Haaytu ɗaɓɓitannde nde yoɓaaka"; else -> "Abandonner la demande non payée" }) }
                    } else Text(when (session.account.defaultLocale) { "en" -> "Declaration received. Waiting for NAXA credit proof; one proof does not activate access."; "ff-CM" -> "Jaŋtol njoɓdi heɓaama. Nana fadi ceede NAXA; kayit tan udditataa abonman."; else -> "Déclaration reçue. En attente du crédit NAXA ; aucun droit activé par une preuve seule." })
                }
            }
        }
        if (session.account.roleCode == "promoter") items(arrayObjects(snapshot?.optJSONArray("intents")).filter { it.optString("status") == "confirmed" }) { row ->
            Text((when (session.account.defaultLocale) { "en" -> "Receipt "; "ff-CM" -> "Kayit "; else -> "Reçu " }) + row.optString("receipt_number") + " · " + xaf(row.optLong("amount_xaf")))
        }
        item { Spacer(Modifier.height(12.dp)) }
    }
}

@Composable
fun PurchasesContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val fr = session.account.defaultLocale != "en"
    val orgId = session.account.organizationId
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val suppliers by remember(siteId) { repository.dao.observeSuppliers(orgId, siteId) }.collectAsState(initial = emptyList())
    val purchases by remember(siteId) { repository.dao.observePurchaseDocuments(orgId, siteId) }.collectAsState(initial = emptyList())
    val inventory by remember(siteId) { repository.dao.observeInventoryItems(orgId, siteId) }.collectAsState(initial = emptyList())
    val payments by remember(siteId) { repository.dao.observeSupplierPayments(orgId, siteId) }.collectAsState(initial = emptyList())
    val cashSessions by remember(siteId) { repository.dao.observeCashSessions(orgId, siteId) }.collectAsState(initial = emptyList())
    val accounting by remember(siteId) { repository.dao.observeAllAccountingEntries(orgId, siteId) }.collectAsState(initial = emptyList())
    val payables by remember(siteId) { repository.dao.observeSupplierPayables(orgId, siteId) }.collectAsState(initial = 0L)
    val legacySuppliers by remember(siteId) { repository.dao.observeManagementRecordsByType(orgId, siteId, "supplier") }.collectAsState(initial = emptyList())
    val legacyPurchases by remember(siteId) { repository.dao.observeManagementRecordsByType(orgId, siteId, "purchase") }.collectAsState(initial = emptyList())

    var supplierName by rememberSaveable { mutableStateOf("") }
    var supplierPhone by rememberSaveable { mutableStateOf("") }
    var supplierWhatsApp by rememberSaveable { mutableStateOf("") }
    var supplierEmail by rememberSaveable { mutableStateOf("") }
    var supplierAddress by rememberSaveable { mutableStateOf("") }
    var supplierTerms by rememberSaveable { mutableStateOf("30") }
    var supplierNotes by rememberSaveable { mutableStateOf("") }
    var selectedSupplierId by rememberSaveable { mutableStateOf("") }
    var purchaseReference by rememberSaveable { mutableStateOf("") }
    var supplierInvoice by rememberSaveable { mutableStateOf("") }
    var dueDays by rememberSaveable { mutableStateOf("30") }
    var recoverableTax by rememberSaveable { mutableStateOf("0") }
    var nonRecoverableTax by rememberSaveable { mutableStateOf("0") }
    var shipping by rememberSaveable { mutableStateOf("0") }
    var otherFees by rememberSaveable { mutableStateOf("0") }
    var purchaseNotes by rememberSaveable { mutableStateOf("") }
    var itemType by rememberSaveable { mutableStateOf("stock") }
    var selectedItemId by rememberSaveable { mutableStateOf("") }
    var lineDescription by rememberSaveable { mutableStateOf("") }
    var lineUnit by rememberSaveable { mutableStateOf("unité") }
    var lineQuantity by rememberSaveable { mutableStateOf("1") }
    var lineUnitCost by rememberSaveable { mutableStateOf("") }
    val draftLines = remember { mutableStateListOf<SupplierPurchaseLineDraft>() }
    val receiptQuantities = remember { mutableStateMapOf<String, String>() }
    var notice by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val selectedItem = inventory.firstOrNull { it.id == selectedItemId }
    val selectedSupplier = suppliers.firstOrNull { it.id == selectedSupplierId }
    val orderSubtotal = draftLines.sumOf { (it.quantity * it.unitCostXaf).roundToLong() }
    val recoverableTaxValue = recoverableTax.toLongOrNull() ?: 0L
    val nonRecoverableTaxValue = nonRecoverableTax.toLongOrNull() ?: 0L
    val shippingValue = shipping.toLongOrNull() ?: 0L
    val otherFeeValue = otherFees.toLongOrNull() ?: 0L
    val orderTotal = orderSubtotal + recoverableTaxValue + nonRecoverableTaxValue + shippingValue + otherFeeValue

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                when (session.account.defaultLocale) { "en" -> "Purchases, suppliers and accounting"; "ff-CM" -> "Soodugol, hokkooɓe jawdi e limtol ceede"; else -> "Achats, fournisseurs et comptabilité" },
                when (session.account.defaultLocale) { "en" -> "Multi-line orders, partial receiving, supplier payables and payments, with balanced journal entries and margin impact."; "ff-CM" -> "Ɗaɓɓitanɗe jawdi keewɗi, heɓugol seeɗa, ñaawoore e njoɓdi hokkooɓe jawdi, jaŋtol ceede e njariñ."; else -> "Commandes multi-lignes, réceptions partielles, dettes et règlements fournisseurs, avec journal débit/crédit et impact sur les marges." }
            )
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) {
                siteId = it; selectedSupplierId = ""; selectedItemId = ""; draftLines.clear()
            }
            LocalOnlyNotice(when (session.account.defaultLocale) { "en" -> "View your available accounting records."; "ff-CM" -> "Yiy jaŋte ceede maa."; else -> "Consultez vos registres comptables disponibles." })
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Site supplier account"; "ff-CM" -> "Konte hokkooɗo jawdi nokkuure"; else -> "Compte fournisseur du site" }, fontWeight = FontWeight.Bold)
                    Text((when (session.account.defaultLocale) { "en" -> "Open supplier payables: "; "ff-CM" -> "Ñaawoore hokkooɓe jawdi yoɓaaka : "; else -> "Dettes fournisseurs non réglées : " }) + xaf(payables), style = MaterialTheme.typography.titleLarge)
                    Text((when (session.account.defaultLocale) { "en" -> "Open purchase documents: "; "ff-CM" -> "Ɗaɓɓitanɗe udditiiɗe : "; else -> "Commandes ouvertes : " }) + purchases.count { it.status !in setOf("closed", "cancelled") })
                    Text((when (session.account.defaultLocale) { "en" -> "Payments recorded: "; "ff-CM" -> "Njoɓdi danndaaɗi : "; else -> "Règlements enregistrés : " }) + payments.size)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Supplier profile"; "ff-CM" -> "Humpito hokkooɗo jawdi"; else -> "Fiche fournisseur" }, fontWeight = FontWeight.Bold)
                    if (suppliers.isEmpty()) Text(when (session.account.defaultLocale) { "en" -> "No active supplier for this site."; "ff-CM" -> "Alaa hokkooɗo jawdi e nokkuure ndee."; else -> "Aucun fournisseur actif pour ce site." })
                    suppliers.forEach { supplier ->
                        OutlinedButton(onClick = { selectedSupplierId = supplier.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (selectedSupplierId == supplier.id) "✓ " else "") + supplier.name + " · " + supplier.phone)
                        }
                    }
                    OutlinedTextField(supplierName, { supplierName = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Supplier name"; "ff-CM" -> "Innde / innde fedde"; else -> "Nom / raison sociale" }) }, singleLine = true)
                    OutlinedTextField(supplierPhone, { supplierPhone = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Phone"; "ff-CM" -> "Telefon"; else -> "Téléphone" }) }, singleLine = true)
                    OutlinedTextField(supplierWhatsApp, { supplierWhatsApp = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("WhatsApp fournisseur · indicatif pays","Supplier WhatsApp · country code","WhatsApp hokkooɗo jawdi · innol leydi")) }, singleLine = true)
                    OutlinedTextField(supplierEmail, { supplierEmail = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Email"; "ff-CM" -> "E-mail"; else -> "E-mail" }) }, singleLine = true)
                    OutlinedTextField(supplierAddress, { supplierAddress = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Address"; "ff-CM" -> "Nokkuure"; else -> "Adresse" }) }, minLines = 2)
                    OutlinedTextField(supplierTerms, { supplierTerms = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Payment terms (days)"; "ff-CM" -> "Sahaa yoɓde (balɗe)"; else -> "Délai de paiement (jours)" }) }, singleLine = true)
                    OutlinedTextField(supplierNotes, { supplierNotes = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Terms and notes"; "ff-CM" -> "Laabi e ɓatakuuji"; else -> "Conditions et notes" }) }, minLines = 2)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true; error = null
                                runCatching {
                                    repository.saveSupplier(orgId, siteId, supplierName, supplierPhone, supplierWhatsApp,
                                        supplierEmail, supplierAddress, supplierTerms.toIntOrNull() ?: 0, supplierNotes, session.account.memberId)
                                }.onSuccess {
                                    selectedSupplierId = it.id
                                    supplierName = ""; supplierPhone = ""; supplierWhatsApp = ""; supplierEmail = ""
                                    supplierAddress = ""; supplierNotes = ""; supplierTerms = "30"
                                    notice = when (session.account.defaultLocale) { "en" -> "Supplier profile saved."; "ff-CM" -> "Humpito hokkooɗo jawdi danndaama."; else -> "Fiche fournisseur enregistrée." }
                                }.onFailure { error = it.message ?: "Supplier save failed." }
                                busy = false
                            }
                        }, enabled = !busy && supplierName.trim().length >= 2 && (supplierTerms.toIntOrNull() ?: -1) in 0..365,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else when (session.account.defaultLocale) { "en" -> "Save supplier"; "ff-CM" -> "Danndu hokkooɗo jawdi"; else -> "Enregistrer le fournisseur" }) }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "New multi-line supplier order"; "ff-CM" -> "Ɗaɓɓitannde jawdi hesere keewɗi"; else -> "Nouvelle commande fournisseur multi-lignes" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "1. Select supplier"; "ff-CM" -> "1. Suɓo hokkooɗo jawdi"; else -> "1. Sélection du fournisseur" })
                    if (selectedSupplier == null) Text(when (session.account.defaultLocale) { "en" -> "Select an existing supplier profile first."; "ff-CM" -> "Suɓo hokkooɗo jawdi tawo."; else -> "Sélectionne d'abord une fiche fournisseur." })
                    else Text(selectedSupplier.name + " · " + selectedSupplier.phone, color = MaterialTheme.colorScheme.primary)
                    OutlinedTextField(purchaseReference, { purchaseReference = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Purchase reference (blank to generate)"; "ff-CM" -> "Innol ɗaɓɓitannde (accu meere ngam sosde)"; else -> "Référence commande (laisser vide pour générer)" }) }, singleLine = true)
                    OutlinedTextField(supplierInvoice, { supplierInvoice = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Supplier invoice reference"; "ff-CM" -> "Innol facture hokkooɗo jawdi"; else -> "Référence facture fournisseur" }) }, singleLine = true)
                    Text(when (session.account.defaultLocale) { "en" -> "2. Add purchase lines"; "ff-CM" -> "2. Ɓeydu jawdi"; else -> "2. Ajouter les lignes" })
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        listOf("stock" to "Stock", "operating_expense" to "Consommable / service", "fixed_asset" to "Immobilisation").forEach { option ->
                            OutlinedButton(onClick = { itemType = option.first; selectedItemId = "" }) {
                                Text((if (itemType == option.first) "✓ " else "") + option.second)
                            }
                        }
                    }
                    if (itemType == "stock") {
                        inventory.forEach { stockItem ->
                            OutlinedButton(onClick = {
                                selectedItemId = stockItem.id; lineDescription = stockItem.name; lineUnit = stockItem.unit
                            }, modifier = Modifier.fillMaxWidth()) {
                                Text((if (selectedItemId == stockItem.id) "✓ " else "") + stockItem.name + " · stock " + stockItem.quantity + " " + stockItem.unit)
                            }
                        }
                    } else {
                        OutlinedTextField(lineDescription, { lineDescription = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Expense / asset description"; "ff-CM" -> "Innde njoɓdi / jawdi juutndi"; else -> "Désignation de la charge / immobilisation" }) })
                    }
                    OutlinedTextField(lineUnit, { lineUnit = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Unit"; "ff-CM" -> "Keewal"; else -> "Unité" }) }, singleLine = true)
                    OutlinedTextField(lineQuantity, { lineQuantity = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Quantity ordered"; "ff-CM" -> "Keewal ɗaɓɓitaangal"; else -> "Quantité commandée" }) }, singleLine = true)
                    OutlinedTextField(lineUnitCost, { lineUnitCost = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Unit cost (XAF)"; "ff-CM" -> "Njoɓdi gootal (FCFA)"; else -> "Coût unitaire (FCFA)" }) }, singleLine = true)
                    OutlinedButton(
                        onClick = {
                            val qty = lineQuantity.replace(",", ".").toDoubleOrNull() ?: 0.0
                            val unitCost = lineUnitCost.toLongOrNull() ?: 0L
                            if (lineDescription.isBlank() || qty <= 0 || !qty.isFinite() || unitCost <= 0 ||
                                (itemType == "stock" && selectedItem == null)
                            ) error = when (session.account.defaultLocale) { "en" -> "Description, linked stock item if required, quantity and unit cost are required."; "ff-CM" -> "Innde, jawdi so soklaa, keewal e njoɓdi ɓurɗi 0 ko waajib."; else -> "Désignation, article de stock si requis, quantité et coût unitaire positifs obligatoires." }
                            else {
                                draftLines.add(SupplierPurchaseLineDraft(
                                    if (itemType == "stock") selectedItem?.id else null,
                                    lineDescription.trim(), itemType, lineUnit.trim(), qty, unitCost
                                ))
                                lineDescription = if (itemType == "stock") "" else lineDescription
                                lineQuantity = "1"; lineUnitCost = ""; selectedItemId = ""
                                error = null
                            }
                        }, modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Add line to purchase"; "ff-CM" -> "Ɓeydu jawdi e ɗaɓɓitannde"; else -> "Ajouter cette ligne à la commande" }) }
                    if (draftLines.isNotEmpty()) {
                        Text(when (session.account.defaultLocale) { "en" -> "Prepared lines"; "ff-CM" -> "Jawdi heblitaandi"; else -> "Lignes préparées" }, fontWeight = FontWeight.SemiBold)
                        draftLines.forEachIndexed { index, line ->
                            Row(horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(line.description, fontWeight = FontWeight.Medium)
                                    Text(line.itemType + " · " + line.quantity + " " + line.unit + " × " + xaf(line.unitCostXaf), style = MaterialTheme.typography.bodySmall)
                                }
                                Text(xaf((line.quantity * line.unitCostXaf).roundToLong()))
                                TextButton(onClick = { draftLines.removeAt(index) }) { Text(when (session.account.defaultLocale) { "en" -> "Remove"; "ff-CM" -> "Ittu"; else -> "Retirer" }) }
                            }
                        }
                    }
                    Text(when (session.account.defaultLocale) { "en" -> "3. Taxes and fees"; "ff-CM" -> "3. Sagalle e njoɓdi"; else -> "3. Taxes et frais" }, fontWeight = FontWeight.SemiBold)
                    OutlinedTextField(recoverableTax, { recoverableTax = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Recoverable tax entered (XAF)"; "ff-CM" -> "Taksa rutteteenga (FCFA)"; else -> "Taxe récupérable déclarée (FCFA)" }) }, singleLine = true)
                    OutlinedTextField(nonRecoverableTax, { nonRecoverableTax = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Non-recoverable tax (XAF)"; "ff-CM" -> "Taksa nde ruttetaake (FCFA)"; else -> "Taxe non récupérable (FCFA)" }) }, singleLine = true)
                    OutlinedTextField(shipping, { shipping = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Shipping / delivery (XAF)"; "ff-CM" -> "Yahdugol / jottugol (FCFA)"; else -> "Transport / livraison (FCFA)" }) }, singleLine = true)
                    OutlinedTextField(otherFees, { otherFees = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Other allocable fees (XAF)"; "ff-CM" -> "Njoɓdi goɗɗi (FCFA)"; else -> "Autres frais imputables (FCFA)" }) }, singleLine = true)
                    OutlinedTextField(dueDays, { dueDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Payment due in (days)"; "ff-CM" -> "Yoɓde caggal (balɗe)"; else -> "Échéance de paiement dans (jours)" }) }, singleLine = true)
                    OutlinedTextField(purchaseNotes, { purchaseNotes = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Notes / receiving conditions"; "ff-CM" -> "Ɓatakuuji / laabi heɓugol"; else -> "Notes / conditions de réception" }) }, minLines = 2)
                    Text(localizedLabel("Sous-total : ","Subtotal: ","Ceede hade fof : ") + xaf(orderSubtotal))
                    Text(localizedLabel("Total engagé : ","Committed total: ","Ceede ɗaɓɓitaaɗe fof : ") + xaf(orderTotal), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "An order alone changes neither stock nor profit. Payables and journal entries are created as goods/services are actually received."; "ff-CM" -> "Ɗaɓɓitannde tan waylataa jawdi walla limooje. Ñaawoore e jaŋtol sosetee so jawdi heɓaama."; else -> "La commande seule ne modifie ni le stock ni le résultat. La dette et les écritures sont créées au rythme des réceptions effectives." })
                    Button(
                        onClick = {
                            if (selectedSupplier == null || draftLines.isEmpty() || orderTotal <= 0L ||
                                listOf(recoverableTaxValue, nonRecoverableTaxValue, shippingValue, otherFeeValue).any { it < 0L } ||
                                (dueDays.toIntOrNull() ?: -1) !in 0..365
                            ) error = when (session.account.defaultLocale) { "en" -> "Supplier, lines and valid amounts required."; "ff-CM" -> "Hokkooɗo jawdi, jawdi e ceede feewɗe ko waajib."; else -> "Fournisseur, lignes et montants valides obligatoires." }
                            else scope.launch {
                                busy = true; error = null
                                runCatching {
                                    repository.createSupplierPurchase(
                                        orgId, siteId, selectedSupplier.id,
                                        purchaseReference.ifBlank { "ACH-" + System.currentTimeMillis() },
                                        supplierInvoice, draftLines.toList(), recoverableTaxValue, nonRecoverableTaxValue,
                                        shippingValue, otherFeeValue,
                                        System.currentTimeMillis() + (dueDays.toLongOrNull() ?: 30L) * 86_400_000L,
                                        purchaseNotes, session.account.memberId
                                    )
                                }.onSuccess {
                                    draftLines.clear(); purchaseReference = ""; supplierInvoice = ""; purchaseNotes = ""
                                    recoverableTax = "0"; nonRecoverableTax = "0"; shipping = "0"; otherFees = "0"; dueDays = "30"
                                    notice = when (session.account.defaultLocale) { "en" -> "Order saved. No stock entry or expense is posted before receipt."; "ff-CM" -> "Ɗaɓɓitannde danndaama. Jawdi walla njoɓdi winndaaka hade heɓugol."; else -> "Commande enregistrée. Aucune entrée de stock ou dépense n'est postée avant réception." }
                                }.onFailure { error = it.message ?: "Purchase creation failed." }
                                busy = false
                            }
                        }, enabled = !busy && selectedSupplier != null && draftLines.isNotEmpty() && orderTotal > 0L,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else when (session.account.defaultLocale) { "en" -> "Create supplier order"; "ff-CM" -> "Tabbitin ɗaɓɓitannde jawdi"; else -> "Valider la commande fournisseur" }) }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Supplier orders, receipts and payables"; "ff-CM" -> "Ɗaɓɓitanɗe, heɓugol e ñaawoore hokkooɓe jawdi"; else -> "Commandes, réceptions et dettes fournisseurs" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (purchases.isEmpty()) item { Text(when (session.account.defaultLocale) { "en" -> "No supplier purchase orders yet."; "ff-CM" -> "Alaa ɗaɓɓitannde jawdi danndaande."; else -> "Aucune commande fournisseur enregistrée." }) }
        items(purchases, key = { it.id }) { purchase ->
            val lines by remember(purchase.id, siteId) { repository.dao.observePurchaseLines(orgId, siteId, purchase.id) }.collectAsState(initial = emptyList())
            val receipts by remember(purchase.id, siteId) { repository.dao.observePurchaseReceipts(orgId, siteId, purchase.id) }.collectAsState(initial = emptyList())
            val due = purchase.receivedTotalXaf - purchase.paidTotalXaf
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                    Text(purchase.reference + " · " + purchase.supplierNameSnapshot, fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Statut : ","Status: ","Ngonka : ") + purchase.status + " · " + (purchase.supplierInvoiceNumber.ifBlank { when (session.account.defaultLocale) { "en" -> "Invoice not entered"; "ff-CM" -> "Facture winndaaka"; else -> "Facture non renseignée" } }))
                    val purchaseSupplier = suppliers.firstOrNull { it.id == purchase.supplierId }
                    if (!purchaseSupplier?.whatsapp.isNullOrBlank()) {
                        OutlinedButton(
                            onClick = {
                                val linesText = lines.joinToString("\n") { it.description + " : " + it.quantityOrdered + " " + it.unit + " × " + it.unitCostXaf + " FCFA" }
                                val body = "Bonjour " + purchase.supplierNameSnapshot + ", voici notre bon de commande " +
                                    purchase.reference + " :\n" + linesText + "\nTotal de commande : " +
                                    (purchase.subtotalXaf + purchase.recoverableTaxXaf + purchase.nonRecoverableTaxXaf + purchase.shippingXaf + purchase.otherFeesXaf) +
                                    " FCFA. Merci de confirmer disponibilité, délai et modalités de livraison."
                                val url = "https://wa.me/" + purchaseSupplier!!.whatsapp.filter(Char::isDigit) +
                                    "?text=" + android.net.Uri.encode(body)
                                runCatching {
                                    context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url)))
                                }.onFailure { error = "WhatsApp ou navigateur indisponible sur cet appareil." }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Send purchase order via WhatsApp"; "ff-CM" -> "Neldu kayit ɗaɓɓitannde e WhatsApp"; else -> "Envoyer le bon de commande par WhatsApp" }) }
                    }
                    Text(localizedLabel("Total commandé : ","Ordered total: ","Ceede ɗaɓɓitaaɗe fof : ") + xaf(purchase.subtotalXaf + purchase.recoverableTaxXaf + purchase.nonRecoverableTaxXaf + purchase.shippingXaf + purchase.otherFeesXaf))
                    Text(localizedLabel("Réceptionné : ","Received: ","Heɓaama : ") + xaf(purchase.receivedTotalXaf) + " · réglé : " + xaf(purchase.paidTotalXaf))
                    Text((when (session.account.defaultLocale) { "en" -> "Supplier payable: "; "ff-CM" -> "Ñaawoore hokkooɗo jawdi : "; else -> "Dette fournisseur : " }) + xaf(due.coerceAtLeast(0L)), color = if (due > 0L) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    lines.forEach { line ->
                        val remaining = (line.quantityOrdered - line.quantityReceived).coerceAtLeast(0.0)
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(line.description + " · " + line.itemType, fontWeight = FontWeight.SemiBold)
                            Text(localizedLabel("Commandé : ","Ordered: ","Ɗaɓɓitaama : ") + line.quantityOrdered + " · reçu : " + line.quantityReceived + " · restant : " + remaining, style = MaterialTheme.typography.bodySmall)
                            if (remaining > 0.000001 && purchase.status !in setOf("cancelled", "closed")) {
                                val qtyText = receiptQuantities[line.id] ?: remaining.toString()
                                OutlinedTextField(qtyText, { receiptQuantities[line.id] = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Quantity received now"; "ff-CM" -> "Keewal heɓaangal jooni"; else -> "Quantité reçue maintenant" }) }, singleLine = true)
                                OutlinedButton(onClick = {
                                    val q = (receiptQuantities[line.id] ?: remaining.toString()).replace(",", ".").toDoubleOrNull() ?: 0.0
                                    scope.launch {
                                        runCatching { repository.receiveSupplierPurchaseLine(
                                            orgId, siteId, purchase.id, line.id, q,
                                            java.util.UUID.nameUUIDFromBytes(
                                                "$orgId|$siteId|${purchase.id}|${line.id}|${line.quantityReceived}|$q".toByteArray(Charsets.UTF_8)
                                            ).toString(),
                                            session.account.memberId
                                        ) }
                                            .onSuccess { receiptQuantities.remove(line.id); notice = when (session.account.defaultLocale) { "en" -> "Receipt posted to inventory, payable and journal."; "ff-CM" -> "Heɓugol danndaama: jawdi, ñaawoore e jaŋtol hesɗitinaama."; else -> "Réception enregistrée : stock, dette et journal mis à jour." } }
                                            .onFailure { error = it.message ?: "Receiving failed." }
                                    }
                                }, enabled = remaining > 0.0) { Text(when (session.account.defaultLocale) { "en" -> "Post this partial / full receipt"; "ff-CM" -> "Tabbitin heɓugol seeɗa / fof"; else -> "Valider cette réception partielle / complète" }) }
                            }
                        }
                    }
                    if (receipts.isNotEmpty()) {
                        Text(when (session.account.defaultLocale) { "en" -> "Receiving history"; "ff-CM" -> "Jaŋtol heɓugol jawdi"; else -> "Historique des réceptions" }, fontWeight = FontWeight.SemiBold)
                        receipts.forEach { receipt ->
                            Text(receipt.quantityReceived.toString() + " · " + xaf(receipt.baseCostXaf + receipt.nonRecoverableCostXaf + receipt.recoverableTaxXaf) +
                                " · " + java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(receipt.receivedAtMillis)),
                                style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    if (due > 0L && purchase.status !in setOf("ordered", "cancelled", "closed")) {
                        var amountToPay by rememberSaveable(purchase.id) { mutableStateOf(due.toString()) }
                        var paymentMethod by rememberSaveable(purchase.id) { mutableStateOf("bank") }
                        var cashSessionId by rememberSaveable(purchase.id) { mutableStateOf("") }
                        var paymentReference by rememberSaveable(purchase.id) { mutableStateOf("") }
                        Text(when (session.account.defaultLocale) { "en" -> "Supplier settlement"; "ff-CM" -> "Njoɓdi hokkooɗo jawdi"; else -> "Règlement fournisseur" }, fontWeight = FontWeight.SemiBold)
                        OutlinedTextField(amountToPay, { amountToPay = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Payment amount (XAF)"; "ff-CM" -> "Ceede yoɓaaɗe (FCFA)"; else -> "Montant réglé (FCFA)" }) }, singleLine = true)
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            listOf("cash" to "Espèces", "bank" to "Banque", "mobile_money" to "Mobile Money", "other" to "Autre").forEach { method ->
                                OutlinedButton(onClick = { paymentMethod = method.first }) { Text((if (paymentMethod == method.first) "✓ " else "") + method.second) }
                            }
                        }
                        if (paymentMethod == "cash") {
                            cashSessions.filter { it.status == "open" }.forEach { cash ->
                                OutlinedButton(onClick = { cashSessionId = cash.id }, modifier = Modifier.fillMaxWidth()) {
                                    Text((if (cashSessionId == cash.id) "✓ " else "") + "Caisse ouverte · " + cash.id.take(8))
                                }
                            }
                        }
                        OutlinedTextField(paymentReference, { paymentReference = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Payment reference"; "ff-CM" -> "Innol njoɓdi"; else -> "Référence du règlement" }) }, singleLine = true)
                        Button(
                            onClick = {
                                val amount = amountToPay.toLongOrNull() ?: 0L
                                if (amount <= 0L || amount > due || (paymentMethod == "cash" && cashSessionId.isBlank())) error = when (session.account.defaultLocale) { "en" -> "Invalid amount or cash register."; "ff-CM" -> "Ceede walla keesu njoɓdi feewaani."; else -> "Montant ou caisse de règlement invalide." }
                                else scope.launch {
                                    runCatching {
                                        repository.recordSupplierPayment(orgId, siteId, purchase.id, amount, paymentMethod,
                                            cashSessionId.takeIf { paymentMethod == "cash" }, paymentReference,
                                            java.util.UUID.nameUUIDFromBytes(
                                                "$orgId|$siteId|${purchase.id}|${purchase.paidTotalXaf}|$amount|$paymentMethod|$cashSessionId|${paymentReference.trim()}"
                                                    .toByteArray(Charsets.UTF_8)
                                            ).toString(), session.account.memberId)
                                    }.onSuccess { notice = when (session.account.defaultLocale) { "en" -> "Supplier payment applied to payable and journal."; "ff-CM" -> "Njoɓdi hokkooɗo jawdi ustina ñaawoore e danndaama e jaŋtol."; else -> "Règlement fournisseur imputé à la dette et au journal." } }
                                        .onFailure { error = it.message ?: "Supplier payment failed." }
                                }
                            }, modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Record supplier payment"; "ff-CM" -> "Danndu njoɓdi"; else -> "Enregistrer le règlement" }) }
                    }
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Management accounting journal"; "ff-CM" -> "Jaŋtol limtol ceede"; else -> "Journal comptable de gestion" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (accounting.isEmpty()) item { Text(when (session.account.defaultLocale) { "en" -> "No journal entry posted for this site."; "ff-CM" -> "Alaa winndannde ceede e nokkuure ndee."; else -> "Aucune écriture postée pour ce site." }) }
        items(accounting.take(50), key = { it.id }) { entry ->
            Text(entry.occurredAtMillis.let { java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(it)) } +
                " · Débit " + entry.debitAccount + " / Crédit " + entry.creditAccount + " · " + xaf(entry.amountXaf) +
                " · " + entry.description, style = MaterialTheme.typography.bodySmall)
        }
        item {
            LocalOnlyNotice(when (session.account.defaultLocale) { "en" -> "The balanced double-entry journal uses management account labels; it is not yet a certified SYSCOHADA chart of accounts or a tax filing."; "ff-CM" -> "Jaŋtol huutorta konte ɗowtugol (jawdi, ñaawoore, keesu, jaaygol, njoɓdi jaaygol). Debi e kredi nanndi, kono wonaa plan SYSCOHADA tabbitinaango walla déclaration fiscale."; else -> "Le journal utilise des comptes de gestion symboliques (stock, dette fournisseur, trésorerie, ventes, coût des ventes). Il est équilibré débit/crédit mais n'est pas encore un plan de comptes SYSCOHADA certifié ni une déclaration fiscale." })
        }

        if (legacySuppliers.isNotEmpty() || legacyPurchases.isNotEmpty()) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(when (session.account.defaultLocale) { "en" -> "Legacy register archive"; "ff-CM" -> "Jaŋte ɓooyɗe"; else -> "Archives des anciens registres" }, fontWeight = FontWeight.Bold)
                        Text(
                            when (session.account.defaultLocale) { "en" -> "Suppliers and orders from the former generic register remain visible below. They are not auto-converted, to avoid duplicate stock or payables."; "ff-CM" -> "Hokkooɓe jawdi e ɗaɓɓitanɗe ɓooyɗe ndanndaama les ɗoo. Ɗe wayletaake e hoore mum ngam haɗde jawdi walla ñaawoore ɗiɗol."; else -> "Les fournisseurs et commandes saisis dans l'ancien module générique sont conservés ci-dessous. Ils ne sont pas convertis automatiquement pour éviter les doublons de stock ou de dette." }
                        )
                        legacySuppliers.take(20).forEach { record ->
                            Text(localizedLabel("Fournisseur historique · ","Previous supplier · ","Hokkooɗo jawdi ɓooyɗo · ") + record.title + " · " + record.counterparty, style = MaterialTheme.typography.bodySmall)
                        }
                        legacyPurchases.take(50).forEach { record ->
                            Text(record.reference + " · " + record.title + " · " + record.counterparty +
                                " · " + xaf(record.amountXaf) + " · " + record.status, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}


@Composable
fun TaxesContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) { repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "tax_estimate") }.collectAsState(initial = emptyList())
    var base by rememberSaveable { mutableStateOf("") }
    var rate by rememberSaveable { mutableStateOf("") }
    var label by rememberSaveable { mutableStateOf("TVA - estimation") }
    var message by remember { mutableStateOf<String?>(null) }
    val baseValue = base.toLongOrNull() ?: 0L
    val rateValue = rate.replace(",", ".").toDoubleOrNull() ?: 0.0
    val estimated = (baseValue * rateValue / 100.0).roundToLong()
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(localizedLabel("Taxes et impôts","Taxes","Taksa e sagalle"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Espace de préparation et de suivi. Les taux, régimes, échéances et obligations doivent être validés par votre comptable selon la réglementation applicable.","Preparation and tracking area. Your accountant must validate rates, regimes, due dates and obligations under applicable law.","Nokkuure heblugol e rewindo. Limtooɗo ceede maa foti tabbitinde sagalle, ñalɗi e laabi e sariya."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Aucune déclaration fiscale n’est transmise par cet écran.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(label, { label = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Nature de la taxe / échéance","Tax / due date type","Fannu sagalle / ñalnde yoɓde")) })
                    OutlinedTextField(base, { base = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Base taxable (FCFA)","Taxable base (XAF)","Ceede ɗe sagalle limtetee (FCFA)")) })
                    OutlinedTextField(rate, { rate = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Taux indicatif (%)","Indicative rate (%)","Keewal tanƴaangal (%)")) })
                    Text(localizedLabel("Montant estimatif : ","Estimated amount: ","Ceede tanƴaaɗe : ") + xaf(estimated), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Button(onClick = {
                        if (baseValue <= 0 || rateValue < 0.0 || rateValue > 100.0) message = "Vérifie la base et le taux."
                        else scope.launch {
                            runCatching { repository.createManagementRecord(session.account.organizationId, siteId, "tax_estimate", "TAX-" + System.currentTimeMillis(), label, "Fiscalité", estimated, 0, null, "draft", "{\"base_xaf\":" + baseValue + ",\"rate_percent\":" + rateValue + ",\"advice\":\"accountant_validation_required\"}", session.account.memberId) }
                                .onSuccess { message = "Estimation sauvegardée comme brouillon, non déclarée." }
                                .onFailure { message = it.message ?: "Sauvegarde impossible." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Enregistrer le brouillon fiscal","Save tax draft","Danndu heblugol sagalle")) }
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.secondary)
                    Text(localizedLabel("NAXA ne soumet pas de déclaration fiscale et ne calcule pas un impôt exigible sans régime confirmé.","NAXA does not submit tax declarations or calculate tax due without a confirmed regime.","NAXA neldataa déclaration fiscale, limtataa sagalle yoɓeteɗe so laawol tabbitinaaka."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item { Text(localizedLabel("Opérations à finaliser","Operations to complete","Golle timmineteeɗe"), fontWeight = FontWeight.Bold) }
        items(records) { Text(it.title + " · " + xaf(it.amountXaf), color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
fun ObjectivesContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    val orgId = session.account.organizationId
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) {
        repository.dao.observeManagementRecordsByType(orgId, siteId, "business_goal")
    }.collectAsState(initial = emptyList())
    var title by rememberSaveable { mutableStateOf("Objectif de chiffre d’affaires") }
    var target by rememberSaveable { mutableStateOf("") }
    var period by rememberSaveable { mutableStateOf("daily") }
    var notice by remember { mutableStateOf<String?>(null) }
    val zone = remember { ZoneId.of("Africa/Douala") }
    val today = java.time.LocalDate.now(zone)
    val periodStart = when (period) {
        "monthly" -> today.withDayOfMonth(1)
        "annual" -> today.withDayOfYear(1)
        else -> today
    }
    val periodEnd = when (period) {
        "monthly" -> periodStart.plusMonths(1).minusDays(1)
        "annual" -> periodStart.plusYears(1).minusDays(1)
        else -> today
    }
    val startMillis = periodStart.atStartOfDay(zone).toInstant().toEpochMilli()
    val endMillis = periodEnd.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli() - 1L
    val sales by remember(orgId, siteId, startMillis, endMillis) {
        repository.dao.observeSalesTotal(orgId, siteId, startMillis, endMillis)
    }.collectAsState(initial = 0L)
    val activeTarget = records.filter {
        it.counterparty == period &&
            when (period) {
                "daily" -> java.time.Instant.ofEpochMilli(it.createdAtMillis).atZone(zone).toLocalDate() == today
                "monthly" -> {
                    val date = java.time.Instant.ofEpochMilli(it.createdAtMillis).atZone(zone).toLocalDate()
                    date.year == today.year && date.monthValue == today.monthValue
                }
                else -> java.time.Instant.ofEpochMilli(it.createdAtMillis).atZone(zone).year == today.year
            }
    }.maxByOrNull { it.createdAtMillis }
    val goal = activeTarget?.amountXaf ?: (target.toLongOrNull() ?: 0L)
    val progress = if (goal > 0L) (sales.toDouble() * 100.0 / goal.toDouble()) else 0.0
    val gap = (goal - sales).coerceAtLeast(0L)

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(localizedLabel("Pilotage et objectifs","Management and targets","Ɗowtugol e faandaare"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Baselines datées et historisées. Un nouvel objectif ajoute une nouvelle version ; il ne réécrit pas les objectifs déjà enregistrés.","Targets are dated and tracked. A new target adds a new version without overwriting earlier targets.","Faandaare kala e ñalnde e jaŋtol mum. Faandaare hesere ɓeydata, waylataa ɗe ndanndaa."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Les résultats de ce site reposent sur les ventes confirmées.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Période de pilotage","Reporting period","Sahaa ɗowtugol"))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("daily" to "Jour", "monthly" to "Mois", "annual" to "Année").forEach { option ->
                            OutlinedButton(onClick = { period = option.first }) {
                                Text((if (period == option.first) "✓ " else "") + option.second)
                            }
                        }
                    }
                    Text(localizedLabel("Du ","From ","Fuɗɗo e ") + periodStart.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")) +
                        " au " + periodEnd.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")),
                        style = MaterialTheme.typography.bodySmall)
                    Text(localizedLabel("CA confirmé : ","Confirmed revenue: ","Ceede jaaygol tabbitinaaɗe : ") + xaf(sales), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Objectif","Target","Faandaare")) })
                    OutlinedTextField(target, { target = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Cible de CA (FCFA)","Revenue target (XAF)","Faandaare ceede jaaygol (FCFA)")) }, singleLine = true)
                    if (activeTarget != null) {
                        Text(localizedLabel("Baseline actuellement applicable : ","Current target: ","Faandaare jooni : ") + xaf(activeTarget.amountXaf) + " · enregistrée le " +
                            java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(activeTarget.createdAtMillis)),
                            style = MaterialTheme.typography.bodySmall)
                    }
                    if (goal > 0L) {
                        androidx.compose.material3.LinearProgressIndicator(
                            progress = progress.toFloat().coerceIn(0f, 1f), modifier = Modifier.fillMaxWidth()
                        )
                        Text(localizedLabel("Atteinte : ","Achievement: ","Ko heɓaa : ") + String.format(java.util.Locale.FRANCE, "%.1f", progress) +
                            " % · " + if (gap > 0L) "reste " + xaf(gap) else "objectif atteint")
                    } else Text(localizedLabel("Aucune cible enregistrée pour cette période.","No target recorded for this period.","Alaa faandaare danndaande e sahaa oo."))
                    Button(
                        onClick = {
                            val value = target.toLongOrNull() ?: 0L
                            if (value <= 0L || title.isBlank()) notice = "Un objectif et une cible positive sont requis."
                            else scope.launch {
                                runCatching {
                                    repository.createManagementRecord(
                                        orgId, siteId, "business_goal",
                                        "OBJ-" + System.currentTimeMillis(), title.trim(), period, value, 0L,
                                        endMillis, "open",
                                        org.json.JSONObject()
                                            .put("period", period)
                                            .put("period_start", periodStart.toString())
                                            .put("period_end", periodEnd.toString())
                                            .put("baseline", "approved_at_creation")
                                            .put("version", records.count { it.counterparty == period } + 1)
                                            .toString(),
                                        session.account.memberId
                                    )
                                }.onSuccess {
                                    target = ""; notice = "Objectif approuvé et historisé. La baseline précédente est conservée."
                                }.onFailure { notice = it.message ?: "Enregistrement impossible." }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(localizedLabel("Enregistrer une nouvelle baseline","Save new target","Danndu faandaare hesere")) }
                    notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                }
            }
        }
        item { Text(localizedLabel("Historique des objectifs approuvés","Approved target history","Jaŋtol faandaare jaɓaaɗe"), fontWeight = FontWeight.Bold) }
        items(records.sortedByDescending { it.createdAtMillis }) { record ->
            Text(
                record.title + " · " + record.counterparty + " · " + xaf(record.amountXaf) + " · " +
                    java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(record.createdAtMillis)),
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

@Composable
private fun FinancialTrendRow(point: FinancialTrendPoint, comparisonLabel: String) {
    fun change(value: Long): String =
        (if (value > 0L) "+" else if (value < 0L) "−" else "") +
            xaf(kotlin.math.abs(value))
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        shape = RoundedCornerShape(14.dp)
    ) {
        Column(Modifier.fillMaxWidth().padding(13.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(point.label, fontWeight = FontWeight.SemiBold)
            Text(localizedLabel("CA confirmé : ","Confirmed revenue: ","Ceede jaaygol tabbitinaaɗe : ") + xaf(point.revenueXaf) + " · " + comparisonLabel + " : " + change(point.revenueDeltaXaf))
            Text(localizedLabel("Coût des ventes connu : ","Known cost of sales: ","Njoɓdi jaaygol anndaaɗi : ") + xaf(point.costOfGoodsXaf) + " · " + comparisonLabel + " : " + change(point.costOfGoodsDeltaXaf))
            Text(localizedLabel("Charges d'exploitation : ","Operating expenses: ","Njoɓdi golle : ") + xaf(point.operatingExpensesXaf) + " · " + comparisonLabel + " : " + change(point.operatingExpensesDeltaXaf))
            Text(localizedLabel("Marge brute : ","Gross margin: ","Ceede heddiiɗe : ") + (point.grossProfitXaf?.let {
                xaf(it) + " · " + comparisonLabel + " : " + (point.grossProfitDeltaXaf?.let(::change) ?: "—")
            } ?: "non calculable : coût direct incomplet"), color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(localizedLabel("Résultat opérationnel indicatif : ","Indicative operating result: ","Limooje golle tanƴaaɗe : ") + (point.operatingResultXaf?.let {
                xaf(it) + " · " + comparisonLabel + " : " + (point.operatingResultDeltaXaf?.let(::change) ?: "—")
            } ?: "non déterminable tant que le coût direct de toutes les ventes n'est pas documenté"), fontWeight = FontWeight.Medium)
            Text(localizedLabel("Fournisseurs : stock capitalisé ","Suppliers: capitalized stock ","Hokkooɓe jawdi : jawdi danndaandi ") + xaf(point.supplierStockPurchasesXaf) +
                    " · achats/consommables " + xaf(point.supplierOperatingPurchasesXaf) +
                    " · immobilisations " + xaf(point.supplierFixedAssetsXaf) +
                    " · paiements " + xaf(point.supplierPaymentsXaf),
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (point.uncostedSalesCount > 0) {
                Text(point.uncostedSalesCount.toString() +
                    " vente(s) avec coût direct manquant : la marge et le résultat sont volontairement masqués.",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun PerformanceProjectionCard(title: String, period: PeriodProjection) {
    val delta = period.projectedXaf - period.comparablePreviousXaf
    val comparison = if (period.comparablePreviousXaf > 0L) {
        (if (delta >= 0L) "+" else "") + xaf(delta) + " (" +
            String.format(java.util.Locale.FRANCE, "%.1f", delta.toDouble() * 100.0 / period.comparablePreviousXaf) + " %)"
    } else "Comparaison antérieure non disponible"
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(title, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Réalisé confirmé : ","Confirmed actual: ","Ko heɓaa tabbitinaama : ") + xaf(period.actualXaf))
            Text(localizedLabel("Projection de clôture : ","Closing forecast: ","Tanƴugol timmugol : ") + xaf(period.projectedXaf), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Période comparable : ","Comparable period: ","Sahaa yerondirgal : ") + xaf(period.comparablePreviousXaf) + " · " + comparison)
            period.targetXaf?.let { target ->
                Text(localizedLabel("Objectif approuvé : ","Approved target: ","Faandaare jaɓaande : ") + xaf(target))
                Text(
                    if ((period.targetGapXaf ?: 0L) > 0L) "Écart prévisionnel : " + xaf(period.targetGapXaf ?: 0L)
                    else "Objectif projeté atteint ou dépassé",
                    color = if ((period.targetGapXaf ?: 0L) > 0L) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                )
                period.achievementPercent?.let { ratio ->
                    androidx.compose.material3.LinearProgressIndicator(
                        progress = (ratio / 100.0).toFloat().coerceIn(0f, 1f),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Text(localizedLabel("Atteinte projetée : ","Projected achievement: ","Ko tanƴaa heɓde : ") + String.format(java.util.Locale.FRANCE, "%.1f", ratio) + " %")
                }
            } ?: Text(localizedLabel("Aucun objectif approuvé enregistré pour cette période.","No approved target recorded for this period.","Alaa faandaare jaɓaande danndaande e sahaa oo."))
        }
    }
}

@Composable
fun AiInsightsContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val orgId = session.account.organizationId
    val siteIds = session.account.activeSiteIds
    val zone = remember { ZoneId.of("Africa/Douala") }
    val fromMillis = remember { LocalDate.now(zone).minusYears(6).atStartOfDay(zone).toInstant().toEpochMilli() }
    val sales by remember(orgId, siteIds, fromMillis) {
        repository.dao.observeSalesForSites(orgId, siteIds, fromMillis)
    }.collectAsState(initial = emptyList())
    val accounting by remember(orgId, siteIds, fromMillis) {
        repository.dao.observeAccountingEntriesForSites(orgId, siteIds, fromMillis)
    }.collectAsState(initial = emptyList())
    val objectives by remember(orgId, siteIds) {
        repository.dao.observeManagementRecordsForSites(orgId, siteIds, "business_goal")
    }.collectAsState(initial = emptyList())
    val supplierPayables by remember(orgId, siteIds) {
        repository.dao.observeSupplierPayablesForSites(orgId, siteIds)
    }.collectAsState(initial = 0L)
    val lowStockCount by remember(orgId, siteIds) {
        repository.dao.observeLowStockCountForSites(orgId, siteIds)
    }.collectAsState(initial = 0)
    val dashboard = remember(sales, accounting, objectives, supplierPayables, lowStockCount) {
        NaxaPerformanceEngine.analyze(
            sales, accounting, objectives, supplierPayables, lowStockCount,
            System.currentTimeMillis(), zone
        )
    }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(localizedLabel("Assistant IA de pilotage","AI management assistant","Ballal IA ɗowtugol"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Prévisions de CA, comparaison des périodes et recommandations de redressement. Les projections utilisent les ventes confirmées disponibles et vos objectifs ; aucune vente en attente n'est comptée.","Revenue forecasts, period comparison and improvement recommendations use available confirmed sales and targets, excluding pending sales.","Tanƴugol ceede jaaygol, yerondirgol sahaaaji e laabi ɓeydude golle. Jaaygol tabbitinaangol e faandaare tan limtetee, wonaa jaaygol fadotoongol."),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            LocalOnlyNotice(
                "Les estimations s’appuient sur vos ventes des 14, 28 et 90 derniers jours. Elles évoluent avec votre activité."
            )
            Text(localizedLabel("Périmètre : ","Scope: ","Nokkuuji : ") + siteIds.size + " site(s) accessibles et consolidés.", style = MaterialTheme.typography.labelSmall)
            Text(localizedLabel("Couverture des ventes : ","Sales coverage: ","Jaaygol limtaangol : ") + dashboard.dataCoverageDays + " jour(s).", style = MaterialTheme.typography.labelSmall)
        }
        item { PerformanceProjectionCard("Aujourd'hui · jour par jour", dashboard.day) }
        item { PerformanceProjectionCard("Mois en cours · mois par mois", dashboard.month) }
        item { PerformanceProjectionCard("Année en cours · année par année", dashboard.year) }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(localizedLabel("Rentabilité et engagements fournisseurs","Profitability and supplier commitments","Njariñ e ɗaɓɓitanɗe hokkooɓe jawdi"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Chiffre d'affaires confirmé (période couverte) : ","Confirmed revenue (covered period): ","Ceede jaaygol tabbitinaaɗe (sahaa oo) : ") + xaf(dashboard.revenueXaf))
                    Text(localizedLabel("CA des ventes au coût fiable : ","Revenue with reliable costs: ","Ceede jaaygol ɗe njoɓdi mum anndaa : ") + xaf(dashboard.costedRevenueXaf))
                    Text(localizedLabel("Coût des marchandises vendues valorisées : ","Valued cost of goods sold: ","Njoɓdi jawdi jaayndi limtaandi : ") + xaf(dashboard.costOfGoodsXaf))
                    Text(localizedLabel("Marge brute sur ventes au coût connu : ","Gross margin on known-cost sales: ","Ceede heddiiɗe e jaaygol ɗe njoɓdi anndaa : ") + xaf(dashboard.grossProfitXaf) +
                        (dashboard.grossMarginPercent?.let { " · " + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %" } ?: " · non calculable"))
                    Text(localizedLabel("Charges d'exploitation journalisées : ","Recorded operating expenses: ","Njoɓdi golle danndaaɗi : ") + xaf(dashboard.operatingExpensesXaf))
                    Text(localizedLabel("Solde de gestion indicatif : ","Indicative management balance: ","Ceede heddiiɗe tanƴaaɗe : ") +
                        (dashboard.operatingProfitProxyXaf?.let { xaf(it) } ?: "non déterminable : COGS historique incomplet"),
                        fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Dette fournisseurs non réglée : ","Outstanding supplier debt: ","Ñaawoore hokkooɓe jawdi yoɓaaka : ") + xaf(dashboard.supplierPayablesXaf))
                    Text(localizedLabel("Flux fournisseurs comptabilisés ce mois-ci","Supplier transactions recorded this month","Golle hokkooɓe jawdi danndaaɗe e lewru nduu"), fontWeight = FontWeight.SemiBold)
                    Text(localizedLabel("Stocks reçus et capitalisés : ","Received and capitalized stock: ","Jawdi heɓaandi danndaandi : ") + xaf(dashboard.currentMonthSupplierStockPurchasesXaf))
                    Text(localizedLabel("Achats courants reçus et passés en charges : ","Received purchases recorded as expenses: ","Jawdi soodaaɗi heɓaaɗi limtaaɗi e njoɓdi : ") + xaf(dashboard.currentMonthSupplierOperatingPurchasesXaf))
                    Text(localizedLabel("Immobilisations reçues : ","Fixed assets received: ","Jawdi juutndi heɓaandi : ") + xaf(dashboard.currentMonthSupplierFixedAssetsXaf))
                    Text(localizedLabel("Règlements fournisseurs (trésorerie, sans seconde charge) : ","Supplier payments (cash flow, not an additional expense): ","Njoɓdi hokkooɓe jawdi (ceede yaltuɗe, wonaa njoɓdi ɗiɗol) : ") + xaf(dashboard.currentMonthSupplierPaymentsXaf))
                    if (dashboard.uncostedStockSalesCount > 0) {
                        Text(
                            dashboard.uncostedStockSalesCount.toString() + " vente(s) de stock antérieure(s) ne possèdent pas de coût historique fiable ; elles sont signalées et ne sont pas inventées dans le coût des ventes.",
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                    Text(localizedLabel("Les achats de stock n'augmentent pas le CA et ne sont pas déduits immédiatement de la marge : ils augmentent la valeur du stock et la dette fournisseur. Le coût est passé en coût des ventes lorsque le stock est vendu.","Stock purchases increase stock value and supplier debt, not revenue or immediate margin expenses. Costs are recognized when stock is sold.","Soodugol jawdi ɓeydataa ceede jaaygol, ustataa njariñ jooni: ɓeydata jawdi e ñaawoore. Njoɓdi limtetee so jawdi jaayama."),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(localizedLabel("Le solde de gestion est une estimation avant éléments non enregistrés, amortissements, commissions et fiscalité ; il n'est pas un résultat SYSCOHADA certifié.","The management balance is an estimate before unrecorded items, depreciation, commissions and tax; it is not a certified SYSCOHADA result.","Ceede heddiiɗe ko tanƴugol hade njoɓdi ɗi ndanndaaka, famɗugol jawdi, komisiyoŋ e sagalle; wonaa limooje SYSCOHADA tabbitinaaɗe."),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item { Text(localizedLabel("Performance jour par jour · 14 derniers jours","Daily performance · last 14 days","Limooje ñalawma kala · balɗe 14 sakkitiiɗe"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.dailyTrend) { row ->
            val delta = (if (row.deltaXaf >= 0L) "+" else "−") + xaf(if (row.deltaXaf >= 0L) row.deltaXaf else -row.deltaXaf)
            val rate = row.deltaPercent?.let { " (" + (if (it >= 0) "+" else "") + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %)" } ?: ""
            Text(row.label + " · " + xaf(row.actualXaf) + " · écart vs veille : " + delta + rate,
                style = MaterialTheme.typography.bodySmall)
        }
        item { Text(localizedLabel("Rentabilité et flux fournisseurs · détail jour par jour","Profitability and supplier flows · daily detail","Njariñ e golle hokkooɓe jawdi · ñalawma kala"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.dailyFinancialTrend, key = { "finance-day-" + it.label }) { point ->
            FinancialTrendRow(point, "vs veille")
        }
        item { Text(localizedLabel("Performance mois par mois · 12 derniers mois","Monthly performance · last 12 months","Limooje lewru kala · lebbi 12 sakkitiiɗi"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.monthlyTrend) { row ->
            val delta = (if (row.deltaXaf >= 0L) "+" else "−") + xaf(if (row.deltaXaf >= 0L) row.deltaXaf else -row.deltaXaf)
            val rate = row.deltaPercent?.let { " (" + (if (it >= 0) "+" else "") + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %)" } ?: ""
            Text(row.label + " · " + xaf(row.actualXaf) + " · écart vs mois précédent : " + delta + rate,
                style = MaterialTheme.typography.bodySmall)
        }
        item { Text(localizedLabel("Rentabilité et flux fournisseurs · détail mois par mois","Profitability and supplier flows · monthly detail","Njariñ e golle hokkooɓe jawdi · lewru kala"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.monthlyFinancialTrend, key = { "finance-month-" + it.label }) { point ->
            FinancialTrendRow(point, "vs période comparable du mois précédent")
        }
        item { Text(localizedLabel("Performance année par année · 5 derniers exercices","Annual performance · last 5 years","Limooje hitaande kala · duuɓi 5 sakkitiiɗi"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.yearlyTrend) { row ->
            val delta = (if (row.deltaXaf >= 0L) "+" else "−") + xaf(if (row.deltaXaf >= 0L) row.deltaXaf else -row.deltaXaf)
            val rate = row.deltaPercent?.let { " (" + (if (it >= 0) "+" else "") + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %)" } ?: ""
            Text(row.label + " · " + xaf(row.actualXaf) + " · écart vs exercice précédent : " + delta + rate,
                style = MaterialTheme.typography.bodySmall)
        }
        item { Text(localizedLabel("Rentabilité et flux fournisseurs · détail année par année","Profitability and supplier flows · annual detail","Njariñ e golle hokkooɓe jawdi · hitaande kala"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.yearlyFinancialTrend, key = { "finance-year-" + it.label }) { point ->
            FinancialTrendRow(point, "vs même période de l'exercice précédent")
        }
        item { Text(localizedLabel("Stratégies de redressement et de progression","Improvement strategies","Laabi ɓeydude golle"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.recoveryActions) { action ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(action.title + " · " + action.priority.uppercase(), fontWeight = FontWeight.Bold)
                    Text(action.detail)
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}

@Composable
internal fun ProfileContent(
    modifier: Modifier,
    session: AuthSession,
    authApi: AuthApi,
    activityProfile: String?,
    repository: NaxaServicesLocalRepository,
    preferences: NaxaServicesPreferences,
    onNavigate: (AppRoute) -> Unit,
    onLogout: () -> Unit
) {
    var showReferralScreen by rememberSaveable(session.account.memberId) { mutableStateOf(false) }
    var showLoyaltyScreen by rememberSaveable(session.account.memberId) { mutableStateOf(false) }
    if (showReferralScreen) {
        ReferralScreen(Modifier.fillMaxSize(), session, authApi, onBack = { showReferralScreen = false })
        return
    }
    if (showLoyaltyScreen) {
        LoyaltyProgramsContent(
            Modifier.fillMaxSize(), repository, session,
            activityProfile ?: session.account.activityProfile ?: "autre",
            onBack = { showLoyaltyScreen = false }
        )
        return
    }
    val context = LocalContext.current
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val history by remember(siteId) { repository.dao.observeManagementRecords(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val activity = NaxaActivityCatalog.find(activityProfile)
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(localizedLabel("Profil","Profile","Humpito am"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    PrivateProfilePhoto(session)
                    Text(session.account.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(session.account.roleCode + " · " + session.account.organizationName)
                    Text(localizedLabel("Identifiant membre : ","Member ID: ","Innol gollotooɗo : ") + session.account.memberId, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(localizedLabel("Activité : ","Activity: ","Golle : ") + (activity?.titleFr ?: "Non définie"))
                    Text(localizedLabel("Langue : ","Language: ","Ɗemngal : ") + session.account.defaultLocale.uppercase())
                    Text(localizedLabel("Modèle : ","Model: ","No golle ɗowtirtee : ") + when(session.account.businessMode) {
                        "solo" -> "PME autonome"
                        "single_site_multi_workstation" -> "Plusieurs emplacements dans un établissement"
                        "multi_site_network" -> "Promoteur multi-sites"
                        else -> session.account.businessMode
                    })
                    Text(session.account.activeSites.size.toString() + " point(s) de vente accessible(s)")
                }
            }
        }
        item {
            Text(localizedLabel("Préférences et sécurité","Preferences and security","Cuɓe e kisal"), fontWeight = FontWeight.Bold)
            OutlinedButton(onClick = { onNavigate(AppRoute.APPEARANCE) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Langue, thème et mode nuit","Language, theme and night mode","Ɗemngal, jayngol e jemma")) }
            OutlinedButton(onClick = { onNavigate(AppRoute.SECURITY) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Comptes, appareils et accès","Accounts, devices and access","Konte, kaɓirɗe e naatugol")) }
            OutlinedButton(onClick = { onNavigate(AppRoute.NOTIFICATIONS) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Centre de notifications","Notification centre","Nokkuure tintine")) }
            LocalAccessPinSettingsCard(session.account.memberId)
            if (session.account.roleCode == "promoter") {
                OutlinedButton(onClick = { showReferralScreen = true }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Parrainage PME et suivi de mes gains","Business referrals and reward tracking","Recommandation golle e rewindo njariñ am")) }
                OutlinedButton(onClick = { onNavigate(AppRoute.CUSTOMER_PROMOTIONS) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Parrainage client et roue promotionnelle","Customer referrals and promotional wheel","Recommandation soottotooɓe e roue")) }
                OutlinedButton(onClick = { showLoyaltyScreen = true }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Programme de fidélité","Loyalty program","Laawol hoolaare")) }
                OutlinedButton(onClick = { onNavigate(AppRoute.CHARGES) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Charges et échéances de paiement","Expenses and payment due dates","Njoɓdi e ñalɗi yoɓde")) }
            }
            OutlinedButton(onClick = { onNavigate(AppRoute.HELP) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("FAQ et assistance","FAQ and support","Naamne e ballal")) }
            OutlinedButton(onClick = { onNavigate(AppRoute.SUBSCRIPTIONS) }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Abonnement et paiement","Subscription and payment","Abonman e njoɓdi")) }
        }
        item {
            Text(localizedLabel("Historique","History","Jaŋtol"), fontWeight = FontWeight.Bold)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Consultez vos dernières opérations disponibles.")
        }
        items(history.take(30)) { item ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(12.dp)) {
                    Text(item.title, fontWeight = FontWeight.SemiBold)
                    Text(item.recordType + " · " + item.status + " · " + xaf(item.amountXaf), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            Button(onClick = onLogout, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Se déconnecter","Sign out","Yaltu")) }
            Spacer(Modifier.height(20.dp))
        }
    }
}

@Composable
fun LivechatContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable(session.account.organizationId) {
        mutableStateOf(siteIds.firstOrNull().orEmpty())
    }
    val requests by remember(session.account.organizationId, siteId) {
        repository.dao.observeSupportRequestsForSite(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    var subject by rememberSaveable { mutableStateOf("") }
    var message by rememberSaveable { mutableStateOf("") }
    var notice by remember { mutableStateOf<String?>(null) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(localizedLabel("Livechat et assistance","Livechat and support","Livechat e ballal"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(localizedLabel("Consultez la FAQ et envoyez une demande d’assistance.","Read the FAQ and send a support request.","Yiy naamne e neldu ɗaɓɓitannde ballal."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(
                siteIds,
                siteId,
                session.account.activeSites.associate { it.id to it.name }
            ) { siteId = it }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Questions fréquentes","Frequently asked questions","Naamne ɓurɗe naamneede"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("• Comment ouvrir et clôturer une caisse ?","• How do I open and close a register?","• No udditirtee e uddirtee keesu?"))
                    Text(localizedLabel("• Comment corriger une erreur sans effacer l’historique ?","• How do I correct an error without deleting history?","• No peewnirtee juumre tawa jaŋtol momtaaka?"))
                    Text(localizedLabel("• Comment ajouter un employé ou un point de vente ?","• How do I add an employee or a location?","• No ɓeydirtée gollotooɗo walla nokkuure jaaygol?"))
                    Text(localizedLabel("• Comment sauvegarder et restaurer mes données ?","• How do I back up and restore my data?","• No danndirtee e heɓtirtee humpito am?"))
                    Text(localizedLabel("• Comment suivre une échéance d’abonnement ?","• How do I track a subscription due date?","• No rewindirtee ñalnde abonman?"))
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(subject, { subject = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Sujet","Subject","Ko ɗaɓɓitaa")) })
                    OutlinedTextField(message, { message = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Votre message","Your message","Ɓatakuru maa")) }, minLines = 4)
                    Button(onClick = {
                        if (subject.isBlank() || message.trim().length < 10) notice = "Saisis un sujet et au moins 10 caractères."
                        else scope.launch {
                            runCatching { repository.createSupportRequest(session.account.organizationId, siteId, subject, message, "normal") }
                                .onSuccess { subject = ""; message = ""; notice = "Demande enregistrée, en attente d'envoi." }
                                .onFailure { notice = it.message ?: "Envoi impossible." }
                        }
                    }, enabled = siteId.isNotBlank(), modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Créer une demande","Create request","Sos ɗaɓɓitannde")) }
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text(localizedLabel("Demandes récentes","Recent requests","Ɗaɓɓitanɗe sakkitiiɗe"), fontWeight = FontWeight.Bold) }
        items(requests.take(20)) { Text(it.subject + " · " + it.state, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

private fun labelRecord(type: String) = when(type) {
    "quote" -> "Devis"
    "work_order" -> "Ordre de travail"
    "repair_order" -> "Ordre de réparation"
    "service_order" -> "Ordre de service"
    "invoice" -> "Facture"
    "cash_receipt" -> "Reçu de caisse"
    "credit_note" -> "Avoir"
    "customer_receivable" -> "Créance client (à recevoir par la PME)"
    "refund_due" -> "Remboursement dû au client (à payer par la PME)"
    "purchase" -> "Achat"
    "subscription_request" -> "Demande d’abonnement"
    "tax_estimate" -> "Estimation fiscale"
    "business_goal" -> "Objectif"
    else -> type
}
private fun statusRecord(status: String) = when(status) {
    "paid" -> "Soldé"
    "partial" -> "Partiellement réglé"
    "open" -> "À régler"
    "draft" -> "Brouillon"
    else -> status
}
private fun shareRecord(context: Context, item: LocalManagementRecord) {
    val text = buildString {
        append("NAXA SERVICES — ").append(labelRecord(item.recordType)).append("\n")
        append(item.reference).append("\n").append(item.title).append("\n")
        append("Client : ").append(item.counterparty).append("\n")
        append("Total : ").append(xaf(item.amountXaf)).append("\n")
        append("Réglé : ").append(xaf(item.paidXaf)).append("\n")
        append("Reste : ").append(xaf(item.amountXaf - item.paidXaf))
    }
    val intent = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
    context.startActivity(Intent.createChooser(intent, "Partager le reçu"))
}
private fun writeReceiptPdf(context: Context, uri: Uri, item: LocalManagementRecord, organization: String) {
    context.contentResolver.openOutputStream(uri)?.use { output ->
        output.write(receiptPdfBytes(item, organization))
    } ?: error("Destination inaccessible.")
}



@Composable
fun CashReceiptActions(sale: LocalSale, session: AuthSession, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val record = remember(sale.id) {
        LocalManagementRecord(
            id = sale.id,
            orgId = sale.orgId,
            siteId = sale.siteId,
            recordType = "cash_receipt",
            reference = sale.saleNumber,
            title = sale.description,
            counterparty = "Client au comptoir",
            amountXaf = sale.totalXaf,
            paidXaf = if (sale.status == "confirmed") sale.totalXaf else 0L,
            dueAtMillis = null,
            status = if (sale.status == "confirmed") "paid" else "open",
            metadataJson = "{\"payment_method\":\"" + sale.paymentMethod + "\",\"sale_status\":\"" + sale.status + "\"}",
            actorMemberId = sale.actorMemberId,
            createdAtMillis = sale.createdAtMillis
        )
    }
    var error by remember { mutableStateOf<String?>(null) }
    val saveLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        if (uri != null) {
            runCatching { writeReceiptPdf(context, uri, record, session.account.organizationName) }
                .onFailure { error = it.message ?: "Enregistrement PDF impossible." }
        }
    }
    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        Card(shape = RoundedCornerShape(22.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(localizedLabel("Reçu de caisse","Cash receipt","Kayit ceede"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(record.reference + " · " + xaf(record.amountXaf))
                Text(if (sale.status == "pending") "Paiement Mobile Money en attente : ce reçu n'atteste pas encore du règlement." else "Paiement espèces enregistré.")
                Text(localizedLabel("Choisis une action pour remettre le justificatif au client.","Choose how to provide the receipt to the customer.","Suɓo laawol hokkude kayit soottotooɗo."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(onClick = { saveLauncher.launch("NAXA-" + sale.saleNumber + ".pdf") }, modifier = Modifier.fillMaxWidth()) {
                    Text(localizedLabel("Télécharger / enregistrer le PDF","Download / save PDF","Heɓ / danndu PDF"))
                }
                OutlinedButton(
                    onClick = {
                        runCatching {
                            val file = writeReceiptToCache(context, record, session.account.organizationName)
                            val uri = FileProvider.getUriForFile(context, context.packageName + ".fileprovider", file)
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/pdf"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                clipData = ClipData.newUri(context.contentResolver, "Reçu NAXA SERVICES", uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            context.startActivity(Intent.createChooser(intent, "Partager le reçu PDF"))
                        }.onFailure { error = it.message ?: "Partage PDF impossible." }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text(localizedLabel("Partager le PDF (WhatsApp ou autre)","Share PDF (WhatsApp or other)","Lollin PDF (WhatsApp walla goɗɗum)")) }
                OutlinedButton(
                    onClick = {
                        runCatching { printReceipt(context, record, session.account.organizationName) }
                            .onFailure { error = it.message ?: "Impression impossible." }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text(localizedLabel("Imprimer le reçu","Print receipt","Winnditin kayit")) }
                if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Fermer","Close","Uddu")) }
            }
        }
    }
}

private fun writeReceiptToCache(context: Context, item: LocalManagementRecord, organization: String): java.io.File {
    val folder = java.io.File(context.cacheDir, "receipts")
    if (!folder.exists() && !folder.mkdirs()) error("Répertoire de reçu inaccessible.")
    val safeName = item.reference.replace(Regex("[^A-Za-z0-9_-]"), "_") + ".pdf"
    val file = java.io.File(folder, safeName)
    file.outputStream().use { it.write(receiptPdfBytes(item, organization)) }
    return file
}

private fun printReceipt(context: Context, item: LocalManagementRecord, organization: String) {
    val manager = context.getSystemService(Context.PRINT_SERVICE) as? PrintManager ?: error("Service d’impression non disponible.")
    val bytes = receiptPdfBytes(item, organization)
    val adapter = object : PrintDocumentAdapter() {
        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes,
            cancellationSignal: CancellationSignal,
            callback: LayoutResultCallback,
            extras: Bundle?
        ) {
            if (cancellationSignal.isCanceled) {
                callback.onLayoutCancelled()
                return
            }
            val info = PrintDocumentInfo.Builder(item.reference + ".pdf")
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .setPageCount(1)
                .build()
            callback.onLayoutFinished(info, true)
        }

        override fun onWrite(
            pages: Array<out PageRange>,
            destination: ParcelFileDescriptor,
            cancellationSignal: CancellationSignal,
            callback: WriteResultCallback
        ) {
            if (cancellationSignal.isCanceled) {
                callback.onWriteCancelled()
                return
            }
            runCatching {
                java.io.FileOutputStream(destination.fileDescriptor).use { it.write(bytes) }
            }.onSuccess {
                callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            }.onFailure {
                callback.onWriteFailed(it.message ?: "Écriture du PDF impossible.")
            }
        }
    }
    val attributes = PrintAttributes.Builder()
        .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
        .setResolution(PrintAttributes.Resolution("naxa-services", "NAXA SERVICES", 300, 300))
        .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
        .build()
    manager.print("NAXA-" + item.reference, adapter, attributes)
}

private fun receiptPdfBytes(item: LocalManagementRecord, organization: String): ByteArray {
    val document = PdfDocument()
    try {
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = document.startPage(pageInfo)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 18f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            color = android.graphics.Color.BLACK
        }
        val normal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 13f
            color = android.graphics.Color.DKGRAY
        }
        page.canvas.drawText("NAXA SERVICES", 42f, 56f, paint)
        paint.textSize = 16f
        page.canvas.drawText(labelRecord(item.recordType), 42f, 102f, paint)
        val lines = listOf(
            "Organisation : " + organization,
            "Référence : " + item.reference,
            "Libellé : " + item.title,
            "Client : " + item.counterparty,
            "Date : " + java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(item.createdAtMillis)),
            "Total : " + xaf(item.amountXaf),
            "Réglé : " + xaf(item.paidXaf),
            "Solde : " + xaf(item.amountXaf - item.paidXaf),
            "Statut : " + statusRecord(item.status),
            "Document établi localement — à synchroniser et valider."
        )
        lines.forEachIndexed { index, line -> page.canvas.drawText(line.take(85), 42f, 150f + index * 30f, normal) }
        page.canvas.drawText("Établi avec NAXA SERVICES", 42f, 790f, normal)
        document.finishPage(page)
        val output = java.io.ByteArrayOutputStream()
        document.writeTo(output)
        return output.toByteArray()
    } finally {
        document.close()
    }
}


@Composable
fun WorkOrdersContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession,
    activityProfile: String?
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val sites = session.account.activeSiteIds
    val fr = session.account.defaultLocale != "en"
    val workflow = ActivityWorkflows.get(activityProfile)
    val profile = workflow.profile
    // Parfumerie is a retail journey. This register is only for special orders/reservations;
    // ordinary product sales remain in catalogue, inventory and POS.
    val recordType = if (workflow.recordType == "retail") "work_order" else workflow.recordType
    var siteId by rememberSaveable { mutableStateOf(sites.firstOrNull().orEmpty()) }
    val records by remember(siteId, recordType) {
        repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, recordType)
    }.collectAsState(initial = emptyList())
    val workstations by remember(siteId) {
        repository.dao.observeWorkstations(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())

    var workstationId by rememberSaveable { mutableStateOf("") }
    var customer by rememberSaveable { mutableStateOf("") }
    var title by rememberSaveable { mutableStateOf("") }
    val fieldValues = remember(profile, session.account.memberId) { mutableStateMapOf<String, String>() }
    var estimate by rememberSaveable { mutableStateOf("0") }
    var requestedDeposit by rememberSaveable { mutableStateOf("0") }
    var dueDays by rememberSaveable { mutableStateOf("3") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    val requiredErrors = ActivityWorkflows.validate(profile, fieldValues)
    val primaryDetail = workflow.fields.firstNotNullOfOrNull { field ->
        fieldValues[field.key]?.trim()?.takeIf { it.isNotEmpty() }
    }.orEmpty()

    fun showDatePicker(key: String) {
        val existing = fieldValues[key].orEmpty()
        val parsed = runCatching { java.time.LocalDate.parse(existing) }.getOrNull()
        val calendar = Calendar.getInstance()
        if (parsed != null) {
            calendar.set(parsed.year, parsed.monthValue - 1, parsed.dayOfMonth)
        }
        android.app.DatePickerDialog(
            context,
            { _, year, month, day ->
                fieldValues[key] = "%04d-%02d-%02d".format(java.util.Locale.ROOT, year, month + 1, day)
            },
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH),
            calendar.get(Calendar.DAY_OF_MONTH)
        ).show()
    }

    fun labelForField(field: ActivityFieldDefinition): String =
        if (fr) field.labelFr else field.labelEn

    fun stageLabel(status: String): String {
        val stage = workflow.stage(if (status == "open") "received" else status)
        return if (fr) stage?.labelFr ?: status else stage?.labelEn ?: status
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                (when (session.account.defaultLocale) { "en" -> "Business journey — "; "ff-CM" -> "Golle — "; else -> "Parcours métier — " }) + if (fr) workflow.titleFr else workflow.titleEn,
                if (fr) workflow.purposeFr else workflow.purposeEn
            )
            AuthorizedSitePicker(
                sites, siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it; workstationId = "" }
            LocalOnlyNotice(
                when (session.account.defaultLocale) { "en" -> "Track your orders. Record payments in the cash register."; "ff-CM" -> "Rewindo golle maa. Danndu ceede keɓaaɗe e keesu."; else -> "Suivez vos dossiers. Enregistrez les encaissements dans la caisse." }
            )
            workflow.notesFr.forEach { note ->
                Text("• " + note, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            }
            if (profile == "beaute" && fr) {
                Text(localizedLabel("Ne saisis aucune donnée médicale, aucun diagnostic ni antécédent dans ce dossier.","Do not enter medical data, diagnoses or medical history in this file.","Hoto winndu humpito cellal, ñawu walla jaŋtol cellal e kayit ngol."), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            if (workflow.journey == "retail") {
                Text(
                    when (session.account.defaultLocale) { "en" -> "Special-order flow only. A real sale must be created in POS, with separate inventory and payment records."; "ff-CM" -> "Ɗoo ko ɗaɓɓitannde walla sahaa tan. Jaaygol goonga foti sosaade e nokkuure jaaygol e jawdi e njoɓdi mum."; else -> "Parcours spécial : commande ou réservation uniquement. Une vente réelle doit être créée dans le Point de vente, avec son stock et son paiement distincts." },
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "New record"; "ff-CM" -> "Golle kesere"; else -> "Nouveau dossier" }, fontWeight = FontWeight.Bold)
                    Text(
                        when (session.account.defaultLocale) { "en" -> "Workstation (optional — the ledger remains consolidated at site level)"; "ff-CM" -> "Nokkuure golle (so a yiɗi — jaŋtol heddotoo e nokkuure jaaygol)"; else -> "Emplacement / poste (facultatif — le registre reste consolidé au niveau du site)" },
                        fontWeight = FontWeight.SemiBold
                    )
                    OutlinedButton(onClick = { workstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (workstationId.isBlank()) (when (session.account.defaultLocale) { "en" -> "✓ No dedicated workstation"; "ff-CM" -> "✓ Alaa nokkuure golle keeriiɗe"; else -> "✓ Aucun poste dédié" }) else when (session.account.defaultLocale) { "en" -> "No dedicated workstation"; "ff-CM" -> "Alaa nokkuure golle keeriiɗe"; else -> "Aucun poste dédié" })
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { workstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (workstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    OutlinedTextField(
                        customer, { customer = it },
                        Modifier.fillMaxWidth(),
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Customer / requester"; "ff-CM" -> "Soottotooɗo / ɗaɓɓitotooɗo"; else -> "Client / donneur d'ordre" }) },
                        singleLine = true
                    )
                    OutlinedTextField(
                        title, { title = it },
                        Modifier.fillMaxWidth(),
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Record title"; "ff-CM" -> "Innde golle"; else -> "Intitulé du dossier" }) },
                        singleLine = true
                    )

                    workflow.fields.forEach { field ->
                        val value = fieldValues[field.key].orEmpty()
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            when (field.kind) {
                                ActivityFieldKind.SELECT -> {
                                    Text(labelForField(field) + if (field.required) " *" else "", fontWeight = FontWeight.Medium)
                                    field.options.forEach { option ->
                                        OutlinedButton(
                                            onClick = { fieldValues[field.key] = option.value },
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            val optionLabel = if (fr) option.labelFr else option.labelEn
                                            Text((if (value == option.value) "✓ " else "") + optionLabel)
                                        }
                                    }
                                }
                                ActivityFieldKind.DATE -> {
                                    Text(labelForField(field) + if (field.required) " *" else "", fontWeight = FontWeight.Medium)
                                    OutlinedButton(onClick = { showDatePicker(field.key) }, modifier = Modifier.fillMaxWidth()) {
                                        Text(if (value.isBlank()) {
                                            when (session.account.defaultLocale) { "en" -> "Choose a date"; "ff-CM" -> "Suɓo ñalnde"; else -> "Choisir une date" }
                                        } else value)
                                    }
                                }
                                ActivityFieldKind.NUMBER -> OutlinedTextField(
                                    value = value,
                                    onValueChange = { next -> fieldValues[field.key] = next.filter(Char::isDigit).take(18) },
                                    modifier = Modifier.fillMaxWidth(),
                                    label = { Text(labelForField(field) + if (field.required) " *" else "") },
                                    singleLine = true
                                )
                                ActivityFieldKind.TEXTAREA -> OutlinedTextField(
                                    value = value,
                                    onValueChange = { next -> fieldValues[field.key] = next.take(field.maxLength) },
                                    modifier = Modifier.fillMaxWidth(),
                                    label = { Text(labelForField(field) + if (field.required) " *" else "") },
                                    minLines = 3
                                )
                                ActivityFieldKind.TEXT -> OutlinedTextField(
                                    value = value,
                                    onValueChange = { next -> fieldValues[field.key] = next.take(field.maxLength) },
                                    modifier = Modifier.fillMaxWidth(),
                                    label = { Text(labelForField(field) + if (field.required) " *" else "") },
                                    singleLine = true
                                )
                            }
                            field.helpFr?.takeIf { fr }?.let {
                                Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }

                    OutlinedTextField(
                        estimate,
                        { estimate = it.filter(Char::isDigit).take(18) },
                        Modifier.fillMaxWidth(),
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Estimated amount / quote (XAF)"; "ff-CM" -> "Ceede tanƴaaɗe / devis (FCFA)"; else -> "Montant estimatif / devis (FCFA)" }) },
                        singleLine = true
                    )
                    OutlinedTextField(
                        requestedDeposit,
                        { requestedDeposit = it.filter(Char::isDigit).take(18) },
                        Modifier.fillMaxWidth(),
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Requested deposit (not collected here) (XAF)"; "ff-CM" -> "Ceede adiiɗe ɗaɓɓitaaɗe (heɓaaka ɗoo) (FCFA)"; else -> "Acompte demandé (non encaissé ici) (FCFA)" }) },
                        singleLine = true
                    )
                    OutlinedTextField(
                        dueDays,
                        { dueDays = it.filter(Char::isDigit).take(3) },
                        Modifier.fillMaxWidth(),
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Estimated lead time in days"; "ff-CM" -> "Balɗe tanƴaaɗe"; else -> "Délai estimé en jours" }) },
                        singleLine = true
                    )
                    Button(
                        onClick = {
                            val amount = estimate.toLongOrNull()
                            val deposit = requestedDeposit.toLongOrNull() ?: 0L
                            val delay = dueDays.toLongOrNull()
                            val fieldErrors = ActivityWorkflows.validate(profile, fieldValues)
                            if (customer.trim().length < 2 || title.trim().length < 2 || amount == null || amount < 0L ||
                                deposit < 0L || deposit > amount || delay == null || delay !in 0L..365L ||
                                fieldErrors.isNotEmpty()
                            ) {
                                val missingLabels = fieldErrors.mapNotNull { key -> workflow.fields.firstOrNull { it.key == key }?.let(::labelForField) }
                                error = if (fr) {
                                    buildString {
                                        append("Vérifie le client, l'intitulé, les montants, le délai (0 à 365 jours)")
                                        if (missingLabels.isNotEmpty()) append(" et les champs : " + missingLabels.joinToString(", "))
                                        append(".")
                                    }
                                } else {
                                    "Check customer, title, amounts, lead time (0–365 days) and required activity fields: " + missingLabels.joinToString(", ")
                                }
                            } else scope.launch {
                                busy = true
                                runCatching {
                                    val fieldsJson = JSONObject()
                                    fieldValues.forEach { (key, value) ->
                                        if (value.isNotBlank()) fieldsJson.put(key, value.trim())
                                    }
                                    val compatibilityPrimary = primaryDetail.ifBlank { title.trim() }
                                    val compatibilitySpecifications = workflow.fields.drop(1)
                                        .firstNotNullOfOrNull { field -> fieldValues[field.key]?.trim()?.takeIf { it.isNotEmpty() } }
                                        .orEmpty()
                                    val materialsValue = fieldValues["materials"] ?: fieldValues["fabric"] ?:
                                        fieldValues["products"] ?: fieldValues["equipment"].orEmpty()
                                    val metadata = JSONObject()
                                        .put("activity", profile)
                                        .put("activity_profile", profile)
                                        .put("journey", workflow.journey)
                                        .put("workflow_version", 2)
                                        .put("workflowVersion", 2)
                                        .put("fields", fieldsJson)
                                        .put("primaryDetail", compatibilityPrimary)
                                        .put("specifications", compatibilitySpecifications)
                                        .put("materials", materialsValue)
                                        .put("assignedStaffLabel", fieldValues["provider"] ?: fieldValues["team"].orEmpty())
                                        .put("depositRequestedXaf", deposit)
                                        .toString()
                                    val referencePrefix = when (recordType) {
                                        "repair_order" -> "REP-"
                                        "service_order" -> "SRV-"
                                        else -> "WO-"
                                    }
                                    repository.createManagementRecord(
                                        session.account.organizationId,
                                        siteId,
                                        recordType,
                                        referencePrefix + System.currentTimeMillis(),
                                        title.trim(),
                                        customer.trim(),
                                        amount,
                                        0L,
                                        System.currentTimeMillis() + delay * 86_400_000L,
                                        "received",
                                        metadata,
                                        session.account.memberId,
                                        workstationId.takeIf { it.isNotBlank() }
                                    )
                                }.onSuccess {
                                    customer = ""
                                    title = ""
                                    fieldValues.clear()
                                    estimate = "0"
                                    requestedDeposit = "0"
                                    dueDays = "3"
                                    error = null
                                    message = when (session.account.defaultLocale) { "en" -> "Record saved. Initial status: received. No payment was recorded."; "ff-CM" -> "Golle danndaama. Ngonka arande: heɓaama. Alaa ceede keɓaaɗe."; else -> "Dossier enregistré. Statut initial : reçu. Aucun encaissement n'a été créé." }
                                }.onFailure {
                                    error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to create record."; "ff-CM" -> "Sosugol waawataa."; else -> "Création impossible." }
                                }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && customer.trim().length >= 2 &&
                            title.trim().length >= 2 && (estimate.toLongOrNull() ?: -1L) >= 0L &&
                            requestedDeposit.toLongOrNull()?.let { it >= 0L && estimate.toLongOrNull()?.let { amount -> it <= amount } == true } == true &&
                            dueDays.toLongOrNull()?.let { it in 0L..365L } == true && requiredErrors.isEmpty(),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(if (busy) {
                            when (session.account.defaultLocale) { "en" -> "Saving…"; "ff-CM" -> "Nana dannda…"; else -> "Enregistrement…" }
                        } else {
                            when (session.account.defaultLocale) { "en" -> "Create record"; "ff-CM" -> "Sos golle"; else -> "Créer le dossier" }
                        })
                    }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Site records"; "ff-CM" -> "Golle nokkuure jaaygol"; else -> "Dossiers du point de vente" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (records.isEmpty()) {
            item { Text(when (session.account.defaultLocale) { "en" -> "No records yet."; "ff-CM" -> "Alaa golle danndaaɗe."; else -> "Aucun dossier enregistré." }, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        items(records) { item ->
            val events by remember(item.id, siteId) {
                repository.dao.observeWorkflowEvents(session.account.organizationId, siteId, item.recordType, item.id)
            }.collectAsState(initial = emptyList())
            var reason by rememberSaveable(item.id) { mutableStateOf("") }
            val metadata = remember(item.id, item.metadataJson) {
                runCatching { JSONObject(item.metadataJson) }.getOrElse { JSONObject() }
            }
            val storedFields = remember(item.id, item.metadataJson) {
                runCatching { metadata.optJSONObject("fields") }.getOrNull()
            }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(item.reference + " · " + item.title, fontWeight = FontWeight.Bold)
                    Text(item.counterparty)
                    item.workstationId?.let { id ->
                        Text(workstations.firstOrNull { it.id == id }?.name ?: id, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                    if (storedFields != null) {
                        workflow.fields.forEach { field ->
                            val value = storedFields.optString(field.key)
                            if (value.isNotBlank()) {
                                Text(
                                    (if (fr) field.labelFr else field.labelEn) + " : " + value,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                        }
                    } else {
                        val legacyDetail = metadata.optString("primaryDetail")
                        val legacySpecification = metadata.optString("specifications")
                        if (legacyDetail.isNotBlank()) Text(legacyDetail)
                        if (legacySpecification.isNotBlank()) Text(legacySpecification, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(
                        (when (session.account.defaultLocale) { "en" -> "Estimated amount"; "ff-CM" -> "Ceede tanƴaaɗe"; else -> "Montant estimatif" }) + " : " + xaf(item.amountXaf) +
                            " · " + (when (session.account.defaultLocale) { "en" -> "Deposit requested"; "ff-CM" -> "Ceede adiiɗe ɗaɓɓitaaɗe"; else -> "Acompte demandé" }) + " : " +
                            xaf(metadata.optLong("depositRequestedXaf", 0L)) +
                            " · " + (when (session.account.defaultLocale) { "en" -> "Deposit actually collected"; "ff-CM" -> "Ceede adiiɗe keɓaaɗe"; else -> "Acompte réellement encaissé" }) + " : " + xaf(item.paidXaf)
                    )
                    Text((when (session.account.defaultLocale) { "en" -> "Status"; "ff-CM" -> "Ngonka"; else -> "Statut" }) + " : " + stageLabel(item.status), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    Text((when (session.account.defaultLocale) { "en" -> "Due"; "ff-CM" -> "Ñalnde timmugol"; else -> "Échéance" }) + " : " + (item.dueAtMillis?.let { java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(it)) } ?: "—"))
                    if (item.status !in setOf("closed", "cancelled")) {
                        OutlinedTextField(
                            reason,
                            { reason = it.take(500) },
                            Modifier.fillMaxWidth(),
                            label = { Text(when (session.account.defaultLocale) { "en" -> "Reason required for status change"; "ff-CM" -> "Daliilu waajib ngam waylude feere"; else -> "Motif obligatoire pour changer l'étape" }) },
                            minLines = 1
                        )
                        workflow.nextStages(item.status).forEach { nextStage ->
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(
                                                session.account.organizationId, siteId, item.id, nextStage.code, reason,
                                                session.account.memberId
                                            )
                                        }.onSuccess {
                                            reason = ""
                                            error = null
                                            message = when (session.account.defaultLocale) { "en" -> "Stage updated."; "ff-CM" -> "Feere hesɗitinaama e danndaama."; else -> "Étape mise à jour et journalisée." }
                                        }.onFailure {
                                            error = it.message ?: when (session.account.defaultLocale) { "en" -> "Transition failed."; "ff-CM" -> "Waylugol feere waawataa."; else -> "Transition impossible." }
                                        }
                                    }
                                },
                                enabled = reason.trim().length in 3..500,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(if (fr) nextStage.labelFr else nextStage.labelEn)
                            }
                        }
                    }
                    if (events.isNotEmpty()) {
                        Text(when (session.account.defaultLocale) { "en" -> "Activity history"; "ff-CM" -> "Jaŋtol feere"; else -> "Historique des étapes" }, fontWeight = FontWeight.SemiBold)
                        events.take(5).forEach { event ->
                            Text(
                                event.fromStatus + " → " + event.toStatus + " · " + event.reason,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TeamPerformanceContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    val fr = session.account.defaultLocale != "en"
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) {
        repository.dao.observeManagementRecords(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val workstations by remember(siteId) {
        repository.dao.observeWorkstations(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())

    var staff by rememberSaveable { mutableStateOf("") }
    var detail by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("") }
    var attendanceOperation by rememberSaveable { mutableStateOf("staff_clock_in") }
    var payrollOperation by rememberSaveable { mutableStateOf("staff_commission") }
    var attendanceWorkstationId by rememberSaveable { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    val attendance = records.filter {
        it.recordType in setOf("staff_clock_in", "staff_clock_out", "staff_break_start", "staff_break_end")
    }
    val payroll = records.filter {
        session.account.roleCode in setOf("promoter","network_manager","site_manager") && it.recordType in setOf("staff_commission", "staff_advance", "staff_bonus")
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                when (session.account.defaultLocale) { "en" -> "Attendance, working hours and variable pay"; "ff-CM" -> "Naatugol, sahaaaji e ceede golluɓe"; else -> "Présences, horaires et rémunérations variables" },
                when (session.account.defaultLocale) { "en" -> "Validated clocking sequence, breaks, workstation assignment, commissions, advances and bonuses."; "ff-CM" -> "Winndugol naatugol, fooftugol, nokkuuji golle, komisiyoŋ, ceede adiiɗe e bonis."; else -> "Pointage chronologique, pauses, affectation par poste, commissions, avances et primes." }
            )
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) {
                siteId = it
                attendanceWorkstationId = ""
            }
            LocalOnlyNotice(
                when (session.account.defaultLocale) { "en" -> "Track attendance. Time entries remain pending approval."; "ff-CM" -> "Rewindo sahaaaji naatugol. Winndanɗe ƴeewtetee."; else -> "Suivez les heures de présence. Les pointages restent soumis à validation." }
            )
        }
        if (rosterAvailable(session.account.businessMode)) {
            if (BuildConfig.ATTENDANCE_ENABLED) {
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(when(session.account.defaultLocale){"en"->"Attendance workstation";"ff-CM"->"Nokkuure golle";else->"Emplacement du pointage"},fontWeight=FontWeight.SemiBold)
                            OutlinedButton(onClick={attendanceWorkstationId=""}, modifier=Modifier.fillMaxWidth()){Text((if(attendanceWorkstationId.isBlank())"✓ " else "")+when(session.account.defaultLocale){"en"->"Site-level attendance";"ff-CM"->"Naatugol e nokkuure";else->"Pointage au niveau du site"})}
                            workstations.filter{it.status=="active"}.forEach{workstation->OutlinedButton(onClick={attendanceWorkstationId=workstation.id},modifier=Modifier.fillMaxWidth()){Text((if(attendanceWorkstationId==workstation.id)"✓ " else "")+workstation.name)}}
                        }
                    }
                }
                item { AttendanceEvidenceCard(repository,session,siteId,attendanceWorkstationId.takeIf { it.isNotBlank() }) }
            } else item { LocalOnlyNotice(when(session.account.defaultLocale){"en"->"Secure attendance is temporarily unavailable.";"ff-CM"->"Winndugol naatugol kisngol heɓotaake jooni.";else->"Le pointage sécurisé est temporairement indisponible."}) }
        } else item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Team time clock"; "ff-CM" -> "Winndanɗe naatugol e golle"; else -> "Pointage et mouvements d’équipe" }, fontWeight = FontWeight.Bold)
                    Text(session.account.displayName, fontWeight = FontWeight.SemiBold)
                    Text(when (session.account.defaultLocale) { "en" -> "Workstation (optional)"; "ff-CM" -> "Nokkuure golle (so a yiɗi)"; else -> "Emplacement / poste (facultatif)" }, fontWeight = FontWeight.SemiBold)
                    OutlinedButton(onClick = { attendanceWorkstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (attendanceWorkstationId.isBlank()) (when (session.account.defaultLocale) { "en" -> "✓ Site-level time clock"; "ff-CM" -> "✓ Winndugol naatugol e nokkuure"; else -> "✓ Pointage au niveau du site" }) else when (session.account.defaultLocale) { "en" -> "No dedicated workstation"; "ff-CM" -> "Alaa nokkuure golle keeriiɗe"; else -> "Aucun poste dédié" })
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { attendanceWorkstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (attendanceWorkstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    listOf(
                        "staff_clock_in" to (when (session.account.defaultLocale) { "en" -> "Clock in"; "ff-CM" -> "Fuɗɗagol golle"; else -> "Prise de service" }),
                        "staff_break_start" to (when (session.account.defaultLocale) { "en" -> "Start break"; "ff-CM" -> "Fuɗɗagol fooftugol"; else -> "Début de pause" }),
                        "staff_break_end" to (when (session.account.defaultLocale) { "en" -> "End break"; "ff-CM" -> "Timmugol fooftugol"; else -> "Fin de pause" }),
                        "staff_clock_out" to (when (session.account.defaultLocale) { "en" -> "Clock out"; "ff-CM" -> "Timmugol golle"; else -> "Fin de service" })
                    ).forEach { (value, label) ->
                        OutlinedButton(onClick = { attendanceOperation = value }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (attendanceOperation == value) "✓ $label" else label)
                        }
                    }
                    Text(
                        when (session.account.defaultLocale) { "en" -> "Sequence: clock in → break → resume → clock out. Duplicate clock-ins and clock-outs without a shift are rejected."; "ff-CM" -> "Fuɗɗagol → fooftugol → ruttugol → yaltugol. Winndugol ɗiɗol walla yaltugol tawa naataaki jaɓaaka."; else -> "Séquence : prise de service → pause → reprise → sortie. Les doubles pointages et sorties sans prise de service sont refusés." },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Button(
                        onClick = {
                            if (siteId.isBlank()) {
                                error = when (session.account.defaultLocale) { "en" -> "Choose a staff member and site."; "ff-CM" -> "Suɓo gollotooɗo e nokkuure jaaygol."; else -> "Choisis un collaborateur et un point de vente." }
                            } else scope.launch {
                                runCatching {
                                    repository.recordStaffTimeEvent(
                                        session.account.organizationId, siteId, attendanceOperation,
                                        session.account.displayName, session.account.memberId,
                                        attendanceWorkstationId.takeIf { it.isNotBlank() }, session.account.memberId
                                    )
                                }.onSuccess {
                                    message = when (session.account.defaultLocale) { "en" -> "Clock event saved; sequence validated and recorded."; "ff-CM" -> "Naatugol danndaama; feere tabbitinaama."; else -> "Pointage enregistré ; séquence validée et historisée." }
                                    error = null
                                }.onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to record time event."; "ff-CM" -> "Winndugol naatugol waawataa."; else -> "Pointage impossible." } }
                            }
                        },
                        enabled = siteId.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Record time event"; "ff-CM" -> "Danndu naatugol"; else -> "Enregistrer le pointage" }) }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Commission, advance or bonus"; "ff-CM" -> "Komisiyoŋ, ceede adiiɗe walla bonis"; else -> "Commission, avance ou prime" }, fontWeight = FontWeight.Bold)
                    OutlinedTextField(staff, { staff = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Staff member"; "ff-CM" -> "Gollotooɗo"; else -> "Collaborateur" }) }, singleLine = true)
                    OutlinedTextField(detail, { detail = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Service / reason"; "ff-CM" -> "Golle / daliilu"; else -> "Prestation / motif" }) }, singleLine = true)
                    OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Amount (XAF)"; "ff-CM" -> "Ceede (FCFA)"; else -> "Montant (FCFA)" }) }, singleLine = true)
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        listOf(
                            "staff_commission" to (when (session.account.defaultLocale) { "en" -> "Commission"; "ff-CM" -> "Komisiyoŋ"; else -> "Commission" }),
                            "staff_advance" to (when (session.account.defaultLocale) { "en" -> "Advance"; "ff-CM" -> "Ceede adiiɗe"; else -> "Avance" }),
                            "staff_bonus" to (when (session.account.defaultLocale) { "en" -> "Bonus"; "ff-CM" -> "Bonis"; else -> "Prime" })
                        ).forEach { (value, label) ->
                            OutlinedButton(onClick = { payrollOperation = value }) {
                                Text(if (payrollOperation == value) "✓ $label" else label)
                            }
                        }
                    }
                    Button(
                        onClick = {
                            val value = amount.toLongOrNull() ?: 0L
                            if (staff.isBlank() || detail.isBlank() || value <= 0 || siteId.isBlank() || session.account.roleCode !in setOf("promoter","network_manager","site_manager")) {
                                error = when (session.account.defaultLocale) { "en" -> "Staff, reason and a positive amount are required."; "ff-CM" -> "Gollotooɗo, daliilu e ceede ɓurɗe 0 ko waajib."; else -> "Collaborateur, motif et montant positif requis." }
                            } else scope.launch {
                                runCatching {
                                    repository.createManagementRecord(
                                        session.account.organizationId, siteId, payrollOperation,
                                        "STAFF-" + System.currentTimeMillis(), detail, staff,
                                        value, 0, null, "pending_review",
                                        JSONObject().put("event", payrollOperation).put("approved", false).toString(),
                                        session.account.memberId,
                                        attendanceWorkstationId.takeIf { it.isNotBlank() }
                                    )
                                }.onSuccess {
                                    message = when (session.account.defaultLocale) { "en" -> "Variable pay record saved for approval."; "ff-CM" -> "Njoɓdi gollotooɗo danndaama, nana fadi tabbitinol."; else -> "Mouvement de rémunération enregistré en attente de validation." }
                                    amount = ""; detail = ""; error = null
                                }.onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to save record."; "ff-CM" -> "Danndugol waawataa."; else -> "Enregistrement impossible." } }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Save variable-pay record"; "ff-CM" -> "Danndu dirtugol"; else -> "Enregistrer le mouvement" }) }
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Recent attendance"; "ff-CM" -> "Sahaaaji sakkitiiɗi"; else -> "Horaires récents" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(attendance.take(40)) { row ->
            Text(
                row.counterparty + " · " + row.title + " · " +
                    java.text.SimpleDateFormat("dd/MM HH:mm", java.util.Locale.getDefault()).format(java.util.Date(row.createdAtMillis)),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Commissions, advances and bonuses"; "ff-CM" -> "Komisiyoŋ, ceede adiiɗe e bonis"; else -> "Commissions, avances et primes" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(payroll.take(40)) { row ->
            var approvalReason by rememberSaveable(row.id) { mutableStateOf("") }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(row.counterparty + " · " + labelRecord(row.recordType), fontWeight = FontWeight.SemiBold)
                    Text(row.title + " · " + xaf(row.amountXaf) + " · " + row.status, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (row.status == "approved" && BuildConfig.BILLING_SETTLEMENT_ENABLED && session.account.roleCode in setOf("promoter","network_manager","site_manager")) {
                        OutlinedTextField(approvalReason, { approvalReason = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Référence ou motif du règlement déjà effectué","Reference or reason for completed settlement","Daliilu njoɓdi")) })
                        OutlinedButton(onClick = {
                            scope.launch {
                                runCatching { repository.transitionManagementRecord(session.account.organizationId, siteId, row.id, "paid", approvalReason, session.account.memberId) }
                                    .onSuccess { approvalReason = ""; message = "Règlement externe déclaré, à synchroniser."; error = null }
                                    .onFailure { error = it.message ?: "Déclaration impossible." }
                            }
                        }, enabled = approvalReason.trim().length >= 3 && approvalReason.length <= 500, modifier = Modifier.fillMaxWidth()) {
                            Text(localizedLabel("Déclarer le règlement déjà effectué","Declare completed external settlement","Hollu njoɓdi waɗaandi"))
                        }
                        Text(localizedLabel("Aucun versement n’est déclenché par cette action.","No transfer is initiated by this action.","Njoɓdi fuɗɗotaako."), style = MaterialTheme.typography.bodySmall)
                    }
                    if (row.status in setOf("pending_review","draft") && session.account.roleCode in setOf("promoter","network_manager","site_manager")) {
                        OutlinedTextField(
                            approvalReason,
                            { approvalReason = it },
                            Modifier.fillMaxWidth(),
                            label = { Text(when (session.account.defaultLocale) { "en" -> "Reason required to approve or reject"; "ff-CM" -> "Daliilu tabbitinol walla salugol ko waajib"; else -> "Motif de validation ou de rejet obligatoire" }) }
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(
                                                session.account.organizationId, siteId, row.id,
                                                "approved", approvalReason, session.account.memberId
                                            )
                                        }.onSuccess { message = when (session.account.defaultLocale) { "en" -> "Record approved and audited."; "ff-CM" -> "Njoɓdi jaɓaama e danndaama."; else -> "Mouvement approuvé et historisé." }; error = null }
                                            .onFailure { error = it.message ?: "Approval failed." }
                                    }
                                },
                                enabled = approvalReason.trim().length >= 3,
                                modifier = Modifier.weight(1f)
                            ) { Text(when (session.account.defaultLocale) { "en" -> "Approve"; "ff-CM" -> "Jaɓu"; else -> "Approuver" }) }
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(
                                                session.account.organizationId, siteId, row.id,
                                                "rejected", approvalReason, session.account.memberId
                                            )
                                        }.onSuccess { message = when (session.account.defaultLocale) { "en" -> "Record rejected and audited."; "ff-CM" -> "Njoɓdi salaama e danndaama."; else -> "Mouvement rejeté et historisé." }; error = null }
                                            .onFailure { error = it.message ?: "Rejection failed." }
                                    }
                                },
                                enabled = approvalReason.trim().length >= 3,
                                modifier = Modifier.weight(1f)
                            ) { Text(when (session.account.defaultLocale) { "en" -> "Reject"; "ff-CM" -> "Sal"; else -> "Rejeter" }) }
                        }
                    }
                }
            }
        }
    }
}


@Composable
fun RecurringChargesContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val orgId = session.account.organizationId
    val charges by remember(siteId) { repository.dao.observeRecurringCharges(orgId, siteId) }.collectAsState(initial = emptyList())
    val payments by remember(siteId) { repository.dao.observeChargePayments(orgId, siteId) }.collectAsState(initial = emptyList())
    var editingId by rememberSaveable { mutableStateOf<String?>(null) }
    var name by rememberSaveable { mutableStateOf("") }
    var category by rememberSaveable { mutableStateOf("Loyer") }
    var amount by rememberSaveable { mutableStateOf("") }
    var recurrence by rememberSaveable { mutableStateOf("monthly") }
    var dueInDays by rememberSaveable { mutableStateOf("7") }
    var reminderDays by rememberSaveable { mutableStateOf("3") }
    var paymentAmount by rememberSaveable { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        message = if (granted) "Notifications d'échéance activées." else "Les notifications restent désactivées ; autorise-les dans les paramètres Android."
    }
    val now = System.currentTimeMillis()
    val monthStart = Calendar.getInstance().apply {
        set(Calendar.DAY_OF_MONTH, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis
    val monthEnd = Calendar.getInstance().apply {
        set(Calendar.DAY_OF_MONTH, getActualMaximum(Calendar.DAY_OF_MONTH)); set(Calendar.HOUR_OF_DAY, 23); set(Calendar.MINUTE, 59); set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999)
    }.timeInMillis
    var monthSales by remember { mutableStateOf(0L) }
    var monthFixedCharges by remember { mutableStateOf(0L) }
    LaunchedEffect(orgId, siteIds, monthStart, monthEnd) {
        monthSales = siteIds.sumOf { id ->
            repository.dao.observeSalesTotal(orgId, id, monthStart, monthEnd).first()
        }
        monthFixedCharges = siteIds.sumOf { id ->
            repository.dao.sumChargePaymentsForPeriod(orgId, id, monthStart, monthEnd)
        }
    }
    val due = charges.filter { it.active && it.nextDueAtMillis <= now + it.reminderDays * 86_400_000L }
    val otherScheduled = charges.filter { it.active && due.none { dueCharge -> dueCharge.id == it.id } }
    val fmt = java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault())

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Charges, échéances et trésorerie", "Configure les dépenses récurrentes, suis les règlements et anticipe les dates de paiement.")
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Consultez les rappels disponibles. Les envois SMS et WhatsApp ne sont pas disponibles.")
            if (android.os.Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                OutlinedButton(
                    onClick = { notificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS) },
                    modifier = Modifier.fillMaxWidth()
                ) { Text(localizedLabel("Autoriser les notifications d'échéance","Allow due date notifications","Yamir tintine ñalɗi yoɓde")) }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(localizedLabel("Pilotage du mois en cours","Current month overview","Yiyde lewru nduu"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Chiffre d'affaires brut encaissé et confirmé : ","Gross revenue received and confirmed: ","Ceede jaaygol fof keɓaaɗe tabbitinaaɗe : ") + xaf(monthSales), style = MaterialTheme.typography.titleMedium)
                    Text(localizedLabel("Charges fixes réglées : ","Paid fixed expenses: ","Njoɓdi ɗi yoɓaa : ") + xaf(monthFixedCharges))
                    Text(localizedLabel("Solde de gestion indicatif après ces charges : ","Indicative balance after these expenses: ","Ceede heddiiɗe tanƴaaɗe caggal njoɓdi ɗii : ") + xaf(monthSales - monthFixedCharges), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Le CA reste le total des ventes confirmées. Le solde indicatif retranche uniquement les charges fixes enregistrées et payées ici ; il ne constitue ni un résultat comptable SYSCOHADA ni un résultat fiscal.","Revenue remains total confirmed sales. This indicative balance deducts only fixed costs recorded and paid here; it is not a SYSCOHADA or tax result.","Ceede jaaygol ko jaaygol tabbitinaangol fof. Ceede heddiiɗe ustina tan njoɓdi danndaaɗi yoɓaaɗi ɗoo; wonaa limooje SYSCOHADA walla sagalle."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (editingId == null) "Nouvelle charge" else "Modifier la charge", fontWeight = FontWeight.Bold)
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Libellé : loyer, électricité, impôts, taxes…","Label: rent, electricity, taxes…","Innde: loyer, elektrisite, sagalle…")) }, singleLine = true)
                    OutlinedTextField(category, { category = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Catégorie","Category","Fannu")) }, singleLine = true)
                    OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Montant attendu (FCFA)","Expected amount (XAF)","Ceede fadotooɗe (FCFA)")) }, singleLine = true)
                    Text(localizedLabel("Périodicité","Frequency","Sahaa kala"))
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        listOf("monthly" to "Mensuelle", "quarterly" to "Trimestrielle", "annual" to "Annuelle", "one_time" to "Unique").forEach { option ->
                            OutlinedButton(onClick = { recurrence = option.first }) {
                                Text((if (recurrence == option.first) "✓ " else "") + option.second)
                            }
                        }
                    }
                    OutlinedTextField(dueInDays, { dueInDays = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Prochaine échéance dans (jours)","Next due date in (days)","Ñalnde yoɓde aroore caggal (balɗe)")) }, singleLine = true)
                    OutlinedTextField(reminderDays, { reminderDays = it.filter(Char::isDigit).take(2) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Rappel avant échéance (jours)","Reminder before due date (days)","Tintinol hade ñalnde yoɓde (balɗe)")) }, singleLine = true)
                    Button(
                        onClick = {
                            val value = amount.toLongOrNull() ?: 0L
                            val lead = reminderDays.toIntOrNull() ?: -1
                            val offset = dueInDays.toLongOrNull() ?: -1L
                            if (name.isBlank() || category.isBlank() || value <= 0L || lead !in 0..30 || offset !in 0..3650) {
                                error = "Vérifie le libellé, le montant et les délais."
                            } else scope.launch {
                                busy = true; error = null
                                runCatching {
                                    repository.saveRecurringCharge(
                                        orgId, siteId, editingId, name, category, value, recurrence,
                                        System.currentTimeMillis() + offset * 86_400_000L, lead, session.account.memberId
                                    )
                                }.onSuccess {
                                    editingId = null; name = ""; amount = ""; category = "Loyer"; dueInDays = "30"; reminderDays = "3"
                                    message = "Charge enregistrée et échéance programmée."
                                }.onFailure { error = it.message ?: "Enregistrement impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && name.isNotBlank() && amount.toLongOrNull() != null && (reminderDays.toIntOrNull() ?: -1) in 0..30,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else if (editingId == null) "Enregistrer la charge" else "Mettre à jour la charge") }
                    if (editingId != null) TextButton(onClick = { editingId = null; name = ""; amount = ""; category = "Loyer" }) { Text(localizedLabel("Annuler la modification","Cancel editing","Haaytu waylugol")) }
                    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    message?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                }
            }
        }
        item { Text(localizedLabel("Rappels à surveiller","Upcoming reminders","Tintine rewindoɗe"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (due.isEmpty()) item { Text(localizedLabel("Aucune échéance dans la fenêtre de rappel configurée.","No due dates within the selected reminder period.","Alaa ñalnde yoɓde e sahaa tintinol suɓaaɗo."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(due) { charge ->
            val paid = payments.filter { it.chargeId == charge.id && it.referenceDueAtMillis == charge.nextDueAtMillis }.sumOf { it.amountXaf }
            val balance = (charge.amountXaf - paid).coerceAtLeast(0L)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(charge.name + " · " + charge.category, fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Échéance : ","Due: ","Ñalnde yoɓde : ") + fmt.format(java.util.Date(charge.nextDueAtMillis)) + " · " + charge.recurrence)
                    Text(localizedLabel("Montant : ","Amount: ","Ceede : ") + xaf(charge.amountXaf) + " · déjà réglé : " + xaf(paid))
                    Text(if (balance == 0L) "Échéance réglée" else if (charge.nextDueAtMillis < now) "En retard : " + xaf(balance) else "À provisionner : " + xaf(balance), color = if (charge.nextDueAtMillis < now && balance > 0L) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
                    if (balance > 0L) {
                        OutlinedTextField(paymentAmount, { paymentAmount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Règlement partiel ou total (FCFA)","Partial or full payment (XAF)","Njoɓdi seeɗa walla fof (FCFA)")) }, singleLine = true)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching { repository.recordRecurringChargePayment(orgId, siteId, charge.id, balance, session.account.memberId) }
                                            .onSuccess { paymentAmount = ""; message = "Échéance réglée. La prochaine échéance a été avancée." }
                                            .onFailure { error = it.message ?: "Paiement impossible." }
                                    }
                                }, modifier = Modifier.weight(1f)
                            ) { Text(localizedLabel("Régler le solde","Pay remaining balance","Yoɓ ceede heddiiɗe")) }
                            OutlinedButton(
                                onClick = {
                                    val value = paymentAmount.toLongOrNull() ?: 0L
                                    if (value <= 0L || value >= balance) error = "Le paiement partiel doit être positif et inférieur au solde."
                                    else scope.launch {
                                        runCatching { repository.recordRecurringChargePayment(orgId, siteId, charge.id, value, session.account.memberId) }
                                            .onSuccess { paymentAmount = ""; message = "Paiement partiel ajouté à l'historique." }
                                            .onFailure { error = it.message ?: "Paiement partiel impossible." }
                                    }
                                }, modifier = Modifier.weight(1f)
                            ) { Text(localizedLabel("Paiement partiel","Partial payment","Njoɓdi seeɗa")) }
                        }
                    }
                    TextButton(onClick = {
                        editingId = charge.id; name = charge.name; category = charge.category; amount = charge.amountXaf.toString()
                        recurrence = charge.recurrence
                        dueInDays = (((charge.nextDueAtMillis - System.currentTimeMillis()) / 86_400_000L).coerceAtLeast(0L)).toString()
                        reminderDays = charge.reminderDays.toString()
                    }) { Text(localizedLabel("Modifier cette charge","Edit this expense","Waylu njoɓdi ɗii")) }
                }
            }
        }
        item { Text(localizedLabel("Autres échéances programmées","Other scheduled due dates","Ñalɗi yoɓde goɗɗi"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (otherScheduled.isEmpty()) item { Text(localizedLabel("Aucune autre charge active à venir.","No other upcoming active expenses.","Alaa njoɓdi goɗɗi arooɗi."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(otherScheduled) { charge ->
            val paid = payments.filter { it.chargeId == charge.id && it.referenceDueAtMillis == charge.nextDueAtMillis }.sumOf { it.amountXaf }
            val balance = (charge.amountXaf - paid).coerceAtLeast(0L)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(charge.name + " · " + charge.category, fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Prochaine échéance : ","Next due date: ","Ñalnde yoɓde aroore : ") + fmt.format(java.util.Date(charge.nextDueAtMillis)) + " · " + charge.recurrence)
                    Text(localizedLabel("Montant : ","Amount: ","Ceede : ") + xaf(charge.amountXaf) + " · rappel " + charge.reminderDays + " jour(s) avant")
                    Text(localizedLabel("Solde sur l'échéance actuelle : ","Remaining amount for current due date: ","Ceede heddiiɗe e ñalnde yoɓde ndee : ") + xaf(balance))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = {
                            editingId = charge.id; name = charge.name; category = charge.category; amount = charge.amountXaf.toString()
                            recurrence = charge.recurrence
                            dueInDays = (((charge.nextDueAtMillis - System.currentTimeMillis()) / 86_400_000L).coerceAtLeast(0L)).toString()
                            reminderDays = charge.reminderDays.toString()
                        }) { Text(localizedLabel("Modifier","Edit","Waylu")) }
                        TextButton(onClick = {
                            scope.launch {
                                runCatching { repository.deactivateRecurringCharge(orgId, siteId, charge.id, session.account.memberId) }
                                    .onSuccess { message = "Charge désactivée ; son historique est conservé." }
                                    .onFailure { error = it.message ?: "Désactivation impossible." }
                            }
                        }) { Text(localizedLabel("Désactiver","Disable","Uddu")) }
                    }
                }
            }
        }
        item { Text(localizedLabel("Historique des règlements","Payment history","Jaŋtol njoɓdi"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (payments.isEmpty()) item { Text(localizedLabel("Aucun règlement enregistré.","No payments recorded.","Alaa njoɓdi danndaaɗi."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(payments) { payment ->
            val chargeName = charges.firstOrNull { it.id == payment.chargeId }?.name ?: "Charge archivée"
            Text(chargeName + " · " + xaf(payment.amountXaf) + " · " + fmt.format(java.util.Date(payment.paidAtMillis)), style = MaterialTheme.typography.bodySmall)
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}

@Composable
fun LoyaltyProgramsContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession,
    activityProfile: String,
    onBack: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val orgId = session.account.organizationId
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val customers by remember(siteId) { repository.dao.observeCustomers(orgId, siteId) }.collectAsState(initial = emptyList())
    val programs by remember(activityProfile) { repository.dao.observeLoyaltyPrograms(orgId, activityProfile) }.collectAsState(initial = emptyList())
    var selectedCode by rememberSaveable { mutableStateOf("points") }
    var selectedCustomerId by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("10000") }
    var notice by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val selected = programs.firstOrNull { it.programCode == selectedCode }
    val events by remember(selected?.id, siteId) {
        repository.dao.observeLoyaltyEvents(orgId, siteId, selected?.id.orEmpty())
    }.collectAsState(initial = emptyList())
    LaunchedEffect(orgId, activityProfile) { repository.ensureDefaultLoyaltyPrograms(orgId, activityProfile) }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                Text(localizedLabel("Programmes de fidélité","Loyalty programs","Laabi hoolaare"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                TextButton(onClick = onBack) { Text(localizedLabel("Retour","Back","Rutto")) }
            }
            Text(localizedLabel("Quatre programmes autonomes adaptés au profil d'activité : points, passages, dépenses cumulées et fréquence de visite.","Four independent programs: points, visits, cumulative spending and visit frequency.","Laabi nay keeriiɗi: puwan, garugol, ceede renndinaaɗe e sahaa garugol."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it; selectedCustomerId = "" }
            LocalOnlyNotice("Consultez vos gains et votre historique. Le versement automatique n'est pas disponible.")
        }
        item {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("points" to "Club points", "visits" to "Carte de passages", "spend" to "Cercle privilège", "frequency" to "Fréquence").forEach { pair ->
                    OutlinedButton(onClick = { selectedCode = pair.first }, modifier = Modifier.fillMaxWidth()) {
                        Text((if (selectedCode == pair.first) "✓ " else "") + pair.second)
                    }
                }
            }
        }
        if (selected != null) {
        val current = selected
        item {
                var name by rememberSaveable(current.id) { mutableStateOf(current.name) }
                var description by rememberSaveable(current.id) { mutableStateOf(current.description) }
                var metric by rememberSaveable(current.id) { mutableStateOf(current.metricCode) }
                var unitAmount by rememberSaveable(current.id) { mutableStateOf(current.unitAmountXaf.toString()) }
                var target by rememberSaveable(current.id) { mutableStateOf(current.targetValue.toString()) }
                var reward by rememberSaveable(current.id) { mutableStateOf(current.rewardDescription) }
                var window by rememberSaveable(current.id) { mutableStateOf(current.windowDays.toString()) }
                var active by rememberSaveable(current.id) { mutableStateOf(current.active) }
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(current.name, fontWeight = FontWeight.Bold)
                        OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Nom du programme","Program name","Innde laawol")) }, singleLine = true)
                        OutlinedTextField(description, { description = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Présentation et règles","Description and rules","Cifagol e laabi")) }, minLines = 2)
                        Text(localizedLabel("Indicateur suivi","Tracked metric","Limoore rewindaande"))
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            listOf("points" to "Points", "visits" to "Visites", "spend" to "Montant dépensé").forEach { option ->
                                OutlinedButton(onClick = { metric = option.first }) { Text((if (metric == option.first) "✓ " else "") + option.second) }
                            }
                        }
                        OutlinedTextField(unitAmount, { unitAmount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("FCFA par unité gagnée (ex. 1 000 pour les points)","XAF per earned unit (e.g. 1,000 per point)","FCFA ngam unit heɓaandi (1 000 ngam puwan)")) }, singleLine = true)
                        OutlinedTextField(target, { target = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Seuil de récompense","Reward threshold","Keewal ngam heɓde njariñ")) }, singleLine = true)
                        OutlinedTextField(reward, { reward = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Récompense à offrir","Reward to offer","Njariñ hokketeengal")) }, minLines = 2)
                        OutlinedTextField(window, { window = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Fenêtre glissante en jours (0 = illimitée)","Rolling window in days (0 = unlimited)","Sahaa e balɗe (0 = alaa keerol)")) }, singleLine = true)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            androidx.compose.material3.Checkbox(checked = active, onCheckedChange = { active = it })
                            Text(localizedLabel("Programme actif","Active program","Laawol nana golla"))
                        }
                        Button(
                            onClick = {
                                val unitValue = unitAmount.toLongOrNull() ?: 0L
                                val targetValue = target.toLongOrNull() ?: 0L
                                val days = window.toIntOrNull() ?: -1
                                if (unitValue <= 0L || targetValue <= 0L || reward.isBlank() || name.isBlank() || days !in 0..365) {
                                    error = "Vérifie le seuil, l'unité, la récompense et la fenêtre."
                                } else scope.launch {
                                    runCatching {
                                        repository.saveLoyaltyProgram(current.copy(
                                            name = name.trim(), description = description.trim(), metricCode = metric,
                                            unitAmountXaf = unitValue, targetValue = targetValue, rewardDescription = reward.trim(),
                                            windowDays = days, active = active
                                        ), session.account.memberId)
                                    }.onSuccess { notice = "Programme enregistré."; error = null }
                                        .onFailure { error = it.message ?: "Enregistrement du programme impossible." }
                                }
                            }, modifier = Modifier.fillMaxWidth()
                        ) { Text(localizedLabel("Enregistrer la configuration","Save settings","Danndu teelte")) }
                    }
                }
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(localizedLabel("Enregistrer une visite ou un achat client","Record a customer visit or purchase","Danndu garugol walla soodugol soottotooɗo"), fontWeight = FontWeight.Bold)
                        if (customers.isEmpty()) Text(localizedLabel("Crée d'abord la fiche du client dans le CRM.","Create the customer record first.","Sos humpito soottotooɗo tawo."))
                        customers.forEach { customer ->
                            OutlinedButton(onClick = { selectedCustomerId = customer.id }, modifier = Modifier.fillMaxWidth()) {
                                Text((if (selectedCustomerId == customer.id) "✓ " else "") + customer.displayName)
                            }
                        }
                        OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Montant de l'achat (FCFA) ; 0 pour un passage","Purchase amount (XAF); 0 for a visit","Ceede soodugol (FCFA); 0 ngam garugol")) }, singleLine = true)
                        Button(
                            onClick = {
                                val clientId = selectedCustomerId
                                val value = amount.toLongOrNull() ?: -1L
                                if (selectedCustomerId.isBlank() || value < 0L || !current.active) error = "Choisis un client, un montant valide et un programme actif."
                                else scope.launch {
                                    busy = true
                                    runCatching { repository.recordLoyaltyActivity(current, siteId, clientId, value, session.account.memberId) }
                                        .onSuccess { result ->
                                            val rewardCount = result.count { it.eventType == "reward_earned" }
                                            notice = if (rewardCount > 0) "Opération enregistrée : " + rewardCount + " récompense(s) gagnée(s)." else "Activité fidélité enregistrée."
                                            error = null
                                        }.onFailure { error = it.message ?: "Enregistrement fidélité impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && selectedCustomerId.isNotBlank() && current.active,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (busy) "Enregistrement…" else "Valider l'activité") }
                    }
                }
            }
            item { Text(localizedLabel("Historique et récompenses","History and rewards","Jaŋtol e njariñ"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
            if (events.isEmpty()) item { Text(localizedLabel("Aucune activité ou récompense enregistrée pour ce programme.","No activity or rewards recorded for this program.","Alaa golle walla njariñ danndaangal e laawol ngol."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
            items(events) { event ->
                val client = customers.firstOrNull { it.id == event.customerId }?.displayName ?: "Client"
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(client + " · " + event.description, fontWeight = FontWeight.SemiBold)
                        Text((if (event.eventType == "reward_earned") "Récompense" else "Activité") +
                            (event.waveNumber?.let { " · vague " + it } ?: "") + " · " +
                            java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(event.createdAtMillis)),
                            style = MaterialTheme.typography.bodySmall)
                        if (event.eventType == "reward_earned") {
                            Text(event.rewardStatus ?: "—")
                            if (event.rewardStatus == "available") {
                                OutlinedButton(onClick = {
                                    scope.launch {
                                        val success = repository.redeemLoyaltyReward(event, session.account.memberId)
                                        if (success) notice = "Récompense marquée comme utilisée."
                                    }
                                }) { Text(localizedLabel("Marquer comme utilisée","Mark as used","Maanto ko huutoraama")) }
                            }
                        } else Text(localizedLabel("Valeur : ","Value: ","Keewal : ") + event.metricDelta + " · achat : " + xaf(event.amountXaf), style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        } else {
            item { Text(localizedLabel("Initialisation des quatre programmes en cours…","Setting up the four programs…","Nana teelta laabi nay…"), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
        notice?.let { item { Text(it, color = MaterialTheme.colorScheme.primary) } }
        item { Spacer(Modifier.height(24.dp)) }
    }
}
