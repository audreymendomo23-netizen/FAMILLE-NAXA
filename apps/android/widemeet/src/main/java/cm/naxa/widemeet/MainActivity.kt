package cm.naxa.widemeet

import android.os.Bundle
import android.content.Context
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import android.os.SystemClock
import cm.naxa.widemeet.auth.*

private val Green=Color(0xFF78C800);private val Yellow=Color(0xFFFFE52B)
private val White=Color(0xFFFFFFFF);private val Black=Color(0xFF121714)
private val Blue=Color(0xFF29B9FF);private val Orange=Color(0xFFFF9A24)
private val Red=Color(0xFFE43636);private val Deep=Color(0xFF07552C)
private val tabs=listOf("Accueil","Agenda","Chat","Archives","Profil")
private val tabsEn=listOf("Home","Calendar","Chat","Archives","Profile")
private val symbols=listOf("⌂","▦","◉","▤","○")
private val menuFr=listOf("Contacts et favoris","Mon entreprise","Équipe","Réunions simultanées","Statistiques","Votes et enquêtes","Décisions et tâches","Abonnements","Sécurité","Livechat et support","FAQ","Langue","Apparence","Paramètres")
private val menuEn=listOf("Contacts and favorites","My company","Team","Concurrent meetings","Statistics","Polls and surveys","Decisions and tasks","Subscriptions","Security","Live chat and support","FAQ","Language","Appearance","Settings")

class MainActivity:ComponentActivity(){
 override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);enableEdgeToEdge();setContent{WideMeetRoot()}}
}

