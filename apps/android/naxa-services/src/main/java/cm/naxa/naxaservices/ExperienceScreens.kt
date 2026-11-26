package cm.naxa.naxaservices
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
fun ActivitySelectionScreen(locale:String,initialSelection:String?,canChoose:Boolean,busy:Boolean,error:String?,onLogout:()->Unit,onSelect:(String)->Unit) {
 var expanded by remember { mutableStateOf(false) }
 var selected by rememberSaveable { mutableStateOf(initialSelection ?: "pressing") }
 val profile=NaxaActivityCatalog.find(selected); val fr=locale!="en"
 Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).padding(22.dp),verticalArrangement=Arrangement.Center) {
  Text("NAXA SERVICES",style=MaterialTheme.typography.labelLarge,color=MaterialTheme.colorScheme.primary,fontWeight=FontWeight.Black)
  Spacer(Modifier.height(16.dp))
  Text(if(canChoose) { if(fr)"Choisir votre activité" else "Choose your business activity" } else { if(fr)"Configuration de votre organisation" else "Organization setup" },style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
  Text(if(canChoose) { if(fr)"Choisissez votre métier pour personnaliser votre espace de travail."
   else "Choose your business to personalize your workspace." }
   else { if(fr)"L’activité principale n’a pas encore été définie par le Promoteur. Déconnectez-vous et demandez-lui de terminer la configuration."
   else "The organization owner has not selected the main activity yet. Sign out and ask them to finish setup." },color=MaterialTheme.colorScheme.onSurfaceVariant)
  Spacer(Modifier.height(20.dp))
  if(canChoose) {
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
  } else {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant),shape=RoundedCornerShape(20.dp)) {
    Column(Modifier.fillMaxWidth().padding(18.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
     Text("🔒",style=MaterialTheme.typography.displaySmall)
     Text(if(fr)"En attente du Promoteur" else "Waiting for the organization owner",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
     Text(if(fr)"Le profil métier n’a pas encore été défini. Le Promoteur de votre organisation doit terminer cette configuration. Vous ne pouvez pas choisir une activité à sa place."
      else "The business profile has not been set yet. Your organization owner must finish setup. You cannot select an activity on their behalf.",color=MaterialTheme.colorScheme.onSurfaceVariant)
    }
   }
  }
  Spacer(Modifier.height(12.dp))
  if(canChoose) {
  Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant),shape=RoundedCornerShape(20.dp)) {
   Column(Modifier.fillMaxWidth().padding(18.dp)) {
    Text(profile?.icon ?: "🧰",style=MaterialTheme.typography.displaySmall)
    Text(if(fr) profile?.titleFr ?: "" else profile?.titleEn ?: "",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold)
    Text(if(fr) profile?.descriptionFr ?: "" else profile?.descriptionEn ?: "",color=MaterialTheme.colorScheme.onSurfaceVariant)
   }
  }
  }
  if(!error.isNullOrBlank()) Text(error,color=MaterialTheme.colorScheme.error,modifier=Modifier.padding(top=12.dp))
  Spacer(Modifier.height(18.dp))
  if(canChoose) {
   Button(onClick={onSelect(selected)},enabled=!busy && profile!=null,modifier=Modifier.fillMaxWidth().height(54.dp)) {
    Text(if(busy) (if(fr) "Enregistrement…" else "Saving…") else if(fr) "Confirmer mon activité" else "Confirm activity")
   }
  } else {
   OutlinedButton(onClick=onLogout,modifier=Modifier.fillMaxWidth().height(52.dp)) {
    Text(if(fr)"Se déconnecter" else "Sign out")
   }
  }
  Text(if(canChoose) { if(fr)"Votre choix s’applique à votre établissement."
   else "Your choice applies to your business." }
   else { if(fr)"Le choix du Promoteur configurera automatiquement votre espace de travail."
   else "The business profile selected by the owner will automatically configure your workspace." },color=MaterialTheme.colorScheme.onSurfaceVariant,style=MaterialTheme.typography.bodySmall,modifier=Modifier.padding(top=12.dp))
 }
}

