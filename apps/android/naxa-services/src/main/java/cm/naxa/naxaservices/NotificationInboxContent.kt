package cm.naxa.naxaservices

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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
    val french = session.account.defaultLocale != "en"
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
            .onFailure { error = it.message ?: if (french) "Impossible de charger les notifications." else "Unable to load notifications." }
        busy = false
    }

    fun runAction(action: suspend () -> Unit) {
        scope.launch {
            busy = true
            error = null
            notice = null
            runCatching { action(); reload() }
                .onSuccess { notice = if (french) "Notification mise à jour." else "Notification updated." }
                .onFailure { error = it.message ?: if (french) "Mise à jour impossible." else "Unable to update notification." }
            busy = false
        }
    }

    val unread = inbox.count { it.status == "sent" }
    LazyColumn(
        modifier = modifier.fillMaxSize().padding(horizontal = 18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(if (french) "Centre de notifications" else "Notification centre", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(
                        unread.toString() + if (french) " notification(s) non lue(s)" else " unread notification(s)",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                TextButton(onClick = onBack) { Text(if (french) "Retour" else "Back") }
            }
            OutlinedButton(onClick = { runAction { reload() } }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(if (french) "Actualiser" else "Refresh")
            }
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            notice?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
            Text(
                if (french) "Ces messages sont chargés depuis le serveur pour ce compte. Une notification ne valide jamais un paiement et ne confère aucun droit métier. Les opérations se réalisent dans leur module respectif."
                else "These messages are loaded from the server for this account. A notification never validates a payment or grants business rights. Complete operations in their respective modules.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (inbox.isEmpty() && !busy) {
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(if (french) "Aucune notification distante" else "No remote notifications", fontWeight = FontWeight.Bold)
                        Text(
                            if (french) "Les notifications apparaîtront ici dès qu’elles auront été enregistrées pour votre compte."
                            else "Notifications will appear here once recorded for your account.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
        items(inbox, key = { it.id }) { item ->
            val title = item.title?.takeIf { it.isNotBlank() } ?: notificationFallbackTitle(item.eventCode, french)
            val statusLabel = when (item.status) {
                "sent" -> if (french) "Non lue" else "Unread"
                "read" -> if (french) "Lue" else "Read"
                "actioned" -> if (french) "Traitée" else "Handled"
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
                                ) { Text(if (french) "Marquer comme lue" else "Mark as read") }
                            }
                            Button(
                                onClick = { runAction { authApi.acknowledgeNotification(session.accessToken, item.id, "actioned") } },
                                enabled = !busy
                            ) { Text(if (french) "Marquer comme traitée" else "Mark as handled") }
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(22.dp)) }
    }
}
