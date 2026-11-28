package cm.naxa.widemeet
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import cm.naxa.widemeet.auth.RoomGateway
import cm.naxa.widemeet.auth.Session
import kotlinx.coroutines.*
import org.json.JSONObject

@Composable internal fun LiveListening(english:Boolean,gateway:RoomGateway,session:Session,roomId:String,preferences:JSONObject?){
 fun tr(fr:String,en:String)=if(english)en else fr
 val context=LocalContext.current
 var enabled by remember(roomId,session.deviceId){mutableStateOf(false)}
 val languages=listOf("original" to tr("Piste originale","Original audio"),"en" to "English","fr" to "Français","ff" to "Fulfulde","es" to "Español","it" to "Italiano","zh" to "中文")
 var target by remember(roomId,session.deviceId){mutableStateOf("en")}
 var chosen by remember(roomId,session.deviceId){mutableStateOf(false)}
 var menu by remember{mutableStateOf(false)}
 var state by remember{mutableStateOf("idle")}
 var engine by remember{mutableStateOf<TextToSpeech?>(null)}
 var ready by remember{mutableStateOf(false)}
 val spoken=remember(roomId,session.deviceId){LinkedHashSet<String>()}
 LaunchedEffect(preferences){if(!chosen)preferences?.optString("listening")?.takeIf{code->languages.any{it.first==code}}?.let{target=it}}
 DisposableEffect(context,enabled){
  if(!enabled){onDispose{}}
  else{var disposed=false;val t=TextToSpeech(context.applicationContext){code->if(!disposed)ready=code==TextToSpeech.SUCCESS};engine=t
   onDispose{disposed=true;ready=false;t.stop();t.shutdown();engine=null}}
 }
 LaunchedEffect(enabled,target,session.accessToken,roomId,ready,preferences?.optString("rate")){
  if(!enabled)return@LaunchedEffect
  val t=engine
  if(target!="en"){state="unavailable";return@LaunchedEffect}
  if(!ready||t==null){state="voice";return@LaunchedEffect}
  var expiry:Job?=null
  fun stop(){expiry?.cancel();expiry=null;t.stop()}
  try{
   while(isActive){
    val began=SystemClock.elapsedRealtime()
    try{
     val v=gateway.request("transcription",JSONObject().put("action","live-captions").put("data",JSONObject().put("room_id",roomId).put("language",target)),session) as JSONObject
     ensureActive()
     val item=liveSpeechWindow(v.optString("status"),v.optBoolean("fallback",true),v.optBoolean("uncertain",true),v.optString("language"),v.optString("source_language"),target,v.optString("text"),v.optString("recording_id"),v.optLong("start_ms",-1),v.optLong("end_ms",-1),v.optLong("ttl_ms",0)-(SystemClock.elapsedRealtime()-began))
     if(item==null){stop();state=if(v.optString("status")=="waiting")"waiting" else "unavailable"}
     else if(item.key !in spoken){
      stop();val voice=runCatching{t.voices?.firstOrNull{!it.isNetworkConnectionRequired&&it.locale.language==target}}.getOrNull()
      if(voice==null||t.setVoice(voice)!=TextToSpeech.SUCCESS||t.setSpeechRate(liveListeningRate(preferences?.optString("rate")))!=TextToSpeech.SUCCESS){state="voice"}
      else if(t.speak(item.text,TextToSpeech.QUEUE_FLUSH,null,item.key)==TextToSpeech.SUCCESS){
       spoken.add(item.key);if(spoken.size>256)spoken.remove(spoken.first());state="playing"
       expiry=launch{delay(item.ttl);t.stop();state="waiting"}
      }else state="voice"
     }else if(state=="playing"&&!t.isSpeaking)state="waiting"
    }catch(e:CancellationException){throw e}catch(e:Exception){stop();state="unavailable"}
    delay(1000)
   }
  }finally{stop()}
 }
 Text(tr("Écoute traduite","Translated listening"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Écoutez les passages traduits du français vers l’anglais lorsque l’enregistrement est autorisé. La piste originale reste audible. Utilisez un casque pour éviter les échos.","Listen to French speech translated into English when recording is permitted. Original audio remains audible. Use headphones to avoid echo."))
 Text(tr("Langue d’écoute","Listening language"))
 Box{OutlinedButton(onClick={menu=true}){Text(languages.firstOrNull{it.first==target}?.second?:tr("Indisponible","Unavailable"))};DropdownMenu(expanded=menu,onDismissRequest={menu=false}){for((code,label) in languages)DropdownMenuItem(text={Text(label)},onClick={chosen=true;target=code;menu=false;state="idle"})}}
 Button(onClick={enabled=!enabled;state="idle"}){Text(if(enabled)tr("Arrêter l’écoute traduite","Stop translated listening") else tr("Activer l’écoute traduite","Enable translated listening"))}
 if(enabled)Text(when(state){"playing"->tr("Écoute en cours…","Playing…");"voice"->tr("Voix indisponible sur cet appareil.","Voice unavailable on this device.");"unavailable"->tr("Traduction indisponible. Écoutez la piste originale.","Translation unavailable. Listen to original audio.");else->tr("En attente d’un passage traduit.","Waiting for translated speech.")})
}
