package cm.naxa.grillad
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import java.util.UUID
class MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{var appearance by rememberSaveable{mutableStateOf("Système")};val dark=when(appearance){"Sombre"->true;"Clair"->false;else->isSystemInDarkTheme()};GrilladTheme(dark){GrilladApp(appearance){appearance=it}}}}}
@Composable private fun GrilladApp(appearance:String,onAppearance:(String)->Unit){
 val ledger=remember{Ledger()};var revision by remember{mutableIntStateOf(0)}
 var page by remember{mutableStateOf("Accueil")};var site by remember{mutableStateOf(ledger.sites.first())};var message by remember{mutableStateOf("")}
 var actor by remember(site){mutableStateOf("manager-demo")};var reportPeriod by remember{mutableStateOf("jour")};var networkReport by remember{mutableStateOf(false)};var reason by remember(page,site){mutableStateOf("")};var name by remember(page){mutableStateOf("")};var value by remember(page){mutableStateOf("")};var cost by remember(page){mutableStateOf("")};var family by remember(page){mutableStateOf(families.first())};var selected by remember(page,site){mutableStateOf("")}
 val groups=linkedMapOf("Accueil" to listOf("Accueil"),"Vente" to listOf("Ventes","Catalogue"),"Activité" to listOf("Préparations","Caisse","Dépenses","Rapports","Prévisions","Point journalier"),"Plus" to listOf("Équipe","Points de vente","Notifications","Vidéosurveillance","ZIPPLE Connect","Abonnement","Profil","Aide"))
 val group=groups.entries.firstOrNull{page in it.value}?.key?:"Accueil"
 fun go(p:String){page=p;message=""}
 fun act(f:()->Unit){try{f();revision++;message="Opération démo enregistrée"}catch(e:Exception){message=e.message?:"Opération refusée"}}
 val current=remember(revision,site){ledger.items.filter{it.site==site}};val r=remember(revision,site){ledger.report(site,dayKey())}
 Scaffold(containerColor=MaterialTheme.colorScheme.background,bottomBar={
  NavigationBar(containerColor=MaterialTheme.colorScheme.surface){groups.entries.forEachIndexed{i,g->NavigationBarItem(selected=group==g.key,onClick={go(g.value.first())},icon={Text(listOf("⌂","＋","▥","⋯")[i],style=MaterialTheme.typography.titleLarge)},label={Text(g.key)},alwaysShowLabel=true)}}
 }){insets->
 Column(Modifier.fillMaxSize().padding(insets).padding(horizontal=16.dp)){
  Row(Modifier.fillMaxWidth().padding(vertical=12.dp),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=androidx.compose.ui.Alignment.CenterVertically){Column(Modifier.weight(1f)){Text("GrillaD",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold,color=MaterialTheme.colorScheme.primary);Text("Votre activité, simplement",style=MaterialTheme.typography.bodySmall)};OutlinedButton({go("Notifications")}){Text("Alertes")}}
  Surface(color=MaterialTheme.colorScheme.surfaceVariant,shape=RoundedCornerShape(12.dp)){Text("Démo locale — aucune donnée réelle. Données effacées à la fermeture.",Modifier.padding(10.dp),style=MaterialTheme.typography.bodySmall)}
  if(ledger.sites.size>1)Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){ledger.sites.forEach{p->TextButton({site=p;message=""},modifier=Modifier.heightIn(min=48.dp)){Text(if(site==p)"✓ "+p else p)}}}else Text(site,Modifier.padding(vertical=8.dp),style=MaterialTheme.typography.bodySmall)
  if(group!="Accueil")Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(6.dp)){groups.getValue(group).forEach{p->if(page==p)Button({go(p)},modifier=Modifier.heightIn(min=48.dp)){Text(p)}else OutlinedButton({go(p)},modifier=Modifier.heightIn(min=48.dp)){Text(p)}}}
  Text(page,Modifier.padding(top=8.dp,bottom=8.dp),style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.SemiBold)
  if(message.isNotEmpty())Surface(color=MaterialTheme.colorScheme.surfaceVariant,shape=RoundedCornerShape(12.dp)){Text(message,Modifier.padding(12.dp))}
  key(page,site){Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)){
   when(page){
    "Accueil","Rapports","Point journalier"->{val report=if(page=="Rapports")ledger.report(if(networkReport&&ledger.plan=="PREMIUM")null else site,if(reportPeriod=="tout")null else dayKey(),reportPeriod) else r;if(page=="Rapports"){Row(Modifier.horizontalScroll(rememberScrollState())){listOf("jour","semaine","mois","annee","tout").forEach{p->TextButton({reportPeriod=p}){Text(if(p==reportPeriod)"✓ $p" else p)}}};if(ledger.plan=="PREMIUM")TextButton({networkReport=!networkReport}){Text(if(networkReport)"Réseau démo" else "Point sélectionné")}};GrilladHero(report.ca,ledger.targets[site]?:0L);Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp)){GrilladMetric("Ventes",report.count.toString(),Modifier.weight(1f));GrilladMetric("Dépenses","${report.charges} F",Modifier.weight(1f))};GrilladMetric("Résultat indicatif",report.result?.let{"$it F"}?:"Non calculable",Modifier.fillMaxWidth());Text("Synthèse locale provisoire — ${dayKey()}",style=MaterialTheme.typography.bodySmall);if(page=="Accueil"){Button({go("Ventes")},modifier=Modifier.fillMaxWidth().heightIn(min=52.dp)){Text("＋ Nouvelle vente")};listOf(listOf("Catalogue","Préparations"),listOf("Caisse","Dépenses"),listOf("Équipe","Point journalier")).forEach{pair->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp)){pair.forEach{p->OutlinedButton({go(p)},Modifier.weight(1f).heightIn(min=52.dp)){Text(p)}}}};Text("Objectif CA : ${ledger.targets[site]?:0L} F");OutlinedTextField(value,{value=it},label={Text("Objectif CA (F)")});Button({act{ledger.targets[site]=value.toLong().also{require(it>=0)}}}){Text("Définir objectif")}}}
    "Catalogue"->{OutlinedTextField(name,{name=it},label={Text("Nom de l’article")});Row(Modifier.horizontalScroll(rememberScrollState())){families.forEach{f->TextButton({family=f}){Text(if(family==f)"✓ $f" else f)}}};OutlinedTextField(value,{value=it},label={Text("Prix F")});OutlinedTextField(cost,{cost=it},label={Text("Coût F (facultatif)")});Button({act{ledger.item(site,name,family,value.toLong(),cost.takeIf{it.isNotBlank()}?.toLong())}}){Text("Ajouter l’article")};current.forEach{Text("${it.name} · ${it.family} · ${it.price} F")}}
    "Préparations","Ventes"->{if(page=="Ventes")Row(Modifier.horizontalScroll(rememberScrollState())){(listOf("manager-demo")+ledger.staff.filter{it.first==site}.map{it.second}).forEach{p->TextButton({actor=p}){Text(if(actor==p)"✓ $p" else p)}}};current.forEach{item->OutlinedButton({selected=item.id}){Text((if(selected==item.id)"✓ " else "")+item.name+" · restant "+(item.prepared-item.sold))}};OutlinedTextField(value,{value=it},label={Text("Quantité")});Button({act{if(page=="Préparations")ledger.prepare(site,selected,value.toLong())else ledger.sell(site,selected,value.toLong(),UUID.randomUUID().toString(),actor)}}){Text(if(page=="Préparations")"Enregistrer la préparation" else "Enregistrer la vente")};if(page=="Ventes"){OutlinedTextField(reason,{reason=it},label={Text("Motif d’annulation")});ledger.sales.filter{it.site==site}.forEach{sale->OutlinedCard(Modifier.fillMaxWidth()){Column(Modifier.padding(12.dp)){Text("${sale.qty} unités · ${sale.total} F · ${sale.actor}");if(sale.cancelled)Text("Annulée : ${sale.reason}")else if(site in ledger.cash)OutlinedButton({act{ledger.cancel(site,sale.id,reason)}}){Text("Annuler cette vente")}}}}}}
    "Caisse"->{val opened=site in ledger.cash;if(opened){Text("Attendu : ${ledger.expected(site)} F");OutlinedTextField(reason,{reason=it},label={Text("Justification si écart")})};OutlinedTextField(value,{value=it},label={Text(if(opened)"Montant compté" else "Fonds initial")});Button({act{if(opened)ledger.close(site,value.toLong(),reason)else ledger.open(site,value.toLong())}}){Text(if(opened)"Clôturer la caisse" else "Ouvrir la caisse")};ledger.closings.filter{it.first==site}.forEach{Text("Écart : ${it.second} F")}}
    "Dépenses"->{OutlinedTextField(name,{name=it},label={Text("Libellé")});OutlinedTextField(value,{value=it},label={Text("Montant F")});Button({act{ledger.expense(site,name,value.toLong())}}){Text("Ajouter la dépense")};ledger.expenses.filter{it.site==site}.forEach{Text("${it.label} · ${it.value} F")}}
    "Équipe"->{OutlinedTextField(name,{name=it},label={Text("Nom fictif du vendeur")});Button({act{require(name.isNotBlank()&&name!="manager-demo"&&ledger.staff.none{it.first==site&&it.second==name}){"Nom déjà utilisé ou invalide"};ledger.staff.add(site to name)}}){Text("Ajouter un vendeur démo")};ledger.staff.filter{it.first==site}.forEach{Text(it.second)};Text("Pointage GPS/photo : serveur sécurisé non raccordé. Aucune capture dans la démo.")}
    "Points de vente"->{OutlinedTextField(name,{name=it},label={Text("Nom du point fictif")});Button({act{ledger.site(name)}}){Text("Ajouter un point")};ledger.sites.forEach{Text(it)}}
    "Prévisions"->{current.forEach{item->val days=ledger.sales.filter{it.site==site&&it.item==item.id&&!it.cancelled&&dayKey(it.at)!=dayKey()}.groupBy{dayKey(it.at)}.toSortedMap().values.toList().takeLast(7);Text(item.name+": "+if(days.size<3)"Historique insuffisant" else "${kotlin.math.ceil(days.map{d->d.sumOf{it.qty}}.average()).toLong()} unités estimées")};if(current.isEmpty())Text("Aucun article.")}
    "Notifications"->{current.filter{it.prepared<=it.sold}.forEach{Text(it.name+" : quantité épuisée")};ledger.closings.filter{it.first==site&&it.second!=0L}.forEach{Text("Écart de caisse à vérifier")};Text("Alertes locales seulement ; FCM non configuré.")}
    "Vidéosurveillance"->Text("NAXA SECURITY non raccordée. Aucun flux vidéo réel.")
    "ZIPPLE Connect"->Text("Partenariat Snack-Bar non raccordé. Aucun QR ou paiement réel.")
    "Abonnement"->{listOf("ACCESS","PREMIUM").forEach{p->Text("$p : ${planPrice(p,false)} F/mois · ${planPrice(p,true)} F/an");Button({act{require(p!="ACCESS"||ledger.sites.size==1){"Sites supplémentaires présents"};ledger.plan=p}}){Text("Tester $p")}};Text("Aucun achat ou abonnement réel.")}
    "Profil"->{Text("Promoteur fictif ; authentification réelle à raccorder.");Text("Apparence",style=MaterialTheme.typography.titleMedium);listOf("Système","Clair","Sombre").forEach{m->OutlinedButton({onAppearance(m)},Modifier.fillMaxWidth().heightIn(min=48.dp)){Text(if(appearance==m)"✓ $m" else m)}}}
    "Aide"->Text("Catalogue → caisse → préparations → ventes. Support en ligne non raccordé.")
   }
  }
 }
}
 }
 }
