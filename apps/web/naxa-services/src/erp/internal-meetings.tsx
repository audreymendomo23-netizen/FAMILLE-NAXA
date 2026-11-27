import React,{useEffect,useRef,useState} from "react";
import {privateRequest} from "./private-request";
import {MeetingCollaboration} from "./meeting-collaboration";
import type {WebAuthAccount} from "../auth/session";
import {rosterApiOrigin,rosterModeEnabled} from "./staff-roster";
type Target={member_id:string;display_name:string;workstation_id:string|null;workstation_name:string|null};
type Meeting={id:string;title:string;scheduled_at:string;status:string;revision:number;host_member_id:string;agenda:string;duration_minutes:number;site_id:string;workstation_id:string|null;series_id?:string|null;series_occurrence?:number|null};
type Invite={meeting_id:string;member_id:string;listening_locale:string;recording_consent:boolean|null;response:string};
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
const langs=[["original","Original"],["fr","Français"],["en","English"],["ff-CM","Fulfulde"],["es","Español"],["it","Italiano"],["zh-CN","中文"]];
const local=(s:string)=>new Date(Date.parse(s)+3600000).toISOString().slice(0,16);
const iso=(s:string)=>new Date(s+":00+01:00").toISOString();
export function InternalMeetings({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const [meetings,setMeetings]=useState<Meeting[]>([]),[invites,setInvites]=useState<Invite[]>([]),[targets,setTargets]=useState<Target[]>([]);
 const [selected,setSelected]=useState<string[]>([]),[post,setPost]=useState(""),[title,setTitle]=useState(""),[when,setWhen]=useState(""),[agenda,setAgenda]=useState(""),[duration,setDuration]=useState("30"),[edit,setEdit]=useState<Meeting|null>(null);
 const [frequency,setFrequency]=useState("once"),[count,setCount]=useState("3");
 const [busy,setBusy]=useState(false),[error,setError]=useState(false),[loaded,setLoaded]=useState(false),[revision,setRevision]=useState(0);
 const token=useRef(getToken);token.current=getToken;const alive=useRef(false),controller=useRef<AbortController|null>(null),foreground=useRef(true);
 const pendingCreation=useRef<{signature:string;payload:Record<string,unknown>}|null>(null);
 const retryKey="ns-meeting-retry-v1:"+account.organization_id+":"+account.member_id+":"+siteId;
 function clearRetry(){try{sessionStorage.removeItem(retryKey);}catch{/* private browsing */}}
 const err=tr("Réunion ou modification indisponible. Actualisez et réessayez.","Meeting or change unavailable. Refresh and retry.","Dental walla baylugol heɓotaako. Hesɗitin, eto.");
 async function req<T>(path:string,body?:Record<string,unknown>,signal?:AbortSignal):Promise<T>{
  const scope=controller.current;const bound=signal??scope?.signal;
  if(!anonKey)throw Error("SESSION_CHANGED");
  return privateRequest<T>(bound,()=>alive.current&&foreground.current&&controller.current===scope,token.current,(jwt,s)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/"+path,{method:body?"POST":"GET",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:body?JSON.stringify(body):undefined,cache:"no-store",credentials:"omit",signal:s}));
 }

 useEffect(()=>{
  alive.current=true;foreground.current=document.visibilityState!=="hidden";const c=new AbortController();controller.current=c;
  let refreshing=false;
  async function refresh(){
   if(c.signal.aborted||!foreground.current||refreshing||!siteId||!rosterModeEnabled(account.business_mode))return;
   refreshing=true;
   try{
    const f="org_id=eq."+encodeURIComponent(account.organization_id);
    const [m,i,t]=await Promise.all([req<Meeting[]>("ns_internal_meetings?select=*&"+f+"&site_id=eq."+encodeURIComponent(siteId)+"&order=scheduled_at.desc&limit=100",undefined,c.signal),req<Invite[]>("ns_internal_meeting_invitees?select=*&"+f+"&limit=2000",undefined,c.signal),req<Target[]>("rpc/ns_roster_targets",{p_org:account.organization_id,p_site:siteId},c.signal)]);
    if(!c.signal.aborted){setMeetings(m);setInvites(i);setTargets(t);setPost(previous=>t.some(x=>(x.workstation_id??'')===previous)?previous:(t[0]?.workstation_id??''));setLoaded(true);setError(false);}
   }catch{if(!c.signal.aborted){setLoaded(false);setError(true);setMeetings([]);setInvites([]);setTargets([]);}}finally{refreshing=false;}
  }
  void refresh();const timer=window.setInterval(()=>{if(document.visibilityState==="visible")void refresh();},20000);
  const visibility=()=>{
   foreground.current=document.visibilityState!=="hidden";
   if(!foreground.current){c.abort();setLoaded(false);setBusy(false);setError(false);setMeetings([]);setInvites([]);setTargets([]);setEdit(null);setTitle("");setAgenda("");setWhen("");setSelected([]);}
   else setRevision(r=>r+1);
  };
  document.addEventListener("visibilitychange",visibility);
  return()=>{alive.current=false;c.abort();window.clearInterval(timer);document.removeEventListener("visibilitychange",visibility);};
 },[account.organization_id,account.member_id,account.business_mode,siteId,authEndpoint,anonKey,revision]);
 const posts=Array.from(new Map(targets.map(t=>[t.workstation_id??"",t.workstation_name??tr("Site entier","Whole site","Nokkuure fof")])).entries());
 const people=targets.filter(t=>(t.workstation_id??"")===post);
 function reset(){setEdit(null);setTitle("");setWhen("");setAgenda("");setDuration("30");setSelected([]);setFrequency("once");setCount("3");pendingCreation.current=null;clearRetry();}
 async function perform(action:()=>Promise<unknown>){
  if(busy||!loaded||!foreground.current)return;const scope=controller.current;const current=()=>alive.current&&foreground.current&&controller.current===scope&&!scope?.signal.aborted;setBusy(true);setError(false);
  try{await action();if(current())setRevision(r=>r+1);}catch{if(current())setError(true);}finally{if(current())setBusy(false);}
 }
 function schedule(){
  if(edit){void perform(async()=>{await req("rpc/ns_revise_meeting_invitees",{p_id:edit.id,p_revision:edit.revision,p_title:title,p_at:iso(when),p_agenda:agenda,p_duration:Number(duration),p_members:[...selected].sort()});reset();});return;}
  if(!selected.length)return;
  void perform(async()=>{
   const fields={p_org:account.organization_id,p_site:siteId,p_post:post||null,p_title:title,p_at:when,p_members:[...selected].sort(),p_agenda:agenda,p_duration:Number(duration),...(frequency==="once"?{}:{p_frequency:frequency,p_count:Number(count)})};
   const signature=JSON.stringify([account.member_id,fields]);
   const digest=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(signature))),x=>x.toString(16).padStart(2,"0")).join("");
   let saved:{digest:string;id:string;at:string}|null=null;
   try{const candidate=JSON.parse(sessionStorage.getItem(retryKey)??"null");if(candidate?.digest===digest&&typeof candidate.id==="string"&&/^[0-9a-f-]{36}$/i.test(candidate.id)&&typeof candidate.at==="string"&&Number.isFinite(Date.parse(candidate.at)))saved=candidate;}catch{/* invalid or unavailable storage */}
   const payload=pendingCreation.current?.signature===signature?pendingCreation.current.payload:{...fields,p_id:saved?.id??crypto.randomUUID(),p_at:saved?.at??(when?iso(when):new Date().toISOString())};
   pendingCreation.current={signature,payload};
   try{sessionStorage.setItem(retryKey,JSON.stringify({digest,id:payload.p_id,at:payload.p_at}));}catch{/* in-memory retry remains available */}
   await req(frequency==="once"?"rpc/ns_schedule_internal_meeting_details":"rpc/ns_schedule_meeting_series",payload);reset();
  });
 }
 function cancelSeries(m:Meeting){
  const expected=meetings.filter(x=>x.series_id===m.series_id&&x.status==="scheduled").map(x=>({id:x.id,revision:x.revision}));
  if(!m.series_id||!expected.length||!window.confirm(tr("Annuler toutes les réunions encore programmées de cette série ?","Cancel all still-scheduled meetings in this series?","Haaytu dentuuji feewnaaɗi ɗii fof?")))return;
  void perform(()=>req("rpc/ns_cancel_meeting_series",{p_id:m.series_id,p_expected:expected}));
 }
 function transition(m:Meeting,next:string){void perform(()=>req("rpc/ns_transition_internal_meeting",{p_id:m.id,p_revision:m.revision,p_next:next}));}
 function status(s:string){return ({scheduled:tr("Programmée","Scheduled","Feewnaama"),open:tr("Ouverte","Open","Udditaama"),closed:tr("Terminée","Ended","Timmi"),cancelled:tr("Annulée","Cancelled","Haaytaama"),pending:tr("En attente","Pending","E fadade"),accepted:tr("Acceptée","Accepted","Jaɓaama"),declined:tr("Refusée","Declined","Salaama"),tentative:tr("Provisoire","Tentative","Haa jooni") } as Record<string,string>)[s]??"—";}
 if(!rosterModeEnabled(account.business_mode)||!siteId)return null;
 return <section className="module-main-card" aria-label={tr("Mes réunions","My meetings","Dentuuji am")}><h2>{tr("Mes réunions","My meetings","Dentuuji am")}</h2>
 <p>{tr("Heure de Douala (UTC+1). L’appel audio/vidéo n’est pas encore disponible.","Douala time (UTC+1). Audio/video calling is not available yet.","Sahaa Duwaala (UTC+1). Noddaango daande e natal heɓotaako tawo.")}</p>
 <button className="btn secondary" disabled={busy} onClick={()=>setRevision(r=>r+1)}>{tr("Actualiser","Refresh","Hesɗitin")}</button>{error&&<p role="alert">{err}</p>}
 {loaded&&(targets.length>0||edit)&&<form onSubmit={e=>{e.preventDefault();schedule();}}>
 <h3>{edit?tr("Modifier la réunion","Edit meeting","Waylu dental"):tr("Programmer une réunion","Schedule meeting","Feewnu dental")}</h3>
 {!edit&&<><label>{tr("Périmètre","Scope","Nokkuure")}<select value={post} onChange={e=>{setPost(e.target.value);setSelected([]);}}>{posts.map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label></>}
 <fieldset><legend>{tr("Invités","Invitees","Noddaaɓe")}</legend>{people.map(t=><label key={t.member_id}><input type="checkbox" checked={selected.includes(t.member_id)} onChange={e=>setSelected(p=>e.target.checked?[...p,t.member_id]:p.filter(x=>x!==t.member_id))}/>{t.display_name}</label>)}</fieldset>
 <label>{tr("Intitulé","Title","Innde")}<input required maxLength={160} value={title} onChange={e=>setTitle(e.target.value)}/></label>
 <label>{tr("Date et heure (vide : maintenant)","Date and time (blank: now)","Ñalnde e sahaa")}<input type="datetime-local" required={Boolean(edit)} value={when} onChange={e=>setWhen(e.target.value)}/></label>
 <><label>{tr("Ordre du jour","Agenda","Feere dental")}<textarea maxLength={2000} value={agenda} onChange={e=>setAgenda(e.target.value)}/></label><label>{tr("Durée (min)","Duration (min)","Sahaa (min)")}<input type="number" min="5" max="480" required value={duration} onChange={e=>setDuration(e.target.value)}/></label></>
 {!edit&&<><label>{tr("Répétition","Repeat","Yaltinde")}<select aria-label={tr("Répétition","Repeat","Yaltinde")} value={frequency} disabled={busy} onChange={e=>setFrequency(e.target.value)}><option value="once">{tr("Une seule fois","Once","Gooto")}</option><option value="daily">{tr("Chaque jour","Daily","Kala ñalnde")}</option><option value="weekly">{tr("Chaque semaine","Weekly","Kala yontere")}</option></select></label>{frequency!=="once"&&<label>{tr("Nombre de réunions","Number of meetings","Limoore dentuuji")}<input aria-label={tr("Nombre de réunions","Number of meetings","Limoore dentuuji")} type="number" required min={2} max={12} value={count} disabled={busy} onChange={e=>setCount(e.target.value)}/></label>}</>}
 <button className="btn primary" disabled={busy||!selected.length}>{edit?tr("Enregistrer et notifier","Save and notify","Danndu e tintin"):tr("Créer et inviter","Create and invite","Sos e noddu")}</button>
 {edit&&<button type="button" className="btn secondary" onClick={reset}>{tr("Abandonner","Discard","Accu")}</button>}</form>}
 {loaded&&!meetings.length&&<p>{tr("Aucune réunion.","No meetings.","Alaa dental.")}</p>}
 {meetings.map(m=>{const host=m.host_member_id===account.member_id,own=invites.find(i=>i.meeting_id===m.id&&i.member_id===account.member_id);return <article key={m.id} className="activity-record">
 <strong>{m.title}</strong><p>{local(m.scheduled_at).replace("T"," ")} · {m.duration_minutes} min · {status(m.status)}</p>{m.agenda&&<p>{m.agenda}</p>}{m.series_occurrence&&<p>{tr("Réunion récurrente","Recurring meeting","Dental yaltindetee")} · {m.series_occurrence}</p>}
 {host&&m.status==="scheduled"&&<><button disabled={busy} className="btn secondary" onClick={()=>{setEdit(m);setPost(m.workstation_id??"");setSelected(invites.filter(i=>i.meeting_id===m.id&&i.member_id!==account.member_id&&targets.some(x=>x.member_id===i.member_id&&(x.workstation_id??"")===(m.workstation_id??""))).map(i=>i.member_id));setTitle(m.title);setWhen(local(m.scheduled_at));setAgenda(m.agenda);setDuration(String(m.duration_minutes));}}>{tr("Modifier","Edit","Waylu")}</button><button disabled={busy} className="btn primary" onClick={()=>transition(m,"open")}>{tr("Ouvrir la réunion (sans appel)","Open meeting (no call)","Uddit dental")}</button><button disabled={busy} className="btn secondary" onClick={()=>transition(m,"cancelled")}>{tr("Annuler","Cancel","Haaytu")}</button>{m.series_id&&<button disabled={busy} className="btn secondary" onClick={()=>cancelSeries(m)}>{tr("Annuler la série","Cancel series","Haaytu dentuuji")}</button>}</>}
 {host&&m.status==="open"&&<button disabled={busy} className="btn secondary" onClick={()=>transition(m,"closed")}>{tr("Terminer","End","Timmin")}</button>}
 {!host&&own&&m.status==="scheduled"&&<><p>{status(own.response)}</p>{["accepted","declined","tentative"].map(r=><button key={r} className="btn secondary" disabled={busy} onClick={()=>void perform(()=>req("rpc/ns_respond_meeting_invitation",{p_id:m.id,p_revision:m.revision,p_response:r}))}>{status(r)}</button>)}</>}
 {host&&<p>{tr("Invités","Invitees","Noddaaɓe")}: {invites.filter(i=>i.meeting_id===m.id&&i.member_id!==account.member_id).map(i=>(targets.find(t=>t.member_id===i.member_id)?.display_name??tr("Participant","Participant","Jeyaaɗo"))+" : "+status(i.response)).join(" · ")}</p>}
 {own&&["scheduled","open"].includes(m.status)&&<><label>{tr("Langue d’écoute souhaitée","Preferred listening language","Ɗemngal heɗagol")}<select disabled={busy} value={own.listening_locale} onChange={e=>void perform(()=>req("rpc/ns_set_meeting_listener",{p_id:m.id,p_locale:e.target.value,p_consent:null}))}>{langs.map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
 <p>{tr("Consentement à un futur enregistrement audio","Consent to future audio recording","Jaɓgol nanndugol daande")} : {own.recording_consent===null?"—":own.recording_consent?tr("Oui","Yes","Eey"):tr("Non","No","Alaa")}</p>
 {[true,false].map(v=><button key={String(v)} className="btn secondary" disabled={busy} onClick={()=>void perform(()=>req("rpc/ns_set_meeting_listener",{p_id:m.id,p_locale:own.listening_locale,p_consent:v}))}>{v?tr("J’accepte","I consent","Mi jaɓii"):tr("Je refuse","I decline","Mi salii")}</button>)}</>}
 {m.status==="open"&&own&&own.response!=="declined"&&<MeetingCollaboration key={account.member_id+":"+m.id} account={account} meetingId={m.id} host={host} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken} onUnavailable={()=>setRevision(r=>r+1)}/>}
 </article>;})}</section>;
}
