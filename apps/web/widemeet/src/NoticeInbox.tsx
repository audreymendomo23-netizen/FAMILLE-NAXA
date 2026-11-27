import React,{useEffect,useState}from"react";
import{roomRequest}from"./room-api.mjs";
export function NoticeInbox({base,session,locale,onOpen}){
 const tr=(fr,en)=>locale==="en"?en:fr;const [items,S]=useState([]),[busy,B]=useState(false),[error,E]=useState(false);
 const labels={invitation:tr("Invitation","Invitation"),meeting_reminder:tr("Rappel de réunion","Meeting reminder"),minutes_published:tr("Compte rendu publié","Minutes published"),task_assigned:tr("Tâche attribuée","Task assigned"),task_overdue:tr("Tâche en retard","Overdue task"),task_review:tr("Tâche à valider","Task to review"),task_done:tr("Tâche validée","Task approved"),subscription_expiring:tr("Abonnement bientôt expiré","Subscription expiring")};
 const req=body=>roomRequest(base,"notices",body,session.access_token);
 async function refresh(){B(true);E(false);try{const d=await req({});S(d.items)}catch{S([]);E(true)}finally{B(false)}}
 useEffect(()=>{void refresh()},[]);
 async function read(x,open){B(true);E(false);try{await req({read:x.k});if(open)onOpen(x.kind);else S(old=>old.map(v=>v.k===x.k?{...v,read_at:new Date().toISOString()}:v))}catch{S([]);E(true)}finally{B(false)}}
 return <section className="card" style={{display:"grid",gap:8}}><h2>{tr("Notifications","Notifications")}</h2><button disabled={busy} onClick={refresh}>{tr("Actualiser","Refresh")}</button>{error&&<p role="alert">{tr("Notifications indisponibles.","Notifications unavailable.")}</p>}{!busy&&!error&&!items.length&&<p>{tr("Aucune notification.","No notifications.")}</p>}{items.map(x=><div key={x.k}><strong>{labels[x.kind]??tr("Notification","Notification")}{!x.read_at?" · "+tr("Nouveau","New"):""}</strong><p>{x.title??""} · {new Date(x.due).toLocaleString(locale,{timeZone:"Africa/Douala"})}</p><button disabled={busy} onClick={()=>read(x,true)}>{tr("Ouvrir","Open")}</button>{!x.read_at&&<button disabled={busy} onClick={()=>read(x,false)}>{tr("Marquer comme lu","Mark as read")}</button>}</div>)}</section>
}
