package cm.naxa.naxaservices

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodes
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
        composeRule.onNodeWithText("Bienvenue").assertIsDisplayed()
        composeRule.onNodeWithText("Identifiant NAXA Services").assertIsDisplayed()
        composeRule.onNodeWithText("Mot de passe").assertIsDisplayed()

        val credentialFields = composeRule.onAllNodes(hasSetTextAction())
        credentialFields.assertCountEquals(2)
        composeRule.onNodeWithText("Se connecter").assertIsNotEnabled()

        credentialFields[0].performTextInput("ns-000001")
        composeRule.onNodeWithText("Se connecter").assertIsNotEnabled()

        credentialFields[1].performTextInput("ui-test-only-invalid-password")
        composeRule.onNodeWithText("Se connecter").assertIsEnabled()
    }
}
