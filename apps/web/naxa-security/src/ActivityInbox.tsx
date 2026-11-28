import React,{useContext,useEffect,useRef,useState}from "react";import{SecurityScope}from "./SessionWorkspace";import{request,reviewRpc}from "./security-api";
const enabled=(import.meta.env as ImportMetaEnv&{VITE_SECURITY_TRUST_ENABLED?:string}).VITE_SECURITY_TRUST_ENABLED==="true";
export function ActivityInbox({screen}:{screen:string}){
 const {session,site}=useContext(SecurityScope);const [rows,setRows]=useState<Record<string,unknown>[]>([]),[busy,setBusy]=useState(false),[status,setStatus]=useState("");const gen=useRef(0),lock=useRef(false);
 useEffect(()=>{gen.current++;lock.current=false;setRows([]);setBusy(false);setStatus("");return()=>{gen.current++}},[session,site,screen]);
 if(!enabled||!session||!site||screen!=="B6.01")return null;
 const scoped=(r:Record<string,unknown>)=>r.organization_id===site.organization_id&&r.site_id===site.id&&r.user_id===session.userId;
 async function run(id?:string){if(!session||!site||lock.current)return;lock.current=true;setBusy(true);const g=gen.current;try{
 if(id){const v=await reviewRpc(session,"sec_read_activity",{p_org:site.organization_id,p_site:site.id,p_id:id});if(!v||v.id!==id||!scoped(v)||!v.read_at)throw Error();if(g===gen.current){setRows(a=>a.map(x=>x.id===id?v:x));setStatus("Lecture enregistrée.")}}
 else{const v=await request(session,"sec_activity_notifications",{organization:site.organization_id,site:site.id,order:"created_at.desc"});if(!Array.isArray(v))throw Error();if(g===gen.current){setRows(v.filter(scoped));setStatus("Activité personnelle chargée.")}}
 }catch{if(g===gen.current)setStatus("Opération refusée ou non confirmée.")}finally{if(g===gen.current){lock.current=false;setBusy(false)}}}
 return <section aria-label="Notifications métier"><h2>Notifications métier personnelles</h2><p>Réception dans l'application uniquement ; aucun envoi externe ni intervention d'urgence confirmé. La signalisation incendie locale reste indépendante.</p><button type="button" disabled={busy} onClick={()=>void run()}>Actualiser les notifications métier</button>{rows.map(x=><article key={String(x.id)}><p>{String(x.source)} · {String(x.event_type)} · {x.read_at?"Lu":"Non lu"}</p>{!x.read_at&&<button type="button" disabled={busy} onClick={()=>void run(String(x.id))}>Confirmer la lecture</button>}</article>)}<p role="status">{status}</p></section>
}
