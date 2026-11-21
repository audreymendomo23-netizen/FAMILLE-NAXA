package cm.naxa.naxaservices

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocalAccessPinManagerInstrumentedTest {
    private lateinit var manager: LocalAccessPinManager
    private lateinit var memberId: String

    @Before fun setUp() {
        manager = LocalAccessPinManager(ApplicationProvider.getApplicationContext<Context>())
        memberId = "instrumented-pin-" + UUID.randomUUID()
    }
    @After fun tearDown() { manager.resetAfterValidatedLogin(memberId) }

    @Test fun keystoreVerifierPersistsAndPinCanBeChanged() {
        assertFalse(manager.isConfigured(memberId))
        assertEquals(LocalAccessPinCode.SUCCESS, manager.enroll(memberId, "0427").code)
        val recreated = LocalAccessPinManager(ApplicationProvider.getApplicationContext())
        assertEquals(LocalAccessPinCode.SUCCESS, recreated.verify(memberId, "0427").code)
        assertEquals(LocalAccessPinCode.SUCCESS, recreated.changePin(memberId, "0427", "9518").code)
        assertEquals(LocalAccessPinCode.INVALID, recreated.verify(memberId, "0427").code)
        assertEquals(LocalAccessPinCode.SUCCESS, recreated.verify(memberId, "9518").code)
    }

    @Test fun fiveBadAttemptsLockAndValidatedLoginResetsPin() {
        assertEquals(LocalAccessPinCode.SUCCESS, manager.enroll(memberId, "1357").code)
        repeat(4) { assertEquals(LocalAccessPinCode.INVALID, manager.verify(memberId, "9999").code) }
        assertEquals(LocalAccessPinCode.LOCKED, manager.verify(memberId, "9999").code)
        val recreated = LocalAccessPinManager(ApplicationProvider.getApplicationContext())
        assertEquals(LocalAccessPinCode.LOCKED, recreated.verify(memberId, "1357").code)
        assertTrue(recreated.resetAfterValidatedLogin(memberId))
        assertFalse(recreated.isConfigured(memberId))
        assertEquals(LocalAccessPinCode.SUCCESS, recreated.enroll(memberId, "8642").code)
        assertEquals(LocalAccessPinCode.SUCCESS, recreated.verify(memberId, "8642").code)
    }

    @Test fun invalidPinCannotBeEnrolled() {
        assertEquals(LocalAccessPinCode.INVALID_FORMAT, manager.enroll(memberId, "123").code)
        assertFalse(manager.isConfigured(memberId))
    }
}
