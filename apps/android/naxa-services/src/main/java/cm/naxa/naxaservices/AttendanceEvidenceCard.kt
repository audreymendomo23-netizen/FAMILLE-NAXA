package cm.naxa.naxaservices

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.TextureView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import cm.naxa.naxaservices.auth.AuthSession
import cm.naxa.naxaservices.data.NaxaServicesLocalRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

private data class AttendanceRule(val revision:Long=0,val gps:Boolean=false,val selfie:Boolean=false)
private data class CapturedSelfie(val bytes:ByteArray,val at:Long)
private val attendanceActions=listOf("staff_clock_in","staff_break_start","staff_break_end","staff_clock_out")
@SuppressLint("MissingPermission")
private suspend fun freshAttendanceLocation(context:Context):Location=withTimeout(25000){
 suspendCancellableCoroutine{continuation->
  val manager=context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
  val listener=object:LocationListener{
   override fun onLocationChanged(location:Location){
    if(location.hasAccuracy()&&location.accuracy>0&&location.accuracy<=500&&!location.isFromMockProvider&&kotlin.math.abs(System.currentTimeMillis()-location.time)<=120000){
     manager.removeUpdates(this);if(continuation.isActive)continuation.resume(location)
    }
   }
   override fun onProviderEnabled(provider:String){}
   override fun onProviderDisabled(provider:String){manager.removeUpdates(this);if(continuation.isActive)continuation.resumeWithException(IllegalStateException("GPS unavailable"))}
   @Deprecated("Deprecated in Java") override fun onStatusChanged(provider:String?,status:Int,extras:android.os.Bundle?){}
  }
  continuation.invokeOnCancellation{manager.removeUpdates(listener)}
  try{manager.requestLocationUpdates(LocationManager.GPS_PROVIDER,0L,0f,listener,Looper.getMainLooper())}catch(e:Exception){if(continuation.isActive)continuation.resumeWithException(e)}
 }
}
@SuppressLint("MissingPermission")
@Composable
private fun FrontCameraProof(onCapture:(CapturedSelfie)->Unit,onError:()->Unit,onCancel:()->Unit){
 val context=LocalContext.current
 val latestError by rememberUpdatedState(onError)
 val latestCapture by rememberUpdatedState(onCapture)
 val view=remember(context){TextureView(context)}
 var frame by remember{mutableStateOf(false)}
 DisposableEffect(view){
  var disposed=false
  var device:CameraDevice?=null
  var captureSession:CameraCaptureSession?=null
  var surface:Surface?=null
  val handler=Handler(Looper.getMainLooper())
  fun close(){captureSession?.close();captureSession=null;device?.close();device=null;surface?.release();surface=null}
  fun fail(){close();if(!disposed)latestError()}
  fun start(texture:SurfaceTexture){
   try{
    val manager=context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    val id=manager.cameraIdList.firstOrNull{manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING)==CameraCharacteristics.LENS_FACING_FRONT}?:throw IllegalStateException("No front camera")
    val sizes=manager.getCameraCharacteristics(id).get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)?.getOutputSizes(SurfaceTexture::class.java).orEmpty()
    val size=sizes.filter{it.width<=1280&&it.height<=1280}.maxByOrNull{it.width*it.height}?:sizes.minByOrNull{it.width*it.height}?:throw IllegalStateException("No preview")
    texture.setDefaultBufferSize(size.width,size.height);val output=Surface(texture);surface=output
    manager.openCamera(id,object:CameraDevice.StateCallback(){
     override fun onOpened(camera:CameraDevice){
      if(disposed){camera.close();return};device=camera
      try{camera.createCaptureSession(listOf(output),object:CameraCaptureSession.StateCallback(){
       override fun onConfigured(s:CameraCaptureSession){
        if(disposed){s.close();return};captureSession=s
        try{val req=camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);req.addTarget(output);s.setRepeatingRequest(req.build(),null,handler)}catch(_:Exception){fail()}
       }
       override fun onConfigureFailed(s:CameraCaptureSession){s.close();fail()}
      },handler)}catch(_:Exception){fail()}
     }
     override fun onDisconnected(camera:CameraDevice){camera.close();fail()}
     override fun onError(camera:CameraDevice,error:Int){camera.close();fail()}
    },handler)
   }catch(_:Exception){fail()}
  }
  view.surfaceTextureListener=object:TextureView.SurfaceTextureListener{
   override fun onSurfaceTextureAvailable(s:SurfaceTexture,width:Int,height:Int){start(s)}
   override fun onSurfaceTextureSizeChanged(s:SurfaceTexture,width:Int,height:Int){}
   override fun onSurfaceTextureDestroyed(s:SurfaceTexture):Boolean{close();return true}
   override fun onSurfaceTextureUpdated(s:SurfaceTexture){if(!disposed&&device!=null)frame=true}
  }
  if(view.isAvailable)view.surfaceTexture?.let{start(it)}
  onDispose{disposed=true;view.surfaceTextureListener=null;close()}
 }
 AndroidView(factory={view},modifier=Modifier.fillMaxWidth().height(240.dp))
 Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){
  Button(enabled=frame,onClick={
   try{
    val bitmap=view.getBitmap(720,720)?:throw IllegalStateException()
    val bytes=ByteArrayOutputStream().use{out->val ok=bitmap.compress(Bitmap.CompressFormat.JPEG,80,out);bitmap.recycle();require(ok);out.toByteArray()}
    require(bytes.isNotEmpty()&&bytes.size<=2097152);latestCapture(CapturedSelfie(bytes,System.currentTimeMillis()))
   }catch(_:Exception){latestError()}
  }){Text("Selfie")}
  TextButton(onClick=onCancel){Text("×")}
 }
}
@Composable
internal fun AttendanceEvidenceCard(repository:NaxaServicesLocalRepository,session:AuthSession,siteId:String,workstationId:String?=null){
 if(!BuildConfig.ATTENDANCE_ENABLED||!rosterAvailable(session.account.businessMode)||siteId.isBlank()||session.requirePasswordChange)return
 key(session.account.organizationId,session.account.memberId,session.deviceId,siteId,workstationId){
  val context=LocalContext.current;val scope=rememberCoroutineScope();val latest by rememberUpdatedState(session)
  fun tr(fr:String,en:String,ff:String)=when(session.account.defaultLocale){"en"->en;"ff-CM"->ff;else->fr}
  val labels=mapOf("staff_clock_in" to tr("Prise de service","Start shift","Fuɗɗo golle"),"staff_break_start" to tr("Début de pause","Start break","Fuɗɗo fowtude"),"staff_break_end" to tr("Fin de pause","End break","Timmin fowtude"),"staff_clock_out" to tr("Fin de service","End shift","Timmin golle"))
  val manager=session.account.roleCode in listOf("promoter","network_manager","site_manager")
  var rules by remember{mutableStateOf<Map<String,AttendanceRule>>(emptyMap())}
  var loaded by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var queued by remember{mutableStateOf(false)}
  var selected by remember{mutableStateOf("staff_clock_in")};var reload by remember{mutableIntStateOf(0)}
  var location by remember{mutableStateOf<Location?>(null)};var selfie by remember{mutableStateOf<CapturedSelfie?>(null)};var camera by remember{mutableStateOf(false)}
  val rule=rules[selected]?:AttendanceRule()
  fun clear(){camera=false;location=null;selfie?.bytes?.fill(0);selfie=null;queued=false}
  DisposableEffect(Unit){onDispose{selfie?.bytes?.fill(0)}}
  LaunchedEffect(reload,session.accessToken){
   loaded=false
   try{
    val org=UUID.fromString(latest.account.organizationId);val site=UUID.fromString(siteId)
    val array=JSONArray(StaffRosterApi.call(latest,"ns_attendance_policies?select=event_type,revision,require_gps,require_selfie&org_id=eq."+org+"&site_id=eq."+site))
    rules=(0 until array.length()).mapNotNull{array.optJSONObject(it)}.associate{it.getString("event_type") to AttendanceRule(it.getLong("revision"),it.getBoolean("require_gps"),it.getBoolean("require_selfie"))}
    loaded=true;error=false
   }catch(c:CancellationException){throw c}catch(_:Exception){error=true;rules=emptyMap()}
  }
  fun gps(){
   if(busy)return;busy=true;error=false;location=null
   scope.launch{try{location=freshAttendanceLocation(context)}catch(c:CancellationException){throw c}catch(_:Exception){error=true}finally{busy=false}}
  }
  val gpsPermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()){granted->if(granted[Manifest.permission.ACCESS_FINE_LOCATION]==true)gps()else error=true}
  val cameraPermission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){granted->if(granted)camera=true else error=true}
  Card(Modifier.fillMaxWidth()){
   Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
    Text(tr("Mon pointage probant","My attendance evidence","Seedeeji golle am"),style=MaterialTheme.typography.titleLarge)
    Text(tr("Position et caméra uniquement au pointage. Connexion nécessaire.","Location and camera only when clocking. Connection required.","Nokkuure e kamera e sahaa golle tan."))
    if(error)Text(tr("Pointage non confirmé. Vérifiez les autorisations et la connexion.","Attendance not confirmed. Check permissions and connection.","Golle tabbitinaaka."),color=MaterialTheme.colorScheme.error)
    if(queued)Text(tr("Preuve préparée : pointage en attente de confirmation serveur.","Proof staged: attendance awaiting server confirmation.","Seedeeji hebiima, tabbitinol ena fadi."))
    OutlinedButton(onClick={clear();reload++},enabled=!busy){Text(tr("Actualiser les règles","Refresh rules","Hesɗitin yamirooje"))}
    if(loaded){
     if(manager)attendanceActions.forEach{a->
      val p=rules[a]?:AttendanceRule()
      Text(labels.getValue(a))
      Row{Checkbox(p.gps,{v->if(!busy){busy=true;scope.launch{try{StaffRosterApi.call(latest,"rpc/ns_set_attendance_policy",JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId).put("p_event",a).put("p_revision",p.revision).put("p_gps",v).put("p_selfie",p.selfie));clear();reload++}catch(c:CancellationException){throw c}catch(_:Exception){error=true;loaded=false}finally{busy=false}}}},enabled=!busy);Text("GPS")
       Checkbox(p.selfie,{v->if(!busy){busy=true;scope.launch{try{StaffRosterApi.call(latest,"rpc/ns_set_attendance_policy",JSONObject().put("p_org",latest.account.organizationId).put("p_site",siteId).put("p_event",a).put("p_revision",p.revision).put("p_gps",p.gps).put("p_selfie",v));clear();reload++}catch(c:CancellationException){throw c}catch(_:Exception){error=true;loaded=false}finally{busy=false}}}},enabled=!busy);Text("Selfie")}
     }
     attendanceActions.forEach{a->OutlinedButton(onClick={clear();selected=a},enabled=!busy){Text((if(selected==a)"✓ "else "")+labels.getValue(a))}}
     if(rule.gps)OutlinedButton(onClick={if(ContextCompat.checkSelfPermission(context,Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED)gps()else gpsPermission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION))},enabled=!busy){Text(if(location!=null)tr("Position obtenue","Location captured","Nokkuure heɓiima")else "GPS")}
     if(rule.selfie){
      if(camera)FrontCameraProof(onCapture={selfie?.bytes?.fill(0);selfie=it;camera=false},onError={camera=false;error=true},onCancel={camera=false})
      else OutlinedButton(onClick={selfie?.bytes?.fill(0);selfie=null;if(ContextCompat.checkSelfPermission(context,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)camera=true else cameraPermission.launch(Manifest.permission.CAMERA)},enabled=!busy){Text(if(selfie!=null)tr("Selfie pris","Selfie captured","Natal heɓiima")else tr("Caméra avant","Front camera","Kamera yeeso"))}
     }
     Button(enabled=!busy&&!camera&&(!rule.gps||location!=null)&&(!rule.selfie||selfie!=null),onClick={
      busy=true;queued=false;error=false
      scope.launch{
       try{
        val now=System.currentTimeMillis();val current=latest;val gps=location;val shot=selfie
        require(!rule.gps||gps!=null&&kotlin.math.abs(now-gps.time)<=120000);require(!rule.selfie||shot!=null&&kotlin.math.abs(now-shot.at)<=120000)
        val id=UUID.randomUUID().toString();val occurred=Instant.ofEpochMilli(now).toString()
        if(rule.selfie&&shot!=null)StaffRosterApi.uploadAttendanceSelfie(current,siteId,id,shot.bytes)
        val staged=JSONObject(StaffRosterApi.call(current,"rpc/ns_stage_attendance_proof",JSONObject().put("p_event_id",id).put("p_org",current.account.organizationId).put("p_site",siteId).put("p_post",workstationId?:JSONObject.NULL).put("p_event",selected).put("p_occurred",occurred).put("p_revision",rule.revision).put("p_latitude",if(rule.gps)gps?.latitude?:JSONObject.NULL else JSONObject.NULL).put("p_longitude",if(rule.gps)gps?.longitude?:JSONObject.NULL else JSONObject.NULL).put("p_accuracy",if(rule.gps)gps?.accuracy?.toDouble()?:JSONObject.NULL else JSONObject.NULL).put("p_gps_at",if(rule.gps&&gps!=null)Instant.ofEpochMilli(gps.time).toString()else JSONObject.NULL).put("p_selfie_at",if(rule.selfie&&shot!=null)Instant.ofEpochMilli(shot.at).toString()else JSONObject.NULL)))
        require(staged.optBoolean("staged")&&staged.optString("proof_ref")==id)
        repository.recordStaffTimeEvent(current.account.organizationId,siteId,selected,current.account.displayName,current.account.memberId,workstationId,current.account.memberId,id,now,id)
        clear();queued=true
       }catch(c:CancellationException){throw c}catch(_:Exception){error=true}finally{busy=false}
      }
     }){Text(tr("Confirmer mon pointage","Confirm my attendance","Tabbitin golle am"))}
    }
   }
  }
 }
}