@Composable
fun LegalAcceptanceScreen(
 locale:String,
 initialTermsAccepted:Boolean,
 initialPrivacyAccepted:Boolean,
 onAccept:(Boolean,Boolean)->Unit,
 busy:Boolean,
 error:String?
) {
 val context=LocalContext.current
 val fr=locale!="en"
 var terms by rememberSaveable { mutableStateOf(initialTermsAccepted) }
 var privacy by rememberSaveable { mutableStateOf(initialPrivacyAccepted) }
 var termsViewed by rememberSaveable { mutableStateOf(initialTermsAccepted) }
 var privacyViewed by rememberSaveable { mutableStateOf(initialPrivacyAccepted) }
 var showTerms by rememberSaveable { mutableStateOf(false) }
 var showPrivacy by rememberSaveable { mutableStateOf(false) }
 val termsAsset=if(fr)"legal/TERMS_OF_USE_2026-11-v1.md" else "legal/TERMS_OF_USE_2026-11-v1_EN.md"
 val privacyAsset=if(fr)"legal/PRIVACY_POLICY_2026-11-v1.md" else "legal/PRIVACY_POLICY_2026-11-v1_EN.md"
 val termsText=remember(termsAsset) {
  runCatching { context.assets.open(termsAsset).bufferedReader(Charsets.UTF_8).use { it.readText() } }
   .getOrElse { if(fr)"Conditions générales indisponibles. Contactez l’assistance." else "Terms are unavailable. Contact support." }
 }
 val privacyText=remember(privacyAsset) {
  runCatching { context.assets.open(privacyAsset).bufferedReader(Charsets.UTF_8).use { it.readText() } }
   .getOrElse { if(fr)"Politique de confidentialité indisponible. Contactez l’assistance." else "Privacy policy is unavailable. Contact support." }
 }
 LazyColumn(Modifier.fillMaxSize().padding(22.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
  item {
   Text(if(fr)"Avant de commencer" else "Before you start",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
   Text(if(fr)"Lisez les deux documents complets. Vous devez les ouvrir avant de confirmer séparément chaque acceptation."
    else "Read both complete documents. You must open them before separately confirming each acceptance.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
  item {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
    Column(Modifier.padding(16.dp)) {
     Text(if(fr)"Conditions générales d’utilisation" else "Terms of use",fontWeight=FontWeight.Bold)
     Text(if(termsViewed)(if(fr)"Document consulté" else "Document viewed") else (if(fr)"Lecture obligatoire" else "Reading required"),color=MaterialTheme.colorScheme.onSurfaceVariant)
     TextButton(onClick={showTerms=true}){Text(if(fr)"Lire les conditions complètes" else "Read full terms")}
     Row(verticalAlignment=Alignment.CenterVertically) {
      Checkbox(checked=terms,onCheckedChange={terms=it},enabled=termsViewed)
      Text(if(fr)"J’accepte les Conditions générales" else "I accept the Terms of use")
     }
    }
   }
  }
  item {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
    Column(Modifier.padding(16.dp)) {
     Text(if(fr)"Politique de confidentialité" else "Privacy policy",fontWeight=FontWeight.Bold)
     Text(if(privacyViewed)(if(fr)"Document consulté" else "Document viewed") else (if(fr)"Lecture obligatoire" else "Reading required"),color=MaterialTheme.colorScheme.onSurfaceVariant)
     TextButton(onClick={showPrivacy=true}){Text(if(fr)"Lire la politique complète" else "Read full privacy policy")}
     Row(verticalAlignment=Alignment.CenterVertically) {
      Checkbox(checked=privacy,onCheckedChange={privacy=it},enabled=privacyViewed)
      Text(if(fr)"J’accepte la Politique de confidentialité" else "I accept the Privacy policy")
     }
    }
   }
  }
  if(!error.isNullOrBlank()) item { Text(error,color=MaterialTheme.colorScheme.error) }
  item {
   Button(onClick={onAccept(terms,privacy)},enabled=terms && privacy && termsViewed && privacyViewed && !busy,modifier=Modifier.fillMaxWidth().height(52.dp)) {
    Text(if(busy)(if(fr)"Enregistrement…" else "Saving…") else if(fr)"Continuer" else "Continue")
   }
  }
 }
 if(showTerms) androidx.compose.material3.AlertDialog(
  onDismissRequest={showTerms=false},
  title={Text(if(fr)"Conditions générales — version 2026-11-v1" else "Terms of use — version 2026-11-v1")},
  text={
   Text(legalPlainText(termsText),modifier=Modifier.heightIn(max=480.dp).verticalScroll(rememberScrollState()),style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
  },
  confirmButton={TextButton(onClick={termsViewed=true;showTerms=false}){Text(if(fr)"J’ai lu les conditions" else "I have read the terms")}},
  dismissButton={TextButton(onClick={showTerms=false}){Text(if(fr)"Fermer" else "Close")}}
 )
 if(showPrivacy) androidx.compose.material3.AlertDialog(
  onDismissRequest={showPrivacy=false},
  title={Text(if(fr)"Politique de confidentialité — version 2026-11-v1" else "Privacy policy — version 2026-11-v1")},
  text={
   Text(legalPlainText(privacyText),modifier=Modifier.heightIn(max=480.dp).verticalScroll(rememberScrollState()),style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
  },
  confirmButton={TextButton(onClick={privacyViewed=true;showPrivacy=false}){Text(if(fr)"J’ai lu la politique" else "I have read the policy")}},
  dismissButton={TextButton(onClick={showPrivacy=false}){Text(if(fr)"Fermer" else "Close")}}
 )
}

private fun legalPlainText(raw:String):String = raw
 .lineSequence()
 .map { line ->
  var clean=line.trim()
  while(clean.startsWith("#")) clean=clean.drop(1)
  clean.trim().replace("**","").replace(96.toChar().toString(),"")
 }
 .filterNot { it.startsWith("> ") || it.startsWith("---") }
 .joinToString("\n")

private data class DiscoveryCard(val icon:String,val titleFr:String,val titleEn:String,val bodyFr:String,val bodyEn:String)
@Composable
fun DiscoveryScreen(locale:String,onComplete:()->Unit) {
 val fr=locale!="en"
 val cards=remember { listOf(
  DiscoveryCard("🧭","Votre activité, votre gestion","Your business, your workspace","Les modules s’adaptent au métier que votre organisation a choisi.","Modules adapt to the business profile selected by your organization."),
  DiscoveryCard("📦","Opérations et stocks","Operations and inventory","Suivez les commandes, prestations, achats, consommations et coûts.","Track jobs, services, purchases, consumption and costs."),
  DiscoveryCard("📊","Pilotage au quotidien","Daily management","Comparez objectifs, ventes, caisse, marges et alertes.","Compare targets, sales, cash, margins and alerts."),
  DiscoveryCard("🛡️","Votre organisation reste protégée","Your organization stays protected","Les accès suivent les rôles, les sites et les emplacements autorisés.","Access follows authorized roles, sites and workstations.")
 ) }
 var page by rememberSaveable { mutableIntStateOf(0) }
 LaunchedEffect(page) { if(page<cards.lastIndex){delay(4000);page=(page+1).coerceAtMost(cards.lastIndex)} }
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
 val context=LocalContext.current
 val fr=locale!="en"; val activity=NaxaActivityCatalog.find(activityProfile)
 val cards=listOf(
  Triple("📈",if(fr)"Performance du jour" else "Today's performance",if(fr)"Ventes, objectifs et tendances de votre activité." else "Sales, targets and business trends."),
  Triple(activity?.icon ?: "🧰",if(fr)activity?.titleFr ?: "Votre activité" else activity?.titleEn ?: "Your business",if(fr)activity?.descriptionFr ?: "Retrouvez les services de votre activité." else activity?.descriptionEn ?: "Explore your business services."),
  Triple("📦",if(fr)"Stock et approvisionnement" else "Inventory and supply",if(fr)"Coûts, seuils de sécurité et réapprovisionnement." else "Costs, safety thresholds and replenishment."),
  Triple("🛡️",if(fr)"Vue de management" else "Management overview",if(fr)"Les données restent séparées par site et consolidées selon vos droits." else "Data stays separate by site and is consolidated according to your access.")
 )
 var index by rememberSaveable { mutableIntStateOf(0) }
 LaunchedEffect(Unit){while(true){delay(4000);index=(index+1)%cards.size}}
 val card=cards[index]
 Card(onClick=onOpen,modifier=Modifier.fillMaxWidth(),shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surfaceVariant),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant)){
  Box(Modifier.fillMaxWidth().heightIn(min=164.dp)) {
   BusinessPhotoBackdrop(activity=activityProfile,modifier=Modifier.matchParentSize())
   Row(Modifier.fillMaxWidth().padding(18.dp),horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.CenterVertically){
    Text(card.first,style=MaterialTheme.typography.titleLarge)
    Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(5.dp)){
     Text(card.second,style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold,color=Color.White)
     Text(card.third,color=Color.White.copy(alpha=.94f))
     Text((index+1).toString()+" / "+cards.size+"  •  "+(if(fr)"Explorer" else "Explore"),color=Color(0xFFFFA8A0),style=MaterialTheme.typography.labelMedium)
    }
   }
  }
 }
}

@Composable
fun AppearanceSettingsContent(locale:String,preferences:NaxaServicesPreferences,onChanged:(Boolean)->Unit,onLocale:(String)->Unit) {
 val fr=locale!="en"
 var mode by rememberSaveable { mutableStateOf(preferences.themeMode()) }
 var start by rememberSaveable { mutableStateOf(formatMinute(preferences.nightStart())) }
 var end by rememberSaveable { mutableStateOf(formatMinute(preferences.nightEnd())) }
 var torch by rememberSaveable { mutableStateOf(preferences.flashlightEnabled()) }
 var error by remember { mutableStateOf<String?>(null) }
 LazyColumn(Modifier.fillMaxSize().padding(horizontal=18.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
  item{
   Spacer(Modifier.height(12.dp)); Text(if(fr)"Apparence et mode nuit" else "Appearance and night mode",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
   Text(if(fr)"Choisissez votre confort visuel, de jour comme de nuit." else "Choose your preferred display, day or night.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
  item{
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)){
    Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
     Text(if(fr)"Langue de l’application" else "Application language",fontWeight=FontWeight.Bold)
     Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
      OutlinedButton(onClick={onLocale("fr")},enabled=locale!="fr"){Text("Français")}
      OutlinedButton(onClick={onLocale("en")},enabled=locale!="en"){Text("English")}
      OutlinedButton(onClick={onLocale("ff-CM")},enabled=locale!="ff-CM"){Text("Fulfulde")}
     }
     if(locale=="ff-CM") Text("Certaines pages restent disponibles en français.", color=MaterialTheme.colorScheme.onSurfaceVariant, style=MaterialTheme.typography.bodySmall)
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
