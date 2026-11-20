package cm.naxa.naxaservices
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
fun ActivitySelectionScreen(locale:String,initialSelection:String?,busy:Boolean,error:String?,onSelect:(String)->Unit) {
 var expanded by remember { mutableStateOf(false) }
 var selected by rememberSaveable { mutableStateOf(initialSelection ?: "pressing") }
 val profile=NaxaActivityCatalog.find(selected); val fr=locale!="en"
 Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(22.dp),verticalArrangement=Arrangement.Center) {
  Text("NAXA SERVICES",style=MaterialTheme.typography.labelLarge,color=MaterialTheme.colorScheme.primary,fontWeight=FontWeight.Black)
  Spacer(Modifier.height(16.dp))
  Text(if(fr) "Choisir votre activité" else "Choose your business activity",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
  Text(if(fr) "Ce choix configure les écrans, le catalogue, les stocks et les workflows de votre ERP. Il sera mémorisé pour toute l’organisation."
   else "This choice configures ERP screens, catalogue, inventory and workflows. It is saved for the whole organization.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  Spacer(Modifier.height(20.dp))
  Box {
   OutlinedButton(onClick={expanded=true},modifier=Modifier.fillMaxWidth().height(58.dp)) {
    Text((profile?.icon ?: "🧰")+"  "+(if(fr) profile?.titleFr else profile?.titleEn))
   }
   DropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) {
    NaxaActivityCatalog.profiles.forEach { item ->
     DropdownMenuItem(text={Text(item.icon+"  "+(if(fr) item.titleFr else item.titleEn))},onClick={selected=item.key;expanded=false})
    }
   }
  }
  Spacer(Modifier.height(12.dp))
  Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant),shape=RoundedCornerShape(20.dp)) {
   Column(Modifier.fillMaxWidth().padding(18.dp)) {
    Text(profile?.icon ?: "🧰",style=MaterialTheme.typography.displaySmall)
    Text(if(fr) profile?.titleFr ?: "" else profile?.titleEn ?: "",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
    Text(if(fr) profile?.descriptionFr ?: "" else profile?.descriptionEn ?: "",color=MaterialTheme.colorScheme.onSurfaceVariant)
   }
  }
  if(!error.isNullOrBlank()) Text(error,color=MaterialTheme.colorScheme.error,modifier=Modifier.padding(top=12.dp))
  Spacer(Modifier.height(18.dp))
  Button(onClick={onSelect(selected)},enabled=!busy && profile!=null,modifier=Modifier.fillMaxWidth().height(54.dp)) {
   Text(if(busy) (if(fr) "Enregistrement…" else "Saving…") else if(fr) "Confirmer mon activité" else "Confirm activity")
  }
  Text(if(fr) "Le choix est enregistré au niveau de l’organisation. Les collaborateurs ne peuvent pas le remplacer depuis leur profil."
   else "The choice is stored at organization level. Employees cannot replace it from their profile.",color=MaterialTheme.colorScheme.onSurfaceVariant,style=MaterialTheme.typography.bodySmall,modifier=Modifier.padding(top=12.dp))
 }
}

