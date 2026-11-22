package cm.naxa.bootik

import androidx.compose.ui.test.assertExists
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppShellInstrumentedTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun retailFirstSetupAndFourteenProfileEntryPointAreVisible() {
        composeRule.onNodeWithText("BOOTIK").assertExists()
        composeRule.onNodeWithText("Univers Détaillants").assertExists()
        composeRule.onNodeWithText("Brocante").performScrollTo().assertExists()
    }
}
