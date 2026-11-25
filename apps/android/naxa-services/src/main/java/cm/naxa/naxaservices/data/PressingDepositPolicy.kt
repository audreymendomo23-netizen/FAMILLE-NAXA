package cm.naxa.naxaservices.data

internal data class PressingDepositTerms(
    val paymentMethod: String?,
    val cashSessionId: String?,
    val status: String
)

/**
 * Normalizes a pressing deposit without inventing a payment method or cash session.
 * Cash is considered locally received only when the operator explicitly binds it
 * to an open session; the repository performs the authoritative session lookup.
 */
internal object PressingDepositPolicy {
    fun resolve(
        depositXaf: Long,
        paymentMethodInput: String?,
        cashSessionIdInput: String?
    ): PressingDepositTerms {
        require(depositXaf >= 0) { "Montant d'acompte négatif." }
        val method = paymentMethodInput?.trim()?.lowercase(java.util.Locale.ROOT)?.takeIf(String::isNotBlank)
        val sessionId = cashSessionIdInput?.trim()?.takeIf(String::isNotBlank)

        if (depositXaf == 0L) {
            require(method == null && sessionId == null) {
                "Un acompte nul ne doit pas porter de moyen ou de session de paiement."
            }
            return PressingDepositTerms(null, null, "none")
        }

        return when (method) {
            "cash" -> {
                require(sessionId != null) {
                    "Sélectionne une session de caisse ouverte pour encaisser l'acompte en espèces."
                }
                PressingDepositTerms("cash", sessionId, "confirmed")
            }
            "mobile_money", "other" -> {
                require(sessionId == null) {
                    "Un paiement non espèces ne peut pas être rattaché à une session de caisse."
                }
                PressingDepositTerms(method, null, "confirmed")
            }
            else -> throw IllegalArgumentException("Choisis explicitement le mode d'encaissement de l'acompte.")
        }
    }
}
