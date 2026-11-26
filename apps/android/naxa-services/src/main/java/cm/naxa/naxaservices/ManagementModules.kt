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
            Text("Facturation, crédits et remboursements", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Devis, factures, créances à recevoir du client et remboursements que la PME doit au client : deux soldes distincts. Les écritures restent rattachées au site.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Documents locaux en attente de synchronisation et validation serveur.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text("Nouvelle pièce commerciale", fontWeight = FontWeight.Bold)
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
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text("Client / tiers") }, singleLine = true)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("Détail de la prestation ou du remboursement") }, singleLine = true)
                    OutlinedTextField(total, { total = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Montant total (FCFA)") }, singleLine = true)
                    OutlinedTextField(paid, { paid = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (type == "customer_receivable") "Déjà encaissé par la PME (FCFA)" else if (type == "refund_due") "Déjà remboursé au client (FCFA)" else "Déjà réglé / encaissé (FCFA)") }, singleLine = true)
                    OutlinedTextField(dueDays, { dueDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text("Échéance dans (jours)") }, singleLine = true)
                    Button(
                        onClick = {
                            val amount = total.toLongOrNull() ?: 0L
                            val settled = paid.toLongOrNull() ?: 0L
                            if (customer.isBlank() || title.isBlank() || amount <= 0 || settled > amount) {
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
                                    notice = labelRecord(type) + " enregistré localement."
                                    customer = ""; title = ""; total = ""; paid = "0"; error = null
                                }.onFailure { error = it.message ?: "Enregistrement impossible." }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Enregistrer la pièce") }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                    Text("Une facture ou un remboursement reste un brouillon local jusqu’à synchronisation et validation serveur.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item { Text("Historique des pièces", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(records.filter { it.recordType in setOf("quote", "invoice", "credit_note", "customer_receivable", "refund_due") }) { item ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(labelRecord(item.recordType) + " · " + item.reference, fontWeight = FontWeight.Bold)
                    Text(item.title + " · " + item.counterparty)
                    Text("Total " + xaf(item.amountXaf) + " · réglé " + xaf(item.paidXaf) + " · restant " + xaf(item.amountXaf - item.paidXaf))
                    Text(statusRecord(item.status), color = MaterialTheme.colorScheme.secondary)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = { receiptToSave = item; pdfLauncher.launch("NAXA-" + item.reference + ".pdf") }) { Text("Télécharger le reçu PDF") }
                        TextButton(onClick = { shareRecord(context, item) }) { Text("Partager WhatsApp") }
                    }
                }
            }
        }
        if (records.none { it.recordType in setOf("quote", "invoice", "credit_note", "customer_receivable", "refund_due") }) {
            item { Text("Aucune pièce commerciale enregistrée.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
            runCatching { action() }.onFailure { error = it.message ?: if (fr) "Opération impossible." else "Operation failed." }
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
            Text(if (fr) "Abonnement NAXA SERVICES" else "NAXA SERVICES subscription", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(if (fr) "Un abonnement par organisation. Les encaissements de votre entreprise sont réalisés hors application." else "One subscription per organization. Your business collects payments outside the app.")
            OutlinedButton(enabled = !busy, onClick = { runAction { loadAccess() } }) {
                Text(if (fr) "Vérifier les droits payés" else "Check paid access")
            }
            access?.let { paid ->
                Text(when (paid.optString("state")) {
                    "active" -> if (fr) "Période payée active" else "Active paid period"
                    "expired" -> if (fr) "Période payée expirée" else "Paid period expired"
                    "cancelled" -> if (fr) "Abonnement annulé" else "Subscription cancelled"
                    "not_started" -> if (fr) "Période payée à venir" else "Upcoming paid period"
                    else -> if (fr) "Aucune période payée enregistrée" else "No paid period recorded"
                })
                paid.optString("period_end_exclusive").takeIf { it.isNotBlank() && it != "null" }?.let {
                    Text((if (fr) "Échéance exclusive : " else "Exclusive end date: ") + it)
                }
            }
            access?.let { paid ->
                if (paid.has("erp_access")) Text(when (paid.optString("access_reason")) {
                    "trial" -> if (fr) "Essai de 72 h en cours" else "72-hour trial"
                    "provisional" -> if (fr) "Accès provisoire de 24 h, paiement non confirmé" else "24-hour provisional access; payment not confirmed"
                    "paid" -> if (fr) "Accès ERP serveur autorisé" else "Server ERP access allowed"
                    else -> if (fr) "Accès ERP serveur suspendu. Données locales conservées ; règlement accessible." else "Server ERP access suspended. Local data retained; payment available."
                })
            }
            if (session.account.roleCode != "promoter") {
                Text(if (fr) "Règlement réservé au Promoteur." else "Payment reserved for the promoter.")
            } else {
                OutlinedButton(enabled = !busy, onClick = { runAction { load() } }) { Text(if (fr) "Consulter / actualiser" else "Load / refresh") }
                snapshot?.optJSONObject("subscription")?.let { sub ->
                    Text(sub.optString("plan_code") + " · " + sub.optString("status") + " · " + (if (fr) "Échéance (exclusive) : " else "End date (exclusive): ") + sub.optString("period_end_exclusive"))
                }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
        if (session.account.roleCode == "promoter" && snapshot != null && current == null) item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Choisir une formule" else "Choose plan", fontWeight = FontWeight.Bold)
                    if (requiresPremium) Text(if (fr) "PREMIUM requis pour le réseau ou plusieurs postes." else "PREMIUM required for multiple workstations or sites.")
                    (if (requiresPremium) listOf("PREMIUM") else listOf("ACCESS","PREMIUM")).forEach { value ->
                        OutlinedButton(onClick = { plan = value }, enabled = !busy) { Text((if (plan == value) "✓ " else "") + value) }
                    }
                    listOf(1,12).forEach { value ->
                        OutlinedButton(onClick = { months = value }, enabled = !busy) { Text((if (months == value) "✓ " else "") + if (value == 1) (if (fr) "Mensuel" else "Monthly") else (if (fr) "Annuel" else "Annual")) }
                    }
                    destinations.forEach { d ->
                        val value = d.optString("channel")
                        OutlinedButton(onClick = { channel = value }, enabled = !busy) { Text((if (channel == value) "✓ " else "") + if (value == "mtn_momo") "MTN MoMo" else "Orange Money") }
                    }
                    if (destinations.isEmpty()) Text(if (fr) "Aucune destination NAXA activée. Ne payez pas sur un autre compte." else "No NAXA payment destination is enabled.")
                    Button(enabled = !busy && destinations.any { it.optString("channel") == channel }, onClick = {
                        runAction {
                            intent = api.subscriptionRequest(session.accessToken, JSONObject().put("action","subscription_create").put("plan_code",plan).put("months",months).put("channel",channel))
                        }
                    }) { Text(if (fr) "Obtenir le montant et la destination" else "Get amount and destination") }
                }
            }
        }
        if (session.account.roleCode == "promoter" && current != null) item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(xaf(current.optLong("amount_xaf")) + " · " + current.optString("plan_code"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text((if (fr) "Bénéficiaire : " else "Beneficiary: ") + current.optString("beneficiary") + " · " + current.optString("merchant_code"))
                    if (current.optString("status") == "pending") {
                        Text(if (fr) "Vérifiez le bénéficiaire et le montant chez l'opérateur. Ne communiquez jamais votre PIN." else "Check the merchant and amount with the operator. Never share your PIN.")
                        if (ussd.isNotEmpty()) {
                            Text(ussd)
                            OutlinedButton(enabled = !busy, onClick = {
                                runCatching { context.startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel",ussd,null))) }.onFailure { error = it.message }
                            }) { Text(if (fr) "Ouvrir le composeur" else "Open dialer") }
                        }
                        OutlinedTextField(payer, { payer = it.take(20) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Numéro du payeur" else "Payer phone") }, singleLine = true)
                        if (current.optString("channel") == "orange_money") OutlinedTextField(date, { date = it.take(16) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Date et heure Cameroun (AAAA-MM-JJ HH:mm)" else "Cameroon time (YYYY-MM-DD HH:mm)") }, singleLine = true)
                        OutlinedTextField(sms, { sms = it.take(8000) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "SMS de débit de cette transaction" else "Debit SMS for this transaction") })
                        Button(enabled = !busy && payer.isNotBlank() && sms.isNotBlank() && (current.optString("channel") != "orange_money" || date.length == 16), onClick = {
                            runAction {
                                val payload = JSONObject().put("action","subscription_declare").put("intent_id",current.optString("id")).put("sms",sms).put("payer_number",payer)
                                if (current.optString("channel") == "orange_money") payload.put("occurred_at",java.time.OffsetDateTime.parse(date.replace(' ','T') + ":00+01:00").toString())
                                api.subscriptionRequest(session.accessToken,payload)
                                sms = ""; payer = ""; date = ""; load()
                            }
                        }) { Text(if (fr) "Déclarer le paiement" else "Declare payment") }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            androidx.compose.material3.Checkbox(checked = notPaid, onCheckedChange = { notPaid = it }, enabled = !busy)
                            Text(if (fr) "Je confirme n’avoir effectué aucun paiement." else "I confirm no payment was made.")
                        }
                        OutlinedButton(enabled = !busy && notPaid, onClick = {
                            runAction {
                                api.subscriptionRequest(session.accessToken, JSONObject().put("action","subscription_cancel").put("intent_id",current.optString("id")).put("not_paid",true))
                                sms = ""; payer = ""; date = ""; load()
                            }
                        }) { Text(if (fr) "Abandonner la demande non payée" else "Cancel unpaid request") }
                    } else Text(if (fr) "Déclaration reçue. En attente du crédit NAXA ; aucun droit activé par une preuve seule." else "Declaration received. Waiting for NAXA credit proof; one proof does not activate access.")
                }
            }
        }
        if (session.account.roleCode == "promoter") items(arrayObjects(snapshot?.optJSONArray("intents")).filter { it.optString("status") == "confirmed" }) { row ->
            Text((if (fr) "Reçu " else "Receipt ") + row.optString("receipt_number") + " · " + xaf(row.optLong("amount_xaf")))
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
                if (fr) "Achats, fournisseurs et comptabilité" else "Purchases, suppliers and accounting",
                if (fr) "Commandes multi-lignes, réceptions partielles, dettes et règlements fournisseurs, avec journal débit/crédit et impact sur les marges." else "Multi-line orders, partial receiving, supplier payables and payments, with balanced journal entries and margin impact."
            )
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) {
                siteId = it; selectedSupplierId = ""; selectedItemId = ""; draftLines.clear()
            }
            LocalOnlyNotice(if (fr) "Registres comptables de gestion conservés localement sur cet appareil. La synchronisation avec le serveur reste liée à l'environnement ERP isolé." else "Management accounting records are stored locally on this device. Server synchronization still depends on the isolated ERP environment.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(if (fr) "Compte fournisseur du site" else "Site supplier account", fontWeight = FontWeight.Bold)
                    Text((if (fr) "Dettes fournisseurs non réglées : " else "Open supplier payables: ") + xaf(payables), style = MaterialTheme.typography.titleLarge)
                    Text((if (fr) "Commandes ouvertes : " else "Open purchase documents: ") + purchases.count { it.status !in setOf("closed", "cancelled") })
                    Text((if (fr) "Règlements enregistrés : " else "Payments recorded: ") + payments.size)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Fiche fournisseur" else "Supplier profile", fontWeight = FontWeight.Bold)
                    if (suppliers.isEmpty()) Text(if (fr) "Aucun fournisseur actif pour ce site." else "No active supplier for this site.")
                    suppliers.forEach { supplier ->
                        OutlinedButton(onClick = { selectedSupplierId = supplier.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (selectedSupplierId == supplier.id) "✓ " else "") + supplier.name + " · " + supplier.phone)
                        }
                    }
                    OutlinedTextField(supplierName, { supplierName = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Nom / raison sociale" else "Supplier name") }, singleLine = true)
                    OutlinedTextField(supplierPhone, { supplierPhone = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Téléphone" else "Phone") }, singleLine = true)
                    OutlinedTextField(supplierWhatsApp, { supplierWhatsApp = it }, Modifier.fillMaxWidth(), label = { Text("WhatsApp fournisseur · indicatif pays") }, singleLine = true)
                    OutlinedTextField(supplierEmail, { supplierEmail = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "E-mail" else "Email") }, singleLine = true)
                    OutlinedTextField(supplierAddress, { supplierAddress = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Adresse" else "Address") }, minLines = 2)
                    OutlinedTextField(supplierTerms, { supplierTerms = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Délai de paiement (jours)" else "Payment terms (days)") }, singleLine = true)
                    OutlinedTextField(supplierNotes, { supplierNotes = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Conditions et notes" else "Terms and notes") }, minLines = 2)
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
                                    notice = if (fr) "Fiche fournisseur enregistrée." else "Supplier profile saved."
                                }.onFailure { error = it.message ?: "Supplier save failed." }
                                busy = false
                            }
                        }, enabled = !busy && supplierName.trim().length >= 2 && (supplierTerms.toIntOrNull() ?: -1) in 0..365,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else if (fr) "Enregistrer le fournisseur" else "Save supplier") }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Nouvelle commande fournisseur multi-lignes" else "New multi-line supplier order", fontWeight = FontWeight.Bold)
                    Text(if (fr) "1. Sélection du fournisseur" else "1. Select supplier")
                    if (selectedSupplier == null) Text(if (fr) "Sélectionne d'abord une fiche fournisseur." else "Select an existing supplier profile first.")
                    else Text(selectedSupplier.name + " · " + selectedSupplier.phone, color = MaterialTheme.colorScheme.primary)
                    OutlinedTextField(purchaseReference, { purchaseReference = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Référence commande (laisser vide pour générer)" else "Purchase reference (blank to generate)") }, singleLine = true)
                    OutlinedTextField(supplierInvoice, { supplierInvoice = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Référence facture fournisseur" else "Supplier invoice reference") }, singleLine = true)
                    Text(if (fr) "2. Ajouter les lignes" else "2. Add purchase lines")
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
                        OutlinedTextField(lineDescription, { lineDescription = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Désignation de la charge / immobilisation" else "Expense / asset description") })
                    }
                    OutlinedTextField(lineUnit, { lineUnit = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Unité" else "Unit") }, singleLine = true)
                    OutlinedTextField(lineQuantity, { lineQuantity = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Quantité commandée" else "Quantity ordered") }, singleLine = true)
                    OutlinedTextField(lineUnitCost, { lineUnitCost = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Coût unitaire (FCFA)" else "Unit cost (XAF)") }, singleLine = true)
                    OutlinedButton(
                        onClick = {
                            val qty = lineQuantity.replace(",", ".").toDoubleOrNull() ?: 0.0
                            val unitCost = lineUnitCost.toLongOrNull() ?: 0L
                            if (lineDescription.isBlank() || qty <= 0 || !qty.isFinite() || unitCost <= 0 ||
                                (itemType == "stock" && selectedItem == null)
                            ) error = if (fr) "Désignation, article de stock si requis, quantité et coût unitaire positifs obligatoires." else "Description, linked stock item if required, quantity and unit cost are required."
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
                    ) { Text(if (fr) "Ajouter cette ligne à la commande" else "Add line to purchase") }
                    if (draftLines.isNotEmpty()) {
                        Text(if (fr) "Lignes préparées" else "Prepared lines", fontWeight = FontWeight.SemiBold)
                        draftLines.forEachIndexed { index, line ->
                            Row(horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(line.description, fontWeight = FontWeight.Medium)
                                    Text(line.itemType + " · " + line.quantity + " " + line.unit + " × " + xaf(line.unitCostXaf), style = MaterialTheme.typography.bodySmall)
                                }
                                Text(xaf((line.quantity * line.unitCostXaf).roundToLong()))
                                TextButton(onClick = { draftLines.removeAt(index) }) { Text(if (fr) "Retirer" else "Remove") }
                            }
                        }
                    }
                    Text(if (fr) "3. Taxes et frais" else "3. Taxes and fees", fontWeight = FontWeight.SemiBold)
                    OutlinedTextField(recoverableTax, { recoverableTax = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Taxe récupérable déclarée (FCFA)" else "Recoverable tax entered (XAF)") }, singleLine = true)
                    OutlinedTextField(nonRecoverableTax, { nonRecoverableTax = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Taxe non récupérable (FCFA)" else "Non-recoverable tax (XAF)") }, singleLine = true)
                    OutlinedTextField(shipping, { shipping = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Transport / livraison (FCFA)" else "Shipping / delivery (XAF)") }, singleLine = true)
                    OutlinedTextField(otherFees, { otherFees = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Autres frais imputables (FCFA)" else "Other allocable fees (XAF)") }, singleLine = true)
                    OutlinedTextField(dueDays, { dueDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Échéance de paiement dans (jours)" else "Payment due in (days)") }, singleLine = true)
                    OutlinedTextField(purchaseNotes, { purchaseNotes = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Notes / conditions de réception" else "Notes / receiving conditions") }, minLines = 2)
                    Text("Sous-total : " + xaf(orderSubtotal))
                    Text("Total engagé : " + xaf(orderTotal), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(if (fr) "La commande seule ne modifie ni le stock ni le résultat. La dette et les écritures sont créées au rythme des réceptions effectives." else "An order alone changes neither stock nor profit. Payables and journal entries are created as goods/services are actually received.")
                    Button(
                        onClick = {
                            if (selectedSupplier == null || draftLines.isEmpty() || orderTotal <= 0L ||
                                listOf(recoverableTaxValue, nonRecoverableTaxValue, shippingValue, otherFeeValue).any { it < 0L } ||
                                (dueDays.toIntOrNull() ?: -1) !in 0..365
                            ) error = if (fr) "Fournisseur, lignes et montants valides obligatoires." else "Supplier, lines and valid amounts required."
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
                                    notice = if (fr) "Commande enregistrée. Aucune entrée de stock ou dépense n'est postée avant réception." else "Order saved. No stock entry or expense is posted before receipt."
                                }.onFailure { error = it.message ?: "Purchase creation failed." }
                                busy = false
                            }
                        }, enabled = !busy && selectedSupplier != null && draftLines.isNotEmpty() && orderTotal > 0L,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else if (fr) "Valider la commande fournisseur" else "Create supplier order") }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(if (fr) "Commandes, réceptions et dettes fournisseurs" else "Supplier orders, receipts and payables", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (purchases.isEmpty()) item { Text(if (fr) "Aucune commande fournisseur enregistrée." else "No supplier purchase orders yet.") }
        items(purchases, key = { it.id }) { purchase ->
            val lines by remember(purchase.id, siteId) { repository.dao.observePurchaseLines(orgId, siteId, purchase.id) }.collectAsState(initial = emptyList())
            val receipts by remember(purchase.id, siteId) { repository.dao.observePurchaseReceipts(orgId, siteId, purchase.id) }.collectAsState(initial = emptyList())
            val due = purchase.receivedTotalXaf - purchase.paidTotalXaf
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                    Text(purchase.reference + " · " + purchase.supplierNameSnapshot, fontWeight = FontWeight.Bold)
                    Text("Statut : " + purchase.status + " · " + (purchase.supplierInvoiceNumber.ifBlank { if (fr) "Facture non renseignée" else "Invoice not entered" }))
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
                        ) { Text(if (fr) "Envoyer le bon de commande par WhatsApp" else "Send purchase order via WhatsApp") }
                    }
                    Text("Total commandé : " + xaf(purchase.subtotalXaf + purchase.recoverableTaxXaf + purchase.nonRecoverableTaxXaf + purchase.shippingXaf + purchase.otherFeesXaf))
                    Text("Réceptionné : " + xaf(purchase.receivedTotalXaf) + " · réglé : " + xaf(purchase.paidTotalXaf))
                    Text((if (fr) "Dette fournisseur : " else "Supplier payable: ") + xaf(due.coerceAtLeast(0L)), color = if (due > 0L) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    lines.forEach { line ->
                        val remaining = (line.quantityOrdered - line.quantityReceived).coerceAtLeast(0.0)
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(line.description + " · " + line.itemType, fontWeight = FontWeight.SemiBold)
                            Text("Commandé : " + line.quantityOrdered + " · reçu : " + line.quantityReceived + " · restant : " + remaining, style = MaterialTheme.typography.bodySmall)
                            if (remaining > 0.000001 && purchase.status !in setOf("cancelled", "closed")) {
                                val qtyText = receiptQuantities[line.id] ?: remaining.toString()
                                OutlinedTextField(qtyText, { receiptQuantities[line.id] = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Quantité reçue maintenant" else "Quantity received now") }, singleLine = true)
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
                                            .onSuccess { receiptQuantities.remove(line.id); notice = if (fr) "Réception enregistrée : stock, dette et journal mis à jour." else "Receipt posted to inventory, payable and journal." }
                                            .onFailure { error = it.message ?: "Receiving failed." }
                                    }
                                }, enabled = remaining > 0.0) { Text(if (fr) "Valider cette réception partielle / complète" else "Post this partial / full receipt") }
                            }
                        }
                    }
                    if (receipts.isNotEmpty()) {
                        Text(if (fr) "Historique des réceptions" else "Receiving history", fontWeight = FontWeight.SemiBold)
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
                        Text(if (fr) "Règlement fournisseur" else "Supplier settlement", fontWeight = FontWeight.SemiBold)
                        OutlinedTextField(amountToPay, { amountToPay = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Montant réglé (FCFA)" else "Payment amount (XAF)") }, singleLine = true)
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
                        OutlinedTextField(paymentReference, { paymentReference = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Référence du règlement" else "Payment reference") }, singleLine = true)
                        Button(
                            onClick = {
                                val amount = amountToPay.toLongOrNull() ?: 0L
                                if (amount <= 0L || amount > due || (paymentMethod == "cash" && cashSessionId.isBlank())) error = if (fr) "Montant ou caisse de règlement invalide." else "Invalid amount or cash register."
                                else scope.launch {
                                    runCatching {
                                        repository.recordSupplierPayment(orgId, siteId, purchase.id, amount, paymentMethod,
                                            cashSessionId.takeIf { paymentMethod == "cash" }, paymentReference,
                                            java.util.UUID.nameUUIDFromBytes(
                                                "$orgId|$siteId|${purchase.id}|${purchase.paidTotalXaf}|$amount|$paymentMethod|$cashSessionId|${paymentReference.trim()}"
                                                    .toByteArray(Charsets.UTF_8)
                                            ).toString(), session.account.memberId)
                                    }.onSuccess { notice = if (fr) "Règlement fournisseur imputé à la dette et au journal." else "Supplier payment applied to payable and journal." }
                                        .onFailure { error = it.message ?: "Supplier payment failed." }
                                }
                            }, modifier = Modifier.fillMaxWidth()
                        ) { Text(if (fr) "Enregistrer le règlement" else "Record supplier payment") }
                    }
                }
            }
        }
        item { Text(if (fr) "Journal comptable de gestion" else "Management accounting journal", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (accounting.isEmpty()) item { Text(if (fr) "Aucune écriture postée pour ce site." else "No journal entry posted for this site.") }
        items(accounting.take(50), key = { it.id }) { entry ->
            Text(entry.occurredAtMillis.let { java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(it)) } +
                " · Débit " + entry.debitAccount + " / Crédit " + entry.creditAccount + " · " + xaf(entry.amountXaf) +
                " · " + entry.description, style = MaterialTheme.typography.bodySmall)
        }
        item {
            LocalOnlyNotice(if (fr) "Le journal utilise des comptes de gestion symboliques (stock, dette fournisseur, trésorerie, ventes, coût des ventes). Il est équilibré débit/crédit mais n'est pas encore un plan de comptes SYSCOHADA certifié ni une déclaration fiscale." else "The balanced double-entry journal uses management account labels; it is not yet a certified SYSCOHADA chart of accounts or a tax filing.")
        }

        if (legacySuppliers.isNotEmpty() || legacyPurchases.isNotEmpty()) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(if (fr) "Archives des anciens registres" else "Legacy register archive", fontWeight = FontWeight.Bold)
                        Text(
                            if (fr) "Les fournisseurs et commandes saisis dans l'ancien module générique sont conservés ci-dessous. Ils ne sont pas convertis automatiquement pour éviter les doublons de stock ou de dette." 
                            else "Suppliers and orders from the former generic register remain visible below. They are not auto-converted, to avoid duplicate stock or payables."
                        )
                        legacySuppliers.take(20).forEach { record ->
                            Text("Fournisseur historique · " + record.title + " · " + record.counterparty, style = MaterialTheme.typography.bodySmall)
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
            Text("Taxes et impôts", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Espace de préparation et de suivi. Les taux, régimes, échéances et obligations doivent être validés par votre comptable selon la réglementation applicable.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Aucune déclaration fiscale n’est transmise par cet écran.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(label, { label = it }, Modifier.fillMaxWidth(), label = { Text("Nature de la taxe / échéance") })
                    OutlinedTextField(base, { base = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Base taxable (FCFA)") })
                    OutlinedTextField(rate, { rate = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, Modifier.fillMaxWidth(), label = { Text("Taux indicatif (%)") })
                    Text("Montant estimatif : " + xaf(estimated), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Button(onClick = {
                        if (baseValue <= 0 || rateValue < 0.0 || rateValue > 100.0) message = "Vérifie la base et le taux."
                        else scope.launch {
                            runCatching { repository.createManagementRecord(session.account.organizationId, siteId, "tax_estimate", "TAX-" + System.currentTimeMillis(), label, "Fiscalité", estimated, 0, null, "draft", "{\"base_xaf\":" + baseValue + ",\"rate_percent\":" + rateValue + ",\"advice\":\"accountant_validation_required\"}", session.account.memberId) }
                                .onSuccess { message = "Estimation sauvegardée comme brouillon, non déclarée." }
                                .onFailure { message = it.message ?: "Sauvegarde impossible." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("Enregistrer le brouillon fiscal") }
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.secondary)
                    Text("NAXA ne soumet pas de déclaration fiscale et ne calcule pas un impôt exigible sans régime confirmé.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item { Text("Préparations locales", fontWeight = FontWeight.Bold) }
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
            Text("Pilotage et objectifs", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Baselines datées et historisées. Un nouvel objectif ajoute une nouvelle version ; il ne réécrit pas les objectifs déjà enregistrés.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Le réalisé provient des ventes confirmées locales de ce site. La consolidation réseau complète dépendra de la synchronisation ERP.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Période de pilotage")
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("daily" to "Jour", "monthly" to "Mois", "annual" to "Année").forEach { option ->
                            OutlinedButton(onClick = { period = option.first }) {
                                Text((if (period == option.first) "✓ " else "") + option.second)
                            }
                        }
                    }
                    Text("Du " + periodStart.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")) +
                        " au " + periodEnd.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")),
                        style = MaterialTheme.typography.bodySmall)
                    Text("CA confirmé : " + xaf(sales), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("Objectif") })
                    OutlinedTextField(target, { target = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Cible de CA (FCFA)") }, singleLine = true)
                    if (activeTarget != null) {
                        Text("Baseline actuellement applicable : " + xaf(activeTarget.amountXaf) + " · enregistrée le " +
                            java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date(activeTarget.createdAtMillis)),
                            style = MaterialTheme.typography.bodySmall)
                    }
                    if (goal > 0L) {
                        androidx.compose.material3.LinearProgressIndicator(
                            progress = progress.toFloat().coerceIn(0f, 1f), modifier = Modifier.fillMaxWidth()
                        )
                        Text("Atteinte : " + String.format(java.util.Locale.FRANCE, "%.1f", progress) +
                            " % · " + if (gap > 0L) "reste " + xaf(gap) else "objectif atteint")
                    } else Text("Aucune cible enregistrée pour cette période.")
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
                    ) { Text("Enregistrer une nouvelle baseline") }
                    notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                }
            }
        }
        item { Text("Historique des objectifs approuvés", fontWeight = FontWeight.Bold) }
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
            Text("CA confirmé : " + xaf(point.revenueXaf) + " · " + comparisonLabel + " : " + change(point.revenueDeltaXaf))
            Text("Coût des ventes connu : " + xaf(point.costOfGoodsXaf) + " · " + comparisonLabel + " : " + change(point.costOfGoodsDeltaXaf))
            Text("Charges d'exploitation : " + xaf(point.operatingExpensesXaf) + " · " + comparisonLabel + " : " + change(point.operatingExpensesDeltaXaf))
            Text("Marge brute : " + (point.grossProfitXaf?.let {
                xaf(it) + " · " + comparisonLabel + " : " + (point.grossProfitDeltaXaf?.let(::change) ?: "—")
            } ?: "non calculable : coût direct incomplet"), color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Résultat opérationnel indicatif : " + (point.operatingResultXaf?.let {
                xaf(it) + " · " + comparisonLabel + " : " + (point.operatingResultDeltaXaf?.let(::change) ?: "—")
            } ?: "non déterminable tant que le coût direct de toutes les ventes n'est pas documenté"), fontWeight = FontWeight.Medium)
            Text(
                "Fournisseurs : stock capitalisé " + xaf(point.supplierStockPurchasesXaf) +
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
            Text("Réalisé confirmé : " + xaf(period.actualXaf))
            Text("Projection de clôture : " + xaf(period.projectedXaf), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Période comparable : " + xaf(period.comparablePreviousXaf) + " · " + comparison)
            period.targetXaf?.let { target ->
                Text("Objectif approuvé : " + xaf(target))
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
                    Text("Atteinte projetée : " + String.format(java.util.Locale.FRANCE, "%.1f", ratio) + " %")
                }
            } ?: Text("Aucun objectif approuvé enregistré pour cette période.")
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
            Text("Assistant IA de pilotage", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(
                "Prévisions de CA, comparaison des périodes et recommandations de redressement. Les projections utilisent les ventes confirmées locales et les objectifs enregistrés ; aucune vente en attente n'est comptée.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            LocalOnlyNotice(
                "Moteur statistique local explicable : moyenne glissante de 14 jours pour la journée, 28 jours pour la clôture mensuelle et 90 jours pour la clôture annuelle. Les résultats dépendent de l'historique disponible et se recalculent à chaque actualisation des données."
            )
            Text("Périmètre : " + siteIds.size + " site(s) accessibles et consolidés.", style = MaterialTheme.typography.labelSmall)
            Text("Couverture des ventes : " + dashboard.dataCoverageDays + " jour(s).", style = MaterialTheme.typography.labelSmall)
        }
        item { PerformanceProjectionCard("Aujourd'hui · jour par jour", dashboard.day) }
        item { PerformanceProjectionCard("Mois en cours · mois par mois", dashboard.month) }
        item { PerformanceProjectionCard("Année en cours · année par année", dashboard.year) }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Rentabilité et engagements fournisseurs", fontWeight = FontWeight.Bold)
                    Text("Chiffre d'affaires confirmé (période couverte) : " + xaf(dashboard.revenueXaf))
                    Text("CA des ventes au coût fiable : " + xaf(dashboard.costedRevenueXaf))
                    Text("Coût des marchandises vendues valorisées : " + xaf(dashboard.costOfGoodsXaf))
                    Text("Marge brute sur ventes au coût connu : " + xaf(dashboard.grossProfitXaf) +
                        (dashboard.grossMarginPercent?.let { " · " + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %" } ?: " · non calculable"))
                    Text("Charges d'exploitation journalisées : " + xaf(dashboard.operatingExpensesXaf))
                    Text("Solde de gestion indicatif : " +
                        (dashboard.operatingProfitProxyXaf?.let { xaf(it) } ?: "non déterminable : COGS historique incomplet"),
                        fontWeight = FontWeight.Bold)
                    Text("Dette fournisseurs non réglée : " + xaf(dashboard.supplierPayablesXaf))
                    Text("Flux fournisseurs comptabilisés ce mois-ci", fontWeight = FontWeight.SemiBold)
                    Text("Stocks reçus et capitalisés : " + xaf(dashboard.currentMonthSupplierStockPurchasesXaf))
                    Text("Achats courants reçus et passés en charges : " + xaf(dashboard.currentMonthSupplierOperatingPurchasesXaf))
                    Text("Immobilisations reçues : " + xaf(dashboard.currentMonthSupplierFixedAssetsXaf))
                    Text("Règlements fournisseurs (trésorerie, sans seconde charge) : " + xaf(dashboard.currentMonthSupplierPaymentsXaf))
                    if (dashboard.uncostedStockSalesCount > 0) {
                        Text(
                            dashboard.uncostedStockSalesCount.toString() + " vente(s) de stock antérieure(s) ne possèdent pas de coût historique fiable ; elles sont signalées et ne sont pas inventées dans le coût des ventes.",
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                    Text(
                        "Les achats de stock n'augmentent pas le CA et ne sont pas déduits immédiatement de la marge : ils augmentent la valeur du stock et la dette fournisseur. Le coût est passé en coût des ventes lorsque le stock est vendu.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "Le solde de gestion est un indicateur local avant éléments non enregistrés, amortissements, commissions et fiscalité ; il n'est pas un résultat SYSCOHADA certifié.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        item { Text("Performance jour par jour · 14 derniers jours", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.dailyTrend) { row ->
            val delta = (if (row.deltaXaf >= 0L) "+" else "−") + xaf(if (row.deltaXaf >= 0L) row.deltaXaf else -row.deltaXaf)
            val rate = row.deltaPercent?.let { " (" + (if (it >= 0) "+" else "") + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %)" } ?: ""
            Text(row.label + " · " + xaf(row.actualXaf) + " · écart vs veille : " + delta + rate,
                style = MaterialTheme.typography.bodySmall)
        }
        item { Text("Rentabilité et flux fournisseurs · détail jour par jour", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.dailyFinancialTrend, key = { "finance-day-" + it.label }) { point ->
            FinancialTrendRow(point, "vs veille")
        }
        item { Text("Performance mois par mois · 12 derniers mois", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.monthlyTrend) { row ->
            val delta = (if (row.deltaXaf >= 0L) "+" else "−") + xaf(if (row.deltaXaf >= 0L) row.deltaXaf else -row.deltaXaf)
            val rate = row.deltaPercent?.let { " (" + (if (it >= 0) "+" else "") + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %)" } ?: ""
            Text(row.label + " · " + xaf(row.actualXaf) + " · écart vs mois précédent : " + delta + rate,
                style = MaterialTheme.typography.bodySmall)
        }
        item { Text("Rentabilité et flux fournisseurs · détail mois par mois", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.monthlyFinancialTrend, key = { "finance-month-" + it.label }) { point ->
            FinancialTrendRow(point, "vs période comparable du mois précédent")
        }
        item { Text("Performance année par année · 5 derniers exercices", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.yearlyTrend) { row ->
            val delta = (if (row.deltaXaf >= 0L) "+" else "−") + xaf(if (row.deltaXaf >= 0L) row.deltaXaf else -row.deltaXaf)
            val rate = row.deltaPercent?.let { " (" + (if (it >= 0) "+" else "") + String.format(java.util.Locale.FRANCE, "%.1f", it) + " %)" } ?: ""
            Text(row.label + " · " + xaf(row.actualXaf) + " · écart vs exercice précédent : " + delta + rate,
                style = MaterialTheme.typography.bodySmall)
        }
        item { Text("Rentabilité et flux fournisseurs · détail année par année", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(dashboard.yearlyFinancialTrend, key = { "finance-year-" + it.label }) { point ->
            FinancialTrendRow(point, "vs même période de l'exercice précédent")
        }
        item { Text("Stratégies de redressement et de progression", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
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
            Text("Profil", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    PrivateProfilePhoto(session)
                    Text(session.account.displayName.take(1).uppercase(), style = MaterialTheme.typography.displayMedium, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Black)
                    }
                    OutlinedButton(onClick = { photoPicker.launch(arrayOf("image/*")) }) { Text("Choisir une photo de profil") }
                    Text(session.account.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(session.account.roleCode + " · " + session.account.organizationName)
                    Text("Identifiant membre : " + session.account.memberId, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Activité : " + (activity?.titleFr ?: "Non définie"))
                    Text("Langue : " + session.account.defaultLocale.uppercase())
                    Text("Modèle : " + when(session.account.businessMode) {
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
            Text("Préférences et sécurité", fontWeight = FontWeight.Bold)
            OutlinedButton(onClick = { onNavigate(AppRoute.APPEARANCE) }, modifier = Modifier.fillMaxWidth()) { Text("Langue, thème et mode nuit") }
            OutlinedButton(onClick = { onNavigate(AppRoute.SECURITY) }, modifier = Modifier.fillMaxWidth()) { Text("Comptes, appareils et accès") }
            OutlinedButton(onClick = { onNavigate(AppRoute.NOTIFICATIONS) }, modifier = Modifier.fillMaxWidth()) { Text("Centre de notifications") }
            LocalAccessPinSettingsCard(session.account.memberId)
            if (session.account.roleCode == "promoter") {
                OutlinedButton(onClick = { showReferralScreen = true }, modifier = Modifier.fillMaxWidth()) { Text("Parrainage PME et suivi de mes gains") }
                OutlinedButton(onClick = { onNavigate(AppRoute.CUSTOMER_PROMOTIONS) }, modifier = Modifier.fillMaxWidth()) { Text("Parrainage client et roue promotionnelle") }
                OutlinedButton(onClick = { showLoyaltyScreen = true }, modifier = Modifier.fillMaxWidth()) { Text("Programme de fidélité") }
                OutlinedButton(onClick = { onNavigate(AppRoute.CHARGES) }, modifier = Modifier.fillMaxWidth()) { Text("Charges et échéances de paiement") }
            }
            OutlinedButton(onClick = { onNavigate(AppRoute.HELP) }, modifier = Modifier.fillMaxWidth()) { Text("FAQ et assistance") }
            OutlinedButton(onClick = { onNavigate(AppRoute.SUBSCRIPTIONS) }, modifier = Modifier.fillMaxWidth()) { Text("Abonnement et paiement") }
        }
        item {
            Text("Historique local", fontWeight = FontWeight.Bold)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Historique des registres locaux ; l’historique serveur complet dépend de la synchronisation.")
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
            Button(onClick = onLogout, modifier = Modifier.fillMaxWidth()) { Text("Se déconnecter") }
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
            Text("Livechat et assistance", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("FAQ et demandes d’assistance. Les messages sont conservés localement et attendent la passerelle support. Les appels et le partage d’écran temps réel nécessitent encore le service média et les permissions de session.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(
                siteIds,
                siteId,
                session.account.activeSites.associate { it.id to it.name }
            ) { siteId = it }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Questions fréquentes", fontWeight = FontWeight.Bold)
                    Text("• Comment ouvrir et clôturer une caisse ?")
                    Text("• Comment corriger une erreur sans effacer l’historique ?")
                    Text("• Comment ajouter un employé ou un point de vente ?")
                    Text("• Comment sauvegarder et restaurer mes données ?")
                    Text("• Comment suivre une échéance d’abonnement ?")
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(subject, { subject = it }, Modifier.fillMaxWidth(), label = { Text("Sujet") })
                    OutlinedTextField(message, { message = it }, Modifier.fillMaxWidth(), label = { Text("Votre message") }, minLines = 4)
                    Button(onClick = {
                        if (subject.isBlank() || message.trim().length < 10) notice = "Saisis un sujet et au moins 10 caractères."
                        else scope.launch {
                            runCatching { repository.createSupportRequest(session.account.organizationId, siteId, subject, message, "normal") }
                                .onSuccess { subject = ""; message = ""; notice = "Demande enregistrée localement. Elle sera transmise à la synchronisation." }
                                .onFailure { notice = it.message ?: "Envoi impossible." }
                        }
                    }, enabled = siteId.isNotBlank(), modifier = Modifier.fillMaxWidth()) { Text("Créer une demande") }
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text("Demandes récentes", fontWeight = FontWeight.Bold) }
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
                Text("Reçu de caisse", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(record.reference + " · " + xaf(record.amountXaf))
                Text(if (sale.status == "pending") "Paiement Mobile Money en attente : ce reçu n'atteste pas encore du règlement." else "Paiement espèces enregistré localement.")
                Text("Choisis une action pour remettre le justificatif au client.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(onClick = { saveLauncher.launch("NAXA-" + sale.saleNumber + ".pdf") }, modifier = Modifier.fillMaxWidth()) {
                    Text("Télécharger / enregistrer le PDF")
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
                ) { Text("Partager le PDF (WhatsApp ou autre)") }
                OutlinedButton(
                    onClick = {
                        runCatching { printReceipt(context, record, session.account.organizationName) }
                            .onFailure { error = it.message ?: "Impression impossible." }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Imprimer le reçu") }
                if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("Fermer") }
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
                (if (fr) "Parcours métier — " else "Business journey — ") + if (fr) workflow.titleFr else workflow.titleEn,
                if (fr) workflow.purposeFr else workflow.purposeEn
            )
            AuthorizedSitePicker(
                sites, siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it; workstationId = "" }
            LocalOnlyNotice(
                if (fr) "Dossiers enregistrés localement puis synchronisés selon le journal serveur. Cette fiche ne valide jamais un encaissement ; le paiement doit passer par la caisse." 
                else "Records are saved locally then synchronized through the server journal. This form never confirms a payment; payment must go through cash."
            )
            workflow.notesFr.forEach { note ->
                Text("• " + note, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            }
            if (profile == "beaute" && fr) {
                Text("Ne saisis aucune donnée médicale, aucun diagnostic ni antécédent dans ce dossier.", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            if (workflow.journey == "retail") {
                Text(
                    if (fr) "Parcours spécial : commande ou réservation uniquement. Une vente réelle doit être créée dans le Point de vente, avec son stock et son paiement distincts."
                    else "Special-order flow only. A real sale must be created in POS, with separate inventory and payment records.",
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Nouveau dossier" else "New record", fontWeight = FontWeight.Bold)
                    Text(
                        if (fr) "Emplacement / poste (facultatif — le registre reste consolidé au niveau du site)"
                        else "Workstation (optional — the ledger remains consolidated at site level)",
                        fontWeight = FontWeight.SemiBold
                    )
                    OutlinedButton(onClick = { workstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (workstationId.isBlank()) (if (fr) "✓ Aucun poste dédié" else "✓ No dedicated workstation") else if (fr) "Aucun poste dédié" else "No dedicated workstation")
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { workstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (workstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    OutlinedTextField(
                        customer, { customer = it },
                        Modifier.fillMaxWidth(),
                        label = { Text(if (fr) "Client / donneur d'ordre" else "Customer / requester") },
                        singleLine = true
                    )
                    OutlinedTextField(
                        title, { title = it },
                        Modifier.fillMaxWidth(),
                        label = { Text(if (fr) "Intitulé du dossier" else "Record title") },
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
                                            if (fr) "Choisir une date" else "Choose a date"
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
                        label = { Text(if (fr) "Montant estimatif / devis (FCFA)" else "Estimated amount / quote (XAF)") },
                        singleLine = true
                    )
                    OutlinedTextField(
                        requestedDeposit,
                        { requestedDeposit = it.filter(Char::isDigit).take(18) },
                        Modifier.fillMaxWidth(),
                        label = { Text(if (fr) "Acompte demandé (non encaissé ici) (FCFA)" else "Requested deposit (not collected here) (XAF)") },
                        singleLine = true
                    )
                    OutlinedTextField(
                        dueDays,
                        { dueDays = it.filter(Char::isDigit).take(3) },
                        Modifier.fillMaxWidth(),
                        label = { Text(if (fr) "Délai estimé en jours" else "Estimated lead time in days") },
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
                                    message = if (fr) "Dossier enregistré. Statut initial : reçu. Aucun encaissement n'a été créé." else "Record saved. Initial status: received. No payment was recorded."
                                }.onFailure {
                                    error = it.message ?: if (fr) "Création impossible." else "Unable to create record."
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
                            if (fr) "Enregistrement…" else "Saving…"
                        } else {
                            if (fr) "Créer le dossier" else "Create record"
                        })
                    }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(if (fr) "Dossiers du point de vente" else "Site records", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (records.isEmpty()) {
            item { Text(if (fr) "Aucun dossier enregistré." else "No records yet.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
                        (if (fr) "Montant estimatif" else "Estimated amount") + " : " + xaf(item.amountXaf) +
                            " · " + (if (fr) "Acompte demandé" else "Deposit requested") + " : " +
                            xaf(metadata.optLong("depositRequestedXaf", 0L)) +
                            " · " + (if (fr) "Acompte réellement encaissé" else "Deposit actually collected") + " : " + xaf(item.paidXaf)
                    )
                    Text((if (fr) "Statut" else "Status") + " : " + stageLabel(item.status), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    Text((if (fr) "Échéance" else "Due") + " : " + (item.dueAtMillis?.let { java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(it)) } ?: "—"))
                    if (item.status !in setOf("closed", "cancelled")) {
                        OutlinedTextField(
                            reason,
                            { reason = it.take(500) },
                            Modifier.fillMaxWidth(),
                            label = { Text(if (fr) "Motif obligatoire pour changer l'étape" else "Reason required for status change") },
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
                                            message = if (fr) "Étape mise à jour et journalisée." else "Workflow stage updated and audited."
                                        }.onFailure {
                                            error = it.message ?: if (fr) "Transition impossible." else "Transition failed."
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
                        Text(if (fr) "Historique des étapes" else "Workflow history", fontWeight = FontWeight.SemiBold)
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
        it.recordType in setOf("staff_commission", "staff_advance", "staff_bonus")
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                if (fr) "Présences, horaires et rémunérations variables" else "Attendance, working hours and variable pay",
                if (fr) "Pointage chronologique, pauses, affectation par poste, commissions, avances et primes." else "Validated clocking sequence, breaks, workstation assignment, commissions, advances and bonuses."
            )
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) {
                siteId = it
                attendanceWorkstationId = ""
            }
            LocalOnlyNotice(
                if (fr) "Les pointages sont locaux, horodatés et contrôlés par séquence. La validation RH/paie serveur et la synchronisation restent à raccorder." else "Clock events are local, timestamped and sequence-validated. Server HR/payroll approval and synchronization remain to be connected."
            )
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Pointage et mouvements d’équipe" else "Team time clock", fontWeight = FontWeight.Bold)
                    OutlinedTextField(
                        staff, { staff = it }, Modifier.fillMaxWidth(),
                        label = { Text(if (fr) "Collaborateur (nom ou identifiant)" else "Staff member (name or ID)") },
                        singleLine = true
                    )
                    Text(if (fr) "Emplacement / poste (facultatif)" else "Workstation (optional)", fontWeight = FontWeight.SemiBold)
                    OutlinedButton(onClick = { attendanceWorkstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (attendanceWorkstationId.isBlank()) (if (fr) "✓ Pointage au niveau du site" else "✓ Site-level time clock") else if (fr) "Aucun poste dédié" else "No dedicated workstation")
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { attendanceWorkstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (attendanceWorkstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    listOf(
                        "staff_clock_in" to (if (fr) "Prise de service" else "Clock in"),
                        "staff_break_start" to (if (fr) "Début de pause" else "Start break"),
                        "staff_break_end" to (if (fr) "Fin de pause" else "End break"),
                        "staff_clock_out" to (if (fr) "Fin de service" else "Clock out")
                    ).forEach { (value, label) ->
                        OutlinedButton(onClick = { attendanceOperation = value }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (attendanceOperation == value) "✓ $label" else label)
                        }
                    }
                    Text(
                        if (fr) "Séquence : prise de service → pause → reprise → sortie. Les doubles pointages et sorties sans prise de service sont refusés." else "Sequence: clock in → break → resume → clock out. Duplicate clock-ins and clock-outs without a shift are rejected.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Button(
                        onClick = {
                            if (staff.isBlank() || siteId.isBlank()) {
                                error = if (fr) "Choisis un collaborateur et un point de vente." else "Choose a staff member and site."
                            } else scope.launch {
                                runCatching {
                                    repository.recordStaffTimeEvent(
                                        session.account.organizationId, siteId, attendanceOperation,
                                        staff, session.account.memberId,
                                        attendanceWorkstationId.takeIf { it.isNotBlank() }
                                    )
                                }.onSuccess {
                                    message = if (fr) "Pointage enregistré ; séquence validée et historisée." else "Clock event saved; sequence validated and recorded."
                                    error = null
                                }.onFailure { error = it.message ?: if (fr) "Pointage impossible." else "Unable to record time event." }
                            }
                        },
                        enabled = staff.isNotBlank() && siteId.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (fr) "Enregistrer le pointage" else "Record time event") }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Commission, avance ou prime" else "Commission, advance or bonus", fontWeight = FontWeight.Bold)
                    OutlinedTextField(staff, { staff = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Collaborateur" else "Staff member") }, singleLine = true)
                    OutlinedTextField(detail, { detail = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Prestation / motif" else "Service / reason") }, singleLine = true)
                    OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Montant (FCFA)" else "Amount (XAF)") }, singleLine = true)
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        listOf(
                            "staff_commission" to (if (fr) "Commission" else "Commission"),
                            "staff_advance" to (if (fr) "Avance" else "Advance"),
                            "staff_bonus" to (if (fr) "Prime" else "Bonus")
                        ).forEach { (value, label) ->
                            OutlinedButton(onClick = { payrollOperation = value }) {
                                Text(if (payrollOperation == value) "✓ $label" else label)
                            }
                        }
                    }
                    Button(
                        onClick = {
                            val value = amount.toLongOrNull() ?: 0L
                            if (staff.isBlank() || detail.isBlank() || value <= 0 || siteId.isBlank()) {
                                error = if (fr) "Collaborateur, motif et montant positif requis." else "Staff, reason and a positive amount are required."
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
                                    message = if (fr) "Mouvement de rémunération enregistré en attente de validation." else "Variable pay record saved for approval."
                                    amount = ""; detail = ""; error = null
                                }.onFailure { error = it.message ?: if (fr) "Enregistrement impossible." else "Unable to save record." }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (fr) "Enregistrer le mouvement" else "Save variable-pay record") }
                }
            }
        }
        item { Text(if (fr) "Horaires récents" else "Recent attendance", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(attendance.take(40)) { row ->
            Text(
                row.counterparty + " · " + row.title + " · " +
                    java.text.SimpleDateFormat("dd/MM HH:mm", java.util.Locale.getDefault()).format(java.util.Date(row.createdAtMillis)),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        item { Text(if (fr) "Commissions, avances et primes" else "Commissions, advances and bonuses", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(payroll.take(40)) { row ->
            var approvalReason by rememberSaveable(row.id) { mutableStateOf("") }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(row.counterparty + " · " + labelRecord(row.recordType), fontWeight = FontWeight.SemiBold)
                    Text(row.title + " · " + xaf(row.amountXaf) + " · " + row.status, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (row.status == "pending_review") {
                        OutlinedTextField(
                            approvalReason,
                            { approvalReason = it },
                            Modifier.fillMaxWidth(),
                            label = { Text(if (fr) "Motif de validation ou de rejet obligatoire" else "Reason required to approve or reject") }
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
                                        }.onSuccess { message = if (fr) "Mouvement approuvé et historisé." else "Record approved and audited."; error = null }
                                            .onFailure { error = it.message ?: "Approval failed." }
                                    }
                                },
                                enabled = approvalReason.trim().length >= 3,
                                modifier = Modifier.weight(1f)
                            ) { Text(if (fr) "Approuver" else "Approve") }
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(
                                                session.account.organizationId, siteId, row.id,
                                                "rejected", approvalReason, session.account.memberId
                                            )
                                        }.onSuccess { message = if (fr) "Mouvement rejeté et historisé." else "Record rejected and audited."; error = null }
                                            .onFailure { error = it.message ?: "Rejection failed." }
                                    }
                                },
                                enabled = approvalReason.trim().length >= 3,
                                modifier = Modifier.weight(1f)
                            ) { Text(if (fr) "Rejeter" else "Reject") }
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
            LocalOnlyNotice("Les rappels Android sont calculés localement sur cet appareil. Les notifications multi-appareils, SMS et WhatsApp côté serveur restent dépendantes du backend.")
            if (android.os.Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                OutlinedButton(
                    onClick = { notificationPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS) },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Autoriser les notifications d'échéance") }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Pilotage du mois en cours", fontWeight = FontWeight.Bold)
                    Text("Chiffre d'affaires brut encaissé et confirmé : " + xaf(monthSales), style = MaterialTheme.typography.titleMedium)
                    Text("Charges fixes réglées : " + xaf(monthFixedCharges))
                    Text("Solde de gestion indicatif après ces charges : " + xaf(monthSales - monthFixedCharges), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Text("Le CA reste le total des ventes confirmées. Le solde indicatif retranche uniquement les charges fixes enregistrées et payées ici ; il ne constitue ni un résultat comptable SYSCOHADA ni un résultat fiscal.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (editingId == null) "Nouvelle charge" else "Modifier la charge", fontWeight = FontWeight.Bold)
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Libellé : loyer, électricité, impôts, taxes…") }, singleLine = true)
                    OutlinedTextField(category, { category = it }, Modifier.fillMaxWidth(), label = { Text("Catégorie") }, singleLine = true)
                    OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Montant attendu (FCFA)") }, singleLine = true)
                    Text("Périodicité")
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        listOf("monthly" to "Mensuelle", "quarterly" to "Trimestrielle", "annual" to "Annuelle", "one_time" to "Unique").forEach { option ->
                            OutlinedButton(onClick = { recurrence = option.first }) {
                                Text((if (recurrence == option.first) "✓ " else "") + option.second)
                            }
                        }
                    }
                    OutlinedTextField(dueInDays, { dueInDays = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(), label = { Text("Prochaine échéance dans (jours)") }, singleLine = true)
                    OutlinedTextField(reminderDays, { reminderDays = it.filter(Char::isDigit).take(2) }, Modifier.fillMaxWidth(), label = { Text("Rappel avant échéance (jours)") }, singleLine = true)
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
                    if (editingId != null) TextButton(onClick = { editingId = null; name = ""; amount = ""; category = "Loyer" }) { Text("Annuler la modification") }
                    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    message?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                }
            }
        }
        item { Text("Rappels à surveiller", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (due.isEmpty()) item { Text("Aucune échéance dans la fenêtre de rappel configurée.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(due) { charge ->
            val paid = payments.filter { it.chargeId == charge.id && it.referenceDueAtMillis == charge.nextDueAtMillis }.sumOf { it.amountXaf }
            val balance = (charge.amountXaf - paid).coerceAtLeast(0L)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(charge.name + " · " + charge.category, fontWeight = FontWeight.Bold)
                    Text("Échéance : " + fmt.format(java.util.Date(charge.nextDueAtMillis)) + " · " + charge.recurrence)
                    Text("Montant : " + xaf(charge.amountXaf) + " · déjà réglé : " + xaf(paid))
                    Text(if (balance == 0L) "Échéance réglée" else if (charge.nextDueAtMillis < now) "En retard : " + xaf(balance) else "À provisionner : " + xaf(balance), color = if (charge.nextDueAtMillis < now && balance > 0L) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
                    if (balance > 0L) {
                        OutlinedTextField(paymentAmount, { paymentAmount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Règlement partiel ou total (FCFA)") }, singleLine = true)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching { repository.recordRecurringChargePayment(orgId, siteId, charge.id, balance, session.account.memberId) }
                                            .onSuccess { paymentAmount = ""; message = "Échéance réglée. La prochaine échéance a été avancée." }
                                            .onFailure { error = it.message ?: "Paiement impossible." }
                                    }
                                }, modifier = Modifier.weight(1f)
                            ) { Text("Régler le solde") }
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
                            ) { Text("Paiement partiel") }
                        }
                    }
                    TextButton(onClick = {
                        editingId = charge.id; name = charge.name; category = charge.category; amount = charge.amountXaf.toString()
                        recurrence = charge.recurrence
                        dueInDays = (((charge.nextDueAtMillis - System.currentTimeMillis()) / 86_400_000L).coerceAtLeast(0L)).toString()
                        reminderDays = charge.reminderDays.toString()
                    }) { Text("Modifier cette charge") }
                }
            }
        }
        item { Text("Autres échéances programmées", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (otherScheduled.isEmpty()) item { Text("Aucune autre charge active à venir.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(otherScheduled) { charge ->
            val paid = payments.filter { it.chargeId == charge.id && it.referenceDueAtMillis == charge.nextDueAtMillis }.sumOf { it.amountXaf }
            val balance = (charge.amountXaf - paid).coerceAtLeast(0L)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(charge.name + " · " + charge.category, fontWeight = FontWeight.Bold)
                    Text("Prochaine échéance : " + fmt.format(java.util.Date(charge.nextDueAtMillis)) + " · " + charge.recurrence)
                    Text("Montant : " + xaf(charge.amountXaf) + " · rappel " + charge.reminderDays + " jour(s) avant")
                    Text("Solde sur l'échéance actuelle : " + xaf(balance))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = {
                            editingId = charge.id; name = charge.name; category = charge.category; amount = charge.amountXaf.toString()
                            recurrence = charge.recurrence
                            dueInDays = (((charge.nextDueAtMillis - System.currentTimeMillis()) / 86_400_000L).coerceAtLeast(0L)).toString()
                            reminderDays = charge.reminderDays.toString()
                        }) { Text("Modifier") }
                        TextButton(onClick = {
                            scope.launch {
                                runCatching { repository.deactivateRecurringCharge(orgId, siteId, charge.id, session.account.memberId) }
                                    .onSuccess { message = "Charge désactivée ; son historique est conservé." }
                                    .onFailure { error = it.message ?: "Désactivation impossible." }
                            }
                        }) { Text("Désactiver") }
                    }
                }
            }
        }
        item { Text("Historique des règlements", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (payments.isEmpty()) item { Text("Aucun règlement enregistré.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
                Text("Programmes de fidélité", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                TextButton(onClick = onBack) { Text("Retour") }
            }
            Text("Quatre programmes autonomes adaptés au profil d'activité : points, passages, dépenses cumulées et fréquence de visite.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it; selectedCustomerId = "" }
            LocalOnlyNotice("Les gains et historiques sont enregistrés localement et rattachés à l'organisation et au site. L'interconnexion automatique à la caisse sera activée avec l'API ERP synchronisée.")
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
                        OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Nom du programme") }, singleLine = true)
                        OutlinedTextField(description, { description = it }, Modifier.fillMaxWidth(), label = { Text("Présentation et règles") }, minLines = 2)
                        Text("Indicateur suivi")
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            listOf("points" to "Points", "visits" to "Visites", "spend" to "Montant dépensé").forEach { option ->
                                OutlinedButton(onClick = { metric = option.first }) { Text((if (metric == option.first) "✓ " else "") + option.second) }
                            }
                        }
                        OutlinedTextField(unitAmount, { unitAmount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("FCFA par unité gagnée (ex. 1 000 pour les points)") }, singleLine = true)
                        OutlinedTextField(target, { target = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Seuil de récompense") }, singleLine = true)
                        OutlinedTextField(reward, { reward = it }, Modifier.fillMaxWidth(), label = { Text("Récompense à offrir") }, minLines = 2)
                        OutlinedTextField(window, { window = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text("Fenêtre glissante en jours (0 = illimitée)") }, singleLine = true)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            androidx.compose.material3.Checkbox(checked = active, onCheckedChange = { active = it })
                            Text("Programme actif")
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
                        ) { Text("Enregistrer la configuration") }
                    }
                }
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Enregistrer une visite ou un achat client", fontWeight = FontWeight.Bold)
                        if (customers.isEmpty()) Text("Crée d'abord la fiche du client dans le CRM.")
                        customers.forEach { customer ->
                            OutlinedButton(onClick = { selectedCustomerId = customer.id }, modifier = Modifier.fillMaxWidth()) {
                                Text((if (selectedCustomerId == customer.id) "✓ " else "") + customer.displayName)
                            }
                        }
                        OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Montant de l'achat (FCFA) ; 0 pour un passage") }, singleLine = true)
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
            item { Text("Historique et récompenses", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
            if (events.isEmpty()) item { Text("Aucune activité ou récompense enregistrée pour ce programme.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
                                }) { Text("Marquer comme utilisée") }
                            }
                        } else Text("Valeur : " + event.metricDelta + " · achat : " + xaf(event.amountXaf), style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        } else {
            item { Text("Initialisation des quatre programmes en cours…", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
        notice?.let { item { Text(it, color = MaterialTheme.colorScheme.primary) } }
        item { Spacer(Modifier.height(24.dp)) }
    }
}
