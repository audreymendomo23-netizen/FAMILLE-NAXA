import React,{useEffect,useRef,useState} from "react";
import type {WebAuthAccount} from "../auth/session";
import {privateRequest} from "./private-request";
import {rosterApiOrigin} from "./staff-roster";
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
type Row={id:string;status:string;commission_xaf:number;base_amount_xaf:number;member_name:string;sale_number:string;created_at:string};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function validateQueue(value:unknown):Row[]{
 if(!Array.isArray(value)||value.length>100||value.some(r=>!r||typeof r.id!=="string"||!uuid.test(r.id)||!["pending_approval","approved","paid","reversed"].includes(r.status)||!Number.isSafeInteger(r.commission_xaf)||r.commission_xaf<0||!Number.isSafeInteger(r.base_amount_xaf)||r.base_amount_xaf<0||typeof r.member_name!=="string"||typeof r.sale_number!=="string"||typeof r.created_at!=="string"||!Number.isFinite(Date.parse(r.created_at)))||new Set(value.map(r=>r.id.toLowerCase())).size!==value.length)throw Error("COMMISSION_QUEUE_INVALID");return value;
}
export function CommissionReview(p:Props){return p.account.role_code==="promoter"&&p.siteId?<Scoped key={JSON.stringify([p.account.organization_id,p.account.member_id,p.siteId,p.authEndpoint,p.anonKey])} {...p}/>:null;}
function Scoped({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const [rows,setRows]=useState<Row[]|null>(null),[reason,setReason]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const ctl=useRef<AbortController|null>(null),alive=useRef(false),retry=useRef<{key:string;id:string}|null>(null);
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden"){ctl.current?.abort();ctl.current=null;setRows(null);setReason("");setBusy(false);setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;ctl.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function run(row?:Row,decision?:string){
  if(busy||ctl.current||document.visibilityState==="hidden")return;
  const c=new AbortController();ctl.current=c;setBusy(true);setError(false);
  const current=()=>alive.current&&ctl.current===c&&!c.signal.aborted&&document.visibilityState!=="hidden";
  const rpc=(name:string,body:object)=>privateRequest<unknown>(c.signal,current,getToken,(jwt,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:JSON.stringify(body),signal,cache:"no-store",credentials:"omit",redirect:"error"}));
  try{
   if(row&&decision){const detail=reason.trim();if(detail.length<4||detail.length>500)throw Error("REASON");const key=JSON.stringify([row.id,decision,detail]);if(retry.current?.key!==key)retry.current={key,id:crypto.randomUUID()};
    const v=await rpc("ns_review_settled_commission",{p_org:account.organization_id,p_site:siteId,p_entry:row.id,p_event:retry.current.id,p_decision:decision,p_reason:detail}) as {entry_id?:string;status?:string};
    if(v.entry_id!==row.id||v.status!==(decision==="approve"?"approved":"reversed"))throw Error("RECEIPT");
    if(current()){retry.current=null;setReason("");}
   }
   const v=validateQueue(await rpc("ns_settled_commission_queue",{p_org:account.organization_id,p_site:siteId}));if(current())setRows(v);
  }catch{if(current()){setError(true);setRows(null);}}finally{if(current()){ctl.current=null;setBusy(false);}}
 }
 const title=tr("Validation des commissions","Commission review","Ƴeewtagol komiisiyoŋaji");
 return <section aria-label={title} aria-busy={busy}><h3>{title}</h3><p>{tr("Décisions comptables uniquement, aucun paiement automatique.","Accounting decisions only, no automatic payment."," Kuugal konte tan, alaa njoɓdi otomatik.")}</p><button className="btn secondary" disabled={busy} onClick={()=>void run()}>{tr("Charger les commissions","Load commissions","Loow komiisiyoŋaji")}</button>{error&&<p role="alert">{tr("Action refusée ou résultat indisponible. Rechargez avant de réessayer.","Action refused or result unavailable. Reload before retry.","Kuugal salaama walla humpito alaa.")}</p>}{rows&&<><label>{tr("Motif de décision","Decision reason","Dalilu kuugal")}<input value={reason} maxLength={500} disabled={busy} onChange={e=>setReason(e.target.value)}/></label>{rows.map(r=><article key={r.id}><strong>{r.member_name} · {r.sale_number}</strong><p>{r.commission_xaf} FCFA · {r.status}</p>{(r.status==="pending_approval"?[["approve",tr("Approuver","Approve","Jaɓ")],["reject",tr("Refuser","Reject","Sal")]]:["approved","paid"].includes(r.status)?[["reverse_refund",tr("Extourne après remboursement intégral","Reverse after full refund","Ruttin caggal njoɓdi")]]:[]).map(([d,label])=><button key={d} className="btn secondary" disabled={busy||reason.trim().length<4} onClick={()=>{if(window.confirm(label+" — "+r.sale_number))void run(r,d);}}>{label}</button>)}</article>)}</>}</section>;
}
