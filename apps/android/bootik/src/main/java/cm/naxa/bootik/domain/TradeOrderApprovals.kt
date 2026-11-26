package cm.naxa.bootik.domain

/**
 * Human approval facts required before an inter-business purchase can become firm.
 * These values are server-authored in production; the Android client must never
 * treat a locally generated stock alert as an approval.
 */
data class TradeOrderApprovals(
    val distributorApprovedBy: String? = null,
    val retailerConfirmedBy: String? = null,
    val distributorChangedTerms: Boolean = false
)

fun canConfirmTradeOrder(approvals: TradeOrderApprovals): Boolean {
    val distributorApprovalExists = !approvals.distributorApprovedBy.isNullOrBlank()
    val retailerApprovalRequired = approvals.distributorChangedTerms
    val retailerApprovalExists = !approvals.retailerConfirmedBy.isNullOrBlank()

    return distributorApprovalExists && (!retailerApprovalRequired || retailerApprovalExists)
}
