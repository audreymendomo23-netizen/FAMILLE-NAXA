import React,{useContext,useEffect,useRef,useState}from "react";
import {SecurityScope}from "./SessionWorkspace";
import {request}from "./security-api";
import {eventBody,eventScope,preferenceEvent,validPreferenceReceipt,type PreferenceEvent}from "./preference-outbox.mjs";
import {enqueuePreference,pendingPreferences,removePreference}from "./preference-store";
const enabled=(import.meta.env as ImportMetaEnv&{VITE_SECURITY_MODULE_REQUESTS_ENABLED?:string}).VITE_SECURITY_MODULE_REQUESTS_ENABLED==="true";
export function PreferenceOutbox(){
 const {session,site}=useContext(SecurityScope);const [key,setKey]=useState("locale"),[value,setValue]=useState("fr"),[rows,setRows]=useState<PreferenceEvent[]>([]),[message,setMessage]=useState(""),[busy,setBusy]=useState(false);
 const gen=useRef(0),lock=useRef(false);
 useEffect(()=>{gen.current++;lock.current=false;setRows([]);setMessage("");setBusy(false);return()=>{gen.current++}},[session,site]);
 if(!enabled||!session||!site)return null;
 const scope={organization:site.organization_id,site:site.id,user:session.userId};
 async function run(op:"queue"|"list"|"flush"){if(!session||!site||lock.current)return;lock.current=true;setBusy(true);const g=gen.current;try{
 if(op==="queue"){await enqueuePreference(preferenceEvent(scope,key,value,crypto.randomUUID()));if(g===gen.current)setMessage("Préférence enregistrée localement — pas encore synchronisée.")}
 if(op==="flush"){let count=0;for(const e of await pendingPreferences(scope)){if(g!==gen.current||Date.now()>=session.expiresAt||!eventScope(e,scope))break;const body=eventBody(e);let data;try{data=await request(session,"sec_module_requests",{method:"POST",body})}catch{data=await request(session,"sec_module_requests",{site:scope.site,organization:scope.organization,requestId:e.id})}if(!Array.isArray(data)||!data.some(r=>validPreferenceReceipt(e,r)))throw Error("UNCONFIRMED");if(g!==gen.current)break;await removePreference(e);count++}if(g===gen.current)setMessage(count+" préférence(s) synchronisée(s) avec reçu confirmé.")}
 const all=await pendingPreferences(scope);if(g===gen.current)setRows(all);
 }catch{if(g===gen.current){setMessage("Non confirmé ou préférence déjà en attente. Aucun élément non confirmé n’est supprimé.");try{const all=await pendingPreferences(scope);if(g===gen.current)setRows(all)}catch{}}}finally{if(g===gen.current){lock.current=false;setBusy(false)}}}}
 return <section aria-label="File locale sécurisée"><h2>Synchronisation des préférences</h2><p>File locale limitée aux préférences non sensibles. Aucun identifiant de connexion, position, image, paiement ou ordre matériel stocké. Réouverture avec le même compte et site nécessaire.</p><label>Type de préférence<select aria-label="Type de préférence" disabled={busy} value={key} onChange={e=>{setKey(e.target.value);setValue(e.target.value==="locale"?"fr":"enabled")}}>{["locale","push","sms","email","whatsapp"].map(k=><option key={k}>{k}</option>)}</select></label><label>Valeur<select aria-label="Valeur de préférence" disabled={busy} value={value} onChange={e=>setValue(e.target.value)}>{(key==="locale"?["fr","en","ff-CM"]:["enabled","disabled"]).map(v=><option key={v}>{v}</option>)}</select></label><button type="button" disabled={busy} onClick={()=>void run("queue")}>Mettre en attente locale</button><button type="button" disabled={busy} onClick={()=>void run("list")}>Charger la file locale</button><button type="button" disabled={busy} onClick={()=>void run("flush")}>Synchroniser les préférences</button>{rows.map(e=><p key={e.key}>{e.kind} : {Object.values(e.payload).join(" · ")} — en attente</p>)}<p role="status">{message}</p></section>
}
