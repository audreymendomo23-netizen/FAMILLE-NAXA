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
            .onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to load promotions."; "ff-CM" -> "Hollugol waawataa."; else -> "Chargement impossible." } }
        busy = false
    }

    fun runAction(action: suspend () -> String?) {
        scope.launch {
            busy = true
            error = null
            notice = null
            runCatching { action() }
                .onSuccess { message ->
                    notice = message ?: when (session.account.defaultLocale) { "en" -> "Operation saved."; "ff-CM" -> "Golle ɗee danndaama."; else -> "Opération enregistrée." }
                    runCatching { reload() }.onFailure { error = it.message }
                }
                .onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Operation failed."; "ff-CM" -> "Golle ɗee waawataa."; else -> "Opération impossible." } }
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
                    Text(when (session.account.defaultLocale) { "en" -> "Customer referrals and wheel"; "ff-CM" -> "Recommandation soottotooɓe e roue"; else -> "Parrainage client et roue" }, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "View your benefits and eligibility requirements."; "ff-CM" -> "Yiy njariñ maa e laabi mum."; else -> "Consultez vos avantages et les conditions d'éligibilité." }, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = onBack) { Text(when (session.account.defaultLocale) { "en" -> "Back"; "ff-CM" -> "Rutto"; else -> "Retour" }) }
            }
            AuthorizedSitePicker(siteIds, siteId, session.account.activeSites.associate { it.id to it.name }) {
                siteId = it
                selectedCustomerId = ""
                generatedCode = ""
            }
            LocalOnlyNotice(when (session.account.defaultLocale) { "en" -> "CRM records remain local until synchronization. Only ID, name, phone and consent are transmitted for referral actions."; "ff-CM" -> "Humpito soottotooɓe heddotoo e kaɓirgol haa hesɗitingol. Innol, innde, telefon e jaɓugol tan neldetee e recommandation."; else -> "Les fiches CRM restent locales jusqu'à la synchronisation. Seuls l'identifiant, le nom, le téléphone et le consentement sont transmis lors d'une action de parrainage." })
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
            OutlinedButton(onClick = { runAction { reload(); when (session.account.defaultLocale) { "en" -> "Data refreshed."; "ff-CM" -> "Humpito hesɗitinaama."; else -> "Données actualisées." } } }, enabled = !busy) {
                Text(when (session.account.defaultLocale) { "en" -> "Refresh"; "ff-CM" -> "Hesɗitin"; else -> "Actualiser" })
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Create a customer referral campaign"; "ff-CM" -> "Sos campagne recommandation soottotooɓe"; else -> "Créer une campagne de parrainage client" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "The Promoter defines the beneficiary and value. No amount is preselected."; "ff-CM" -> "Jom golle suɓata neɗɗo heɓoowo e njariñ mum. Ceede suɓaaka tawo."; else -> "Le Promoteur détermine le bénéficiaire et la valeur. Aucun montant n'est présélectionné." })
                    OutlinedTextField(campaignName, { campaignName = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Name"; "ff-CM" -> "Innde"; else -> "Nom" }) }, singleLine = true)
                    OutlinedTextField(campaignStart, { campaignStart = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Start (YYYY-MM-DD)"; "ff-CM" -> "Fuɗɗagol (AAAA-MM-JJ)"; else -> "Début (AAAA-MM-JJ)" }) }, singleLine = true)
                    OutlinedTextField(campaignEnd, { campaignEnd = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Optional end (YYYY-MM-DD)"; "ff-CM" -> "Timmugol (so a yiɗi) (AAAA-MM-JJ)"; else -> "Fin facultative (AAAA-MM-JJ)" }) }, singleLine = true)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = campaignAllSites, onCheckedChange = { campaignAllSites = it })
                        Text(when (session.account.defaultLocale) { "en" -> "Entire organization"; "ff-CM" -> "Fedde fof"; else -> "Toute l'organisation" })
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { beneficiaryMode = "referrer" }) { Text((if (beneficiaryMode == "referrer") "✓ " else "") + when (session.account.defaultLocale) { "en" -> "Referrer"; "ff-CM" -> "Hollinoowo"; else -> "Parrain" }) }
                        OutlinedButton(onClick = { beneficiaryMode = "both" }) { Text((if (beneficiaryMode == "both") "✓ " else "") + when (session.account.defaultLocale) { "en" -> "Both customers"; "ff-CM" -> "Soottotooɓe ɗiɗo"; else -> "Les deux clients" }) }
                    }
                    listOf(
                        "points" to (when (session.account.defaultLocale) { "en" -> "Points"; "ff-CM" -> "Puwan"; else -> "Points" }),
                        "discount_xaf" to (when (session.account.defaultLocale) { "en" -> "XAF discount"; "ff-CM" -> "Ustu njoɓdi FCFA"; else -> "Remise FCFA" }),
                        "credit_xaf" to (when (session.account.defaultLocale) { "en" -> "Business credit XAF"; "ff-CM" -> "Ñaawoore jaaygol FCFA"; else -> "Crédit commercial FCFA" }),
                        "free_service" to (when (session.account.defaultLocale) { "en" -> "Free service"; "ff-CM" -> "Golle tawa yoɓaaka"; else -> "Prestation offerte" })
                    ).forEach { pair ->
                        OutlinedButton(onClick = { rewardKind = pair.first }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (rewardKind == pair.first) "✓ " else "") + pair.second)
                        }
                    }
                    OutlinedTextField(rewardValue, { rewardValue = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Benefit value"; "ff-CM" -> "Keewal njariñ"; else -> "Valeur de l'avantage" }) }, singleLine = true)
                    OutlinedTextField(minimumSale, { minimumSale = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Minimum paid sale (XAF)"; "ff-CM" -> "Ceede soodugol les (FCFA)"; else -> "Achat payé minimum (FCFA)" }) }, singleLine = true)
                    OutlinedTextField(rewardExpiry, { rewardExpiry = it.filter(Char::isDigit).take(4) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Validity in days (optional)"; "ff-CM" -> "Balɗe huutorgol (so a yiɗi)"; else -> "Validité en jours (facultatif)" }) }, singleLine = true)
                    OutlinedTextField(termsText, { termsText = it.take(10000); termsConfirmed = false }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Terms shown to customers (at least 30 characters)"; "ff-CM" -> "Laabi hollitaaɗi soottotooɗo (binndi 30 walla ɓuri)"; else -> "Conditions affichées au client (30 caractères minimum)" }) }, minLines = 4)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = termsConfirmed, onCheckedChange = { termsConfirmed = it })
                        Text(when (session.account.defaultLocale) { "en" -> "I confirm the settings and terms."; "ff-CM" -> "Mi tabbitinii teelte e laabi."; else -> "Je confirme les paramètres et les conditions." })
                    }
                    Button(
                        onClick = {
                            runAction {
                                val benefit = rewardValue.toLongOrNull() ?: 0L
                                val minimum = minimumSale.toLongOrNull() ?: -1L
                                require(campaignName.trim().length >= 2 && benefit > 0 && minimum >= 0 && termsText.trim().length >= 30 && termsConfirmed) {
                                    when (session.account.defaultLocale) { "en" -> "Complete the fields and confirm the terms."; "ff-CM" -> "Winndu humpito e tabbitin laabi."; else -> "Complète les champs et confirme les conditions." }
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
                                when (session.account.defaultLocale) { "en" -> "Draft created. Review and publish the campaign."; "ff-CM" -> "Golle heblitteeɗe sosaama. Ƴeewto, kisa bayyin campagne."; else -> "Brouillon créé. Vérifie puis publie la campagne." }
                            }
                        },
                        enabled = !busy && campaignName.trim().length >= 2 && rewardValue.toLongOrNull()?.let { it > 0 } == true && termsText.trim().length >= 30 && termsConfirmed,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Create draft"; "ff-CM" -> "Sos golle heblitteeɗe"; else -> "Créer le brouillon" }) }
                }
            }
        }

        item { Text(when (session.account.defaultLocale) { "en" -> "Customer campaigns"; "ff-CM" -> "Campagnes soottotooɓe"; else -> "Campagnes client" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (campaigns.isEmpty()) item { Text(when (session.account.defaultLocale) { "en" -> "No campaigns yet."; "ff-CM" -> "Alaa campagne sosaande."; else -> "Aucune campagne créée." }) }
        else items(campaigns, key = { it.optString("id") }) { campaign ->
            var confirmPublish by rememberSaveable(campaign.optString("id")) { mutableStateOf(false) }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(campaign.optString("name"), fontWeight = FontWeight.Bold)
                    Text((when (session.account.defaultLocale) { "en" -> "Status: "; "ff-CM" -> "Ngonka : "; else -> "État : " }) + campaign.optString("status"))
                    Text((when (session.account.defaultLocale) { "en" -> "Benefit: "; "ff-CM" -> "Njariñ : "; else -> "Avantage : " }) + campaign.optString("reward_kind") + " · " + campaign.optLong("reward_value"))
                    Text((when (session.account.defaultLocale) { "en" -> "Beneficiary: "; "ff-CM" -> "Heɓoowo : "; else -> "Bénéficiaire : " }) + campaign.optString("beneficiary_mode"))
                    Text(campaign.optString("terms_text"), style = MaterialTheme.typography.bodySmall)
                    if (campaign.optString("status") == "draft") {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = confirmPublish, onCheckedChange = { confirmPublish = it })
                            Text(when (session.account.defaultLocale) { "en" -> "I reviewed and confirm these terms."; "ff-CM" -> "Mi tari, mi tabbitinii laabi ɗii."; else -> "J'ai relu et confirme ces conditions." })
                        }
                        Button(
                            onClick = {
                                runAction {
                                    require(confirmPublish) { when (session.account.defaultLocale) { "en" -> "Confirm the terms."; "ff-CM" -> "Tabbitin laabi."; else -> "Confirme les conditions." } }
                                    authApi.customerPromotionsRequest(
                                        session.accessToken,
                                        JSONObject()
                                            .put("action", "publish_customer_referral_campaign")
                                            .put("app_code", "naxa-services")
                                            .put("campaign_id", campaign.optString("id"))
                                            .put("terms_version", campaign.optString("terms_version"))
                                    )
                                    when (session.account.defaultLocale) { "en" -> "Campaign published."; "ff-CM" -> "Campagne bayyinaama."; else -> "Campagne publiée." }
                                }
                            },
                            enabled = !busy && confirmPublish,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Publish campaign"; "ff-CM" -> "Bayyin campagne"; else -> "Publier la campagne" }) }
                    }
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Customer referral codes"; "ff-CM" -> "Kode recommandation soottotooɓe"; else -> "Codes de parrainage des clients" }, fontWeight = FontWeight.Bold)
                    customers.take(100).forEach { customer ->
                        OutlinedButton(onClick = { selectedCustomerId = customer.id; generatedCode = "" }, modifier = Modifier.fillMaxWidth()) {
                            Text((if (selectedCustomerId == customer.id) "✓ " else "") + customer.displayName)
                        }
                    }
                    if (selectedCustomer != null) {
                        Text(if (selectedCustomer.contactConsent) (when (session.account.defaultLocale) { "en" -> "Consent recorded."; "ff-CM" -> "Jaɓugol danndaama."; else -> "Consentement enregistré." }) else (when (session.account.defaultLocale) { "en" -> "Consent missing."; "ff-CM" -> "Alaa jaɓugol."; else -> "Consentement absent." }))
                        Button(
                            onClick = {
                                runAction {
                                    require(selectedCustomer.phoneContact.isNotBlank() && selectedCustomer.contactConsent) {
                                        when (session.account.defaultLocale) { "en" -> "Phone and consent are required."; "ff-CM" -> "Telefon e jaɓugol ko waajib."; else -> "Un téléphone et le consentement sont obligatoires." }
                                    }
                                    val campaign = activeCampaigns.firstOrNull { it.optString("id") == selectedCampaignId }
                                        ?: activeCampaigns.firstOrNull()
                                        ?: throw IllegalStateException(when (session.account.defaultLocale) { "en" -> "No active campaign."; "ff-CM" -> "Alaa campagne huutortee ndee."; else -> "Aucune campagne active." })
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
                                    when (session.account.defaultLocale) { "en" -> "Code ready to share."; "ff-CM" -> "Kode hebiima ngam lollinde."; else -> "Code prêt à partager." }
                                }
                            },
                            enabled = !busy && selectedCustomer.phoneContact.isNotBlank() && selectedCustomer.contactConsent && activeCampaigns.isNotEmpty(),
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Generate or retrieve code"; "ff-CM" -> "Sos walla heɓtu kode"; else -> "Générer ou retrouver le code" }) }
                    }
                    if (generatedCode.isNotBlank()) {
                        Text(generatedCode, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Black)
                        OutlinedButton(onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("NAXA referral", generatedCode))
                            notice = when (session.account.defaultLocale) { "en" -> "Code copied."; "ff-CM" -> "Kode nattaama."; else -> "Code copié." }
                        }, modifier = Modifier.fillMaxWidth()) { Text(when (session.account.defaultLocale) { "en" -> "Copy code"; "ff-CM" -> "Nattu kode"; else -> "Copier le code" }) }
                        OutlinedButton(onClick = {
                            val message = when (session.account.defaultLocale) { "en" -> "Here is my NAXA code: $generatedCode. Present it on your first visit and check the terms with the business."; "ff-CM" -> "Ɗoo ko kode NAXA am : $generatedCode. Hollu kode ngol nde a ari laawol aranol, ƴeewto laabi nokkuure."; else -> "Voici mon code NAXA : $generatedCode. Présente-le lors de ta première visite et consulte les conditions auprès de l'établissement." }
                            val intent = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, message)
                            context.startActivity(Intent.createChooser(intent, when (session.account.defaultLocale) { "en" -> "Share code"; "ff-CM" -> "Lollin kode"; else -> "Partager le code" }))
                        }, modifier = Modifier.fillMaxWidth()) { Text(when (session.account.defaultLocale) { "en" -> "Share (WhatsApp or other)"; "ff-CM" -> "Lollin (WhatsApp walla goɗɗum)"; else -> "Partager (WhatsApp ou autre)" }) }
                    }
                }
            }
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Apply a code to a new customer"; "ff-CM" -> "Jokkondir kode heɓaaɗo e soottotooɗo keso"; else -> "Associer un code reçu à un nouveau client" }, fontWeight = FontWeight.Bold)
                    OutlinedTextField(receivedCode, { receivedCode = it.uppercase().take(15) }, Modifier.fillMaxWidth(), label = { Text("CREF-XXXXXXXXXX") }, singleLine = true)
                    Button(
                        onClick = {
                            runAction {
                                val customer = selectedCustomer ?: throw IllegalStateException(when (session.account.defaultLocale) { "en" -> "Select a customer."; "ff-CM" -> "Suɓo soottotooɗo."; else -> "Sélectionne un client." })
                                require(customer.contactConsent && customer.phoneContact.isNotBlank()) { when (session.account.defaultLocale) { "en" -> "Phone and consent are required."; "ff-CM" -> "Telefon e jaɓugol ko waajib."; else -> "Téléphone et consentement requis." } }
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
                                when (session.account.defaultLocale) { "en" -> "Code linked. Qualification awaits the first fully paid sale confirmed by the server."; "ff-CM" -> "Kode jokkondiraama. Njariñ nana fadi jaaygol aranol yoɓaangol fof e tabbitinol."; else -> "Code associé. La qualification attend la première vente entièrement encaissée et confirmée côté serveur." }
                            }
                        },
                        enabled = !busy && selectedCustomer != null && receivedCode.matches(Regex("^CREF-[A-F0-9]{10}$")),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Apply code"; "ff-CM" -> "Jokkondir kode"; else -> "Associer le code" }) }
                }
            }
        }

        item { Text(when (session.account.defaultLocale) { "en" -> "Referral and reward tracking"; "ff-CM" -> "Rewindo soottotooɓe kollinaaɓe e njariñ"; else -> "Suivi des filleuls et récompenses" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        val referrals = dashboard.optJSONArray("referrals") ?: JSONArray()
        if (referrals.length() == 0) item { Text(when (session.account.defaultLocale) { "en" -> "No referrals yet."; "ff-CM" -> "Alaa soottotooɗo kollinaaɗo."; else -> "Aucun filleul." }) }
        else items(referrals.length()) { index ->
            val row = referrals.optJSONObject(index) ?: JSONObject()
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text((when (session.account.defaultLocale) { "en" -> "Referrer: "; "ff-CM" -> "Hollinoowo : "; else -> "Parrain : " }) + row.optString("referrer_customer_id").take(8))
                    Text((when (session.account.defaultLocale) { "en" -> "Referred: "; "ff-CM" -> "Soottotooɗo kollinaaɗo : "; else -> "Filleul : " }) + row.optString("referred_customer_id").take(8))
                    Text((when (session.account.defaultLocale) { "en" -> "Status: "; "ff-CM" -> "Ngonka : "; else -> "État : " }) + row.optString("status"))
                    if (row.optString("first_paid_at").isNotBlank() && row.optString("first_paid_at") != "null") {
                        Text((when (session.account.defaultLocale) { "en" -> "First paid sale: "; "ff-CM" -> "Jaaygol aranol yoɓaangol : "; else -> "Première vente payée : " }) + row.optString("first_paid_at"))
                    }
                    if (row.optString("rejection_reason").isNotBlank() && row.optString("rejection_reason") != "null") {
                        Text((when (session.account.defaultLocale) { "en" -> "Reason: "; "ff-CM" -> "Daliilu : "; else -> "Motif : " }) + row.optString("rejection_reason"), color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
        val rewards = dashboard.optJSONArray("rewards") ?: JSONArray()
        if (rewards.length() == 0) item { Text(when (session.account.defaultLocale) { "en" -> "No benefits issued yet."; "ff-CM" -> "Alaa njariñ hokkaaɗo."; else -> "Aucun avantage délivré." }) }
        else items(rewards.length()) { index ->
            val row = rewards.optJSONObject(index) ?: JSONObject()
            Text(row.optString("reward_kind") + " · " + row.optLong("reward_value") + " · " + row.optString("status"))
        }

        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Promotional wheel — draft only"; "ff-CM" -> "Roue promotion — heblugol tan"; else -> "Roue promotionnelle — brouillon uniquement" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "Public draws are not available. Written legal qualification and any required Cameroonian authorization are needed before a draw or prize issuance."; "ff-CM" -> "Alaa tirage peñcu. Ɗerewol sariya e yamiroore soklaa e Kameruun hade tirage walla hokkude lot."; else -> "Aucun tirage public n'est disponible. La qualification juridique écrite et les éventuelles autorisations sont nécessaires au Cameroun avant tout tirage ou remise de lot." })
                    OutlinedTextField(wheelTitle, { wheelTitle = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Campaign name"; "ff-CM" -> "Innde campagne"; else -> "Nom de la campagne" }) }, singleLine = true)
                    OutlinedTextField(wheelStart, { wheelStart = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Start date (YYYY-MM-DD)"; "ff-CM" -> "Fuɗɗagol (AAAA-MM-JJ)"; else -> "Début (AAAA-MM-JJ)" }) }, singleLine = true)
                    OutlinedTextField(wheelEnd, { wheelEnd = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Optional end date"; "ff-CM" -> "Timmugol (so a yiɗi)"; else -> "Fin facultative" }) }, singleLine = true)
                    Button(
                        onClick = {
                            runAction {
                                require(wheelTitle.trim().length >= 2) { when (session.account.defaultLocale) { "en" -> "Campaign name required."; "ff-CM" -> "Innde ko waajib."; else -> "Nom obligatoire." } }
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
                                when (session.account.defaultLocale) { "en" -> "Draft created. The wheel remains disabled."; "ff-CM" -> "Golle heblitteeɗe sosaama. Roue heddotoo uddaa."; else -> "Brouillon créé. La roue reste désactivée." }
                            }
                        },
                        enabled = !busy && wheelTitle.trim().length >= 2,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Create draft"; "ff-CM" -> "Sos golle heblitteeɗe"; else -> "Créer un brouillon" }) }
                }
            }
        }

        item { Text(when (session.account.defaultLocale) { "en" -> "Wheel campaigns and prizes"; "ff-CM" -> "Campagnes roue e lot"; else -> "Campagnes de roue et lots" }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
        if (wheelCampaigns.isEmpty()) item { Text(when (session.account.defaultLocale) { "en" -> "No drafts."; "ff-CM" -> "Alaa golle heblitteeɗe."; else -> "Aucun brouillon." }) }
        else items(wheelCampaigns, key = { it.optString("id") }) { wheel ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(wheel.optString("title"), fontWeight = FontWeight.Bold)
                    Text((when (session.account.defaultLocale) { "en" -> "Status: "; "ff-CM" -> "Ngonka : "; else -> "État : " }) + wheel.optString("status"))
                    OutlinedButton(onClick = { selectedWheelId = wheel.optString("id") }) {
                        Text((if (selectedWheelId == wheel.optString("id")) "✓ " else "") + when (session.account.defaultLocale) { "en" -> "Configure prizes"; "ff-CM" -> "Teeltu lot"; else -> "Configurer les lots" })
                    }
                }
            }
        }
        if (selectedWheelId.isNotBlank()) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                    Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(when (session.account.defaultLocale) { "en" -> "Add a prize to the draft"; "ff-CM" -> "Ɓeydu lot"; else -> "Ajouter un lot au brouillon" }, fontWeight = FontWeight.Bold)
                        OutlinedTextField(prizeLabel, { prizeLabel = it }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Label"; "ff-CM" -> "Innde"; else -> "Libellé" }) }, singleLine = true)
                        listOf(
                            "no_prize" to (when (session.account.defaultLocale) { "en" -> "No prize"; "ff-CM" -> "Alaa njariñ"; else -> "Aucun gain" }),
                            "points" to "Points",
                            "discount_xaf" to (when (session.account.defaultLocale) { "en" -> "XAF discount"; "ff-CM" -> "Ustu njoɓdi FCFA"; else -> "Remise FCFA" }),
                            "credit_xaf" to (when (session.account.defaultLocale) { "en" -> "XAF credit"; "ff-CM" -> "Ñaawoore FCFA"; else -> "Crédit FCFA" }),
                            "free_service" to (when (session.account.defaultLocale) { "en" -> "Free service"; "ff-CM" -> "Golle tawa yoɓaaka"; else -> "Prestation offerte" }),
                            "product" to (when (session.account.defaultLocale) { "en" -> "Product"; "ff-CM" -> "Jawdi"; else -> "Produit" })
                        ).forEach { pair ->
                            OutlinedButton(onClick = { prizeKind = pair.first }) {
                                Text((if (prizeKind == pair.first) "✓ " else "") + pair.second)
                            }
                        }
                        OutlinedTextField(prizeValue, { prizeValue = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Value (0 for no prize)"; "ff-CM" -> "Keewal (0 so alaa njariñ)"; else -> "Valeur (0 si aucun gain)" }) }, singleLine = true)
                        OutlinedTextField(prizeWeight, { prizeWeight = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Relative weight"; "ff-CM" -> "Keewal yerondirgal"; else -> "Poids relatif" }) }, singleLine = true)
                        OutlinedTextField(prizeCap, { prizeCap = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text(when (session.account.defaultLocale) { "en" -> "Prize cap (optional)"; "ff-CM" -> "Keewal lot dow (so a yiɗi)"; else -> "Plafond de lots (facultatif)" }) }, singleLine = true)
                        Button(
                            onClick = {
                                runAction {
                                    val value = prizeValue.toLongOrNull() ?: -1L
                                    val weight = prizeWeight.toIntOrNull() ?: 0
                                    require(prizeLabel.isNotBlank() && value >= 0 && weight > 0 &&
                                        ((prizeKind == "no_prize" && value == 0L) || (prizeKind != "no_prize" && value > 0))) {
                                        when (session.account.defaultLocale) { "en" -> "Check the label, value and weight."; "ff-CM" -> "Ƴeewto innde, keewal e yerondirgal."; else -> "Vérifie le libellé, la valeur et le poids." }
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
                                    when (session.account.defaultLocale) { "en" -> "Prize added to draft."; "ff-CM" -> "Lot ɓeydaama."; else -> "Lot ajouté au brouillon." }
                                }
                            },
                            enabled = !busy,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Add prize"; "ff-CM" -> "Ɓeydu lot"; else -> "Ajouter le lot" }) }
                        if (wheelPrizes.isNotEmpty() && totalWeight > 0) {
                            Text(when (session.account.defaultLocale) { "en" -> "Total weight: $totalWeight"; "ff-CM" -> "Keewal fof : $totalWeight"; else -> "Poids total : $totalWeight" })
                            wheelPrizes.forEach { prize ->
                                val probability = prize.optInt("weight") * 100.0 / totalWeight
                                Text(prize.optString("label") + " · " + DecimalFormat("0.00").format(probability) + "%*")
                            }
                            Text(when (session.account.defaultLocale) { "en" -> "*Draft-only indication, not a published or authorized probability."; "ff-CM" -> "*Humpito heblugol tan, wonaa keewal bayyinaangal walla yamiraangal."; else -> "*Indication du brouillon uniquement, pas une probabilité publiée ou autorisée." }, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}
