package cm.naxa.zipple

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import java.util.UUID
import kotlin.math.floor

// Same opaque UUID contract as the existing Web loyalty QR. No personal data or external QR service.
internal fun zippleOpaqueQrMatrix(code: String): BitMatrix? {
    val uuid = try { UUID.fromString(code) } catch (_: IllegalArgumentException) { return null }
    if (uuid.toString() != code) return null
    return QRCodeWriter().encode(code, BarcodeFormat.QR_CODE, 0, 0, mapOf(
        EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M,
        EncodeHintType.MARGIN to 4
    ))
}

@Composable internal fun ZippleOpaqueQr(code: String, description: String) {
    val matrix = remember(code) { zippleOpaqueQrMatrix(code) } ?: return
    Canvas(Modifier.size(200.dp).semantics { contentDescription = description }) {
        drawRect(Color.White)
        val module = floor(minOf(size.width / matrix.width, size.height / matrix.height))
        if (module < 1f) return@Canvas
        val x0 = floor((size.width - matrix.width * module) / 2f)
        val y0 = floor((size.height - matrix.height * module) / 2f)
        for (y in 0 until matrix.height) for (x in 0 until matrix.width) {
            if (matrix[x, y]) drawRect(Color.Black, Offset(x0 + x * module, y0 + y * module), Size(module, module))
        }
    }
}