@Composable
fun LegalAcceptanceScreen(locale:String,termsAccepted:Boolean,privacyAccepted:Boolean,onTermsChange:(Boolean)->Unit,onPrivacyChange:(Boolean)->Unit,onContinue:()->Unit,busy:Boolean) {
 val fr=locale!="en"
 LazyColumn(Modifier.fillMaxSize().padding(22.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
  item {
   Text(if(fr) "Avant de commencer" else "Before you start",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
   Text(if(fr) "Consultez les deux documents. Leur acceptation est enregistrée avec leur version, la date et votre compte."
    else "Review both documents. Acceptance is recorded with document version, date and account.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
  item {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
    Column(Modifier.padding(16.dp)) {
     Text(if(fr) "Conditions générales d’utilisation" else "Terms of use",fontWeight=FontWeight.Bold)
     Text(if(fr) "NAXA SERVICES fournit un outil de gestion. Le Promoteur reste responsable de la véracité des données, des opérations validées, de ses obligations professionnelles et des accès accordés à son équipe."
      else "NAXA SERVICES provides a management tool. The business owner remains responsible for data accuracy, approved operations, professional obligations and team access.",color=MaterialTheme.colorScheme.onSurfaceVariant)
     Text(if(fr) "Les paiements déclarés ne sont pas réputés confirmés sans preuve fiable. Les exports, reçus et calculs doivent être vérifiés avant usage externe."
      else "Declared payments are not considered confirmed without reliable evidence. Exports, receipts and calculations must be checked before external use.",color=MaterialTheme.colorScheme.onSurfaceVariant)
     Row(verticalAlignment=Alignment.CenterVertically){ Checkbox(termsAccepted,onTermsChange); Text(if(fr) "J’accepte les Conditions générales" else "I accept the Terms of use") }
    }
   }
  }
  item {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
    Column(Modifier.padding(16.dp)) {
     Text(if(fr) "Politique de confidentialité" else "Privacy policy",fontWeight=FontWeight.Bold)
     Text(if(fr) "Les données sont utilisées pour les opérations de l’organisation, la sécurité, l’assistance et les services activés. Les accès sont limités par rôle et périmètre. Les informations personnelles et les sauvegardes doivent être protégées et conservées selon une politique définie."
      else "Data is used for organization operations, security, support and enabled services. Access is restricted by role and scope. Personal information and backups must be protected and retained under a defined policy.",color=MaterialTheme.colorScheme.onSurfaceVariant)
     Text(if(fr) "Les fonctionnalités d’IA constituent une aide à la décision, pas un conseil comptable, financier ou fiscal."
      else "AI features are decision support, not accounting, financial or tax advice.",color=MaterialTheme.colorScheme.onSurfaceVariant)
     Row(verticalAlignment=Alignment.CenterVertically){ Checkbox(privacyAccepted,onPrivacyChange); Text(if(fr) "J’accepte la Politique de confidentialité" else "I accept the Privacy policy") }
    }
   }
  }
  item { Button(onClick=onContinue,enabled=termsAccepted && privacyAccepted && !busy,modifier=Modifier.fillMaxWidth().height(52.dp)){Text(if(fr) "Continuer" else "Continue")} }
 }
}

private data class DiscoveryCard(val icon:String,val titleFr:String,val titleEn:String,val bodyFr:String,val bodyEn:String)
@Composable
fun DiscoveryScreen(locale:String,onComplete:()->Unit) {
 val fr=locale!="en"
 val cards=remember { listOf(
  DiscoveryCard("🧭","Votre activité, votre ERP","Your business, your ERP","Les modules s’adaptent au métier que votre organisation a choisi.","Modules adapt to the business profile selected by your organization."),
  DiscoveryCard("📦","Opérations et stocks","Operations and inventory","Suivez les commandes, prestations, achats, consommations et coûts.","Track jobs, services, purchases, consumption and costs."),
  DiscoveryCard("📊","Pilotage au quotidien","Daily management","Comparez objectifs, ventes, caisse, marges et alertes.","Compare targets, sales, cash, margins and alerts."),
  DiscoveryCard("🛡️","Votre organisation reste protégée","Your organization stays protected","Les accès suivent les rôles, les sites et les emplacements autorisés.","Access follows authorized roles, sites and workstations.")
 ) }
 var page by rememberSaveable { mutableIntStateOf(0) }
 LaunchedEffect(page) { if(page<cards.lastIndex){delay(5000);page=(page+1).coerceAtMost(cards.lastIndex)} }
 val card=cards[page]
 Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(22.dp),verticalArrangement=Arrangement.Center) {
  Row(horizontalArrangement=Arrangement.spacedBy(6.dp)){cards.indices.forEach{idx->Box(Modifier.weight(1f).height(4.dp).background(if(idx<=page)MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,RoundedCornerShape(4.dp)))}}
  Spacer(Modifier.height(28.dp))
  Card(Modifier.fillMaxWidth(),shape=RoundedCornerShape(26.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant)) {
   Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
    Text(card.icon,style=MaterialTheme.typography.displayLarge)
    Text(if(fr)card.titleFr else card.titleEn,style=MaterialTheme.typography.headlineSmall,fontWeight=FontWeight.Bold)
    Text(if(fr)card.bodyFr else card.bodyEn,color=MaterialTheme.colorScheme.onSurfaceVariant,style=MaterialTheme.typography.bodyLarge)
   }
  }
  Spacer(Modifier.height(22.dp))
  Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically) {
   TextButton(onClick=onComplete){Text(if(fr)"Passer" else "Skip")}
   Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
    if(page>0)OutlinedButton(onClick={page--}){Text(if(fr)"Précédent" else "Back")}
    Button(onClick={if(page==cards.lastIndex)onComplete() else {page++}}){Text(if(page==cards.lastIndex){if(fr)"Commencer" else "Start"}else{if(fr)"Suivant" else "Next"})}
   }
  }
 }
}

