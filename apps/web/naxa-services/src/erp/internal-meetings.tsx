import React,{useEffect,useRef,useState} from "react";
import type {WebAuthAccount} from "../auth/session";
import {rosterApiOrigin,rosterModeEnabled} from "./staff-roster";
type Target={member_id:string;display_name:string;workstation_id:string|null;workstation_name:string|null};
type Meeting={id:string;title:string;scheduled_at:string;status:string;revision:number;host_member_id:string;agenda:string;duration_minutes:number;site_id:string;workstation_id:string|null};
type Invite={meeting_id:string;member_id:string;listening_locale:string;recording_consent:boolean|null;response:string};
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
const langs=[["original","Original"],["fr","Français"],["en","English"],["ff-CM","Fulfulde"],["es","Español"],["it","Italiano"],["zh-CN","中文"]];
const local=(s:string)=>new Date(Date.parse(s)+3600000).toISOString().slice(0,16);
const iso=(s:string)=>new Date(s+":00+01:00").toISOString();
export function InternalMeetings({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const [meetings,setMeetings]=useState<Meeting[]>([]),[invites,setInvites]=useState<Invite[]>([]),[targets,setTargets]=useState<Target[]>([]);
 const [selected,setSelected]=useState<string[]>([]),[post,setPost]=useState(""),[title,setTitle]=useState(""),[when,setWhen]=useState(""),[agenda,setAgenda]=useState(""),[duration,setDuration]=useState("30"),[edit,setEdit]=useState<Meeting|null>(null);
 const [busy,setBusy]=useState(false),[error,setError]=useState(false),[loaded,setLoaded]=useState(false),[revision,setRevision]=useState(0);
 const token=useRef(getToken);token.current=getToken;const alive=useRef(false),controller=useRef<AbortController|null>(null);
 const err=tr("Réunion ou modification indisponible. Actualisez et réessayez.","Meeting or change unavailable. Refresh and retry.","Dental walla baylugol heɓotaako. Hesɗitin, eto.");
 async function req<T>(path:string,body?:Record<string,unknown>,signal?:AbortSignal):Promise<T>{
  const jwt=await token.current();if(!alive.current||signal?.aborted||!jwt||!anonKey)throw Error("SESSION_CHANGED");
  const response=await fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/"+path,{method:body?"POST":"GET",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:body?JSON.stringify(body):undefined,cache:"no-store",credentials:"omit",signal});
  if(!response.ok)throw Error("MEETING_REQUEST_FAILED");return await response.json() as T;
 }
 useEffect(()=>{
  alive.current=true;const c=new AbortController();controller.current=c;
  let refreshing=false;
  async function refresh(){
   if(refreshing||!siteId||!rosterModeEnabled(account.business_mode))return;
   refreshing=true;
   try{
    const f="org_id=eq."+encodeURIComponent(account.organization_id);
    const [m,i,t]=await Promise.all([req<Meeting[]>("ns_internal_meetings?select=*&"+f+"&site_id=eq."+encodeURIComponent(siteId)+"&order=scheduled_at.desc&limit=100",undefined,c.signal),req<Invite[]>("ns_internal_meeting_invitees?select=*&"+f+"&limit=2000",undefined,c.signal),req<Target[]>("rpc/ns_roster_targets",{p_org:account.organization_id,p_site:siteId},c.signal)]);
    if(!c.signal.aborted){setMeetings(m);setInvites(i);setTargets(t);setLoaded(true);setError(false);}
   }catch{if(!c.signal.aborted){setLoaded(false);setError(true);setMeetings([]);setInvites([]);setTargets([]);}}finally{refreshing=false;}
  }
  void refresh();const timer=window.setInterval(()=>{if(document.visibilityState==="visible")void refresh();},20000);
  return()=>{alive.current=false;c.abort();window.clearInterval(timer);};
 },[account.organization_id,account.member_id,account.business_mode,siteId,authEndpoint,anonKey,revision]);
 const posts=Array.from(new Map(targets.map(t=>[t.workstation_id??"",t.workstation_name??tr("Site entier","Whole site","Nokkuure fof")])).entries());
 const people=targets.filter(t=>(t.workstation_id??"")===post);
 function reset(){setEdit(null);setTitle("");setWhen("");setAgenda("");setDuration("30");setSelected([]);}
 async function perform(action:()=>Promise<unknown>){
  if(busy||!loaded)return;setBusy(true);setError(false);
  try{await action();if(alive.current)setRevision(r=>r+1);}catch{if(alive.current)setError(true);}finally{if(alive.current)setBusy(false);}
 }
 function schedule(){
  if(edit){void perform(async()=>{await req("rpc/ns_revise_internal_meeting",{p_id:edit.id,p_revision:edit.revision,p_title:title,p_at:iso(when),p_agenda:agenda,p_duration:Number(duration)});reset();});return;}
  if(!selected.length)return;
  void perform(async()=>{await req("rpc/ns_schedule_internal_meeting",{p_id:crypto.randomUUID(),p_org:account.organization_id,p_site:siteId,p_post:post||null,p_title:title,p_at:when?iso(when):new Date().toISOString(),p_members:selected});reset();});
 }
 function transition(m:Meeting,next:string){void perform(()=>req("rpc/ns_transition_internal_meeting",{p_id:m.id,p_revision:m.revision,p_next:next}));}
 function status(s:string){return ({scheduled:tr("Programmée","Scheduled","Feewnaama"),open:tr("Ouverte","Open","Udditaama"),closed:tr("Terminée","Ended","Timmi"),cancelled:tr("Annulée","Cancelled","Haaytaama"),pending:tr("En attente","Pending","E fadade"),accepted:tr("Acceptée","Accepted","Jaɓaama"),declined:tr("Refusée","Declined","Salaama"),tentative:tr("Provisoire","Tentative","Haa jooni") } as Record<string,string>)[s]??"—";}
 if(!rosterModeEnabled(account.business_mode)||!siteId)return null;
 return <section className="module-main-card"><h2>{tr("Mes réunions","My meetings","Dentuuji am")}</h2>
 <p>{tr("Heure de Douala (UTC+1). L’appel audio/vidéo n’est pas encore disponible.","Douala time (UTC+1). Audio/video calling is not available yet.","Sahaa Duwaala (UTC+1). Noddaango daande e natal heɓotaako tawo.")}</p>
 <button className="btn secondary" disabled={busy} onClick={()=>setRevision(r=>r+1)}>{tr("Actualiser","Refresh","Hesɗitin")}</button>{error&&<p role="alert">{err}</p>}
 {loaded&&(targets.length>0||edit)&&<form onSubmit={e=>{e.preventDefault();schedule();}}>
 <h3>{edit?tr("Modifier la réunion","Edit meeting","Waylu dental"):tr("Programmer une réunion","Schedule meeting","Feewnu dental")}</h3>
 {!edit&&<><label>{tr("Périmètre","Scope","Nokkuure")}<select value={post} onChange={e=>{setPost(e.target.value);setSelected([]);}}>{posts.map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
 <fieldset><legend>{tr("Invités","Invitees","Noddaaɓe")}</legend>{people.map(t=><label key={t.member_id}><input type="checkbox" checked={selected.includes(t.member_id)} onChange={e=>setSelected(p=>e.target.checked?[...p,t.member_id]:p.filter(x=>x!==t.member_id))}/>{t.display_name}</label>)}</fieldset></>}
 <label>{tr("Intitulé","Title","Innde")}<input required maxLength={160} value={title} onChange={e=>setTitle(e.target.value)}/></label>
 <label>{tr("Date et heure (vide : maintenant)","Date and time (blank: now)","Ñalnde e sahaa")}<input type="datetime-local" required={Boolean(edit)} value={when} onChange={e=>setWhen(e.target.value)}/></label>
 {edit&&<><label>{tr("Ordre du jour","Agenda","Feere dental")}<textarea maxLength={2000} value={agenda} onChange={e=>setAgenda(e.target.value)}/></label><label>{tr("Durée (min)","Duration (min)","Sahaa (min)")}<input type="number" min="5" max="480" required value={duration} onChange={e=>setDuration(e.target.value)}/></label></>}
 <button className="btn primary" disabled={busy||(!edit&&!selected.length)}>{edit?tr("Enregistrer et notifier","Save and notify","Danndu e tintin"):tr("Créer et inviter","Create and invite","Sos e noddu")}</button>
 {edit&&<button type="button" className="btn secondary" onClick={reset}>{tr("Abandonner","Discard","Accu")}</button>}</form>}
 {loaded&&!meetings.length&&<p>{tr("Aucune réunion.","No meetings.","Alaa dental.")}</p>}
 {meetings.map(m=>{const host=m.host_member_id===account.member_id,own=invites.find(i=>i.meeting_id===m.id&&i.member_id===account.member_id);return <article key={m.id} className="activity-record">
 <strong>{m.title}</strong><p>{local(m.scheduled_at).replace("T"," ")} · {m.duration_minutes} min · {status(m.status)}</p>{m.agenda&&<p>{m.agenda}</p>}
 {host&&m.status==="scheduled"&&<><button disabled={busy} className="btn secondary" onClick={()=>{setEdit(m);setTitle(m.title);setWhen(local(m.scheduled_at));setAgenda(m.agenda);setDuration(String(m.duration_minutes));}}>{tr("Modifier","Edit","Waylu")}</button><button disabled={busy} className="btn primary" onClick={()=>transition(m,"open")}>{tr("Ouvrir la réunion (sans appel)","Open meeting (no call)","Uddit dental")}</button><button disabled={busy} className="btn secondary" onClick={()=>transition(m,"cancelled")}>{tr("Annuler","Cancel","Haaytu")}</button></>}
 {host&&m.status==="open"&&<button disabled={busy} className="btn secondary" onClick={()=>transition(m,"closed")}>{tr("Terminer","End","Timmin")}</button>}
 {!host&&own&&m.status==="scheduled"&&<><p>{status(own.response)}</p>{["accepted","declined","tentative"].map(r=><button key={r} className="btn secondary" disabled={busy} onClick={()=>void perform(()=>req("rpc/ns_respond_meeting_invitation",{p_id:m.id,p_revision:m.revision,p_response:r}))}>{status(r)}</button>)}</>}
 {host&&<p>{tr("Invités","Invitees","Noddaaɓe")}: {invites.filter(i=>i.meeting_id===m.id&&i.member_id!==account.member_id).map(i=>(targets.find(t=>t.member_id===i.member_id)?.display_name??tr("Participant","Participant","Jeyaaɗo"))+" : "+status(i.response)).join(" · ")}</p>}
 {own&&["scheduled","open"].includes(m.status)&&<><label>{tr("Langue d’écoute souhaitée","Preferred listening language","Ɗemngal heɗagol")}<select disabled={busy} value={own.listening_locale} onChange={e=>void perform(()=>req("rpc/ns_set_meeting_listener",{p_id:m.id,p_locale:e.target.value,p_consent:null}))}>{langs.map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
 <p>{tr("Consentement à un futur enregistrement audio","Consent to future audio recording","Jaɓgol nanndugol daande")} : {own.recording_consent===null?"—":own.recording_consent?tr("Oui","Yes","Eey"):tr("Non","No","Alaa")}</p>
 {[true,false].map(v=><button key={String(v)} className="btn secondary" disabled={busy} onClick={()=>void perform(()=>req("rpc/ns_set_meeting_listener",{p_id:m.id,p_locale:own.listening_locale,p_consent:v}))}>{v?tr("J’accepte","I consent","Mi jaɓii"):tr("Je refuse","I decline","Mi salii")}</button>)}</>}
 </article>;})}</section>;
}
