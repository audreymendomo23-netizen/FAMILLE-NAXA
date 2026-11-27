import React,{useEffect,useRef,useState} from "react";
import {privateRequest} from "./private-request";
import type { WebAuthAccount } from "../auth/session";

type Target={member_id:string;display_name:string;workstation_id:string|null;workstation_name:string|null};
type Shift={id:string;member_id:string;site_id:string;workstation_id:string|null;starts_at:string;ends_at:string;planned_break_minutes:number;tolerance_minutes:number;status:"published"|"cancelled";revision:number;change_reason:string};
type Ack={shift_id:string;revision:number;acknowledged_at:string};
type Comparison={shift_id:string;baseline_revision:number;current_revision:number;actual_start:string|null;actual_end:string|null;late_minutes:number|null;early_departure_minutes:number|null;extra_minutes:number|null;actual_break_minutes:number|null;comparison_status:string};
type Justification={shift_id:string;baseline_revision:number;explanation:string;decision:"accepted"|"rejected"|null;decision_reason:string|null};
type Availability={id:string;member_id:string;workstation_id:string|null;starts_at:string;ends_at:string;kind:"leave"|"unavailable";reason:string;status:"pending"|"approved"|"rejected";decision_reason:string|null};
type OwnPost={workstation_id:string|null;workstation_name:string|null};
type RosterTemplate={id:string;member_id:string;workstation_id:string|null;name:string;start_minute:number;duration_minutes:number;break_minutes:number;tolerance_minutes:number;repeat_days:number;repeat_count:number};
type RosterAlert={shift_id:string;revision:number;unacknowledged_due:boolean;appointment_conflicts:number};
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
type Form={id:string;target:string;start:string;end:string;pause:string;tolerance:string;revision:number;reason:string;rotation?:string[];repeat:"once"|"daily"|"weekly";count:string};
const key=(t:Target)=>t.member_id+":"+(t.workstation_id??"");
const localInput=(iso:string)=>new Date(Date.parse(iso)+3600000).toISOString().slice(0,16);
const toIso=(value:string)=>new Date(value+":00+01:00").toISOString();
const blank=():Form=>({id:"",target:"",start:"",end:"",pause:"0",tolerance:"10",revision:0,reason:"",repeat:"once",count:"1"});
const modeEnabled=(mode:string)=>mode==="single_site_multi_workstation"||mode==="multi_site_network";
export {modeEnabled as rosterModeEnabled};
export function rosterApiOrigin(endpoint:string):string{
 const u=new URL(endpoint);
 if(u.protocol!=="https:"||u.username||u.password||u.pathname.replace(/\/$/,"")!=="/functions/v1/naxa-services-auth")throw new Error("INVALID_ROSTER_ENDPOINT");
 return u.origin;
}
export function StaffRoster(props:Props){
 // Reset private data, draft commands and retry identifiers whenever the authorization scope changes.
 const scope=JSON.stringify([props.account.organization_id,props.account.member_id,props.account.business_mode,props.siteId,props.authEndpoint,props.anonKey]);
 return <ScopedStaffRoster key={scope} {...props}/>;
}
function ScopedStaffRoster({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const locale=account.default_locale;
 const tr=(fr:string,en:string,ff:string)=>locale==="en"?en:locale==="ff-CM"?ff:fr;
 const [targets,setTargets]=useState<Target[]>([]),[shifts,setShifts]=useState<Shift[]>([]),[acks,setAcks]=useState<Ack[]>([]),[comparisons,setComparisons]=useState<Comparison[]>([]);
 const [justifications,setJustifications]=useState<Justification[]>([]);
 const [availability,setAvailability]=useState<Availability[]>([]),[ownPosts,setOwnPosts]=useState<OwnPost[]>([]),[templates,setTemplates]=useState<RosterTemplate[]>([]),[alerts,setAlerts]=useState<RosterAlert[]>([]);
 const [leave,setLeave]=useState({post:"",kind:"leave",start:"",end:"",reason:""});
 const [replacement,setReplacement]=useState<Record<string,string>>({});
 const [templateDate,setTemplateDate]=useState("");
 const pendingExtensions=useRef(new Map<string,{fingerprint:string;id:string}>());
 function extensionId(kind:string,body:Record<string,unknown>){const fingerprint=JSON.stringify(body);const previous=pendingExtensions.current.get(kind);if(previous?.fingerprint===fingerprint)return previous.id;const id=crypto.randomUUID();pendingExtensions.current.set(kind,{fingerprint,id});return id;}
 const pendingPublish=useRef<{key:string;ids:string[]}|null>(null);
 const [form,setForm]=useState<Form>(blank),[error,setError]=useState(""),[busy,setBusy]=useState(false),[loaded,setLoaded]=useState(false);
 const tokenRef=useRef(getToken);tokenRef.current=getToken;
 const alive=useRef(false),requestScope=useRef<AbortController|null>(null);
 const [version,setVersion]=useState(0);
 const foreground=useRef(true);
 const canManage=targets.length>0;
 const textError=tr("Planning indisponible. Vérifiez la connexion et réessayez.","Schedule unavailable. Check your connection and retry.","Feere golle heɓotaake. Ƴeewto ceŋol, kadi eto.");
 const fmt=(iso:string|null)=>iso?new Intl.DateTimeFormat(locale==="ff-CM"?"fr-CM":locale,{dateStyle:"short",timeStyle:"short",timeZone:"Africa/Douala"}).format(new Date(iso)):"—";
 async function request<T>(path:string,body?:Record<string,unknown>,signal?:AbortSignal):Promise<T>{
  const scope=requestScope.current;const bound=signal??scope?.signal;
  if(!anonKey)throw Error("SESSION_CHANGED");
  return privateRequest<T>(bound,()=>alive.current&&foreground.current&&requestScope.current===scope,tokenRef.current,(token,s)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/"+path,{method:body?"POST":"GET",headers:{apikey:anonKey,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation"},body:body?JSON.stringify(body):undefined,cache:"no-store",credentials:"omit",signal:s}));
 }

 useEffect(()=>{
  alive.current=true;foreground.current=document.visibilityState!=="hidden";
  const abort=new AbortController();requestScope.current=abort;
  let refreshing=false;
  async function refresh(){
   if(abort.signal.aborted||!foreground.current||refreshing||!modeEnabled(account.business_mode)||!siteId)return;
   refreshing=true;
   try{
    const filter="org_id=eq."+encodeURIComponent(account.organization_id)+"&site_id=eq."+encodeURIComponent(siteId);
    const [next,people,read,report,explanations,absences,posts,models,issues]=await Promise.all([
      request<Shift[]>("ns_roster_shifts?select=*&"+filter+"&order=starts_at.desc&limit=200",undefined,abort.signal),
      request<Target[]>("rpc/ns_roster_targets",{p_org:account.organization_id,p_site:siteId},abort.signal),
      request<Ack[]>("ns_roster_acknowledgements?select=shift_id,revision,acknowledged_at&"+filter+"&limit=1000",undefined,abort.signal),
      request<Comparison[]>("ns_roster_service_comparison?select=*&"+filter+"&limit=200",undefined,abort.signal),
      request<Justification[]>("ns_roster_justifications?select=shift_id,baseline_revision,explanation,decision,decision_reason&"+filter+"&limit=200",undefined,abort.signal),
      request<Availability[]>("ns_roster_availability?select=*&"+filter+"&order=starts_at.desc&limit=200",undefined,abort.signal),
      request<OwnPost[]>("rpc/ns_roster_own_posts",{p_org:account.organization_id,p_site:siteId},abort.signal),
      request<RosterTemplate[]>("ns_roster_templates?select=*&"+filter+"&archived_at=is.null&limit=100",undefined,abort.signal),
      request<RosterAlert[]>("rpc/ns_roster_alerts",{p_org:account.organization_id,p_site:siteId},abort.signal)]);
    if(!abort.signal.aborted){setShifts(next);setTargets(people);setAcks(read);setComparisons(report);setJustifications(explanations);setAvailability(absences);setOwnPosts(posts);setTemplates(models);setAlerts(issues);setLoaded(true);setError("");}
   }catch{if(!abort.signal.aborted){setError(textError);setLoaded(false);setShifts([]);setTargets([]);setAcks([]);setComparisons([]);setJustifications([]);setAvailability([]);setOwnPosts([]);setTemplates([]);setAlerts([]);}}
   finally{refreshing=false;}
  }
  void refresh();
  const interval=window.setInterval(()=>{if(document.visibilityState==="visible")void refresh();},30000);
  const onVisibility=()=>{
   foreground.current=document.visibilityState!=="hidden";
   if(!foreground.current){
    abort.abort();setLoaded(false);setBusy(false);setError("");setForm(blank());
    setShifts([]);setTargets([]);setAcks([]);setComparisons([]);setJustifications([]);setAvailability([]);setOwnPosts([]);setTemplates([]);setAlerts([]);
    setReplacement({});setLeave({post:"",kind:"leave",start:"",end:"",reason:""});setTemplateDate("");
   }else setVersion(v=>v+1);
  };
  document.addEventListener("visibilitychange",onVisibility);
  return()=>{alive.current=false;abort.abort();window.clearInterval(interval);document.removeEventListener("visibilitychange",onVisibility);};
 },[account.organization_id,account.member_id,account.business_mode,siteId,authEndpoint,anonKey,version]);
 function commandScope(){const scope=requestScope.current;return ()=>alive.current&&foreground.current&&requestScope.current===scope&&Boolean(scope&&!scope.signal.aborted);}
 function edit(s:Shift){
  const target=targets.find(t=>t.member_id===s.member_id&&t.workstation_id===s.workstation_id);if(!target)return;
  setForm({id:s.id,target:key(target),start:localInput(s.starts_at),end:localInput(s.ends_at),pause:String(s.planned_break_minutes),tolerance:String(s.tolerance_minutes),revision:s.revision,reason:"",repeat:"once",count:"1"});
 }
 async function save(cancel?:Shift){
  const current=commandScope();if(!current())return;
  if(busy||!loaded)return;
  const selected=cancel?targets.find(t=>t.member_id===cancel.member_id&&t.workstation_id===cancel.workstation_id):targets.find(t=>key(t)===form.target);
  if(!selected)return;
  const reason=cancel?window.prompt(tr("Motif de l'annulation","Reason for cancellation","Sabu haaytugol")):form.reason;
  if(!reason?.trim()||!current())return;
  setBusy(true);setError("");
  try{
   const command={p_org:account.organization_id,p_site:siteId,p_post:selected.workstation_id,p_member:selected.member_id,p_starts:cancel?.starts_at??toIso(form.start),p_ends:cancel?.ends_at??toIso(form.end),p_break:cancel?.planned_break_minutes??Number(form.pause),p_tolerance:cancel?.tolerance_minutes??Number(form.tolerance),p_status:cancel?"cancelled":"published",p_expected_revision:cancel?.revision??form.revision,p_reason:reason.trim()};
   const count=!cancel&&!form.id&&form.repeat!=="once"?Number(form.count):1;
   if(!Number.isInteger(count)||count<1||count>31||(!cancel&&!form.id&&form.repeat!=="once"&&count<2))throw new Error("ROSTER_REPEAT_INVALID");
   const step=(form.repeat==="weekly"?7:1)*86400000;
   const rotation=count>1?(form.rotation??[]):[];
   const people=[selected,...rotation.map(id=>targets.find(t=>t.member_id===id&&t.workstation_id===selected.workstation_id))];
   if(people.some(person=>!person)||people.length>count)throw new Error("ROSTER_ROTATION_INVALID");
   const commands=Array.from({length:count},(_,i)=>i===0?command:{...command,p_member:people[i%people.length]!.member_id,p_starts:new Date(Date.parse(command.p_starts)+i*step).toISOString(),p_ends:new Date(Date.parse(command.p_ends)+i*step).toISOString()});
   const fingerprint=JSON.stringify(commands);
   const ids=cancel||form.id?[cancel?.id||form.id]:pendingPublish.current?.key===fingerprint?pendingPublish.current.ids:commands.map(()=>crypto.randomUUID());
   if(!cancel&&!form.id)pendingPublish.current={key:fingerprint,ids};
   type Receipt={id:string;revision:number;status:string};
   const receipts=count===1?[await request<Receipt>("rpc/ns_publish_roster_shift",{p_id:ids[0],...commands[0]})]:(await request<{receipts:Receipt[]}>("rpc/ns_publish_roster_batch",{p_commands:commands.map((c,i)=>({p_id:ids[i],...c}))})).receipts;
   if(!Array.isArray(receipts)||receipts.length!==count||!ids.every(id=>receipts.filter(r=>r.id===id&&r.revision===command.p_expected_revision+1&&r.status===command.p_status).length===1))throw new Error("ROSTER_RECEIPT_INVALID");
   if(current()){pendingPublish.current=null;setForm(blank());setVersion(v=>v+1);}
  }catch{if(current())setError(tr("Modification non confirmée. Actualisez le planning et vérifiez les horaires.","Change not confirmed. Refresh the schedule and check the hours.","Baylugol tabbitinaaka. Hesɗitin feere golle, ƴeewto sahaa."));}
  finally{if(current())setBusy(false);}
 }
 async function acknowledge(s:Shift){
  const current=commandScope();if(!current())return;
  if(busy||!loaded)return;setBusy(true);setError("");
  try{await request("rpc/ns_ack_roster_shift",{p_id:s.id,p_revision:s.revision});if(current())setVersion(v=>v+1);}
  catch{if(current())setError(textError);}finally{if(current())setBusy(false);}
 }
 async function explain(s:Shift,c:Comparison,decision?:"accepted"|"rejected"){
  const current=commandScope();if(!current())return;
  if(busy||!loaded)return;
  const reason=window.prompt(decision?tr("Motif de la décision","Decision reason","Sabu ñaawol"):tr("Expliquez l'écart","Explain the variance","Humpit ceertugol"));
  if(!reason?.trim()||reason.trim().length>1000||!current())return;
  setBusy(true);setError("");
  try{
   const body={p_shift:s.id,p_revision:c.baseline_revision};
   const response=decision?await request<{decision:string}>("rpc/ns_decide_roster_justification",{...body,p_decision:decision,p_reason:reason.trim()}):await request<{submitted:boolean}>("rpc/ns_submit_roster_justification",{...body,p_explanation:reason.trim()});
   if(decision?!("decision" in response&&response.decision===decision):!("submitted" in response&&response.submitted===true))throw new Error("ROSTER_JUSTIFICATION_RECEIPT");
   if(current())setVersion(v=>v+1);
  }catch{if(current())setError(textError);}finally{if(current())setBusy(false);}
 }
 async function extension(action:()=>Promise<void>){
  const current=commandScope();if(!current())return;
  if(busy||!loaded)return;
  setBusy(true);setError("");
  try{await action();if(current())setVersion(v=>v+1);}
  catch{if(current())setError(tr("Opération non confirmée. Vérifiez les droits, les horaires et les services en conflit.","Operation not confirmed. Check permissions, times and conflicting shifts.","Golle tabbitinaaka. Ƴeewto yamirooje e sahaa."));}
  finally{if(current())setBusy(false);}
 }
 async function requestLeave(){await extension(async()=>{
  const body={p_org:account.organization_id,p_site:siteId,p_post:leave.post||null,p_kind:leave.kind,p_start:toIso(leave.start),p_end:toIso(leave.end),p_reason:leave.reason.trim()};
  if(!ownPosts.some(p=>(p.workstation_id??"")===leave.post))throw new Error("ROSTER_SCOPE");
  const id=extensionId("availability",body);
  const r=await request<{id:string;status:string}>("rpc/ns_request_roster_availability",{p_id:id,...body});
  if(r.id!==id||!["pending","approved","rejected"].includes(r.status))throw new Error("ROSTER_RECEIPT_INVALID");
  pendingExtensions.current.delete("availability");setLeave(v=>({...v,start:"",end:"",reason:""}));
 });}
 async function decideLeave(a:Availability,status:"approved"|"rejected"){
  const reason=window.prompt(tr("Motif de la décision","Decision reason","Sabu ñaawol"));if(!reason?.trim())return;
  await extension(async()=>{const r=await request<{id:string;status:string}>("rpc/ns_decide_roster_availability",{p_id:a.id,p_status:status,p_reason:reason.trim()});if(r.id!==a.id||r.status!==status)throw new Error("ROSTER_RECEIPT_INVALID");});
 }
 async function replaceShift(s:Shift){
  const member=replacement[s.id];if(!member)return;
  const reason=window.prompt(tr("Motif du remplacement","Replacement reason","Sabu lomtingol"));if(!reason?.trim())return;
  await extension(async()=>{const body={p_shift:s.id,p_revision:s.revision,p_member:member,p_reason:reason.trim()};const id=extensionId("replacement:"+s.id,body);
   const r=await request<{original_shift_id:string;replacement_shift_id:string;replaced:boolean}>("rpc/ns_replace_roster_shift",{...body,p_new_shift:id});
   if(r.original_shift_id!==s.id||r.replacement_shift_id!==id||!r.replaced)throw new Error("ROSTER_RECEIPT_INVALID");pendingExtensions.current.delete("replacement:"+s.id);});
 }
 async function saveTemplate(){
  const selected=targets.find(t=>key(t)===form.target);if(!selected||form.id)return;
  const name=window.prompt(tr("Nom du modèle","Template name","Innde leydi"));if(!name?.trim())return;
  await extension(async()=>{
   const mins=Number(form.start.slice(11,13))*60+Number(form.start.slice(14,16));const duration=(Date.parse(toIso(form.end))-Date.parse(toIso(form.start)))/60000;
   const body={p_org:account.organization_id,p_site:siteId,p_post:selected.workstation_id,p_member:selected.member_id,p_name:name.trim(),p_start:mins,p_duration:duration,p_break:Number(form.pause),p_tolerance:Number(form.tolerance),p_step:form.repeat==="weekly"?7:1,p_count:form.repeat==="once"?1:Number(form.count)};
   const id=extensionId("template",body);const r=await request<{id:string;saved:boolean}>("rpc/ns_save_roster_template",{p_id:id,...body});if(r.id!==id||!r.saved)throw new Error("ROSTER_RECEIPT_INVALID");pendingExtensions.current.delete("template");
  });
 }
 function applyTemplate(t:RosterTemplate){
  if(!templateDate||!targets.some(x=>x.member_id===t.member_id&&x.workstation_id===t.workstation_id))return;
  const date=Date.parse(templateDate+"T00:00:00+01:00");if(!Number.isFinite(date))return;
  const start=date+t.start_minute*60000,end=start+t.duration_minutes*60000;
  setForm({...blank(),target:t.member_id+":"+(t.workstation_id??""),start:localInput(new Date(start).toISOString()),end:localInput(new Date(end).toISOString()),pause:String(t.break_minutes),tolerance:String(t.tolerance_minutes),repeat:t.repeat_count===1?"once":t.repeat_days===7?"weekly":"daily",count:String(t.repeat_count),reason:t.name});
 }
 async function archiveTemplate(t:RosterTemplate){if(!window.confirm(tr("Archiver ce modèle ?","Archive this template?","Resnude ndee leydi?")))return;await extension(async()=>{const r=await request<{id:string;archived:boolean}>("rpc/ns_archive_roster_template",{p_id:t.id});if(r.id!==t.id||!r.archived)throw new Error("ROSTER_RECEIPT_INVALID");});}
 if(!modeEnabled(account.business_mode)||!siteId)return null;
 const statusText=(s:string)=>(({variance_review:tr("Écart à examiner","Variance to review","Ceertugol ƴeewtetee"),unmatched_review:tr("Pointage à vérifier","Attendance to verify","Naatugol ƴeewtetee"),awaiting_clock_in:tr("Service à venir","Upcoming shift","Golle arde"),in_service_or_incomplete:tr("En service / incomplet","On duty / incomplete","E golle / timmaaki"),within_tolerance:tr("Dans la tolérance","Within tolerance","E yaafuyya"),multiple_sessions_review:tr("Plusieurs services à vérifier","Multiple sessions to review","Golle keewɗe ƴeewtetee"),cancelled:tr("Annulé","Cancelled","Haaytaama")} as Record<string,string>)[s]??"—");
 return <section className="module-main-card" aria-label={tr("Planning de service","Work schedule","Feere golle")}>
  <h2>{tr("Planning de service","Work schedule","Feere golle")}</h2>
  <p>{tr("Horaires de Douala (UTC+1). Les modifications sont notifiées et historisées.","Douala time (UTC+1). Changes are notified and recorded.","Sahaa Duwaala (UTC+1). Baylugol winndetee.")}</p>
  <button type="button" className="btn secondary" disabled={busy} onClick={()=>setVersion(v=>v+1)}>{tr("Actualiser","Refresh","Hesɗitin")}</button>
  {error&&<p role="alert">{error}</p>}
  {loaded&&ownPosts.length>0&&<details><summary>{tr("Congés et indisponibilités","Leave and availability","Heddaade e alaa")}</summary>
   <form onSubmit={e=>{e.preventDefault();void requestLeave();}}>
    <label>{tr("Lieu de la demande","Request location","Nokkuure ɗaɓɓitannde")}<select value={leave.post} onChange={e=>setLeave(v=>({...v,post:e.target.value}))} required={false}>{!ownPosts.some(p=>p.workstation_id===null)&&<option value="">—</option>}{ownPosts.map(p=><option key={p.workstation_id??"site"} value={p.workstation_id??""}>{p.workstation_name??tr("Site","Site","Nokkuure")}</option>)}</select></label>
    <label>{tr("Type de demande","Request type","Fannu ɗaɓɓitannde")}<select value={leave.kind} onChange={e=>setLeave(v=>({...v,kind:e.target.value}))}><option value="leave">{tr("Congé","Leave","Heddaade")}</option><option value="unavailable">{tr("Indisponibilité","Unavailable","Alaa")}</option></select></label>
    <label>{tr("Début de la demande","Request start","Fuɗɗagol ɗaɓɓitannde")}<input required type="datetime-local" value={leave.start} onChange={e=>setLeave(v=>({...v,start:e.target.value}))}/></label>
    <label>{tr("Fin de la demande","Request end","Timmugol ɗaɓɓitannde")}<input required type="datetime-local" value={leave.end} onChange={e=>setLeave(v=>({...v,end:e.target.value}))}/></label>
    <label>{tr("Motif de la demande","Request reason","Sabu ɗaɓɓitannde")}<textarea required maxLength={500} value={leave.reason} onChange={e=>setLeave(v=>({...v,reason:e.target.value}))}/></label>
    <button disabled={busy} className="btn primary">{tr("Envoyer la demande","Submit request","Neldu ɗaɓɓitannde")}</button>
   </form></details>}
  {loaded&&availability.map(a=>{const own=a.member_id===account.member_id,editable=targets.some(t=>t.member_id===a.member_id&&t.workstation_id===a.workstation_id);return <div key={a.id} className="activity-record"><strong>{a.kind==="leave"?tr("Congé","Leave","Heddaade"):tr("Indisponibilité","Unavailable","Alaa")} · {own?tr("Ma demande","My request","Ɗaɓɓitannde am"):targets.find(t=>t.member_id===a.member_id)?.display_name??tr("Collaborateur","Employee","Gollotooɗo")}</strong><p>{fmt(a.starts_at)} — {fmt(a.ends_at)}</p><p>{a.reason}</p><p>{a.status==="approved"?tr("Approuvée","Approved","Jaɓaama"):a.status==="rejected"?tr("Refusée","Rejected","Jaɓaaka"):tr("À examiner","Awaiting review","Ƴeewto")}{a.decision_reason?" · "+a.decision_reason:""}</p>{editable&&a.status==="pending"&&<><button type="button" disabled={busy} onClick={()=>void decideLeave(a,"approved")}>{tr("Approuver la demande","Approve request","Jaɓ ɗaɓɓitannde")}</button><button type="button" disabled={busy} onClick={()=>void decideLeave(a,"rejected")}>{tr("Refuser la demande","Reject request","Sal ɗaɓɓitannde")}</button></>}</div>;})}
  {loaded&&canManage&&templates.length>0&&<details><summary>{tr("Modèles de service","Shift templates","Leɗɗe golle")}</summary><label>{tr("Date du premier service","First shift date","Ñalngu golle aranere")}<input type="date" value={templateDate} onChange={e=>setTemplateDate(e.target.value)}/></label>{templates.map(t=><p key={t.id}>{t.name} · {t.repeat_count} <button type="button" disabled={busy||!templateDate} onClick={()=>applyTemplate(t)}>{tr("Utiliser le modèle","Use template","Huutoro leydi")}</button> <button type="button" disabled={busy} onClick={()=>void archiveTemplate(t)}>{tr("Archiver","Archive","Resnu")}</button></p>)}</details>}
  {loaded&&canManage&&<form onSubmit={e=>{e.preventDefault();void save();}}>
   <h3>{form.revision?tr("Modifier le service","Edit shift","Waylu golle"):tr("Publier un service","Publish shift","Bayyin golle")}</h3>
   <label>{tr("Collaborateur et poste","Employee and workstation","Gollotooɗo e nokkuure")}<select required value={form.target} disabled={busy||Boolean(form.id)} onChange={e=>setForm(f=>({...f,target:e.target.value,rotation:[]}))}><option value="">—</option>{targets.map(t=><option key={key(t)} value={key(t)}>{t.display_name} · {t.workstation_name??tr("Site","Site","Nokkuure")}</option>)}</select></label>
   <label>{tr("Début de service","Shift start","Fuɗɗagol golle")}<input required type="datetime-local" value={form.start} onChange={e=>setForm(f=>({...f,start:e.target.value}))}/></label>
   <label>{tr("Fin de service","Shift end","Timmugol golle")}<input required type="datetime-local" value={form.end} onChange={e=>setForm(f=>({...f,end:e.target.value}))}/></label>
   <label>{tr("Pause prévue (min)","Planned break (min)","Fooftugol (min)")}<input required type="number" min="0" max="1439" value={form.pause} onChange={e=>setForm(f=>({...f,pause:e.target.value}))}/></label>
   <label>{tr("Tolérance (min)","Tolerance (min)","Yaafuyya (min)")}<input required type="number" min="0" max="120" value={form.tolerance} onChange={e=>setForm(f=>({...f,tolerance:e.target.value}))}/></label>
   {!form.id&&<><label>{tr("Répétition du service","Shift repetition","Ɓeydude golle")}<select aria-label={tr("Répétition du service","Shift repetition","Ɓeydude golle")} value={form.repeat} disabled={busy} onChange={e=>setForm(f=>({...f,repeat:e.target.value as Form["repeat"],rotation:[],count:e.target.value==="once"?"1":"2"}))}><option value="once">{tr("Une fois","Once","Laawol gootol")}</option><option value="daily">{tr("Chaque jour","Daily","Ñalawma kala")}</option><option value="weekly">{tr("Chaque semaine","Weekly","Yontere kala")}</option></select></label>{form.repeat!=="once"&&<label>{tr("Nombre de services","Number of shifts","Limoore golle")}<input required type="number" min="2" max="31" value={form.count} disabled={busy} onChange={e=>setForm(f=>({...f,count:e.target.value}))}/></label>}</>}
   {!form.id&&form.repeat!=="once"&&form.target&&<fieldset disabled={busy}><legend>{tr("Rotation des collaborateurs","Employee rotation","Gollotooɓe e dow deggondiral")}</legend>
    {targets.filter(t=>key(t)!==form.target&&t.workstation_id===targets.find(person=>key(person)===form.target)?.workstation_id).map(t=>{
     const order=(form.rotation??[]).indexOf(t.member_id);
     return <label key={key(t)}><input type="checkbox" checked={order>=0} onChange={e=>{
      const checked=e.target.checked;
      setForm(f=>({...f,rotation:checked?[...(f.rotation??[]),t.member_id]:(f.rotation??[]).filter(id=>id!==t.member_id)}));
     }}/>{order>=0?(order+2)+". ":""}{t.display_name}</label>;
    })}
   </fieldset>}
   <label>{tr("Motif","Reason","Sabu")}<textarea required maxLength={500} value={form.reason} onChange={e=>setForm(f=>({...f,reason:e.target.value}))}/></label>
   <button className="btn primary" disabled={busy||(form.rotation?.length??0)>=Number(form.count)}>{tr("Publier et notifier","Publish and notify","Bayyin e tintin")}</button>
   {!form.id&&!form.rotation?.length&&<button type="button" className="btn secondary" disabled={busy||!form.target||!form.start||!form.end} onClick={()=>void saveTemplate()}>{tr("Enregistrer comme modèle","Save as template","Resnu leydi")}</button>}
   {form.id&&<button type="button" className="btn secondary" onClick={()=>setForm(blank())}>{tr("Annuler la modification","Discard changes","Haaytu baylugol")}</button>}
  </form>}
  {loaded&&shifts.length===0&&<p>{tr("Aucun service planifié.","No scheduled shifts.","Alaa golle e feere.")}</p>}
  {shifts.map(s=>{const own=s.member_id===account.member_id,editable=targets.some(t=>t.member_id===s.member_id&&t.workstation_id===s.workstation_id),ack=acks.find(a=>a.shift_id===s.id&&a.revision===s.revision);return <article className="activity-record" key={s.id}>
   <strong>{own?tr("Mon service","My shift","Golle am"):targets.find(t=>t.member_id===s.member_id)?.display_name??tr("Collaborateur","Employee","Gollotooɗo")}</strong>
   <p>{fmt(s.starts_at)} — {fmt(s.ends_at)} · {tr("Pause","Break","Fooftugol")} {s.planned_break_minutes} min</p>
   <p>{s.status==="cancelled"?tr("Annulé","Cancelled","Haaytaama"):tr("Publié","Published","Bayyinaama")} · {tr("Version","Version","Yamre")} {s.revision} · {ack?tr("Pris en compte","Acknowledged","Jaɓaama"):tr("À confirmer","Awaiting acknowledgement","Foti jaɓeede")}</p>
   {own&&!ack&&<button type="button" className="btn primary" disabled={busy||!loaded} onClick={()=>void acknowledge(s)}>{tr("J'ai pris connaissance","Acknowledge","Mi heɓii humpito")}</button>}
   {editable&&s.status==="published"&&<><button type="button" className="btn secondary" disabled={busy||!loaded} onClick={()=>edit(s)}>{tr("Modifier","Edit","Waylu")}</button> <button type="button" className="btn secondary" disabled={busy||!loaded} onClick={()=>void save(s)}>{tr("Annuler le service","Cancel shift","Haaytu golle")}</button></>}
   {editable&&alerts.filter(a=>a.shift_id===s.id&&a.revision===s.revision).map(a=><div key={a.shift_id}>{a.unacknowledged_due&&<p>{tr("Accusé en retard","Acknowledgement overdue","Jaɓgol leelii")}</p>}{a.appointment_conflicts>0&&<p>{tr("Rendez-vous à réaffecter ou vérifier","Appointments to reassign or review","Ɗe njiillooje ƴeewtetee")}: {a.appointment_conflicts}</p>}</div>)}
   {editable&&s.status==="published"&&Date.parse(s.starts_at)>Date.now()&&targets.some(t=>t.member_id!==s.member_id&&t.workstation_id===s.workstation_id)&&<><label>{tr("Remplaçant","Substitute","Lomtinɗo")}<select aria-label={tr("Remplaçant","Substitute","Lomtinɗo")} value={replacement[s.id]??""} onChange={e=>setReplacement(v=>({...v,[s.id]:e.target.value}))}><option value="">—</option>{targets.filter(t=>t.member_id!==s.member_id&&t.workstation_id===s.workstation_id).map(t=><option key={t.member_id} value={t.member_id}>{t.display_name}</option>)}</select></label><button type="button" disabled={busy||!replacement[s.id]} onClick={()=>void replaceShift(s)}>{tr("Remplacer le collaborateur","Replace employee","Lomtin gollotooɗo")}</button></>}
   {comparisons.filter(c=>c.shift_id===s.id).map(c=><div key={c.baseline_revision}><strong>{statusText(c.comparison_status)}</strong><p>{tr("Référence","Baseline","Ɗo ƴeewtoroo")} {c.baseline_revision} · {tr("Arrivée","Arrival","Naatugol")} {fmt(c.actual_start)} · {tr("Départ","Departure","Yaltugol")} {fmt(c.actual_end)}</p><p>{tr("Retard","Late","Leeltugol")}: {c.late_minutes??"—"} min · {tr("Départ anticipé","Early departure","Yaltugol adii")} : {c.early_departure_minutes??"—"} min · {tr("Temps supplémentaire","Extra time","Sahaa ɓeydiiɗo")}: {c.extra_minutes??"—"} min · {tr("Pause réelle","Actual break","Fooftugol goonga")}: {c.actual_break_minutes??"—"} min</p>
    {(()=>{const j=justifications.find(x=>x.shift_id===s.id&&x.baseline_revision===c.baseline_revision);return j?<><p>{j.explanation}</p><p>{j.decision==="accepted"?tr("Justification acceptée","Explanation accepted","Jaɓaama"):j.decision==="rejected"?tr("Justification refusée","Explanation rejected","Jaɓaaka"):tr("Justification à examiner","Explanation awaiting review","Ƴeewto")}{j.decision_reason?" · "+j.decision_reason:""}</p>{editable&&!j.decision&&<><button type="button" disabled={busy} onClick={()=>void explain(s,c,"accepted")}>{tr("Accepter","Accept","Jaɓ")}</button><button type="button" disabled={busy} onClick={()=>void explain(s,c,"rejected")}>{tr("Refuser","Reject","Sal")}</button></>}</>:own&&["variance_review","unmatched_review","multiple_sessions_review"].includes(c.comparison_status)?<button type="button" disabled={busy} onClick={()=>void explain(s,c)}>{tr("Justifier l'écart","Explain variance","Humpit ceertugol")}</button>:null;})()}
   </div>)}
  </article>;})}
 </section>;
}
