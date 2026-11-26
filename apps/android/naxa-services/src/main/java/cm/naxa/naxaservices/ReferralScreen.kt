package cm.naxa.naxaservices

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.auth.ReferralDashboard
import kotlinx.coroutines.launch

@Composable
internal fun ReferralScreen(
    modifier: Modifier,
    session: AuthSession,
    authApi: AuthApi,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val fr = session.account.defaultLocale != "en"
    val isPromoter = session.account.roleCode == "promoter"
    var dashboard by remember { mutableStateOf<ReferralDashboard?>(null) }
    var referralCodeInput by rememberSaveable(session.account.organizationId) { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }

    suspend fun reload() {
        dashboard = authApi.referralDashboard(session.accessToken)
    }

    LaunchedEffect(session.account.organizationId) {
        busy = true
        runCatching { reload() }
            .onFailure { error = it.message ?: "Impossible de charger le parrainage." }
        busy = false
    }

    fun runAction(action: suspend () -> Unit) {
        scope.launch {
            busy = true
            error = null
            notice = null
            runCatching { action(); reload() }
                .onSuccess { notice = when (session.account.defaultLocale) { "en" -> "Operation saved."; "ff-CM" -> "Golle ɗee danndaama."; else -> "Opération enregistrée." } }
                .onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Operation failed."; "ff-CM" -> "Golle ɗee waawataa."; else -> "Opération impossible." } }
            busy = false
        }
    }

    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column(Modifier.weight(1f)) {
                    Text(when (session.account.defaultLocale) { "en" -> "SME referrals"; "ff-CM" -> "Hollinde NAXA e golle goɗɗe"; else -> "Parrainage PME" }, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(
                        when (session.account.defaultLocale) { "en" -> "Refer five SMEs that each complete their first paid subscription. Every group of five earns a benefit."; "ff-CM" -> "Hollin NAXA e golle joy ɗe kala yoɓi abonman arano. Golle joy kala addata njariñ."; else -> "Parrainez cinq PME qui réalisent chacune leur premier abonnement payé. Chaque groupe de cinq déclenche un avantage." },
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                OutlinedButton(onClick = onBack) { Text(when (session.account.defaultLocale) { "en" -> "Back"; "ff-CM" -> "Rutto"; else -> "Retour" }) }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "My referral code"; "ff-CM" -> "Kode recommandation am"; else -> "Mon code de parrainage" }, fontWeight = FontWeight.Bold)
                    if (!isPromoter) {
                        Text(when (session.account.defaultLocale) { "en" -> "Referral management is reserved for the organization Promoter."; "ff-CM" -> "Jom golle tan waawi ɗowtude recommandation."; else -> "La gestion du parrainage est réservée au Promoteur de l’organisation." })
                    } else if (dashboard?.code != null) {
                        Text(dashboard!!.code!!, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.primary)
                        OutlinedButton(onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("NAXA SERVICES referral code", dashboard!!.code!!))
                            notice = when (session.account.defaultLocale) { "en" -> "Code copied."; "ff-CM" -> "Kode nattaama."; else -> "Code copié." }
                        }) { Text(when (session.account.defaultLocale) { "en" -> "Copy code"; "ff-CM" -> "Nattu kode"; else -> "Copier le code" }) }
                    } else {
                        Text(when (session.account.defaultLocale) { "en" -> "No active code for this organization."; "ff-CM" -> "Alaa kode huutorteeɗo e fedde ndee."; else -> "Aucun code actif pour cette organisation." })
                        Button(onClick = { runAction { authApi.generateReferralCode(session.accessToken) } }, enabled = !busy) {
                            Text(when (session.account.defaultLocale) { "en" -> "Generate referral code"; "ff-CM" -> "Sos kode recommandation"; else -> "Générer un code de parrainage" })
                        }
                    }
                    if (busy) CircularProgressIndicator()
                    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                }
            }
        }
        item {
            val data = dashboard
            val progress = (data?.progressInCurrentWave ?: 0).coerceIn(0, 4)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Track my rewards"; "ff-CM" -> "Rewindo njariñ am"; else -> "Suivre mes gains" }, fontWeight = FontWeight.Bold)
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(when (session.account.defaultLocale) { "en" -> "SMEs referred: ${data?.referredCount ?: 0}"; "ff-CM" -> "Golle winnditaaɗe : ${data?.referredCount ?: 0}"; else -> "PME inscrites : ${data?.referredCount ?: 0}" })
                        Text(when (session.account.defaultLocale) { "en" -> "Activated: ${data?.activatedCount ?: 0}"; "ff-CM" -> "Abonman fuɗɗii : ${data?.activatedCount ?: 0}"; else -> "Activées : ${data?.activatedCount ?: 0}" })
                    }
                    Text(
                        when (session.account.defaultLocale) { "en" -> "Wave ${data?.nextWaveNumber ?: 1}: $progress / 5 first paid subscriptions"; "ff-CM" -> "Fedde ${data?.nextWaveNumber ?: 1} : $progress / 5 abonman arande yoɓaaɗe"; else -> "Vague ${data?.nextWaveNumber ?: 1} : $progress / 5 premières souscriptions payées" }
                    )
                    LinearProgressIndicator(progress = progress / 5f, modifier = Modifier.fillMaxWidth())
                    Text(
                        when (session.account.defaultLocale) { "en" -> "A referral counts only after the server confirms the referred SME's first paid subscription."; "ff-CM" -> "Limtol waɗata tan caggal tabbitinol njoɓdi abonman arano."; else -> "Une activation est comptée seulement après confirmation serveur du premier abonnement payé du filleul." },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Referred SMEs and activations"; "ff-CM" -> "Golle kollinaaɗe e abonman"; else -> "PME parrainées et activations" }, fontWeight = FontWeight.Bold) }
        if (dashboard?.referrals.isNullOrEmpty()) {
            item { Text(when (session.account.defaultLocale) { "en" -> "No SMEs have used your code yet."; "ff-CM" -> "Alaa golle kuutortooɗe kode maa jooni."; else -> "Aucune PME rattachée à votre code pour le moment." }) }
        } else {
            items(dashboard!!.referrals) { referral ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(referral.organizationName, fontWeight = FontWeight.SemiBold)
                        Text(
                            if (referral.status == "qualified") {
                                when (session.account.defaultLocale) { "en" -> "First paid subscription confirmed"; "ff-CM" -> "Abonman arano yoɓaama tabbitinaama"; else -> "Premier abonnement payé confirmé" }
                            } else {
                                when (session.account.defaultLocale) { "en" -> "Registration received — activation pending"; "ff-CM" -> "Winnditagol heɓaama — nana fadi njoɓdi"; else -> "Inscription reçue — activation en attente" }
                            },
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text((when (session.account.defaultLocale) { "en" -> "Joined: "; "ff-CM" -> "Winnditagol : "; else -> "Inscription : " }) + referral.referredAt)
                        Text((when (session.account.defaultLocale) { "en" -> "Activated: "; "ff-CM" -> "Fuɗɗagol : "; else -> "Activation : " }) + (referral.activatedAt ?: when (session.account.defaultLocale) { "en" -> "Pending"; "ff-CM" -> "Nana fadi"; else -> "En attente" }))
                    }
                }
            }
        }
        item { Text(when (session.account.defaultLocale) { "en" -> "Wave rewards"; "ff-CM" -> "Njariñ fedde kala"; else -> "Récompenses par vague" }, fontWeight = FontWeight.Bold) }
        if (dashboard?.rewards.isNullOrEmpty()) {
            item { Text(when (session.account.defaultLocale) { "en" -> "No rewards earned yet. Waves are calculated in separate groups of five activated SMEs."; "ff-CM" -> "Alaa njariñ heɓaango. Fedde kala ko golle joy ɗe abonman mum fuɗɗii."; else -> "Aucune récompense acquise. Les vagues sont calculées par groupes distincts de cinq PME activées." }) }
        } else {
            items(dashboard!!.rewards) { reward ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(when (session.account.defaultLocale) { "en" -> "Wave ${reward.waveNumber}"; "ff-CM" -> "Fedde ${reward.waveNumber}"; else -> "Vague ${reward.waveNumber}" }, fontWeight = FontWeight.SemiBold)
                        Text(
                            when (reward.rewardKind) {
                                "monthly_free_cycle" -> when (session.account.defaultLocale) { "en" -> "One free monthly renewal"; "ff-CM" -> "Lewru wooturu tawa yoɓaaka"; else -> "Un cycle mensuel gratuit" }
                                "annual_extension_month" -> when (session.account.defaultLocale) { "en" -> "One extra month at annual expiry"; "ff-CM" -> "Lewru goɗɗuru caggal timmugol hitaande"; else -> "Un mois supplémentaire à l’expiration de l’annuel" }
                                else -> reward.rewardKind
                            }
                        )
                        Text((when (session.account.defaultLocale) { "en" -> "Status: "; "ff-CM" -> "Ngonka : "; else -> "État : " }) + reward.status)
                        Text((when (session.account.defaultLocale) { "en" -> "Earned: "; "ff-CM" -> "Heɓaama ñalnde : "; else -> "Obtenue le : " }) + reward.createdAt)
                        if (reward.appliedAt != null) Text((when (session.account.defaultLocale) { "en" -> "Applied: "; "ff-CM" -> "Huutoraama ñalnde : "; else -> "Appliquée le : " }) + reward.appliedAt)
                    }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "I received a code"; "ff-CM" -> "Mi heɓii kode"; else -> "J’ai reçu un code" }, fontWeight = FontWeight.Bold)
                    Text(when (session.account.defaultLocale) { "en" -> "The referred SME's Promoter can register the code once, before its first paid activation."; "ff-CM" -> "Jom golle waawi danndude kode laawol gootol hade njoɓdi abonman arano."; else -> "Le Promoteur de la PME filleule peut enregistrer le code une seule fois, avant sa première activation payante." })
                    OutlinedTextField(
                        value = referralCodeInput,
                        onValueChange = { referralCodeInput = it.uppercase().take(10) },
                        label = { Text(when (session.account.defaultLocale) { "en" -> "Referral code"; "ff-CM" -> "Kode recommandation"; else -> "Code de parrainage" }) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Button(
                        onClick = { runAction { authApi.applyReferralCode(session.accessToken, referralCodeInput) } },
                        enabled = !busy && isPromoter && referralCodeInput.matches(Regex("^NS-[A-Z0-9]{7}$"))
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Apply received code"; "ff-CM" -> "Tabbitin kode heɓaaɗo"; else -> "Valider le code reçu" }) }
                }
            }
        }
        item { Spacer(Modifier.height(22.dp)) }
    }
}
