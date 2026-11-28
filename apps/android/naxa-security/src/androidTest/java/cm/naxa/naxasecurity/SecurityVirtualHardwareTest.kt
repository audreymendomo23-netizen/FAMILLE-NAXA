package cm.naxa.naxasecurity

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Looper
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class SecurityVirtualHardwareTest {
 private val inst=InstrumentationRegistry.getInstrumentation()
 private val context=inst.targetContext
 private val code="50000000-0000-0000-0000-000000000441."+"a".repeat(64)
 private fun readQr(b:Bitmap):String{
  val pixels=IntArray(b.width*b.height)
  b.getPixels(pixels,0,b.width,0,0,b.width,b.height)
  return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(b.width,b.height,pixels)))).text
 }
 private fun sample(now:Long=System.currentTimeMillis())=Location(LocationManager.GPS_PROVIDER).apply{
  latitude=4.0;longitude=9.0;accuracy=10f;time=now;elapsedRealtimeNanos=SystemClock.elapsedRealtimeNanos()
 }
 private fun shell(cmd:String):String=inst.uiAutomation.executeShellCommand(cmd).use{fd->android.os.ParcelFileDescriptor.AutoCloseInputStream(fd).bufferedReader().use{it.readText()}}
 private fun failure(action:()->Unit){var rejected=false;try{action()}catch(_:Exception){rejected=true};assertTrue("Operation should reject invalid input",rejected)}
 @Test fun qr01_nativeBitmapRoundTrip(){
  val bitmap=securityTemporaryQrBitmap(code)
  try{assertEquals(280,bitmap.width);assertEquals(280,bitmap.height);assertEquals(code,readQr(bitmap))}finally{bitmap.recycle()}
 }
 @Test fun qr02_malformedAndUnreadable(){
  listOf(code.replace(".","\\."),code+"\n",code.dropLast(1),"-".repeat(36)+"."+"a".repeat(64)).forEach{bad->assertFalse(securityTemporaryQrPattern.matches(bad));failure{securityTemporaryQrBitmap(bad)}}
  val blank=Bitmap.createBitmap(280,280,Bitmap.Config.ARGB_8888)
  try{blank.eraseColor(Color.WHITE);failure{readQr(blank)}}finally{blank.recycle()}
 }
 @Test fun gps01_freshnessAccuracyAndBounds(){
  val now=System.currentTimeMillis()
  assertTrue(securityUsableGps(sample(now),now))
  assertFalse(securityUsableGps(sample(now-120001),now))
  assertFalse(securityUsableGps(sample(now+1),now))
  assertFalse(securityUsableGps(sample(now).apply{accuracy=101f},now))
  assertFalse(securityUsableGps(sample(now).apply{accuracy=0f},now))
  assertFalse(securityUsableGps(sample(now).apply{latitude=91.0},now))
 }
 @Suppress("DEPRECATION","MissingPermission")
 @Test fun gps02_androidMockProviderIsRejected(){
  // Deliberately synthetic Android framework provider. Never report a physical location.
  val pkg=context.packageName
  val manager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
  val provider="security_lab_virtual"
  val received=AtomicReference<Location>()
  val latch=CountDownLatch(1)
  val listener=object:LocationListener{
   override fun onLocationChanged(location:Location){received.set(location);latch.countDown()}
   override fun onProviderEnabled(provider:String){}
   override fun onProviderDisabled(provider:String){}
   override fun onStatusChanged(provider:String?,status:Int,extras:android.os.Bundle?){}
  }
  shell("pm grant $pkg "+Manifest.permission.ACCESS_COARSE_LOCATION)
  shell("pm grant $pkg "+Manifest.permission.ACCESS_FINE_LOCATION)
  shell("appops set $pkg android:mock_location allow")
  var installed=false
  try{
   manager.addTestProvider(provider,false,false,false,false,true,true,true,1,1)
   installed=true
   manager.setTestProviderEnabled(provider,true)
   manager.requestLocationUpdates(provider,0L,0f,listener,Looper.getMainLooper())
   manager.setTestProviderLocation(provider,sample().apply{this.provider=provider})
   assertTrue("Android framework did not deliver synthetic provider event",latch.await(10,TimeUnit.SECONDS))
   val p=requireNotNull(received.get())
   assertTrue("Android must mark injected sample as mock",p.isFromMockProvider)
   assertFalse("Production GPS acceptance must reject mock",securityUsableGps(p))
  }finally{
   manager.removeUpdates(listener)
   if(installed)manager.removeTestProvider(provider)
   shell("appops set $pkg android:mock_location default")
  }
 }
 @Test fun storage01_contentResolverAndSha256(){
  val f=File.createTempFile("security-lab-",".bin",context.cacheDir)
  try{
   val uri=Uri.fromFile(f)
   context.contentResolver.openOutputStream(uri,"wt")!!.use{it.write("abc".toByteArray())}
   val read=context.contentResolver.openInputStream(uri)!!.use{securityReadEvidence(it)}
   try{assertArrayEquals("abc".toByteArray(),read);assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",securityEvidenceDigest(read));read[0]=0;assertNotEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",securityEvidenceDigest(read))}finally{read.fill(0)}
  }finally{f.delete()}
 }
 @Test fun storage02_bounds(){
  val max=ByteArray(262144){7};val got=securityReadEvidence(ByteArrayInputStream(max));try{assertArrayEquals(max,got)}finally{got.fill(0);max.fill(0)}
  failure{securityReadEvidence(ByteArrayInputStream(ByteArray(0)))}
  failure{securityReadEvidence(ByteArrayInputStream(ByteArray(262145)))}
 }
 @Test fun device01_reportCapabilitiesWithoutCertification(){
  assertTrue(Build.VERSION.SDK_INT>=26)
  val pm=context.packageManager
  val features=listOf(PackageManager.FEATURE_CAMERA_ANY,PackageManager.FEATURE_LOCATION_GPS,PackageManager.FEATURE_NFC,PackageManager.FEATURE_BLUETOOTH_LE)
  android.util.Log.i("SECURITY_VIRTUAL_LAB","mode=emulator; physical_certified=false; "+features.joinToString(";"){it+"="+pm.hasSystemFeature(it)})
  // A capability flag is not proof of a physical sensor, radio or reader.
 }
}
