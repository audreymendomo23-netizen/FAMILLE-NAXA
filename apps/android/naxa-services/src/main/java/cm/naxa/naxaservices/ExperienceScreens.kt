package cm.naxa.naxaservices
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
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
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
fun ActivitySelectionScreen(locale:String,initialSelection:String?,canChoose:Boolean,busy:Boolean,error:String?,onSelect:(String)->Unit) {
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
  if(!canChoose) Text(if(fr) "Seul le Promoteur peut choisir l’activité principale de l’organisation." else "Only the organization promoter can select the main activity.",color=MaterialTheme.colorScheme.error,modifier=Modifier.padding(top=10.dp))
  Button(onClick={onSelect(selected)},enabled=canChoose && !busy && profile!=null,modifier=Modifier.fillMaxWidth().height(54.dp)) {
   Text(if(busy) (if(fr) "Enregistrement…" else "Saving…") else if(fr) "Confirmer mon activité" else "Confirm activity")
  }
  Text(if(fr) "Le choix est enregistré au niveau de l’organisation. Les collaborateurs ne peuvent pas le remplacer depuis leur profil."
   else "The choice is stored at organization level. Employees cannot replace it from their profile.",color=MaterialTheme.colorScheme.onSurfaceVariant,style=MaterialTheme.typography.bodySmall,modifier=Modifier.padding(top=12.dp))
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
 val fr=locale!="en"
 var terms by rememberSaveable { mutableStateOf(initialTermsAccepted) }
 var privacy by rememberSaveable { mutableStateOf(initialPrivacyAccepted) }
 var showTerms by rememberSaveable { mutableStateOf(false) }
 var showPrivacy by rememberSaveable { mutableStateOf(false) }
 LazyColumn(Modifier.fillMaxSize().padding(22.dp),verticalArrangement=Arrangement.spacedBy(14.dp)) {
  item {
   Text(if(fr)"Avant de commencer" else "Before you start",style=MaterialTheme.typography.headlineMedium,fontWeight=FontWeight.Bold)
   Text(if(fr)"Lisez les deux documents. Chaque acceptation est enregistrée séparément avec sa version et votre compte."
    else "Read both documents. Each acceptance is recorded separately with its version and your account.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
  item {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
    Column(Modifier.padding(16.dp)) {
     Text(if(fr)"Conditions générales d’utilisation" else "Terms of use",fontWeight=FontWeight.Bold)
     Text(if(fr)"Objet, responsabilité de l’organisation, comptes, opérations, abonnements, usage hors connexion, documents, fiscalité, IA, support et sécurité."
      else "Purpose, organization responsibility, accounts, operations, subscriptions, offline use, documents, tax, AI, support and security.",color=MaterialTheme.colorScheme.onSurfaceVariant)
     TextButton(onClick={showTerms=true}){Text(if(fr)"Lire les conditions complètes" else "Read full terms")}
     Row(verticalAlignment=Alignment.CenterVertically){Checkbox(terms,{terms=it});Text(if(fr)"J’accepte les Conditions générales" else "I accept the Terms of use")}
    }
   }
  }
  item {
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
    Column(Modifier.padding(16.dp)) {
     Text(if(fr)"Politique de confidentialité" else "Privacy policy",fontWeight=FontWeight.Bold)
     Text(if(fr)"Données traitées, finalités, accès, IA, prestataires, conservation, sécurité, sauvegardes et droits des personnes."
      else "Processed data, purposes, access, AI, service providers, retention, security, backups and individual rights.",color=MaterialTheme.colorScheme.onSurfaceVariant)
     TextButton(onClick={showPrivacy=true}){Text(if(fr)"Lire la politique complète" else "Read full privacy policy")}
     Row(verticalAlignment=Alignment.CenterVertically){Checkbox(privacy,{privacy=it});Text(if(fr)"J’accepte la Politique de confidentialité" else "I accept the Privacy policy")}
    }
   }
  }
  if(!error.isNullOrBlank()) item { Text(error,color=MaterialTheme.colorScheme.error) }
  item { Button(onClick={onAccept(terms,privacy)},enabled=terms && privacy && !busy,modifier=Modifier.fillMaxWidth().height(52.dp)){Text(if(busy) (if(fr)"Enregistrement…" else "Saving…") else if(fr)"Continuer" else "Continue")} }
 }
 if(showTerms) androidx.compose.ui.window.Dialog(onDismissRequest={showTerms=false}) {
  Card(modifier=Modifier.fillMaxWidth(),shape=RoundedCornerShape(22.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
   LazyColumn(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
    item { Text(if(fr)"Conditions générales d’utilisation — version 2026-11-v1" else "Terms of use — version 2026-11-v1",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold) }
    val sections=if(fr) listOf(
     "Objet et acceptation" to "NAXA SERVICES est un outil logiciel de gestion. L’accès est réservé aux personnes ayant reçu un identifiant créé par un responsable. L’acceptation des conditions et de la politique de confidentialité est enregistrée séparément.",
     "Compte et responsabilités" to "Chaque utilisateur protège son identifiant et son mot de passe. Le Promoteur gère les comptes, les rôles, les sites et les révocations. Le partage d’identifiants est interdit.",
     "Organisation et activité" to "Le Promoteur choisit le profil métier principal lors de la première mise en service. Ce choix configure le modèle ERP de l’organisation. Le modèle solo, multi-emplacements ou multi-sites est indépendant du profil métier.",
     "Données et opérations" to "L’entreprise garantit l’exactitude des données. Les écritures validées ne sont pas effacées silencieusement. Les corrections, annulations et remboursements doivent être motivés et journalisés.",
     "Paiements et abonnements" to "Une déclaration de paiement n’est pas une preuve. Les abonnements sont activés après rapprochement fiable ou validation autorisée. L’échéance peut limiter les droits sans effacer les données.",
     "Hors connexion" to "Les données locales sont conservées jusqu’à synchronisation durable ou résolution du conflit. Une opération financière ne doit pas être rejouée comme nouvelle après un timeout.",
     "Documents et fiscalité" to "Les documents doivent être vérifiés avant remise externe. Les taux et obligations fiscales sont validés par un professionnel. Les estimations ne sont ni une déclaration ni un conseil fiscal.",
     "IA, assistance et sécurité" to "L’IA aide à la décision et ne confirme pas de paiements. Les appels et partages d’écran nécessitent un consentement explicite. Les utilisateurs protègent leurs appareils et leurs accès.",
     "Responsabilité et droit applicable" to "Les clauses finales de disponibilité, de responsabilité, de résiliation, de propriété intellectuelle, de droit applicable et les coordonnées officielles doivent être complétées et approuvées par conseil juridique avant usage commercial."
    ) else listOf(
     "Purpose and acceptance" to "NAXA SERVICES is business management software. Access is restricted to users given an account by an authorized manager. Terms and Privacy acceptance are recorded separately.",
     "Accounts and responsibilities" to "Each user protects their credentials. The owner manages accounts, roles, sites and revocation. Credential sharing is prohibited.",
     "Organization and activity" to "The owner selects the primary business profile during setup. This configures the organization's ERP model. Solo, multi-workstation and multi-site structures are separate from the business activity.",
     "Data and operations" to "The business is responsible for data accuracy. Approved entries are not silently erased. Corrections, cancellations and refunds require a reason and an audit trail.",
     "Payments and subscriptions" to "A payment declaration is not proof. Subscriptions activate after reliable reconciliation or authorized validation. Expiry can restrict rights without deleting data.",
     "Offline use" to "Local data remains until durable synchronization or conflict resolution. A financial event must not be replayed as a new event after a timeout.",
     "Documents and tax" to "Documents must be checked before external delivery. Tax rates and duties must be validated by a professional. Estimates are not filings or tax advice.",
     "AI, support and security" to "AI supports decisions and does not confirm payments. Calls and screen sharing require explicit consent. Users must protect their devices and accounts.",
     "Liability and applicable law" to "Final availability, liability, termination, intellectual property, governing law and official contact clauses must be completed and approved by counsel before commercial use."
    )
    items(sections){(title,body)->item{Column(verticalArrangement=Arrangement.spacedBy(3.dp)){Text(title,fontWeight=FontWeight.Bold);Text(body,color=MaterialTheme.colorScheme.onSurfaceVariant)}}}
    item { Text(if(fr)"Projet soumis à validation juridique avant toute utilisation commerciale." else "Draft subject to legal review before commercial use.",color=MaterialTheme.colorScheme.error) }
    item { Button(onClick={showTerms=false},modifier=Modifier.fillMaxWidth()){Text(if(fr)"Fermer" else "Close")} }
   }
  }
 }
 if(showPrivacy) androidx.compose.ui.window.Dialog(onDismissRequest={showPrivacy=false}) {
  Card(modifier=Modifier.fillMaxWidth(),shape=RoundedCornerShape(22.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)) {
   LazyColumn(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
    item { Text(if(fr)"Politique de confidentialité — version 2026-11-v1" else "Privacy policy — version 2026-11-v1",style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold) }
    val sections=if(fr) listOf(
     "Responsable et contact" to "L’identité légale, l’adresse et le contact de confidentialité de l’éditeur doivent être complétés avant publication.",
     "Données" to "Selon les modules activés : comptes, rôles, organisations, clients, fournisseurs, prestations, rendez-vous, tickets, ventes, paiements, factures, stocks, dépenses, rapports, appareils et journaux de sécurité.",
     "Finalités et accès" to "Les données servent à fournir l’ERP, sécuriser les comptes, gérer les opérations, synchroniser, facturer, assister et produire des indicateurs. Chaque organisation et chaque site restent isolés selon les droits.",
     "Consentements" to "Les photos, communications marketing, accès à certaines données de l’appareil, appels, partage d’écran et sauvegarde Google nécessitent des consentements distincts lorsque la loi l’exige.",
     "IA" to "Les analyses IA sont limitées aux données autorisées. Les informations d’une PME ne doivent jamais apparaître dans les réponses d’une autre. Les PIN, OTP et SMS bruts ne sont pas transmis à un modèle externe.",
     "Hébergement et conservation" to "Les prestataires réellement utilisés et leurs pays doivent être déclarés. Les durées de conservation sont définies par catégories et obligations applicables.",
     "Sécurité et droits" to "Les mesures visent contrôle d’accès, chiffrement, journalisation et sauvegarde sécurisée. Les procédures d’accès, rectification, opposition, effacement et portabilité doivent être complétées.",
     "Hors connexion et sauvegarde" to "Une partie des données peut rester localement sur le téléphone. Les sauvegardes Drive sont facultatives, chiffrées et ne contiennent pas les jetons de session."
    ) else listOf(
     "Controller and contact" to "The publisher's legal identity, address and privacy contact must be completed before release.",
     "Data" to "Depending on enabled modules: accounts, roles, organizations, customers, suppliers, services, appointments, tickets, sales, payments, invoices, inventory, expenses, reports, devices and security logs.",
     "Purposes and access" to "Data is used to provide the ERP, secure accounts, manage operations, synchronize, bill, support and produce indicators. Organizations and sites remain isolated according to permissions.",
     "Consent" to "Photos, marketing communications, device permissions, calls, screen sharing and Google backups require separate consent where legally required.",
     "AI" to "AI analysis is limited to authorized data. One SME's information must never appear in another SME's answers. PINs, OTPs and raw SMS are not sent to an external model.",
     "Hosting and retention" to "Actual providers and processing countries must be disclosed. Retention periods are defined by data category and applicable obligations.",
     "Security and rights" to "Safeguards include access control, encryption, logging and secure backups. Access, correction, objection, deletion and portability procedures must be completed.",
     "Offline and backups" to "Some data may remain locally on the device. Drive backups are optional, encrypted and exclude session tokens."
    )
    items(sections){(title,body)->item{Column(verticalArrangement=Arrangement.spacedBy(3.dp)){Text(title,fontWeight=FontWeight.Bold);Text(body,color=MaterialTheme.colorScheme.onSurfaceVariant)}}}
    item { Text(if(fr)"Projet soumis à validation juridique et conformité avant toute utilisation commerciale." else "Draft subject to legal and compliance review before commercial use.",color=MaterialTheme.colorScheme.error) }
    item { Button(onClick={showPrivacy=false},modifier=Modifier.fillMaxWidth()){Text(if(fr)"Fermer" else "Close")} }
   }
  }
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
 val context=LocalContext.current
 val fr=locale!="en"; val activity=NaxaActivityCatalog.find(activityProfile)
 val cards=listOf(
  Triple("📈",if(fr)"Performance du jour" else "Today's performance",if(fr)"Ventes, objectifs et tendances de votre activité." else "Sales, targets and business trends."),
  Triple(activity?.icon ?: "🧰",if(fr)activity?.titleFr ?: "Votre activité" else activity?.titleEn ?: "Your business",if(fr)activity?.descriptionFr ?: "Modules configurés pour votre métier." else activity?.descriptionEn ?: "Modules configured for your business."),
  Triple("📦",if(fr)"Stock et approvisionnement" else "Inventory and supply",if(fr)"Coûts, seuils de sécurité et réapprovisionnement." else "Costs, safety thresholds and replenishment."),
  Triple("🛡️",if(fr)"Vue de management" else "Management overview",if(fr)"Les données restent séparées par site et consolidées selon vos droits." else "Data stays separate by site and is consolidated according to your access.")
 )
 val folder=activityProfile?.takeIf { NaxaActivityCatalog.find(it)!=null } ?: "autre"
 val photoNames=remember(folder) {
  runCatching {
   context.assets.list("activities/$folder").orEmpty()
    .filter { it.lowercase().endsWith(".webp") || it.lowercase().endsWith(".jpg") || it.lowercase().endsWith(".jpeg") || it.lowercase().endsWith(".png") }
    .sorted()
  }.getOrDefault(emptyList())
 }
 var index by rememberSaveable { mutableIntStateOf(0) }
 var photoIndex by rememberSaveable(folder) { mutableIntStateOf(0) }
 LaunchedEffect(Unit){while(true){delay(5000);index=(index+1)%cards.size}}
 LaunchedEffect(photoNames.size) { if(photoNames.isNotEmpty()){while(true){delay(5000);photoIndex=(photoIndex+1)%photoNames.size}} }
 val photoName=photoNames.getOrNull(photoIndex)
 val bitmap:Bitmap?=remember(folder,photoName) {
  photoName?.let { name -> runCatching { context.assets.open("activities/$folder/$name").use { stream -> BitmapFactory.decodeStream(stream) } }.getOrNull() }
 }
 val card=cards[index]
 Card(onClick=onOpen,modifier=Modifier.fillMaxWidth(),shape=RoundedCornerShape(24.dp),colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surfaceVariant),border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant)){
  Box(Modifier.fillMaxWidth().height(164.dp)) {
   if(bitmap!=null) Image(bitmap.asImageBitmap(),contentDescription=null,modifier=Modifier.fillMaxSize(),contentScale=ContentScale.Crop)
   Box(Modifier.fillMaxSize().background(if(bitmap!=null) Color(0xCC101010) else MaterialTheme.colorScheme.surfaceVariant))
   Row(Modifier.fillMaxSize().padding(18.dp),horizontalArrangement=Arrangement.spacedBy(14.dp),verticalAlignment=Alignment.CenterVertically){
    Text(if(bitmap==null)card.first else " ",style=MaterialTheme.typography.displayMedium)
    Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy(5.dp)){
     Text(card.second,style=MaterialTheme.typography.titleLarge,fontWeight=FontWeight.Bold,color=if(bitmap!=null)Color.White else MaterialTheme.colorScheme.onSurface)
     Text(card.third,color=if(bitmap!=null)Color.White.copy(alpha=.9f) else MaterialTheme.colorScheme.onSurfaceVariant)
     Text((index+1).toString()+" / "+cards.size+"  •  "+(if(fr)"Explorer" else "Explore"),color=if(bitmap!=null)Color(0xFFFF8A80) else MaterialTheme.colorScheme.primary,style=MaterialTheme.typography.labelMedium)
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
   Text(if(fr)"Le mode nuit s’applique à toutes les pages. Le programme est recalculé à chaque reprise de l’application." else "Night mode applies across all pages. The schedule is recalculated whenever the app resumes.",color=MaterialTheme.colorScheme.onSurfaceVariant)
  }
  item{
   Card(colors=CardDefaults.cardColors(containerColor=MaterialTheme.colorScheme.surface)){
    Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){
     Text(if(fr)"Langue de l’application" else "Application language",fontWeight=FontWeight.Bold)
     Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
      OutlinedButton(onClick={onLocale("fr")},enabled=!fr){Text("Français")}
      OutlinedButton(onClick={onLocale("en")},enabled=fr){Text("English")}
     }
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
