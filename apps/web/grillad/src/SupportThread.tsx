import {GrilladCall} from './GrilladCall';
import React,{useEffect,useRef,useState} from 'react';
type ThreadProps={ticket:string;request:(b:any)=>Promise<any>;disabled:boolean};
// A pending request and draft belong to exactly one ticket; never reuse them on navigation.
export function SupportThread(props:ThreadProps){return <TicketThread key={props.ticket} {...props}/>}
function TicketThread({ticket,request,disabled}:ThreadProps){
 const [data,D]=useState<any>(null),[body,B]=useState(''),[notice,N]=useState(''),[busy,S]=useState(false);const pending=useRef<any>(null),lock=useRef(false),alive=useRef(true);
 async function read(){if(lock.current||blocked.current)return;lock.current=true;try{const d=await latest.current({action:'support_thread',ticket});if(alive.current&&!blocked.current){D(d);N('')}}catch{if(alive.current)N('Conversation indisponible.')}finally{lock.current=false}}
 const blocked=useRef(disabled),latest=useRef(request);blocked.current=disabled;latest.current=request;
 useEffect(()=>{alive.current=true;return()=>{alive.current=false}},[]);
 useEffect(()=>{if(disabled)return;void read();const timer=setInterval(()=>{if(document.visibilityState==='visible')void read()},5000);return()=>clearInterval(timer)},[disabled]);
 async function send(e:React.FormEvent){e.preventDefault();if(lock.current||disabled||!body.trim())return;lock.current=true;S(true);const p=pending.current??{action:'support_thread',ticket,event:crypto.randomUUID(),message:body.trim()};pending.current=p;try{const d=await request(p);if(alive.current){D(d);B('');N('')}pending.current=null}catch{if(alive.current)N('Envoi non confirmé : réessayez le même message.')}finally{lock.current=false;if(alive.current)S(false)}}
 return <article><h2>Conversation assistance</h2><p>{data?.description}</p>{(data?.messages??[]).map((m:any)=><p key={m.id}><strong>{m.author_kind==='agent'?'Agent NAXA':'Vous'}</strong> · {m.body}</p>)}<button disabled={busy||disabled} onClick={()=>void read()}>Actualiser la conversation</button><form onSubmit={send}><textarea aria-label="Message assistance" maxLength={2000} value={body} disabled={busy||!!pending.current} onChange={e=>B(e.target.value)}/><button disabled={busy||disabled||!body.trim()}>{pending.current?'Réessayer':'Envoyer le message'}</button></form>{notice&&<p role="status">{notice}</p>}<GrilladCall key={ticket} disabled={disabled} request={(operation,sdp,screen)=>request({action:'support_call',ticket,operation,sdp,screen})}/></article>
}
