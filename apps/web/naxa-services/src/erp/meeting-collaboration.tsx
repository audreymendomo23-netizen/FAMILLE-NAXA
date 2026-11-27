import React,{useEffect,useRef,useState} from "react";
import {privateRequest} from "./private-request";
import type {WebAuthAccount} from "../auth/session";
import {rosterApiOrigin} from "./staff-roster";
type Participant={member_id:string;display_name:string;hand_raised_at:string|null;screen_allowed:boolean;chat_allowed:boolean;mic_muted_by_host:boolean};
type Chat={id:string;member_id:string;message:string;created_at:string};
type Reaction={id:string;member_id:string;reaction:string};
type Recording={id:string;status:string;display_name:string};
type Props={account:WebAuthAccount;meetingId:string;host:boolean;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>;onUnavailable:()=>void};
const reactions:Record<string,string>={like:"👍",clap:"👏",heart:"❤️",laugh:"😄",agree:"✅",celebrate:"🎉"};
export function MeetingCollaboration({account,meetingId,host,authEndpoint,anonKey,getToken,onUnavailable}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const [people,setPeople]=useState<Participant[]>([]),[chat,setChat]=useState<Chat[]>([]),[recent,setRecent]=useState<Reaction[]>([]);
 const [recordings,setRecordings]=useState<Recording[]>([]);
 const [text,setText]=useState(""),[busy,setBusy]=useState(false),[ready,setReady]=useState(false),[error,setError]=useState(false);
 const token=useRef(getToken);token.current=getToken;const unavailable=useRef(onUnavailable);unavailable.current=onUnavailable;
 const active=useRef(false),controller=useRef<AbortController|null>(null),running=useRef(false),writing=useRef(false);
 async function req<T>(path:string,body?:Record<string,unknown>):Promise<T>{
  const scope=controller.current;
  if(!anonKey)throw Error("SESSION_CHANGED");
  return privateRequest<T>(scope?.signal,()=>active.current&&controller.current===scope,token.current,(jwt,s)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/"+path,{method:body?"POST":"GET",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:body?JSON.stringify(body):undefined,cache:"no-store",credentials:"omit",signal:s}));
 }

 async function refresh(){
  const scope=controller.current;
  if(running.current||!active.current||!scope||scope.signal.aborted)return;running.current=true;
  try{
   const filter="meeting_id=eq."+encodeURIComponent(meetingId);
   const [p,c,r,rec]=await Promise.all([req<Participant[]>("rpc/ns_meeting_participants",{p_id:meetingId}),req<Chat[]>("ns_meeting_chat?select=id,member_id,message,created_at&"+filter+"&order=created_at.desc,id.desc&limit=100"),req<Reaction[]>("ns_meeting_reactions?select=id,member_id,reaction&"+filter+"&order=created_at.desc&limit=20"),req<Recording[]>("ns_meeting_recording_requests?select=id,status,display_name&"+filter+"&order=requested_at.desc&limit=20")]);
   if(!active.current||scope.signal.aborted||controller.current!==scope)return;
   if(!p.some(x=>x.member_id===account.member_id)){setPeople([]);setChat([]);setRecent([]);setRecordings([]);setReady(false);unavailable.current();return;}
   setPeople(p);setChat(c.reverse());setRecent(r);setRecordings(rec);setReady(true);setError(false);
  }catch{if(active.current&&controller.current===scope&&!scope.signal.aborted){setReady(false);setPeople([]);setChat([]);setRecent([]);setRecordings([]);setError(true);}}finally{running.current=false;}
 }
 useEffect(()=>{active.current=true;controller.current=new AbortController();void refresh();const id=window.setInterval(()=>{if(document.visibilityState==="visible")void refresh();},3000);return()=>{active.current=false;controller.current?.abort();window.clearInterval(id);};},[meetingId,account.member_id,authEndpoint,anonKey]);
 async function act(action:string,value:string|null=null,target?:string){
  if(writing.current||!ready)return;writing.current=true;setBusy(true);
  try{await req(target?"rpc/ns_moderate_meeting":"rpc/ns_meeting_action",target?{p_id:meetingId,p_event:crypto.randomUUID(),p_target:target,p_action:action}:{p_id:meetingId,p_event:crypto.randomUUID(),p_action:action,p_value:value});if(active.current){if(action==="chat"&&!target)setText("");await refresh();}}catch{if(active.current)setError(true);}finally{writing.current=false;if(active.current)setBusy(false);}
 }
 async function requestRecording(id:string,action:"start"|"stop"){
  if(writing.current||!ready||!host)return;writing.current=true;setBusy(true);
  try{await req("rpc/ns_request_meeting_recording",{p_id:meetingId,p_request:id,p_action:action});await refresh();}catch{if(active.current)setError(true);}finally{writing.current=false;if(active.current)setBusy(false);}
 }
 const currentRecording=recordings.find(r=>["requested","recording","stop_requested"].includes(r.status));
 const own=people.find(p=>p.member_id===account.member_id);
 const name=(id:string)=>people.find(p=>p.member_id===id)?.display_name??tr("Participant","Participant","Jeyaaɗo");
 return <section className="module-main-card"><h3>{tr("Échanges de réunion","Meeting discussion","Jeewte dental")}</h3>
 <p>{tr("Actualisation toutes les 3 secondes. Les commandes micro/écran sont des autorisations, pas un contrôle audio/vidéo actif.","Refresh every 3 seconds. Mic/screen settings are permissions, not active media controls.","Hesɗitinal kala 3 seconde. Yamirooje daande e ekran tan, wonaa noddaango.")}</p>
 {error&&<p role="alert">{tr("Échanges indisponibles.","Discussion unavailable.","Jeewte heɓotaake.")}</p>}
 {ready&&own&&<><button className="btn secondary" disabled={busy} onClick={()=>void act(own.hand_raised_at?"lower_hand":"raise_hand")}>{own.hand_raised_at?tr("Baisser la main","Lower hand","Lesɗin junngo"):tr("Lever la main","Raise hand","Ɓamtu junngo")}</button>
 <div>{Object.entries(reactions).map(([k,v])=><button key={k} aria-label={k} className="btn secondary" disabled={busy} onClick={()=>void act("reaction",k)}>{v}</button>)}</div>
 <p>{recent.map(r=>reactions[r.reaction]).join(" ")}</p>
 <h4>{tr("Enregistrement audio","Audio recording","Nanndugol daande")}</h4>
 <p>{tr("Le moteur audio est indisponible. Une demande ne constitue pas un enregistrement.","Audio engine unavailable. A request is not a recording.","Masiŋ daande heɓotaako. Ɗaɓɓitannde wonaa nanndugol.")}</p>
 {currentRecording&&<p>{currentRecording.display_name} · {currentRecording.status==="requested"?tr("Demande en attente","Pending request","Ɗaɓɓitannde e fadade"):tr("Vérification nécessaire","Verification required","Ƴeewtagol ena sokli")}</p>}
 {host&&<button className="btn secondary" disabled={busy||currentRecording?.status==="stop_requested"} onClick={()=>void requestRecording(currentRecording?.id??crypto.randomUUID(),currentRecording?"stop":"start")}>{currentRecording?tr("Annuler la demande","Cancel request","Haaytu ɗaɓɓitannde"):tr("Demander l’enregistrement (sans capture)","Request recording (no capture)","Ɗaɓɓu nanndugol")}</button>}
 <h4>{tr("Participants invités habilités","Authorized invitees","Noddaaɓe yamiraaɓe")}</h4>
 {people.map(p=><div key={p.member_id}><strong>{p.display_name}</strong>{p.hand_raised_at&&" ✋"}{host&&p.member_id!==account.member_id&&<div>
 {[[p.mic_muted_by_host?"allow_mic":"mute",p.mic_muted_by_host?tr("Autoriser micro","Allow mic","Yamir daande"):tr("Restreindre micro","Restrict mic","Haɗ daande")],[p.screen_allowed?"deny_screen":"allow_screen",p.screen_allowed?tr("Retirer partage","Remove sharing","Haɗ ekran"):tr("Autoriser partage","Allow sharing","Yamir ekran")],[p.chat_allowed?"deny_chat":"allow_chat",p.chat_allowed?tr("Restreindre chat","Restrict chat","Haɗ jeewte"):tr("Autoriser chat","Allow chat","Yamir jeewte")],["lower_hand",tr("Baisser main","Lower hand","Lesɗin junngo")],["exclude",tr("Exclure","Exclude","Ittu")]].map(([action,label])=><button key={action} disabled={busy} className="btn secondary" onClick={()=>{if(action==="exclude"&&!window.confirm(tr("Retirer l’accès à cette réunion ?","Remove access to this meeting?","Ittu jamiroore dental?")))return;void act(action,null,p.member_id);}}>{label}</button>)}</div>}</div>)}
 <h4>{tr("Discussion","Chat","Jeewte")}</h4><div aria-live="polite">{chat.map(c=><p key={c.id}><strong>{name(c.member_id)} : </strong>{c.message}</p>)}</div>
 {own.chat_allowed&&<form onSubmit={e=>{e.preventDefault();if(text.trim())void act("chat",text);}}><textarea aria-label={tr("Message","Message","Ɓatakuru")} maxLength={2000} value={text} onChange={e=>setText(e.target.value)}/><button className="btn primary" disabled={busy||!text.trim()}>{tr("Envoyer","Send","Neldu")}</button></form>}</>}
 </section>;
}
