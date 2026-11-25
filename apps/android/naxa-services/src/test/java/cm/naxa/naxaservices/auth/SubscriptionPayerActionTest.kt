package cm.naxa.naxaservices.auth

import org.junit.Assert.assertThrows
import org.junit.Test

class SubscriptionPayerActionTest {
    @Test
    fun allPayerActionsIncludingUnpaidCancellationAreAccepted() {
        listOf("subscription_list", "subscription_create", "subscription_declare", "subscription_cancel")
            .forEach { requireSubscriptionPayerAction(it) }
    }

    @Test
    fun unknownAndAdministrativeActionsRemainRejected() {
        listOf("", "subscription_confirm", "subscription_credit_capture", "subscription_review_reject", "subscription_access")
            .forEach { action ->
                assertThrows(IllegalArgumentException::class.java) { requireSubscriptionPayerAction(action) }
            }
    }
}
