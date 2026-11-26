package cm.naxa.naxaservices

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
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
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cm.naxa.naxaservices.auth.AuthApi
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.auth.NotificationInboxItem
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private fun notificationDateLabel(value: String): String = runCatching {
    DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")
        .withZone(ZoneId.systemDefault())
        .format(Instant.parse(value))
}.getOrDefault(value)

private fun notificationFallbackTitle(eventCode: String, french: Boolean): String {
    val normalized = eventCode.replace('.', '_').replace('-', '_').lowercase()
    val known = mapOf(
        "sale_confirmed" to ("Vente confirmée" to "Sale confirmed"),
        "payment_confirmed" to ("Paiement confirmé" to "Payment confirmed"),
        "appointment_reminder" to ("Rappel de rendez-vous" to "Appointment reminder"),
        "pressing_ready" to ("Commande prête" to "Order ready"),
        "stock_threshold" to ("Seuil de stock atteint" to "Stock threshold reached"),
        "subscription_expiry" to ("Échéance d’abonnement" to "Subscription due"),
        "device_registered" to ("Nouvel appareil connecté" to "New device connected"),
        "security_alert" to ("Alerte de sécurité" to "Security alert")
    )
    val pair = known[normalized]
    return if (pair != null && french) pair.first else pair?.second ?: eventCode.replace('.', ' ').replace('_', ' ')
}

