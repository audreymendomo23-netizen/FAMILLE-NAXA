import React,{useState,useEffect,useRef} from "react";
import {identityAction} from "./session.mjs";
export function CompanyFeed({base,session,locale}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [kind,K]=useState("news"),[data,D]=useState(null),[body,B]=useState(""),[busy,W]=useState(false),[error,E]=useState(false);
 const pending=useRef(null),serial=useRef(0),lock=useRef(false);
 const req=(name,payload)=>identityAction(base,session,"center-company-"+name,payload);
 async function load(k,token){const v=await req("list",{kind:k});if(serial.current===token)D(v);}
 async function work(fn){if(lock.current)return;lock.current=true;const token=++serial.current;W(true);E(false);try{await fn(token)}catch{if(serial.current===token){D(null);E(true)}}finally{if(serial.current===token)W(false);lock.current=false}}
 useEffect(()=>{D(null);void work(t=>load(kind,t));return()=>{serial.current++;lock.current=false}},[kind,session.device_id]);
 async function publish(t){const p=pending.current??{id:crypto.randomUUID(),kind,body:body.trim()};pending.current=p;await req("publish",p);pending.current=null;B("");await load(kind,t);}
 return <section aria-label={tr("Mon entreprise","My company")} style={{display:"grid",gap:12}}><h1>{tr("Mon entreprise","My company")}</h1>
 <div role="group" aria-label={tr("Rubriques","Sections")} style={{display:"flex",gap:12,borderBottom:"1px solid currentColor"}}>{[["news",tr("Actualités","News")],["announcement",tr("Annonces","Announcements")]].map(([k,label])=><button type="button" key={k} aria-pressed={kind===k} disabled={busy||!!pending.current} onClick={()=>{B("");K(k)}}>{label}</button>)}</div>
 {busy&&<p role="status">{tr("Chargement…","Loading…")}</p>}{error&&<p role="alert">{tr("Action non confirmée. Réessayez.","Action not confirmed. Try again.")}</p>}
 <button disabled={busy} onClick={()=>work(t=>load(kind,t))}>{tr("Actualiser","Refresh")}</button>
 {(data?.can_publish||pending.current)&&<form onSubmit={e=>{e.preventDefault();void work(publish)}} style={{display:"grid",gap:8}}><label>{kind==="news"?tr("Votre actualité","Your update"):tr("Votre annonce","Your announcement")}<textarea required maxLength={4000} disabled={busy||!!pending.current} value={body} onChange={e=>B(e.target.value)}/></label><button disabled={busy||(!body.trim()&&!pending.current)}>{pending.current?tr("Réessayer la publication","Retry publication"):tr("Publier","Publish")}</button></form>}
 {data?.items?.length===0&&<p>{kind==="news"?tr("Aucune actualité pour le moment.","No updates yet."):tr("Aucune annonce pour le moment.","No announcements yet.")}</p>}
 {(data?.items??[]).map(p=><article key={p.id} style={{padding:"12px 0",borderBottom:"1px solid var(--wm-line)"}}><strong>{p.display_name}</strong>{p.job_title&&<p>{p.job_title}</p>}<small>{new Date(p.created_at).toLocaleString(locale)}</small><p style={{whiteSpace:"pre-wrap",overflowWrap:"anywhere"}}>{p.body}</p>
 {p.can_confirm&&(p.confirmed?<p>{tr("Lecture confirmée","Reading confirmed")}</p>:<button disabled={busy} onClick={()=>work(async t=>{await req("confirm",{id:p.id});await load(kind,t)})}>{tr("Confirmer la lecture","Confirm reading")}</button>)}
 {Number.isSafeInteger(p.confirmation_count)&&<p>{tr("Lectures confirmées","Confirmed readings")}: {p.confirmation_count}</p>}
 {p.can_remove&&<button disabled={busy} onClick={()=>{if(confirm(tr("Retirer cette publication ?","Remove this post?")))void work(async t=>{await req("remove",{id:p.id});await load(kind,t)})}}>{tr("Retirer","Remove")}</button>}</article>)}</section>
}
