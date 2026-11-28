package cm.naxa.grillad
import org.junit.Test
import org.junit.Assert.*
import com.google.zxing.*
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
class GrilladReferralCodeTest{
 private val code="ABCDEF0123456789ABCDEF0123456789"
 @Test fun onlyOpaqueCodeIsAccepted(){
  assertEquals(code,GrilladReferralCode.normalize(code.lowercase()))
  assertEquals(code,GrilladReferralCode.normalize("Mon code GRILLAD : "+code))
  assertEquals(code,GrilladReferralCode.normalize("https://example.invalid/app#referral="+code))
  assertNull(GrilladReferralCode.normalize("https://example.invalid/app?token=private#referral="+code))
  assertNull(GrilladReferralCode.normalize("https://example.invalid/app#connect="+code))
  assertNull(GrilladReferralCode.normalize("javascript:alert(1)#referral="+code))
 }
 @Test fun qrRoundTripUsesOnlyOpaqueCode(){
  val m=GrilladReferralCode.qr(code);val pixels=IntArray(m.width*m.height){i->if(m[i%m.width,i/m.width])0xff000000.toInt() else 0xffffffff.toInt()}
  val image=BinaryBitmap(HybridBinarizer(RGBLuminanceSource(m.width,m.height,pixels)))
  assertEquals(code,QRCodeReader().decode(image).text)
 }
}
