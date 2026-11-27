package cm.naxa.naxaservices.auth

import org.junit.Assert.*
import org.junit.Test

class TemporarySessionFailureTest {
    @Test fun onlyTransientFailuresCanResumeLocalSession() {
        listOf(null,408,429,500,502,503,504,599).forEach { assertTrue("status=$it",isTemporarySessionFailure(it)) }
        listOf(200,400,401,403,404,409,422,499,600).forEach { assertFalse("status=$it",isTemporarySessionFailure(it)) }
        assertTrue(discardRememberedSession(401))
        assertTrue(discardRememberedSession(403))
        assertFalse(discardRememberedSession(503))
    }
}
