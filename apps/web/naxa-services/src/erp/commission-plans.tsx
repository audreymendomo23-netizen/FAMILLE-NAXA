import React,{useEffect,useRef,useState} from "react";
import type {WebAuthAccount} from "../auth/session";
import {privateRequest} from "./private-request";
import {rosterApiOrigin} from "./staff-roster";
type Props={account:WebAuthAccount;siteId:string;sale:string;allocations:{line:string;appointment:string}[];enabled:boolean;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
type Plan={id:string;state:"waiting"|"processed"|"review_required";sale_number:string;line_count:number};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function validPlan(x:unknown):x is Plan{const v=x as Plan;return !!v&&typeof v.id==="string"&&uuid.test(v.id)&&["waiting","processed","review_required"].includes(v.state)&&typeof v.sale_number==="string"&&Number.isInteger(v.line_count)&&v.line_count>=1&&v.line_count<=30;}
export function CommissionPlans(p:Props){return p.siteId?<Scoped key={JSON.stringify([p.account.organization_id,p.account.member_id,p.siteId,p.authEndpoint,p.anonKey])} {...p}/>:null;}
function Scoped({account,siteId,sale,allocations,enabled,authEndpoint,anonKey,getToken}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const [rows,setRows]=useState<Plan[]>([]),[busy,setBusy]=useState(false),[message,setMessage]=useState(""),[error,setError]=useState(false),[single,setSingle]=useState(true);
 const ctl=useRef<AbortController|null>(null),alive=useRef(false),retry=useRef<{key:string;id:string}|null>(null);
 const chosen=single?allocations.slice(0,1):allocations;
 const valid=uuid.test(sale)&&chosen.length>0&&chosen.every(a=>uuid.test(a.line)&&uuid.test(a.appointment))&&new Set(chosen.map(a=>a.line.toLowerCase())).size===chosen.length&&new Set(chosen.map(a=>a.appointment.toLowerCase())).size===chosen.length;
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden"){ctl.current?.abort();ctl.current=null;setRows([]);setBusy(false);setMessage("");setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;ctl.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function run(action:"register"|"list"|"process",id?:string){
  if(ctl.current||document.visibilityState==="hidden")return;
  const c=new AbortController();ctl.current=c;setBusy(true);setError(false);setMessage("");
  const current=()=>alive.current&&ctl.current===c&&!c.signal.aborted&&document.visibilityState!=="hidden";
  const rpc=(name:string,body:object={})=>privateRequest<unknown>(c.signal,current,getToken,(jwt,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,...body}),signal,cache:"no-store",credentials:"omit",redirect:"error"}));
  try{
   if(action==="register"){
    if(!enabled||!valid)throw Error("PLAN_INVALID");
    const alloc=chosen.map(a=>({line_id:a.line.toLowerCase(),appointment_id:a.appointment.toLowerCase()})).sort((a,b)=>a.line_id.localeCompare(b.line_id));
    const key=JSON.stringify([sale,alloc]);if(retry.current?.key!==key)retry.current={key,id:crypto.randomUUID()};
    const r=await rpc("ns_register_commission_plan",{p_sale:sale,p_id:retry.current.id,p_allocations:alloc}) as {id?:string;state?:string};
    if(r.id!==retry.current.id||!["waiting","processed","review_required"].includes(r.state??""))throw Error("PLAN_RECEIPT");
    if(current())setMessage(tr("Association enregistrée.","Allocation registered.","Kawrital winndii."));
   }else if(action==="process"){
    const r=await rpc("ns_process_commission_plan",{p_id:id}) as {id?:string;state?:string};
    if(r.id!==id||!["waiting","processed","review_required"].includes(r.state??""))throw Error("PLAN_RECEIPT");
    if(current())setMessage(r.state==="waiting"?tr("En attente des conditions.","Waiting for conditions.","Fadude sarɗiiji."):r.state==="processed"?tr("Traitement terminé ; consultez la validation.","Processed; consult review.","Golle timmii."):tr("Rapprochement à revoir.","Reconciliation requires review.","Ƴeewto kawrital."));
   }
   const list=await rpc("ns_list_commission_plans");if(!Array.isArray(list)||list.length>100||!list.every(validPlan))throw Error("PLAN_LIST");if(current())setRows(list);
  }catch{if(current()){setError(true);setRows([]);}}finally{if(current()){ctl.current=null;setBusy(false);}}
 }
 return <section aria-label={tr("Rapprochements différés","Deferred reconciliations","Kawrital caggal")} aria-busy={busy}><h3>{tr("Rapprochements différés","Deferred reconciliations","Kawrital caggal")}</h3><p>{tr("Enregistrez les associations avant la fin du service ou du règlement, puis traitez la file après confirmation. Utilisez les identifiants de vente et lignes ci-dessus.","Register associations before service completion or payment, then process after confirmation. Use sale and line IDs above.","Winndu kawrital hade timmugol e njoɓdi.")}</p><label>{tr("Mode d’association","Allocation mode","Feere kawrital")}<select value={single?"single":"multiple"} disabled={busy} onChange={e=>setSingle(e.target.value==="single")}><option value="single">{tr("Première ligne uniquement","First line only","Gorol aranol")}</option><option value="multiple">{tr("Toutes les lignes","All lines","Gorle fof")}</option></select></label><button type="button" disabled={busy||!enabled||!valid} onClick={()=>void run("register")}>{tr("Enregistrer l’association","Register allocation","Winndin kawrital")}</button><button type="button" disabled={busy} onClick={()=>void run("list")}>{tr("Charger la file","Load queue","Loow doggol")}</button>{message&&<p role="status">{message}</p>}{error&&<p role="alert">{tr("Association refusée ou indisponible.","Allocation refused or unavailable.","Kawrital salaama.")}</p>}{rows.map(r=><article key={r.id}><strong>{r.sale_number}</strong><p>{r.line_count} · {r.state==="waiting"?tr("En attente","Waiting","Fadude"):r.state==="processed"?tr("Traitée","Processed","Timmiima"):tr("À revoir","Review required","Ƴeewto")}</p>{r.state==="waiting"&&<button type="button" disabled={busy||!enabled} onClick={()=>void run("process",r.id)}>{tr("Traiter si éligible","Process if eligible","Gollu so jaɓaama")}</button>}</article>)}</section>;
}
