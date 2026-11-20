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
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.Calendar
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
fun SubscriptionsContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    val records by remember(session.account.organizationId) {
        repository.dao.observeOrganizationManagementRecordsByType(session.account.organizationId, "subscription_request")
    }.collectAsState(initial = emptyList())
    var plan by rememberSaveable { mutableStateOf("ACCESS") }
    var period by rememberSaveable { mutableStateOf("monthly") }
    var paymentReference by rememberSaveable { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val monthlyPrice = if (plan == "ACCESS") 3000L else 10000L
    val matureMonthlyPrice = if (plan == "ACCESS") 5000L else 15000L
    val amountDue = monthlyPrice * if (period == "annual") 10L else 1L
    val matureAmount = matureMonthlyPrice * if (period == "annual") 10L else 1L
    val priceLabel = if (fr) "FCFA" else "XAF"

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text(if (fr) "Abonnement NAXA SERVICES" else "NAXA SERVICES subscription", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(
                if (fr) "Une souscription Promoteur par organisation couvre les points de vente et postes autorisés. Aucun site supplémentaire ne crée un second abonnement." else "One Promoter subscription per organization covers its authorized sites and workstations. Adding a site does not create a second subscription.",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            LocalOnlyNotice(if (fr) "Le paiement, les renouvellements et les droits seront confirmés par le serveur. Cette page ne valide aucun paiement ni entitlement." else "Payments, renewals and entitlements must be confirmed by the server. This screen does not activate any payment or entitlement.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(if (fr) "Choisir une formule" else "Choose a plan", fontWeight = FontWeight.Bold)
                    listOf(
                        "ACCESS" to (if (fr) "ACCÈS" else "ACCESS"),
                        "PREMIUM" to "PREMIUM"
                    ).forEach { (code, label) ->
                        val amount = if (code == "ACCESS") 3000 else 10000
                        val mature = if (code == "ACCESS") 5000 else 15000
                        Card(
                            colors = CardDefaults.cardColors(
                                containerColor = if (plan == code) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceVariant
                            ),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                Text(label, fontWeight = FontWeight.Bold)
                                Text(if (fr) "Aujourd'hui : " + xaf(amount.toLong()) + " / mois" else "Today: " + xaf(amount.toLong()) + " / month")
                                Text(if (fr) "À partir du 1er mai 2027 : " + xaf(mature.toLong()) + " / mois" else "From 1 May 2027: " + xaf(mature.toLong()) + " / month")
                                Text(
                                    if (code == "ACCESS") {
                                        if (fr) "Compte unique, prestations, agenda, caisse, clients, stocks et pilotage de base." else "Single account, services, calendar, cash, customers, inventory and core management."
                                    } else {
                                        if (fr) "Inclut tous les droits ACCÈS, avec organisation multiniveau, délégation, supervision et consolidation." else "Includes all ACCESS rights, plus multi-level organization, delegation, supervision and consolidation."
                                    },
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                OutlinedButton(onClick = { plan = code }, modifier = Modifier.fillMaxWidth()) {
                                    Text(if (plan == code) if (fr) "✓ Formule sélectionnée" else "✓ Selected plan" else if (fr) "Choisir cette formule" else "Choose this plan")
                                }
                            }
                        }
                    }
                    Text(if (fr) "Périodicité" else "Billing period", fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { period = "monthly" }, enabled = period != "monthly", modifier = Modifier.weight(1f)) {
                            Text(if (fr) "Mensuel" else "Monthly")
                        }
                        OutlinedButton(onClick = { period = "annual" }, enabled = period != "annual", modifier = Modifier.weight(1f)) {
                            Text(if (fr) "Annuel — 2 mois offerts" else "Annual — 2 months free")
                        }
                    }
                    Text(
                        if (fr) "Montant aujourd'hui : " + xaf(amountDue) + " pour " + (if (period == "annual") "12 mois" else "1 mois") else "Amount today: " + xaf(amountDue) + " for " + (if (period == "annual") "12 months" else "1 month"),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        if (fr) "Montant au renouvellement à partir du 1er mai 2027 : " + xaf(matureAmount) + (if (period == "annual") " pour 12 mois" else " / mois") else "Renewal amount from 1 May 2027: " + xaf(matureAmount) + (if (period == "annual") " for 12 months" else " / month"),
                        color = MaterialTheme.colorScheme.secondary
                    )
                    Text(
                        if (fr) "La grille maturité est programmée au 1er mai 2027 pour les dix applications NAXA FAMILY. Elle s'applique aux nouvelles périodes de service commençant à cette date ou après ; une période déjà payée n'est pas recalculée." else "The maturity catalogue is scheduled for 1 May 2027 across all ten NAXA FAMILY apps. It applies to new service periods starting on or after that date; an already-paid period is not repriced.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(if (fr) "Essai initial : 72 heures, une seule fois par organisation et application." else "Initial trial: 72 hours, once per organization and app.", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Demande de souscription / renouvellement" else "Subscription / renewal request", fontWeight = FontWeight.Bold)
                    OutlinedTextField(paymentReference, { paymentReference = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Référence de paiement (facultative)" else "Payment reference (optional)") }, singleLine = true)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                runCatching {
                                    val metadata = JSONObject()
                                        .put("catalogAppId", "NAXA_SERVICES")
                                        .put("planCode", plan)
                                        .put("billingPeriod", period)
                                        .put("launchMonthlyAmountXaf", monthlyPrice)
                                        .put("scheduledMatureMonthlyAmountXaf", matureMonthlyPrice)
                                        .put("maturityEffectiveDate", "2027-05-01")
                                        .put("paymentReference", paymentReference.take(100))
                                        .put("annualFactor", if (period == "annual") 10 else 1)
                                        .toString()
                                    repository.createManagementRecord(
                                        session.account.organizationId, "ORG_SCOPE", "subscription_request",
                                        "SUB-" + System.currentTimeMillis(),
                                        "NAXA SERVICES " + plan + " " + period,
                                        session.account.organizationName,
                                        amountDue, 0, null, "pending_review", metadata,
                                        session.account.memberId
                                    )
                                }.onSuccess {
                                    paymentReference = ""
                                    message = if (fr) "Demande enregistrée localement. Aucun droit n'est activé avant confirmation du paiement côté serveur." else "Request saved locally. No entitlement is activated before server-side payment confirmation."
                                    error = null
                                }.onFailure { error = it.message ?: "Subscription request failed." }
                                busy = false
                            }
                        },
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) if (fr) "Enregistrement…" else "Saving…" else if (fr) "Enregistrer la demande" else "Save request") }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(if (fr) "Historique des demandes" else "Request history", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (records.isEmpty()) item { Text(if (fr) "Aucune demande enregistrée." else "No requests recorded.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(records) { row ->
            val metadata = runCatching { JSONObject(row.metadataJson) }.getOrNull()
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(row.title, fontWeight = FontWeight.SemiBold)
                    Text(xaf(row.amountXaf) + " · " + row.status)
                    Text((if (fr) "Périodicité" else "Billing period") + " : " + (metadata?.optString("billingPeriod") ?: "—"))
                    Text((if (fr) "Date maturité" else "Maturity date") + " : " + (metadata?.optString("maturityEffectiveDate") ?: "2027-05-01"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}


@Composable
fun PurchasesContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val purchases by remember(siteId) {
        repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "purchase")
    }.collectAsState(initial = emptyList())
    val suppliers by remember(siteId) {
        repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "supplier")
    }.collectAsState(initial = emptyList())
    val inventory by remember(siteId) {
        repository.dao.observeInventoryItems(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())

    var supplier by rememberSaveable { mutableStateOf("") }
    var supplierPhone by rememberSaveable { mutableStateOf("") }
    var supplierDetails by rememberSaveable { mutableStateOf("") }
    var itemId by rememberSaveable { mutableStateOf("") }
    var quantity by rememberSaveable { mutableStateOf("1") }
    var unitCost by rememberSaveable { mutableStateOf("") }
    var deliveryDays by rememberSaveable { mutableStateOf("7") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val selectedItem = inventory.firstOrNull { it.id == itemId }
    val qty = quantity.replace(",", ".").toDoubleOrNull() ?: 0.0
    val cost = unitCost.toLongOrNull() ?: 0L
    val total = (qty * cost).takeIf { it.isFinite() && it <= Long.MAX_VALUE.toDouble() }?.toLong() ?: 0L

    fun nextPurchaseActions(status: String): List<Pair<String, String>> = when (status) {
        "open" -> listOf("ordered" to if (fr) "Valider la commande fournisseur" else "Place supplier order")
        "ordered" -> listOf("received" to if (fr) "Confirmer la réception complète" else "Confirm full receipt")
        "received" -> listOf("invoice_review" to if (fr) "Contrôler la facture fournisseur" else "Review supplier invoice")
        "invoice_review" -> listOf("closed" to if (fr) "Clôturer l'achat" else "Close purchase")
        else -> emptyList()
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                if (fr) "Achats, fournisseurs et réceptions" else "Purchases, suppliers and receiving",
                if (fr) "Un achat est rattaché à un site. La réception d'une ligne liée à un article augmente automatiquement son stock et crée un mouvement traçable." else "Each purchase belongs to a site. Receiving a line linked to an inventory item increases its stock and records an auditable movement."
            )
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it; itemId = "" }
            LocalOnlyNotice(if (fr) "Registres et réceptions locaux. Les commandes fournisseurs ne sont pas envoyées et les factures ne sont pas rapprochées automatiquement du serveur." else "Local purchase and receiving records. Orders are not sent to suppliers and invoices are not automatically reconciled with the server.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Fournisseurs du point de vente" else "Site suppliers", fontWeight = FontWeight.Bold)
                    if (suppliers.isEmpty()) Text(if (fr) "Aucun fournisseur enregistré." else "No suppliers registered.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    suppliers.take(12).forEach { row ->
                        Text(row.title + if (row.counterparty.isBlank()) "" else " · " + row.counterparty, style = MaterialTheme.typography.bodySmall)
                    }
                    OutlinedTextField(supplier, { supplier = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Nom du fournisseur" else "Supplier name") }, singleLine = true)
                    OutlinedTextField(supplierPhone, { supplierPhone = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Téléphone / contact" else "Phone / contact") }, singleLine = true)
                    OutlinedTextField(supplierDetails, { supplierDetails = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Adresse, activité ou conditions" else "Address, activity or terms") }, minLines = 2)
                    OutlinedButton(
                        onClick = {
                            if (supplier.isBlank()) error = if (fr) "Le nom du fournisseur est obligatoire." else "Supplier name is required."
                            else scope.launch {
                                busy = true
                                runCatching {
                                    repository.createManagementRecord(
                                        session.account.organizationId, siteId, "supplier",
                                        "SUP-" + System.currentTimeMillis(), supplier.trim(), supplierPhone.trim(),
                                        0, 0, null, "open",
                                        JSONObject().put("details", supplierDetails.trim()).toString(),
                                        session.account.memberId
                                    )
                                }.onSuccess {
                                    supplier = ""; supplierPhone = ""; supplierDetails = ""
                                    message = if (fr) "Fournisseur enregistré localement." else "Supplier saved locally."
                                    error = null
                                }.onFailure { error = it.message ?: "Supplier save failed." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && supplier.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (fr) "Ajouter le fournisseur" else "Add supplier") }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Nouvelle commande d'achat (une ligne d'article)" else "New purchase order (one stock item per order)", fontWeight = FontWeight.Bold)
                    OutlinedTextField(supplier, { supplier = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Fournisseur" else "Supplier") }, singleLine = true)
                    suppliers.take(20).forEach { row ->
                        OutlinedButton(onClick = { supplier = row.title }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (supplier == row.title) "✓ " + row.title else row.title)
                        }
                    }
                    Text(if (fr) "Article lié au stock" else "Link to stock item", fontWeight = FontWeight.SemiBold)
                    if (inventory.isEmpty()) {
                        Text(if (fr) "Crée d'abord un article dans le module Stock. Une réception sans article lié ne modifie pas le stock." else "Create an item in Stock first. An unlinked receipt will not change stock.")
                    } else {
                        inventory.forEach { stockItem ->
                            OutlinedButton(onClick = { itemId = stockItem.id }, modifier = Modifier.fillMaxWidth()) {
                                Text(if (itemId == stockItem.id) "✓ " + stockItem.name + " · " + stockItem.quantity + " " + stockItem.unit else stockItem.name + " · " + stockItem.quantity + " " + stockItem.unit)
                            }
                        }
                    }
                    OutlinedTextField(quantity, { quantity = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Quantité commandée" else "Quantity ordered") }, singleLine = true)
                    OutlinedTextField(unitCost, { unitCost = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Coût d'achat unitaire (FCFA)" else "Unit purchase cost (XAF)") }, singleLine = true)
                    OutlinedTextField(deliveryDays, { deliveryDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Livraison prévue dans (jours)" else "Expected delivery in days") }, singleLine = true)
                    Text((if (fr) "Total estimé : " else "Estimated total: ") + xaf(total), fontWeight = FontWeight.Bold)
                    Button(
                        onClick = {
                            if (supplier.isBlank() || selectedItem == null || !qty.isFinite() || qty <= 0 || cost <= 0 || total <= 0) {
                                error = if (fr) "Fournisseur, article, quantité et coût unitaire positifs requis." else "Supplier, stock item, quantity and positive unit cost are required."
                            } else scope.launch {
                                busy = true
                                runCatching {
                                    val metadata = JSONObject()
                                        .put("inventoryItemId", selectedItem.id)
                                        .put("inventorySku", selectedItem.sku)
                                        .put("quantity", qty)
                                        .put("unitCostXaf", cost)
                                        .put("supplier", supplier.trim())
                                        .put("receiptApplied", false)
                                        .toString()
                                    repository.createManagementRecord(
                                        session.account.organizationId, siteId, "purchase",
                                        "ACH-" + System.currentTimeMillis(), selectedItem.name, supplier.trim(),
                                        total, 0,
                                        System.currentTimeMillis() + (deliveryDays.toLongOrNull() ?: 7L).coerceIn(1L, 365L) * 86_400_000L,
                                        "open", metadata, session.account.memberId
                                    )
                                }.onSuccess {
                                    itemId = ""; quantity = "1"; unitCost = ""; deliveryDays = "7"
                                    message = if (fr) "Commande créée. La quantité ne sera ajoutée au stock qu'après réception confirmée." else "Order created. Quantity will be added to inventory only after receipt is confirmed."
                                    error = null
                                }.onFailure { error = it.message ?: "Purchase order failed." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && supplier.isNotBlank() && selectedItem != null && qty > 0 && cost > 0,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) if (fr) "Enregistrement…" else "Saving…" else if (fr) "Créer la commande" else "Create purchase order") }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(if (fr) "Commandes et réceptions" else "Orders and receipts", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (purchases.isEmpty()) item { Text(if (fr) "Aucune commande." else "No purchase orders.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(purchases) { item ->
            val events by remember(item.id, siteId) {
                repository.dao.observeWorkflowEvents(session.account.organizationId, siteId, "purchase", item.id)
            }.collectAsState(initial = emptyList())
            var reason by rememberSaveable(item.id) { mutableStateOf("") }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(item.reference + " · " + item.title, fontWeight = FontWeight.Bold)
                    Text(item.counterparty)
                    Text(xaf(item.amountXaf) + " · " + item.status)
                    Text((if (fr) "Réception prévue : " else "Expected delivery: ") + (item.dueAtMillis?.let { java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(it)) } ?: "—"))
                    if (item.status !in setOf("closed", "cancelled")) {
                        OutlinedTextField(reason, { reason = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Motif / référence de réception" else "Reason / receipt reference") })
                        nextPurchaseActions(item.status).forEach { (nextStatus, label) ->
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(session.account.organizationId, siteId, item.id, nextStatus, reason, session.account.memberId)
                                        }.onSuccess {
                                            reason = ""
                                            message = if (nextStatus == "received") {
                                                if (fr) "Réception confirmée : le stock du site a été augmenté et le mouvement journalisé." else "Receipt confirmed: site inventory was increased and the movement recorded."
                                            } else if (fr) "Étape d'achat mise à jour." else "Purchase stage updated."
                                        }.onFailure { error = it.message ?: "Purchase transition failed." }
                                    }
                                },
                                enabled = reason.trim().length >= 3,
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(label) }
                        }
                    }
                    events.take(4).forEach { event ->
                        Text(event.fromStatus + " → " + event.toStatus + " · " + event.reason, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
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
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) { repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "business_goal") }.collectAsState(initial = emptyList())
    val calendar = remember { Calendar.getInstance() }
    val start = remember { (calendar.clone() as Calendar).apply { set(Calendar.HOUR_OF_DAY,0); set(Calendar.MINUTE,0); set(Calendar.SECOND,0); set(Calendar.MILLISECOND,0) }.timeInMillis }
    val end = start + 86_400_000L
    val sales by remember(siteId,start) { repository.dao.observeSalesTotal(session.account.organizationId, siteId, start, end) }.collectAsState(initial = 0L)
    var title by rememberSaveable { mutableStateOf("Objectif de chiffre d’affaires du jour") }
    var target by rememberSaveable { mutableStateOf("") }
    var period by rememberSaveable { mutableStateOf("daily") }
    var notice by remember { mutableStateOf<String?>(null) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Pilotage et objectifs", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Objectifs datés, réalisé, écart et historique des décisions. La cible enregistrée n’est pas réécrite rétroactivement.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Les objectifs et réalisés visibles ici sont issus du stockage local de ce site.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Réalisation aujourd’hui : " + xaf(sales), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("Objectif") })
                    OutlinedTextField(target, { target = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Cible (FCFA)") })
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("daily", "weekly", "monthly").forEach { value -> OutlinedButton(onClick = { period = value }) { Text(if (period == value) "✓ " + value else value) } }
                    }
                    val goal = target.toLongOrNull() ?: 0L
                    val ratio = if (goal > 0) (sales.toDouble() / goal.toDouble()).coerceIn(0.0,1.0).toFloat() else 0f
                    androidx.compose.material3.LinearProgressIndicator(progress = ratio, modifier = Modifier.fillMaxWidth())
                    Text(if (goal > 0) "Atteinte : " + (ratio * 100).toInt() + " % · Écart : " + xaf(goal - sales) else "Saisis une cible pour suivre l’atteinte.")
                    Button(onClick = {
                        if (goal <= 0 || title.isBlank()) notice = "Un objectif et une cible positive sont requis."
                        else scope.launch {
                            runCatching { repository.createManagementRecord(session.account.organizationId, siteId, "business_goal", "OBJ-" + System.currentTimeMillis(), title, period, goal, 0, null, "open", "{\"period\":\"" + period + "\",\"baseline\":\"approved_at_creation\"}", session.account.memberId) }
                                .onSuccess { target = ""; notice = "Objectif enregistré avec date et auteur." }
                                .onFailure { notice = it.message ?: "Enregistrement impossible." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("Fixer l’objectif") }
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text("Objectifs enregistrés", fontWeight = FontWeight.Bold) }
        items(records) { Text(it.title + " · " + it.counterparty + " · " + xaf(it.amountXaf), color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
fun AiInsightsContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
    val now = System.currentTimeMillis()
    val start = now - 30L * 86_400_000L
    val sales by remember(siteId,start) { repository.dao.observeSalesTotal(session.account.organizationId, siteId, start, now) }.collectAsState(initial = 0L)
    val expenses by remember(siteId,start) { repository.dao.observeExpensesTotal(session.account.organizationId, siteId, start, now) }.collectAsState(initial = 0L)
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Assistant de gestion", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Indicateurs déterministes calculés à partir des données locales. Les prédictions avancées et l’assistant IA distant nécessitent encore un moteur IA, un contexte sécurisé et des données synchronisées.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Synthèse locale — 30 derniers jours", fontWeight = FontWeight.Bold)
                    Text("Ventes confirmées : " + xaf(sales))
                    Text("Dépenses enregistrées : " + xaf(expenses))
                    Text("Solde simplifié avant coûts de stock, commissions, taxes et charges non saisies : " + xaf(sales - expenses), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp)) {
                    Text("Contrôles à effectuer", fontWeight = FontWeight.Bold)
                    Text("• Rapprocher les paiements Mobile Money en attente.")
                    Text("• Comparer les dépenses et achats avec les justificatifs.")
                    Text("• Vérifier les articles proches du seuil minimum.")
                    Text("• Contrôler les objectifs et les échéances clients.")
                    Text("Ces pistes sont des règles de contrôle, pas des prédictions générées par un modèle entraîné.")
                }
            }
        }
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
    var photoUri by rememberSaveable(session.account.memberId) { mutableStateOf(preferences.profilePhoto(session.account.memberId)) }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            runCatching { context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            photoUri = uri.toString()
            preferences.saveProfilePhoto(session.account.memberId, uri.toString())
        }
    }
    val profileBitmap: Bitmap? = remember(photoUri) {
        photoUri?.let { value ->
            runCatching { context.contentResolver.openInputStream(Uri.parse(value))?.use { stream -> BitmapFactory.decodeStream(stream) } }.getOrNull()
        }
    }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Profil", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    if (profileBitmap != null) {
                        Image(profileBitmap.asImageBitmap(), contentDescription = "Photo de profil", modifier = Modifier.size(88.dp), contentScale = ContentScale.Crop)
                    } else {
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
            OutlinedButton(onClick = { showReferralScreen = true }, modifier = Modifier.fillMaxWidth()) { Text("Parrainage et suivi de mes gains") }
            OutlinedButton(onClick = { showLoyaltyScreen = true }, modifier = Modifier.fillMaxWidth()) { Text("Programme de fidélité") }
            OutlinedButton(onClick = { onNavigate(AppRoute.CHARGES) }, modifier = Modifier.fillMaxWidth()) { Text("Charges et échéances de paiement") }
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
    val sites = session.account.activeSiteIds
    val fr = session.account.defaultLocale != "en"
    var siteId by rememberSaveable { mutableStateOf(sites.firstOrNull().orEmpty()) }
    val profile = activityProfile ?: "autre"
    val profileTitle = when (profile) {
        "pressing" -> if (fr) "Pressing" else "Laundry"
        "coiffure" -> if (fr) "Coiffure" else "Hair salon"
        "couture" -> if (fr) "Couture" else "Tailoring"
        "beaute" -> if (fr) "Beauté / soins" else "Beauty / treatments"
        "parfumerie" -> if (fr) "Parfumerie" else "Perfume retail"
        "reparation" -> if (fr) "Réparation" else "Repair"
        "menuiserie" -> if (fr) "Menuiserie" else "Carpentry"
        "garage" -> if (fr) "Garage" else "Garage"
        "nettoyage" -> if (fr) "Nettoyage" else "Cleaning"
        "domicile" -> if (fr) "Services à domicile" else "Home services"
        "impression" -> if (fr) "Imprimerie" else "Printing"
        "photo_evenementiel" -> if (fr) "Photo / événementiel" else "Photography / events"
        else -> if (fr) "Services" else "Services"
    }
    val recordType = when (profile) {
        "reparation", "garage" -> "repair_order"
        "domicile", "nettoyage", "photo_evenementiel" -> "service_order"
        else -> "work_order"
    }
    val records by remember(siteId, recordType) {
        repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, recordType)
    }.collectAsState(initial = emptyList())
    val workstations by remember(siteId) {
        repository.dao.observeWorkstations(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())

    val labels = when (profile) {
        "couture" -> listOf(
            if (fr) "Vêtement / retouche / commande" else "Garment / alteration / order",
            if (fr) "Mensurations, tissu et essayage" else "Measurements, fabric and fitting",
            if (fr) "Tissu, fournitures et accessoires" else "Fabric, supplies and accessories",
            if (fr) "Date d'essayage ou de livraison" else "Fitting or delivery date"
        )
        "beaute" -> listOf(
            if (fr) "Soin / formule / cabine" else "Treatment / package / room",
            if (fr) "Produits, protocole et consignes" else "Products, procedure and instructions",
            if (fr) "Produits et consommables" else "Products and consumables",
            if (fr) "Date de prestation" else "Service date"
        )
        "coiffure" -> listOf(
            if (fr) "Style / prestation / fauteuil" else "Style / service / chair",
            if (fr) "Technique, longueur et consignes" else "Technique, length and instructions",
            if (fr) "Produits et accessoires" else "Products and accessories",
            if (fr) "Date de prestation" else "Service date"
        )
        "parfumerie" -> listOf(
            if (fr) "Produit / format / coffret" else "Product / size / gift set",
            if (fr) "Référence fournisseur, lot ou conditionnement" else "Supplier reference, batch or packaging",
            if (fr) "Approvisionnement ou présentation" else "Supply or display details",
            if (fr) "Date attendue" else "Expected date"
        )
        "reparation" -> listOf(
            if (fr) "Appareil / marque / modèle / série" else "Device / make / model / serial",
            if (fr) "Panne constatée et diagnostic" else "Reported fault and diagnosis",
            if (fr) "Pièces et composants nécessaires" else "Required parts and components",
            if (fr) "Date de restitution" else "Return date"
        )
        "menuiserie" -> listOf(
            if (fr) "Meuble / ouvrage / chantier" else "Furniture / workpiece / project",
            if (fr) "Dimensions, plan et finition" else "Dimensions, plan and finish",
            if (fr) "Bois, panneaux et quincaillerie" else "Timber, panels and hardware",
            if (fr) "Date de pose ou livraison" else "Installation or delivery date"
        )
        "garage" -> listOf(
            if (fr) "Véhicule / marque / modèle / immatriculation" else "Vehicle / make / model / registration",
            if (fr) "Intervention, panne ou travaux" else "Repair, fault or work requested",
            if (fr) "Pièces et consommables" else "Parts and consumables",
            if (fr) "Date de restitution" else "Return date"
        )
        "nettoyage" -> listOf(
            if (fr) "Site du contrat / zone à nettoyer" else "Contract site / cleaning zone",
            if (fr) "Tâches, fréquence et niveau de service" else "Tasks, frequency and service level",
            if (fr) "Produits, matériel et équipe" else "Products, equipment and team",
            if (fr) "Date ou prochaine intervention" else "Date or next intervention"
        )
        "domicile" -> listOf(
            if (fr) "Adresse d'intervention / quartier" else "Service address / neighborhood",
            if (fr) "Prestation, accès et consignes" else "Service, access and instructions",
            if (fr) "Matériel et technicien demandé" else "Equipment and requested technician",
            if (fr) "Date de visite" else "Visit date"
        )
        "impression" -> listOf(
            if (fr) "Format / support / quantité" else "Format / media / quantity",
            if (fr) "Couleurs, finition et épreuve" else "Colors, finishing and proof",
            if (fr) "Papier, encre et consommables" else "Paper, ink and consumables",
            if (fr) "Date de retrait" else "Pickup date"
        )
        "photo_evenementiel" -> listOf(
            if (fr) "Événement / lieu / organisateur" else "Event / venue / organizer",
            if (fr) "Forfait, livrables et durée" else "Package, deliverables and duration",
            if (fr) "Matériel et équipe" else "Equipment and crew",
            if (fr) "Date de l'événement" else "Event date"
        )
        "pressing" -> listOf(
            if (fr) "Lot textile / type de vêtement" else "Laundry batch / garment type",
            if (fr) "Détail des pièces, traitement et précautions" else "Items, treatment and care instructions",
            if (fr) "Lessive, détachant et consommables" else "Detergent, stain remover and consumables",
            if (fr) "Date promise de retrait" else "Promised pickup date"
        )
        else -> listOf(
            if (fr) "Prestation / commande / référence" else "Service / order / reference",
            if (fr) "Description et spécifications" else "Description and specifications",
            if (fr) "Matériel ou consommables nécessaires" else "Required equipment or consumables",
            if (fr) "Date d'échéance" else "Due date"
        )
    }

    var workstationId by rememberSaveable { mutableStateOf("") }
    var customer by rememberSaveable { mutableStateOf("") }
    var title by rememberSaveable { mutableStateOf("") }
    var specificPrimary by rememberSaveable { mutableStateOf("") }
    var specifications by rememberSaveable { mutableStateOf("") }
    var materials by rememberSaveable { mutableStateOf("") }
    var assignedStaff by rememberSaveable { mutableStateOf("") }
    var estimate by rememberSaveable { mutableStateOf("") }
    var deposit by rememberSaveable { mutableStateOf("0") }
    var dueDays by rememberSaveable { mutableStateOf("3") }
    var transitionReason by rememberSaveable { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    fun transitions(status: String): List<Pair<String, String>> {
        val stages: Map<String, Set<String>> = when (profile) {
            "couture" -> mapOf(
                "received" to setOf("measurement", "diagnostic"), "open" to setOf("measurement", "diagnostic"),
                "measurement" to setOf("quote_pending"), "diagnostic" to setOf("quote_pending"),
                "quote_pending" to setOf("waiting_customer", "approved"),
                "waiting_customer" to setOf("approved"), "approved" to setOf("waiting_parts", "in_progress"),
                "waiting_parts" to setOf("in_progress"), "in_progress" to setOf("fitting", "quality_check"),
                "fitting" to setOf("in_progress", "quality_check"), "quality_check" to setOf("fitting", "ready"),
                "ready" to setOf("delivered"), "delivered" to setOf("closed")
            )
            "menuiserie" -> mapOf(
                "received" to setOf("diagnostic", "quote_pending"), "open" to setOf("diagnostic", "quote_pending"),
                "diagnostic" to setOf("quote_pending"), "quote_pending" to setOf("waiting_customer", "approved"),
                "waiting_customer" to setOf("approved"), "approved" to setOf("waiting_parts", "fabrication"),
                "waiting_parts" to setOf("fabrication"), "fabrication" to setOf("quality_check"),
                "quality_check" to setOf("fabrication", "installation", "ready"),
                "installation" to setOf("ready"), "ready" to setOf("delivered"), "delivered" to setOf("closed")
            )
            "impression" -> mapOf(
                "received" to setOf("quote_pending", "proof_ready"), "open" to setOf("quote_pending", "proof_ready"),
                "quote_pending" to setOf("waiting_customer", "proof_ready"),
                "waiting_customer" to setOf("approved"), "proof_ready" to setOf("approved", "in_progress"),
                "approved" to setOf("production"), "production" to setOf("quality_check"),
                "quality_check" to setOf("production", "ready"), "ready" to setOf("delivered"), "delivered" to setOf("closed")
            )
            "domicile", "nettoyage" -> mapOf(
                "received" to setOf("quote_pending", "approved"), "open" to setOf("quote_pending", "approved"),
                "quote_pending" to setOf("waiting_customer", "approved"), "waiting_customer" to setOf("approved"),
                "approved" to setOf("planning", "on_site"), "planning" to setOf("on_site"),
                "on_site" to setOf("in_progress"), "in_progress" to setOf("quality_check"),
                "quality_check" to setOf("in_progress", "ready"), "ready" to setOf("delivered"), "delivered" to setOf("closed")
            )
            "photo_evenementiel" -> mapOf(
                "received" to setOf("quote_pending", "planning"), "open" to setOf("quote_pending", "planning"),
                "quote_pending" to setOf("waiting_customer", "approved"), "waiting_customer" to setOf("approved"),
                "approved" to setOf("planning"), "planning" to setOf("shooting"),
                "shooting" to setOf("post_production"), "post_production" to setOf("quality_check"),
                "quality_check" to setOf("post_production", "ready"), "ready" to setOf("delivered"), "delivered" to setOf("closed")
            )
            else -> emptyMap()
        }
        val statuses = stages[status] ?: when (status) {
            "received", "open" -> setOf("diagnostic", "quote_pending", "in_progress", "cancelled")
            "diagnostic" -> setOf("quote_pending", "awaiting_approval", "in_progress", "cancelled")
            "quote_pending" -> setOf("waiting_customer", "approved", "cancelled")
            "waiting_customer", "awaiting_approval" -> setOf("approved", "cancelled")
            "approved" -> setOf("waiting_parts", "in_progress")
            "waiting_parts" -> setOf("in_progress")
            "in_progress" -> setOf("quality_check", "ready")
            "quality_check" -> setOf("in_progress", "ready")
            "ready" -> setOf("delivered")
            "delivered" -> setOf("closed")
            else -> emptySet()
        }
        val label = mapOf(
            "measurement" to if (fr) "Prendre les mensurations" else "Measure",
            "diagnostic" to if (fr) "Diagnostiquer" else "Diagnose",
            "quote_pending" to if (fr) "Préparer le devis" else "Prepare quote",
            "waiting_customer" to if (fr) "Attendre le client" else "Await customer",
            "approved" to if (fr) "Accord reçu" else "Approval received",
            "waiting_parts" to if (fr) "Attendre les pièces" else "Await parts",
            "fabrication" to if (fr) "Lancer la fabrication" else "Start fabrication",
            "fitting" to if (fr) "Essayage" else "Fitting",
            "proof_ready" to if (fr) "Épreuve prête" else "Proof ready",
            "production" to if (fr) "Démarrer la production" else "Start production",
            "planning" to if (fr) "Planifier l'intervention" else "Plan intervention",
            "on_site" to if (fr) "Équipe sur site" else "Team on site",
            "shooting" to if (fr) "Prise de vue" else "Photo / video session",
            "post_production" to if (fr) "Post-production" else "Post-production",
            "in_progress" to if (fr) "Démarrer / reprendre" else "Start / resume",
            "quality_check" to if (fr) "Contrôle qualité" else "Quality check",
            "ready" to if (fr) "Valider prêt" else "Approve ready",
            "installation" to if (fr) "Installer / poser" else "Install",
            "delivered" to if (fr) "Remis au client" else "Delivered",
            "closed" to if (fr) "Clôturer" else "Close",
            "cancelled" to if (fr) "Annuler" else "Cancel",
            "awaiting_approval" to if (fr) "Attendre accord client" else "Await approval"
        )
        return statuses.map { it to (label[it] ?: it) }
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                (if (fr) "Ordres de travail — " else "Work orders — ") + profileTitle,
                if (fr) "Dossiers métier, devis, affectations, étapes de production et remise client. Chaque dossier reste rattaché à son site d'origine." else "Activity-specific jobs, quotes, assignments, production stages and handover. Each job remains bound to its source site."
            )
            AuthorizedSitePicker(
                sites, siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it; workstationId = "" }
            LocalOnlyNotice(if (fr) "Dossiers locaux en attente de synchronisation. Les encaissements et décisions fiscales ne sont jamais validés par cette fiche." else "Local records pending synchronization. Cash receipts and tax decisions are never approved by this form.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Nouveau dossier" else "New work order", fontWeight = FontWeight.Bold)
                    Text(if (fr) "Emplacement / poste (facultatif — le registre reste consolidé au niveau du site)" else "Workstation (optional — site ledger remains consolidated)", fontWeight = FontWeight.SemiBold)
                    OutlinedButton(onClick = { workstationId = "" }, modifier = Modifier.fillMaxWidth()) {
                        Text(if (workstationId.isBlank()) (if (fr) "✓ Aucun poste dédié" else "✓ No dedicated workstation") else if (fr) "Aucun poste dédié" else "No dedicated workstation")
                    }
                    workstations.filter { it.status == "active" }.forEach { workstation ->
                        OutlinedButton(onClick = { workstationId = workstation.id }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (workstationId == workstation.id) "✓ " else "") + workstation.name + " · " + workstation.kind)
                        }
                    }
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Client" else "Customer") }, singleLine = true)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Titre du dossier" else "Work order title") }, singleLine = true)
                    OutlinedTextField(specificPrimary, { specificPrimary = it }, Modifier.fillMaxWidth(), label = { Text(labels[0]) }, singleLine = true)
                    OutlinedTextField(specifications, { specifications = it }, Modifier.fillMaxWidth(), label = { Text(labels[1]) }, minLines = 2)
                    OutlinedTextField(materials, { materials = it }, Modifier.fillMaxWidth(), label = { Text(labels[2]) }, minLines = 2)
                    OutlinedTextField(assignedStaff, { assignedStaff = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Collaborateur / prestataire affecté" else "Assigned staff / provider") }, singleLine = true)
                    OutlinedTextField(estimate, { estimate = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Devis estimatif (FCFA)" else "Estimated quote (XAF)") }, singleLine = true)
                    OutlinedTextField(deposit, { deposit = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Acompte demandé (FCFA)" else "Deposit requested (XAF)") }, singleLine = true)
                    OutlinedTextField(dueDays, { dueDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Délai estimé en jours" else "Estimated days") }, singleLine = true)
                    Button(
                        onClick = {
                            val amount = estimate.toLongOrNull() ?: 0L
                            val paid = deposit.toLongOrNull() ?: 0L
                            if (customer.isBlank() || title.isBlank() || amount <= 0 || paid > amount) {
                                error = if (fr) "Client, titre et devis positif requis. L'acompte ne peut pas dépasser le devis." else "Customer, title and positive quote are required. Deposit cannot exceed quote."
                            } else scope.launch {
                                busy = true
                                runCatching {
                                    val metadata = JSONObject()
                                        .put("activity", profile)
                                        .put("primaryDetail", specificPrimary.trim())
                                        .put("specifications", specifications.trim())
                                        .put("materials", materials.trim())
                                        .put("assignedStaffLabel", assignedStaff.trim())
                                        .put("depositXaf", paid)
                                        .put("workflowVersion", 1)
                                        .toString()
                                    repository.createManagementRecord(
                                        session.account.organizationId, siteId, recordType,
                                        (if (recordType == "repair_order") "REP-" else if (recordType == "service_order") "SRV-" else "WO-") + System.currentTimeMillis(),
                                        title.trim(), customer.trim(), amount, paid,
                                        System.currentTimeMillis() + (dueDays.toLongOrNull() ?: 3L).coerceIn(1L, 365L) * 86_400_000L,
                                        "received", metadata, session.account.memberId,
                                        workstationId.takeIf { it.isNotBlank() }
                                    )
                                }.onSuccess {
                                    customer = ""; title = ""; specificPrimary = ""; specifications = ""
                                    materials = ""; assignedStaff = ""; estimate = ""; deposit = "0"
                                    error = null
                                    message = if (fr) "Dossier enregistré. Statut initial : reçu." else "Work order saved. Initial status: received."
                                }.onFailure { error = it.message ?: if (fr) "Création impossible." else "Unable to create work order." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && customer.isNotBlank() && title.isNotBlank() && (estimate.toLongOrNull() ?: 0L) > 0,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) if (fr) "Enregistrement…" else "Saving…" else if (fr) "Créer le dossier" else "Create work order") }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(if (fr) "Dossiers du point de vente" else "Site work orders", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (records.isEmpty()) item { Text(if (fr) "Aucun dossier enregistré." else "No work orders yet.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(records) { item ->
            val events by remember(item.id, siteId) {
                repository.dao.observeWorkflowEvents(session.account.organizationId, siteId, item.recordType, item.id)
            }.collectAsState(initial = emptyList())
            var reason by rememberSaveable(item.id) { mutableStateOf("") }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(item.reference + " · " + item.title, fontWeight = FontWeight.Bold)
                    Text(item.counterparty)
                    item.workstationId?.let { id ->
                        Text(workstations.firstOrNull { it.id == id }?.name ?: id, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                    Text(labels[0] + " : " + (runCatching { JSONObject(item.metadataJson).optString("primaryDetail") }.getOrDefault("")))
                    Text((if (fr) "Devis" else "Quote") + " : " + xaf(item.amountXaf) + " · " + (if (fr) "Acompte" else "Deposit") + " : " + xaf(item.paidXaf))
                    Text((if (fr) "Statut" else "Status") + " : " + item.status, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    Text((if (fr) "Échéance" else "Due") + " : " + (item.dueAtMillis?.let { java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(it)) } ?: "—"))
                    if (item.status !in setOf("closed", "cancelled")) {
                        OutlinedTextField(reason, { reason = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Motif obligatoire pour changer l'étape" else "Reason required for status change") }, minLines = 1)
                        transitions(item.status).forEach { (status, label) ->
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(session.account.organizationId, siteId, item.id, status, reason, session.account.memberId)
                                        }.onSuccess { reason = ""; message = if (fr) "Étape mise à jour et journalisée." else "Workflow stage updated and audited." }
                                            .onFailure { error = it.message ?: if (fr) "Transition impossible." else "Transition failed." }
                                    }
                                },
                                enabled = reason.trim().length >= 3,
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(label) }
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
    val now = System.currentTimeMillis()
    val monthStart = Calendar.getInstance().apply {
        set(Calendar.DAY_OF_MONTH, 1); set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis
    val monthEnd = Calendar.getInstance().apply {
        set(Calendar.DAY_OF_MONTH, getActualMaximum(Calendar.DAY_OF_MONTH)); set(Calendar.HOUR_OF_DAY, 23); set(Calendar.MINUTE, 59); set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999)
    }.timeInMillis
    var monthSales by remember { mutableStateOf(0L) }
    LaunchedEffect(orgId, siteIds, monthStart) {
        monthSales = siteIds.sumOf { id ->
            repository.dao.observeSalesTotal(orgId, id, monthStart, monthEnd).first()
        }
    }
    val monthFixedCharges = payments.filter { it.paidAtMillis in monthStart..monthEnd }.sumOf { it.amountXaf }
    val due = charges.filter { it.active && it.nextDueAtMillis <= now + it.reminderDays * 86_400_000L }
    val fmt = java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault())

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Charges, échéances et trésorerie", "Configure les dépenses récurrentes, suis les règlements et anticipe les dates de paiement.")
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Les rappels sont calculés à partir des échéances enregistrées sur cet appareil. La synchronisation multi-appareils et les notifications serveur restent dépendantes du backend.")
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
