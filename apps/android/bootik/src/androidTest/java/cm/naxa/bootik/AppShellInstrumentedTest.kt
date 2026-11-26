package cm.naxa.bootik

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppShellInstrumentedTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun connectionScreenAndLocalReturnAreVisible() {
        composeRule.onNodeWithText("Connexion BOOTIK").performClick()
        composeRule.onNodeWithText("Identifiant").assertExists()
        composeRule.onNodeWithText("Mot de passe").assertExists()
        composeRule.onNodeWithText("Brouillons locaux").performClick()
        composeRule.onNodeWithTag("bootik-setup-list").assertExists()
    }

    @Test
    fun loginRequiresBothCredentialsLikeNaxaServices(){
        composeRule.onNodeWithText("Connexion BOOTIK").performClick()
        val submit=composeRule.onNodeWithTag("login-submit")
        submit.assertIsNotEnabled()
        composeRule.onNodeWithTag("login-identifier").performTextInput("BK-000001")
        submit.assertIsNotEnabled()
        composeRule.onNodeWithTag("login-password").performTextInput("test-only-password")
        submit.assertIsEnabled()
    }

    @Test
    fun retailFirstSetupAndFourteenProfileEntryPointAreVisible() {
        composeRule.onNodeWithText("BOOTIK").assertExists()
        composeRule.onNodeWithText(composeRule.activity.getString(R.string.universe_retailer)).assertExists()
        composeRule.onNodeWithTag("bootik-setup-list").performScrollToIndex(16)
        composeRule.onNodeWithText(composeRule.activity.getString(R.string.profile_brocante)).assertExists()
    }
}
