package cm.naxa.naxasecurity

internal data class SecurityModule(val id:String,val screen:String,val title:String,val kind:String,val fields:List<String>,val sample:List<String>,val note:String)
internal val securityModules = listOf(
 SecurityModule("NS-02","B2.02","Vidéo","media",listOf("device","purpose","consent"),listOf("cam-01","inspection","yes"),"Demande de consultation d’un équipement autorisé ; aucun flux activé."),
 SecurityModule("NS-03","B2.10","Audio","media",listOf("device","purpose","consent"),listOf("audio-01","interphonie","yes"),"Consentement explicite ; aucune activation du microphone."),
 SecurityModule("NS-07","B4.21","Accès","access",listOf("reference","purpose","duration"),listOf("badge-01","maintenance","30"),"Demande de droit temporaire ; jamais une ouverture de porte."),
 SecurityModule("NS-08","B3.07","Intrusion","alarm",listOf("reference","kind","detail"),listOf("zone-01","intrusion","Contrôle requis"),"Signalement humain ; aucune sirène commandée."),
 SecurityModule("NS-10","B3.23","IA Security","ai",listOf("value","threshold"),listOf("12","10"),"Analyse de seuil ; décision humaine obligatoire."),
 SecurityModule("NS-12","B3.22","Environnement","environment",listOf("kind","value","threshold"),listOf("temperature","31","30"),"Comparaison de mesure saisie ; aucun capteur connecté."),
 SecurityModule("NS-13","B4.25","Visiteurs","visitor",listOf("reference","purpose","duration"),listOf("visite-01","rendez-vous","30"),"Demande de visite pseudonymisée ; pas d’autorisation automatique."),
 SecurityModule("NS-14","B4.28","Véhicules","vehicle",listOf("reference","purpose","duration"),listOf("veh-01","livraison","45"),"Demande de passage ; aucun suivi permanent."),
 SecurityModule("NS-15","B4.30","SOS","sos",listOf("reference","detail"),listOf("zone-01","Demande assistance"),"Signalement non urgent ; en cas de danger appeler directement les secours."),
 SecurityModule("NS-17","B3.02","Control 360","overview",listOf(),listOf(),"Synthèse du site sélectionné et autorisé."),
 SecurityModule("NS-18","B2.21","EDGE","edge",listOf("reference","observed","detail"),listOf("edge-01","60","Diagnostic"),"Diagnostic d’âge du heartbeat déclaré ; aucun équipement sondé."),
 SecurityModule("NS-19","B2.20","Compatibilité","compatibility",listOf("reference","firmware","protocol"),listOf("modele-01","1.0","onvif"),"Dossier de qualification ; aucune certification automatique."),
 SecurityModule("NS-21","B5.08","ERP","assignment",listOf("reference","purpose","duration"),listOf("poste-01","affectation","60"),"Demande d’affectation ; pas d’octroi de droits."),
 SecurityModule("NS-22","B5.28","Reporting","report",listOf(),listOf(),"Rapport et export CSV des incidents autorisés."),
 SecurityModule("NS-24","B1.20","Paiements","payment",listOf("reference","amount","channel"),listOf("txn-qa","5000","mobile_money"),"Demande de rapprochement ; aucun débit ni activation."),
 SecurityModule("NS-25","B6.11","Livecare","support",listOf("category","detail"),listOf("technical","Diagnostic demandé"),"Ticket d’assistance ; aucun accès caméra pour le support."),
 SecurityModule("NS-26","B6.02","Notifications","notification",listOf("channel","preference"),listOf("push","enabled"),"Demande de préférence ; aucun envoi externe."),
 SecurityModule("NS-27","B5.34","Assistant IA","assistant",listOf("value","threshold"),listOf("12","10"),"Recommandation explicable ; pas de décision automatique."),
 SecurityModule("NS-28","B1.16","Langues","language",listOf("locale"),listOf("en"),"Préférence FR/EN/Fulfulde ; traduction complète non validée."),
 SecurityModule("NS-29","B6.16","Administration","admin",listOf("reference","purpose"),listOf("compte-01","revue"),"Demande de revue ; aucune élévation de privilèges."),
 SecurityModule("NS-30","B6.19","Audit","audit",listOf(),listOf(),"Historique des demandes personnelles horodatées."),
 SecurityModule("NS-31","B6.22","Preuves","evidence",listOf("reference","digest"),listOf("preuve-01","aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),"Empreinte SHA-256 calculable localement ; aucun upload ni certification."),
 SecurityModule("NS-34","B6.27","Sauvegarde","backup",listOf("reference","purpose"),listOf("backup-01","test-restauration"),"Demande de restauration isolée ; aucune action en production."),
 SecurityModule("NS-35","B5.23","Partenaires","partner",listOf("reference","purpose"),listOf("installateur-01","qualification"),"Demande de qualification ; aucun droit implicite.")
)
internal object SecurityModuleRules {
 fun evaluate(m:SecurityModule,input:Map<String,String>):String {
  require(input.keys==m.fields.toSet())
  fun clean(k:String,max:Int=120):String {val v=input.getValue(k).trim();require(v.isNotEmpty()&&v.length<=max&&v.none{it.code<32});return v}
  fun ref(k:String){require(Regex("^[A-Za-z0-9._-]{1,80}$").matches(clean(k,80)))}
  fun choice(k:String,vararg allowed:String){require(input.getValue(k) in allowed)}
  fun number(k:String,min:Double,max:Double,integer:Boolean=false):Double{val v=input.getValue(k);require(Regex("^[+-]?[0-9]+([.][0-9]+)?$").matches(v));val n=v.toDouble();require(n.isFinite()&&n in min..max&&(!integer||n%1.0==0.0));return n}
  when(m.kind){
   "media"->{ref("device");clean("purpose");choice("consent","yes")}
   "access","visitor","vehicle","assignment"->{ref("reference");clean("purpose");number("duration",1.0,1440.0,true)}
   "alarm"->{ref("reference");choice("kind","intrusion","sabotage","fault");clean("detail",500)}
   "sos"->{ref("reference");clean("detail",500)}
   "ai","assistant"->{val v=number("value",-1e9,1e9);val t=number("threshold",-1e9,1e9);return if(v>t)"Seuil dépassé — revue humaine" else "Seuil non dépassé — ne prouve pas la sécurité"}
   "environment"->{choice("kind","temperature","humidity","water","co","gas");val k=input.getValue("kind");val min=if(k=="temperature")-1e6 else 0.0;val max=if(k=="humidity")100.0 else 1e6;val v=number("value",min,max);val t=number("threshold",min,max);return if(v>t)"Mesure saisie au-dessus du seuil" else "Mesure saisie au seuil ou en dessous"}
   "edge"->{ref("reference");val age=number("observed",0.0,864000.0,true);clean("detail",500);return if(age>120)"Heartbeat déclaré ancien — état inconnu" else "Heartbeat déclaré récent — non vérifié"}
   "compatibility"->{ref("reference");clean("firmware",80);choice("protocol","onvif","rtsp","vendor_api","other")}
   "payment"->{ref("reference");number("amount",1.0,100000000.0,true);choice("channel","mobile_money","bank")}
   "support"->{choice("category","account","technical","billing","privacy","other");clean("detail",500)}
   "notification"->{choice("channel","push","sms","email","whatsapp");choice("preference","enabled","disabled")}
   "language"->choice("locale","fr","en","ff-CM")
   "admin","backup","partner"->{ref("reference");clean("purpose")}
   "evidence"->{ref("reference");require(Regex("^[a-fA-F0-9]{64}$").matches(clean("digest",64)))}
   "overview","report","audit"->return "Lecture serveur Android non raccordée"
   else->error("INVALID_MODULE")
  }
  return "Brouillon valide localement — aucune transmission ni action."
 }
}
