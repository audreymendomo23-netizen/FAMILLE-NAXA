package cm.naxa.core.notifications

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

enum class NotificationChannel { CRITICAL, OPERATIONS, SUBSCRIPTION, INFORMATION, AI_COACHING }
enum class DeliveryState { CREATED, SENT, RECEIVED, READ, ACTION_DONE, FAILED }

object NotificationContract {
    /** Stable event key is the idempotency key; the server must enforce UNIQUE. */
    fun eventKey(appId: String, recipientId: String, eventType: String, sourceId: String): String {
        require(listOf(appId, recipientId, eventType, sourceId).all { it.isNotBlank() })
        return listOf(appId, recipientId, eventType, sourceId).joinToString(":")
    }

    private val secretLike = listOf(
        Regex("(?i)\\b(pin|otp|one[- ]time password|code secret|verification code)\\b"),
        Regex("(?<!\\d)\\d{4,8}(?!\\d)")
    )

    /** Conservative guard: rejects secret-like content before opening WhatsApp. */
    fun isSafeWhatsAppText(text: String): Boolean =
        text.isNotBlank() && secretLike.none { it.containsMatchIn(text) }

    fun waMeUrl(phoneE164Digits: String, text: String): String {
        require(phoneE164Digits.matches(Regex("^\\d{8,15}$")))
        require(isSafeWhatsAppText(text)) { "unsafe_message_content" }
        val encoded = URLEncoder.encode(text, StandardCharsets.UTF_8).replace("+", "%20")
        return "https://wa.me/$phoneE164Digits?text=$encoded"
    }
}
