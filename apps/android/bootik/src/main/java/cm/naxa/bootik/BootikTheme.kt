package cm.naxa.bootik

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val BootikNavy = Color(0xFF052163)
private val BootikOrange = Color(0xFFFC7820)
private val BootikBackground = Color(0xFFF4F6FB)
private val BootikInk = Color(0xFF17233D)

@Composable
fun BootikTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = BootikNavy,
            onPrimary = Color.White,
            secondary = BootikOrange,
            onSecondary = Color.Black,
            background = BootikBackground,
            onBackground = BootikInk,
            surface = Color.White,
            onSurface = BootikInk,
            surfaceVariant = Color(0xFFE9EDF6),
            onSurfaceVariant = Color(0xFF4C5870),
            error = Color(0xFFB3261E),
            onError = Color.White
        ),
        content = content
    )
}
