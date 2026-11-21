package cm.naxa.naxaservices

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PushTokenRegistryInstrumentedTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        PushTokenRegistry.disable(context)
    }

    @After
    fun tearDown() {
        PushTokenRegistry.disable(context)
    }

    @Test
    fun logoutClearsDevicePushOptInAndPreviousMemberBinding() {
        val token = "fcm_" + "a".repeat(80)
        PushTokenRegistry.enable(context, token)
        PushTokenRegistry.markRegistered("member-before-logout", "old-session-key")

        assertTrue(PushTokenRegistry.state.value.enabled)
        assertEquals(token, PushTokenRegistry.state.value.token)
        assertEquals("member-before-logout", PushTokenRegistry.state.value.registeredMemberId)

        PushTokenRegistry.disable(context)
        PushTokenRegistry.initialize(context)

        val state = PushTokenRegistry.state.value
        assertFalse(state.enabled)
        assertNull(state.token)
        assertNull(state.registeredMemberId)
        assertNull(state.registeredSessionKey)
        assertNull(context.getSharedPreferences("naxa_services_push_preferences", Context.MODE_PRIVATE)
            .getString("fcm_token", null))
    }
}
