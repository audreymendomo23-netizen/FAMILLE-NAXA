package cm.naxa.naxasecurity

import android.graphics.Bitmap
import android.graphics.Color
import android.location.Location
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import java.io.InputStream
import java.security.MessageDigest

// Production primitives exercised by Android instrumentation. No emulator bypass.
internal val securityTemporaryQrPattern=Regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\\.[a-f0-9]{64}$")
internal fun securityTemporaryQrBitmap(code:String):Bitmap{
 require(code.length==101&&securityTemporaryQrPattern.matches(code))
 val m=QRCodeWriter().encode(code,BarcodeFormat.QR_CODE,280,280)
 return Bitmap.createBitmap(IntArray(280*280){i->if(m[i%280,i/280])Color.BLACK else Color.WHITE},280,280,Bitmap.Config.ARGB_8888)
}
internal fun securityUsableGps(p:Location,now:Long=System.currentTimeMillis()):Boolean =
 p.hasAccuracy()&&p.accuracy.isFinite()&&p.accuracy>0f&&p.accuracy<=100f&&
 p.latitude.isFinite()&&p.latitude in -90.0..90.0&&p.longitude.isFinite()&&p.longitude in -180.0..180.0&&
 !p.isFromMockProvider&&p.time>0&&now>=p.time&&now-p.time<=120000L

internal fun securityReadEvidence(input:InputStream):ByteArray{
 val buffer=ByteArray(262145)
 try{
  var count=0
  while(count<buffer.size){val k=input.read(buffer,count,buffer.size-count);if(k<0)break;check(k>0);count+=k}
  check(count in 1..262144)
  return buffer.copyOf(count)
 }finally{buffer.fill(0)}
}
internal fun securityEvidenceDigest(bytes:ByteArray):String =
 MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){"%02x".format(it.toInt() and 255)}
