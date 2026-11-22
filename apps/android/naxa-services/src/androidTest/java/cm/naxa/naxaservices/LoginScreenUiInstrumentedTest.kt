package cm.naxa.naxaservices

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTextInput
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

        identifier.assertIsDisplayed()
        password.assertIsDisplayed()
        submit.assertIsDisplayed()
        submit.assertIsNotEnabled()

        identifier.performTextInput("ns-000001")
        submit.assertIsNotEnabled()

        password.performTextInput("ui-test-only-invalid-password")
        submit.assertIsEnabled()
    }
}
