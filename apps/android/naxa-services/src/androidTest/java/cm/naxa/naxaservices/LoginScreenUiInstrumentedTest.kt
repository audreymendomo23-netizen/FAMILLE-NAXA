package cm.naxa.naxaservices

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LoginScreenUiInstrumentedTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun loginScreenRequiresBothCredentialsBeforeEnablingSubmit() {
        // Stable test tags keep this interaction test independent of device
        // locale and of Material3's merged text semantics.
        val identifier = composeRule.onNodeWithTag("login-identifier")
        val password = composeRule.onNodeWithTag("login-password")
        val submit = composeRule.onNodeWithTag("login-submit")

        composeRule.onNodeWithTag("business-photo-backdrop").assertIsDisplayed()
        identifier.performScrollTo().assertIsDisplayed()
        password.performScrollTo().assertIsDisplayed()
        submit.performScrollTo().assertIsDisplayed()
        submit.assertIsNotEnabled()

        identifier.performScrollTo().performTextInput("ns-000001")
        submit.assertIsNotEnabled()

        password.performScrollTo().performTextInput("ui-test-only-invalid-password")
        submit.performScrollTo().assertIsEnabled()
    }

    @Test
    fun loginLanguageSwitchesAcrossFrenchEnglishAndFulfulde() {
        composeRule.onNodeWithTag("locale-fr").performScrollTo()
        val fr = composeRule.onNodeWithTag("locale-fr")
        if (NaxaServicesPreferences(composeRule.activity).locale() != "fr") fr.performClick()
        composeRule.onNodeWithText("Bienvenue").assertIsDisplayed()
        composeRule.onNodeWithTag("locale-en").performClick()
        composeRule.onNodeWithText("Welcome").assertIsDisplayed()
        composeRule.onNodeWithTag("locale-ff").performClick()
        composeRule.onNodeWithText("A jaɓɓaama").assertIsDisplayed()
        org.junit.Assert.assertEquals("ff-CM",NaxaServicesPreferences(composeRule.activity).locale())
        fr.performClick()
        composeRule.onNodeWithText("Bienvenue").assertIsDisplayed()
    }

    @Test
    fun nightModeActivationShowsDecorativeTorchThenClearsIt() {
        val preferences = NaxaServicesPreferences(composeRule.activity)
        val toggle = composeRule.onNodeWithTag("login-theme-toggle")
        toggle.performScrollTo()
        if (!preferences.isLightNow()) toggle.performClick()
        composeRule.waitForIdle()
        composeRule.mainClock.autoAdvance = false
        try {
            toggle.performClick()
            composeRule.mainClock.advanceTimeBy(250)
            composeRule.onNodeWithTag("night-torch-animation").assertIsDisplayed()
            composeRule.mainClock.advanceTimeBy(1900)
            composeRule.onNodeWithTag("night-torch-animation").assertDoesNotExist()
        } finally {
            composeRule.mainClock.autoAdvance = true
        }
    }
}
