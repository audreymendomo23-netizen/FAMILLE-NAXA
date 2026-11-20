package cm.naxa.naxaservices

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalInventoryItem
import cm.naxa.naxaservices.data.LocalSite
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import java.util.Calendar
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

@Composable
fun AuthorizedSitePicker(
    siteIds: List<String>,
    selectedSiteId: String,
    siteLabels: Map<String, String> = emptyMap(),
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    if (siteIds.isEmpty()) {
        Text("Aucun point de vente n’est affecté à ce compte.", color = MaterialTheme.colorScheme.error)
    } else {
        Box {
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
                Text("Point de vente : " + (siteLabels[selectedSiteId] ?: selectedSiteId))
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                siteIds.forEachIndexed { index, id ->
                    DropdownMenuItem(
                        text = { Text(siteLabels[id] ?: ("Point " + (index + 1).toString() + " · " + id)) },
                        onClick = { onSelect(id); expanded = false }
                    )
                }
            }
        }
    }
}

@Composable
private fun ModulePageTitle(title: String, description: String) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(description, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun LocalOnlyNotice(text: String = "Brouillon local : aucune synchronisation serveur ni validation distante n’est déclarée.") {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
}

@Composable
fun ServicesCatalogContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val services by remember(siteId) { repository.dao.observeServices(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    var activity by rememberSaveable { mutableStateOf("pressing") }
    var name by rememberSaveable { mutableStateOf("") }
    var duration by rememberSaveable { mutableStateOf("30") }
    var price by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Catalogue des prestations", "Configure les services et tarifs séparément pour chaque point de vente.")
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }) { siteId = it }
            LocalOnlyNotice()
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Nouvelle prestation", fontWeight = FontWeight.Bold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("pressing", "hair", "retail").forEach { value ->
                            OutlinedButton(onClick = { activity = value }) {
                                Text(if (activity == value) "✓ " + value.uppercase() else value.uppercase())
                            }
                        }
                    }
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Nom de la prestation") }, singleLine = true)
                    OutlinedTextField(duration, { duration = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Durée en minutes") }, singleLine = true)
                    OutlinedTextField(price, { price = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Prix en FCFA") }, singleLine = true)
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (!notice.isNullOrBlank()) Text(notice!!, color = MaterialTheme.colorScheme.secondary)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true; error = null; notice = null
                                runCatching {
                                    repository.createLocalService(
                                        session.account.organizationId,
                                        siteId,
                                        activity,
                                        name,
                                        duration.toIntOrNull(),
                                        price.toLong()
                                    )
                                }.onSuccess {
                                    name = ""; duration = "30"; price = ""
                                    notice = "Prestation enregistrée sur cet appareil."
                                }.onFailure { error = it.message ?: "Enregistrement impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && name.isNotBlank() && (price.toLongOrNull() ?: -1L) >= 0L,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else "Ajouter au catalogue") }
                }
            }
        }
        item { Text("Prestations configurées", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (services.isEmpty()) item { Text("Aucune prestation locale pour ce point de vente.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(services) { service ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(service.name, fontWeight = FontWeight.Bold)
                    Text(service.activity.uppercase() + " · " + (service.durationMinutes?.toString() ?: "—") + " min")
                    Text(service.priceXaf.toString() + " FCFA", color = MaterialTheme.colorScheme.primary)
                    LocalOnlyNotice("Tarif local · " + service.code)
                }
            }
        }
    }
}

@Composable
fun CustomersContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val customers by remember(siteId) { repository.dao.observeCustomers(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    var name by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var consent by rememberSaveable { mutableStateOf(false) }
    var search by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    val visible = customers.filter {
        it.displayName.contains(search, ignoreCase = true) || it.phoneContact.contains(search, ignoreCase = true)
    }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Clients et fidélisation", "Fiches client privées, historique local et consentement de contact explicite.")
            AuthorizedSitePicker(
                siteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it }
            LocalOnlyNotice("Les fiches clients ne sont pas partagées entre points de vente dans ce stockage local.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text("Créer une fiche client", fontWeight = FontWeight.Bold)
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Nom complet") }, singleLine = true)
                    OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text("Téléphone (facultatif)") }, singleLine = true)
                    OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text("Notes privées (facultatif)") }, minLines = 2)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = consent, onCheckedChange = { consent = it })
                        Text("Le client accepte les communications")
                    }
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true; error = null
                                runCatching { repository.createLocalCustomer(session.account.organizationId, siteId, name, phone, notes, consent) }
                                    .onSuccess { name = ""; phone = ""; notes = ""; consent = false }
                                    .onFailure { error = it.message ?: "Création impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && name.isNotBlank(),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else "Enregistrer le client") }
                }
            }
        }
        item { OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth(), label = { Text("Rechercher un client") }, singleLine = true) }
        item { Text(visible.size.toString() + " client(s)", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (visible.isEmpty()) item { Text("Aucun client correspondant sur ce point de vente.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(visible) { customer ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(customer.displayName, fontWeight = FontWeight.Bold)
                    if (customer.phoneContact.isNotBlank()) Text(customer.phoneContact)
                    if (customer.notesPrivate.isNotBlank()) Text(customer.notesPrivate, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(if (customer.contactConsent) "Consentement de contact enregistré" else "Aucun consentement de contact", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
fun StockContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val stock by remember(siteId) { repository.dao.observeInventoryItems(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    var selectedItemId by rememberSaveable { mutableStateOf("") }
    val selected = stock.firstOrNull { it.id == selectedItemId }
    var itemName by rememberSaveable { mutableStateOf("") }
    var sku by rememberSaveable { mutableStateOf("") }
    var unit by rememberSaveable { mutableStateOf("unité") }
    var reorder by rememberSaveable { mutableStateOf("0") }
    var movementType by rememberSaveable { mutableStateOf("in") }
    var quantity by rememberSaveable { mutableStateOf("") }
    var reason by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Stocks et consommables", "Suivi par point de vente : lessive, produits coiffure et consommables.")
            AuthorizedSitePicker(
                siteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it; selectedItemId = "" }
            LocalOnlyNotice("Chaque mouvement est journalisé localement ; le stock ne peut pas devenir négatif.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Créer un article", fontWeight = FontWeight.Bold)
                    OutlinedTextField(itemName, { itemName = it }, Modifier.fillMaxWidth(), label = { Text("Désignation") }, singleLine = true)
                    OutlinedTextField(sku, { sku = it }, Modifier.fillMaxWidth(), label = { Text("Référence / SKU") }, singleLine = true)
                    OutlinedTextField(unit, { unit = it }, Modifier.fillMaxWidth(), label = { Text("Unité (pièce, litre, kg…)") }, singleLine = true)
                    OutlinedTextField(reorder, { reorder = it }, Modifier.fillMaxWidth(), label = { Text("Seuil d’alerte") }, singleLine = true)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true; error = null
                                runCatching { repository.createInventoryItem(session.account.organizationId, siteId, sku, itemName, unit, reorder.replace(",", ".").toDouble()) }
                                    .onSuccess { itemName = ""; sku = ""; reorder = "0"; notice = "Article créé avec un stock initial nul." }
                                    .onFailure { error = it.message ?: "Création impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && itemName.isNotBlank() && unit.isNotBlank() && (reorder.replace(",", ".").toDoubleOrNull() ?: -1.0) >= 0.0,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Ajouter l’article") }
                }
            }
        }
        item { Text("Articles du point de vente", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (stock.isEmpty()) item { Text("Aucun article configuré.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(stock) { item ->
            Card(
                onClick = { selectedItemId = item.id },
                colors = CardDefaults.cardColors(containerColor = if (selectedItemId == item.id) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface)
            ) {
                Row(Modifier.fillMaxWidth().padding(14.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(item.name, fontWeight = FontWeight.Bold)
                        Text(item.sku.ifBlank { "Sans référence" } + " · " + item.unit, style = MaterialTheme.typography.bodySmall)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(item.quantity.toString() + " " + item.unit, fontWeight = FontWeight.Bold)
                        Text(if (item.quantity <= item.reorderLevel) "Seuil atteint" else "Stock disponible", color = if (item.quantity <= item.reorderLevel) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
        }
        if (selected != null) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Mouvement : " + selected.name, fontWeight = FontWeight.Bold)
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            listOf("in", "consumption", "loss", "adjustment").forEach { type ->
                                OutlinedButton(onClick = { movementType = type }) { Text(if (movementType == type) "✓ " + type else type) }
                            }
                        }
                        OutlinedTextField(quantity, { quantity = it }, Modifier.fillMaxWidth(), label = { Text("Quantité") }, singleLine = true)
                        OutlinedTextField(reason, { reason = it }, Modifier.fillMaxWidth(), label = { Text("Motif obligatoire") }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true; error = null
                                    runCatching {
                                        repository.recordInventoryMovement(
                                            session.account.organizationId, siteId, selected.id,
                                            movementType, quantity.replace(",", ".").toDouble(), reason,
                                            session.account.memberId
                                        )
                                    }.onSuccess { quantity = ""; reason = ""; notice = "Mouvement de stock enregistré." }
                                        .onFailure { error = it.message ?: "Mouvement impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && (quantity.replace(",", ".").toDoubleOrNull()?.let { it != 0.0 && (movementType == "adjustment" || it > 0.0) } == true) && reason.trim().length >= 3,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Valider le mouvement") }
                    }
                }
            }
        }
        if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
        if (!notice.isNullOrBlank()) item { Text(notice!!, color = MaterialTheme.colorScheme.secondary) }
    }
}

private data class SiteDailyReport(
    val siteId: String,
    val salesXaf: Long,
    val expensesXaf: Long,
    val appointments: Int,
    val pressingTickets: Int
)

@Composable
fun ReportsContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<SiteDailyReport>>(emptyList()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var generatedAt by remember { mutableStateOf<String?>(null) }

    fun refresh() {
        scope.launch {
            busy = true; error = null
            runCatching {
                val start = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                val end = start + 24L * 60L * 60L * 1000L - 1L
                session.account.activeSiteIds.map { siteId ->
                    SiteDailyReport(
                        siteId = siteId,
                        salesXaf = repository.dao.observeSalesTotal(session.account.organizationId, siteId, start, end).first(),
                        expensesXaf = repository.dao.observeExpensesTotal(session.account.organizationId, siteId, start, end).first(),
                        appointments = repository.dao.observeAppointmentCount(session.account.organizationId, siteId, start, end).first(),
                        pressingTickets = repository.dao.observePressingCount(session.account.organizationId, siteId, start, end).first()
                    )
                }
            }.onSuccess {
                rows = it
                generatedAt = java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date())
            }.onFailure { error = it.message ?: "Calcul du rapport impossible." }
            busy = false
        }
    }

    LaunchedEffect(session.account.memberId) { refresh() }
    val totalSales = rows.sumOf { it.salesXaf }
    val totalExpenses = rows.sumOf { it.expensesXaf }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Rapports et pilotage", "Indicateurs de la journée, ventilés par point de vente autorisé.")
            LocalOnlyNotice("Rapport issu des données locales de cet appareil ; il ne constitue pas une clôture comptable ni un rapport réseau synchronisé.")
            Button(onClick = { refresh() }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(if (busy) "Calcul…" else "Actualiser le rapport du jour")
            }
            if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
            if (!generatedAt.isNullOrBlank()) Text("Calculé le " + generatedAt!!, style = MaterialTheme.typography.labelSmall)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                    Text("Consolidation indicative des points autorisés", fontWeight = FontWeight.Bold)
                    Text("Recettes confirmées : " + totalSales + " FCFA")
                    Text("Dépenses : " + totalExpenses + " FCFA")
                    Text("Solde indicatif : " + (totalSales - totalExpenses) + " FCFA", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    Text("Les caisses, stocks et équipes restent séparés dans les détails ci-dessous.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        items(rows) { row ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(15.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(row.siteId, fontWeight = FontWeight.Bold)
                    Text("Recettes confirmées : " + row.salesXaf + " FCFA")
                    Text("Dépenses : " + row.expensesXaf + " FCFA")
                    Text("Rendez-vous : " + row.appointments + " · Tickets pressing : " + row.pressingTickets)
                }
            }
        }
        if (rows.isEmpty() && !busy) item { Text("Aucune donnée locale pour les points de vente de ce compte.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
internal fun OrganizationWorkspaceContent(
    modifier: Modifier,
    route: AppRoute,
    repository: NaxaServicesLocalRepository,
    api: AuthApi,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val orgId = session.account.organizationId
    val profile by remember(orgId) { repository.dao.observeOrganizationProfile(orgId) }.collectAsState(initial = null)
    val localSites by remember(orgId) { repository.dao.observeSites(orgId) }.collectAsState(initial = emptyList())
    var displayName by rememberSaveable { mutableStateOf(session.account.organizationName) }
    var mode by rememberSaveable { mutableStateOf(session.account.businessMode) }
    var locale by rememberSaveable { mutableStateOf(session.account.defaultLocale) }
    var siteCode by rememberSaveable { mutableStateOf("") }
    var siteName by rememberSaveable { mutableStateOf("") }
    var address by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var selectedSite by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    var workstationCode by rememberSaveable { mutableStateOf("") }
    var workstationName by rememberSaveable { mutableStateOf("") }
    var workstationType by rememberSaveable { mutableStateOf("hair_chair") }
    var capacity by rememberSaveable { mutableStateOf("1") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var profileConfirmedHere by remember { mutableStateOf(false) }

    // The authenticated organization profile is authoritative. A local draft
    // may be resumed explicitly, but must never silently overwrite server state.
    LaunchedEffect(
        session.account.organizationId,
        session.account.organizationName,
        session.account.businessMode,
        session.account.defaultLocale
    ) {
        displayName = session.account.organizationName
        mode = session.account.businessMode
        locale = session.account.defaultLocale
    }

    val workstations by remember(selectedSite) { repository.dao.observeWorkstations(orgId, selectedSite) }.collectAsState(initial = emptyList())
    val canManageNetwork = session.roleCanManageNetwork()
    val canManageWorkstations = session.roleCanManageWorkstations()
    val title = when (route) {
        AppRoute.ORGANIZATION -> "Organisation et modèle d’exploitation"
        AppRoute.NETWORK -> "Pilotage du réseau"
        AppRoute.SITES -> "Points de vente autonomes"
        else -> "Emplacements et postes de travail"
    }
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(title, "Une organisation, plusieurs niveaux de gestion, des périmètres strictement séparés.")
            if (route == AppRoute.ORGANIZATION) {
                LocalOnlyNotice("Le profil et le modèle sont enregistrés côté serveur. Les nouveaux sites et postes ajoutés depuis les autres onglets restent des brouillons locaux.")
            } else {
                LocalOnlyNotice("Les nouveaux sites et postes sont préparés localement. Leur activation et les droits définitifs relèvent du serveur.")
            }
        }
        if (route == AppRoute.ORGANIZATION) {
            if (!profileConfirmedHere && profile != null && (
                profile!!.displayName != session.account.organizationName ||
                profile!!.businessMode != session.account.businessMode ||
                profile!!.defaultLocale != session.account.defaultLocale
            )) {
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("Brouillon local non confirmé", fontWeight = FontWeight.Bold)
                            Text(profile!!.displayName + " · " + profile!!.businessMode)
                            Text("Cette version n'a pas été validée par le serveur. Le profil serveur reste la référence.")
                            OutlinedButton(
                                onClick = {
                                    displayName = profile!!.displayName
                                    mode = profile!!.businessMode
                                    locale = profile!!.defaultLocale
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) { Text("Reprendre ce brouillon local") }
                        }
                    }
                }
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                        Text("Profil de l’organisation", fontWeight = FontWeight.Bold)
                        OutlinedTextField(displayName, { displayName = it }, Modifier.fillMaxWidth(), label = { Text("Nom commercial") }, singleLine = true, enabled = canManageNetwork)
                        Text("Choisir le modèle d’exploitation", fontWeight = FontWeight.SemiBold)
                        if (!canManageNetwork) {
                            Text("Le modèle d’exploitation est administré par le Promoteur de l’organisation.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        listOf(
                            "solo" to "PME autonome · un point de vente",
                            "single_site_multi_workstation" to "Responsable · plusieurs emplacements dans un même lieu",
                            "multi_site_network" to "Promoteur · plusieurs points de vente autonomes"
                        ).forEach { (key, label) ->
                            OutlinedButton(onClick = { mode = key }, modifier = Modifier.fillMaxWidth(), enabled = canManageNetwork) {
                                Text((if (mode == key) "✓ " else "") + label)
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { locale = "fr" }, enabled = canManageNetwork) { Text(if (locale == "fr") "✓ Français" else "Français") }
                            OutlinedButton(onClick = { locale = "en" }, enabled = canManageNetwork) { Text(if (locale == "en") "✓ English" else "English") }
                        }
                        if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true; error = null; notice = null
                                    runCatching {
                                        api.updateOrganizationProfile(session.accessToken, displayName, mode, locale)
                                    }.onSuccess {
                                        runCatching { repository.saveOrganizationProfile(orgId, displayName, mode, locale) }
                                        profileConfirmedHere = true
                                        notice = "Profil et modèle d’exploitation confirmés par le serveur."
                                    }.onFailure { remoteError ->
                                        profileConfirmedHere = false
                                        runCatching { repository.saveOrganizationProfile(orgId, displayName, mode, locale) }
                                            .onSuccess {
                                                notice = "Brouillon local uniquement : le serveur n’a pas confirmé la modification."
                                                error = remoteError.message ?: "Service distant indisponible."
                                            }
                                            .onFailure { localError ->
                                                error = localError.message ?: remoteError.message ?: "Enregistrement impossible."
                                            }
                                    }
                                    busy = false
                                }
                            },
                            enabled = !busy && canManageNetwork && orgId.isNotBlank() && displayName.isNotBlank(),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Enregistrer le profil et le modèle") }
                    }
                }
                if (!canManageNetwork) {
                    Text("Lecture seule pour ce rôle : le Promoteur conserve l’arbitrage du modèle d’organisation.")
                }
            }
            item {
                Text("Règles d’autonomie", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text("PME : caisse, stock, équipe et activité d’un seul établissement.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Responsable multi-emplacements : plusieurs postes et plannings dans un même établissement ; caisse rattachée au site.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Promoteur : chaque point de vente conserve sa caisse, son stock, son équipe et ses opérations. Le réseau consolide seulement les indicateurs autorisés.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (route == AppRoute.NETWORK || route == AppRoute.SITES) {
            item {
                Text("Points de vente affectés par le serveur", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                if (session.account.activeSites.isEmpty()) Text("Aucun point de vente affecté.")
                else session.account.activeSites.forEachIndexed { index, site ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.fillMaxWidth().padding(13.dp)) {
                            Text(site.name.ifBlank { "Point " + (index + 1).toString() }, fontWeight = FontWeight.Bold)
                            Text(listOf(site.code, site.addressLabel, site.phoneContact).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.bodySmall)
                            Text("Données et opérations isolées · lecture selon les droits serveur", color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
            item {
                Text("Points de vente ajoutés sur cet appareil", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                localSites.forEach { site ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.fillMaxWidth().padding(13.dp)) {
                            Text(site.name, fontWeight = FontWeight.Bold)
                            Text(site.code + " · " + site.addressLabel)
                            LocalOnlyNotice("Non activé côté serveur")
                        }
                    }
                }
            }
            if (route == AppRoute.SITES) {
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Préparer un nouveau point de vente", fontWeight = FontWeight.Bold)
                            OutlinedTextField(siteCode, { siteCode = it }, Modifier.fillMaxWidth(), label = { Text("Code interne") }, singleLine = true)
                            OutlinedTextField(siteName, { siteName = it }, Modifier.fillMaxWidth(), label = { Text("Nom du point de vente") }, singleLine = true)
                            OutlinedTextField(address, { address = it }, Modifier.fillMaxWidth(), label = { Text("Adresse") }, singleLine = true)
                            OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text("Téléphone") }, singleLine = true)
                            Button(
                                onClick = {
                                    scope.launch {
                                        busy = true; error = null
                                        runCatching { repository.createLocalSite(orgId, siteCode, siteName, address, phone) }
                                            .onSuccess { siteCode = ""; siteName = ""; address = ""; phone = ""; notice = "Point de vente préparé localement ; il n’est pas encore actif." }
                                            .onFailure { error = it.message ?: "Création locale impossible." }
                                        busy = false
                                    }
                                },
                                enabled = !busy && canManageNetwork && mode == "multi_site_network" && siteCode.isNotBlank() && siteName.isNotBlank(),
                                modifier = Modifier.fillMaxWidth()
                            ) { Text("Créer le brouillon du point de vente") }
                            if (!canManageNetwork) Text("La création des points de vente est réservée au rôle promoteur.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
            if (!notice.isNullOrBlank()) item { Text(notice!!, color = MaterialTheme.colorScheme.secondary) }
            if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
        }
        if (route == AppRoute.WORKSTATIONS) {
            item {
                Text("Emplacement dans un établissement", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                val selectable = (session.account.activeSiteIds + localSites.map { it.id }).distinct()
                AuthorizedSitePicker(
                    selectable,
                    selectedSite,
                    session.account.activeSites.associate { it.id to it.name } + localSites.associate { it.id to it.name }
                ) { selectedSite = it }
                Text("Exemples : fauteuil de coiffure, comptoir pressing, atelier, réception ou caisse.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Créer un emplacement local", fontWeight = FontWeight.Bold)
                        OutlinedTextField(workstationCode, { workstationCode = it }, Modifier.fillMaxWidth(), label = { Text("Code de l’emplacement") }, singleLine = true)
                        OutlinedTextField(workstationName, { workstationName = it }, Modifier.fillMaxWidth(), label = { Text("Nom de l’emplacement") }, singleLine = true)
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            listOf("hair_chair", "pressing_counter", "pressing_workshop", "reception", "cashier").forEach { type ->
                                OutlinedButton(onClick = { workstationType = type }) { Text(if (workstationType == type) "✓ " + type else type) }
                            }
                        }
                        OutlinedTextField(capacity, { capacity = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Capacité") }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true; error = null
                                    runCatching { repository.createLocalWorkstation(orgId, selectedSite, workstationCode, workstationName, workstationType, capacity.toInt()) }
                                        .onSuccess { workstationCode = ""; workstationName = ""; capacity = "1"; notice = "Emplacement préparé localement ; il n’est pas encore actif." }
                                        .onFailure { error = it.message ?: "Création impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && canManageWorkstations && selectedSite.isNotBlank() && workstationCode.isNotBlank() && workstationName.isNotBlank() && (capacity.toIntOrNull() ?: 0) in 1..100,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Ajouter l’emplacement") }
                        if (!canManageWorkstations) Text("Gestion réservée aux responsables autorisés.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            item { Text("Emplacements locaux du point de vente", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
            if (workstations.isEmpty()) item { Text("Aucun emplacement local configuré.") }
            items(workstations) { item ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.fillMaxWidth().padding(13.dp)) {
                        Text(item.name, fontWeight = FontWeight.Bold)
                        Text(item.code + " · " + item.kind + " · capacité " + item.capacity)
                        LocalOnlyNotice("En attente de création côté serveur")
                    }
                }
            }
            if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
            if (!notice.isNullOrBlank()) item { Text(notice!!, color = MaterialTheme.colorScheme.secondary) }
        }
    }
}

@Composable
fun SupportContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val requests by remember(session.account.organizationId) { repository.dao.observeSupportRequests(session.account.organizationId) }.collectAsState(initial = emptyList())
    var siteId by rememberSaveable { mutableStateOf(session.account.activeSiteIds.firstOrNull().orEmpty()) }
    var subject by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }
    var priority by rememberSaveable { mutableStateOf("normal") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Assistance et briefings", "Centralise les difficultés d’exploitation sans transmettre de secrets.")
            AuthorizedSitePicker(
                session.account.activeSiteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it }
            LocalOnlyNotice("Les demandes restent en brouillon sur l’appareil tant que la passerelle support n’est pas connectée.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Nouvelle demande", fontWeight = FontWeight.Bold)
                    OutlinedTextField(subject, { subject = it }, Modifier.fillMaxWidth(), label = { Text("Sujet") }, singleLine = true)
                    OutlinedTextField(description, { description = it }, Modifier.fillMaxWidth(), label = { Text("Description détaillée (10 caractères minimum)") }, minLines = 4)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("low", "normal", "high").forEach { value ->
                            OutlinedButton(onClick = { priority = value }) { Text(if (priority == value) "✓ " + value else value) }
                        }
                    }
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true; error = null
                                runCatching { repository.createSupportRequest(session.account.organizationId, siteId.ifBlank { null }, subject, description, priority) }
                                    .onSuccess { subject = ""; description = "" }
                                    .onFailure { error = it.message ?: "Demande impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && subject.isNotBlank() && description.trim().length >= 10,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Enregistrer la demande") }
                }
            }
        }
        item { Text("Demandes sur cet appareil", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (requests.isEmpty()) item { Text("Aucune demande enregistrée.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(requests) { request ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(14.dp)) {
                    Text(request.subject, fontWeight = FontWeight.Bold)
                    Text(request.priority.uppercase() + " · " + request.state)
                    Text(request.description, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
fun SettingsContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession,
    lightTheme: Boolean,
    onTheme: () -> Unit
) {
    val pending by repository.dao.observePendingOutboxCount(session.account.organizationId).collectAsState(initial = 0)
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Paramètres et synchronisation", "Préférences de l’application et état des écritures locales.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Apparence", fontWeight = FontWeight.Bold)
                    Text(if (lightTheme) "Thème clair actif" else "Thème sombre actif")
                    OutlinedButton(onClick = onTheme, modifier = Modifier.fillMaxWidth()) { Text("Basculer le thème") }
                    Text("Langue : Français / English — les ressources de l’application sont disponibles dans les deux langues.")
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("File locale d’événements", fontWeight = FontWeight.Bold)
                    Text(pending.toString() + " événement(s) en attente ou non synchronisé(s)")
                    LocalOnlyNotice("Aucun bouton de synchronisation n’est exposé : le contrat d’écriture serveur et ses tests restent à terminer.")
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text("Sécurité de l’appareil", fontWeight = FontWeight.Bold)
                    Text("Identifiant interne : " + session.account.memberId)
                    Text("Organisation : " + session.account.organizationId)
                    Text("Points de vente affectés : " + session.account.activeSiteIds.size)
                    Text("La conservation de session dépend de l’option « Rester connecté » choisie à la connexion.")
                }
            }
        }
    }
}

private fun AuthSession.roleCanManageNetwork(): Boolean =
    account.roleCode == "promoter"

private fun AuthSession.roleCanManageWorkstations(): Boolean =
    account.roleCode in setOf("promoter", "network_manager", "site_manager")
