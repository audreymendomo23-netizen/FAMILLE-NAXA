import React,{useEffect,useRef,useState} from "react";
import type {WebAuthAccount} from "../auth/session";
import {privateRequest} from "./private-request";
import {CommissionReview} from "./commission-review";
import {CommissionPlans} from "./commission-plans";
import {rosterApiOrigin} from "./staff-roster";
type Choice={id:string;name:string;site_id?:string|null};
type Policy={id:string;code:string;version:number;status:string;method:string;rate_bps:number|null;fixed_amount_xaf:number|null;effective_from:string;effective_until:string|null;site_id:string|null;member_id:string|null;service_id:string|null;activity_profile:string|null;reference:string};
type Catalog={settings:{enabled:boolean;revision:number};sites:Choice[];members:Choice[];services:Choice[];policies:Policy[]};
type Draft={code:string;version:string;method:"percent_bps"|"fixed_xaf";amount:string;site:string;member:string;service:string;activity:boolean;from:string;until:string;reference:string;approved:boolean};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const date=(s:string)=>/^\d{4}-\d{2}-\d{2}$/.test(s)&&Number.isFinite(Date.parse(s+"T00:00:00Z"))&&new Date(s+"T00:00:00Z").toISOString().slice(0,10)===s;
const activityProfiles=new Set(["pressing","coiffure","couture","beaute","parfumerie","reparation","menuiserie","garage","nettoyage","domicile","impression","photo_evenementiel","autre"]);
const empty=():Draft=>({code:"",version:"1",method:"percent_bps",amount:"",site:"",member:"",service:"",activity:false,from:"",until:"",reference:"",approved:false});
export function commissionPolicyPayload(d:Draft,org:string,activity:string,id:string){
 if((d.activity&&!activityProfiles.has(activity))||!uuid.test(org)||!uuid.test(id)||!d.approved||d.code.trim().length<2||d.code.trim().length>80||d.reference.trim().length<8||d.reference.trim().length>500||!date(d.from)||(d.until&&(!date(d.until)||d.until<d.from))||!/^\d+$/.test(d.version)||Number(d.version)<1||Number(d.version)>2147483647||[d.site,d.member,d.service].some(v=>v&&!uuid.test(v)))throw Error("INVALID_COMMISSION_POLICY");
 let rate:number|null=null,fixed:number|null=null;
 if(d.method==="percent_bps"){
  if(!/^\d{1,3}([.,]\d{1,2})?$/.test(d.amount))throw Error("INVALID_COMMISSION_RATE");
  rate=Math.round(Number(d.amount.replace(",","."))*100);
  if(rate<0||rate>10000)throw Error("INVALID_COMMISSION_RATE");
 }else if(d.method==="fixed_xaf"){
  if(!/^\d+$/.test(d.amount))throw Error("INVALID_COMMISSION_FIXED");
  fixed=Number(d.amount);if(!Number.isSafeInteger(fixed)||fixed<1)throw Error("INVALID_COMMISSION_FIXED");
 }else throw Error("INVALID_COMMISSION_METHOD");
 return {p_id:id,p_org:org,p_site:d.site||null,p_member:d.member||null,p_service:d.service||null,p_activity:d.activity?activity:null,p_code:d.code.trim(),p_version:Number(d.version),p_method:d.method,p_rate:rate,p_fixed:fixed,p_from:d.from,p_until:d.until||null,p_reference:d.reference.trim()};
}
export function validateCommissionCatalog(x:unknown):Catalog{
 if(!x||typeof x!=="object")throw Error("INVALID_COMMISSION_CATALOG");
 const c=x as Catalog;
 if(typeof c.settings?.enabled!=="boolean"||!Number.isSafeInteger(c.settings?.revision)||c.settings.revision<0)throw Error("INVALID_COMMISSION_SETTINGS");
 for(const list of [c.sites,c.members,c.services])if(!Array.isArray(list)||list.some(v=>!v||typeof v.id!=="string"||!uuid.test(v.id)||typeof v.name!=="string"||(v.site_id!=null&&(typeof v.site_id!=="string"||!uuid.test(v.site_id))))||new Set(list.map(v=>v.id.toLowerCase())).size!==list.length)throw Error("INVALID_COMMISSION_CATALOG");
 if(!Array.isArray(c.policies)||c.policies.some(v=>!v||!uuid.test(v.id)||typeof v.code!=="string"||!Number.isSafeInteger(v.version)||!["approved","retired"].includes(v.status)||!["percent_bps","fixed_xaf"].includes(v.method)))throw Error("INVALID_COMMISSION_CATALOG");
 if(new Set(c.policies.map(p=>p.id.toLowerCase())).size!==c.policies.length)throw Error("INVALID_COMMISSION_CATALOG");
 for(const p of c.policies){
  if(!date(p.effective_from)||(p.effective_until!==null&&(!date(p.effective_until)||p.effective_until<p.effective_from))||p.version<1||typeof p.reference!=="string"||[p.site_id,p.member_id,p.service_id].some(x=>x!==null&&(typeof x!=="string"||!uuid.test(x))))throw Error("INVALID_COMMISSION_CATALOG");
  if(p.method==="percent_bps"&&(!Number.isInteger(p.rate_bps)||p.rate_bps===null||p.rate_bps<0||p.rate_bps>10000||p.fixed_amount_xaf!==null))throw Error("INVALID_COMMISSION_CATALOG");
  if(p.method==="fixed_xaf"&&(!Number.isSafeInteger(p.fixed_amount_xaf)||p.fixed_amount_xaf===null||p.fixed_amount_xaf<1||p.rate_bps!==null))throw Error("INVALID_COMMISSION_CATALOG");
 }
 return c;
}
type Props={account:WebAuthAccount;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
export function CommissionSettings(props:Props){
 return props.account.role_code==="promoter"?<ScopedCommissionSettings key={JSON.stringify([props.account.organization_id,props.account.member_id,props.account.activity_profile,props.authEndpoint,props.anonKey])} {...props}/>:null;
}
function ScopedCommissionSettings({account,authEndpoint,anonKey,getToken}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const title=tr("Commissions automatiques","Automatic commissions","Komiisiyoŋaji otomatik");
 const [catalog,setCatalog]=useState<Catalog|null>(null),[draft,setDraft]=useState<Draft>(empty),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const [policyFilter,setPolicyFilter]=useState("all");
 const [allocations,setAllocations]=useState([{line:"",appointment:""},{line:"",appointment:""}]),[batchResult,setBatchResult]=useState("");
 const batchRetry=useRef<{key:string;id:string}|null>(null);
 const [settleSite,setSettleSite]=useState(""),[appointment,setAppointment]=useState(""),[sale,setSale]=useState(""),[settleResult,setSettleResult]=useState("");
 const settlementEnabled=import.meta.env.VITE_NAXA_SERVICES_COMMISSION_SETTLEMENT_ENABLED==="true";
 const mounted=useRef(false),controller=useRef<AbortController|null>(null),retry=useRef<{fingerprint:string;id:string}|null>(null);
 const tokenRef=useRef(getToken);tokenRef.current=getToken;
 // Preserve an uncertain publication UUID in memory across visibility changes. It is destroyed on scope unmount.
 useEffect(()=>{mounted.current=true;const hide=()=>{if(document.visibilityState==="hidden"){controller.current?.abort();controller.current=null;setCatalog(null);setDraft(empty());setSettleSite("");setAppointment("");setSale("");setSettleResult("");setAllocations([{line:"",appointment:""},{line:"",appointment:""}]);setBatchResult("");setBusy(false);setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{mounted.current=false;controller.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function execute(action?:(rpc:(name:string,body:Record<string,unknown>)=>Promise<unknown>)=>Promise<void>){
  if(controller.current||!mounted.current||document.visibilityState==="hidden")return;
  const c=new AbortController();controller.current=c;setBusy(true);setError(false);
  const current=()=>mounted.current&&controller.current===c&&document.visibilityState!=="hidden";
  const rpc=(name:string,body:Record<string,unknown>)=>privateRequest<unknown>(c.signal,current,()=>tokenRef.current(),(token,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify(body),signal,cache:"no-store",credentials:"omit",redirect:"error"}));
  try{
   if(!anonKey)throw Error("COMMISSION_UNAVAILABLE");
   if(action)await action(rpc);
   const result=validateCommissionCatalog(await rpc("ns_automatic_commission_catalog",{p_org:account.organization_id}));
   if(current())setCatalog(result);
  }catch{if(current()){setError(true);setCatalog(null);}}
  finally{if(current()){controller.current=null;setBusy(false);}}
 }
 function change<K extends keyof Draft>(key:K,value:Draft[K]){setDraft(prev=>({...prev,[key]:value}));}
 const publish=()=>void execute(async rpc=>{
  const fingerprint=JSON.stringify(draft);
  if(retry.current?.fingerprint!==fingerprint)retry.current={fingerprint,id:crypto.randomUUID()};
  const payload=commissionPolicyPayload(draft,account.organization_id,account.activity_profile,retry.current.id);
  if(await rpc("ns_publish_automatic_commission_policy",payload)!==payload.p_id)throw Error("COMMISSION_UNCONFIRMED");
  retry.current=null;setDraft(empty());
 });
 const availableServices=catalog?.services.filter(s=>!s.site_id||s.site_id===draft.site)??[];
 return <section className="module-main-card" aria-label={title} aria-busy={busy}><h2>{title}</h2>
 <p>{tr("Facultatif. Aucun décaissement automatique. La génération depuis les prestations n’est pas encore activée.","Optional. No automatic payout. Generation from completed services is not yet enabled.","Suɓaare. Alaa njoɓdi otomatik.")}</p>
 <button className="btn secondary" disabled={busy} onClick={()=>void execute()}>{tr("Charger les paramètres","Load settings","Loow teelte")}</button>
 {error&&<p role="alert">{tr("Paramètres indisponibles ou modification refusée. Rechargez avant de réessayer.","Settings unavailable or change refused. Reload before retrying.","Teelte heɓotaako walla waylugol salaama. Loow kadi.")}</p>}
 {catalog&&<>
 <p role="status">{catalog.settings.enabled?tr("Activé","Enabled","Huɓɓiima"):tr("Désactivé","Disabled","Ñiftiima")}</p>
 <button className="btn secondary" disabled={busy} onClick={()=>void execute(async rpc=>{const next=!catalog.settings.enabled;const v=await rpc("ns_set_automatic_commission_settings",{p_org:account.organization_id,p_enabled:next,p_expected_revision:catalog.settings.revision}) as {enabled?:boolean};if(v.enabled!==next)throw Error("COMMISSION_UNCONFIRMED");})}>{catalog.settings.enabled?tr("Désactiver","Disable","Ñiftin"):tr("Activer","Enable","Huɓɓin")}</button>
 <h3>{tr("Nouvelle règle","New rule","Laawol kesol")}</h3>
 <p>{tr("Les règles qui se chevauchent sont refusées : aucune priorité implicite ni taux par défaut. Sans règle applicable, aucune commission.","Overlapping rules are rejected: no implicit priority or default rate. Without an applicable rule, no commission.","Laabi kawritiiɗi salaama. So alaa laawol, alaa komiisiyoŋ.")}</p>
 <label>{tr("Code de règle","Rule code","Kod laawol")}<input aria-label={tr("Code de règle","Rule code","Kod laawol")} value={draft.code} disabled={busy} onChange={e=>change("code",e.target.value)}/></label>
 <label>Version<input type="number" min="1" value={draft.version} disabled={busy} onChange={e=>change("version",e.target.value)}/></label>
 <label>{tr("Établissement","Site","Nokku")}<select aria-label={tr("Établissement","Site","Nokku")} disabled={busy} value={draft.site} onChange={e=>{change("site",e.target.value);change("service","");}}><option value="">{tr("Tous","All","Fof")}</option>{catalog.sites.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
 <label>{tr("Collaborateur","Staff member","Gollotooɗo")}<select aria-label={tr("Collaborateur","Staff member","Gollotooɗo")} disabled={busy} value={draft.member} onChange={e=>change("member",e.target.value)}><option value="">{tr("Tous","All","Fof")}</option>{catalog.members.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
 <label>{tr("Prestation","Service","Gollal")}<select aria-label={tr("Prestation","Service","Gollal")} disabled={busy} value={draft.service} onChange={e=>change("service",e.target.value)}><option value="">{tr("Toutes","All","Fof")}</option>{availableServices.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
 <label><input type="checkbox" checked={draft.activity} disabled={busy||!activityProfiles.has(account.activity_profile)} onChange={e=>change("activity",e.target.checked)}/>{tr("Limiter à mon activité","Limit to my activity","Heftin e golle am")}</label>
 <label>{tr("Méthode","Method","Feere")}<select aria-label={tr("Méthode","Method","Feere")} value={draft.method} disabled={busy} onChange={e=>{change("method",e.target.value as Draft["method"]);change("amount","");}}><option value="percent_bps">{tr("Pourcentage","Percentage","Teemedere")}</option><option value="fixed_xaf">{tr("Montant fixe FCFA","Fixed XAF amount","Ceede tabbitiiɗe")}</option></select></label>
 <label>{draft.method==="percent_bps"?tr("Taux (%)","Rate (%)","Teemedere (%)"):tr("Montant FCFA","XAF amount","Ceede FCFA")}<input aria-label={draft.method==="percent_bps"?tr("Taux (%)","Rate (%)","Teemedere (%)"):tr("Montant FCFA","XAF amount","Ceede FCFA")} inputMode="decimal" disabled={busy} value={draft.amount} onChange={e=>change("amount",e.target.value)}/></label>
 <label>{tr("Date de début","Start date","Ñalnde fuɗɗorde")}<input aria-label={tr("Date de début","Start date","Ñalnde fuɗɗorde")} type="date" disabled={busy} value={draft.from} onChange={e=>change("from",e.target.value)}/></label>
 <label>{tr("Date de fin (facultative)","End date (optional)","Ñalnde timmorde")}<input aria-label={tr("Date de fin (facultative)","End date (optional)","Ñalnde timmorde")} type="date" disabled={busy} value={draft.until} onChange={e=>change("until",e.target.value)}/></label>
 <label>{tr("Référence de la décision","Decision reference","Winndannde kuugal")}<input aria-label={tr("Référence de la décision","Decision reference","Winndannde kuugal")} disabled={busy} value={draft.reference} onChange={e=>change("reference",e.target.value)}/></label>
 <label><input aria-label={tr("J’approuve cette règle","I approve this rule","Mi jaɓii laawol ngol")} type="checkbox" disabled={busy} checked={draft.approved} onChange={e=>change("approved",e.target.checked)}/>{tr("J’approuve cette règle","I approve this rule","Mi jaɓii laawol ngol")}</label>
 <button className="btn primary" disabled={busy||!draft.approved} onClick={publish}>{tr("Publier la règle","Publish rule","Winndin laawol")}</button>
 {settlementEnabled&&<section aria-label={tr("Rapprochement prestation et vente","Service and sale reconciliation","Kawrital golle e jaaygol")}><h3>{tr("Rapprochement prestation et vente","Service and sale reconciliation","Kawrital golle e jaaygol")}</h3><p>{tr("Uniquement une prestation terminée, une vente de service unique et intégralement confirmée. Préparation pour approbation, aucun paiement.","One completed appointment, one fully confirmed single-service sale only. Preparation for approval, no payout.","Gollal timmuɗal e jaaygol tabbitinaangol. Alaa njoɓdi.")}</p><form onSubmit={e=>{e.preventDefault();if(!uuid.test(settleSite)||!uuid.test(appointment)||!uuid.test(sale))return;setSettleResult("");void execute(async rpc=>{const r=await rpc("ns_prepare_settled_commission",{p_org:account.organization_id,p_site:settleSite,p_appointment:appointment,p_sale:sale}) as {status?:string;entry_id?:string};if(typeof r.status!=="string"||!["disabled","existing","pending_approval","awaiting_completed_and_confirmed","unsupported_sale_allocation","refund_review_required","no_applicable_policy","blocked_ambiguous_policy","no_commission"].includes(r.status))throw Error("COMMISSION_UNCONFIRMED");setSettleResult(r.status);});}}><label>{tr("Site du rapprochement","Reconciliation site","Nokku kawrital")}<select required value={settleSite} disabled={busy} onChange={e=>{setSettleSite(e.target.value);setSettleResult("");}}><option value="">—</option>{catalog.sites.map(s=><option key={s.id} value={s.id}>{s.name}</option>)}</select></label><label>{tr("Identifiant du rendez-vous","Appointment ID","Innol kawrital")}<input required value={appointment} disabled={busy} onChange={e=>{setAppointment(e.target.value);setSettleResult("");}}/></label><label>{tr("Identifiant de la vente","Sale ID","Innol jaaygol")}<input required value={sale} disabled={busy} onChange={e=>{setSale(e.target.value);setSettleResult("");}}/></label><button className="btn primary" disabled={busy||!catalog.settings.enabled||!uuid.test(settleSite)||!uuid.test(appointment)||!uuid.test(sale)}>{tr("Préparer la commission","Prepare commission","Feewnu komiisiyoŋ")}</button></form>{settleResult&&<p role="status">{settleResult}</p>}<h3>{tr("Vente à plusieurs prestations","Multi-service sale","Jaaygol golle keewɗe")}</h3><p>{tr("Associer chaque ligne de service à un rendez-vous terminé distinct. La vente doit être intégralement confirmée.","Assign each service line to a separate completed appointment. The sale must be fully confirmed.","Kawritin golle e kawrital tabbitinaangal.")}</p>
 <form onSubmit={e=>{e.preventDefault();if(!uuid.test(settleSite)||!uuid.test(sale)||allocations.some(a=>!uuid.test(a.line)||!uuid.test(a.appointment))||new Set(allocations.map(a=>a.line.toLowerCase())).size!==allocations.length||new Set(allocations.map(a=>a.appointment.toLowerCase())).size!==allocations.length)return;setBatchResult("");void execute(async rpc=>{const alloc=allocations.map(a=>({line_id:a.line.toLowerCase(),appointment_id:a.appointment.toLowerCase()})).sort((a,b)=>a.line_id.localeCompare(b.line_id));const key=JSON.stringify([settleSite,sale,alloc]);if(batchRetry.current?.key!==key)batchRetry.current={key,id:crypto.randomUUID()};const r=await rpc("ns_prepare_multiline_commissions",{p_org:account.organization_id,p_site:settleSite,p_sale:sale,p_id:batchRetry.current.id,p_allocations:alloc}) as {id?:string;status?:string;lines?:unknown[]};if(r.id!==batchRetry.current.id||r.status!=="prepared"||!Array.isArray(r.lines)||r.lines.length!==alloc.length)throw Error("COMMISSION_UNCONFIRMED");setBatchResult(tr("Lot préparé, consultez la file de validation.","Batch prepared, review the approval queue.","Golle heblii, ƴeewto doggol."));});}}>
 {allocations.map((a,i)=><fieldset key={i}><legend>{i+1}</legend><label>{tr("Identifiant de la ligne de vente","Sale line ID","Innol gorol jaaygol")}<input required disabled={busy} value={a.line} onChange={e=>setAllocations(v=>v.map((x,j)=>j===i?{...x,line:e.target.value}:x))}/></label><label>{tr("Identifiant du rendez-vous","Appointment ID","Innol kawrital")}<input required disabled={busy} value={a.appointment} onChange={e=>setAllocations(v=>v.map((x,j)=>j===i?{...x,appointment:e.target.value}:x))}/></label>{allocations.length>2&&<button type="button" disabled={busy} onClick={()=>setAllocations(v=>v.filter((_,j)=>i!==j))}>{tr("Retirer la ligne","Remove line","Ittu gorol")}</button>}</fieldset>)}
 <button type="button" disabled={busy||allocations.length>=30} onClick={()=>setAllocations(v=>[...v,{line:"",appointment:""}])}>{tr("Ajouter une ligne","Add line","Ɓeydu gorol")}</button><button className="btn primary" disabled={busy||!catalog.settings.enabled||!uuid.test(settleSite)||!uuid.test(sale)||allocations.some(a=>!uuid.test(a.line)||!uuid.test(a.appointment))}>{tr("Préparer les commissions du lot","Prepare batch commissions","Feewnu komiisiyoŋaji")}</button></form>{batchResult&&<p role="status">{batchResult}</p>}<CommissionPlans account={account} siteId={settleSite} sale={sale} allocations={allocations} enabled={catalog.settings.enabled} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken}/><CommissionReview account={account} siteId={settleSite} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken}/></section>}
 <h3>{tr("Historique des règles","Policy history","Aslol laabi")}</h3>
 <label>{tr("Filtrer les règles","Filter policies","Suɓo laabi")}<select value={policyFilter} onChange={e=>setPolicyFilter(e.target.value)}><option value="all">{tr("Toutes","All","Fof")}</option><option value="approved">{tr("Approuvées","Approved","Jaɓaama")}</option><option value="retired">{tr("Retirées","Retired","Ittaama")}</option></select></label>
 {catalog.policies.filter(v=>policyFilter==="all"||v.status===policyFilter).map(v=><article key={v.id} data-commission-policy-id={v.id}><strong>{v.code} · v{v.version}</strong><p>{[v.site_id?catalog.sites.find(s=>s.id===v.site_id)?.name??v.site_id:tr("Tous les sites","All sites","Nokkuuji fof"),v.member_id?catalog.members.find(s=>s.id===v.member_id)?.name??v.member_id:tr("Tous les collaborateurs","All staff","Gollotooɓe fof"),v.service_id?catalog.services.find(s=>s.id===v.service_id)?.name??v.service_id:tr("Toutes les prestations","All services","Golle fof"),v.activity_profile??tr("Toutes les activités","All activities","Golle fof")].join(" · ")}</p><p data-commission-policy-status={v.status}>{v.status==="approved"?tr("Approuvée","Approved","Jaɓaama"):tr("Retirée","Retired","Ittaama")} · {v.method==="percent_bps"?(v.rate_bps===null?"—":v.rate_bps/100+" %"):v.fixed_amount_xaf+" FCFA"} · {v.effective_from}{v.effective_until?" — "+v.effective_until:""}</p>{v.status==="approved"&&<button className="btn secondary" disabled={busy} onClick={()=>{if(window.confirm(tr("Retirer cette règle ?","Retire this rule?","Ittude laawol ngol?")))void execute(async rpc=>{if(await rpc("ns_retire_automatic_commission_policy",{p_org:account.organization_id,p_id:v.id})!==true)throw Error("COMMISSION_UNCONFIRMED");});}}>{tr("Retirer la règle","Retire rule","Ittu laawol")}</button>}</article>)}
 </>}
 </section>;
}
