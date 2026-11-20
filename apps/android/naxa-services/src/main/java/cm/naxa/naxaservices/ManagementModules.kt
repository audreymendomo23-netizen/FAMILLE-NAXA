package cm.naxa.naxaservices

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalManagementRecord
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.launch
import java.util.Calendar
import kotlin.math.roundToLong

private fun xaf(v: Long): String = "%,d F".format(v).replace(',', ' ')

@Composable
fun BillingContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
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
            Text("Devis, factures, encaissements, avoirs et sommes que la PME doit rembourser au client. Les écritures restent rattachées au site.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text("Nouvelle pièce commerciale", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("quote", "invoice", "credit_note", "refund_due").forEach { item ->
                            OutlinedButton(onClick = { type = item }) { Text(if (type == item) "✓ " + labelRecord(item) else labelRecord(item)) }
                        }
                    }
                    OutlinedTextField(customer, { customer = it }, Modifier.fillMaxWidth(), label = { Text("Client / tiers") }, singleLine = true)
                    OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("Détail de la prestation ou du remboursement") }, singleLine = true)
                    OutlinedTextField(total, { total = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Montant total (FCFA)") }, singleLine = true)
                    OutlinedTextField(paid, { paid = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Déjà encaissé / déjà remboursé (FCFA)") }, singleLine = true)
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
        items(records.filter { it.recordType in setOf("quote", "invoice", "credit_note", "refund_due") }) { item ->
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
        if (records.none { it.recordType in setOf("quote", "invoice", "credit_note", "refund_due") }) {
            item { Text("Aucune pièce commerciale enregistrée.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

@Composable
fun SubscriptionsContent(modifier: Modifier, repository: NaxaServicesLocalRepository, session: AuthSession) {
    val scope = rememberCoroutineScope()
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
    val records by remember(siteId) { repository.dao.observeManagementRecordsByType(session.account.organizationId, siteId, "subscription_request") }.collectAsState(initial = emptyList())
    var reference by rememberSaveable { mutableStateOf("") }
    var plan by rememberSaveable { mutableStateOf("Pro") }
    var message by remember { mutableStateOf<String?>(null) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Abonnement et droits de l’organisation", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Le Promoteur de l’organisation mère porte l’abonnement. Les sites et postes héritent des droits et quotas autorisés par le contrat.", color = MaterialTheme.colorScheme.onSurfaceVariant)
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
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
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
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
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
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
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
fun ProfileContent(
    modifier: Modifier,
    session: AuthSession,
    activityProfile: String?,
    repository: NaxaServicesLocalRepository,
    onNavigate: (AppRoute) -> Unit,
    onLogout: () -> Unit
) {
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
    val history by remember(siteId) { repository.dao.observeManagementRecords(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val activity = NaxaActivityCatalog.find(activityProfile)
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Profil", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(22.dp)) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(session.account.displayName.take(1).uppercase(), style = MaterialTheme.typography.displayMedium, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Black)
                    Text(session.account.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(session.account.roleCode + " · " + session.account.organizationName)
                    Text("Identifiant membre : " + session.account.memberId, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Activité : " + (activity?.titleFr ?: "Non définie"))
                    Text("Modèle : " + session.account.businessMode)
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
        item { Text("Historique local", fontWeight = FontWeight.Bold) }
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
    val siteId = session.account.activeSiteIds.firstOrNull().orEmpty()
    val requests by remember(session.account.organizationId) { repository.dao.observeSupportRequests(session.account.organizationId) }.collectAsState(initial = emptyList())
    var subject by rememberSaveable { mutableStateOf("") }
    var message by rememberSaveable { mutableStateOf("") }
    var notice by remember { mutableStateOf<String?>(null) }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Text("Livechat et assistance", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("FAQ et demandes d’assistance. Les messages sont conservés localement et attendent la passerelle support. Les appels et le partage d’écran temps réel nécessitent encore le service média et les permissions de session.", color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                    }, modifier = Modifier.fillMaxWidth()) { Text("Créer une demande") }
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
    "invoice" -> "Facture"
    "credit_note" -> "Avoir"
    "refund_due" -> "Remboursement dû au client"
    "purchase" -> "Achat"
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
    val document = PdfDocument()
    val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
    val page = document.startPage(pageInfo)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 18f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); color = android.graphics.Color.BLACK }
    val normal = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 13f; color = android.graphics.Color.DKGRAY }
    page.canvas.drawText("NAXA SERVICES", 42f, 56f, paint)
    paint.textSize = 16f
    page.canvas.drawText(labelRecord(item.recordType), 42f, 102f, paint)
    normal.textSize = 13f
    val lines = listOf(
        "Organisation : " + organization,
        "Référence : " + item.reference,
        "Libellé : " + item.title,
        "Client : " + item.counterparty,
        "Total : " + xaf(item.amountXaf),
        "Réglé : " + xaf(item.paidXaf),
        "Solde : " + xaf(item.amountXaf - item.paidXaf),
        "Statut : " + statusRecord(item.status),
        "Document généré localement — à synchroniser et valider."
    )
    lines.forEachIndexed { index, line -> page.canvas.drawText(line.take(85), 42f, 150f + index * 30f, normal) }
    page.canvas.drawText("Établi avec NAXA SERVICES", 42f, 790f, normal)
    document.finishPage(page)
    context.contentResolver.openOutputStream(uri)?.use { document.writeTo(it) } ?: error("Destination inaccessible.")
    document.close()
}
