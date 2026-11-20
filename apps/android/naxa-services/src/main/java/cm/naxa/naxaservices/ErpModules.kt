package cm.naxa.naxaservices

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

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
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.LocalInventoryImportRow
import cm.naxa.naxaservices.data.LocalInventoryItem
import cm.naxa.naxaservices.data.LocalSite
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.util.Calendar
import kotlinx.coroutines.flow.first
import kotlin.math.roundToLong
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
fun ModulePageTitle(title: String, description: String) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(description, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
fun LocalOnlyNotice(text: String = "Brouillon local : aucune synchronisation serveur ni validation distante n’est déclarée.") {
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
    val activityOptions = when (session.account.activityProfile) {
        "pressing" -> listOf("pressing", "retail")
        "coiffure" -> listOf("hair", "retail")
        "beaute" -> listOf("beauty", "retail")
        "parfumerie" -> listOf("retail")
        "couture", "menuiserie", "reparation", "garage", "nettoyage", "domicile", "impression", "photo_evenementiel" -> listOf("service", "material")
        else -> listOf("service", "retail")
    }
    var activity by rememberSaveable(session.account.activityProfile) { mutableStateOf(activityOptions.first()) }
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
                        activityOptions.forEach { value ->
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
    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val customers by remember(siteId) {
        repository.dao.observeCustomers(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val followUps by remember(siteId) {
        repository.dao.observeCustomerFollowUps(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())
    val contactEvents by remember(siteId) {
        repository.dao.observeCustomerContactEvents(session.account.organizationId, siteId)
    }.collectAsState(initial = emptyList())

    var name by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var contactConsent by rememberSaveable { mutableStateOf(false) }
    var addressLine by rememberSaveable { mutableStateOf("") }
    var neighborhood by rememberSaveable { mutableStateOf("") }
    var landmark by rememberSaveable { mutableStateOf("") }
    var locationConsent by rememberSaveable { mutableStateOf(false) }
    var latitude by rememberSaveable { mutableStateOf("") }
    var longitude by rememberSaveable { mutableStateOf("") }
    var locationAccuracy by rememberSaveable { mutableStateOf("") }
    var locationMessage by remember { mutableStateOf<String?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    var selectedCustomerId by rememberSaveable { mutableStateOf("") }
    var followUpTitle by rememberSaveable { mutableStateOf("Suivi client") }
    var followUpFrequency by rememberSaveable { mutableStateOf("monthly") }
    var followUpChannel by rememberSaveable { mutableStateOf("phone") }
    var followUpNotes by rememberSaveable { mutableStateOf("") }
    var followUpError by remember { mutableStateOf<String?>(null) }

    fun readRecentLocation() {
        try {
            val fineGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarseGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!fineGranted && !coarseGranted) {
                locationMessage = "Autorisation de localisation non accordée."
                return
            }
            val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val now = System.currentTimeMillis()
            val candidates = manager.allProviders
                .filter { provider -> runCatching { manager.isProviderEnabled(provider) }.getOrDefault(false) }
                .mapNotNull { provider ->
                    runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
                }
                .filter { location -> now - location.time in 0..(15 * 60 * 1000L) }
            val latest = candidates.maxByOrNull { it.time }
            if (latest == null) {
                locationMessage = "Aucune position récente n'est disponible. Saisis l'adresse manuellement ou réessaie après activation de la localisation."
                return
            }
            latitude = latest.latitude.toString()
            longitude = latest.longitude.toString()
            locationAccuracy = if (latest.hasAccuracy()) latest.accuracy.toString() else ""
            locationMessage = "Position récente récupérée. Vérifie l'adresse et le repère avant d'enregistrer."
        } catch (_: SecurityException) {
            locationMessage = "Accès à la position refusé. Tu peux saisir l'adresse manuellement."
        } catch (_: Exception) {
            locationMessage = "Position indisponible. Tu peux saisir l'adresse manuellement."
        }
    }

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        if (permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        ) {
            readRecentLocation()
        } else {
            locationMessage = "Autorisation refusée. L'adresse manuelle reste disponible."
        }
    }

    val visible = customers.filter {
        it.displayName.contains(search, ignoreCase = true) ||
            it.phoneContact.contains(search, ignoreCase = true) ||
            it.addressLine.contains(search, ignoreCase = true)
    }
    val selectedCustomer = customers.firstOrNull { it.id == selectedCustomerId && it.orgId == session.account.organizationId && it.siteId == siteId }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                "Clients, CRM et fidélisation",
                "Fiches clients, routines de relance et adresses de service à domicile."
            )
            AuthorizedSitePicker(
                siteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) {
                siteId = it
                selectedCustomerId = ""
            }
            LocalOnlyNotice("CRM local pour ce point de vente. Les relances ne sont pas encore envoyées automatiquement : elles restent enregistrées dans l'agenda local jusqu'au raccordement du planificateur serveur et des notifications.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text("Créer une fiche client", fontWeight = FontWeight.Bold)
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Nom complet") }, singleLine = true)
                    OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text("Téléphone (facultatif)") }, singleLine = true)
                    OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text("Notes privées (facultatif)") }, minLines = 2)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = contactConsent, onCheckedChange = { contactConsent = it })
                        Text("Le client accepte les communications commerciales et de suivi")
                    }
                    Text("Adresse de prestation / livraison à domicile", fontWeight = FontWeight.SemiBold)
                    OutlinedTextField(addressLine, { addressLine = it }, Modifier.fillMaxWidth(), label = { Text("Adresse (facultatif)") }, singleLine = true)
                    OutlinedTextField(neighborhood, { neighborhood = it }, Modifier.fillMaxWidth(), label = { Text("Quartier") }, singleLine = true)
                    OutlinedTextField(landmark, { landmark = it }, Modifier.fillMaxWidth(), label = { Text("Repère ou consigne d'accès") }, singleLine = true)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = locationConsent, onCheckedChange = {
                            locationConsent = it
                            if (!it) {
                                latitude = ""; longitude = ""; locationAccuracy = ""
                                locationMessage = "Coordonnées GPS effacées du formulaire."
                            }
                        })
                        Text("Le client autorise l'enregistrement de sa position pour le service ou la livraison demandée.")
                    }
                    OutlinedButton(
                        onClick = {
                            locationMessage = null
                            if (!locationConsent) {
                                locationMessage = "Obtiens d'abord le consentement explicite du client."
                            } else {
                                val fineGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                                val coarseGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                                if (fineGranted || coarseGranted) readRecentLocation()
                                else locationPermissionLauncher.launch(arrayOf(
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                    Manifest.permission.ACCESS_COARSE_LOCATION
                                ))
                            }
                        },
                        enabled = locationConsent && !busy,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Récupérer une position GPS récente") }
                    if (latitude.isNotBlank() && longitude.isNotBlank()) {
                        Text("Latitude : $latitude · Longitude : $longitude", style = MaterialTheme.typography.bodySmall)
                        if (locationAccuracy.isNotBlank()) Text("Précision annoncée : $locationAccuracy m", style = MaterialTheme.typography.bodySmall)
                    }
                    if (!locationMessage.isNullOrBlank()) Text(locationMessage!!, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    Text("La géolocalisation est facultative. Pas de suivi continu du client ; l'adresse peut être saisie sans GPS.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                error = null
                                runCatching {
                                    repository.createLocalCustomer(
                                        session.account.organizationId,
                                        siteId,
                                        name,
                                        phone,
                                        notes,
                                        contactConsent,
                                        addressLine,
                                        neighborhood,
                                        landmark,
                                        latitude.toDoubleOrNull(),
                                        longitude.toDoubleOrNull(),
                                        locationAccuracy.toFloatOrNull(),
                                        locationConsent
                                    )
                                }.onSuccess {
                                    name = ""; phone = ""; notes = ""; contactConsent = false
                                    addressLine = ""; neighborhood = ""; landmark = ""
                                    locationConsent = false; latitude = ""; longitude = ""; locationAccuracy = ""
                                    locationMessage = null
                                    notice = "Fiche client enregistrée localement."
                                }.onFailure { error = it.message ?: "Création impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && name.isNotBlank() &&
                            ((latitude.isBlank() && longitude.isBlank()) ||
                                (locationConsent && latitude.toDoubleOrNull() != null && longitude.toDoubleOrNull() != null)),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else "Enregistrer le client") }
                    if (!notice.isNullOrBlank()) Text(notice!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text("Programmer une relance client", fontWeight = FontWeight.Bold)
                    Text(
                        selectedCustomer?.displayName?.let { "Client sélectionné : $it" } ?: "Sélectionne d'abord un client dans la liste ci-dessous.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(followUpTitle, { followUpTitle = it }, Modifier.fillMaxWidth(), label = { Text("Objet du suivi") }, singleLine = true)
                    Text("Fréquence", fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { followUpFrequency = "weekly" }, enabled = followUpFrequency != "weekly") { Text("Chaque semaine") }
                        OutlinedButton(onClick = { followUpFrequency = "monthly" }, enabled = followUpFrequency != "monthly") { Text("Chaque mois") }
                    }
                    Text("Canal prévu", fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        OutlinedButton(onClick = { followUpChannel = "in_person" }, enabled = followUpChannel != "in_person") { Text("Sur place") }
                        OutlinedButton(onClick = { followUpChannel = "phone" }, enabled = followUpChannel != "phone") { Text("Téléphone") }
                        OutlinedButton(onClick = { followUpChannel = "whatsapp" }, enabled = followUpChannel != "whatsapp") { Text("WhatsApp") }
                    }
                    OutlinedTextField(followUpNotes, { followUpNotes = it }, Modifier.fillMaxWidth(), label = { Text("Consignes de relance (facultatif)") }, minLines = 2)
                    if (!followUpError.isNullOrBlank()) Text(followUpError!!, color = MaterialTheme.colorScheme.error)
                    Button(
                        onClick = {
                            val customer = selectedCustomer
                            scope.launch {
                                followUpError = null
                                runCatching {
                                    require(customer != null) { "Sélectionne un client avant de programmer la relance." }
                                    repository.createCustomerFollowUp(
                                        session.account.organizationId, siteId, customer.id,
                                        followUpTitle, followUpFrequency, followUpChannel, followUpNotes,
                                        session.account.memberId
                                    )
                                }.onSuccess {
                                    followUpNotes = ""
                                    notice = "Routine enregistrée. La première échéance est calculée à partir d'aujourd'hui."
                                }.onFailure { followUpError = it.message ?: "Création de relance impossible." }
                            }
                        },
                        enabled = selectedCustomer != null && !busy,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Enregistrer la routine") }
                }
            }
        }

        item { Text("Clients (" + visible.size + ")", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (visible.isEmpty()) item { Text("Aucun client correspondant sur ce point de vente.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(visible) { customer ->
            Card(
                onClick = { selectedCustomerId = customer.id },
                colors = CardDefaults.cardColors(
                    containerColor = if (selectedCustomerId == customer.id) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface
                )
            ) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(customer.displayName, fontWeight = FontWeight.Bold)
                    if (customer.phoneContact.isNotBlank()) Text(customer.phoneContact)
                    if (customer.addressLine.isNotBlank()) Text("Adresse : " + customer.addressLine)
                    if (customer.neighborhood.isNotBlank()) Text("Quartier : " + customer.neighborhood)
                    if (customer.landmark.isNotBlank()) Text("Repère : " + customer.landmark)
                    if (customer.latitude != null && customer.longitude != null) Text("GPS enregistré avec consentement")
                    if (customer.notesPrivate.isNotBlank()) Text(customer.notesPrivate, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(if (customer.contactConsent) "Consentement de contact enregistré" else "Aucun consentement de contact", style = MaterialTheme.typography.labelSmall)
                    Text(if (selectedCustomerId == customer.id) "Sélectionné pour le suivi" else "Toucher pour sélectionner", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        item { Text("Routines de relance", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (followUps.isEmpty()) item { Text("Aucune routine de relance sur ce point de vente.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(followUps) { followUp ->
            val owner = customers.firstOrNull { it.id == followUp.customerId }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(owner?.displayName ?: "Client", fontWeight = FontWeight.Bold)
                    Text(followUp.title)
                    Text(
                        (if (followUp.frequency == "weekly") "Hebdomadaire" else "Mensuelle") +
                            " · " + when (followUp.channel) {
                                "phone" -> "Téléphone"
                                "whatsapp" -> "WhatsApp"
                                else -> "Sur place"
                            }
                    )
                    Text("Prochaine échéance : " + java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(followUp.nextDueAtMillis)))
                    if (followUp.notes.isNotBlank()) Text(followUp.notes, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    OutlinedButton(
                        onClick = {
                            scope.launch {
                                runCatching {
                                    repository.completeCustomerFollowUp(
                                        session.account.organizationId, siteId, followUp.id,
                                        "completed", "Relance effectuée", session.account.memberId
                                    )
                                }.onSuccess { notice = "Relance clôturée et prochaine échéance reprogrammée." }
                                    .onFailure { followUpError = it.message ?: "Mise à jour impossible." }
                            }
                        }
                    ) { Text("Marquer comme effectuée") }
                }
            }
        }

        item { Text("Historique des suivis récents", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (contactEvents.isEmpty()) item { Text("Aucun événement de suivi enregistré.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(contactEvents.take(20)) { event ->
            val owner = customers.firstOrNull { it.id == event.customerId }
            Text(
                (owner?.displayName ?: "Client") + " · " + event.outcome +
                    " · " + java.text.SimpleDateFormat("dd/MM HH:mm", java.util.Locale.getDefault()).format(java.util.Date(event.happenedAtMillis)),
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

private fun formatInventoryXaf(value: Long): String = "%,d FCFA".format(value).replace(',', ' ')

@Composable
fun StockContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val stock by remember(siteId) { repository.dao.observeInventoryItems(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    val valuations by remember(siteId) { repository.dao.observeInventoryValuations(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())
    var selectedItemId by rememberSaveable { mutableStateOf("") }
    var unitCostXaf by rememberSaveable { mutableStateOf("") }
    var sellingPriceXaf by rememberSaveable { mutableStateOf("") }
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
    var includeReorderField by rememberSaveable { mutableStateOf(true) }
    var includePurchasePriceField by rememberSaveable { mutableStateOf(true) }
    var includeSellingPriceField by rememberSaveable { mutableStateOf(true) }
    var importPreview by remember { mutableStateOf<List<LocalInventoryImportRow>>(emptyList()) }
    var importFileName by remember { mutableStateOf("") }
    var updateExistingItems by rememberSaveable { mutableStateOf(false) }
    var importMessage by remember { mutableStateOf<String?>(null) }

    val templateLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("text/csv")
    ) { uri: Uri? ->
        if (uri != null) {
            runCatching {
                val columns = buildList {
                    add("sku"); add("name"); add("unit"); add("quantity")
                    if (includeReorderField) add("reorder_level")
                    if (includePurchasePriceField) add("purchase_price_xaf")
                    if (includeSellingPriceField) add("selling_price_xaf")
                }
                context.contentResolver.openOutputStream(uri)?.use { output ->
                    OutputStreamWriter(output, Charsets.UTF_8).use { writer ->
                        writer.append("#NAXA_STOCK_TEMPLATE,1\n")
                        writer.append(columns.joinToString(",")).append("\n")
                    }
                } ?: error("Impossible d'écrire le fichier sélectionné.")
            }.onSuccess {
                importMessage = "Template CSV créé. Renseigne une ligne par article avant l'import."
            }.onFailure {
                error = it.message ?: "Téléchargement du template impossible."
            }
        }
    }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            runCatching {
                val content = context.contentResolver.openInputStream(uri)?.use { input ->
                    InputStreamReader(input, Charsets.UTF_8).buffered().readText()
                } ?: error("Impossible de lire le fichier sélectionné.")
                parseStockImportCsv(content)
            }.onSuccess { parsed ->
                importPreview = parsed
                importFileName = uri.lastPathSegment ?: "fichier.csv"
                importMessage = "Aperçu chargé. Vérifie les doublons et confirme l'import."
                error = null
            }.onFailure {
                importPreview = emptyList()
                error = it.message ?: "Lecture ou validation du fichier impossible."
            }
        }
    }
    val importDuplicateCount = importPreview.count { row ->
        stock.any { it.sku.trim().equals(row.sku.trim(), ignoreCase = true) }
    }
    val unvaluedItems = stock.count { item -> valuations.none { it.inventoryItemId == item.id } }
    val stockCostValue = stock.sumOf { item ->
        (item.quantity * (valuations.firstOrNull { it.inventoryItemId == item.id }?.unitCostXaf ?: 0L).toDouble()).roundToLong()
    }
    val stockSaleValue = stock.sumOf { item ->
        (item.quantity * (valuations.firstOrNull { it.inventoryItemId == item.id }?.sellingPriceXaf ?: 0L).toDouble()).roundToLong()
    }
    val potentialGrossMargin = stockSaleValue - stockCostValue

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Stocks et consommables", "Suivi par point de vente : lessive, produits coiffure et consommables.")
            AuthorizedSitePicker(
                siteIds,
                siteId,
                session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }
            ) { siteId = it; selectedItemId = ""; unitCostXaf = ""; sellingPriceXaf = "" }
            LocalOnlyNotice("Chaque mouvement est journalisé localement ; le stock ne peut pas devenir négatif.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Importation des stocks (CSV)", fontWeight = FontWeight.Bold)
                    Text("Le template adapte ses colonnes aux champs sélectionnés. Colonnes obligatoires : SKU, désignation, unité et quantité initiale.", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = includeReorderField, onCheckedChange = { includeReorderField = it })
                        Text("Seuil d'alerte")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = includePurchasePriceField, onCheckedChange = { includePurchasePriceField = it })
                        Text("Coût d'achat")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = includeSellingPriceField, onCheckedChange = { includeSellingPriceField = it })
                        Text("Prix de vente")
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = { templateLauncher.launch("naxa-services-stock-template.csv") },
                            modifier = Modifier.weight(1f)
                        ) { Text("Télécharger le template") }
                        Button(
                            onClick = { importLauncher.launch(arrayOf("text/*", "application/csv", "application/vnd.ms-excel")) },
                            modifier = Modifier.weight(1f)
                        ) { Text("Importer le fichier des stocks") }
                    }
                    Text("Format pris en charge : CSV UTF-8. Les lignes et colonnes sont validées avant toute écriture.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (importPreview.isNotEmpty()) {
                        Text("Aperçu : $importFileName", fontWeight = FontWeight.SemiBold)
                        Text("${importPreview.size} ligne(s) valide(s) · $importDuplicateCount SKU déjà présent(s)")
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = updateExistingItems, onCheckedChange = { updateExistingItems = it })
                            Text("Mettre à jour les articles existants (confirmation explicite)")
                        }
                        importPreview.take(8).forEach { row ->
                            Text(
                                "${row.sku} · ${row.name} · ${row.quantity} ${row.unit} · seuil ${row.reorderLevel}",
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        if (importPreview.size > 8) Text("… et ${importPreview.size - 8} autre(s) ligne(s)", style = MaterialTheme.typography.bodySmall)
                        Button(
                            onClick = {
                                scope.launch {
                                    busy = true
                                    error = null
                                    runCatching {
                                        repository.importInventoryBatch(
                                            session.account.organizationId,
                                            siteId,
                                            importPreview,
                                            updateExistingItems,
                                            session.account.memberId
                                        )
                                    }.onSuccess { result ->
                                        notice = "Import terminé : ${result.first} article(s) créé(s), ${result.second} mis à jour."
                                        importPreview = emptyList()
                                        importFileName = ""
                                        updateExistingItems = false
                                        importMessage = null
                                    }.onFailure { error = it.message ?: "Import annulé." }
                                    busy = false
                                }
                            },
                            enabled = !busy && importPreview.isNotEmpty() && (importDuplicateCount == 0 || updateExistingItems),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (busy) "Import en cours…" else "Confirmer l'import CSV") }
                        Text("L'import est transactionnel : si une ligne échoue, aucune ligne du lot n'est appliquée. Les quantités initiales et ajustements sont journalisés comme mouvements.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (!importMessage.isNullOrBlank()) Text(importMessage!!, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Valorisation estimative du point de vente", fontWeight = FontWeight.Bold)
                    Text("Coût total du stock : " + formatInventoryXaf(stockCostValue))
                    Text("Valeur de vente théorique : " + formatInventoryXaf(stockSaleValue))
                    Text("Marge brute potentielle : " + formatInventoryXaf(potentialGrossMargin), fontWeight = FontWeight.Bold)
                    Text("Articles non valorisés : " + unvaluedItems + " / " + stock.size, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Calcul local fondé sur les coûts et prix saisis. Hors taxes, pertes, remises, frais indirects et mouvements non synchronisés.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
            }
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
                        val value = valuations.firstOrNull { it.inventoryItemId == item.id }
                        Text("Coût unitaire : " + (value?.unitCostXaf?.toString() ?: "—") + " F", style = MaterialTheme.typography.bodySmall)
                        Text("Prix de vente : " + (value?.sellingPriceXaf?.toString() ?: "—") + " F", style = MaterialTheme.typography.bodySmall)
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
                        val savedValue = valuations.firstOrNull { it.inventoryItemId == selected.id }
                        if (unitCostXaf.isBlank()) unitCostXaf = savedValue?.unitCostXaf?.toString() ?: ""
                        if (sellingPriceXaf.isBlank()) sellingPriceXaf = savedValue?.sellingPriceXaf?.toString() ?: ""
                        OutlinedTextField(unitCostXaf, { unitCostXaf = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Coût d’achat unitaire (FCFA)") }, singleLine = true)
                        OutlinedTextField(sellingPriceXaf, { sellingPriceXaf = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Prix de vente unitaire (FCFA)") }, singleLine = true)
                        Button(
                            onClick = {
                                scope.launch {
                                    runCatching {
                                        repository.saveInventoryValuation(
                                            session.account.organizationId, siteId, selected.id,
                                            unitCostXaf.toLong(), sellingPriceXaf.toLong()
                                        )
                                    }.onSuccess { notice = "Coût et prix de vente enregistrés." }
                                        .onFailure { error = it.message ?: "Enregistrement des coûts impossible." }
                                }
                            },
                            enabled = unitCostXaf.toLongOrNull() != null && sellingPriceXaf.toLongOrNull() != null,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("Enregistrer les coûts et la marge brute unitaire") }
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


private fun parseStockImportCsv(raw: String): List<LocalInventoryImportRow> {
    require(raw.isNotBlank()) { "Le fichier CSV est vide." }
    val text = raw.removePrefix("\uFEFF")
    val records = mutableListOf<List<String>>()
    val row = mutableListOf<String>()
    val field = StringBuilder()
    var quoted = false
    var index = 0
    while (index < text.length) {
        val char = text[index]
        when {
            char == '"' && quoted && index + 1 < text.length && text[index + 1] == '"' -> {
                field.append('"'); index++
            }
            char == '"' -> quoted = !quoted
            char == ',' && !quoted -> { row.add(field.toString()); field.setLength(0) }
            (char == '\n' || char == '\r') && !quoted -> {
                if (char == '\r' && index + 1 < text.length && text[index + 1] == '\n') index++
                row.add(field.toString())
                if (row.any { it.isNotBlank() }) records.add(row.toList())
                row.clear(); field.setLength(0)
            }
            else -> field.append(char)
        }
        index++
    }
    require(!quoted) { "Le CSV contient un guillemet non fermé." }
    row.add(field.toString())
    if (row.any { it.isNotBlank() }) records.add(row.toList())
    val dataRecords = records.filterNot { it.firstOrNull()?.startsWith("#NAXA_STOCK_TEMPLATE") == true }
    require(dataRecords.size >= 2) { "Le CSV doit contenir une ligne d'en-tête et au moins un article." }

    fun normalize(value: String): String = java.text.Normalizer.normalize(value.trim().lowercase(java.util.Locale.ROOT), java.text.Normalizer.Form.NFD)
        .replace(Regex("\\p{Mn}+"), "")
        .replace(Regex("[^a-z0-9]+"), "_")
        .trim('_')

    val header = dataRecords.first().map(::normalize)
    fun findColumn(vararg aliases: String): Int? {
        return header.indexOfFirst { it in aliases.toSet() }.takeIf { it >= 0 }
    }
    val skuIndex = findColumn("sku", "reference", "ref", "code", "barcode", "code_barre")
    val nameIndex = findColumn("name", "nom", "designation", "produit", "article", "product_name")
    val unitIndex = findColumn("unit", "unite", "unite_mesure", "measure_unit")
    val quantityIndex = findColumn("quantity", "quantite", "stock", "stock_initial", "initial_quantity")
    val reorderIndex = findColumn("reorder_level", "seuil", "seuil_alerte", "stock_minimum")
    val purchaseIndex = findColumn("purchase_price_xaf", "purchase_price", "prix_achat", "cout_achat", "unit_cost")
    val sellingIndex = findColumn("selling_price_xaf", "selling_price", "prix_vente", "prix_public", "sale_price")
    require(skuIndex != null && nameIndex != null && unitIndex != null && quantityIndex != null) {
        "Colonnes obligatoires manquantes : sku, name, unit, quantity. Utilise le template NAXA SERVICES."
    }

    fun cell(cells: List<String>, column: Int?): String =
        column?.let { cells.getOrNull(it)?.trim().orEmpty() }.orEmpty()
    fun decimal(value: String, fieldName: String, rowNumber: Int): Double {
        if (value.isBlank()) return 0.0
        val parsed = value.replace(" ", "").replace(",", ".").toDoubleOrNull()
        require(parsed != null && parsed.isFinite() && parsed >= 0.0) {
            "Ligne $rowNumber : valeur $fieldName invalide."
        }
        return parsed
    }
    fun amount(value: String, fieldName: String, rowNumber: Int): Long? {
        if (value.isBlank()) return null
        val parsed = value.replace(" ", "").replace(",", ".").toDoubleOrNull()
        require(parsed != null && parsed.isFinite() && parsed >= 0.0 && parsed <= Long.MAX_VALUE.toDouble()) {
            "Ligne $rowNumber : montant $fieldName invalide."
        }
        require(parsed % 1.0 == 0.0) { "Ligne $rowNumber : $fieldName doit être un montant entier en FCFA." }
        return parsed.toLong()
    }

    val result = mutableListOf<LocalInventoryImportRow>()
    dataRecords.drop(1).forEachIndexed { offset, cells ->
        val rowNumber = offset + 2
        if (cells.all { it.isBlank() }) return@forEachIndexed
        val sku = cell(cells, skuIndex)
        val name = cell(cells, nameIndex)
        val unit = cell(cells, unitIndex)
        require(sku.isNotBlank() && name.isNotBlank() && unit.isNotBlank()) {
            "Ligne $rowNumber : SKU, désignation et unité sont obligatoires."
        }
        result.add(
            LocalInventoryImportRow(
                sku = sku,
                name = name,
                unit = unit,
                quantity = decimal(cell(cells, quantityIndex), "quantité", rowNumber),
                reorderLevel = decimal(cell(cells, reorderIndex), "seuil d'alerte", rowNumber),
                unitCostXaf = amount(cell(cells, purchaseIndex), "coût d'achat", rowNumber),
                sellingPriceXaf = amount(cell(cells, sellingIndex), "prix de vente", rowNumber)
            )
        )
    }
    require(result.isNotEmpty()) { "Aucun article exploitable dans le CSV." }
    require(result.size <= 5000) { "Limite de 5 000 articles par import." }
    val duplicateSku = result.groupBy { it.sku.trim().uppercase() }.entries.firstOrNull { it.value.size > 1 }?.key
    require(duplicateSku == null) { "Le fichier contient plusieurs lignes avec le SKU $duplicateSku." }
    return result
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
    session: AuthSession,
    onSessionUpdated: (AuthSession) -> Unit
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
    LaunchedEffect(route, selectedSite, session.accessToken, session.account.memberId) {
        if (route == AppRoute.WORKSTATIONS && selectedSite in session.account.activeSiteIds) {
            runCatching { api.listWorkstations(session.accessToken, selectedSite) }
                .onSuccess { serverRows ->
                    serverRows.forEach { row ->
                        runCatching {
                            repository.cacheServerWorkstation(
                                row.id, orgId, row.siteId, row.code, row.name,
                                row.kind, row.capacity, row.status
                            )
                        }
                    }
                }
                .onFailure { error = it.message ?: "Chargement des emplacements serveur impossible." }
        }
    }
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
                            OutlinedButton(onClick = { locale = "fr" }, enabled = canManageNetwork && locale != "fr") { Text(if (locale == "fr") "✓ Français" else "Français") }
                            OutlinedButton(onClick = { locale = "en" }, enabled = canManageNetwork && locale != "en") { Text(if (locale == "en") "✓ English" else "English") }
                            OutlinedButton(onClick = { locale = "ff-CM" }, enabled = canManageNetwork && locale != "ff-CM") { Text(if (locale == "ff-CM") "✓ Fulfulde" else "Fulfulde") }
                            if (locale == "ff-CM") Text("Traductions Fulfulde en cours de validation ; les contenus non traduits restent en français.", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
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
                Text("Brouillons locaux non activés", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                localSites.filter { it.syncStatus != "server_confirmed" }.forEach { site ->
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
                            Text("Créer un point de vente", fontWeight = FontWeight.Bold)
                            Text("Le site devient actif uniquement après confirmation du serveur.", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                            OutlinedTextField(siteCode, { siteCode = it }, Modifier.fillMaxWidth(), label = { Text("Code interne") }, singleLine = true)
                            OutlinedTextField(siteName, { siteName = it }, Modifier.fillMaxWidth(), label = { Text("Nom du point de vente") }, singleLine = true)
                            OutlinedTextField(address, { address = it }, Modifier.fillMaxWidth(), label = { Text("Adresse") }, singleLine = true)
                            OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text("Téléphone") }, singleLine = true)
                            Button(
                                onClick = {
                                    scope.launch {
                                        busy = true; error = null
                                        runCatching { api.createSite(session.accessToken, siteCode, siteName, address, phone) }
                                            .onSuccess { site ->
                                                val updatedSites = (session.account.activeSites + site).distinctBy { it.id }
                                                onSessionUpdated(session.copy(account = session.account.copy(
                                                    activeSiteIds = (session.account.activeSiteIds + site.id).distinct(),
                                                    activeSites = updatedSites
                                                )))
                                                siteCode = ""; siteName = ""; address = ""; phone = ""
                                                notice = "Point de vente créé, activé et confirmé par le serveur."
                                            }
                                            .onFailure { error = it.message ?: "Création du point de vente impossible." }
                                        busy = false
                                    }
                                },
                                enabled = !busy && canManageNetwork && mode == "multi_site_network" && siteCode.isNotBlank() && siteCode.trim().length >= 2 && siteName.isNotBlank(),
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
                AuthorizedSitePicker(
                    session.account.activeSiteIds,
                    selectedSite,
                    session.account.activeSites.associate { it.id to it.name }
                ) { selectedSite = it }
                Text("Seuls les points de vente autorisés par le serveur peuvent recevoir des emplacements actifs.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Exemples : fauteuil de coiffure, comptoir pressing, atelier, réception ou caisse.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Créer un emplacement dans ce point de vente", fontWeight = FontWeight.Bold)
                        Text("La création et l’activation sont confirmées par le serveur.", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
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
                                    runCatching {
                                        api.createWorkstation(
                                            session.accessToken,
                                            selectedSite,
                                            workstationCode,
                                            workstationName,
                                            workstationType,
                                            capacity.toInt()
                                        )
                                    }.onSuccess { serverRow ->
                                        repository.cacheServerWorkstation(
                                            serverRow.id, orgId, serverRow.siteId, serverRow.code,
                                            serverRow.name, serverRow.kind, serverRow.capacity, serverRow.status
                                        )
                                        workstationCode = ""; workstationName = ""; capacity = "1"
                                        notice = "Emplacement créé, activé et confirmé par le serveur."
                                    }.onFailure { error = it.message ?: "Création de l’emplacement impossible." }
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
            if (workstations.isEmpty()) item { Text("Aucun emplacement configuré pour ce point de vente.") }
            items(workstations) { item ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.fillMaxWidth().padding(13.dp)) {
                        Text(item.name, fontWeight = FontWeight.Bold)
                        Text(item.code + " · " + item.kind + " · capacité " + item.capacity)
                        if (item.syncStatus == "server_confirmed") {
                            Text("Actif côté serveur", color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                        } else {
                            LocalOnlyNotice("Brouillon local · non activé")
                        }
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
    val context = androidx.compose.ui.platform.LocalContext.current
    var permissionGranted by remember { mutableStateOf(Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> permissionGranted = granted }
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
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Notifications du téléphone", fontWeight = FontWeight.Bold)
                    Text(if (permissionGranted) "Notifications autorisées sur cet appareil." else "Les rappels locaux sont programmés, mais Android n’autorise pas encore leur affichage.")
                    if (Build.VERSION.SDK_INT >= 33 && !permissionGranted) {
                        Button(onClick = { permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS) }, modifier = Modifier.fillMaxWidth()) {
                            Text("Autoriser les notifications")
                        }
                    }
                    Text("Briefings locaux programmés : 07:00 et 19:00. Les notifications push distantes nécessitent le raccord FCM serveur.")
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
