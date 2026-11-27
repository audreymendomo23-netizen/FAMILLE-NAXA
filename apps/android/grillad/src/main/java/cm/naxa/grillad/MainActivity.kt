package cm.naxa.grillad
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import java.util.UUID
class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{MaterialTheme(colorScheme=lightColorScheme(primary=Color(0xFFA43C0C))){GrilladApp()}}}}
@Composable private fun GrilladApp(){
 val ledger=remember{Ledger()};var revision by remember{mutableIntStateOf(0)}
 var page by remember{mutableStateOf("Accueil")};var site by remember{mutableStateOf(ledger.sites.first())};var message by remember{mutableStateOf("")}
 var name by remember(page){mutableStateOf("")};var value by remember(page){mutableStateOf("")};var cost by remember(page){mutableStateOf("")};var family by remember(page){mutableStateOf(families.first())};var selected by remember(page,site){mutableStateOf("")}
 val pages=listOf("Accueil","Catalogue","Préparations","Ventes","Caisse","Dépenses","Équipe","Points de vente","Rapports","Prévisions","Point journalier","Notifications","Vidéosurveillance","ZIPPLE Connect","Abonnement","Profil","Aide")
 fun act(f:()->Unit){try{f();revision++;message="Opération démo enregistrée"}catch(e:Exception){message=e.message?:"Opération refusée"}}
 val current=remember(revision,site){ledger.items.filter{it.site==site}};val r=remember(revision,site){ledger.report(site,dayKey())}
 Column(Modifier.fillMaxSize().padding(16.dp)){
  Text("GRILLAD",style=MaterialTheme.typography.headlineMedium,color=MaterialTheme.colorScheme.primary)
  Text("Démo locale — données fictives, effacées à la fermeture. Aucun service réel.")
  Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){pages.forEach{p->if(page==p)Button({page=p}){Text(p)}else OutlinedButton({page=p;message=""}){Text(p)}}}
  Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){ledger.sites.forEach{p->TextButton({site=p;message=""}){Text(if(site==p)"✓ "+p else p)}}}
  Text(page,style=MaterialTheme.typography.titleLarge)
  if(message.isNotEmpty())Text(message)
  Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(8.dp)){
   when(page){
    "Accueil","Rapports","Point journalier"->{val report=if(page=="Rapports")ledger.report(site) else r;Text("CA net : ${report.ca} F");Text("Ventes : ${report.count}");Text("Dépenses : ${report.charges} F");Text("Résultat indicatif : ${report.result?.let{"$it F"}?:"Non calculable"}");Text("Synthèse locale provisoire — ${dayKey()}");if(page=="Accueil"){Text("Objectif CA : ${ledger.target} F");OutlinedTextField(value,{value=it},label={Text("Objectif CA (F)")});Button({act{ledger.target=value.toLong().also{require(it>=0)}}}){Text("Définir objectif")}}}
    "Catalogue"->{OutlinedTextField(name,{name=it},label={Text("Nom de l’article")});Row(Modifier.horizontalScroll(rememberScrollState())){families.forEach{f->TextButton({family=f}){Text(if(family==f)"✓ $f" else f)}}};OutlinedTextField(value,{value=it},label={Text("Prix F")});OutlinedTextField(cost,{cost=it},label={Text("Coût F (facultatif)")});Button({act{ledger.item(site,name,family,value.toLong(),cost.takeIf{it.isNotBlank()}?.toLong())}}){Text("Ajouter l’article")};current.forEach{Text("${it.name} · ${it.family} · ${it.price} F")}}
    "Préparations","Ventes"->{current.forEach{item->OutlinedButton({selected=item.id}){Text((if(selected==item.id)"✓ " else "")+item.name+" · restant "+(item.prepared-item.sold))}};OutlinedTextField(value,{value=it},label={Text("Quantité")});Button({act{if(page=="Préparations")ledger.prepare(site,selected,value.toLong())else ledger.sell(site,selected,value.toLong(),UUID.randomUUID().toString())}}){Text(if(page=="Préparations")"Enregistrer la préparation" else "Enregistrer la vente")};if(page=="Ventes")ledger.sales.filter{it.site==site}.forEach{Text("${it.qty} unités · ${it.total} F")}}
    "Caisse"->{val opened=site in ledger.cash;if(opened)Text("Attendu : ${ledger.expected(site)} F");OutlinedTextField(value,{value=it},label={Text(if(opened)"Montant compté" else "Fonds initial")});Button({act{if(opened)ledger.close(site,value.toLong())else ledger.open(site,value.toLong())}}){Text(if(opened)"Clôturer la caisse" else "Ouvrir la caisse")};ledger.closings.filter{it.first==site}.forEach{Text("Écart : ${it.second} F")}}
    "Dépenses"->{OutlinedTextField(name,{name=it},label={Text("Libellé")});OutlinedTextField(value,{value=it},label={Text("Montant F")});Button({act{ledger.expense(site,name,value.toLong())}}){Text("Ajouter la dépense")};ledger.expenses.filter{it.site==site}.forEach{Text("${it.label} · ${it.value} F")}}
    "Équipe"->{OutlinedTextField(name,{name=it},label={Text("Nom fictif du vendeur")});Button({act{require(name.isNotBlank());ledger.staff.add(site to name)}}){Text("Ajouter un vendeur démo")};ledger.staff.filter{it.first==site}.forEach{Text(it.second)};Text("Pointage GPS/photo : serveur sécurisé non raccordé. Aucune capture dans la démo.")}
    "Points de vente"->{OutlinedTextField(name,{name=it},label={Text("Nom du point fictif")});Button({act{ledger.site(name)}}){Text("Ajouter un point")};ledger.sites.forEach{Text(it)}}
    "Prévisions"->{current.forEach{item->val days=ledger.sales.filter{it.site==site&&it.item==item.id&&dayKey(it.at)!=dayKey()}.groupBy{dayKey(it.at)}.toSortedMap().values.toList().takeLast(7);Text(item.name+": "+if(days.size<3)"Historique insuffisant" else "${kotlin.math.ceil(days.map{d->d.sumOf{it.qty}}.average()).toLong()} unités estimées")};if(current.isEmpty())Text("Aucun article.")}
    "Notifications"->{current.filter{it.prepared<=it.sold}.forEach{Text(it.name+" : quantité épuisée")};ledger.closings.filter{it.first==site&&it.second!=0L}.forEach{Text("Écart de caisse à vérifier")};Text("Alertes locales seulement ; FCM non configuré.")}
    "Vidéosurveillance"->Text("NAXA SECURITY non raccordée. Aucun flux vidéo réel.")
    "ZIPPLE Connect"->Text("Partenariat Snack-Bar non raccordé. Aucun QR ou paiement réel.")
    "Abonnement"->{listOf("ACCESS","PREMIUM").forEach{p->Text("$p : ${planPrice(p,false)} F/mois · ${planPrice(p,true)} F/an");Button({act{require(p!="ACCESS"||ledger.sites.size==1){"Sites supplémentaires présents"};ledger.plan=p}}){Text("Tester $p")}};Text("Aucun achat ou abonnement réel.")}
    "Profil"->Text("Promoteur fictif ; authentification réelle à raccorder.")
    "Aide"->Text("Catalogue → caisse → préparations → ventes. Support en ligne non raccordé.")
   }
  }
 }
}
