package cm.naxa.widemeet
import android.speech.tts.TextToSpeech
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
private val languageOptions=listOf("fr" to "Français","en" to "English","ff" to "Fulfulde / Fufulbé","es" to "Español","it" to "Italiano","zh" to "中文","wes" to "Cameroon Pidgin English","ewo" to "Ewondo","dua" to "Duala","bas" to "Basaa","bbj" to "Ghomala’","bum" to "Bulu","bax" to "Bamoun","ybb" to "Yemba","mhk" to "Mungaka","ar" to "العربية","pt" to "Português","de" to "Deutsch")
@Composable private fun LanguageChoice(label:String,value:String,options:List<Pair<String,String>>,enabled:Boolean,onChange:(String)->Unit){
 var expanded by remember{mutableStateOf(false)}
 Text(label,style=MaterialTheme.typography.labelLarge)
 Box{OutlinedButton(enabled=enabled,onClick={expanded=true}){Text(options.firstOrNull{it.first==value}?.second?:value)}
 DropdownMenu(expanded=expanded,onDismissRequest={expanded=false}){for((code,name) in options)DropdownMenuItem(text={Text(name)},onClick={expanded=false;onChange(code)})}}
}
@Composable fun LanguageCenter(english:Boolean,gateway:AuthGateway,session:Session,onLocale:(Boolean)->Unit,onArchives:()->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 val scope=rememberCoroutineScope();val context=LocalContext.current
 var data by remember{mutableStateOf<JSONObject?>(null)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var saved by remember{mutableStateOf(false)}
 var confirmReset by remember{mutableStateOf(false)};var ready by remember{mutableStateOf(false)};var preview by remember{mutableStateOf("")};var engine by remember{mutableStateOf<TextToSpeech?>(null)}
 DisposableEffect(context){val t=TextToSpeech(context.applicationContext){status->ready=status==TextToSpeech.SUCCESS};engine=t;onDispose{ready=false;t.stop();t.shutdown();engine=null}}
 fun work(action:String,payload:JSONObject=JSONObject()){if(busy)return;busy=true;error=false;saved=false;scope.launch{try{val result=gateway.identity(session,"language-"+action,payload);data=result;if(action!="preferences"){onLocale(result.getString("interface")=="en");saved=true}}catch(e:CancellationException){throw e}catch(e:Exception){error=true}finally{busy=false}}}
 LaunchedEffect(session.deviceId){work("preferences")}
 fun set(key:String,value:String){data=data?.let{JSONObject(it.toString()).put(key,value)};saved=false}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 Text(tr("Préférences de langue et d’écoute","Language and listening preferences"),style=MaterialTheme.typography.titleMedium)
 Text(tr("Français et anglais : interface et PDF. Les autres choix sont des préférences, pas une garantie de traduction ou sous-titres en direct.","French and English: interface and PDFs. Other choices are preferences, not a guarantee of live translation or subtitles."))
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth());if(error)Text(tr("Action non confirmée. Réessayez.","Action unconfirmed. Retry."),color=MaterialTheme.colorScheme.error)
 val d=data
 if(d==null)Button(enabled=!busy,onClick={work("preferences")}){Text(tr("Actualiser","Refresh"))}
 else{
 LanguageChoice(tr("Langue de l’interface","Interface language"),d.getString("interface"),languageOptions.take(2),!busy){set("interface",it)}
 LanguageChoice(tr("Langue parlée préférée","Preferred spoken language"),d.getString("spoken"),listOf("auto" to tr("Détection automatique souhaitée","Prefer automatic detection"))+languageOptions,!busy){set("spoken",it)}
 LanguageChoice(tr("Langue d’écoute préférée","Preferred listening language"),d.getString("listening"),listOf("original" to tr("Piste originale","Original audio"))+languageOptions,!busy){set("listening",it)}
 LanguageChoice(tr("Langue de sous-titres préférée","Preferred subtitle language"),d.getString("subtitles"),listOf("original" to tr("Langue originale","Original language"))+languageOptions,!busy){set("subtitles",it)}
 LanguageChoice(tr("Langue PDF préférée","Preferred PDF language"),d.getString("pdf"),languageOptions.take(2),!busy){set("pdf",it)}
 LanguageChoice(tr("Vitesse de lecture","Playback speed"),d.getString("rate"),listOf("0.75","1","1.25","1.5").map{it to "$it×"},!busy){set("rate",it)}
 Button(enabled=!busy,onClick={work("save",JSONObject(d.toString()))}){Text(tr("Enregistrer mes préférences","Save my preferences"))}
 TextButton(enabled=!busy,onClick={confirmReset=true}){Text(tr("Réinitialiser","Reset"))}
 if(confirmReset)AlertDialog(onDismissRequest={confirmReset=false},title={Text(tr("Réinitialiser vos préférences d’écoute ?","Reset listening preferences?"))},confirmButton={TextButton(onClick={confirmReset=false;work("reset")}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={confirmReset=false}){Text(tr("Annuler","Cancel"))}})
 TextButton(enabled=!busy,onClick={val t=engine;val lang=d.getString("listening").let{if(it=="original")d.getString("interface")else it};val voice=if(ready&&t!=null&&lang in setOf("fr","en"))runCatching{t.voices?.firstOrNull{!it.isNetworkConnectionRequired&&it.locale.language==lang}}.getOrNull()else null
 preview=if(t!=null&&voice!=null&&t.setVoice(voice)==TextToSpeech.SUCCESS&&t.setSpeechRate(d.getString("rate").toFloat())==TextToSpeech.SUCCESS&&t.speak(if(lang=="fr")"Bienvenue dans WideMeet."else "Welcome to WideMeet.",TextToSpeech.QUEUE_FLUSH,null,"wm-language-sample")==TextToSpeech.SUCCESS)tr("Lecture demandée.","Playback requested.")else tr("Voix indisponible pour cette langue.","Voice unavailable for this language.")}){Text(tr("Écouter un aperçu","Listen to a preview"))}
 TextButton(onClick={engine?.stop();preview=tr("Arrêt demandé.","Stop requested.")}){Text(tr("Arrêter la lecture","Stop playback"))}
 if(preview.isNotEmpty())Text(preview);if(saved)Text(tr("Préférences enregistrées.","Preferences saved."))
 }
 TextButton(onClick=onArchives){Text(tr("Ouvrir mes documents","Open my documents"))}
 Text(tr("La traduction simultanée n’est pas encore disponible. L’exemple n’utilise aucun contenu de réunion.","Simultaneous translation is not yet available. The sample uses no meeting content."))
 }}
}
