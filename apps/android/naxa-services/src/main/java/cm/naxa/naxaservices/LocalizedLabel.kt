package cm.naxa.naxaservices

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration

/** A label is localized explicitly at the display boundary, never by translating business data. */
@Composable
internal fun localizedLabel(fr: String, en: String, ff: String): String =
    when (LocalConfiguration.current.locales[0].language) {
        "en" -> en
        "ff" -> ff
        else -> fr
    }
