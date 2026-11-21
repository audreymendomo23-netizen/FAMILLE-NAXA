package cm.naxa.naxaservices

import android.app.PendingIntent
import android.content.Intent
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import cm.naxa.core.notifications.NotificationChannels

class NaxaServicesFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        PushTokenRegistry.onTokenRefresh(applicationContext, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val data = message.data
        val eventCode = data["event_code"].orEmpty().lowercase()
        val title = message.notification?.title ?: data["title"]?.takeIf { it.isNotBlank() } ?: "NAXA SERVICES"
        val body = message.notification?.body ?: data["body"]?.takeIf { it.isNotBlank() } ?: "Une nouvelle information est disponible."
        val channel = when {
            eventCode.contains("security") || eventCode.contains("critical") -> NotificationChannels.CRITICAL
            eventCode.contains("subscription") || eventCode.contains("payment") -> NotificationChannels.SUBSCRIPTION
            eventCode.contains("ai") || eventCode.contains("coach") -> NotificationChannels.AI_COACHING
            eventCode.contains("information") || eventCode.contains("info") -> NotificationChannels.INFORMATION
            else -> NotificationChannels.OPERATIONS
        }
        val rawId = data["notification_id"] ?: message.messageId ?: eventCode + body
        val notificationId = (rawId.hashCode() and 0x7fffffff).coerceAtLeast(1)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("naxa_notification_id", data["notification_id"])
            putExtra("naxa_notification_route", data["route"])
        }
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                notificationId,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        NotificationChannels.create(this)
        NotificationChannels.post(
            this,
            channel,
            notificationId,
            title.take(80),
            body.take(180),
            android.R.drawable.ic_dialog_info,
            pendingIntent
        )
    }
}

