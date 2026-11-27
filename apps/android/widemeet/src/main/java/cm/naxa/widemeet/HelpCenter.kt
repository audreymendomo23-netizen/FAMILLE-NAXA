package cm.naxa.widemeet
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable fun HelpCenter(english:Boolean,mode:String,authenticated:Boolean,onOpen:(String)->Unit){
 fun tr(fr:String,en:String)=if(english)en else fr
 fun go(key:String)=onOpen(if(authenticated||key=="faq")key else "signin")
 var query by remember{mutableStateOf("")}
 val topics=listOf(
 listOf("Comment rejoindre une réunion ?","How do I join a meeting?","Ouvrez Agenda, acceptez l’invitation et attendez l’admission si nécessaire.","Open Calendar, accept the invitation and await admission if required.","agenda"),
 listOf("Comment protéger mon compte ?","How do I secure my account?","Vérifiez et révoquez vos appareils dans Sécurité. Gardez votre clé de récupération secrète.","Review and revoke devices in Security. Keep your recovery key secret.","security"),
 listOf("Où retrouver mes comptes rendus ?","Where are my minutes?","Les archives affichent uniquement les documents auxquels votre compte a accès.","Archives display only documents your account may access.","archives"),
 listOf("Pourquoi une réunion ne démarre-t-elle pas ?","Why won't a meeting start?","Vérifiez le réseau, l’invitation, l’admission et les droits de l’organisateur.","Check network, invitation, admission and organizer permissions.","agenda"))
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){
 if(mode=="faq"){
  OutlinedTextField(query,{query=it},label={Text(tr("Rechercher dans l’aide","Search help"))},modifier=Modifier.fillMaxWidth())
  val results=topics.filter{t->t.take(4).any{it.contains(query.trim(),ignoreCase=true)}}
  if(results.isEmpty()){Text(tr("Aucun résultat. Essayez un autre mot.","No results. Try another word."));TextButton(onClick={query=""}){Text(tr("Effacer la recherche","Clear search"))}}
  for(topic in results){var expanded by remember(topic[0]){mutableStateOf(false)};TextButton(onClick={expanded=!expanded}){Text(tr(topic[0],topic[1]))};if(expanded){Text(tr(topic[2],topic[3]));Button(onClick={go(topic[4])}){Text(tr("Ouvrir cet espace","Open this area"))}}}
 }else{
 val info=when(mode){
 "support"->listOf("Les tickets et le Livechat ne sont pas encore connectés. Consultez l’aide sans transmettre votre mot de passe.","Tickets and live chat are not connected yet. Browse help without sharing your password.","faq","Consulter la FAQ","Read FAQ")
 "connect"->listOf("Le récepteur sécurisé n’est pas encore disponible. Rejoignez vos réunions sur cet appareil.","Secure receiver is not yet available. Join meetings on this device.","agenda","Ouvrir mon agenda","Open calendar")
 "transcription"->listOf("La transcription automatique n’est pas disponible. Les comptes rendus manuels restent accessibles selon vos droits.","Automatic transcription is unavailable. Manual minutes remain accessible according to your permissions.","archives","Ouvrir mes comptes rendus","Open minutes")
 else->listOf("Interface français et anglais. La traduction vocale simultanée n’est pas disponible.","French and English interface. Simultaneous voice translation is unavailable.","language","Changer la langue","Change language")
 }
 Text(tr(info[0],info[1]));Button(onClick={go(info[2])}){Text(tr(info[3],info[4]))}
 if(mode=="support")TextButton(onClick={go("security")}){Text(tr("Sécuriser mon compte","Secure my account"))}
 }
 }}
}
