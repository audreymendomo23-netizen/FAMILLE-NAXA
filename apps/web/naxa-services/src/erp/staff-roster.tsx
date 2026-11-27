import React,{useEffect,useRef,useState} from "react";
import type { WebAuthAccount } from "../auth/session";

type Target={member_id:string;display_name:string;workstation_id:string|null;workstation_name:string|null};
type Shift={id:string;member_id:string;site_id:string;workstation_id:string|null;starts_at:string;ends_at:string;planned_break_minutes:number;tolerance_minutes:number;status:"published"|"cancelled";revision:number;change_reason:string};
type Ack={shift_id:string;revision:number;acknowledged_at:string};
type Comparison={shift_id:string;baseline_revision:number;current_revision:number;actual_start:string|null;actual_end:string|null;late_minutes:number|null;early_departure_minutes:number|null;extra_minutes:number|null;actual_break_minutes:number|null;comparison_status:string};
type Justification={shift_id:string;baseline_revision:number;explanation:string;decision:"accepted"|"rejected"|null;decision_reason:string|null};
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
type Form={id:string;target:string;start:string;end:string;pause:string;tolerance:string;revision:number;reason:string};
const key=(t:Target)=>t.member_id+":"+(t.workstation_id??"");
const localInput=(iso:string)=>new Date(Date.parse(iso)+3600000).toISOString().slice(0,16);
const toIso=(value:string)=>new Date(value+":00+01:00").toISOString();
const blank=():Form=>({id:"",target:"",start:"",end:"",pause:"0",tolerance:"10",revision:0,reason:""});
const modeEnabled=(mode:string)=>mode==="single_site_multi_workstation"||mode==="multi_site_network";
export {modeEnabled as rosterModeEnabled};
export function rosterApiOrigin(endpoint:string):string{
 const u=new URL(endpoint);
 if(u.protocol!=="https:"||u.username||u.password||u.pathname.replace(/\/$/,"")!=="/functions/v1/naxa-services-auth")throw new Error("INVALID_ROSTER_ENDPOINT");
 return u.origin;
}
export function StaffRoster({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const locale=account.default_locale;
 const tr=(fr:string,en:string,ff:string)=>locale==="en"?en:locale==="ff-CM"?ff:fr;
 const [targets,setTargets]=useState<Target[]>([]),[shifts,setShifts]=useState<Shift[]>([]),[acks,setAcks]=useState<Ack[]>([]),[comparisons,setComparisons]=useState<Comparison[]>([]);
 const [justifications,setJustifications]=useState<Justification[]>([]);
 const pendingPublish=useRef<{key:string;id:string}|null>(null);
 const [form,setForm]=useState<Form>(blank),[error,setError]=useState(""),[busy,setBusy]=useState(false),[loaded,setLoaded]=useState(false);
 const tokenRef=useRef(getToken);tokenRef.current=getToken;
 const alive=useRef(false),refreshing=useRef(false);
 const [version,setVersion]=useState(0);
 const canManage=targets.length>0;
 const textError=tr("Planning indisponible. Vérifiez la connexion et réessayez.","Schedule unavailable. Check your connection and retry.","Feere golle heɓotaake. Ƴeewto ceŋol, kadi eto.");
 const fmt=(iso:string|null)=>iso?new Intl.DateTimeFormat(locale==="ff-CM"?"fr-CM":locale,{dateStyle:"short",timeStyle:"short",timeZone:"Africa/Douala"}).format(new Date(iso)):"—";
 async function request<T>(path:string,body?:Record<string,unknown>,signal?:AbortSignal):Promise<T>{
  const token=await tokenRef.current();if(signal?.aborted||!alive.current||!token||!anonKey)throw new Error("SESSION_CHANGED");
  const res=await fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/"+path,{method:body?"POST":"GET",headers:{apikey:anonKey,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation"},body:body?JSON.stringify(body):undefined,cache:"no-store",credentials:"omit",signal});
  if(!res.ok)throw new Error("ROSTER_REQUEST_FAILED");
  return await res.json() as T;
 }
 useEffect(()=>{
  alive.current=true;
  const abort=new AbortController();
  async function refresh(){
   if(refreshing.current||!modeEnabled(account.business_mode)||!siteId)return;
   refreshing.current=true;
   try{
    const filter="org_id=eq."+encodeURIComponent(account.organization_id)+"&site_id=eq."+encodeURIComponent(siteId);
    const [next,people,read,report,explanations]=await Promise.all([
      request<Shift[]>("ns_roster_shifts?select=*&"+filter+"&order=starts_at.desc&limit=200",undefined,abort.signal),
      request<Target[]>("rpc/ns_roster_targets",{p_org:account.organization_id,p_site:siteId},abort.signal),
      request<Ack[]>("ns_roster_acknowledgements?select=shift_id,revision,acknowledged_at&"+filter+"&limit=1000",undefined,abort.signal),
      request<Comparison[]>("ns_roster_service_comparison?select=*&"+filter+"&limit=200",undefined,abort.signal),
      request<Justification[]>("ns_roster_justifications?select=shift_id,baseline_revision,explanation,decision,decision_reason&"+filter+"&limit=200",undefined,abort.signal)]);
    if(!abort.signal.aborted){setShifts(next);setTargets(people);setAcks(read);setComparisons(report);setJustifications(explanations);setLoaded(true);setError("");}
   }catch{if(!abort.signal.aborted){setError(textError);setLoaded(false);setShifts([]);setTargets([]);setAcks([]);setComparisons([]);setJustifications([]);}}
   finally{refreshing.current=false;}
  }
  void refresh();
  const interval=window.setInterval(()=>{if(document.visibilityState==="visible")void refresh();},30000);
  const onVisibility=()=>{if(document.visibilityState==="visible")void refresh();};
  document.addEventListener("visibilitychange",onVisibility);
  return()=>{alive.current=false;abort.abort();refreshing.current=false;window.clearInterval(interval);document.removeEventListener("visibilitychange",onVisibility);};
 },[account.organization_id,account.member_id,account.business_mode,siteId,authEndpoint,anonKey,version]);
 function edit(s:Shift){
  const target=targets.find(t=>t.member_id===s.member_id&&t.workstation_id===s.workstation_id);if(!target)return;
  setForm({id:s.id,target:key(target),start:localInput(s.starts_at),end:localInput(s.ends_at),pause:String(s.planned_break_minutes),tolerance:String(s.tolerance_minutes),revision:s.revision,reason:""});
 }
 async function save(cancel?:Shift){
  if(busy||!loaded)return;
  const selected=cancel?targets.find(t=>t.member_id===cancel.member_id&&t.workstation_id===cancel.workstation_id):targets.find(t=>key(t)===form.target);
  if(!selected)return;
  const reason=cancel?window.prompt(tr("Motif de l'annulation","Reason for cancellation","Sabu haaytugol")):form.reason;
  if(!reason?.trim())return;
  setBusy(true);setError("");
  try{
   const command={p_org:account.organization_id,p_site:siteId,p_post:selected.workstation_id,p_member:selected.member_id,p_starts:cancel?.starts_at??toIso(form.start),p_ends:cancel?.ends_at??toIso(form.end),p_break:cancel?.planned_break_minutes??Number(form.pause),p_tolerance:cancel?.tolerance_minutes??Number(form.tolerance),p_status:cancel?"cancelled":"published",p_expected_revision:cancel?.revision??form.revision,p_reason:reason.trim()};
   const fingerprint=JSON.stringify(command);
   const id=cancel?.id||form.id||(pendingPublish.current?.key===fingerprint?pendingPublish.current.id:crypto.randomUUID());
   if(!cancel&&!form.id)pendingPublish.current={key:fingerprint,id};
   const receipt=await request<{id:string;revision:number;status:string}>("rpc/ns_publish_roster_shift",{p_id:id,...command});
   if(receipt.id!==id||receipt.revision!==command.p_expected_revision+1||receipt.status!==command.p_status)throw new Error("ROSTER_RECEIPT_INVALID");
   pendingPublish.current=null;
   if(alive.current){setForm(blank());setVersion(v=>v+1);}
  }catch{if(alive.current)setError(tr("Modification non confirmée. Actualisez le planning et vérifiez les horaires.","Change not confirmed. Refresh the schedule and check the hours.","Baylugol tabbitinaaka. Hesɗitin feere golle, ƴeewto sahaa."));}
  finally{if(alive.current)setBusy(false);}
 }
 async function acknowledge(s:Shift){
  if(busy||!loaded)return;setBusy(true);setError("");
  try{await request("rpc/ns_ack_roster_shift",{p_id:s.id,p_revision:s.revision});if(alive.current)setVersion(v=>v+1);}
  catch{if(alive.current)setError(textError);}finally{if(alive.current)setBusy(false);}
 }
 async function explain(s:Shift,c:Comparison,decision?:"accepted"|"rejected"){
  if(busy||!loaded)return;
  const reason=window.prompt(decision?tr("Motif de la décision","Decision reason","Sabu ñaawol"):tr("Expliquez l'écart","Explain the variance","Humpit ceertugol"));
  if(!reason?.trim()||reason.trim().length>1000)return;
  setBusy(true);setError("");
  try{
   const body={p_shift:s.id,p_revision:c.baseline_revision};
   const response=decision?await request<{decision:string}>("rpc/ns_decide_roster_justification",{...body,p_decision:decision,p_reason:reason.trim()}):await request<{submitted:boolean}>("rpc/ns_submit_roster_justification",{...body,p_explanation:reason.trim()});
   if(decision?!("decision" in response&&response.decision===decision):!("submitted" in response&&response.submitted===true))throw new Error("ROSTER_JUSTIFICATION_RECEIPT");
   if(alive.current)setVersion(v=>v+1);
  }catch{if(alive.current)setError(textError);}finally{if(alive.current)setBusy(false);}
 }
 if(!modeEnabled(account.business_mode)||!siteId)return null;
 const statusText=(s:string)=>(({variance_review:tr("Écart à examiner","Variance to review","Ceertugol ƴeewtetee"),unmatched_review:tr("Pointage à vérifier","Attendance to verify","Naatugol ƴeewtetee"),awaiting_clock_in:tr("Service à venir","Upcoming shift","Golle arde"),in_service_or_incomplete:tr("En service / incomplet","On duty / incomplete","E golle / timmaaki"),within_tolerance:tr("Dans la tolérance","Within tolerance","E yaafuyya"),multiple_sessions_review:tr("Plusieurs services à vérifier","Multiple sessions to review","Golle keewɗe ƴeewtetee"),cancelled:tr("Annulé","Cancelled","Haaytaama")} as Record<string,string>)[s]??"—");
 return <section className="module-main-card" aria-label={tr("Planning de service","Work schedule","Feere golle")}>
  <h2>{tr("Planning de service","Work schedule","Feere golle")}</h2>
  <p>{tr("Horaires de Douala (UTC+1). Les modifications sont notifiées et historisées.","Douala time (UTC+1). Changes are notified and recorded.","Sahaa Duwaala (UTC+1). Baylugol winndetee.")}</p>
  <button type="button" className="btn secondary" disabled={busy} onClick={()=>setVersion(v=>v+1)}>{tr("Actualiser","Refresh","Hesɗitin")}</button>
  {error&&<p role="alert">{error}</p>}
  {loaded&&canManage&&<form onSubmit={e=>{e.preventDefault();void save();}}>
   <h3>{form.revision?tr("Modifier le service","Edit shift","Waylu golle"):tr("Publier un service","Publish shift","Bayyin golle")}</h3>
   <label>{tr("Collaborateur et poste","Employee and workstation","Gollotooɗo e nokkuure")}<select required value={form.target} disabled={busy||Boolean(form.id)} onChange={e=>setForm(f=>({...f,target:e.target.value}))}><option value="">—</option>{targets.map(t=><option key={key(t)} value={key(t)}>{t.display_name} · {t.workstation_name??tr("Site","Site","Nokkuure")}</option>)}</select></label>
   <label>{tr("Début de service","Shift start","Fuɗɗagol golle")}<input required type="datetime-local" value={form.start} onChange={e=>setForm(f=>({...f,start:e.target.value}))}/></label>
   <label>{tr("Fin de service","Shift end","Timmugol golle")}<input required type="datetime-local" value={form.end} onChange={e=>setForm(f=>({...f,end:e.target.value}))}/></label>
   <label>{tr("Pause prévue (min)","Planned break (min)","Fooftugol (min)")}<input required type="number" min="0" max="1439" value={form.pause} onChange={e=>setForm(f=>({...f,pause:e.target.value}))}/></label>
   <label>{tr("Tolérance (min)","Tolerance (min)","Yaafuyya (min)")}<input required type="number" min="0" max="120" value={form.tolerance} onChange={e=>setForm(f=>({...f,tolerance:e.target.value}))}/></label>
   <label>{tr("Motif","Reason","Sabu")}<textarea required maxLength={500} value={form.reason} onChange={e=>setForm(f=>({...f,reason:e.target.value}))}/></label>
   <button className="btn primary" disabled={busy}>{tr("Publier et notifier","Publish and notify","Bayyin e tintin")}</button>
   {form.id&&<button type="button" className="btn secondary" onClick={()=>setForm(blank())}>{tr("Annuler la modification","Discard changes","Haaytu baylugol")}</button>}
  </form>}
  {loaded&&shifts.length===0&&<p>{tr("Aucun service planifié.","No scheduled shifts.","Alaa golle e feere.")}</p>}
  {shifts.map(s=>{const own=s.member_id===account.member_id,editable=targets.some(t=>t.member_id===s.member_id&&t.workstation_id===s.workstation_id),ack=acks.find(a=>a.shift_id===s.id&&a.revision===s.revision);return <article className="activity-record" key={s.id}>
   <strong>{own?tr("Mon service","My shift","Golle am"):targets.find(t=>t.member_id===s.member_id)?.display_name??tr("Collaborateur","Employee","Gollotooɗo")}</strong>
   <p>{fmt(s.starts_at)} — {fmt(s.ends_at)} · {tr("Pause","Break","Fooftugol")} {s.planned_break_minutes} min</p>
   <p>{s.status==="cancelled"?tr("Annulé","Cancelled","Haaytaama"):tr("Publié","Published","Bayyinaama")} · {tr("Version","Version","Yamre")} {s.revision} · {ack?tr("Pris en compte","Acknowledged","Jaɓaama"):tr("À confirmer","Awaiting acknowledgement","Foti jaɓeede")}</p>
   {own&&!ack&&<button type="button" className="btn primary" disabled={busy||!loaded} onClick={()=>void acknowledge(s)}>{tr("J'ai pris connaissance","Acknowledge","Mi heɓii humpito")}</button>}
   {editable&&s.status==="published"&&<><button type="button" className="btn secondary" disabled={busy||!loaded} onClick={()=>edit(s)}>{tr("Modifier","Edit","Waylu")}</button> <button type="button" className="btn secondary" disabled={busy||!loaded} onClick={()=>void save(s)}>{tr("Annuler le service","Cancel shift","Haaytu golle")}</button></>}
   {comparisons.filter(c=>c.shift_id===s.id).map(c=><div key={c.baseline_revision}><strong>{statusText(c.comparison_status)}</strong><p>{tr("Référence","Baseline","Ɗo ƴeewtoroo")} {c.baseline_revision} · {tr("Arrivée","Arrival","Naatugol")} {fmt(c.actual_start)} · {tr("Départ","Departure","Yaltugol")} {fmt(c.actual_end)}</p><p>{tr("Retard","Late","Leeltugol")}: {c.late_minutes??"—"} min · {tr("Départ anticipé","Early departure","Yaltugol adii")} : {c.early_departure_minutes??"—"} min · {tr("Temps supplémentaire","Extra time","Sahaa ɓeydiiɗo")}: {c.extra_minutes??"—"} min · {tr("Pause réelle","Actual break","Fooftugol goonga")}: {c.actual_break_minutes??"—"} min</p>
    {(()=>{const j=justifications.find(x=>x.shift_id===s.id&&x.baseline_revision===c.baseline_revision);return j?<><p>{j.explanation}</p><p>{j.decision==="accepted"?tr("Justification acceptée","Explanation accepted","Jaɓaama"):j.decision==="rejected"?tr("Justification refusée","Explanation rejected","Jaɓaaka"):tr("Justification à examiner","Explanation awaiting review","Ƴeewto")}{j.decision_reason?" · "+j.decision_reason:""}</p>{editable&&!j.decision&&<><button type="button" disabled={busy} onClick={()=>void explain(s,c,"accepted")}>{tr("Accepter","Accept","Jaɓ")}</button><button type="button" disabled={busy} onClick={()=>void explain(s,c,"rejected")}>{tr("Refuser","Reject","Sal")}</button></>}</>:own&&["variance_review","unmatched_review","multiple_sessions_review"].includes(c.comparison_status)?<button type="button" disabled={busy} onClick={()=>void explain(s,c)}>{tr("Justifier l'écart","Explain variance","Humpit ceertugol")}</button>:null;})()}
   </div>)}
  </article>;})}
 </section>;
}
