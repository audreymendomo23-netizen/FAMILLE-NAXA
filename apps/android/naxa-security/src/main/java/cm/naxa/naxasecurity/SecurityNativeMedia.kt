package cm.naxa.naxasecurity
import android.net.Uri
import android.widget.VideoView
import android.widget.MediaController
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.URI
internal data class SecurityMediaPlayback(val url:String,val expiresAt:Long,val media:String)
internal fun validSecurityMediaUrl(url:String,origin:String):Boolean=try{val b=URI(origin);val u=URI(url);origin.matches(Regex("https://[A-Za-z0-9.-]+"))&&b.host!=null&&u.scheme=="https"&&u.host==b.host&&u.port==-1&&u.rawUserInfo==null&&u.rawQuery==null&&u.rawFragment==null&&u.rawPath.matches(Regex("/security/media/[A-Za-z0-9_-]{16,160}"))}catch(_:Exception){false}
@Composable internal fun SecurityNativeMedia(screen:String){
 val media=when(screen){"B2.01","B2.02","B2.04","B2.05"->"video";"B2.10","B2.11"->"audio";else->return}
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val g=n.generation;val scope=rememberCoroutineScope();val context=LocalContext.current
 var rows by remember(screen,g){mutableStateOf<List<JSONObject>>(emptyList())};var playing by remember(screen,g){mutableStateOf<SecurityMediaPlayback?>(null)};var busy by remember(screen,g){mutableStateOf(false)};var status by remember(screen,g){mutableStateOf("")}
 fun load(revoke:String?=null){if(busy)return;busy=true;scope.launch{try{val a=SecurityNativeApi.mediaManage(s,site,revoke);if(n.generation==g){rows=(0 until a.length()).map{a.getJSONObject(it)}.filter{it.optString("media")==media};playing=null;status=if(revoke==null)"Autorisations chargées." else "Révocation serveur confirmée."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g)status="Service indisponible ou non autorisé."}finally{if(n.generation==g)busy=false}}}
 fun open(r:JSONObject){if(busy)return;busy=true;scope.launch{try{val p=SecurityNativeApi.mediaOpen(s,site,r.getString("id"),r.getString("device_id"),media);if(n.generation==g){playing=p;status="Lecture demandée."}}catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==g){playing=null;status="Autorisation ou origine média indisponible."}}finally{if(n.generation==g)busy=false}}}
 Text("Lecture média autorisée — "+media);Text("Transport compatible requis. Aucun microphone local ni commande physique.")
 Button(enabled=!busy,onClick={load()}){Text("Charger les autorisations")}
 rows.forEach{r->val expiry=runCatching{java.time.Instant.parse(r.getString("expires_at")).toEpochMilli()}.getOrDefault(0);Text(r.optString("device_id")+" · "+if(!r.isNull("revoked_at"))"Révoqué" else if(expiry<=System.currentTimeMillis())"Expiré" else "Autorisé");if(r.isNull("revoked_at")){if(r.optString("user_id")==s.user&&expiry>System.currentTimeMillis())Button(enabled=!busy,onClick={open(r)}){Text("Ouvrir la lecture autorisée")};TextButton(enabled=!busy,onClick={load(r.getString("id"))}){Text("Révoquer")}}}
 val p=playing
 if(p!=null){key(p){val view=remember{VideoView(context)};var active by remember{mutableStateOf(true)}
 DisposableEffect(p){val owner=context as? ComponentActivity;val observer=LifecycleEventObserver{_,event->if(event==Lifecycle.Event.ON_STOP){active=false;view.stopPlayback();playing=null}};owner?.lifecycle?.addObserver(observer);onDispose{active=false;owner?.lifecycle?.removeObserver(observer);view.stopPlayback()}}
 LaunchedEffect(p){delay((p.expiresAt-System.currentTimeMillis()).coerceAtLeast(0));active=false;view.stopPlayback();playing=null;status="Autorisation expirée."}
 AndroidView(factory={view.apply{val controller=MediaController(context);controller.setAnchorView(this);setMediaController(controller);setOnPreparedListener{if(active&&n.generation==g&&System.currentTimeMillis()<p.expiresAt){start();status="Lecture en cours."}else stopPlayback()};setOnErrorListener{_,_,_->if(active){playing=null;status="Transport média indisponible."};true};setVideoURI(Uri.parse(p.url))}},modifier=Modifier.fillMaxWidth().height(if(media=="video")220.dp else 72.dp))
 Button(onClick={active=false;view.stopPlayback();playing=null}){Text("Arrêter la lecture")}
 }}
 Text(status)
}
