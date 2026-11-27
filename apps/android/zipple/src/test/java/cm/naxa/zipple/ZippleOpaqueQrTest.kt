package cm.naxa.zipple

import com.google.zxing.qrcode.decoder.Decoder
import org.junit.Assert.*
import org.junit.Test

class ZippleOpaqueQrTest {
    @Test fun exactOpaqueTokenRoundTrips() {
        for (code in listOf("81a53f1e-e55b-4aa1-ae2e-d6d6d4de4901", "e9af380a-6d8d-44aa-b768-752c38c114f2")) {
            val matrix = requireNotNull(zippleOpaqueQrMatrix(code))
            // Remove the four-module quiet zone for the low-level QR decoder.
            val core = com.google.zxing.common.BitMatrix(matrix.width - 8)
            for (y in 0 until core.height) for (x in 0 until core.width)
                if (matrix[x+4, y+4]) core.set(x,y)
            assertEquals(code, Decoder().decode(core).text)
            for (i in 0 until matrix.width) {
                assertFalse(matrix[i, 0]); assertFalse(matrix[0, i])
            }
        }
    }
    @Test fun invalidOrPersonalDataIsNotEncoded() {
        for (value in listOf("", "699123456", "Client Nom", "1-1-1-1-1", "https://example.test"))
            assertNull(zippleOpaqueQrMatrix(value))
    }
}
