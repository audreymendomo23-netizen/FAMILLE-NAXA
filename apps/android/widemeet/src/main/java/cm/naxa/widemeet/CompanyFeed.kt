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
 var mediaOpen by remember{mutableStateOf<String?>(null)};var team by remember{mutableStateOf("")};var teamMenu by remember{mutableStateOf(false)}
 var pollEnabled by remember{mutableStateOf(false)};var options by remember{mutableStateOf(listOf("",""))};var voteConfirm by remember{mutableStateOf<Pair<String,Int>?>(null)};var closeConfirm by remember{mutableStateOf<String?>(null)}
 var favorites by remember{mutableStateOf(false)};var opened by remember{mutableStateOf<String?>(null)};var comments by remember{mutableStateOf<org.json.JSONArray?>(null)};var commentBody by remember{mutableStateOf("")};var commentPending by remember{mutableStateOf<JSONObject?>(null)}
 val scope=rememberCoroutineScope()
 suspend fun req(action:String,p:JSONObject)=gateway.identity(session,"center-company-"+action,p)
 suspend fun load(){data=req("list",JSONObject().put("kind",kind).put("favorites",kind=="news"&&favorites))}
 suspend fun loadComments(id:String){comments=req("comments",JSONObject().put("id",id)).getJSONArray("items");opened=id}
 fun work(block:suspend ()->Unit){if(busy)return;busy=true;error=false;scope.launch{try{block()}catch(e:CancellationException){throw e}catch(e:Exception){if(commentPending==null){data=null;opened=null;comments=null};error=true}finally{busy=false}}}
 LaunchedEffect(kind,favorites){data=null;opened=null;comments=null;commentBody="";work{load()}}
 Text(tr("Actualités","News"),style=MaterialTheme.typography.headlineMedium)
 Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){if(kind=="news"){TextButton(enabled=!busy&&pending==null&&commentPending==null,onClick={body="";team="";pollEnabled=false;options=listOf("","");kind="announcement"}){Text(tr("Annonces","Announcements"))}}else{TextButton(enabled=!busy&&pending==null&&commentPending==null,onClick={body="";team="";pollEnabled=false;options=listOf("","");kind="news"}){Text(tr("Retour au fil","Back to feed"))};Text(tr("Annonces","Announcements"),style=MaterialTheme.typography.titleMedium)}}
 HorizontalDivider()
 if(busy)LinearProgressIndicator(Modifier.fillMaxWidth())
 if(error)Text(tr("Action non confirmée. Réessayez.","Action not confirmed. Try again."),color=MaterialTheme.colorScheme.error)
 TextButton(enabled=!busy,onClick={work{load();opened?.let{loadComments(it)}}}){Text(tr("Actualiser","Refresh"))}
 if(kind=="news")TextButton(enabled=!busy&&pending==null&&commentPending==null,onClick={favorites=!favorites}){Text(if(favorites)tr("Tous les articles","All posts")else tr("Mes favoris","My favorites"))}
 if(data?.optBoolean("can_publish")==true||pending!=null){
  OutlinedTextField(body,{body=it.take(4000)},enabled=!busy&&pending==null,label={Text(if(kind=="news")tr("Votre actualité","Your update")else tr("Votre annonce","Your announcement"))},modifier=Modifier.fillMaxWidth())
  data?.optJSONArray("teams")?.let{ts->if(ts.length()>0){val selected=(0 until ts.length()).map{ts.getJSONObject(it)}.find{it.optString("id")==team};Text(tr("Audience","Audience"),style=MaterialTheme.typography.labelLarge);Box{OutlinedButton(enabled=!busy&&pending==null,onClick={teamMenu=true}){Text(selected?.let{tr("Équipe de","Team of")+" "+it.optString("name")}?:tr("Toute l’entreprise","Entire company"))};DropdownMenu(expanded=teamMenu,onDismissRequest={teamMenu=false}){DropdownMenuItem(text={Text(tr("Toute l’entreprise","Entire company"))},onClick={team="";teamMenu=false});for(j in 0 until ts.length()){val t=ts.getJSONObject(j);DropdownMenuItem(text={Text(tr("Équipe de","Team of")+" "+t.optString("name"))},onClick={team=t.getString("id");teamMenu=false})}}}}}
  if(kind=="news"){Row{Checkbox(pollEnabled,{pollEnabled=it},enabled=!busy&&pending==null);Text(tr("Ajouter un sondage","Add a poll"),Modifier.padding(top=12.dp))};if(pollEnabled){options.forEachIndexed{i,v->OutlinedTextField(v,{value->options=options.mapIndexed{j,x->if(i==j)value.take(120) else x}},enabled=!busy&&pending==null,label={Text(tr("Choix","Choice")+" "+(i+1))},modifier=Modifier.fillMaxWidth())};if(options.size<6)TextButton(enabled=!busy&&pending==null,onClick={options=options+""}){Text(tr("Ajouter un choix","Add a choice"))};if(options.size>2)TextButton(enabled=!busy&&pending==null,onClick={options=options.dropLast(1)}){Text(tr("Retirer le dernier choix","Remove last choice"))}}}
  Button(enabled=!busy&&(pending!=null||(body.isNotBlank()&&(!pollEnabled||kind!="news"||(options.all{it.isNotBlank()}&&options.map{it.trim().lowercase()}.distinct().size==options.size)))),onClick={work{val p=pending?:JSONObject().put("id",UUID.randomUUID().toString()).put("kind",kind).put("body",body.trim()).also{if(team.isNotEmpty())it.put("team_id",team);if(kind=="news"&&pollEnabled)it.put("poll_options",org.json.JSONArray(options.map{x->x.trim()}));pending=it};req("publish",p);pending=null;body="";team="";pollEnabled=false;options=listOf("","");load()}}){Text(if(pending!=null)tr("Réessayer la publication","Retry publication")else tr("Publier","Publish"))}
 }
 data?.optJSONArray("items")?.let{items->
  if(items.length()==0)Text(if(kind=="news")tr("Aucune actualité pour le moment.","No updates yet.")else tr("Aucune annonce pour le moment.","No announcements yet."))
  for(i in 0 until items.length()){val p=items.getJSONObject(i);val id=p.getString("id")
   Text(p.getString("display_name"),style=MaterialTheme.typography.titleMedium)
   if(!p.isNull("job_title"))Text(p.optString("job_title"),style=MaterialTheme.typography.bodySmall)
   val date=runCatching{java.time.OffsetDateTime.parse(p.getString("created_at")).atZoneSameInstant(java.time.ZoneId.systemDefault()).format(java.time.format.DateTimeFormatter.ofLocalizedDateTime(java.time.format.FormatStyle.SHORT).withLocale(if(english)java.util.Locale.ENGLISH else java.util.Locale.FRENCH))}.getOrDefault(p.optString("created_at"))
   Text(date+" · "+if(p.isNull("team_id"))tr("Entreprise","Company")else tr("Équipe","Team"),style=MaterialTheme.typography.bodySmall);Text(p.getString("body"))
   if(BuildConfig.WIDEMEET_CHAT_MEDIA_ENABLED){TextButton(onClick={mediaOpen=if(mediaOpen==id)null else id}){Text(tr("Pièces jointes","Attachments"))};if(mediaOpen==id)key(id){ChatMediaPanel(english,gateway,session,allowUpload=p.optString("author_id")==session.memberId,voiceAllowed=false,postId=id)}}
   p.optJSONObject("poll")?.let{poll->Text(if(poll.optBoolean("closed"))tr("Sondage clôturé","Poll closed")else tr("Sondage en cours","Open poll"),style=MaterialTheme.typography.titleSmall);val choices=poll.getJSONArray("options");val counts=poll.optJSONArray("counts");for(j in 0 until choices.length()){val label=choices.getString(j);if(poll.isNull("my_vote")&&!poll.optBoolean("closed"))TextButton(enabled=!busy&&commentPending==null,onClick={voteConfirm=id to j}){Text(label)}else Text(label+(if(poll.optInt("my_vote",-1)==j)" ✓" else "")+(counts?.let{" — "+it.optInt(j)+" "+tr("vote(s)","vote(s)")}?: ""))};if(p.optBoolean("can_remove")&&!poll.optBoolean("closed"))TextButton(enabled=!busy,onClick={closeConfirm=id}){Text(tr("Clôturer le sondage","Close poll"))}}
   if(kind=="news"){
    val reactions=listOf(Triple("like","👍",tr("J’aime","Like")),Triple("celebrate","👏",tr("Bravo","Celebrate")),Triple("love","❤️",tr("J’adore","Love")),Triple("insightful","💡",tr("Instructif","Insightful")),Triple("support","🤝",tr("Soutien","Support")),Triple("funny","😂",tr("Amusant","Funny")))
    reactions.chunked(2).forEach{pair->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(4.dp)){pair.forEach{(r,emoji,label)->TextButton(modifier=Modifier.weight(1f),enabled=!busy&&commentPending==null,onClick={work{req("reaction",JSONObject().put("id",id).put("reaction",if(p.optString("my_reaction")==r)JSONObject.NULL else r));load()}}){Text((if(p.optString("my_reaction")==r)"✓ " else "")+emoji+" "+label)}}}}
    Text(p.optInt("reaction_count").toString()+" "+tr("réactions","reactions"),style=MaterialTheme.typography.bodySmall)
    TextButton(enabled=!busy&&commentPending==null,onClick={work{req("favorite",JSONObject().put("id",id).put("enabled",!p.optBoolean("favorite")));load()}}){Text(if(p.optBoolean("favorite"))tr("Retirer des favoris","Remove from favorites")else tr("Ajouter aux favoris","Add to favorites"))}
    TextButton(enabled=!busy&&commentPending==null,onClick={if(opened==id){opened=null;comments=null;commentBody=""}else{commentBody="";work{loadComments(id)}}}){Text(tr("Commentaires","Comments")+" ("+p.optInt("comment_count")+")")}
    if(opened==id){comments?.let{cs->for(j in 0 until cs.length()){val c=cs.getJSONObject(j);Text(c.getString("display_name")+(if(c.isNull("job_title"))"" else " · "+c.optString("job_title")),style=MaterialTheme.typography.labelLarge);Text(c.getString("body"));if(c.optBoolean("can_remove"))TextButton(enabled=!busy&&commentPending==null,onClick={work{req("comment-remove",JSONObject().put("id",id).put("comment_id",c.getString("id")));loadComments(id);load()}}){Text(tr("Retirer le commentaire","Remove comment"))}}}
     OutlinedTextField(commentBody,{commentBody=it.take(1000)},enabled=!busy&&commentPending==null,label={Text(tr("Votre commentaire","Your comment"))},modifier=Modifier.fillMaxWidth())
     Button(enabled=!busy&&(commentBody.isNotBlank()||commentPending!=null),onClick={work{val payload=commentPending?:JSONObject().put("id",id).put("comment_id",UUID.randomUUID().toString()).put("body",commentBody.trim()).also{commentPending=it};req("comment",payload);commentPending=null;commentBody="";loadComments(id);load()}}){Text(if(commentPending!=null)tr("Réessayer le commentaire","Retry comment")else tr("Commenter","Comment"))}
    }
   }
   if(p.optBoolean("can_confirm")){if(p.optBoolean("confirmed"))Text(tr("Lecture confirmée","Reading confirmed"))else TextButton(enabled=!busy,onClick={work{req("confirm",JSONObject().put("id",id));load()}}){Text(tr("Confirmer la lecture","Confirm reading"))}}
   if(!p.isNull("confirmation_count"))Text(tr("Lectures confirmées","Confirmed readings")+": "+p.optInt("confirmation_count"))
   if(p.optBoolean("can_remove"))TextButton(enabled=!busy,onClick={remove=id}){Text(tr("Retirer","Remove"))}
   HorizontalDivider()
  }
 }
 voteConfirm?.let{(id,j)->AlertDialog(onDismissRequest={voteConfirm=null},title={Text(tr("Confirmer votre vote ?","Confirm your vote?"))},text={Text(tr("Il ne pourra plus être modifié.","It cannot be changed."))},confirmButton={TextButton(onClick={voteConfirm=null;work{req("vote",JSONObject().put("id",id).put("choice",j));load()}}){Text(tr("Confirmer","Confirm"))}},dismissButton={TextButton(onClick={voteConfirm=null}){Text(tr("Annuler","Cancel"))}})}
 closeConfirm?.let{id->AlertDialog(onDismissRequest={closeConfirm=null},title={Text(tr("Clôturer ce sondage ?","Close this poll?"))},confirmButton={TextButton(onClick={closeConfirm=null;work{req("poll-close",JSONObject().put("id",id));load()}}){Text(tr("Clôturer","Close"))}},dismissButton={TextButton(onClick={closeConfirm=null}){Text(tr("Annuler","Cancel"))}})}
 remove?.let{id->AlertDialog(onDismissRequest={remove=null},title={Text(tr("Retirer cette publication ?","Remove this post?"))},confirmButton={TextButton(onClick={remove=null;work{req("remove",JSONObject().put("id",id));load()}}){Text(tr("Retirer","Remove"))}},dismissButton={TextButton(onClick={remove=null}){Text(tr("Annuler","Cancel"))}})}
}
