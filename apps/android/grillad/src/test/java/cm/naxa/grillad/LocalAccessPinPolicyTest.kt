package cm.naxa.grillad

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalAccessPinPolicyTest {
    @Test fun acceptsOnlyFourAsciiDigits() {
        assertTrue(LocalAccessPinPolicy.isValid("0427"))
        assertFalse(LocalAccessPinPolicy.isValid("427"))
        assertFalse(LocalAccessPinPolicy.isValid("04270"))
        assertFalse(LocalAccessPinPolicy.isValid("04a7"))
        assertFalse(LocalAccessPinPolicy.isValid("０４２７"))
    }
    @Test fun activeMemberMustMatchTheMemberThatWasUnlocked() {
        assertTrue(LocalAccessPinGatePolicy.requiresUnlock("member-a", null))
        assertFalse(LocalAccessPinGatePolicy.requiresUnlock("member-a", "member-a"))
        assertTrue(LocalAccessPinGatePolicy.requiresUnlock("member-b", "member-a"))
        assertFalse(LocalAccessPinGatePolicy.requiresUnlock(null, "member-a"))
        assertTrue(LocalAccessPinGatePolicy.requiresUnlock("", "member-a"))
    }

    @Test fun lockoutEscalatesAfterEachFiveFailures() {
        assertEquals(0L, LocalAccessPinPolicy.lockoutDurationMillis(4))
        assertEquals(30_000L, LocalAccessPinPolicy.lockoutDurationMillis(5))
        assertEquals(0L, LocalAccessPinPolicy.lockoutDurationMillis(6))
        assertEquals(60_000L, LocalAccessPinPolicy.lockoutDurationMillis(10))
        assertEquals(300_000L, LocalAccessPinPolicy.lockoutDurationMillis(15))
        assertEquals(3_600_000L, LocalAccessPinPolicy.lockoutDurationMillis(25))
        assertEquals(3_600_000L, LocalAccessPinPolicy.lockoutDurationMillis(100))
    }
    @Test fun attemptWindowRestartsAfterFiveFailures() {
        assertEquals(1, LocalAccessPinPolicy.attemptsRemaining(4))
        assertEquals(5, LocalAccessPinPolicy.attemptsRemaining(5))
        assertEquals(4, LocalAccessPinPolicy.attemptsRemaining(6))
    }
}
