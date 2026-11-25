package cm.naxa.naxaservices

import cm.naxa.naxaservices.data.PressingDepositPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class PressingDepositPolicyTest {
    @Test
    fun zeroDepositHasNoPaymentMethodOrSession() {
        val terms = PressingDepositPolicy.resolve(0L, null, null)
        assertNull(terms.paymentMethod)
        assertNull(terms.cashSessionId)
        assertEquals("none", terms.status)
    }

    @Test
    fun cashDepositRequiresAndRetainsExplicitCashSession() {
        val terms = PressingDepositPolicy.resolve(2500L, " CASH ", " session-01 ")
        assertEquals("cash", terms.paymentMethod)
        assertEquals("session-01", terms.cashSessionId)
        assertEquals("confirmed", terms.status)
    }

    @Test
    fun cashDepositCannotBeRecordedWithoutCashSession() {
        assertThrows(IllegalArgumentException::class.java) {
            PressingDepositPolicy.resolve(2500L, "cash", null)
        }
    }

    @Test
    fun mobileMoneyDepositRecordedManuallyAndCannotUseCashSession() {
        val terms = PressingDepositPolicy.resolve(2500L, "mobile_money", null)
        assertEquals("mobile_money", terms.paymentMethod)
        assertNull(terms.cashSessionId)
        assertEquals("confirmed", terms.status)
        assertThrows(IllegalArgumentException::class.java) {
            PressingDepositPolicy.resolve(2500L, "mobile_money", "session-01")
        }
    }

    @Test
    fun otherNonCashDepositRecordedManually() {
        val terms = PressingDepositPolicy.resolve(1000L, "other", null)
        assertEquals("other", terms.paymentMethod)
        assertNull(terms.cashSessionId)
        assertEquals("confirmed", terms.status)
    }

    @Test
    fun paidDepositRequiresExplicitMethodAndZeroDepositRejectsPaymentTerms() {
        assertThrows(IllegalArgumentException::class.java) {
            PressingDepositPolicy.resolve(1000L, null, null)
        }
        assertThrows(IllegalArgumentException::class.java) {
            PressingDepositPolicy.resolve(0L, "cash", "session-01")
        }
    }
}
