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
 const [shareText,setShareText]=useState<Record<string,string>>({});
 const [sourceKind,setSourceKind]=useState("appointment"),[sourceId,setSourceId]=useState(""),[sourceService,setSourceService]=useState(""),[sourceMember,setSourceMember]=useState("");
 const chosen=single?allocations.slice(0,1):allocations;
 function sharesFor(line:string){const raw=(shareText[line]??"").trim();if(!raw)return undefined;const entries=raw.split("\n").map(s=>{const [id,bps,...rest]=s.trim().split(/\s+/);if(rest.length||!uuid.test(id)||!/^\d{1,5}$/.test(bps??""))throw Error("SHARES");return {member_id:id.toLowerCase(),share_bps:Number(bps)};}).sort((a,b)=>a.member_id.localeCompare(b.member_id));if(entries.length<2||entries.length>20||new Set(entries.map(e=>e.member_id)).size!==entries.length||entries.some(e=>e.share_bps<1||e.share_bps>10000)||entries.reduce((a,b)=>a+b.share_bps,0)!==10000)throw Error("SHARES");return entries;}
 const valid=uuid.test(sale)&&chosen.length>0&&chosen.every(a=>uuid.test(a.line)&&uuid.test(a.appointment))&&new Set(chosen.map(a=>a.line.toLowerCase())).size===chosen.length&&new Set(chosen.map(a=>a.appointment.toLowerCase())).size===chosen.length;
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden"){ctl.current?.abort();ctl.current=null;setRows([]);setBusy(false);setMessage("");setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;ctl.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function run(action:"register"|"list"|"process",id?:string){
  if(ctl.current||document.visibilityState==="hidden")return;
  const c=new AbortController();ctl.current=c;setBusy(true);setError(false);setMessage("");
  const current=()=>alive.current&&ctl.current===c&&!c.signal.aborted&&document.visibilityState!=="hidden";
  const rpc=(name:string,body:object={})=>privateRequest<unknown>(c.signal,current,getToken,(jwt,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,...body}),signal,cache:"no-store",credentials:"omit",redirect:"error"}));
  try{
   if(action==="register"){
    if(!enabled)throw Error("PLAN_INVALID");
    if(sourceKind!=="appointment"){
     if(!uuid.test(sourceId)||!uuid.test(sourceService)||!uuid.test(sourceMember)||(sourceKind==="work"&&!uuid.test(sale)))throw Error("PLAN_INVALID");
     const shares=sharesFor("source")??null,body={p_kind:sourceKind,p_source:sourceId,p_sale:sourceKind==="work"?sale:null,p_service:sourceService,p_member:sourceMember,p_shares:shares};
     const key=JSON.stringify(body);if(retry.current?.key!==key)retry.current={key,id:crypto.randomUUID()};
     const r=await rpc("ns_register_source_commission_plan",{...body,p_id:retry.current.id}) as {id?:string;state?:string};
     if(r.id!==retry.current.id||!["waiting","processed","review_required"].includes(r.state??""))throw Error("PLAN_RECEIPT");
     if(current())setMessage(tr("Association enregistrée.","Allocation registered.","Kawrital winndii."));
    }else{
    if(!valid)throw Error("PLAN_INVALID");
    const alloc=chosen.map(a=>{const shares=sharesFor(a.line);return {line_id:a.line.toLowerCase(),appointment_id:a.appointment.toLowerCase(),...(shares?{shares}:{})};}).sort((a,b)=>a.line_id.localeCompare(b.line_id));
    const key=JSON.stringify([sale,alloc]);if(retry.current?.key!==key)retry.current={key,id:crypto.randomUUID()};
    const r=await rpc("ns_register_commission_plan",{p_sale:sale,p_id:retry.current.id,p_allocations:alloc}) as {id?:string;state?:string};
    if(r.id!==retry.current.id||!["waiting","processed","review_required"].includes(r.state??""))throw Error("PLAN_RECEIPT");
    if(current())setMessage(tr("Association enregistrée.","Allocation registered.","Kawrital winndii."));
    }
   }else if(action==="process"){
    const r=await rpc("ns_process_commission_plan",{p_id:id}) as {id?:string;state?:string};
    if(r.id!==id||!["waiting","processed","review_required"].includes(r.state??""))throw Error("PLAN_RECEIPT");
    if(current())setMessage(r.state==="waiting"?tr("En attente des conditions.","Waiting for conditions.","Fadude sarɗiiji."):r.state==="processed"?tr("Traitement terminé ; consultez la validation.","Processed; consult review.","Golle timmii."):tr("Rapprochement à revoir.","Reconciliation requires review.","Ƴeewto kawrital."));
   }
   const list=await rpc("ns_list_commission_plans");if(!Array.isArray(list)||list.length>100||!list.every(validPlan))throw Error("PLAN_LIST");if(current())setRows(list);
  }catch{if(current()){setError(true);setRows([]);}}finally{if(current()){ctl.current=null;setBusy(false);}}
 }
 return <section aria-label={tr("Rapprochements différés","Deferred reconciliations","Kawrital caggal")} aria-busy={busy}><h3>{tr("Rapprochements différés","Deferred reconciliations","Kawrital caggal")}</h3><p>{tr("Enregistrez les associations avant la fin du service ou du règlement. Le traitement manuel reste disponible ; l’automatisation nécessite un worker serveur actif. Utilisez les identifiants ci-dessus.","Register associations before completion or payment. Manual processing remains available; automatic processing requires an active server worker. Use the IDs above.","Winndu kawrital hade timmugol e njoɓdi.")}</p><label>{tr("Source de prestation","Service source","Iwdi golle")}<select value={sourceKind} disabled={busy} onChange={e=>setSourceKind(e.target.value)}><option value="appointment">{tr("Rendez-vous","Appointment","Kawrital")}</option><option value="work">{tr("Ordre de travail lié à la vente","Work order linked to sale","Golle")}</option><option value="pressing">{tr("Ticket pressing","Pressing ticket","Tiket laɓɓingol")}</option></select></label>{sourceKind!=="appointment"?<>{[[tr("ID du ticket ou travail","Ticket or work ID","ID golle"),sourceId,setSourceId],[tr("ID de prestation","Service ID","ID golle"),sourceService,setSourceService],[tr("ID exécutant","Executor ID","ID gollotooɗo"),sourceMember,setSourceMember]].map(([label,value,setter],i)=><label key={i}>{label as string}<input value={value as string} disabled={busy} onChange={e=>(setter as (s:string)=>void)(e.target.value)}/></label>)}<label>{tr("Parts facultatives (ID et points de base)","Optional shares (ID and basis points)","Geɗal gollotooɓe")}<textarea value={shareText.source??""} disabled={busy} onChange={e=>setShareText(old=>({...old,source:e.target.value}))}/></label></>:<><label>{tr("Mode d’association","Allocation mode","Feere kawrital")}<select value={single?"single":"multiple"} disabled={busy} onChange={e=>setSingle(e.target.value==="single")}><option value="single">{tr("Première ligne uniquement","First line only","Gorol aranol")}</option><option value="multiple">{tr("Toutes les lignes","All lines","Gorle fof")}</option></select></label>{chosen.filter(a=>uuid.test(a.line)).map(a=><label key={a.line}>{tr("Partage facultatif de la ligne : ID collaborateur et part en points de base (total 10 000), une ligne par personne","Optional line shares: member ID and basis points (total 10,000), one row per person","Seerndu komiisiyoŋ: ID e geɗal, 10 000")} — {a.line}<textarea rows={3} value={shareText[a.line]??""} disabled={busy} onChange={e=>setShareText(old=>({...old,[a.line]:e.target.value}))}/></label>)}</>}<button type="button" disabled={busy||!enabled||(sourceKind==="appointment"?!valid:!uuid.test(sourceId)||!uuid.test(sourceService)||!uuid.test(sourceMember)||(sourceKind==="work"&&!uuid.test(sale)))} onClick={()=>void run("register")}>{tr("Enregistrer l’association","Register allocation","Winndin kawrital")}</button><button type="button" disabled={busy} onClick={()=>void run("list")}>{tr("Charger la file","Load queue","Loow doggol")}</button>{message&&<p role="status">{message}</p>}{error&&<p role="alert">{tr("Association refusée ou indisponible.","Allocation refused or unavailable.","Kawrital salaama.")}</p>}{rows.map(r=><article key={r.id}><strong>{r.sale_number}</strong><p>{r.line_count} · {r.state==="waiting"?tr("En attente","Waiting","Fadude"):r.state==="processed"?tr("Traitée","Processed","Timmiima"):tr("À revoir","Review required","Ƴeewto")}</p>{r.state==="waiting"&&<button type="button" disabled={busy||!enabled} onClick={()=>void run("process",r.id)}>{tr("Traiter si éligible","Process if eligible","Gollu so jaɓaama")}</button>}</article>)}</section>;
}
