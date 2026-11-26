package cm.naxa.naxaservices.auth

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RememberedSessionRecoveryTest {
    @Test fun networkAndTemporaryFailuresNeverEraseRememberedCredentials() {
        listOf(null, 408, 425, 429, 500, 502, 503, 504).forEach { assertFalse(discardRememberedSession(it)) }
    }
    @Test fun explicitAuthRejectionStillRevokesRememberedSession() {
        assertTrue(discardRememberedSession(401)); assertTrue(discardRememberedSession(403))
    }
}
