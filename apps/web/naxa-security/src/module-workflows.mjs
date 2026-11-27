// SECURITY: only requests and read-only computation; never physical execution.
export const modules=[
  {
    "id": "NS-02",
    "bulk": "B2",
    "title": "Vidéo",
    "screen": "B2.02",
    "kind": "media",
    "fields": [
      "device",
      "purpose",
      "consent"
    ],
    "example": [
      "cam-01",
      "inspection",
      "yes"
    ],
    "note": "Demande de consultation d’un équipement autorisé ; aucun flux activé."
  },
  {
    "id": "NS-03",
    "bulk": "B2",
    "title": "Audio",
    "screen": "B2.10",
    "kind": "media",
    "fields": [
      "device",
      "purpose",
      "consent"
    ],
    "example": [
      "audio-01",
      "interphonie",
      "yes"
    ],
    "note": "Consentement explicite ; aucune activation du microphone."
  },
  {
    "id": "NS-07",
    "bulk": "B4",
    "title": "Accès",
    "screen": "B4.21",
    "kind": "access",
    "fields": [
      "reference",
      "purpose",
      "duration"
    ],
    "example": [
      "badge-01",
      "maintenance",
      "30"
    ],
    "note": "Demande de droit temporaire ; jamais une ouverture de porte."
  },
  {
    "id": "NS-08",
    "bulk": "B3",
    "title": "Intrusion",
    "screen": "B3.07",
    "kind": "alarm",
    "fields": [
      "reference",
      "kind",
      "detail"
    ],
    "example": [
      "zone-01",
      "intrusion",
      "Contrôle requis"
    ],
    "note": "Signalement humain ; aucune sirène commandée."
  },
  {
    "id": "NS-10",
    "bulk": "B3",
    "title": "IA Security",
    "screen": "B3.23",
    "kind": "ai",
    "fields": [
      "value",
      "threshold"
    ],
    "example": [
      "12",
      "10"
    ],
    "note": "Analyse de seuil ; décision humaine obligatoire."
  },
  {
    "id": "NS-12",
    "bulk": "B3",
    "title": "Environnement",
    "screen": "B3.22",
    "kind": "environment",
    "fields": [
      "kind",
      "value",
      "threshold"
    ],
    "example": [
      "temperature",
      "31",
      "30"
    ],
    "note": "Comparaison de mesure saisie ; aucun capteur connecté."
  },
  {
    "id": "NS-13",
    "bulk": "B4",
    "title": "Visiteurs",
    "screen": "B4.25",
    "kind": "visitor",
    "fields": [
      "reference",
      "purpose",
      "duration"
    ],
    "example": [
      "visite-01",
      "rendez-vous",
      "30"
    ],
    "note": "Demande de visite pseudonymisée ; pas d’autorisation automatique."
  },
  {
    "id": "NS-14",
    "bulk": "B4",
    "title": "Véhicules",
    "screen": "B4.28",
    "kind": "vehicle",
    "fields": [
      "reference",
      "purpose",
      "duration"
    ],
    "example": [
      "veh-01",
      "livraison",
      "45"
    ],
    "note": "Demande de passage ; aucun suivi permanent."
  },
  {
    "id": "NS-15",
    "bulk": "B4",
    "title": "SOS",
    "screen": "B4.30",
    "kind": "sos",
    "fields": [
      "reference",
      "detail"
    ],
    "example": [
      "zone-01",
      "Demande assistance"
    ],
    "note": "Signalement non urgent ; en cas de danger appeler directement les secours."
  },
  {
    "id": "NS-17",
    "bulk": "B3",
    "title": "Control 360",
    "screen": "B3.02",
    "kind": "overview",
    "fields": [],
    "example": [],
    "note": "Synthèse du site sélectionné et autorisé."
  },
  {
    "id": "NS-18",
    "bulk": "B2",
    "title": "EDGE",
    "screen": "B2.21",
    "kind": "edge",
    "fields": [
      "reference",
      "observed",
      "detail"
    ],
    "example": [
      "edge-01",
      "60",
      "Diagnostic"
    ],
    "note": "Diagnostic d’âge du heartbeat déclaré ; aucun équipement sondé."
  },
  {
    "id": "NS-19",
    "bulk": "B2",
    "title": "Compatibilité",
    "screen": "B2.20",
    "kind": "compatibility",
    "fields": [
      "reference",
      "firmware",
      "protocol"
    ],
    "example": [
      "modele-01",
      "1.0",
      "onvif"
    ],
    "note": "Dossier de qualification ; aucune certification automatique."
  },
  {
    "id": "NS-21",
    "bulk": "B5",
    "title": "ERP",
    "screen": "B5.08",
    "kind": "assignment",
    "fields": [
      "reference",
      "purpose",
      "duration"
    ],
    "example": [
      "poste-01",
      "affectation",
      "60"
    ],
    "note": "Demande d’affectation ; pas d’octroi de droits."
  },
  {
    "id": "NS-22",
    "bulk": "B5",
    "title": "Reporting",
    "screen": "B5.28",
    "kind": "report",
    "fields": [],
    "example": [],
    "note": "Rapport et export CSV des incidents autorisés."
  },
  {
    "id": "NS-24",
    "bulk": "B1",
    "title": "Paiements",
    "screen": "B1.20",
    "kind": "payment",
    "fields": [
      "reference",
      "amount",
      "channel"
    ],
    "example": [
      "txn-qa",
      "5000",
      "mobile_money"
    ],
    "note": "Demande de rapprochement ; aucun débit ni activation."
  },
  {
    "id": "NS-25",
    "bulk": "B6",
    "title": "Livecare",
    "screen": "B6.11",
    "kind": "support",
    "fields": [
      "category",
      "detail"
    ],
    "example": [
      "technical",
      "Diagnostic demandé"
    ],
    "note": "Ticket d’assistance ; aucun accès caméra pour le support."
  },
  {
    "id": "NS-26",
    "bulk": "B6",
    "title": "Notifications",
    "screen": "B6.02",
    "kind": "notification",
    "fields": [
      "channel",
      "preference"
    ],
    "example": [
      "push",
      "enabled"
    ],
    "note": "Demande de préférence ; aucun envoi externe."
  },
  {
    "id": "NS-27",
    "bulk": "B5",
    "title": "Assistant IA",
    "screen": "B5.34",
    "kind": "assistant",
    "fields": [
      "value",
      "threshold"
    ],
    "example": [
      "12",
      "10"
    ],
    "note": "Recommandation explicable ; pas de décision automatique."
  },
  {
    "id": "NS-28",
    "bulk": "B1",
    "title": "Langues",
    "screen": "B1.16",
    "kind": "language",
    "fields": [
      "locale"
    ],
    "example": [
      "en"
    ],
    "note": "Préférence FR/EN/Fulfulde ; traduction complète non validée."
  },
  {
    "id": "NS-29",
    "bulk": "B6",
    "title": "Administration",
    "screen": "B6.16",
    "kind": "admin",
    "fields": [
      "reference",
      "purpose"
    ],
    "example": [
      "compte-01",
      "revue"
    ],
    "note": "Demande de revue ; aucune élévation de privilèges."
  },
  {
    "id": "NS-30",
    "bulk": "B6",
    "title": "Audit",
    "screen": "B6.19",
    "kind": "audit",
    "fields": [],
    "example": [],
    "note": "Historique des demandes personnelles horodatées."
  },
  {
    "id": "NS-31",
    "bulk": "B6",
    "title": "Preuves",
    "screen": "B6.22",
    "kind": "evidence",
    "fields": [
      "reference",
      "digest"
    ],
    "example": [
      "preuve-01",
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    ],
    "note": "Empreinte SHA-256 calculable localement ; aucun upload ni certification."
  },
  {
    "id": "NS-34",
    "bulk": "B6",
    "title": "Sauvegarde",
    "screen": "B6.27",
    "kind": "backup",
    "fields": [
      "reference",
      "purpose"
    ],
    "example": [
      "backup-01",
      "test-restauration"
    ],
    "note": "Demande de restauration isolée ; aucune action en production."
  },
  {
    "id": "NS-35",
    "bulk": "B5",
    "title": "Partenaires",
    "screen": "B5.23",
    "kind": "partner",
    "fields": [
      "reference",
      "purpose"
    ],
    "example": [
      "installateur-01",
      "qualification"
    ],
    "note": "Demande de qualification ; aucun droit implicite."
  }
];
export const persistentKinds=["media","access","alarm","visitor","vehicle","sos","compatibility","assignment","payment","support","notification","language","admin","evidence","backup","partner"];
const clean=(s,max=120)=>{if(typeof s!=="string"||!s.trim()||s.trim().length>max||/[\u0000-\u001f]/.test(s))throw Error("INVALID_TEXT");return s.trim()};
const ref=s=>{s=clean(s,80);if(!/^[A-Za-z0-9._-]+$/.test(s))throw Error("INVALID_REFERENCE");return s};
const one=(s,values)=>{if(!values.includes(s))throw Error("INVALID_CHOICE");return s};
const num=(s,min,max,integer=false)=>{if(typeof s!=="string"||!/^[-+]?\d+(\.\d+)?$/.test(s))throw Error("INVALID_NUMBER");const n=Number(s);if(!Number.isFinite(n)||n<min||n>max||(integer&&!Number.isSafeInteger(n)))throw Error("INVALID_NUMBER");return n};
export function evaluate(id,input){
 const m=modules.find(x=>x.id===id);if(!m||!input||Object.keys(input).some(k=>!m.fields.includes(k))||m.fields.some(k=>!(k in input)))throw Error("INVALID_MODULE_INPUT");
 const x=input;let p={};let result="Demande à examiner";
 switch(m.kind){
 case "media":p={reference:ref(x.device),purpose:clean(x.purpose),consent:one(x.consent,["yes"]),media:id==="NS-02"?"video":"audio"};break;
 case "access":case "visitor":case "vehicle":case "assignment":p={reference:ref(x.reference),purpose:clean(x.purpose),duration_minutes:num(x.duration,1,1440,true)};break;
 case "alarm":p={reference:ref(x.reference),kind:one(x.kind,["intrusion","sabotage","fault"]),detail:clean(x.detail,500)};break;
 case "sos":p={reference:ref(x.reference),detail:clean(x.detail,500)};break;
 // Adapted from packages/assistant/src/index.ts: threshold explanation and human decision.
 case "ai":case "assistant":{const value=num(x.value,-1e9,1e9),threshold=num(x.threshold,-1e9,1e9);p={value,threshold,requiresHumanDecision:true};result=value>threshold?"Seuil dépassé — revue humaine":"Seuil non dépassé — ne prouve pas la sécurité";break;}
 case "environment":{const kind=one(x.kind,["temperature","humidity","water","co","gas"]);const value=num(x.value,-1e6,1e6),threshold=num(x.threshold,-1e6,1e6);if(kind!=="temperature"&&(value<0||threshold<0))throw Error("INVALID_MEASURE");if(kind==="humidity"&&(value>100||threshold>100))throw Error("INVALID_MEASURE");p={kind,value,threshold};result=value>threshold?"Mesure saisie au-dessus du seuil":"Mesure saisie au seuil ou en dessous";break;}
 case "edge":{const observed=num(x.observed,0,864000,true);p={reference:ref(x.reference),observed_seconds:observed,detail:clean(x.detail,500)};result=observed>120?"Heartbeat déclaré ancien — état inconnu":"Heartbeat déclaré récent — non vérifié";break;}
 case "compatibility":p={reference:ref(x.reference),firmware:clean(x.firmware,80),protocol:one(x.protocol,["onvif","rtsp","vendor_api","other"])};break;
 case "payment":p={reference:ref(x.reference),amount_fcfa:num(x.amount,1,100000000,true),channel:one(x.channel,["mobile_money","bank"])};break;
 case "support":p={category:one(x.category,["account","technical","billing","privacy","other"]),detail:clean(x.detail,500)};break;
 case "notification":p={channel:one(x.channel,["push","sms","email","whatsapp"]),preference:one(x.preference,["enabled","disabled"])};break;
 case "language":p={locale:one(x.locale,["fr","en","ff-CM"])};break;
 case "admin":case "backup":case "partner":p={reference:ref(x.reference),purpose:clean(x.purpose)};break;
 case "evidence":{const digest=clean(x.digest,64).toLowerCase();if(!/^[a-f0-9]{64}$/.test(digest))throw Error("INVALID_DIGEST");p={reference:ref(x.reference),digest};break;}
 case "overview":case "report":case "audit":result="Charger les données autorisées";break;
 default:throw Error("INVALID_MODULE");
 }
 return {module:id,kind:m.kind,payload:p,result,persist:persistentKinds.includes(m.kind)};
}
export function summarizeIncidents(rows){if(!Array.isArray(rows))throw Error("INVALID_ROWS");const priorities={P1:0,P2:0,P3:0,P4:0,unknown:0};let closed=0;for(const r of rows){if(!r||typeof r!=="object")throw Error("INVALID_ROW");priorities[Object.hasOwn(priorities,r.priority)?r.priority:"unknown"]++;if(r.state==="closed")closed++}return {total:rows.length,closed,open:rows.length-closed,priorities};}
// Authorized local export pattern from NAXA SERVICES; formula injection guard.
export function csv(rows){return rows.map(row=>row.map(v=>{let s=String(v??"");if(/^[\s\u0000-\u001f]*[=+@-]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"'}).join(",")).join("\r\n")}
function canonical(v){if(!v||typeof v!=="object")return JSON.stringify(v);return JSON.stringify(Object.keys(v).sort().map(k=>[k,v[k]]))}
export function matchesReceipt(row,body){return !!row&&row.request_id===body.request_id&&row.reporter_id===body.reporter_id&&row.organization_id===body.organization_id&&row.site_id===body.site_id&&row.kind===body.kind&&["requested","reviewed","declined"].includes(row.state)&&canonical(row.payload)===canonical(body.payload)}
export async function evidenceHash(bytes){if(!(bytes instanceof ArrayBuffer)||bytes.byteLength>20*1024*1024)throw Error("INVALID_FILE");const hash=await crypto.subtle.digest("SHA-256",bytes);return Array.from(new Uint8Array(hash),b=>b.toString(16).padStart(2,"0")).join("")}
