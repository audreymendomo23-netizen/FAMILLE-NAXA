package cm.naxa.naxasecurity
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable internal fun SecurityActivityInbox(screen:String){
 if(screen!="B6.01")return
 val n=LocalSecurityNative.current;val s=n.session?:return;val site=n.site?:return;val gen=n.generation;val scope=rememberCoroutineScope()
 val channels=listOf("fcm" to "Push mobile","web_push" to "Push Web","sms" to "SMS","whatsapp" to "WhatsApp","email" to "E-mail")
 var channel by remember(gen){mutableStateOf("fcm")}
 var rows by remember(gen){mutableStateOf<List<JSONObject>>(emptyList())};var busy by remember(gen){mutableStateOf(false)};var status by remember(gen){mutableStateOf("")}
 fun run(id:String?){if(busy)return;busy=true;scope.launch{try{
 if(id==null){val a=SecurityNativeApi.records(s,site,"sec_activity_notifications").filter{it.optString("user_id")==s.user};if(n.generation==gen){rows=a;status="Activité personnelle chargée."}}
 else{val v=SecurityNativeApi.action(s,site,"sec_read_activity",JSONObject().put("p_id",id));if(n.generation==gen){rows=rows.map{if(it.optString("id")==id)v else it};status="Lecture enregistrée."}}
 }catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==gen)status="Opération refusée ou non confirmée."}finally{if(n.generation==gen)busy=false}}}
 fun preference(on:Boolean){if(busy)return;busy=true;val chosen=channel;scope.launch{try{
 SecurityNativeApi.action(s,site,"sec_set_activity_channel",JSONObject().put("p_channel",chosen).put("p_enabled",on))
 if(n.generation==gen)status="Préférence "+chosen+" confirmée : "+(if(on)"activée" else "désactivée")+". Diffusion externe non raccordée."
 }catch(e:CancellationException){throw e}catch(_:Exception){if(n.generation==gen)status="Préférence refusée ou non confirmée."}finally{if(n.generation==gen)busy=false}}}
 Text("Notifications métier personnelles");Text("Réception interne uniquement ; aucune intervention ou diffusion externe confirmée.")
 Button(enabled=!busy,onClick={run(null)}){Text("Actualiser les notifications métier")}
 rows.forEach{v->Text(v.optString("source")+" · "+v.optString("event_type")+" · "+if(v.isNull("read_at"))"Non lu" else "Lu");if(v.isNull("read_at"))Button(enabled=!busy,onClick={run(v.optString("id"))}){Text("Confirmer la lecture")}}
 Text("Préférences de diffusion (préparation)")
 Text("Aucun envoi externe actif. Les alarmes locales restent indépendantes.")
 channels.forEach{(key,label)->FilterChip(selected=channel==key,onClick={channel=key},label={Text(label)},enabled=!busy)}
 Button(enabled=!busy,onClick={preference(true)}){Text("Autoriser le canal")}
 Button(enabled=!busy,onClick={preference(false)}){Text("Révoquer le canal")}
 Text(status)
}
