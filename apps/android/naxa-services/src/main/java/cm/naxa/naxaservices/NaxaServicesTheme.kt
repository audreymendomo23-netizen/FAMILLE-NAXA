package cm.naxa.naxaservices

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val BrandRed = Color(0xFFDD3A33)
private val DarkBg = Color(0xFF111111)
private val DarkSurface = Color(0xFF1E1E1E)
private val LightBg = Color(0xFFFDECEA)
private val Ink = Color(0xFF171717)
private val Muted = Color(0xFF9C9C9C)

@Composable
fun NaxaServicesTheme(light: Boolean = false, content: @Composable () -> Unit) {
    val scheme = if (light) {
        lightColorScheme(
            primary = BrandRed,
            onPrimary = Color.White,
            secondary = Color(0xFFB3261E),
            background = LightBg,
            onBackground = Ink,
            surface = Color.White,
            onSurface = Ink,
            surfaceVariant = Color(0xFFF5DEDC),
            onSurfaceVariant = Color(0xFF494242),
            error = Color(0xFF8E0000),
            onError = Color.White
        )
    } else {
        darkColorScheme(
            primary = BrandRed,
            onPrimary = Color.White,
            secondary = Color(0xFFFF756F),
            background = DarkBg,
            onBackground = Color.White,
            surface = DarkSurface,
            onSurface = Color.White,
            surfaceVariant = Color(0xFF292929),
            onSurfaceVariant = Color(0xFFE4E1E1),
            error = Color(0xFFFF6B63),
            onError = Color.Black
        )
    }
    MaterialTheme(colorScheme = scheme, content = content)
}
