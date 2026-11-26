package cm.naxa.widemeet

import android.os.SystemClock
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import java.util.Locale

/** UI adapter only. Caller must supply authenticated server snapshot, transport, and pending state. */
@OptIn(ExperimentalLayoutApi::class)
@Composable fun MeetingDeadlineCard(
    endMs: Long, hardEndMs: Long, serverNowMs: Long, serverAnchorElapsedMs: Long,
    status: String, organizerAllowed: Boolean, online: Boolean, pending: Boolean,
    english: Boolean, onExtend: (Int) -> Unit
) {
    var now by remember(serverNowMs, serverAnchorElapsedMs) { mutableLongStateOf(serverNowMs) }
    var custom by remember { mutableStateOf(false) }
    var input by remember { mutableStateOf("") }
    LaunchedEffect(serverNowMs, serverAnchorElapsedMs, endMs, status) {
        while (true) {
            now = serverNowMs + (SystemClock.elapsedRealtime() - serverAnchorElapsedMs).coerceAtLeast(0)
            delay(250)
        }
    }
    val view = meetingClockView(endMs, hardEndMs, now, status, organizerAllowed)
    if (!view.warning) return
    val enabled = view.canExtend && online && !pending
    val maxMinutes = ((hardEndMs - endMs) / 60000).coerceAtMost(480)
    fun tr(fr: String, en: String) = if (english) en else fr
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(tr("Fin de la réunion dans", "Meeting ends in"), style = MaterialTheme.typography.titleMedium)
            Text(String.format(Locale.ROOT, "%02d:%02d", view.seconds / 60, view.seconds % 60), style = MaterialTheme.typography.headlineLarge)
            Text(tr("Prolonger la session", "Extend the session"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(15, 30, 60).forEach { minutes ->
                    OutlinedButton(enabled = enabled && minutes.toLong() <= maxMinutes, onClick = { onExtend(minutes) }) {
                        Text(if (minutes == 60) "+1 h" else "+$minutes min")
                    }
                }
                OutlinedButton(enabled = enabled && maxMinutes >= 1, onClick = { custom = true }) { Text(tr("Configurer", "Custom")) }
            }
            if (!online) Text(tr("Connexion requise", "Connection required"))
            else if (pending) Text(tr("Confirmation en cours", "Awaiting confirmation"))
            else if (maxMinutes < 1) Text(tr("Limite de durée atteinte", "Duration limit reached"))
        }
    }
    if (custom) {
        val value = input.toIntOrNull()
        AlertDialog(onDismissRequest = { custom = false }, title = { Text(tr("Durée supplémentaire", "Additional duration")) },
            text = { OutlinedTextField(value = input, onValueChange = { input = it.take(3) }, label = { Text(tr("Minutes", "Minutes")) }, singleLine = true) },
            confirmButton = { TextButton(enabled = enabled && value != null && value.toLong() in 1L..maxMinutes, onClick = { value?.let(onExtend); custom = false; input = "" }) { Text(tr("Prolonger", "Extend")) } },
            dismissButton = { TextButton(onClick = { custom = false }) { Text(tr("Annuler", "Cancel")) } })
    }
}
