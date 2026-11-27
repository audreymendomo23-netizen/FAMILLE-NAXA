package cm.naxa.naxaservices

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import org.json.JSONArray
import android.net.Uri
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
import cm.naxa.naxaservices.data.LocalService
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
        Text(localizedLabel("Aucun point de vente n’est affecté à ce compte.","No location assigned to this account.","Konte ngoo alaa nokkuure jaaygol."), color = MaterialTheme.colorScheme.error)
    } else {
        Box {
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
                Text(localizedLabel("Point de vente : ","Location: ","Nokkuure jaaygol : ") + (siteLabels[selectedSiteId] ?: selectedSiteId))
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
fun LocalOnlyNotice(text: String = "En attente de confirmation.") {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
}

@Composable
fun ServicesCatalogContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    val siteIds = session.account.activeSiteIds
    val profile = session.account.activityProfile ?: "autre"
    var siteId by rememberSaveable { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val services by remember(siteId) { repository.dao.observeServices(session.account.organizationId, siteId) }.collectAsState(initial = emptyList())

    val activityOptions = when (profile) {
        "pressing" -> listOf("pressing", "material", "retail")
        "coiffure" -> listOf("hair", "treatment", "retail")
        "beaute" -> listOf("beauty", "treatment", "retail")
        "parfumerie" -> listOf("perfume", "retail")
        "couture" -> listOf("tailoring", "material", "service")
        "reparation" -> listOf("repair", "part", "service")
        "menuiserie" -> listOf("manufacturing", "material", "service")
        "garage" -> listOf("vehicle", "part", "service")
        "nettoyage" -> listOf("cleaning", "contract", "material")
        "domicile" -> listOf("home", "service", "material")
        "impression" -> listOf("printing", "material", "service")
        "photo_evenementiel" -> listOf("event", "package", "retail")
        else -> listOf("service", "material", "retail")
    }
    val categoryOptions = when (profile) {
        "pressing" -> listOf("pressing", "retail")
        "coiffure" -> listOf("hair", "retail")
        "beaute" -> listOf("beauty", "retail")
        "parfumerie" -> listOf("retail")
        "couture" -> listOf("tailoring", "retail")
        "reparation" -> listOf("repair", "retail")
        "menuiserie" -> listOf("manufacturing", "retail")
        "garage" -> listOf("vehicle", "retail")
        "nettoyage" -> listOf("cleaning", "retail")
        "domicile" -> listOf("home", "retail")
        "impression" -> listOf("printing", "retail")
        "photo_evenementiel" -> listOf("event", "retail")
        else -> listOf("general", "retail")
    }
    val defaultCategory = categoryOptions.first()
    var activity by rememberSaveable(session.account.activityProfile) { mutableStateOf(activityOptions.first()) }
    var category by rememberSaveable(session.account.activityProfile) { mutableStateOf(defaultCategory) }
    var selectedServiceId by rememberSaveable { mutableStateOf("") }
    var name by rememberSaveable { mutableStateOf("") }
    var duration by rememberSaveable { mutableStateOf("30") }
    var price by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }
    var providerIds by rememberSaveable { mutableStateOf("") }
    var workstationKinds by rememberSaveable { mutableStateOf("") }
    var packageSessions by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    fun csvJson(value: String): String = JSONArray().apply {
        value.split(",").map { it.trim() }.filter { it.isNotBlank() }.distinct().forEach { put(it) }
    }.toString()

    fun jsonCsv(value: String): String = runCatching {
        val array = JSONArray(value)
        (0 until array.length()).map { array.optString(it) }.joinToString(", ")
    }.getOrDefault("")

    fun loadService(service: LocalService) {
        selectedServiceId = service.id
        name = service.name
        duration = service.durationMinutes?.toString() ?: ""
        price = service.priceXaf.toString()
        activity = service.activity
        category = service.category
        description = service.description
        providerIds = jsonCsv(service.providerMemberIdsJson)
        workstationKinds = jsonCsv(service.requiredWorkstationKindsJson)
        packageSessions = service.packageSessions?.toString() ?: ""
        error = null
    }

    fun resetForm() {
        selectedServiceId = ""
        name = ""; duration = "30"; price = ""; description = ""
        providerIds = ""; workstationKinds = ""; packageSessions = ""
        activity = activityOptions.first(); category = defaultCategory
    }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle(
                when (session.account.defaultLocale) { "en" -> "Activity service catalogue"; "ff-CM" -> "Doggol golle"; else -> "Catalogue métier des prestations" },
                when (session.account.defaultLocale) { "en" -> "Prices, durations, qualifications, packages and required workstations for each site."; "ff-CM" -> "Njoɓdi, sahaa, baawɗe, forfait e nokkuuji golle kala."; else -> "Tarifs, durées, qualifications, forfaits et postes requis pour chaque point de vente." }
            )
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to (it.name + if (it.addressLabel.isBlank()) "" else " · " + it.addressLabel) }) {
                siteId = it
                resetForm()
            }
            LocalOnlyNotice(when (session.account.defaultLocale) { "en" -> "Price changes are pending confirmation."; "ff-CM" -> "Waylugol njoɓdi nana fadi tabbitinol."; else -> "Les modifications de prix sont en attente de confirmation." })
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(if (selectedServiceId.isBlank()) when (session.account.defaultLocale) { "en" -> "New service"; "ff-CM" -> "Golle kesere"; else -> "Nouvelle prestation" } else when (session.account.defaultLocale) { "en" -> "Edit service"; "ff-CM" -> "Waylu golle"; else -> "Modifier la prestation" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "Service type"; "ff-CM" -> "Fannu golle"; else -> "Type d'activité" }, fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        activityOptions.forEach { value ->
                            OutlinedButton(onClick = { activity = value }) {
                                Text(if (activity == value) "✓ " + value.uppercase() else value.uppercase())
                            }
                        }
                    }
                    Text(when (session.account.defaultLocale) { "en" -> "Management category"; "ff-CM" -> "Fannu ɗowtugol"; else -> "Catégorie de gestion" }, fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        categoryOptions.forEach { value ->
                            OutlinedButton(onClick = { category = value }) {
                                Text(if (category == value) "✓ " + value.uppercase() else value.uppercase())
                            }
                        }
                    }
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Service / product name"; "ff-CM" -> "Innde golle / jawdi"; else -> "Nom de la prestation / produit" }) }, singleLine = true)
                    OutlinedTextField(description, { description = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Description, rules and terms"; "ff-CM" -> "Cifagol, laabi e sarɗi"; else -> "Description, règles et conditions" }) }, minLines = 2)
                    OutlinedTextField(duration, { duration = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Duration in minutes (blank if not applicable)"; "ff-CM" -> "Sahaa e minit (accu meere so alaa)"; else -> "Durée en minutes (laisser vide si sans durée)" }) }, singleLine = true)
                    OutlinedTextField(price, { price = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Unit price (XAF)"; "ff-CM" -> "Njoɓdi gootal (FCFA)"; else -> "Prix unitaire (FCFA)" }) }, singleLine = true)
                    OutlinedTextField(providerIds, { providerIds = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Qualified provider IDs (comma separated)"; "ff-CM" -> "Innol golluɓe yamiraaɓe (seerndu e virgule)"; else -> "IDs des prestataires habilités (séparés par virgule)" }) }, minLines = 1)
                    OutlinedTextField(workstationKinds, { workstationKinds = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Required workstation kinds (comma separated)"; "ff-CM" -> "Fannu nokkuuji golle soklaaɗi (seerndu e virgule)"; else -> "Types de postes requis (séparés par virgule)" }) }, minLines = 1)
                    OutlinedTextField(packageSessions, { packageSessions = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Package session count (optional)"; "ff-CM" -> "Limoore golle e forfait (so a yiɗi)"; else -> "Nombre de séances du forfait (facultatif)" }) }, singleLine = true)
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                    if (!notice.isNullOrBlank()) Text(notice!!, color = MaterialTheme.colorScheme.primary)
                    Button(
                        onClick = {
                            val parsedPrice = price.toLongOrNull() ?: -1L
                            val parsedDuration = duration.toIntOrNull()
                            val parsedSessions = packageSessions.toIntOrNull()
                            if (name.isBlank() || parsedPrice < 0L || (duration.isNotBlank() && (parsedDuration == null || parsedDuration !in 1..1440)) || (packageSessions.isNotBlank() && parsedSessions == null)) {
                                error = when (session.account.defaultLocale) { "en" -> "Check service name, price, duration and package."; "ff-CM" -> "Ƴeewto innde, njoɓdi, sahaa e forfait."; else -> "Vérifie le nom, le tarif, la durée et le forfait." }
                                return@Button
                            }
                            scope.launch {
                                busy = true
                                error = null
                                runCatching {
                                    if (selectedServiceId.isBlank()) {
                                        repository.createLocalService(
                                            session.account.organizationId, siteId, activity, name,
                                            parsedDuration, parsedPrice, category, description,
                                            csvJson(providerIds), csvJson(workstationKinds), parsedSessions
                                        )
                                    } else {
                                        repository.updateServiceCatalogItem(
                                            session.account.organizationId, siteId, selectedServiceId,
                                            name, parsedDuration, parsedPrice, category, description,
                                            csvJson(providerIds), csvJson(workstationKinds), parsedSessions,
                                            session.account.memberId
                                        )
                                    }
                                }.onSuccess {
                                    resetForm()
                                    notice = when (session.account.defaultLocale) { "en" -> "Service saved for this site."; "ff-CM" -> "Golle danndaama e nokkuure jaaygol ndee."; else -> "Prestation enregistrée sur ce point de vente." }
                                }.onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Save failed."; "ff-CM" -> "Danndugol waawataa."; else -> "Enregistrement impossible." } }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && name.isNotBlank() && (price.toLongOrNull() ?: -1L) >= 0L,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) when (session.account.defaultLocale) { "en" -> "Saving…"; "ff-CM" -> "Nana dannda…"; else -> "Enregistrement…" } else if (selectedServiceId.isBlank()) when (session.account.defaultLocale) { "en" -> "Add to catalogue"; "ff-CM" -> "Ɓeydu e doggol"; else -> "Ajouter au catalogue" } else when (session.account.defaultLocale) { "en" -> "Save changes"; "ff-CM" -> "Danndu wayle"; else -> "Enregistrer les modifications" }) }
                    if (selectedServiceId.isNotBlank()) {
                        TextButton(onClick = { resetForm() }) { Text(when (session.account.defaultLocale) { "en" -> "Cancel editing"; "ff-CM" -> "Haaytu waylugol"; else -> "Annuler la modification" }) }
                    }
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Configured services and products"; "ff-CM" -> "Golle e jawdi teeltaandi"; else -> "Prestations et produits configurés" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (services.isEmpty()) item { Text(when (session.account.defaultLocale) { "en" -> "No services on this site."; "ff-CM" -> "Alaa golle e nokkuure jaaygol ndee."; else -> "Aucune prestation sur ce point de vente." }, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(services) { service ->
            Card(
                onClick = { loadService(service) },
                colors = CardDefaults.cardColors(containerColor = if (selectedServiceId == service.id) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(service.name, fontWeight = FontWeight.Bold)
                    Text(service.activity.uppercase() + " · " + service.category.uppercase() + " · " + (service.durationMinutes?.toString() ?: "—") + " min")
                    Text(service.priceXaf.toString() + " FCFA", color = MaterialTheme.colorScheme.primary)
                    if (service.description.isNotBlank()) Text(service.description, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (service.packageSessions != null) Text((when (session.account.defaultLocale) { "en" -> "Package: "; "ff-CM" -> "Forfait : "; else -> "Forfait : " }) + service.packageSessions + (when (session.account.defaultLocale) { "en" -> " sessions"; "ff-CM" -> " golle"; else -> " séances" }))
                    Text(when (session.account.defaultLocale) { "en" -> "Tap to edit"; "ff-CM" -> "Memtu ngam waylude"; else -> "Toucher pour modifier" }, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
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

    var editingCustomerId by rememberSaveable { mutableStateOf("") }
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
                editingCustomerId = ""
                name = ""; phone = ""; notes = ""; addressLine = ""; neighborhood = ""; landmark = ""
                latitude = ""; longitude = ""; locationAccuracy = ""
                contactConsent = false; locationConsent = false
            }
            LocalOnlyNotice("Consultez les relances prévues dans votre agenda. L'envoi automatique n'est pas disponible.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(if (editingCustomerId.isBlank()) "Créer une fiche client" else "Modifier la fiche client", fontWeight = FontWeight.Bold)
                    OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Nom complet","Full name","Innde fof")) }, singleLine = true)
                    OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Téléphone (facultatif)","Phone (optional)","Telefon (so a yiɗi)")) }, singleLine = true)
                    OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Notes privées (facultatif)","Private notes (optional)","Ɓatakuuji sirri (so a yiɗi)")) }, minLines = 2)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = contactConsent, onCheckedChange = { contactConsent = it })
                        Text(localizedLabel("Le client accepte les communications commerciales et de suivi","Customer consents to business communications and follow-up","Soottotooɗo jaɓii jokkondiral jaaygol e rewindo"))
                    }
                    Text(localizedLabel("Adresse de prestation / livraison à domicile","Service / home delivery address","Nokkuure golle / jottugol e suudu"), fontWeight = FontWeight.SemiBold)
                    OutlinedTextField(addressLine, { addressLine = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Adresse (facultatif)","Address (optional)","Nokkuure (so a yiɗi)")) }, singleLine = true)
                    OutlinedTextField(neighborhood, { neighborhood = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Quartier","Neighborhood","Wuro")) }, singleLine = true)
                    OutlinedTextField(landmark, { landmark = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Repère ou consigne d'accès","Landmark or access instructions","Maantore walla laawol naatugol")) }, singleLine = true)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = locationConsent, onCheckedChange = {
                            locationConsent = it
                            if (!it) {
                                latitude = ""; longitude = ""; locationAccuracy = ""
                                locationMessage = "Coordonnées GPS effacées du formulaire."
                            }
                        })
                        Text(localizedLabel("Le client autorise l'enregistrement de sa position pour le service ou la livraison demandée.","Customer consents to saving their location for the requested service or delivery.","Soottotooɗo yamiri danndude nokkuure mum ngam golle walla jottugol ɗaɓɓitaangol."))
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
                    ) { Text(localizedLabel("Récupérer une position GPS récente","Get recent GPS location","Heɓ nokkuure GPS hesere")) }
                    if (latitude.isNotBlank() && longitude.isNotBlank()) {
                        Text(localizedLabel("Latitude : $latitude · Longitude : $longitude","Latitude: $latitude · Longitude: $longitude","Latitude : $latitude · Longitude : $longitude"), style = MaterialTheme.typography.bodySmall)
                        if (locationAccuracy.isNotBlank()) Text(localizedLabel("Précision annoncée : $locationAccuracy m","Reported accuracy: $locationAccuracy m","Feewugol : $locationAccuracy m"), style = MaterialTheme.typography.bodySmall)
                    }
                    if (!locationMessage.isNullOrBlank()) Text(locationMessage!!, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    Text(localizedLabel("La géolocalisation est facultative. Pas de suivi continu du client ; l'adresse peut être saisie sans GPS.","Location is optional. Customers are not tracked continuously; an address can be entered without GPS.","GPS wonaa waajib. Soottotooɗo rewindotaake sahaa fof; nokkuure winndetee tawa GPS alaa."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true
                                error = null
                                runCatching {
                                    val lat = latitude.toDoubleOrNull()
                                    val lon = longitude.toDoubleOrNull()
                                    val accuracy = locationAccuracy.toFloatOrNull()
                                    if (editingCustomerId.isBlank()) {
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
                                            lat,
                                            lon,
                                            accuracy,
                                            locationConsent
                                        )
                                    } else {
                                        repository.updateLocalCustomer(
                                            session.account.organizationId,
                                            siteId,
                                            editingCustomerId,
                                            name,
                                            phone,
                                            notes,
                                            contactConsent,
                                            addressLine,
                                            neighborhood,
                                            landmark,
                                            lat,
                                            lon,
                                            accuracy,
                                            locationConsent
                                        )
                                    }
                                }.onSuccess {
                                    name = ""; phone = ""; notes = ""; contactConsent = false
                                    addressLine = ""; neighborhood = ""; landmark = ""
                                    locationConsent = false; latitude = ""; longitude = ""; locationAccuracy = ""
                                    locationMessage = null
                                    editingCustomerId = ""
                                    notice = "Fiche client enregistrée."
                                }.onFailure { error = it.message ?: "Création impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && name.isNotBlank() &&
                            ((latitude.isBlank() && longitude.isBlank()) ||
                                (locationConsent && latitude.toDoubleOrNull() != null && longitude.toDoubleOrNull() != null)),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (busy) "Enregistrement…" else if (editingCustomerId.isBlank()) "Enregistrer le client" else "Enregistrer les modifications") }
                    if (editingCustomerId.isNotBlank()) {
                        OutlinedButton(onClick = {
                            editingCustomerId = ""
                            name = ""; phone = ""; notes = ""; contactConsent = false
                            addressLine = ""; neighborhood = ""; landmark = ""
                            locationConsent = false; latitude = ""; longitude = ""; locationAccuracy = ""
                            locationMessage = null
                        }, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Annuler la modification","Cancel editing","Haaytu waylugol")) }
                    }
                    if (!notice.isNullOrBlank()) Text(notice!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(localizedLabel("Programmer une relance client","Schedule customer follow-up","Teeltu rewindo soottotooɗo"), fontWeight = FontWeight.Bold)
                    Text(
                        selectedCustomer?.displayName?.let { "Client sélectionné : $it" } ?: "Sélectionne d'abord un client dans la liste ci-dessous.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(followUpTitle, { followUpTitle = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Objet du suivi","Follow-up subject","Ko rewindo")) }, singleLine = true)
                    Text(localizedLabel("Fréquence","Frequency","Sahaa"), fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { followUpFrequency = "weekly" }, enabled = followUpFrequency != "weekly") { Text(localizedLabel("Chaque semaine","Every week","Yontere kala")) }
                        OutlinedButton(onClick = { followUpFrequency = "monthly" }, enabled = followUpFrequency != "monthly") { Text(localizedLabel("Chaque mois","Every month","Lewru kala")) }
                    }
                    Text(localizedLabel("Canal prévu","Planned channel","Laawol jokkondiral"), fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        OutlinedButton(onClick = { followUpChannel = "in_person" }, enabled = followUpChannel != "in_person") { Text(localizedLabel("Sur place","In person","E nokkuure")) }
                        OutlinedButton(onClick = { followUpChannel = "phone" }, enabled = followUpChannel != "phone") { Text(localizedLabel("Téléphone","Phone","Telefon")) }
                        OutlinedButton(onClick = { followUpChannel = "whatsapp" }, enabled = followUpChannel != "whatsapp") { Text("WhatsApp") }
                    }
                    OutlinedTextField(followUpNotes, { followUpNotes = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Consignes de relance (facultatif)","Follow-up instructions (optional)","Yamirooje rewindo (so a yiɗi)")) }, minLines = 2)
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
                    ) { Text(localizedLabel("Enregistrer la routine","Save routine","Danndu rewindo")) }
                }
            }
        }

        item { Text(localizedLabel("Clients (","Customers (","Soottotooɓe (") + visible.size + ")", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (visible.isEmpty()) item { Text(localizedLabel("Aucun client correspondant sur ce point de vente.","No matching customer at this location.","Alaa soottotooɗo nannduɗo e nokkuure ndee."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
                    if (customer.addressLine.isNotBlank()) Text(localizedLabel("Adresse : ","Address: ","Nokkuure : ") + customer.addressLine)
                    if (customer.neighborhood.isNotBlank()) Text(localizedLabel("Quartier : ","Neighborhood: ","Wuro : ") + customer.neighborhood)
                    if (customer.landmark.isNotBlank()) Text(localizedLabel("Repère : ","Landmark: ","Maantore : ") + customer.landmark)
                    if (customer.latitude != null && customer.longitude != null) Text(localizedLabel("GPS enregistré avec consentement","GPS saved with consent","GPS danndaama e jaɓugol"))
                    if (customer.notesPrivate.isNotBlank()) Text(customer.notesPrivate, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(if (customer.contactConsent) "Consentement de contact enregistré" else "Aucun consentement de contact", style = MaterialTheme.typography.labelSmall)
                    Text(if (customer.locationConsentAtMillis != null) "GPS autorisé pour le service demandé" else "Aucune coordonnée GPS conservée", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = { selectedCustomerId = customer.id },
                            modifier = Modifier.weight(1f)
                        ) { Text(if (selectedCustomerId == customer.id) "✓ Suivi sélectionné" else "Sélectionner pour suivi") }
                        OutlinedButton(
                            onClick = {
                                editingCustomerId = customer.id
                                selectedCustomerId = customer.id
                                name = customer.displayName
                                phone = customer.phoneContact
                                notes = customer.notesPrivate
                                contactConsent = customer.contactConsent
                                addressLine = customer.addressLine
                                neighborhood = customer.neighborhood
                                landmark = customer.landmark
                                latitude = customer.latitude?.toString().orEmpty()
                                longitude = customer.longitude?.toString().orEmpty()
                                locationAccuracy = customer.locationAccuracyMeters?.toString().orEmpty()
                                locationConsent = customer.locationConsentAtMillis != null
                                locationMessage = null
                                notice = "Modification de la fiche " + customer.displayName
                            },
                            modifier = Modifier.weight(1f)
                        ) { Text(if (editingCustomerId == customer.id) "✓ Modifier" else "Modifier") }
                    }
                }
            }
        }

        item { Text(localizedLabel("Routines de relance","Follow-up routines","Laabi rewindo"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (followUps.isEmpty()) item { Text(localizedLabel("Aucune routine de relance sur ce point de vente.","No follow-up routine for this location.","Alaa rewindo e nokkuure ndee."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
                    Text(localizedLabel("Prochaine échéance : ","Next due date: ","Ñalnde yoɓde aroore : ") + java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.getDefault()).format(java.util.Date(followUp.nextDueAtMillis)))
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
                    ) { Text(localizedLabel("Marquer comme effectuée","Mark as completed","Maanto ko timmii")) }
                }
            }
        }

        item { Text(localizedLabel("Historique des suivis récents","Recent follow-up history","Jaŋtol rewindo sakkitiiɗo"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (contactEvents.isEmpty()) item { Text(localizedLabel("Aucun événement de suivi enregistré.","No follow-up activity recorded.","Alaa rewindo danndaango."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
    var newSupplierWhatsApp by rememberSaveable { mutableStateOf("") }
    var supplierWhatsApp by rememberSaveable { mutableStateOf("") }
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
                    add("supplier_whatsapp")
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
    val allTransfers by remember(session.account.organizationId) {
        repository.dao.observeOrganizationManagementRecordsByType(session.account.organizationId, "inventory_transfer")
    }.collectAsState(initial = emptyList())
    val transfers = allTransfers.filter { transfer ->
        val metadata = runCatching { org.json.JSONObject(transfer.metadataJson) }.getOrNull()
        metadata?.optString("sourceSiteId") == siteId || metadata?.optString("destinationSiteId") == siteId
    }
    val transferDestinations = session.account.activeSites.filter { it.id != siteId }
    var transferDestinationSiteId by rememberSaveable { mutableStateOf("") }
    var transferItemId by rememberSaveable { mutableStateOf("") }
    var transferQuantity by rememberSaveable { mutableStateOf("1") }
    var transferMessage by remember { mutableStateOf<String?>(null) }
    var transferError by remember { mutableStateOf<String?>(null) }
    var transferBusy by remember { mutableStateOf(false) }
    val transferItem = stock.firstOrNull { it.id == transferItemId }
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
            ) {
                siteId = it
                selectedItemId = ""; unitCostXaf = ""; sellingPriceXaf = ""
                transferDestinationSiteId = ""; transferItemId = ""
            }
            LocalOnlyNotice("Votre stock ne peut pas devenir négatif.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Importation des stocks (CSV)","Inventory import (CSV)","Naatnugol jawdi (CSV)"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Le template adapte ses colonnes aux champs sélectionnés. Colonnes obligatoires : SKU, désignation, unité et quantité initiale.","The template adapts to selected fields. Required columns: SKU, name, unit and initial quantity.","Kayit nanndinta e humpito suɓaango. SKU, innde, unit e keewal arande ko waajib."), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = includeReorderField, onCheckedChange = { includeReorderField = it })
                        Text(localizedLabel("Seuil d'alerte","Alert threshold","Keewal les ngam tintinol"))
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = includePurchasePriceField, onCheckedChange = { includePurchasePriceField = it })
                        Text(localizedLabel("Coût d'achat","Purchase cost","Njoɓdi soodugol"))
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = includeSellingPriceField, onCheckedChange = { includeSellingPriceField = it })
                        Text(localizedLabel("Prix de vente","Sale price","Njoɓdi jaaygol"))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(
                            onClick = { templateLauncher.launch("naxa-services-stock-template.csv") },
                            modifier = Modifier.weight(1f)
                        ) { Text(localizedLabel("Télécharger le template","Download template","Heɓ kayit winndugol")) }
                        Button(
                            onClick = { importLauncher.launch(arrayOf("text/*", "application/csv", "application/vnd.ms-excel")) },
                            modifier = Modifier.weight(1f)
                        ) { Text(localizedLabel("Importer le fichier des stocks","Import inventory file","Naatnu fiilde jawdi")) }
                    }
                    Text(localizedLabel("Format pris en charge : CSV UTF-8 (séparateur virgule ou point-virgule). Les lignes et colonnes sont validées avant toute écriture.","Supported format: UTF-8 CSV (comma or semicolon). Rows and columns are checked before saving.","Format jaɓaangol: CSV UTF-8 (virgule walla point-virgule). Humpito ƴeewtetee hade danndude."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (importPreview.isNotEmpty()) {
                        Text(localizedLabel("Aperçu : $importFileName","Preview: $importFileName","Ƴeewndugol : $importFileName"), fontWeight = FontWeight.SemiBold)
                        Text(localizedLabel("${importPreview.size} ligne(s) valide(s) · $importDuplicateCount SKU déjà présent(s)","${importPreview.size} valid row(s) · $importDuplicateCount existing SKU(s)","${importPreview.size} binndi feewɗi · $importDuplicateCount SKU goodɗi"))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = updateExistingItems, onCheckedChange = { updateExistingItems = it })
                            Text(localizedLabel("Mettre à jour les articles existants (confirmation explicite)","Update existing items (confirm)","Hesɗitin jawdi goodndi (tabbitin)"))
                        }
                        importPreview.take(8).forEach { row ->
                            Text(localizedLabel("${row.sku} · ${row.name} · ${row.quantity} ${row.unit} · seuil ${row.reorderLevel}","${row.sku} · ${row.name} · ${row.quantity} ${row.unit} · threshold ${row.reorderLevel}","${row.sku} · ${row.name} · ${row.quantity} ${row.unit} · keewal les ${row.reorderLevel}"),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        if (importPreview.size > 8) Text(localizedLabel("… et ${importPreview.size - 8} autre(s) ligne(s)","… and ${importPreview.size - 8} other row(s)","… e ${importPreview.size - 8} binndi goɗɗi"), style = MaterialTheme.typography.bodySmall)
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
                        Text(localizedLabel("L'import est transactionnel : si une ligne échoue, aucune ligne du lot n'est appliquée. Les quantités initiales et ajustements sont journalisés comme mouvements.","If any row fails, none of the batch is saved. Initial quantities and adjustments are recorded as movements.","So gootol jaɓaaka, fof danndaaka. Keewal arande e peewngol ndanndetee e jaŋtol dirtugol."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (!importMessage.isNullOrBlank()) Text(importMessage!!, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Transferts inter-sites","Transfers between locations","Dirtugol hakkunde nokkuuji"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Les transferts relient deux points de vente autonomes. La demande et l'approbation ne modifient pas les stocks ; seule la réception confirmée effectue les deux mouvements.","Transfers link two independent locations. Requests and approvals do not change stock; confirmed receipt records both movements.","Dirtugol jokkondirta nokkuuji ɗiɗi. Ɗaɓɓitannde e jaɓugol waylataa jawdi; heɓugol tabbitinaangol tan waylata jawdi ɗiɗi."),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                    if (session.account.roleCode == "promoter") {
                        Text(localizedLabel("Site source : ","Source location: ","Nokkuure iwdi : ") + (session.account.activeSites.firstOrNull { it.id == siteId }?.name ?: siteId), fontWeight = FontWeight.SemiBold)
                        if (transferDestinations.isEmpty()) {
                            Text(localizedLabel("Aucun autre point de vente actif n'est disponible dans ce réseau.","No other active location in this network.","Alaa nokkuure jaaygol goɗɗere."))
                        } else {
                            transferDestinations.forEach { destination ->
                                OutlinedButton(
                                    onClick = { transferDestinationSiteId = destination.id },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text((if (transferDestinationSiteId == destination.id) "✓ " else "") + destination.name)
                                }
                            }
                        }
                        Text(localizedLabel("Article à transférer","Item to transfer","Jawdi dirtetee ndi"), fontWeight = FontWeight.SemiBold)
                        stock.forEach { item ->
                            OutlinedButton(
                                onClick = { transferItemId = item.id },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text((if (transferItemId == item.id) "✓ " else "") + item.name + " · " + item.quantity + " " + item.unit)
                            }
                        }
                        OutlinedTextField(
                            transferQuantity,
                            { transferQuantity = it },
                            Modifier.fillMaxWidth(),
                            label = { Text(localizedLabel("Quantité à transférer","Quantity to transfer","Keewal dirtetee ngal")) },
                            singleLine = true
                        )
                        if (transferItem != null) {
                            Text("SKU " + transferItem.sku + " · disponible maintenant : " + transferItem.quantity + " " + transferItem.unit, style = MaterialTheme.typography.bodySmall)
                        }
                        Button(
                            onClick = {
                                val quantityToTransfer: Double = transferQuantity.replace(",", ".").toDoubleOrNull() ?: 0.0
                                val selectedItemForTransfer = transferItem
                                if (selectedItemForTransfer == null || !quantityToTransfer.isFinite() ||
                                    quantityToTransfer <= 0.0 || quantityToTransfer > selectedItemForTransfer.quantity
                                ) {
                                    transferError = "Choisis un article et une quantité disponible strictement positive."
                                } else if (transferDestinationSiteId.isBlank() || transferDestinationSiteId == siteId) {
                                    transferError = "Choisis un point de vente destination différent du site source."
                                } else {
                                    scope.launch {
                                        transferBusy = true
                                        transferError = null
                                        runCatching {
                                            repository.createInventoryTransfer(
                                                session.account.organizationId,
                                                siteId,
                                                transferDestinationSiteId,
                                                selectedItemForTransfer.id,
                                                quantityToTransfer,
                                                session.account.memberId,
                                                session.account.roleCode
                                            )
                                        }.onSuccess { record ->
                                            transferItemId = ""
                                            transferQuantity = "1"
                                            transferMessage = "Demande " + record.reference + " créée. Le stock ne changera qu'à la réception."
                                            transferError = null
                                        }.onFailure { transferError = it.message ?: "Création du transfert impossible." }
                                        transferBusy = false
                                    }
                                }
                            },
                            enabled = !transferBusy && session.account.roleCode == "promoter" &&
                                session.account.activeSites.size > 1 && transferDestinationSiteId.isNotBlank() && transferItem != null,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (transferBusy) "Création…" else "Créer une demande de transfert") }
                    } else {
                        Text(localizedLabel("Les demandes et réceptions inter-sites sont réservées au Promoteur du réseau.","Only the network owner can request and receive transfers.","Jom nokkuuji tan waawi ɗaɓɓude e jaɓɓude jawdi."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (!transferError.isNullOrBlank()) Text(transferError!!, color = MaterialTheme.colorScheme.error)
                    if (!transferMessage.isNullOrBlank()) Text(transferMessage!!, color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item { Text(localizedLabel("Demandes de transfert du réseau","Network transfer requests","Ɗaɓɓitanɗe dirtugol nokkuuji"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (transfers.isEmpty()) {
            item { Text(localizedLabel("Aucune demande de transfert pour ce point de vente.","No transfer requests for this location.","Alaa ɗaɓɓitannde dirtugol e nokkuure ndee."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        items(transfers) { transfer ->
            var transitionReason by rememberSaveable(transfer.id) { mutableStateOf("") }
            val metadata = remember(transfer.metadataJson) {
                runCatching { org.json.JSONObject(transfer.metadataJson) }.getOrNull()
            }
            val sourceTransferSiteId = metadata?.optString("sourceSiteId")?.takeIf { it.isNotBlank() } ?: transfer.siteId
            val destinationTransferSiteId = metadata?.optString("destinationSiteId").orEmpty()
            val sourceTransferSiteName = metadata?.optString("sourceSiteName").orEmpty()
            val destinationTransferSiteName = metadata?.optString("destinationSiteName").orEmpty()
            val isSourceSite = siteId == sourceTransferSiteId
            val isDestinationSite = siteId == destinationTransferSiteId
            val events by remember(transfer.id, sourceTransferSiteId) {
                repository.dao.observeWorkflowEvents(session.account.organizationId, sourceTransferSiteId, "inventory_transfer", transfer.id)
            }.collectAsState(initial = emptyList())
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(transfer.reference + " · " + transfer.title, fontWeight = FontWeight.SemiBold)
                    Text(
                        (if (isSourceSite) "Sortie demandée depuis : " else "Réception prévue à : ") +
                            (if (isSourceSite) sourceTransferSiteName else destinationTransferSiteName) +
                            " · Statut : " + transfer.status
                    )
                    Text(localizedLabel("Trajet : ","Route: ","Laawol : ") + sourceTransferSiteName + " → " + destinationTransferSiteName +
                            " · Quantité : " + (metadata?.optDouble("quantity") ?: 0.0) +
                            " · SKU : " + (metadata?.optString("sku") ?: "—")
                    )
                    val canApprove = session.account.roleCode == "promoter" && isSourceSite && transfer.status == "open"
                    val canReceive = session.account.roleCode == "promoter" && isDestinationSite && transfer.status == "approved"
                    val canReject = session.account.roleCode == "promoter" &&
                        transfer.status in setOf("open", "approved") && (isSourceSite || isDestinationSite)
                    if (canApprove || canReceive || canReject) {
                        OutlinedTextField(
                            transitionReason,
                            { transitionReason = it },
                            Modifier.fillMaxWidth(),
                            label = { Text(localizedLabel("Motif obligatoire pour cette étape","Reason required for this step","Daliilu waajib ngam feere ndee")) }
                        )
                        val actions = buildList {
                            if (canApprove) add("approved" to "Approuver la demande")
                            if (canReceive) add("received" to "Confirmer la réception physique")
                            if (canReject) add("rejected" to "Rejeter la demande")
                        }
                        actions.forEach { (nextStatus, label) ->
                            OutlinedButton(
                                onClick = {
                                    scope.launch {
                                        runCatching {
                                            repository.transitionManagementRecord(
                                                session.account.organizationId, sourceTransferSiteId, transfer.id,
                                                nextStatus, transitionReason, session.account.memberId
                                            )
                                        }.onSuccess {
                                            transitionReason = ""
                                            transferMessage = when (nextStatus) {
                                                "approved" -> "Transfert approuvé ; stocks inchangés."
                                                "received" -> "Réception confirmée ; mouvements source et destination journalisés."
                                                else -> "Transfert rejeté ; stocks inchangés."
                                            }
                                            transferError = null
                                        }.onFailure { transferError = it.message ?: "Transition du transfert impossible." }
                                    }
                                },
                                enabled = transitionReason.trim().length >= 3,
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(label) }
                        }
                    } else if (transfer.status == "approved" && isSourceSite) {
                        Text(localizedLabel("En attente de confirmation physique sur le site destination.","Awaiting physical receipt at destination.","Nana fadi tabbitinol heɓugol e nokkuure jaɓɓoore."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    events.take(5).forEach { event ->
                        Text(
                            event.fromStatus + " → " + event.toStatus + " · " + event.reason,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(localizedLabel("Valorisation estimative du point de vente","Estimated inventory valuation","Keewal ceede jawdi tanƴaangal"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Coût total du stock : ","Total stock cost: ","Njoɓdi jawdi fof : ") + formatInventoryXaf(stockCostValue))
                    Text(localizedLabel("Valeur de vente théorique : ","Estimated sale value: ","Ceede jaaygol tanƴaaɗe : ") + formatInventoryXaf(stockSaleValue))
                    Text(localizedLabel("Marge brute potentielle : ","Potential gross margin: ","Ceede heddiiɗe tanƴaaɗe : ") + formatInventoryXaf(potentialGrossMargin), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Articles non valorisés : ","Items without valuation: ","Jawdi ɗe njoɓdi mum anndaaka : ") + unvaluedItems + " / " + stock.size, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(localizedLabel("Estimation fondée sur les coûts et prix saisis. Hors taxes, pertes, remises, frais indirects et mouvements non synchronisés.","Estimate based on entered costs and prices, excluding taxes, losses, discounts, indirect expenses and unsynced movements.","Tanƴugol e njoɓdi winndaaɗi, alaa sagalle, majjugol, ustugol njoɓdi, njoɓdi goɗɗi e golle ɗe hesɗitinaaka."),
                        color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Créer un article","Create item","Sos jawdi"), fontWeight = FontWeight.Bold)
                    OutlinedTextField(itemName, { itemName = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Désignation","Item name","Innde jawdi")) }, singleLine = true)
                    OutlinedTextField(sku, { sku = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Référence / SKU","Reference / SKU","Innol / SKU")) }, singleLine = true)
                    OutlinedTextField(unit, { unit = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Unité (pièce, litre, kg…)","Unit (piece, litre, kg…)","Unit (gootal, litre, kg…)")) }, singleLine = true)
                    OutlinedTextField(reorder, { reorder = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Seuil d’alerte","Alert threshold","Keewal les ngam tintinol")) }, singleLine = true)
                    OutlinedTextField(newSupplierWhatsApp, { newSupplierWhatsApp = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("WhatsApp fournisseur (indicatif pays + numéro)","Supplier WhatsApp (country code + number)","WhatsApp hokkooɗo jawdi (innol leydi + tonngoode)")) }, singleLine = true)
                    Button(
                        onClick = {
                            scope.launch {
                                busy = true; error = null
                                runCatching { repository.createInventoryItem(session.account.organizationId, siteId, sku, itemName, unit, reorder.replace(",", ".").toDouble(), newSupplierWhatsApp) }
                                    .onSuccess { itemName = ""; sku = ""; reorder = "0"; newSupplierWhatsApp = ""; notice = "Article créé avec un stock initial nul." }
                                    .onFailure { error = it.message ?: "Création impossible." }
                                busy = false
                            }
                        },
                        enabled = !busy && siteId.isNotBlank() && itemName.isNotBlank() && unit.isNotBlank() && (reorder.replace(",", ".").toDoubleOrNull() ?: -1.0) >= 0.0,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(localizedLabel("Ajouter l’article","Add item","Ɓeydu jawdi")) }
                }
            }
        }
        item { Text(localizedLabel("Articles du point de vente","Location inventory","Jawdi nokkuure jaaygol"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (stock.isEmpty()) item { Text(localizedLabel("Aucun article configuré.","No items configured.","Alaa jawdi teeltaandi."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(stock) { item ->
            Card(
                onClick = { selectedItemId = item.id; supplierWhatsApp = item.supplierWhatsApp },
                colors = CardDefaults.cardColors(containerColor = if (selectedItemId == item.id) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface)
            ) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(item.name, fontWeight = FontWeight.Bold)
                            Text(item.sku.ifBlank { "Sans référence" } + " · " + item.unit, style = MaterialTheme.typography.bodySmall)
                            val value = valuations.firstOrNull { it.inventoryItemId == item.id }
                            Text(localizedLabel("Coût unitaire : ","Unit cost: ","Njoɓdi gootal : ") + (value?.unitCostXaf?.toString() ?: "—") + " F", style = MaterialTheme.typography.bodySmall)
                            Text(localizedLabel("Prix de vente : ","Sale price: ","Njoɓdi jaaygol : ") + (value?.sellingPriceXaf?.toString() ?: "—") + " F", style = MaterialTheme.typography.bodySmall)
                            Text(localizedLabel("WhatsApp fournisseur : ","Supplier WhatsApp: ","WhatsApp hokkooɗo jawdi : ") + (item.supplierWhatsApp.ifBlank { "Non renseigné" }), style = MaterialTheme.typography.bodySmall)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(item.quantity.toString() + " " + item.unit, fontWeight = FontWeight.Bold)
                            Text(if (item.quantity <= item.reorderLevel) "Seuil atteint" else "Stock disponible", color = if (item.quantity <= item.reorderLevel) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                    if (item.quantity <= item.reorderLevel) {
                        val suggestedQty = (item.reorderLevel * 2.0 - item.quantity).coerceAtLeast(1.0)
                        OutlinedButton(
                            onClick = {
                                val phone = item.supplierWhatsApp.filter(Char::isDigit)
                                if (phone.length < 9) {
                                    selectedItemId = item.id
                                    supplierWhatsApp = item.supplierWhatsApp
                                    error = "Ajoute d'abord le numéro WhatsApp du fournisseur dans la fiche de l'article."
                                } else {
                                    val orderText = "Bonjour, je souhaite commander " + suggestedQty + " " + item.unit +
                                        " de " + item.name + " (SKU " + item.sku + "). Stock actuel : " + item.quantity +
                                        " " + item.unit + " ; seuil d'alerte : " + item.reorderLevel +
                                        " " + item.unit + ". Merci de confirmer disponibilité, prix et délai."
                                    val url = "https://wa.me/" + phone + "?text=" + android.net.Uri.encode(orderText)
                                    runCatching {
                                        context.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url)))
                                    }.onFailure { error = "WhatsApp ou navigateur indisponible sur cet appareil." }
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(localizedLabel("Préparer la commande sur WhatsApp · ","Prepare order on WhatsApp · ","Heblu ɗaɓɓitannde e WhatsApp · ") + suggestedQty + " " + item.unit) }
                    }
                }
            }
        }
        if (selected != null) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(localizedLabel("Mouvement : ","Movement: ","Dirtugol : ") + selected.name, fontWeight = FontWeight.Bold)
                        if (supplierWhatsApp.isBlank()) supplierWhatsApp = selected.supplierWhatsApp
                        OutlinedTextField(supplierWhatsApp, { supplierWhatsApp = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("WhatsApp fournisseur (indicatif pays + numéro)","Supplier WhatsApp (country code + number)","WhatsApp hokkooɗo jawdi (innol leydi + tonngoode)")) }, singleLine = true)
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    runCatching { repository.saveSupplierWhatsApp(session.account.organizationId, siteId, selected.id, supplierWhatsApp) }
                                        .onSuccess { supplierWhatsApp = it.supplierWhatsApp; notice = "Contact WhatsApp fournisseur enregistré." }
                                        .onFailure { error = it.message ?: "Enregistrement du contact impossible." }
                                }
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(localizedLabel("Enregistrer le contact fournisseur","Save supplier contact","Danndu telefon hokkooɗo jawdi")) }
                        val savedValue = valuations.firstOrNull { it.inventoryItemId == selected.id }
                        if (unitCostXaf.isBlank()) unitCostXaf = savedValue?.unitCostXaf?.toString() ?: ""
                        if (sellingPriceXaf.isBlank()) sellingPriceXaf = savedValue?.sellingPriceXaf?.toString() ?: ""
                        OutlinedTextField(unitCostXaf, { unitCostXaf = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Coût d’achat unitaire (FCFA)","Unit purchase cost (XAF)","Njoɓdi soodugol gootal (FCFA)")) }, singleLine = true)
                        OutlinedTextField(sellingPriceXaf, { sellingPriceXaf = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Prix de vente unitaire (FCFA)","Unit sale price (XAF)","Njoɓdi jaaygol gootal (FCFA)")) }, singleLine = true)
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
                        ) { Text(localizedLabel("Enregistrer les coûts et la marge brute unitaire","Save costs and unit margin","Danndu njoɓdi e ceede heddiiɗe gootal")) }
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            (listOf("in", "consumption", "loss", "adjustment") + if (BuildConfig.BILLING_SETTLEMENT_ENABLED && session.account.roleCode in setOf("promoter","network_manager","site_manager")) listOf("count") else emptyList()).forEach { type ->
                                OutlinedButton(onClick = { movementType = type }) { Text((if (movementType == type) "✓ " else "") + (if (type == "count") localizedLabel("Inventaire","Count","Limtagol") else type)) }
                            }
                        }
                        OutlinedTextField(quantity, { quantity = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Quantité","Quantity","Keewal")) }, singleLine = true)
                        OutlinedTextField(reason, { reason = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Motif obligatoire","Reason required","Daliilu waajib")) }, singleLine = true)
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
                                    }.onSuccess { quantity = ""; reason = ""; notice = if (movementType == "count") "Comptage transmis à la file de synchronisation. Le stock ne change qu’après reçu serveur." else "Mouvement de stock enregistré." }
                                        .onFailure { error = it.message ?: "Mouvement impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && (quantity.replace(",", ".").toDoubleOrNull()?.let { if (movementType == "count") it >= 0.0 && it != selected.quantity else it != 0.0 && (movementType == "adjustment" || it > 0.0) } == true) && reason.trim().length >= 3,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(localizedLabel("Valider le mouvement","Confirm movement","Tabbitin dirtugol")) }
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
    require(raw.length <= 20 * 1024 * 1024) { "Le fichier dépasse la limite de 20 Mo." }
    val text = raw.removePrefix("\uFEFF")
    val headerLine = text.lineSequence().firstOrNull {
        it.isNotBlank() && !it.startsWith("#NAXA_STOCK_TEMPLATE")
    } ?: throw IllegalArgumentException("En-tête CSV introuvable.")
    val delimiter = if (headerLine.count { it == ';' } > headerLine.count { it == ',' }) ';' else ','
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
            char == delimiter && !quoted -> { row.add(field.toString()); field.setLength(0) }
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
    val supplierIndex = findColumn("supplier_whatsapp", "whatsapp_supplier", "contact_whatsapp", "whatsapp_fournisseur")
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
                sellingPriceXaf = amount(cell(cells, sellingIndex), "prix de vente", rowNumber),
                supplierWhatsApp = cell(cells, supplierIndex).filter(Char::isDigit)
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
    val supplierPaymentsXaf: Long,
    val costOfGoodsXaf: Long,
    val confirmedSalesCount: Int,
    val uncostedSalesCount: Int,
    val appointments: Int,
    val pressingTickets: Int
) {
    val grossProfitXaf: Long?
        get() = if (confirmedSalesCount > 0 && uncostedSalesCount == 0) salesXaf - costOfGoodsXaf else null
    val operatingResultXaf: Long?
        get() = grossProfitXaf?.minus(expensesXaf)
}

@Composable
fun ReportsContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val scopeKey=session.account.organizationId+":"+session.account.memberId+":"+session.account.activeSiteIds.sorted().joinToString(",")
    val liveScope=androidx.compose.runtime.rememberUpdatedState(scopeKey)
    var rows by remember(scopeKey) { mutableStateOf<List<SiteDailyReport>>(emptyList()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var generatedAt by remember(scopeKey) { mutableStateOf<String?>(null) }
    var exportNotice by remember(scopeKey) { mutableStateOf<String?>(null) }
    var pendingExport by remember(scopeKey) { mutableStateOf<Pair<String,List<List<Any?>>>?>(null) }
    var period by remember(scopeKey) { mutableStateOf("day") }

    fun reportRows(): List<List<Any?>> {
        val header=listOf<Any?>("Point de vente","CA confirmé FCFA","Coûts connus FCFA","Charges FCFA","Marge brute FCFA","Résultat indicatif FCFA","Règlements fournisseurs FCFA","Ventes non chiffrées","Rendez-vous","Tickets pressing")
        return listOf(listOf<Any?>("NAXA SERVICES — rapport local",session.account.organizationName,period,generatedAt.orEmpty()),header)+rows.map { r ->
            listOf<Any?>(session.account.activeSites.firstOrNull { it.id==r.siteId }?.name?:r.siteId,r.salesXaf,r.costOfGoodsXaf,r.expensesXaf,r.grossProfitXaf,r.operatingResultXaf,r.supplierPaymentsXaf,r.uncostedSalesCount,r.appointments,r.pressingTickets)
        }
    }
    val xlsx=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")) { uri ->
        val export=pendingExport;pendingExport=null
        if(uri!=null&&export!=null&&export.first==liveScope.value) runCatching {
            context.contentResolver.openOutputStream(uri,"w")?.use { NativeReportExport.writeXlsx(it,export.second) }?:error("Destination indisponible")
        }.onSuccess { exportNotice="Classeur XLSX enregistré." }.onFailure { error=it.message }
    }
    val pdf=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        val export=pendingExport;pendingExport=null
        if(uri!=null&&export!=null&&export.first==liveScope.value) runCatching {
            context.contentResolver.openOutputStream(uri,"w")?.use { NativeReportExport.writePdf(it,export.second) }?:error("Destination indisponible")
        }.onSuccess { exportNotice="Rapport PDF enregistré." }.onFailure { error=it.message }
    }
    fun refresh() {
        scope.launch {
            if(busy)return@launch
            busy = true; error = null; rows=emptyList();generatedAt=null;exportNotice=null
            val requestedScope=scopeKey
            val requestedPeriod=period
            runCatching {
                val start = Calendar.getInstance(java.util.TimeZone.getTimeZone("Africa/Douala")).apply {
                    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                    if(requestedPeriod=="month")set(Calendar.DAY_OF_MONTH,1)
                    if(requestedPeriod=="year")set(Calendar.DAY_OF_YEAR,1)
                }.timeInMillis
                val end = System.currentTimeMillis()
                session.account.activeSiteIds.map { siteId ->
                    SiteDailyReport(
                        siteId = siteId,
                        salesXaf = repository.dao.observeSalesTotal(session.account.organizationId, siteId, start, end).first(),
                        expensesXaf = repository.dao.observeOperatingExpensesTotal(session.account.organizationId, siteId, start, end).first(),
                        supplierPaymentsXaf = repository.dao.observeSupplierPaymentsTotal(session.account.organizationId, siteId, start, end).first(),
                        costOfGoodsXaf = repository.dao.observeCostOfGoodsTotal(session.account.organizationId, siteId, start, end).first(),
                        confirmedSalesCount = repository.dao.observeConfirmedSalesCount(session.account.organizationId, siteId, start, end).first(),
                        uncostedSalesCount = repository.dao.observeUncostedSalesCount(session.account.organizationId, siteId, start, end).first(),
                        appointments = repository.dao.observeAppointmentCount(session.account.organizationId, siteId, start, end).first(),
                        pressingTickets = repository.dao.observePressingCount(session.account.organizationId, siteId, start, end).first()
                    )
                }
            }.onSuccess {
                if(requestedScope==liveScope.value){rows = it
                generatedAt = java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale.getDefault()).format(java.util.Date())}
            }.onFailure { error = it.message ?: "Calcul du rapport impossible." }
            busy = false
        }
    }

    LaunchedEffect(scopeKey,period) { refresh() }
    val totalSales = rows.sumOf { it.salesXaf }
    val totalExpenses = rows.sumOf { it.expensesXaf }
    val totalSupplierPayments = rows.sumOf { it.supplierPaymentsXaf }
    val totalCostOfGoods = rows.sumOf { it.costOfGoodsXaf }
    val totalConfirmedSales = rows.sumOf { it.confirmedSalesCount }
    val totalUncostedSales = rows.sumOf { it.uncostedSalesCount }
    val grossProfit = if (totalConfirmedSales > 0 && totalUncostedSales == 0) totalSales - totalCostOfGoods else null
    val operatingResult = grossProfit?.minus(totalExpenses)
    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            ModulePageTitle("Rapports et pilotage", "Indicateurs par période, ventilés par point de vente autorisé.")
            LocalOnlyNotice("Rapport fondé sur les données disponibles sur cet appareil. Il ne constitue ni une clôture comptable ni un rapport complet du réseau.")
            Row(horizontalArrangement=Arrangement.spacedBy(6.dp)) {
                listOf("day" to "Jour","month" to "Mois","year" to "Année").forEach { (value,label) -> OutlinedButton(enabled=!busy&&period!=value,onClick={period=value;rows=emptyList();generatedAt=null}) { Text(label) } }
            }
            Button(onClick = { refresh() }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(if (busy) "Calcul…" else "Actualiser le rapport")
            }
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                OutlinedButton(enabled=!busy&&rows.isNotEmpty()&&generatedAt!=null,onClick={pendingExport=scopeKey to reportRows();xlsx.launch("NAXA-Rapport.xlsx")}) { Text("XLSX") }
                OutlinedButton(enabled=!busy&&rows.isNotEmpty()&&generatedAt!=null,onClick={pendingExport=scopeKey to reportRows();pdf.launch("NAXA-Rapport.pdf")}) { Text("PDF") }
            }
            if(exportNotice!=null)Text(exportNotice!!)
            if (!error.isNullOrBlank()) Text(error!!, color = MaterialTheme.colorScheme.error)
            if (!generatedAt.isNullOrBlank()) Text(localizedLabel("Calculé le ","Calculated on ","Limtaama ñalnde ") + generatedAt!!, style = MaterialTheme.typography.labelSmall)
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                    Text(localizedLabel("Consolidation indicative des points autorisés","Indicative overview of authorized locations","Limooje nokkuuji yamiraaɗi tanƴaaɗe"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Chiffre d'affaires confirmé : ","Confirmed revenue: ","Ceede jaaygol tabbitinaaɗe : ") + totalSales + " FCFA")
                    Text(localizedLabel("Coût des ventes connu : ","Known cost of sales: ","Njoɓdi jaaygol anndaaɗi : ") + totalCostOfGoods + " FCFA")
                    Text(localizedLabel("Charges d'exploitation enregistrées : ","Recorded operating expenses: ","Njoɓdi golle danndaaɗi : ") + totalExpenses + " FCFA")
                    Text(localizedLabel("Marge brute : ","Gross margin: ","Ceede heddiiɗe : ") + (grossProfit?.let { "$it FCFA" } ?: "non calculable : au moins une vente n'a pas de coût direct documenté"))
                    Text(localizedLabel("Résultat opérationnel indicatif : ","Indicative operating result: ","Limooje golle tanƴaaɗe : ") + (operatingResult?.let { "$it FCFA" } ?: "non déterminable avec les coûts directs manquants"))
                    Text(localizedLabel("Règlements fournisseurs : ","Supplier payments: ","Njoɓdi hokkooɓe jawdi : ") + totalSupplierPayments + " FCFA · sortie de dette, pas une charge supplémentaire")
                    Text(localizedLabel("Les règlements fournisseurs restent inclus dans la clôture de caisse lorsqu'ils sont en espèces, mais séparés du résultat. Les caisses, stocks et équipes restent détaillés ci-dessous.","Cash supplier payments are included in register closing, separately from profit. Registers, stock and staff are detailed below.","Njoɓdi hokkooɓe jawdi e ceede juuɗe limtetee e uddude keesu, kono seertii e limooje njariñ. Keesuuji, jawdi e golluɓe kollirtee les ɗoo."), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        items(rows) { row ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(15.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(row.siteId, fontWeight = FontWeight.Bold)
                    Text(localizedLabel("CA confirmé : ","Confirmed revenue: ","Ceede jaaygol tabbitinaaɗe : ") + row.salesXaf + " FCFA")
                    Text(localizedLabel("Coût des ventes connu : ","Known cost of sales: ","Njoɓdi jaaygol anndaaɗi : ") + row.costOfGoodsXaf + " FCFA")
                    Text(localizedLabel("Charges d'exploitation : ","Operating expenses: ","Njoɓdi golle : ") + row.expensesXaf + " FCFA")
                    Text(localizedLabel("Marge brute : ","Gross margin: ","Ceede heddiiɗe : ") + (row.grossProfitXaf?.let { "$it FCFA" } ?: "non calculable : coût direct incomplet"))
                    Text(localizedLabel("Résultat opérationnel indicatif : ","Indicative operating result: ","Limooje golle tanƴaaɗe : ") + (row.operatingResultXaf?.let { "$it FCFA" } ?: "non déterminable"))
                    Text(localizedLabel("Règlements fournisseurs : ","Supplier payments: ","Njoɓdi hokkooɓe jawdi : ") + row.supplierPaymentsXaf + " FCFA · hors charges d'exploitation")
                    Text(localizedLabel("Rendez-vous : ","Appointments: ","Sahaaaji : ") + row.appointments + " · Tickets pressing : " + row.pressingTickets)
                }
            }
        }
        if (rows.isEmpty() && !busy) item { Text(localizedLabel("Aucune donnée disponible pour vos points de vente.","No data available for your locations.","Alaa humpito e nokkuuji jaaygol maa."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
                .onFailure { error = it.message ?: "Impossible de charger les emplacements." }
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
                LocalOnlyNotice("Gérez votre profil et vos établissements. Les nouveaux sites doivent être confirmés.")
            } else {
                LocalOnlyNotice("Les nouveaux sites et postes sont en attente d'activation.")
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
                            Text(localizedLabel("Brouillon en attente de confirmation","Draft awaiting confirmation","Golle heblitteeɗe nana fadi tabbitinol"), fontWeight = FontWeight.Bold)
                            Text(profile!!.displayName + " · " + profile!!.businessMode)
                            Text(localizedLabel("Cette modification est en attente de confirmation.","This change is awaiting confirmation.","Waylugol ngol nana fadi tabbitinol."))
                            OutlinedButton(
                                onClick = {
                                    displayName = profile!!.displayName
                                    mode = profile!!.businessMode
                                    locale = profile!!.defaultLocale
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(localizedLabel("Reprendre ce brouillon","Resume draft","Jokku e golle heblitteeɗe")) }
                        }
                    }
                }
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                        Text(localizedLabel("Profil de l’organisation","Business profile","Humpito fedde"), fontWeight = FontWeight.Bold)
                        OutlinedTextField(displayName, { displayName = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Nom commercial","Trade name","Innde jaaygol")) }, singleLine = true, enabled = canManageNetwork)
                        Text(localizedLabel("Choisir le modèle d’exploitation","Choose operating model","Suɓo no golle ɗowtirtee"), fontWeight = FontWeight.SemiBold)
                        if (!canManageNetwork) {
                            Text(localizedLabel("Le modèle d’exploitation est administré par le Promoteur de l’organisation.","The business owner manages the operating model.","Jom golle ɗowtata laawol golle."), color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                            if (locale == "ff-CM") Text(localizedLabel("Traductions Fulfulde en cours de validation ; les contenus non traduits restent en français.","Fulfulde translations are under review; untranslated content remains in French.","Waylugol ɗemngal Fulfulde nana ƴeewtee; binndi ɗi waylaaka keddii e Français."), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
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
                                        notice = "Profil et modèle d’exploitation enregistrés."
                                    }.onFailure { remoteError ->
                                        profileConfirmedHere = false
                                        runCatching { repository.saveOrganizationProfile(orgId, displayName, mode, locale) }
                                            .onSuccess {
                                                notice = "Modification en attente de confirmation."
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
                        ) { Text(localizedLabel("Enregistrer le profil et le modèle","Save profile and operating model","Danndu humpito e laawol golle")) }
                    }
                }
                if (!canManageNetwork) {
                    Text(localizedLabel("Lecture seule pour ce rôle : le Promoteur conserve l’arbitrage du modèle d’organisation.","View-only: the owner controls the operating model.","Yiyde tan: jom golle suɓata laawol golle."))
                }
            }
            item {
                Text(localizedLabel("Règles d’autonomie","Independent operation rules","Laabi golle keeriiɗe"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(localizedLabel("PME : caisse, stock, équipe et activité d’un seul établissement.","Independent business: register, inventory, team and activity at one location.","Golle seeɗa: keesu, jawdi, golluɓe e golle nokkuure wootere."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(localizedLabel("Responsable multi-emplacements : plusieurs postes et plannings dans un même établissement ; caisse rattachée au site.","Multi-workstation manager: several workstations and schedules in one location; shared location register.","Hooreejo nokkuuji golle: nokkuuji e sahaaaji keewɗi e nokkuure wootere; keesu nokkuure."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(localizedLabel("Promoteur : chaque point de vente conserve sa caisse, son stock, son équipe et ses opérations. Le réseau consolide seulement les indicateurs autorisés.","Owner: each location keeps its own register, inventory, team and operations. Only authorized indicators are combined.","Jom golle: nokkuure kala e keesu, jawdi, golluɓe e golle mum. Limooje yamiraaɗe tan renndinetee."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (route == AppRoute.NETWORK || route == AppRoute.SITES) {
            item {
                Text(localizedLabel("Vos points de vente","Your locations","Nokkuuji jaaygol maa"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                if (session.account.activeSites.isEmpty()) Text(localizedLabel("Aucun point de vente affecté.","No assigned locations.","Alaa nokkuure jaaygol yamiraande."))
                else session.account.activeSites.forEachIndexed { index, site ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.fillMaxWidth().padding(13.dp)) {
                            Text(site.name.ifBlank { "Point " + (index + 1).toString() }, fontWeight = FontWeight.Bold)
                            Text(listOf(site.code, site.addressLabel, site.phoneContact).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.bodySmall)
                            Text(localizedLabel("Accès autorisé","Access authorized","Naatugol yamiraama"), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
            item {
                Text(localizedLabel("Brouillons locaux non activés","Inactive drafts","Golle heblitteeɗe ɗe udditaaka"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                localSites.filter { it.syncStatus != "server_confirmed" }.forEach { site ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.fillMaxWidth().padding(13.dp)) {
                            Text(site.name, fontWeight = FontWeight.Bold)
                            Text(site.code + " · " + site.addressLabel)
                            LocalOnlyNotice("En attente d'activation")
                        }
                    }
                }
            }
            if (route == AppRoute.SITES) {
                item {
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(localizedLabel("Créer un point de vente","Create location","Sos nokkuure jaaygol"), fontWeight = FontWeight.Bold)
                            Text(localizedLabel("Le site sera disponible après confirmation.","The location will be available after confirmation.","Nokkuure ndee maa heɓee caggal tabbitinol."), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                            OutlinedTextField(siteCode, { siteCode = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Code interne","Internal code","Innol")) }, singleLine = true)
                            OutlinedTextField(siteName, { siteName = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Nom du point de vente","Location name","Innde nokkuure jaaygol")) }, singleLine = true)
                            OutlinedTextField(address, { address = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Adresse","Address","Nokkuure")) }, singleLine = true)
                            OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Téléphone","Phone","Telefon")) }, singleLine = true)
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
                                                notice = "Point de vente créé et activé."
                                            }
                                            .onFailure { error = it.message ?: "Création du point de vente impossible." }
                                        busy = false
                                    }
                                },
                                enabled = !busy && canManageNetwork && mode == "multi_site_network" && siteCode.isNotBlank() && siteCode.trim().length >= 2 && siteName.isNotBlank(),
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(localizedLabel("Créer le brouillon du point de vente","Create location draft","Heblu nokkuure jaaygol")) }
                            if (!canManageNetwork) Text(localizedLabel("La création des points de vente est réservée au rôle promoteur.","Only the business owner can create locations.","Jom golle tan waawi sosde nokkuuji jaaygol."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
            if (!notice.isNullOrBlank()) item { Text(notice!!, color = MaterialTheme.colorScheme.secondary) }
            if (!error.isNullOrBlank()) item { Text(error!!, color = MaterialTheme.colorScheme.error) }
        }
        if (route == AppRoute.WORKSTATIONS) {
            item {
                Text(localizedLabel("Emplacement dans un établissement","Workstation at a location","Nokkuure golle e nokkuure jaaygol"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                AuthorizedSitePicker(
                    session.account.activeSiteIds,
                    selectedSite,
                    session.account.activeSites.associate { it.id to it.name }
                ) { selectedSite = it }
                Text(localizedLabel("Choisissez un point de vente autorisé.","Choose an authorized location.","Suɓo nokkuure jaaygol yamiraande."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(localizedLabel("Exemples : fauteuil de coiffure, comptoir pressing, atelier, réception ou caisse.","Examples: hairdressing chair, laundry counter, workshop, reception or register.","Yerɗe: jooɗorgal ñaawugol sukundu, jaɓɓorgo lootugol, nokkuure golle, jaɓɓorgo walla keesu."), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(localizedLabel("Créer un emplacement dans ce point de vente","Create workstation at this location","Sos nokkuure golle e nokkuure ndee"), fontWeight = FontWeight.Bold)
                        Text(localizedLabel("L'emplacement sera disponible après confirmation.","The workstation will be available after confirmation.","Nokkuure golle ndee maa heɓee caggal tabbitinol."), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                        OutlinedTextField(workstationCode, { workstationCode = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Code de l’emplacement","Workstation code","Innol nokkuure golle")) }, singleLine = true)
                        OutlinedTextField(workstationName, { workstationName = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Nom de l’emplacement","Workstation name","Innde nokkuure golle")) }, singleLine = true)
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            listOf("hair_chair", "pressing_counter", "pressing_workshop", "reception", "cashier").forEach { type ->
                                OutlinedButton(onClick = { workstationType = type }) { Text(if (workstationType == type) "✓ " + type else type) }
                            }
                        }
                        OutlinedTextField(capacity, { capacity = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Capacité","Capacity","Keewal")) }, singleLine = true)
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
                                        notice = "Emplacement créé et activé."
                                    }.onFailure { error = it.message ?: "Création de l’emplacement impossible." }
                                    busy = false
                                }
                            },
                            enabled = !busy && canManageWorkstations && selectedSite.isNotBlank() && workstationCode.isNotBlank() && workstationName.isNotBlank() && (capacity.toIntOrNull() ?: 0) in 1..100,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(localizedLabel("Ajouter l’emplacement","Add workstation","Ɓeydu nokkuure golle")) }
                        if (!canManageWorkstations) Text(localizedLabel("Gestion réservée aux responsables autorisés.","Only authorized managers can manage this.","Hooreeɓe yamiraaɓe tan mbaawi ɗowtude."), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            item { Text(localizedLabel("Emplacements locaux du point de vente","Location workstations","Nokkuuji golle nokkuure jaaygol"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
            if (workstations.isEmpty()) item { Text(localizedLabel("Aucun emplacement configuré pour ce point de vente.","No workstation configured for this location.","Alaa nokkuure golle teeltaande e nokkuure ndee.")) }
            items(workstations) { item ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.fillMaxWidth().padding(13.dp)) {
                        Text(item.name, fontWeight = FontWeight.Bold)
                        Text(item.code + " · " + item.kind + " · capacité " + item.capacity)
                        if (item.syncStatus == "server_confirmed") {
                            Text(localizedLabel("Actif","Active","Nana golla"), color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.labelSmall)
                        } else {
                            LocalOnlyNotice("Brouillon · non activé")
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
            LocalOnlyNotice("Les demandes en attente seront transmises dès que le service sera disponible.")
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Nouvelle demande","New request","Ɗaɓɓitannde hesere"), fontWeight = FontWeight.Bold)
                    OutlinedTextField(subject, { subject = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Sujet","Subject","Ko ɗaɓɓitaa")) }, singleLine = true)
                    OutlinedTextField(description, { description = it }, Modifier.fillMaxWidth(), label = { Text(localizedLabel("Description détaillée (10 caractères minimum)","Detailed description (at least 10 characters)","Cifagol laaɓtungol (binndi 10 walla ɓuri)")) }, minLines = 4)
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
                    ) { Text(localizedLabel("Enregistrer la demande","Save request","Danndu ɗaɓɓitannde")) }
                }
            }
        }
        item { Text(localizedLabel("Demandes sur cet appareil","Requests on this device","Ɗaɓɓitanɗe e kaɓirgol ngol"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (requests.isEmpty()) item { Text(localizedLabel("Aucune demande enregistrée.","No requests recorded.","Alaa ɗaɓɓitannde danndaande."), color = MaterialTheme.colorScheme.onSurfaceVariant) }
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
    api: AuthApi,
    lightTheme: Boolean,
    onTheme: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var supplierSyncBusy by remember { mutableStateOf(false) }
    var supplierSyncStatus by remember { mutableStateOf<String?>(null) }
    val supplierSyncConfigured = SupplierSyncCoordinator.isConfigured()
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
                    Text(localizedLabel("Apparence","Appearance","No hollirtee"), fontWeight = FontWeight.Bold)
                    Text(if (lightTheme) "Thème clair actif" else "Thème sombre actif")
                    OutlinedButton(onClick = onTheme, modifier = Modifier.fillMaxWidth()) { Text(localizedLabel("Basculer le thème","Change theme","Waylu jayngol")) }
                    Text(localizedLabel("Langue : Français / English — les ressources de l’application sont disponibles dans les deux langues.","Language: French / English / Fulfulde.","Ɗemngal: Français / English / Fulfulde."))
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(localizedLabel("Notifications du téléphone","Phone notifications","Tintine telefon"), fontWeight = FontWeight.Bold)
                    Text(if (permissionGranted) "Notifications autorisées sur cet appareil." else "Les rappels locaux sont programmés, mais Android n’autorise pas encore leur affichage.")
                    if (Build.VERSION.SDK_INT >= 33 && !permissionGranted) {
                        Button(onClick = { permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS) }, modifier = Modifier.fillMaxWidth()) {
                            Text(localizedLabel("Autoriser les notifications","Allow notifications","Yamir tintine"))
                        }
                    }
                    Text(localizedLabel("Vos briefings sont programmés à 07:00 et 19:00.","Your briefings are scheduled at 07:00 and 19:00.","Jaŋte maa teeltaama e 07:00 e 19:00."))
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(localizedLabel("Opérations en attente","Pending operations","Golle fadotooɗe"), fontWeight = FontWeight.Bold)
                    Text(pending.toString() + " événement(s) en attente ou non synchronisé(s)")
                    if (supplierSyncConfigured) {
                        OutlinedButton(
                            onClick = {
                                coroutineScope.launch {
                                    supplierSyncBusy = true
                                    supplierSyncStatus = null
                                    runCatching { SupplierSyncCoordinator.syncPending(repository, api, session) }
                                        .onSuccess { result ->
                                            supplierSyncStatus = "Synchronisés : ${result.applied} · À réessayer : ${result.retried} · Bloqués : ${result.blocked} · Rejetés : ${result.rejected} · Restants : ${result.remaining}"
                                        }
                                        .onFailure { failure ->
                                            supplierSyncStatus = failure.message ?: "Synchronisation impossible."
                                        }
                                    supplierSyncBusy = false
                                }
                            },
                            enabled = !supplierSyncBusy,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(if (supplierSyncBusy) "Synchronisation…" else "Synchroniser les opérations fournisseurs")
                        }
                    } else {
                        LocalOnlyNotice("L'actualisation des fournisseurs est momentanément indisponible.")
                    }
                    supplierSyncStatus?.let { Text(it, color = MaterialTheme.colorScheme.secondary) }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(localizedLabel("Sécurité de l’appareil","Device security","Kisal kaɓirgol"), fontWeight = FontWeight.Bold)
                    Text(localizedLabel("Identifiant interne : ","Account reference: ","Innol konte : ") + session.account.memberId)
                    Text(localizedLabel("Organisation : ","Business: ","Fedde : ") + session.account.organizationId)
                    Text(localizedLabel("Points de vente affectés : ","Assigned locations: ","Nokkuuji jaaygol yamiraaɗi : ") + session.account.activeSiteIds.size)
                    Text(localizedLabel("La conservation de session dépend de l’option « Rester connecté » choisie à la connexion.","Your session is kept only if you chose Stay signed in.","Naatugol maa heddotoo tan so a suɓii heddude e naatugol."))
                }
            }
        }
    }
}

private fun AuthSession.roleCanManageNetwork(): Boolean =
    account.roleCode == "promoter"

private fun AuthSession.roleCanManageWorkstations(): Boolean =
    account.roleCode in setOf("promoter", "network_manager", "site_manager")
