import React,{useEffect,useRef,useState} from "react";
import type {WebAuthAccount} from "../auth/session";
import {privateRequest} from "./private-request";
import {rosterApiOrigin} from "./staff-roster";
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
type Counts={open:number;overdue:number;ready:number};
type Data={site_id:string;generated_at:string;orders:Counts;pressing:Counts;appointments:Counts;receivables:{open:number;overdue:number;balance_xaf:number}};
export function validateOperations(value:unknown,site:string):Data{
 if(!value||typeof value!=="object")throw Error("OPERATIONS_INVALID");
 const r=value as Data;
 const n=(v:unknown)=>typeof v==="number"&&Number.isSafeInteger(v)&&v>=0;
 if(r.site_id!==site||typeof r.generated_at!=="string"||!Number.isFinite(Date.parse(r.generated_at)))throw Error("OPERATIONS_INVALID");
 for(const c of [r.orders,r.pressing,r.appointments])if(!c||!n(c.open)||!n(c.overdue)||!n(c.ready)||c.overdue>c.open||c.ready>c.open)throw Error("OPERATIONS_INVALID");
 const c=r.receivables;if(!c||!n(c.open)||!n(c.overdue)||!n(c.balance_xaf)||c.overdue>c.open)throw Error("OPERATIONS_INVALID");return r;
}
export function TransverseOperations(p:Props){return <Scoped key={JSON.stringify([p.account.organization_id,p.account.member_id,p.account.role_code,p.siteId,p.authEndpoint,p.anonKey])} {...p}/>;}
function Scoped({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const [data,setData]=useState<Data|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const request=useRef<AbortController|null>(null),alive=useRef(false);
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden"){request.current?.abort();request.current=null;setData(null);setBusy(false);setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;request.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function load(){
  if(!siteId||busy||document.visibilityState==="hidden")return;
  const c=new AbortController();request.current=c;setBusy(true);setError(false);setData(null);
  const current=()=>alive.current&&request.current===c&&!c.signal.aborted&&document.visibilityState!=="hidden";
  try{const v=await privateRequest<unknown>(c.signal,current,getToken,(jwt,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/ns_cross_activity_operations",{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId}),signal,cache:"no-store",credentials:"omit",redirect:"error"}));if(current())setData(validateOperations(v,siteId));}catch{if(current())setError(true);}finally{if(current()){request.current=null;setBusy(false);}}
 }
 if(!siteId||!["promoter","network_manager","site_manager"].includes(account.role_code))return null;
 const title=tr("Suivi transversal des opérations","Cross-activity operations","Rewindo golle fof");
 return <section className="module-main-card" aria-label={title} aria-busy={busy}><h2>{title}</h2><p>{tr("Données du site, catégories distinctes et échéances dépassées.","Site records, separate categories and overdue deadlines.","Humpito nokkuure e sahaaaji ɓennuɗi.")}</p><button className="btn secondary" disabled={busy} onClick={()=>void load()}>{tr("Charger les opérations","Load operations","Loow golle")}</button>{error&&<p role="alert">{tr("Données indisponibles","Data unavailable","Humpito heɓotaako")}</p>}{data&&<><p>{new Date(data.generated_at).toLocaleString(account.default_locale==="ff-CM"?"fr-CM":account.default_locale,{timeZone:"Africa/Douala"})}</p>{[[tr("Ordres de service","Service orders","Golle"),data.orders],[tr("Tickets pressing","Pressing tickets","Tikete pressing"),data.pressing],[tr("Rendez-vous","Appointments","Kawrital"),data.appointments]].map(([label,c])=><article key={label as string}><h3>{label as string}</h3><p>{tr("Ouverts","Open","Udditii")}: {(c as Counts).open} · {tr("En retard","Overdue","Ɓenni")}: {(c as Counts).overdue} · {tr("Prêts","Ready","Heblii")}: {(c as Counts).ready}</p></article>)}<article><h3>{tr("Créances clients","Customer receivables","Ceede soottotooɓe")}</h3><p>{data.receivables.open} · {tr("En retard","Overdue","Ɓenni")}: {data.receivables.overdue} · {data.receivables.balance_xaf} FCFA</p></article></>}</section>;
}
