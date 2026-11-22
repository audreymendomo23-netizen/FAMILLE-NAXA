package cm.naxa.naxaservices

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
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
        // The screen applies the saved app locale through LocalConfiguration.
        // Match the same FR/EN copy so the test is independent of emulator locale.
        val labels = if (NaxaServicesPreferences(composeRule.activity).locale() == "en") {
            listOf("Welcome", "NAXA Services ID", "Password", "Sign in")
        } else {
            listOf("Bienvenue", "Identifiant NAXA Services", "Mot de passe", "Se connecter")
        }
        val (title, identifierLabel, passwordLabel, signInLabel) = labels

        // Material3 TextField labels are merged with their editable field by default.
        // Inspect the unmerged tree for the visible labels; keep field interactions
        // on the normal merged tree below.
        composeRule.onAllNodesWithText(title, useUnmergedTree = true).assertCountEquals(1)
        composeRule.onAllNodesWithText(identifierLabel, useUnmergedTree = true).assertCountEquals(1)
        composeRule.onAllNodesWithText(passwordLabel, useUnmergedTree = true).assertCountEquals(1)

        val credentialFields = composeRule.onAllNodes(hasSetTextAction())
        credentialFields.assertCountEquals(2)
        composeRule.onNodeWithText(signInLabel).assertIsNotEnabled()

        credentialFields[0].performTextInput("ns-000001")
        composeRule.onNodeWithText(signInLabel).assertIsNotEnabled()

        credentialFields[1].performTextInput("ui-test-only-invalid-password")
        composeRule.onNodeWithText(signInLabel).assertIsEnabled()
    }
}
