import React,{useContext,useEffect,useRef,useState} from "react";
import {SecurityScope} from "./SessionWorkspace";
import {request,reviewRpc,type Resource} from "./security-api";
const enabled=(import.meta.env as ImportMetaEnv & {VITE_SECURITY_MODULE_REQUESTS_ENABLED?:string}).VITE_SECURITY_MODULE_REQUESTS_ENABLED==="true";
type Entry={resource:Resource;title:string;kind?:string;order?:string};
const panels:Record<string,Entry>={
 "B1.16":{resource:"sec_preferences",title:"Préférences personnelles"},
 "B1.20":{resource:"sec_payment_receipts",title:"Reçus fournisseur confirmés",order:"provider_confirmed_at.desc"},
 "B2.21":{resource:"sec_device_observations",title:"Télémétrie reçue",order:"observed_at.desc"},
 "B2.25":{resource:"sec_device_observations",title:"Santé des équipements",order:"observed_at.desc"},
 "B2.20":{resource:"sec_service_register",title:"Registre des dossiers de compatibilité",kind:"compatibility",order:"recorded_at.desc"},
 "B3.07":{resource:"sec_incidents",title:"Incidents déclarés"},
 "B3.03":{resource:"sec_observation_alerts",title:"Avertissements de télémétrie",order:"observed_at.desc"},
 "B3.22":{resource:"sec_device_observations",title:"Mesures environnementales reçues",order:"observed_at.desc"},
 "B4.24":{resource:"sec_service_register",title:"Registre des visites examinées",kind:"visitor",order:"recorded_at.desc"},
 "B4.27":{resource:"sec_service_register",title:"Registre des passages examinés",kind:"vehicle",order:"recorded_at.desc"},
 "B5.08":{resource:"sec_service_register",title:"Registre des affectations examinées",kind:"assignment",order:"recorded_at.desc"},
 "B5.23":{resource:"sec_service_register",title:"Registre des dossiers partenaires examinés",kind:"partner",order:"recorded_at.desc"},
 "B6.01":{resource:"sec_inbox",title:"Boîte de réception personnelle",order:"created_at.desc"},
 "B6.02":{resource:"sec_preferences",title:"Préférences enregistrées"},
 "B6.12":{resource:"sec_support_messages",title:"Conversations personnelles",order:"created_at.desc"}
};
const safeText=(v:unknown)=>String(v??"");
export function ServiceWorkspace({screen}:{screen:string}){
 const panel=panels[screen];const {session,site}=useContext(SecurityScope);
 const [rows,setRows]=useState<Record<string,unknown>[]>([]),[message,setMessage]=useState(""),[busy,setBusy]=useState(false),[reply,setReply]=useState(""),[ticket,setTicket]=useState("");
 const serial=useRef(0),lock=useRef(false),pending=useRef<{id:string;ticket:string;body:string}|null>(null);
 useEffect(()=>{serial.current++;lock.current=false;pending.current=null;setRows([]);setMessage("");setBusy(false);setReply("");setTicket("");return()=>{serial.current++}},[screen,session,site]);
 if(!panel||!enabled||!session||!site)return null;
 const current=(r:Record<string,unknown>)=>r.organization_id===site.organization_id&&r.site_id===site.id;
 async function load(){if(!session||!site||lock.current)return;lock.current=true;setBusy(true);const g=serial.current;try{const data=await request(session,panel.resource,{site:site.id,organization:site.organization_id,order:panel.order});if(!Array.isArray(data))throw Error();if(g===serial.current){setRows(data.filter(r=>current(r)&&(!panel.kind||r.kind===panel.kind)&&(!["sec_preferences","sec_inbox"].includes(panel.resource)||r.user_id===session.userId)));setMessage("Données chargées — 100 lignes maximum.")}}catch{if(g===serial.current){setRows([]);setMessage("Lecture non disponible ou non autorisée.")}}finally{if(g===serial.current){lock.current=false;setBusy(false)}}}
 async function mark(row:Record<string,unknown>){if(!session||!site||lock.current||!current(row)||row.user_id!==session.userId)return;lock.current=true;setBusy(true);const g=serial.current;try{const v=await reviewRpc(session,"sec_read_inbox",{p_id:row.id,p_org:site.organization_id,p_site:site.id});if(!v||!current(v)||v.id!==row.id||v.user_id!==session.userId||!v.read_at)throw Error();if(g===serial.current)setRows(a=>a.map(x=>x.id===v.id?v:x))}catch{if(g===serial.current)setMessage("Lecture non confirmée.")}finally{if(g===serial.current){lock.current=false;setBusy(false)}}}
 async function send(){if(!session||!site||lock.current||!reply.trim()||!rows.some(r=>r.request_id===ticket))return;lock.current=true;setBusy(true);const g=serial.current,body=reply.trim(),id=pending.current?.ticket===ticket&&pending.current?.body===body?pending.current.id:crypto.randomUUID();pending.current={id,ticket,body};try{const p={id,organization_id:site.organization_id,site_id:site.id,request_id:ticket,author_id:session.userId,body};let v;try{v=await request(session,"sec_support_messages",{method:"POST",body:p})}catch{v=await request(session,"sec_support_messages",{site:site.id,organization:site.organization_id,record:id})}if(!Array.isArray(v)||!v.some(x=>current(x)&&x.id===id&&x.author_id===session.userId&&x.request_id===ticket&&x.body===body))throw Error();if(g===serial.current){setRows(a=>[...v.filter(x=>current(x)&&x.id===id),...a.filter(x=>x.id!==id)]);setReply("");pending.current=null;setMessage("Message enregistré ; réponse du support non confirmée.")}}catch{if(g===serial.current)setMessage("Message non confirmé ; réessayer sans modifier la saisie.")}finally{if(g===serial.current){lock.current=false;setBusy(false)}}}
 function description(r:Record<string,unknown>){switch(panel.resource){
 case "sec_preferences":return safeText(r.key)+" : "+safeText(r.value);
 case "sec_payment_receipts":return safeText(r.channel)+" · "+safeText(r.reference)+" · "+safeText(r.amount_fcfa)+" FCFA · reçu fournisseur";
 case "sec_service_register":return safeText(r.reference)+" · dossier examiné (ni autorisation ni certification)";
 case "sec_inbox":return (r.event_type==="request_received"?"Demande reçue":"Revue enregistrée")+" · "+(r.read_at?"Lu":"Non lu");
 case "sec_support_messages":return safeText(r.body);
 case "sec_incidents":return safeText(r.subject)+" · "+safeText(r.priority)+" · "+safeText(r.state);
 case "sec_observation_alerts":return safeText(r.kind)+" · "+safeText(r.device_id)+" · "+safeText(r.observed_at)+" — avertissement, pas alarme certifiée";
 case "sec_device_observations":{const ms=Date.parse(safeText(r.observed_at)),fresh=Number.isFinite(ms)&&ms<=Date.now()&&Date.now()-ms<=120000;return safeText(r.device_id)+" · "+(fresh?safeText(r.status):"État inconnu (donnée ancienne)")+(r.metric?" · "+safeText(r.metric)+": "+safeText(r.value):"");}
 default:return "";
 }}
 return <section aria-label={panel.title}><h2>Service — {panel.title}</h2><button type="button" disabled={busy} onClick={load}>Actualiser le service</button><p role="status">{message}</p>{rows.map((r,i)=><article key={safeText(r.id??r.key??i)}><p>{description(r)}</p>{r.created_at!=null&&<small>{safeText(r.created_at)}</small>}{panel.resource==="sec_inbox"&&!r.read_at&&<button type="button" disabled={busy} onClick={()=>void mark(r)}>Marquer comme lu</button>}</article>)}{panel.resource==="sec_support_messages"&&rows.length>0&&<><label>Ticket<select disabled={busy} value={ticket} onChange={e=>setTicket(e.target.value)}><option value="">Choisir</option>{[...new Set(rows.map(r=>safeText(r.request_id)))].map(x=><option key={x}>{x}</option>)}</select></label><label>Message complémentaire<input maxLength={500} disabled={busy} value={reply} onChange={e=>setReply(e.target.value)}/></label><button type="button" disabled={busy||!ticket||!reply.trim()} onClick={()=>void send()}>Ajouter au ticket</button></>}</section>
}
