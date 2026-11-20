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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalManagementRecord
import cm.naxa.naxaservices.data.LocalSale
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
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
    val siteId = "ORG_SCOPE"
    val records by remember(session.account.organizationId) { repository.dao.observeOrganizationManagementRecordsByType(session.account.organizationId, "subscription_request") }.collectAsState(initial = emptyList())
    var reference by rememberSaveable { mutableStateOf("") }
    var plan by rememberSaveable { mutableStateOf("Pro") }
    var message by remember { mutableStateOf<String?>(null) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Abonnement et droits de l’organisation", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Le Promoteur de l’organisation mère porte l’abonnement. Les sites et postes héritent des droits et quotas autorisés par le contrat.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            LocalOnlyNotice("Aucune transaction ni entitlement n’est activé par cet écran tant que la passerelle de paiement et la vérification serveur ne sont pas raccordées.")
        }
        item {
            listOf("Essentiel" to "Démarrage d’une PME et fonctions essentielles", "Pro" to "Équipe, agenda, pilotage et rapports enrichis", "Réseau" to "Plusieurs points de vente autonomes et consolidation").forEach { row ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(14.dp)) {
                        Text(row.first, fontWeight = FontWeight.Bold)
                        Text(row.second, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        OutlinedButton(onClick = { plan = row.first }) { Text(if (plan == row.first) "✓ Sélectionné" else "Choisir") }
                    }
                }
            }
            Text("Les anciens montants tarifaires du cahier sont des propositions, pas un catalogue commercial approuvé. Aucun droit n’est activé par une simple saisie de référence.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Demande de souscription / renouvellement", fontWeight = FontWeight.Bold)
                    OutlinedTextField(reference, { reference = it }, Modifier.fillMaxWidth(), label = { Text("Référence de paiement (facultative)") }, singleLine = true)
                    Button(onClick = {
                        scope.launch {
                            runCatching {
                                repository.createManagementRecord(
                                    session.account.organizationId, siteId, "subscription_request",
                                    "SUB-" + System.currentTimeMillis(), "Demande de formule " + plan,
                                    session.account.organizationName, 0, 0, null, "pending_review",
                                    "{\"plan\":\"" + plan + "\",\"payment_reference\":\"" + reference.take(80) + "\"}",
                                    session.account.memberId
                                )
                            }.onSuccess { message = "Demande enregistrée en attente de rapprochement. L’abonnement n’est pas activé." }
                                .onFailure { message = it.message ?: "Demande impossible." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("Enregistrer ma demande") }
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text("Demandes locales", fontWeight = FontWeight.Bold) }
        items(records) { Text(it.title + " · " + it.status, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
fun PurchasesContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) { repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "purchase") }.collectAsState(initial = emptyList())
    var supplier by rememberSaveable { mutableStateOf("") }
    var details by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("") }
    var notice by remember { mutableStateOf<String?>(null) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Achats et fournisseurs", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Préparez les commandes, suivez les coûts d’approvisionnement et rattachez les pièces à leur site d’origine.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice()
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(supplier, { supplier = it }, Modifier.fillMaxWidth(), label = { Text("Fournisseur") })
                    OutlinedTextField(details, { details = it }, Modifier.fillMaxWidth(), label = { Text("Articles / détail de la commande") })
                    OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Coût estimé (FCFA)") })
                    Button(onClick = {
                        val value = amount.toLongOrNull() ?: 0L
                        if (supplier.isBlank() || details.isBlank() || value <= 0) { notice = "Fournisseur, détail et montant requis." }
                        else scope.launch {
                            runCatching { repository.createManagementRecord(session.account.organizationId, siteId, "purchase", "ACH-" + System.currentTimeMillis(), details, supplier, value, 0, null, "open", "{\"kind\":\"local_purchase_order\"}", session.account.memberId) }
                                .onSuccess { supplier = ""; details = ""; amount = ""; notice = "Commande d’achat enregistrée localement." }
                                .onFailure { notice = it.message ?: "Échec de l’enregistrement." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("Enregistrer l’achat") }
                    if (notice != null) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text("Commandes et achats", fontWeight = FontWeight.Bold) }
        items(records) { item ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(14.dp)) { Text(item.title, fontWeight = FontWeight.Bold); Text(item.counterparty); Text(xaf(item.amountXaf) + " · " + item.status) }
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
    activityProfile: String?,
    repository: NaxaServicesLocalRepository,
    preferences: NaxaServicesPreferences,
    onNavigate: (AppRoute) -> Unit,
    onLogout: () -> Unit
) {
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
    var siteId by rememberSaveable { mutableStateOf(sites.firstOrNull().orEmpty()) }
    val records by remember(siteId) {
        repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "work_order")
    }.collectAsState(initial = emptyList())
    var customer by rememberSaveable { mutableStateOf("") }
    var title by rememberSaveable { mutableStateOf("") }
    var materials by rememberSaveable { mutableStateOf("") }
    var estimate by rememberSaveable { mutableStateOf("") }
    var dueDays by rememberSaveable { mutableStateOf("3") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val business = NaxaActivityCatalog.find(activityProfile)
    val businessName = business?.titleFr ?: "Atelier / services"

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Ordres de travail", "Devis, dossiers clients, matières ou pièces, délai et suivi des étapes pour $businessName.")
            AuthorizedSitePicker(
                sites, siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it }
            LocalOnlyNotice("Dossier préparé sur cet appareil. Le serveur et la synchronisation métier restent à valider.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Nouveau dossier de travail", fontWeight = FontWeight.Bold)
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text("Client") }, singleLine = true)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("Prestation / réparation / fabrication") }, singleLine = true)
                    OutlinedTextField(materials, { materials = it }, Modifier.fillMaxWidth(), label = { Text("Matières, pièces ou éléments nécessaires") }, minLines = 2)
                    OutlinedTextField(estimate, { estimate = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Devis estimatif (FCFA)") }, singleLine = true)
                    OutlinedTextField(dueDays, { dueDays = it.filter(Char::isDigit).take(3) }, Modifier.fillMaxWidth(), label = { Text("Délai estimé (jours)") }, singleLine = true)
                    Button(onClick = {
                        val amount = estimate.toLongOrNull() ?: 0L
                        if (customer.isBlank() || title.isBlank() || amount <= 0) {
                            error = "Le client, la description et un devis positif sont requis."
                        } else scope.launch {
                            runCatching {
                                repository.createManagementRecord(
                                    session.account.organizationId, siteId, "work_order",
                                    "WO-" + System.currentTimeMillis(), title, customer,
                                    amount, 0,
                                    System.currentTimeMillis() + (dueDays.toLongOrNull() ?: 0L) * 86_400_000L,
                                    "open",
                                    "{\"activity\":\"" + (activityProfile ?: "autre") + "\",\"materials\":\"" + materials.replace("\"", "'").take(500) + "\",\"stage\":\"received\"}",
                                    session.account.memberId
                                )
                            }.onSuccess {
                                customer = ""; title = ""; materials = ""; estimate = ""; error = null
                                message = "Ordre de travail créé localement."
                            }.onFailure { error = it.message ?: "Création impossible." }
                        }
                    }, enabled = siteId.isNotBlank() && customer.isNotBlank() && title.isNotBlank() && (estimate.toLongOrNull() ?: 0L) > 0, modifier = Modifier.fillMaxWidth()) {
                        Text("Créer le dossier")
                    }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text("Dossiers du point de vente", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(records) { item ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(item.reference + " · " + item.title, fontWeight = FontWeight.Bold)
                    Text(item.counterparty)
                    Text("Devis : " + item.amountXaf + " FCFA · " + item.status)
                    Text("Délai : " + (item.dueAtMillis?.let { java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(it)) } ?: "Non défini"),
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        if (records.isEmpty()) item { Text("Aucun dossier enregistré sur ce point de vente.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val records by remember(siteId) { repository.dao.observeManagementRecords(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    var staff by rememberSaveable { mutableStateOf("") }
    var detail by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("") }
    var operation by rememberSaveable { mutableStateOf("staff_clock_in") }
    var message by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    val attendance = records.filter { it.recordType in setOf("staff_clock_in", "staff_clock_out", "staff_break_start", "staff_break_end") }
    val payroll = records.filter { it.recordType in setOf("staff_commission", "staff_advance", "staff_bonus") }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Présences, horaires et rémunérations variables", "Prise et fin de service, pauses, commissions par prestation, avances et primes.")
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) { siteId = it }
            LocalOnlyNotice("Ces événements sont journalisés localement par site. La validation et la synchronisation serveur restent à tester.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Pointage et mouvements d’équipe", fontWeight = FontWeight.Bold)
                    OutlinedTextField(staff, { staff = it }, Modifier.fillMaxWidth(), label = { Text("Collaborateur") }, singleLine = true)
                    listOf(
                        "staff_clock_in" to "Prise de service",
                        "staff_break_start" to "Début de pause",
                        "staff_break_end" to "Fin de pause",
                        "staff_clock_out" to "Fin de service"
                    ).forEach { (value, label) ->
                        OutlinedButton(onClick = { operation = value }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (operation == value) "✓ $label" else label)
                        }
                    }
                    Button(onClick = {
                        if (staff.isBlank() || siteId.isBlank()) error = "Choisis un collaborateur et un point de vente."
                        else scope.launch {
                            runCatching {
                                repository.createManagementRecord(
                                    session.account.organizationId, siteId, operation,
                                    "TIME-" + System.currentTimeMillis(), operation, staff,
                                    0, 0, null, "open",
                                    "{\"event\":\"" + operation + "\",\"recorded_local\":\"true\"}",
                                    session.account.memberId
                                )
                            }.onSuccess { message = "Événement d’horaire enregistré."; error = null }
                                .onFailure { error = it.message ?: "Pointage impossible." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("Enregistrer le pointage") }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Commission, avance ou prime", fontWeight = FontWeight.Bold)
                    OutlinedTextField(staff, { staff = it }, Modifier.fillMaxWidth(), label = { Text("Collaborateur") }, singleLine = true)
                    OutlinedTextField(detail, { detail = it }, Modifier.fillMaxWidth(), label = { Text("Prestation / motif") }, singleLine = true)
                    OutlinedTextField(amount, { amount = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Montant (FCFA)") }, singleLine = true)
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        listOf("staff_commission" to "Commission", "staff_advance" to "Avance", "staff_bonus" to "Prime").forEach { (value, label) ->
                            OutlinedButton(onClick = { operation = value }) { Text(if (operation == value) "✓ $label" else label) }
                        }
                    }
                    Button(onClick = {
                        val value = amount.toLongOrNull() ?: 0L
                        if (staff.isBlank() || detail.isBlank() || value <= 0 || siteId.isBlank()) error = "Collaborateur, motif et montant positif requis."
                        else scope.launch {
                            runCatching {
                                repository.createManagementRecord(
                                    session.account.organizationId, siteId, operation,
                                    "STAFF-" + System.currentTimeMillis(), detail, staff,
                                    value, 0, null, "pending_review",
                                    "{\"event\":\"" + operation + "\",\"approved\":false}",
                                    session.account.memberId
                                )
                            }.onSuccess { message = "Mouvement de rémunération enregistré en attente de validation."; amount = ""; detail = ""; error = null }
                                .onFailure { error = it.message ?: "Enregistrement impossible." }
                        }
                    }, modifier = Modifier.fillMaxWidth()) { Text("Enregistrer le mouvement") }
                    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (message != null) Text(message!!, color = MaterialTheme.colorScheme.secondary)
                }
            }
        }
        item { Text("Horaires récents", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(attendance.take(40)) { row ->
            Text(row.counterparty + " · " + row.title + " · " + java.text.SimpleDateFormat("dd/MM HH:mm", java.util.Locale.getDefault()).format(java.util.Date(row.createdAtMillis)),
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item { Text("Commissions, avances et primes", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        items(payroll.take(40)) { row ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(12.dp)) {
                    Text(row.counterparty + " · " + labelRecord(row.recordType), fontWeight = FontWeight.SemiBold)
                    Text(row.title + " · " + xaf(row.amountXaf) + " · " + row.status, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

