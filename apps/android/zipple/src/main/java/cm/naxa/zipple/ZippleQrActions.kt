package cm.naxa.zipple

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File

// Export exactly the existing opaque QR, including its quiet zone; no customer fields.
internal fun zippleQrPng(code: String, table: Boolean = false): ByteArray {
    val matrix = requireNotNull(if (table) zippleTableQrMatrix(code) else zippleOpaqueQrMatrix(code))
    val scale = 12
    val size = matrix.width * scale
    val pixels = IntArray(size * size) { i ->
        if (matrix[(i % size) / scale, (i / size) / scale]) android.graphics.Color.BLACK else android.graphics.Color.WHITE
    }
    val bitmap = Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
    return try {
        ByteArrayOutputStream().use { out ->
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, out))
            out.toByteArray()
        }
    } finally { bitmap.recycle() }
}

internal fun zippleQrShareIntent(context: Context, code: String, table: Boolean = false): Intent {
    val bytes = zippleQrPng(code, table)
    val directory = File(context.cacheDir, "qr-share")
    check(directory.isDirectory || directory.mkdirs())
    // Avoid accumulating temporary exports; don't remove recently shared images.
    val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
    directory.listFiles()?.filter { it.isFile && it.name.startsWith("zipple-qr-") && it.lastModified() < cutoff }?.forEach { it.delete() }
    val file = File.createTempFile("zipple-qr-", ".png", directory)
    try {
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(context, context.packageName + ".qrshare", file)
        return Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri("ZIPPLE QR", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    } catch (e: Exception) {
        file.delete()
        throw e
    }
}

@Composable internal fun ZippleQrActions(code: String, card: Boolean, en: Boolean, allowed: Boolean, table: Boolean = false) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val t: (String, String) -> String = { fr, english -> if (en) english else fr }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    val filename = if (table) "zipple-table-qr.png" else if (card) "zipple-fidelite.png" else "zipple-parrainage.png"
    val valid = remember(code, table) { (if (table) zippleTableQrMatrix(code) else zippleOpaqueQrMatrix(code)) != null }
    fun run(block: suspend () -> Unit) {
        if (busy || !allowed || !valid) return
        busy = true
        message = ""
        scope.launch {
            try { block() }
            catch (c: CancellationException) { throw c }
            catch (_: Exception) { message = t("Export non confirmé", "Export unconfirmed") }
            finally { busy = false }
        }
    }
    // Reuse the native supporting-document pattern: explicit system file chooser, no storage permission.
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("image/png")) { uri ->
        if (uri != null) run {
            withContext(Dispatchers.IO) {
                val png = zippleQrPng(code, table)
                requireNotNull(context.contentResolver.openOutputStream(uri, "wt")).use { it.write(png) }
            }
            message = t("QR enregistré", "QR saved")
        }
    }
    Row {
        OutlinedButton(enabled = allowed && valid && !busy, onClick = { save.launch(filename) }) {
            Text(if (table) t("Enregistrer le QR de commande","Save order QR") else if (card) t("Enregistrer la carte QR", "Save card QR") else t("Enregistrer le QR de parrainage", "Save referral QR"))
        }
    }
    OutlinedButton(enabled = allowed && valid && !busy, onClick = { run {
        val intent = withContext(Dispatchers.IO) { zippleQrShareIntent(context, code, table) }
        context.startActivity(Intent.createChooser(intent, t("Partager le QR", "Share QR")))
    } }) {
        Text(if (table) t("Partager le QR de commande","Share order QR") else if (card) t("Partager la carte QR", "Share card QR") else t("Partager le QR de parrainage", "Share referral QR"))
    }
    if (message.isNotBlank()) Text(message)
}
