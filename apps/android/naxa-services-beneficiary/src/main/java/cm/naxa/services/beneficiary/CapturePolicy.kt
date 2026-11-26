package cm.naxa.services.beneficiary

internal object CapturePolicy {
    fun channel(origin: String?): String? = when (origin) {
        "MobileMoney" -> "mtn_momo"
        "OrangeMoney" -> "orange_money"
        else -> null
    }
    fun allowed(enrolled: String?, consent: Boolean, permission: Boolean, origin: String?): Boolean =
        enrolled != null && consent && permission && channel(origin) == enrolled

    // Only recognizable credit-shaped messages may leave the beneficiary phone.
    // Server parsing and paired-proof verification remain authoritative.
    fun creditCandidate(channel: String, message: String): Boolean {
        if (message.length !in 12..8000) return false
        val text = java.text.Normalizer.normalize(message, java.text.Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "").lowercase(java.util.Locale.ROOT)
        return when (channel) {
            "mtn_momo" -> (text.contains("vous avez recu") || text.contains("you have received")) &&
                (text.contains("financial transaction id") || text.contains("identifiant de transaction financiere"))
            "orange_money" -> text.contains("payment de ") && text.contains("id transaction:") && text.contains("montant transaction:")
            else -> false
        }
    }
}