@Composable private fun WideMeetRoot(){
 val context=LocalContext.current
 val gateway=remember{AuthGateway(context,BuildConfig.WIDEMEET_AUTH_URL)}
 var session by remember{mutableStateOf<Session?>(null)}
 var signIn by remember{mutableStateOf(false)}
 var logoutError by remember{mutableStateOf(false)}
 var switchError by remember{mutableStateOf(false)}
 var switching by remember{mutableStateOf(false)}
 var switchDialog by remember{mutableStateOf(false)}
 val coroutineScope=rememberCoroutineScope()
 LaunchedEffect(session){while(session!=null){val s=session?:break;if(!validLease(s,System.currentTimeMillis(),SystemClock.elapsedRealtime())){session=null;break};delay(1000)}}
 val current=session?.let{activeWorkspace(it,System.currentTimeMillis(),SystemClock.elapsedRealtime())}
 val prefs=remember{context.getSharedPreferences("widemeet.appearance.v1",Context.MODE_PRIVATE)}
 var dark by rememberSaveable{mutableStateOf(prefs.getBoolean("dark",false))}
 var english by rememberSaveable{mutableStateOf(prefs.getBoolean("english",false))}
 var motion by rememberSaveable{mutableStateOf(prefs.getBoolean("motion",true))}
 var tab by rememberSaveable{mutableIntStateOf(0)}
 var detail by rememberSaveable{mutableStateOf("")}
 var menu by rememberSaveable{mutableStateOf(false)}
 var tour by rememberSaveable{mutableIntStateOf(-1)}
 var pulse by remember{mutableIntStateOf(0)}
 val alpha=remember{Animatable(0f)}
 val startup=remember{Animatable(0f)}
 val systemMotion=Settings.Global.getFloat(context.contentResolver,Settings.Global.ANIMATOR_DURATION_SCALE,1f)>0f
 val animate=motion&&systemMotion
 LaunchedEffect(dark,english,motion){prefs.edit().putBoolean("dark",dark).putBoolean("english",english).putBoolean("motion",motion).apply()}
 LaunchedEffect(animate){if(animate){startup.snapTo(.6f);startup.animateTo(0f,tween(1200))}else startup.snapTo(0f)}
 LaunchedEffect(pulse,animate){if(pulse>0&&animate){alpha.snapTo(.5f);alpha.animateTo(0f,tween(1700))}else alpha.snapTo(0f)}
 fun changeWorkspace(id:String){val s=session?:return;if(switching||id==s.activeWorkspaceId)return;switching=true;switchDialog=false;switchError=false;coroutineScope.launch{try{session=gateway.switchWorkspace(s,id);detail="";tab=0}catch(e:kotlinx.coroutines.CancellationException){throw e}catch(e:Exception){session=null;detail="";tab=0;switchError=true}finally{switching=false}}}
 fun logout(){if(switching)return;val s=session?:return;session=null;logoutError=false;coroutineScope.launch{try{gateway.logout(s)}catch(e:Exception){logoutError=true}}}
 fun toggle(){if(!dark&&animate)pulse++ else pulse=0;dark=!dark}
 fun tr(fr:String,en:String)=if(english)en else fr
 val labels=if(english)tabsEn else tabs
 val menuLabels=if(english)menuEn else menuFr
 val colors=if(dark)darkColorScheme(primary=Green,onPrimary=Black,secondary=Yellow,onSecondary=Black,background=Color(0xFF101611),surface=Color(0xFF1A241C),onSurface=White,onBackground=White,error=Color(0xFFFF7777)) else lightColorScheme(primary=Deep,onPrimary=White,secondary=Yellow,onSecondary=Black,background=Color(0xFFF6FAEF),surface=White,onSurface=Black,onBackground=Black,error=Red)
 val unavailable=tr("Cet espace sera disponible à la connexion de votre compte.","This area will be available when your account is connected.")
 MaterialTheme(colorScheme=colors){
 Scaffold(contentWindowInsets=WindowInsets.safeDrawing,topBar={
 Row(Modifier.fillMaxWidth().padding(horizontal=12.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically){
  Surface(color=White,shape=MaterialTheme.shapes.medium,modifier=Modifier.weight(1f)){Image(painterResource(R.drawable.widemeet_logo),contentDescription="WideMeet",modifier=Modifier.height(44.dp).padding(6.dp))}
  TextButton(onClick={toggle()}){Text(if(dark)"☀" else "☾",fontSize=22.sp)}
  TextButton(onClick={menu=true}){Text("☰",fontSize=22.sp)}
 }
 },bottomBar={NavigationBar{labels.forEachIndexed{i,l->NavigationBarItem(selected=tab==i&&detail.isEmpty(),onClick={tab=i;detail=""},icon={Text(symbols[i],fontSize=22.sp)},label={Text(l,fontSize=11.sp)},colors=NavigationBarItemDefaults.colors(indicatorColor=Green,selectedIconColor=Black,selectedTextColor=colors.onSurface))}}}){padding->
 Box(Modifier.fillMaxSize().padding(padding)){
 Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
 if(switchError)Text(tr("Changement d’espace non confirmé. Reconnectez-vous.","Workspace switch unconfirmed. Sign in again."),color=MaterialTheme.colorScheme.error)
 if(logoutError)Text(tr("Déconnexion locale effectuée ; révocation distante non confirmée.","Local sign-out completed; remote revocation unconfirmed."),color=MaterialTheme.colorScheme.error)
 if(signIn){SignIn(english,BuildConfig.WIDEMEET_AUTH_URL.isNotBlank(),gateway,{session=it;signIn=false;tab=0;detail=""},{signIn=false})}
 else if(session?.requirePasswordChange==true){Text(tr("Votre mot de passe doit être changé avant d’accéder à votre espace.","Change your password before accessing your workspace."));Button(onClick={logout()}){Text(tr("Se déconnecter","Sign out"))}}
 else if(detail.isNotEmpty()){TextButton(onClick={detail=""}){Text(tr("← Retour","← Back"))};Text(detail,style=MaterialTheme.typography.headlineMedium)
 if(detail in listOf(menuFr[11],menuFr[12],menuFr[13],menuEn[11],menuEn[12],menuEn[13])){Button(onClick={toggle()}){Text(if(dark)tr("Mode clair","Light mode")else tr("Mode nuit","Dark mode"))};Button(onClick={english=!english;detail=""}){Text(if(english)"Français"else "English")};Row(verticalAlignment=Alignment.CenterVertically){Switch(checked=motion,onCheckedChange={motion=it});Text("Animations")}}else Text(unavailable)
 }else if(tab==0){
 Card(colors=CardDefaults.cardColors(containerColor=Deep,contentColor=White),modifier=Modifier.fillMaxWidth()){
 Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
 Text(tr("Vos réunions, sans frontières.","Your meetings, without borders."),style=MaterialTheme.typography.headlineMedium)
 if(current!=null){Text(current.name);if((session?.workspaces?.size?:0)>1)Button(enabled=!switching,onClick={switchDialog=true}){Text(tr("Changer d’espace","Switch workspace"))}}else Button(onClick={signIn=true}){Text(tr("Se connecter","Sign in"))}
 Text(tr("Découvrez votre espace","Discover your workspace"))
 Button(onClick={tour=0},colors=ButtonDefaults.buttonColors(containerColor=Yellow,contentColor=Black)){Text(tr("Découvrez WideMeet","Discover WideMeet"))}
 }}
 val actions=listOf(tr("Nouvelle réunion","New meeting"),tr("Programmer","Schedule"),tr("Rejoindre","Join"),tr("Mes rapports","My reports"))
 val marks=listOf("＋","▦","↗","▤");val accents=listOf(Green,Yellow,Blue,Orange)
 for(row in 0..1){Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(10.dp)){for(col in 0..1){val i=row*2+col
 Card(onClick={detail=actions[i]},modifier=Modifier.weight(1f).heightIn(min=110.dp)){
 Column(Modifier.padding(14.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Surface(color=accents[i],shape=MaterialTheme.shapes.medium){Text(marks[i],color=Black,fontSize=23.sp,modifier=Modifier.padding(8.dp))};Text(actions[i],style=MaterialTheme.typography.titleMedium)}
 }}}}
 Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(8.dp)){Text(labels[1],style=MaterialTheme.typography.titleLarge);Text(unavailable)}}
 }else{Text(labels[tab],style=MaterialTheme.typography.headlineMedium);Card(Modifier.fillMaxWidth()){Column(Modifier.padding(18.dp)){Text(unavailable);if(tab==4){TextButton(onClick={detail=menuLabels[13]}){Text(menuLabels[13])};TextButton(onClick={detail=menuLabels[9]}){Text(menuLabels[9])}}}}}
 }
 if(alpha.value>0f||startup.value>0f)Box(Modifier.matchParentSize().background(Brush.radialGradient(listOf(Yellow.copy(alpha=maxOf(alpha.value,startup.value)),Color.Transparent),center=Offset(0f,0f),radius=700f)))
 }
 }
 if(switchDialog)AlertDialog(onDismissRequest={switchDialog=false},title={Text(tr("Changer d’espace","Switch workspace"))},text={Column{session?.workspaces?.forEach{w->TextButton(enabled=!switching&&w.id!=session?.activeWorkspaceId,onClick={changeWorkspace(w.id)}){Text(w.name)}}}},confirmButton={TextButton(onClick={switchDialog=false}){Text(tr("Fermer","Close"))}})
 if(menu)AlertDialog(onDismissRequest={menu=false},title={Text(tr("Options","Options"))},text={Column(Modifier.heightIn(max=450.dp).verticalScroll(rememberScrollState())){if(session!=null)TextButton(onClick={menu=false;logout()}){Text(tr("Se déconnecter","Sign out"))}else TextButton(onClick={menu=false;signIn=true}){Text(tr("Se connecter","Sign in"))};menuLabels.filter{it!=menuLabels[7]||session?.let{s->mayPay(s,System.currentTimeMillis(),SystemClock.elapsedRealtime())}==true}.forEach{item->TextButton(onClick={detail=item;menu=false},modifier=Modifier.fillMaxWidth()){Text(item)}}}},confirmButton={TextButton(onClick={menu=false}){Text(tr("Fermer","Close"))}})
 if(tour>=0)AlertDialog(onDismissRequest={tour=-1},title={Text("${tour+1}/5 — ${labels[tour]}")},text={Text(unavailable)},confirmButton={TextButton(onClick={if(tour==4){prefs.edit().putBoolean("discovered",true).apply();tour=-1}else tour++}){Text(if(tour==4)tr("Terminer","Done")else tr("Suivant","Next"))}},dismissButton={TextButton(onClick={tour=-1}){Text(tr("Fermer","Close"))}})
 }
}
