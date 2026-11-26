package cm.naxa.bootik
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import org.json.JSONObject
@Composable fun BootikFirstUse(api:BootikApi,session:BootikSession,onDone:()->Unit,onLogout:()->Unit){
 val scope=rememberCoroutineScope();var state by remember{mutableStateOf<JSONObject?>(null)};var step by remember{mutableStateOf(0)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf("")}
 val discovery=listOf(Triple("🧭","Votre activité, votre gestion","Les modules s’adaptent aux activités attribuées à votre compte."),Triple("📦","Opérations et stocks","Suivez les articles, achats, mouvements et coûts."),Triple("📊","Pilotage au quotidien","Suivez ventes, caisse et indicateurs autorisés."),Triple("🛡️","Votre organisation reste protégée","Les accès suivent vos rôles et vos sites."))
 val tour=listOf(Triple("📊","Tableau de bord","Retrouvez vos indicateurs selon vos droits."),Triple("🧾","Caisse et ventes","Ouvrez une caisse, préparez une vente et consultez vos opérations."),Triple("📦","Stock et achats","Recherchez les articles, suivez quantités et approvisionnements."),Triple("🛡️","Sécurité et abonnement","Consultez appareils, droits et échéances autorisées."),Triple("💬","Assistance","Demandez de l’aide depuis votre espace."))
 fun task(p:JSONObject?=null){if(busy)return;busy=true;message="";scope.launch{try{state=if(p==null)api.onboarding(session) else api.onboardingStep(session,p);step=0}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){message="Étape non confirmée. Réessayez."}finally{busy=false}}}
 LaunchedEffect(session.token){task()}
 val current=state
 val docs=current?.optJSONArray("documents")
 val doc=if(docs==null)null else (0 until docs.length()).map{docs.getJSONObject(it)}.firstOrNull{!it.optBoolean("accepted")}
 LaunchedEffect(current){if(current!=null&&doc==null&&current.optBoolean("discovery_completed")&&current.optBoolean("tour_completed"))onDone()}
 Text("Bienvenue dans BOOTIK",style=MaterialTheme.typography.headlineSmall)
 if(current==null){Text(if(busy)"Chargement…" else message);Button(enabled=!busy,onClick={task()}){Text("Réessayer")}}
 else if(doc!=null){Text(if(doc.getString("kind")=="terms")"Conditions d’utilisation" else "Politique de confidentialité",style=MaterialTheme.typography.titleLarge);Text("Version "+doc.getString("version")+" • "+doc.getString("locale"));Text(doc.getString("text"));Button(enabled=!busy,onClick={task(JSONObject().put("step","legal").put("kind",doc.getString("kind")).put("version",doc.getString("version")).put("sha256",doc.getString("sha256")).put("locale",doc.getString("locale")).put("accepted",true))}){Text("J’accepte ce document")}}
 else{val first=!current.optBoolean("discovery_completed");val items=if(first)discovery else if(session.role=="staff")listOf(Triple("📊","Mon espace","Retrouvez votre site et vos opérations autorisées."))+tour.drop(1) else tour;val item=items[step.coerceIn(0,items.lastIndex)]
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){Text("${step+1} / ${items.size}",color=MaterialTheme.colorScheme.primary);Text(item.first,style=MaterialTheme.typography.headlineLarge);Text(item.second,style=MaterialTheme.typography.titleLarge);Text(item.third)}}
 if(step>0)TextButton(enabled=!busy,onClick={step--}){Text("Précédent")}
 TextButton(enabled=!busy,onClick={task(JSONObject().put("step",if(first)"discovery" else "tour"))}){Text(if(first)"Passer la découverte" else "Passer le tutoriel")}
 Button(enabled=!busy,onClick={if(step<items.lastIndex)step++ else task(JSONObject().put("step",if(first)"discovery" else "tour"))}){Text(if(step==items.lastIndex){if(first)"Commencer" else "Terminer"}else if(first)"Suivant" else "J’ai compris")}
 };Text(message);TextButton(enabled=!busy,onClick=onLogout){Text("Se déconnecter")}
}