@Composable
fun FirstUseTourContent(locale:String,step:Int,onNext:()->Unit,onSkip:()->Unit) {
 val fr=locale!="en"
 val items=listOf(
  Triple("📊","Tableau de bord","Votre activité, vos objectifs, vos alertes et les chiffres du jour."),
  Triple("🧾","Première opération","Créez un ticket, un rendez-vous, un ordre de travail ou une vente selon votre activité."),
  Triple("📦","Stock et coûts","Suivez les quantités, les prix d’achat, les consommations et les marges."),
  Triple("🛡️","Sécurité et abonnement","Contrôlez les rôles, les appareils, les droits et l’échéance de votre organisation."),
  Triple("💬","Assistance","Consultez la FAQ et contactez l’assistance depuis votre espace.")
 )
 val item=items[step.coerceIn(0,items.lastIndex)]
 Box(Modifier.fillMaxSize().background(Color(0xAA000000)).padding(18.dp),contentAlignment=Alignment.BottomCenter) {
  Card(shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
   Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
    Text((step+1).toString()+" / 5",color=MaterialTheme.colorScheme.primary,fontWeight=FontWeight.Bold)
    Text(item.first,style=MaterialTheme.typography.headlineMedium)
    Text(if(fr)item.second else listOf("Your activity, goals, alerts and key daily figures.","Create a ticket, appointment, work order or sale for your business.","Track quantities, purchase prices, consumption and margins.","Control roles, devices, access rights and subscription expiry.","Browse the FAQ and contact support from your workspace.")[step],style=MaterialTheme.typography.titleMedium,fontWeight=FontWeight.Bold)
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
     TextButton(onClick=onSkip){Text(if(fr)"Passer le tutoriel" else "Skip tutorial")}
     Button(onClick=onNext){Text(if(step==4){if(fr)"Terminer" else "Done"}else{if(fr)"J’ai compris" else "Got it"})}
    }
   }
  }
 }
}

@Composable
fun DashboardHeroCarousel(locale:String,activityProfile:String?,onOpen:()->Unit) {
 val fr=locale!="en"; val activity=NaxaActivityCatalog.find(activityProfile)
 val cards=listOf(
  Triple("📈",if(fr)"Performance du jour" else "Today's performance",if(fr)"Ventes, objectifs et tendances de votre activité." else "Sales, targets and business trends."),
  Triple(activity?.icon ?: "🧰",if(fr)activity?.titleFr ?: "Votre activité" else activity?.titleEn ?: "Your business",if(fr)activity?.descriptionFr ?: "Modules configurés pour votre métier." else activity?.descriptionEn ?: "Modules configured for your business."),
  Triple("📦",if(fr)"Stock et approvisionnement" else "Inventory and supply",if(fr)"Coûts, seuils de sécurité et réapprovisionnement." else "Costs, safety thresholds and replenishment."),
  Triple("🛡️",if(fr)"Vue de management" else "Management overview",if(fr)"Les données restent séparées par site et consolidées selon vos droits." else "Data stays separate by site and is consolidated according to your access.")
 )
 var index by rememberSaveable { mutableIntStateOf(0) }
 LaunchedEffect(Unit){while(true){delay(5000);index=(index+1)%cards.size}}
 val card=cards[index]
 Card(onClick=onOpen,modifier=Modifier.fillMaxWidth(),shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surfaceVariant),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant)){
  Row(Modifier.padding(18.dp),horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.CenterVertically){
   Text(card.first,style=MaterialTheme.typography.displayMedium)
   Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(5.dp)){
    Text(card.second,style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
    Text(card.third,color=MaterialTheme.colorScheme.onSurfaceVariant)
    Text((index+1).toString()+" / "+cards.size+"  •  "+(if(fr)"Explorer" else "Explore"),color=MaterialTheme.colorScheme.primary,style=MaterialTheme.typography.labelMedium)
   }
  }
 }
}

