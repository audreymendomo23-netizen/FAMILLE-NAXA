package cm.naxa.grillad
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import java.net.URI
import java.util.Locale

internal object GrilladReferralCode {
 private val code=Regex("[0-9a-fA-F]{32}")
 fun normalize(input:String):String? {
  if(input.length>2048)return null
  val s=input.trim()
  val raw=when{
   code.matches(s)->s
   s.startsWith("Mon code GRILLAD : ")->s.removePrefix("Mon code GRILLAD : ")
   else->{val uri=runCatching{URI(s)}.getOrNull()?:return null
    if(uri.scheme!="https"||uri.host.isNullOrBlank()||uri.rawUserInfo!=null||uri.rawQuery!=null)return null
    uri.rawFragment?.takeIf{it.startsWith("referral=")}?.removePrefix("referral=")?:return null}
  }
  return raw.takeIf{code.matches(it)}?.uppercase(Locale.ROOT)
 }
 fun qr(raw:String):BitMatrix{
  require(code.matches(raw)&&raw==raw.uppercase(Locale.ROOT))
  return QRCodeWriter().encode(raw,BarcodeFormat.QR_CODE,240,240,mapOf(EncodeHintType.MARGIN to 4,EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M))
 }
}
