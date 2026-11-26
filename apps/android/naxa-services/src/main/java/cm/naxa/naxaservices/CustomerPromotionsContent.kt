package cm.naxa.naxaservices

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
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
import androidx.compose.material3.Checkbox
import androidx.compose.material3.LinearProgressIndicator
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
import cm.naxa.naxaservices.data.LocalCustomer
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.text.DecimalFormat
import java.time.LocalDate
import java.time.ZoneId

@Composable
internal fun CustomerPromotionsContent(
    modifier: Modifier,
    repository: NaxaServicesLocalRepository,
    session: AuthSession,
    authApi: AuthApi,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    val orgId = session.account.organizationId
    val siteIds = session.account.activeSiteIds
    var siteId by rememberSaveable(orgId) { mutableStateOf(siteIds.firstOrNull().orEmpty()) }
    val customers by remember(siteId) { repository.dao.observeCustomers(orgId, siteId) }.collectAsState(initial = emptyList())

    var dashboard by remember { mutableStateOf(JSONObject()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var selectedCustomerId by rememberSaveable(siteId) { mutableStateOf("") }
    var selectedCampaignId by rememberSaveable { mutableStateOf("") }
    var generatedCode by rememberSaveable { mutableStateOf("") }
    var receivedCode by rememberSaveable { mutableStateOf("") }

    var campaignName by rememberSaveable { mutableStateOf("") }
    var campaignStart by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    var campaignEnd by rememberSaveable { mutableStateOf("") }
    var campaignAllSites by rememberSaveable { mutableStateOf(true) }
    var beneficiaryMode by rememberSaveable { mutableStateOf("referrer") }
    var rewardKind by rememberSaveable { mutableStateOf("points") }
    var rewardValue by rememberSaveable { mutableStateOf("") }
    var minimumSale by rememberSaveable { mutableStateOf("0") }
    var rewardExpiry by rememberSaveable { mutableStateOf("") }
    var termsText by rememberSaveable { mutableStateOf("") }
    var termsConfirmed by rememberSaveable { mutableStateOf(false) }

    var wheelTitle by rememberSaveable { mutableStateOf("") }
    var wheelStart by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    var wheelEnd by rememberSaveable { mutableStateOf("") }
    var selectedWheelId by rememberSaveable { mutableStateOf("") }
    var prizeLabel by rememberSaveable { mutableStateOf("") }
    var prizeKind by rememberSaveable { mutableStateOf("no_prize") }
    var prizeValue by rememberSaveable { mutableStateOf("0") }
    var prizeWeight by rememberSaveable { mutableStateOf("1") }
    var prizeCap by rememberSaveable { mutableStateOf("") }

    fun customerSnapshot(customer: LocalCustomer) = JSONObject()
        .put("id", customer.id)
        .put("display_name", customer.displayName)
        .put("phone_contact", customer.phoneContact)
        .put("contact_consent", customer.contactConsent)

    suspend fun reload() {
        val response = authApi.customerPromotionsRequest(
            session.accessToken,
            JSONObject().put("action", "customer_referral_dashboard").put("app_code", "naxa-services")
        )
        dashboard = response.optJSONObject("result") ?: JSONObject()
        if (selectedCampaignId.isBlank()) {
            val campaigns = dashboard.optJSONArray("campaigns") ?: JSONArray()
            for (i in 0 until campaigns.length()) {
                val row = campaigns.optJSONObject(i) ?: continue
                if (row.optString("status") == "active") {
                    selectedCampaignId = row.optString("id")
                    break
                }
            }
        }
        if (selectedWheelId.isBlank()) {
            val wheels = dashboard.optJSONArray("wheel_campaigns") ?: JSONArray()
            if (wheels.length() > 0) selectedWheelId = wheels.optJSONObject(0)?.optString("id").orEmpty()
        }
    }

    LaunchedEffect(orgId) {
        busy = true
        runCatching { reload() }
            .onFailure { error = it.message ?: if (fr) "Chargement impossible." else "Unable to load promotions." }
        busy = false
    }

    fun runAction(action: suspend () -> String?) {
        scope.launch {
            busy = true
            error = null
            notice = null
            runCatching { action() }
                .onSuccess { message ->
                    notice = message ?: if (fr) "Opération enregistrée." else "Operation saved."
                    runCatching { reload() }.onFailure { error = it.message }
                }
                .onFailure { error = it.message ?: if (fr) "Opération impossible." else "Operation failed." }
            busy = false
        }
    }

    fun isoDate(value: String, endOfDay: Boolean = false): String {
        val date = LocalDate.parse(value.trim())
        val local = if (endOfDay) date.atTime(23, 59, 59) else date.atStartOfDay()
        return local.atZone(ZoneId.systemDefault()).toInstant().toString()
    }

    val campaigns = buildList {
        val array = dashboard.optJSONArray("campaigns") ?: JSONArray()
        for (i in 0 until array.length()) array.optJSONObject(i)?.let { add(it) }
    }
    val activeCampaigns = campaigns.filter { it.optString("status") == "active" }
    val wheelCampaigns = buildList {
        val array = dashboard.optJSONArray("wheel_campaigns") ?: JSONArray()
        for (i in 0 until array.length()) array.optJSONObject(i)?.let { add(it) }
    }
    val wheelPrizes = buildList {
        val array = dashboard.optJSONArray("wheel_prizes") ?: JSONArray()
        for (i in 0 until array.length()) array.optJSONObject(i)?.let { add(it) }
    }.filter { it.optString("campaign_id") == selectedWheelId && it.optBoolean("active", false) }
    val totalWeight = wheelPrizes.sumOf { it.optInt("weight", 0) }.coerceAtLeast(0)
    val selectedCustomer = customers.firstOrNull { it.id == selectedCustomerId && it.orgId == orgId && it.siteId == siteId }

    LazyColumn(modifier.fillMaxSize().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(if (fr) "Parrainage client et roue" else "Customer referrals and wheel", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(if (fr) "Consultez vos avantages et les conditions d'éligibilité." else "View your benefits and eligibility requirements.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = onBack) { Text(if (fr) "Retour" else "Back") }
            }
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) {
                siteId = it
                selectedCustomerId = ""
                generatedCode = ""
            }
            LocalOnlyNotice(if (fr) "Les fiches CRM restent locales jusqu'à la synchronisation. Seuls l'identifiant, le nom, le téléphone et le consentement sont transmis lors d'une action de parrainage." else "CRM records remain local until synchronization. Only ID, name, phone and consent are transmitted for referral actions.")
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
            OutlinedButton(onClick = { runAction { reload(); if (fr) "Données actualisées." else "Data refreshed." } }, enabled = !busy) {
                Text(if (fr) "Actualiser" else "Refresh")
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Créer une campagne de parrainage client" else "Create a customer referral campaign", fontWeight = FontWeight.Bold)
                    Text(if (fr) "Le Promoteur détermine le bénéficiaire et la valeur. Aucun montant n'est présélectionné." else "The Promoter defines the beneficiary and value. No amount is preselected.")
                    OutlinedTextField(campaignName, { campaignName = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Nom" else "Name") }, singleLine = true)
                    OutlinedTextField(campaignStart, { campaignStart = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Début (AAAA-MM-JJ)" else "Start (YYYY-MM-DD)") }, singleLine = true)
                    OutlinedTextField(campaignEnd, { campaignEnd = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Fin facultative (AAAA-MM-JJ)" else "Optional end (YYYY-MM-DD)") }, singleLine = true)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = campaignAllSites, onCheckedChange = { campaignAllSites = it })
                        Text(if (fr) "Toute l'organisation" else "Entire organization")
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { beneficiaryMode = "referrer" }) { Text((if (beneficiaryMode == "referrer") "✓ " else "") + if (fr) "Parrain" else "Referrer") }
                        OutlinedButton(onClick = { beneficiaryMode = "both" }) { Text((if (beneficiaryMode == "both") "✓ " else "") + if (fr) "Les deux clients" else "Both customers") }
                    }
                    listOf(
                        "points" to (if (fr) "Points" else "Points"),
                        "discount_xaf" to (if (fr) "Remise FCFA" else "XAF discount"),
                        "credit_xaf" to (if (fr) "Crédit commercial FCFA" else "Business credit XAF"),
                        "free_service" to (if (fr) "Prestation offerte" else "Free service")
                    ).forEach { pair ->
                        OutlinedButton(onClick = { rewardKind = pair.first }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (rewardKind == pair.first) "✓ " else "") + pair.second)
                        }
                    }
                    OutlinedTextField(rewardValue, { rewardValue = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Valeur de l'avantage" else "Benefit value") }, singleLine = true)
                    OutlinedTextField(minimumSale, { minimumSale = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Achat payé minimum (FCFA)" else "Minimum paid sale (XAF)") }, singleLine = true)
                    OutlinedTextField(rewardExpiry, { rewardExpiry = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Validité en jours (facultatif)" else "Validity in days (optional)") }, singleLine = true)
                    OutlinedTextField(termsText, { termsText = it.take(10000); termsConfirmed = false }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Conditions affichées au client (30 caractères minimum)" else "Terms shown to customers (at least 30 characters)") }, minLines = 4)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = termsConfirmed, onCheckedChange = { termsConfirmed = it })
                        Text(if (fr) "Je confirme les paramètres et les conditions." else "I confirm the settings and terms.")
                    }
                    Button(
                        onClick = {
                            runAction {
                                val benefit = rewardValue.toLongOrNull() ?: 0L
                                val minimum = minimumSale.toLongOrNull() ?: -1L
                                require(campaignName.trim().length >= 2 && benefit > 0 && minimum >= 0 && termsText.trim().length >= 30 && termsConfirmed) {
                                    if (fr) "Complète les champs et confirme les conditions." else "Complete the fields and confirm the terms."
                                }
                                authApi.customerPromotionsRequest(
                                    session.accessToken,
                                    JSONObject()
                                        .put("action", "create_customer_referral_campaign")
                                        .put("app_code", "naxa-services")
                                        .put("site_id", if (campaignAllSites) JSONObject.NULL else siteId)
                                        .put("name", campaignName.trim())
                                        .put("starts_at", isoDate(campaignStart))
                                        .put("ends_at", if (campaignEnd.isBlank()) JSONObject.NULL else isoDate(campaignEnd, true))
                                        .put("beneficiary_mode", beneficiaryMode)
                                        .put("reward_kind", rewardKind)
                                        .put("reward_value", benefit)
                                        .put("minimum_paid_sale_xaf", minimum)
                                        .put("reward_expiry_days", rewardExpiry.toIntOrNull() ?: JSONObject.NULL)
                                        .put("terms_version", "NAXA-CLIENT-REFERRAL-V1")
                                        .put("terms_text", termsText.trim())
                                )
                                campaignName = ""
                                if (fr) "Brouillon créé. Vérifie puis publie la campagne." else "Draft created. Review and publish the campaign."
                            }
                        },
                        enabled = !busy && campaignName.trim().length >= 2 && rewardValue.toLongOrNull()?.let { it > 0 } == true && termsText.trim().length >= 30 && termsConfirmed,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (fr) "Créer le brouillon" else "Create draft") }
                }
            }
        }

        item { Text(if (fr) "Campagnes client" else "Customer campaigns", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (campaigns.isEmpty()) item { Text(if (fr) "Aucune campagne créée." else "No campaigns yet.") }
        else items(campaigns, key = { it.optString("id") }) { campaign ->
            var confirmPublish by rememberSaveable(campaign.optString("id")) { mutableStateOf(false) }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(campaign.optString("name"), fontWeight = FontWeight.Bold)
                    Text((if (fr) "État : " else "Status: ") + campaign.optString("status"))
                    Text((if (fr) "Avantage : " else "Benefit: ") + campaign.optString("reward_kind") + " · " + campaign.optLong("reward_value"))
                    Text((if (fr) "Bénéficiaire : " else "Beneficiary: ") + campaign.optString("beneficiary_mode"))
                    Text(campaign.optString("terms_text"), style = MaterialTheme.typography.bodySmall)
                    if (campaign.optString("status") == "draft") {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = confirmPublish, onCheckedChange = { confirmPublish = it })
                            Text(if (fr) "J'ai relu et confirme ces conditions." else "I reviewed and confirm these terms.")
                        }
                        Button(
                            onClick = {
                                runAction {
                                    require(confirmPublish) { if (fr) "Confirme les conditions." else "Confirm the terms." }
                                    authApi.customerPromotionsRequest(
                                        session.accessToken,
                                        JSONObject()
                                            .put("action", "publish_customer_referral_campaign")
                                            .put("app_code", "naxa-services")
                                            .put("campaign_id", campaign.optString("id"))
                                            .put("terms_version", campaign.optString("terms_version"))
                                    )
                                    if (fr) "Campagne publiée." else "Campaign published."
                                }
                            },
                            enabled = !busy && confirmPublish,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (fr) "Publier la campagne" else "Publish campaign") }
                    }
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Codes de parrainage des clients" else "Customer referral codes", fontWeight = FontWeight.Bold)
                    customers.take(100).forEach { customer ->
                        OutlinedButton(onClick = { selectedCustomerId = customer.id; generatedCode = "" }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (selectedCustomerId == customer.id) "✓ " else "") + customer.displayName)
                        }
                    }
                    if (selectedCustomer != null) {
                        Text(if (selectedCustomer.contactConsent) (if (fr) "Consentement enregistré." else "Consent recorded.") else (if (fr) "Consentement absent." else "Consent missing."))
                        Button(
                            onClick = {
                                runAction {
                                    require(selectedCustomer.phoneContact.isNotBlank() && selectedCustomer.contactConsent) {
                                        if (fr) "Un téléphone et le consentement sont obligatoires." else "Phone and consent are required."
                                    }
                                    val campaign = activeCampaigns.firstOrNull { it.optString("id") == selectedCampaignId }
                                        ?: activeCampaigns.firstOrNull()
                                        ?: throw IllegalStateException(if (fr) "Aucune campagne active." else "No active campaign.")
                                    val response = authApi.customerPromotionsRequest(
                                        session.accessToken,
                                        JSONObject()
                                            .put("action", "create_customer_referral_code")
                                            .put("app_code", "naxa-services")
                                            .put("site_id", siteId)
                                            .put("campaign_id", campaign.optString("id"))
                                            .put("customer_id", selectedCustomer.id)
                                            .put("customer_snapshot", customerSnapshot(selectedCustomer))
                                    )
                                    generatedCode = (response.optJSONObject("result") ?: response).optString("code")
                                    require(generatedCode.matches(Regex("^CREF-[A-F0-9]{10}$"))) { "INVALID_CUSTOMER_REFERRAL_CODE" }
                                    if (fr) "Code prêt à partager." else "Code ready to share."
                                }
                            },
                            enabled = !busy && selectedCustomer.phoneContact.isNotBlank() && selectedCustomer.contactConsent && activeCampaigns.isNotEmpty(),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (fr) "Générer ou retrouver le code" else "Generate or retrieve code") }
                    }
                    if (generatedCode.isNotBlank()) {
                        Text(generatedCode, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Black)
                        OutlinedButton(onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("NAXA referral", generatedCode))
                            notice = if (fr) "Code copié." else "Code copied."
                        }, modifier = Modifier.fillMaxWidth()) { Text(if (fr) "Copier le code" else "Copy code") }
                        OutlinedButton(onClick = {
                            val message = if (fr) "Voici mon code NAXA : $generatedCode. Présente-le lors de ta première visite et consulte les conditions auprès de l'établissement." else "Here is my NAXA code: $generatedCode. Present it on your first visit and check the terms with the business."
                            val intent = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, message)
                            context.startActivity(Intent.createChooser(intent, if (fr) "Partager le code" else "Share code"))
                        }, modifier = Modifier.fillMaxWidth()) { Text(if (fr) "Partager (WhatsApp ou autre)" else "Share (WhatsApp or other)") }
                    }
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Associer un code reçu à un nouveau client" else "Apply a code to a new customer", fontWeight = FontWeight.Bold)
                    OutlinedTextField(receivedCode, { receivedCode = it.uppercase().take(15) }, Modifier.fillMaxWidth(), label = { Text("CREF-XXXXXXXXXX") }, singleLine = true)
                    Button(
                        onClick = {
                            runAction {
                                val customer = selectedCustomer ?: throw IllegalStateException(if (fr) "Sélectionne un client." else "Select a customer.")
                                require(customer.contactConsent && customer.phoneContact.isNotBlank()) { if (fr) "Téléphone et consentement requis." else "Phone and consent are required." }
                                authApi.customerPromotionsRequest(
                                    session.accessToken,
                                    JSONObject()
                                        .put("action", "apply_customer_referral_code")
                                        .put("app_code", "naxa-services")
                                        .put("site_id", siteId)
                                        .put("customer_id", customer.id)
                                        .put("referral_code", receivedCode.trim())
                                        .put("customer_snapshot", customerSnapshot(customer))
                                )
                                receivedCode = ""
                                if (fr) "Code associé. La qualification attend la première vente entièrement encaissée et confirmée côté serveur." else "Code linked. Qualification awaits the first fully paid sale confirmed by the server."
                            }
                        },
                        enabled = !busy && selectedCustomer != null && receivedCode.matches(Regex("^CREF-[A-F0-9]{10}$")),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (fr) "Associer le code" else "Apply code") }
                }
            }
        }

        item { Text(if (fr) "Suivi des filleuls et récompenses" else "Referral and reward tracking", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        val referrals = dashboard.optJSONArray("referrals") ?: JSONArray()
        if (referrals.length() == 0) item { Text(if (fr) "Aucun filleul." else "No referrals yet.") }
        else items(referrals.length()) { index ->
            val row = referrals.optJSONObject(index) ?: JSONObject()
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text((if (fr) "Parrain : " else "Referrer: ") + row.optString("referrer_customer_id").take(8))
                    Text((if (fr) "Filleul : " else "Referred: ") + row.optString("referred_customer_id").take(8))
                    Text((if (fr) "État : " else "Status: ") + row.optString("status"))
                    if (row.optString("first_paid_at").isNotBlank() && row.optString("first_paid_at") != "null") {
                        Text((if (fr) "Première vente payée : " else "First paid sale: ") + row.optString("first_paid_at"))
                    }
                    if (row.optString("rejection_reason").isNotBlank() && row.optString("rejection_reason") != "null") {
                        Text((if (fr) "Motif : " else "Reason: ") + row.optString("rejection_reason"), color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
        val rewards = dashboard.optJSONArray("rewards") ?: JSONArray()
        if (rewards.length() == 0) item { Text(if (fr) "Aucun avantage délivré." else "No benefits issued yet.") }
        else items(rewards.length()) { index ->
            val row = rewards.optJSONObject(index) ?: JSONObject()
            Text(row.optString("reward_kind") + " · " + row.optLong("reward_value") + " · " + row.optString("status"))
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "Roue promotionnelle — brouillon uniquement" else "Promotional wheel — draft only", fontWeight = FontWeight.Bold)
                    Text(if (fr) "Aucun tirage public n'est disponible. La qualification juridique écrite et les éventuelles autorisations sont nécessaires au Cameroun avant tout tirage ou remise de lot." else "Public draws are not available. Written legal qualification and any required Cameroonian authorization are needed before a draw or prize issuance.")
                    OutlinedTextField(wheelTitle, { wheelTitle = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Nom de la campagne" else "Campaign name") }, singleLine = true)
                    OutlinedTextField(wheelStart, { wheelStart = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Début (AAAA-MM-JJ)" else "Start date (YYYY-MM-DD)") }, singleLine = true)
                    OutlinedTextField(wheelEnd, { wheelEnd = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Fin facultative" else "Optional end date") }, singleLine = true)
                    Button(
                        onClick = {
                            runAction {
                                require(wheelTitle.trim().length >= 2) { if (fr) "Nom obligatoire." else "Campaign name required." }
                                authApi.customerPromotionsRequest(
                                    session.accessToken,
                                    JSONObject()
                                        .put("action", "create_wheel_campaign")
                                        .put("app_code", "naxa-services")
                                        .put("site_id", siteId)
                                        .put("title", wheelTitle.trim())
                                        .put("starts_at", isoDate(wheelStart))
                                        .put("ends_at", if (wheelEnd.isBlank()) JSONObject.NULL else isoDate(wheelEnd, true))
                                )
                                wheelTitle = ""
                                if (fr) "Brouillon créé. La roue reste désactivée." else "Draft created. The wheel remains disabled."
                            }
                        },
                        enabled = !busy && wheelTitle.trim().length >= 2,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (fr) "Créer un brouillon" else "Create draft") }
                }
            }
        }

        item { Text(if (fr) "Campagnes de roue et lots" else "Wheel campaigns and prizes", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (wheelCampaigns.isEmpty()) item { Text(if (fr) "Aucun brouillon." else "No drafts.") }
        else items(wheelCampaigns, key = { it.optString("id") }) { wheel ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(wheel.optString("title"), fontWeight = FontWeight.Bold)
                    Text((if (fr) "État : " else "Status: ") + wheel.optString("status"))
                    OutlinedButton(onClick = { selectedWheelId = wheel.optString("id") }) {
                        Text((if (selectedWheelId == wheel.optString("id")) "✓ " else "") + if (fr) "Configurer les lots" else "Configure prizes")
                    }
                }
            }
        }
        if (selectedWheelId.isNotBlank()) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(if (fr) "Ajouter un lot au brouillon" else "Add a prize to the draft", fontWeight = FontWeight.Bold)
                        OutlinedTextField(prizeLabel, { prizeLabel = it }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Libellé" else "Label") }, singleLine = true)
                        listOf(
                            "no_prize" to (if (fr) "Aucun gain" else "No prize"),
                            "points" to "Points",
                            "discount_xaf" to (if (fr) "Remise FCFA" else "XAF discount"),
                            "credit_xaf" to (if (fr) "Crédit FCFA" else "XAF credit"),
                            "free_service" to (if (fr) "Prestation offerte" else "Free service"),
                            "product" to (if (fr) "Produit" else "Product")
                        ).forEach { pair ->
                            OutlinedButton(onClick = { prizeKind = pair.first }) {
                                Text((if (prizeKind == pair.first) "✓ " else "") + pair.second)
                            }
                        }
                        OutlinedTextField(prizeValue, { prizeValue = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Valeur (0 si aucun gain)" else "Value (0 for no prize)") }, singleLine = true)
                        OutlinedTextField(prizeWeight, { prizeWeight = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Poids relatif" else "Relative weight") }, singleLine = true)
                        OutlinedTextField(prizeCap, { prizeCap = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(if (fr) "Plafond de lots (facultatif)" else "Prize cap (optional)") }, singleLine = true)
                        Button(
                            onClick = {
                                runAction {
                                    val value = prizeValue.toLongOrNull() ?: -1L
                                    val weight = prizeWeight.toIntOrNull() ?: 0
                                    require(prizeLabel.isNotBlank() && value >= 0 && weight > 0 &&
                                        ((prizeKind == "no_prize" && value == 0L) || (prizeKind != "no_prize" && value > 0))) {
                                        if (fr) "Vérifie le libellé, la valeur et le poids." else "Check the label, value and weight."
                                    }
                                    authApi.customerPromotionsRequest(
                                        session.accessToken,
                                        JSONObject()
                                            .put("action", "add_wheel_prize")
                                            .put("app_code", "naxa-services")
                                            .put("campaign_id", selectedWheelId)
                                            .put("label", prizeLabel.trim())
                                            .put("prize_kind", prizeKind)
                                            .put("reward_value", value)
                                            .put("weight", weight)
                                            .put("max_awards", prizeCap.toIntOrNull() ?: JSONObject.NULL)
                                    )
                                    prizeLabel = ""
                                    prizeValue = "0"
                                    prizeWeight = "1"
                                    prizeCap = ""
                                    if (fr) "Lot ajouté au brouillon." else "Prize added to draft."
                                }
                            },
                            enabled = !busy,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(if (fr) "Ajouter le lot" else "Add prize") }
                        if (wheelPrizes.isNotEmpty() && totalWeight > 0) {
                            Text(if (fr) "Poids total : $totalWeight" else "Total weight: $totalWeight")
                            wheelPrizes.forEach { prize ->
                                val probability = prize.optInt("weight") * 100.0 / totalWeight
                                Text(prize.optString("label") + " · " + DecimalFormat("0.00").format(probability) + "%*")
                            }
                            Text(if (fr) "*Indication du brouillon uniquement, pas une probabilité publiée ou autorisée." else "*Draft-only indication, not a published or authorized probability.", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}
