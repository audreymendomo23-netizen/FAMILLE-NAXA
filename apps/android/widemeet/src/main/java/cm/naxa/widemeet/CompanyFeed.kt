package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cm.naxa.widemeet.auth.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

@Composable fun CompanyFeed(english:Boolean,gateway:AuthGateway,session:Session){
 fun tr(fr:String,en:String)=if(english)en else fr
 var kind by remember{mutableStateOf("news")};var body by remember{mutableStateOf("")};var data by remember{mutableStateOf<JSONObject?>(null)}
 var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf(false)};var pending by remember{mutableStateOf<JSONObject?>(null)};var remove by remember{mutableStateOf<String?>(null)}
 val scope=rememberCoroutineScope()
 suspend fun req(action:String,p:JSONObject)=gateway.identity(session,"center-company-"+action,p)
 suspend fun load(){data=req("list",JSONObject().put("kind",kind))}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){data=null;error=true}finally{busy=false}}}
 LaunchedEffect(kind){data=null;work{load()}}
 Text(tr("Mon entreprise","My company"),style=MaterialTheme.typography.headlineMedium)
 Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){listOf("news" to tr("Actualités","News"),"announcement" to tr("Annonces","Announcements")).forEach{(k,label)->TextButton(enabled=!busy&&pending==null,onClick={body="";kind=k}){Text(if(kind==k)"• "+label else label)}}}
 HorizontalDivider()
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Action non confirmée. Réessayez.","Action not confirmed. Try again."),color=MaterialTheme.colorScheme.error)
 TextButton(enabled=!busy,onClick={work{load()}}){Text(tr("Actualiser","Refresh"))}
 if(data?.optBoolean("can_publish")==true||pending!=null){
  OutlinedTextField(body,{body=it.take(4000)},enabled=!busy&&pending==null,label={Text(if(kind=="news")tr("Votre actualité","Your update")else tr("Votre annonce","Your announcement"))},modifier=Modifier.fillMaxWidth())
  Button(enabled=!busy&&(body.isNotBlank()||pending!=null),onClick={work{val p=pending?:JSONObject().put("id",UUID.randomUUID().toString()).put("kind",kind).put("body",body.trim()).also{pending=it};req("publish",p);pending=null;body="";load()}}){Text(if(pending!=null)tr("Réessayer la publication","Retry publication")else tr("Publier","Publish"))}
 }
 data?.optJSONArray("items")?.let{items->
  if(items.length()==0)Text(if(kind=="news")tr("Aucune actualité pour le moment.","No updates yet.")else tr("Aucune annonce pour le moment.","No announcements yet."))
  for(i in 0 until items.length()){val p=items.getJSONObject(i);val id=p.getString("id")
   Text(p.getString("display_name"),style=MaterialTheme.typography.titleMedium)
   if(!p.isNull("job_title"))Text(p.optString("job_title"),style=MaterialTheme.typography.bodySmall)
   val date=runCatching{java.time.OffsetDateTime.parse(p.getString("created_at")).atZoneSameInstant(java.time.ZoneId.systemDefault()).format(java.time.format.DateTimeFormatter.ofLocalizedDateTime(java.time.format.FormatStyle.SHORT).withLocale(if(english)java.util.Locale.ENGLISH else java.util.Locale.FRENCH))}.getOrDefault(p.optString("created_at"))
   Text(date,style=MaterialTheme.typography.bodySmall);Text(p.getString("body"))
   if(p.optBoolean("can_confirm")){if(p.optBoolean("confirmed"))Text(tr("Lecture confirmée","Reading confirmed"))else TextButton(enabled=!busy,onClick={work{req("confirm",JSONObject().put("id",id));load()}}){Text(tr("Confirmer la lecture","Confirm reading"))}}
   if(!p.isNull("confirmation_count"))Text(tr("Lectures confirmées","Confirmed readings")+": "+p.optInt("confirmation_count"))
   if(p.optBoolean("can_remove"))TextButton(enabled=!busy,onClick={remove=id}){Text(tr("Retirer","Remove"))}
   HorizontalDivider()
  }
 }
 remove?.let{id->AlertDialog(onDismissRequest={remove=null},title={Text(tr("Retirer cette publication ?","Remove this post?"))},confirmButton={TextButton(onClick={remove=null;work{req("remove",JSONObject().put("id",id));load()}}){Text(tr("Retirer","Remove"))}},dismissButton={TextButton(onClick={remove=null}){Text(tr("Annuler","Cancel"))}})}
}
