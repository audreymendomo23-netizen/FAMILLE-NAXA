package cm.naxa.naxaservices.auth

import org.junit.Assert.*
import org.junit.Test

class TemporarySessionFailureTest {
    @Test fun onlyTransientFailuresCanResumeLocalSession() {
        listOf(408,429,500,502,503,504,599).forEach { assertTrue("status=$it",isTemporarySessionFailure(AuthApiException("test",it))) }
        listOf(200,400,401,403,404,409,422,499,600).forEach { assertFalse("status=$it",isTemporarySessionFailure(AuthApiException("test",it))) }
        assertTrue(isTemporarySessionFailure(AuthApiException("network",transportFailure=true)))
        assertFalse(isTemporarySessionFailure(AuthApiException("malformed Auth response")))
        assertFalse(isTemporarySessionFailure(IllegalStateException("local failure")))
        assertFalse(isTemporarySessionFailure(AuthApiException("denied",403,transportFailure=true)))
        assertTrue(discardRememberedSession(401))
        assertTrue(discardRememberedSession(403))
        assertFalse(discardRememberedSession(503))
    }
}