@Composable
fun AppearanceSettingsContent(locale:String,preferences:NaxaServicesPreferences,onChanged:(Boolean)->Unit) {
 val fr=locale!="en"
 var mode by rememberSaveable { mutableStateOf(preferences.themeMode()) }
 var start by rememberSaveable { mutableStateOf(formatMinute(preferences.nightStart())) }
 var end by rememberSaveable { mutableStateOf(formatMinute(preferences.nightEnd())) }
 var torch by rememberSaveable { mutableStateOf(preferences.flashlightEnabled()) }
 var error by remember { mutableStateOf<String?>(null) }
 LazyColumn(Modifier.fillMaxSize().padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
  item{
   Spacer(Modifier.height(12.dp)); Text(if(fr)"Apparence et mode nuit" else "Appearance and night mode",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
   Text(if(fr)"Le mode nuit s’applique à toutes les pages. Le programme est recalculé à chaque reprise de l’application." else "Night mode applies across all pages. The schedule is recalculated whenever the app resumes.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
  item{
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)){
    Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
     Text(if(fr)"Mode d’affichage" else "Display mode",fontWeight=FontWeight.Bold)
     listOf("dark","light","scheduled").forEach{value->
      Row(verticalAlignment=Alignment.CenterVertically){
       RadioButton(selected=mode==value,onClick={mode=value})
       Text(when(value){"dark"->if(fr)"Nuit permanente" else "Always dark";"light"->if(fr)"Clair permanent" else "Always light";else->if(fr)"Automatique selon les heures" else "Scheduled automatically"})
      }
     }
     OutlinedTextField(start,{start=it;error=null},modifier=Modifier.fillMaxWidth(),label={Text(if(fr)"Activation du mode nuit (HH:mm)" else "Night mode starts (HH:mm)")},singleLine=true)
     OutlinedTextField(end,{end=it;error=null},modifier=Modifier.fillMaxWidth(),label={Text(if(fr)"Désactivation du mode nuit (HH:mm)" else "Night mode ends (HH:mm)")},singleLine=true)
     Row(verticalAlignment=Alignment.CenterVertically){
      Switch(checked=torch,onCheckedChange={torch=it})
      Spacer(Modifier.size(8.dp))
      Column { Text(if(fr)"Mini-lampe torche" else "Mini flashlight",fontWeight=FontWeight.SemiBold); Text(if(fr)"Effet graphique doux autour des zones touchées." else "Soft visual light around touched controls.",style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant) }
     }
     if(error!=null)Text(error!!,color=MaterialTheme.colorScheme.error)
     Button(onClick={
      val s=parseMinute(start);val e=parseMinute(end)
      if(s==null||e==null)error=if(fr)"Saisis deux heures valides au format HH:mm." else "Enter two valid times as HH:mm."
      else{preferences.saveTheme(mode,s,e,torch);onChanged(preferences.isLightNow());error=null}
     },modifier=Modifier.fillMaxWidth()){Text(if(fr)"Enregistrer les préférences" else "Save preferences")}
    }
   }
  }
  item{
   Text(if(fr)"La lampe est une animation d’interface. Elle n’active jamais le flash LED du téléphone et ne demande aucune permission caméra." else "The flashlight is a UI animation. It never activates the phone LED flash and requires no camera permission.",style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
 }
}
private fun parseMinute(v:String):Int? {
 val m=Regex("^([01][0-9]|2[0-3]):([0-5][0-9])$").matchEntire(v.trim())?:return null
 return m.groupValues[1].toInt()*60+m.groupValues[2].toInt()
}
private fun formatMinute(v:Int):String="%02d:%02d".format(v/60,v%60)
