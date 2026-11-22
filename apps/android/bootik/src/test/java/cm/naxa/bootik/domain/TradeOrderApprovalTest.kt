package cm.naxa.bootik.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TradeOrderApprovalTest {
    @Test
    fun stockAlertAloneCannotConfirmAnOrder() {
        assertFalse(canConfirmTradeOrder(TradeOrderApprovals()))
    }

    @Test
    fun unchangedTermsRequireHumanDistributorApproval() {
        assertFalse(canConfirmTradeOrder(TradeOrderApprovals()))
        assertTrue(
            canConfirmTradeOrder(
                TradeOrderApprovals(distributorApprovedBy = "human-distributor-member")
            )
        )
    }

    @Test
    fun changedTermsRequireDistributorAndRetailerApproval() {
        val distributorAcceptedChangedTerms = TradeOrderApprovals(
            distributorApprovedBy = "human-distributor-member",
            distributorChangedTerms = true
        )
        assertFalse(canConfirmTradeOrder(distributorAcceptedChangedTerms))
        assertTrue(
            canConfirmTradeOrder(
                distributorAcceptedChangedTerms.copy(retailerConfirmedBy = "human-retailer-member")
            )
        )
    }
}