@Composable
internal fun NotificationInboxContent(
    modifier: Modifier,
    session: AuthSession,
    authApi: AuthApi,
    onBack: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val french = session.account.defaultLocale != "en"
    val pushState by PushTokenRegistry.state.collectAsState()
    var pushBusy by remember { mutableStateOf(false) }
    var pushError by remember { mutableStateOf<String?>(null) }
    var pushNotice by remember { mutableStateOf<String?>(null) }
    val firebaseConfigured = remember { FirebasePushClient.isConfigured(context) }
    val notificationPermissionGranted = Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    suspend fun enablePushOnThisDevice() {
        if (!FirebasePushClient.isConfigured(context)) {
            throw IllegalStateException(when (session.account.defaultLocale) { "en" -> "Firebase configuration missing: the NAXA SERVICES project must be registered first."; "ff-CM" -> "Tintine telefon alaa jooni. Ɗaɓɓu ballal."; else -> "Configuration Firebase absente : le projet NAXA SERVICES doit d'abord être enregistré." })
        }
        val token = FirebasePushClient.fetchToken(context)
        PushTokenRegistry.enable(context, token)
        pushError = null
        pushNotice = when (session.account.defaultLocale) { "en" -> "Permission saved. This device is being registered with NAXA."; "ff-CM" -> "Yamiroore danndaama. Kaɓirgol ngol nana winnditee e NAXA."; else -> "Autorisation enregistrée. L'appareil est en cours d'enregistrement auprès de NAXA." }
    }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            scope.launch {
                pushBusy = true
                runCatching { enablePushOnThisDevice() }
                    .onFailure { pushError = it.message ?: "FCM_REGISTRATION_FAILED" }
                pushBusy = false
            }
        } else {
            pushError = when (session.account.defaultLocale) { "en" -> "Android permission denied. Notifications remain available in the in-app centre."; "ff-CM" -> "Yamiroore telefon salaama. Tintine keɓetee e nokkuure tintine."; else -> "Autorisation Android refusée. Les notifications restent disponibles dans le centre de l'application." }
        }
    }
    var inbox by remember { mutableStateOf<List<NotificationInboxItem>>(emptyList()) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }

    suspend fun reload() {
        inbox = authApi.notificationInbox(session.accessToken, 75)
    }

    LaunchedEffect(session.account.memberId) {
        busy = true
        runCatching { reload() }
            .onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to load notifications."; "ff-CM" -> "Hollugol tintine waawataa."; else -> "Impossible de charger les notifications." } }
        busy = false
    }

    fun runAction(action: suspend () -> Unit) {
        scope.launch {
            busy = true
            error = null
            notice = null
            runCatching { action(); reload() }
                .onSuccess { notice = when (session.account.defaultLocale) { "en" -> "Notification updated."; "ff-CM" -> "Tintinol hesɗitinaama."; else -> "Notification mise à jour." } }
                .onFailure { error = it.message ?: when (session.account.defaultLocale) { "en" -> "Unable to update notification."; "ff-CM" -> "Hesɗitingol waawataa."; else -> "Mise à jour impossible." } }
            busy = false
        }
    }

    val unread = inbox.count { it.status == "sent" }
    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Notifications on this device"; "ff-CM" -> "Tintine e kaɓirgol ngol"; else -> "Notifications sur cet appareil" }, fontWeight = FontWeight.Bold)
                    Text(
                        when {
                            !firebaseConfigured -> when (session.account.defaultLocale) { "en" -> "Firebase is not configured for NAXA SERVICES yet. The in-app inbox remains available."; "ff-CM" -> "Tintine telefon alaa tawo. A waawi yiyde nokkuure tintine."; else -> "Firebase n'est pas encore configuré pour NAXA SERVICES. Le centre de notifications reste accessible." }
                            !notificationPermissionGranted -> when (session.account.defaultLocale) { "en" -> "Android notification permission is not granted on this device."; "ff-CM" -> "Kaɓirgol ngol alaa yamiroore tintine."; else -> "L'autorisation Android n'est pas accordée sur cet appareil." }
                            !pushState.enabled -> when (session.account.defaultLocale) { "en" -> "Remote notifications are disabled on this device."; "ff-CM" -> "Tintine telefon uddaa e kaɓirgol ngol."; else -> "Les notifications distantes sont désactivées sur cet appareil." }
                            pushState.registeredMemberId == session.account.memberId -> when (session.account.defaultLocale) { "en" -> "This device is registered for your account."; "ff-CM" -> "Kaɓirgol ngol winnditaama e konte maa."; else -> "Cet appareil est enregistré pour votre compte." }
                            pushState.errorMessage != null -> (when (session.account.defaultLocale) { "en" -> "Registration failed: "; "ff-CM" -> "Winnditagol timmaani : "; else -> "Enregistrement en échec : " }) + pushState.errorMessage
                            else -> when (session.account.defaultLocale) { "en" -> "Registering this device token with the server…"; "ff-CM" -> "Kaɓirgol ngol nana winnditee…"; else -> "Enregistrement du jeton auprès du serveur…" }
                        },
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (pushBusy) LinearProgressIndicator(Modifier.fillMaxWidth())
                    pushError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                    pushNotice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
                    Button(
                        onClick = {
                            if (Build.VERSION.SDK_INT >= 33 && !notificationPermissionGranted) {
                                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            } else {
                                scope.launch {
                                    pushBusy = true
                                    pushError = null
                                    runCatching { enablePushOnThisDevice() }
                                        .onFailure { pushError = it.message ?: "FCM_REGISTRATION_FAILED" }
                                    pushBusy = false
                                }
                            }
                        },
                        enabled = !pushBusy && firebaseConfigured,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(when (session.account.defaultLocale) { "en" -> "Enable remote notifications"; "ff-CM" -> "Uddit tintine telefon"; else -> "Activer les notifications distantes" }) }
                    if (pushState.enabled) {
                        OutlinedButton(
                            onClick = {
                                scope.launch {
                                    pushBusy = true
                                    pushError = null
                                    runCatching {
                                        authApi.revokeCurrentDevicePushTokens(session.accessToken)
                                        PushTokenRegistry.disable(context)
                                        pushNotice = when (session.account.defaultLocale) { "en" -> "Server token revoked. Remote notifications are disabled."; "ff-CM" -> "Yamiroore ittaama. Tintine telefon uddaa."; else -> "Jeton révoqué côté serveur. Les notifications distantes sont désactivées." }
                                    }.onFailure { pushError = it.message ?: "PUSH_TOKEN_REVOCATION_FAILED" }
                                    pushBusy = false
                                }
                            },
                            enabled = !pushBusy,
                            modifier = Modifier.fillMaxWidth()
                        ) { Text(when (session.account.defaultLocale) { "en" -> "Disable on this device"; "ff-CM" -> "Uddu e kaɓirgol ngol"; else -> "Désactiver sur cet appareil" }) }
                        if (pushState.errorMessage != null) {
                            TextButton(
                                onClick = { PushTokenRegistry.retry() },
                                enabled = !pushBusy
                            ) { Text(when (session.account.defaultLocale) { "en" -> "Retry registration"; "ff-CM" -> "Eto winnditagol kadi"; else -> "Réessayer l'enregistrement" }) }
                        }
                    }
                }
            }
        }
        item {
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(when (session.account.defaultLocale) { "en" -> "Notification centre"; "ff-CM" -> "Nokkuure tintine"; else -> "Centre de notifications" }, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(
                        unread.toString() + when (session.account.defaultLocale) { "en" -> " unread notification(s)"; "ff-CM" -> " tintine ɗe taraaka"; else -> " notification(s) non lue(s)" },
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                TextButton(onClick = onBack) { Text(when (session.account.defaultLocale) { "en" -> "Back"; "ff-CM" -> "Rutto"; else -> "Retour" }) }
            }
            OutlinedButton(onClick = { runAction { reload() } }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(when (session.account.defaultLocale) { "en" -> "Refresh"; "ff-CM" -> "Hesɗitin"; else -> "Actualiser" })
            }
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
            Text(
                when (session.account.defaultLocale) { "en" -> "These messages are loaded from the server for this account. A notification never validates a payment or grants business rights. Complete operations in their respective modules."; "ff-CM" -> "Ɓatakuuji ɗii ko ngam konte maa. Tintinol tabbitintaa njoɓdi walla hokku yamiroore. Waɗ golle kala e nokkuure mum."; else -> "Ces messages sont chargés depuis le serveur pour ce compte. Une notification ne valide jamais un paiement et ne confère aucun droit métier. Les opérations se réalisent dans leur module respectif." },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (inbox.isEmpty() && !busy) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(when (session.account.defaultLocale) { "en" -> "No remote notifications"; "ff-CM" -> "Alaa tintinol telefon"; else -> "Aucune notification distante" }, fontWeight = FontWeight.Bold)
                        Text(
                            when (session.account.defaultLocale) { "en" -> "Notifications will appear here once recorded for your account."; "ff-CM" -> "Tintine maa njiyete ɗoo so ɗe winnditaama e konte maa."; else -> "Les notifications apparaîtront ici dès qu’elles auront été enregistrées pour votre compte." },
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
        items(inbox, key = { it.id }) { item ->
            val title = item.title?.takeIf { it.isNotBlank() } ?: notificationFallbackTitle(item.eventCode, french)
            val statusLabel = when (item.status) {
                "sent" -> when (session.account.defaultLocale) { "en" -> "Unread"; "ff-CM" -> "Taraaka"; else -> "Non lue" }
                "read" -> when (session.account.defaultLocale) { "en" -> "Read"; "ff-CM" -> "Taraama"; else -> "Lue" }
                "actioned" -> when (session.account.defaultLocale) { "en" -> "Handled"; "ff-CM" -> "Timmii"; else -> "Traitée" }
                else -> item.status
            }
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(title, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                        Text(statusLabel, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                    }
                    item.body?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    Text(notificationDateLabel(item.sentAt), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (item.status != "actioned") {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (item.status == "sent") {
                                OutlinedButton(
                                    onClick = { runAction { authApi.acknowledgeNotification(session.accessToken, item.id, "read") } },
                                    enabled = !busy
                                ) { Text(when (session.account.defaultLocale) { "en" -> "Mark as read"; "ff-CM" -> "Maanto ko taraama"; else -> "Marquer comme lue" }) }
                            }
                            Button(
                                onClick = { runAction { authApi.acknowledgeNotification(session.accessToken, item.id, "actioned") } },
                                enabled = !busy
                            ) { Text(when (session.account.defaultLocale) { "en" -> "Mark as handled"; "ff-CM" -> "Maanto ko timmii"; else -> "Marquer comme traitée" }) }
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(22.dp)) }
    }
}
