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
                .onSuccess { notice = if (fr) "Opération enregistrée." else "Operation saved." }
                .onFailure { error = it.message ?: if (fr) "Opération impossible." else "Operation failed." }
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
                    Text(if (fr) "Parrainage PME" else "SME referrals", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(
                        if (fr) "Parrainez cinq PME qui réalisent chacune leur premier abonnement payé. Chaque groupe de cinq déclenche un avantage." else "Refer five SMEs that each complete their first paid subscription. Every group of five earns a benefit.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                OutlinedButton(onClick = onBack) { Text(if (fr) "Retour" else "Back") }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text(if (fr) "Mon code de parrainage" else "My referral code", fontWeight = FontWeight.Bold)
                    if (!isPromoter) {
                        Text(if (fr) "La gestion du parrainage est réservée au Promoteur de l’organisation." else "Referral management is reserved for the organization Promoter.")
                    } else if (dashboard?.code != null) {
                        Text(dashboard!!.code!!, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.primary)
                        OutlinedButton(onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("NAXA SERVICES referral code", dashboard!!.code!!))
                            notice = if (fr) "Code copié." else "Code copied."
                        }) { Text(if (fr) "Copier le code" else "Copy code") }
                    } else {
                        Text(if (fr) "Aucun code actif pour cette organisation." else "No active code for this organization.")
                        Button(onClick = { runAction { authApi.generateReferralCode(session.accessToken) } }, enabled = !busy) {
                            Text(if (fr) "Générer un code de parrainage" else "Generate referral code")
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
                    Text(if (fr) "Suivre mes gains" else "Track my rewards", fontWeight = FontWeight.Bold)
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(if (fr) "PME inscrites : ${data?.referredCount ?: 0}" else "SMEs referred: ${data?.referredCount ?: 0}")
                        Text(if (fr) "Activées : ${data?.activatedCount ?: 0}" else "Activated: ${data?.activatedCount ?: 0}")
                    }
                    Text(
                        if (fr) "Vague ${data?.nextWaveNumber ?: 1} : $progress / 5 premières souscriptions payées" else "Wave ${data?.nextWaveNumber ?: 1}: $progress / 5 first paid subscriptions"
                    )
                    LinearProgressIndicator(progress = progress / 5f, modifier = Modifier.fillMaxWidth())
                    Text(
                        if (fr) "Une activation est comptée seulement après confirmation serveur du premier abonnement payé du filleul." else "A referral counts only after the server confirms the referred SME's first paid subscription.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
        item { Text(if (fr) "PME parrainées et activations" else "Referred SMEs and activations", fontWeight = FontWeight.Bold) }
        if (dashboard?.referrals.isNullOrEmpty()) {
            item { Text(if (fr) "Aucune PME rattachée à votre code pour le moment." else "No SMEs have used your code yet.") }
        } else {
            items(dashboard!!.referrals) { referral ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(referral.organizationName, fontWeight = FontWeight.SemiBold)
                        Text(
                            if (referral.status == "qualified") {
                                if (fr) "Premier abonnement payé confirmé" else "First paid subscription confirmed"
                            } else {
                                if (fr) "Inscription reçue — activation en attente" else "Registration received — activation pending"
                            },
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text((if (fr) "Inscription : " else "Joined: ") + referral.referredAt)
                        Text((if (fr) "Activation : " else "Activated: ") + (referral.activatedAt ?: if (fr) "En attente" else "Pending"))
                    }
                }
            }
        }
        item { Text(if (fr) "Récompenses par vague" else "Wave rewards", fontWeight = FontWeight.Bold) }
        if (dashboard?.rewards.isNullOrEmpty()) {
            item { Text(if (fr) "Aucune récompense acquise. Les vagues sont calculées par groupes distincts de cinq PME activées." else "No rewards earned yet. Waves are calculated in separate groups of five activated SMEs.") }
        } else {
            items(dashboard!!.rewards) { reward ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(if (fr) "Vague ${reward.waveNumber}" else "Wave ${reward.waveNumber}", fontWeight = FontWeight.SemiBold)
                        Text(
                            when (reward.rewardKind) {
                                "monthly_free_cycle" -> if (fr) "Un cycle mensuel gratuit" else "One free monthly renewal"
                                "annual_extension_month" -> if (fr) "Un mois supplémentaire à l’expiration de l’annuel" else "One extra month at annual expiry"
                                else -> reward.rewardKind
                            }
                        )
                        Text((if (fr) "État : " else "Status: ") + reward.status)
                        Text((if (fr) "Obtenue le : " else "Earned: ") + reward.createdAt)
                        if (reward.appliedAt != null) Text((if (fr) "Appliquée le : " else "Applied: ") + reward.appliedAt)
                    }
                }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(if (fr) "J’ai reçu un code" else "I received a code", fontWeight = FontWeight.Bold)
                    Text(if (fr) "Le Promoteur de la PME filleule peut enregistrer le code une seule fois, avant sa première activation payante." else "The referred SME's Promoter can register the code once, before its first paid activation.")
                    OutlinedTextField(
                        value = referralCodeInput,
                        onValueChange = { referralCodeInput = it.uppercase().take(10) },
                        label = { Text(if (fr) "Code de parrainage" else "Referral code") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Button(
                        onClick = { runAction { authApi.applyReferralCode(session.accessToken, referralCodeInput) } },
                        enabled = !busy && isPromoter && referralCodeInput.matches(Regex("^NS-[A-Z0-9]{7}$"))
                    ) { Text(if (fr) "Valider le code reçu" else "Apply received code") }
                }
            }
        }
        item { Spacer(Modifier.height(22.dp)) }
    }
}
