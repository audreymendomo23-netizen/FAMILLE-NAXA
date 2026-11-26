import React,{useEffect,useState} from "react";
import {timerView} from "../../../../packages/widemeet-domain/meeting-clock.mjs";
// Adapter for future authenticated live room. Server snapshot and monotonic anchor required; no fake session.
export function MeetingDeadlineCard({meeting,actor,serverNowMs,anchorMonotonicMs,online,pending,locale="fr",onExtend}){
 const [tick,setTick]=useState(()=>performance.now()),[custom,setCustom]=useState(false),[input,setInput]=useState("");
 useEffect(()=>{setTick(performance.now());const t=setInterval(()=>setTick(performance.now()),250);return()=>clearInterval(t)},[meeting.id,meeting.endMs,serverNowMs,anchorMonotonicMs]);
 const now=serverNowMs+Math.max(0,Math.floor(tick-anchorMonotonicMs));const v=timerView(meeting,now,actor);
 if(!v.warning)return null;
 const tr=(fr,en)=>locale==="en"?en:fr;
 const enabled=v.canExtend&&online&&!pending, max=Math.min(480,Math.floor((meeting.hardEndMs-meeting.endMs)/60000)),n=Number(input);
 const send=minutes=>{if(enabled&&Number.isInteger(minutes)&&minutes>=1&&minutes<=max)onExtend(minutes)};
 return <section className="card" aria-label={tr("Fin de réunion","Meeting deadline")}>
 <h2>{tr("Fin de la réunion dans","Meeting ends in")}</h2>
 <output role="timer" aria-live="off" style={{fontSize:"2rem",fontVariantNumeric:"tabular-nums"}}>{String(Math.floor(v.seconds/60)).padStart(2,"0")}:{String(v.seconds%60).padStart(2,"0")}</output>
 <p>{tr("Prolonger la session","Extend the session")}</p>
 <div style={{display:"flex",gap:8,flexWrap:"wrap"}}>{[15,30,60].map(m=><button key={m} disabled={!enabled||m>max} onClick={()=>send(m)}>{m===60?"+1 h":"+"+m+" min"}</button>)}<button disabled={!enabled||max<1} onClick={()=>setCustom(!custom)}>{tr("Configurer","Custom")}</button></div>
 {custom&&<form onSubmit={e=>{e.preventDefault();send(n);setCustom(false);setInput("")}}><label>{tr("Minutes supplémentaires","Additional minutes")} <input type="number" min={1} max={max} step={1} value={input} onChange={e=>setInput(e.target.value)} required/></label><button disabled={!enabled||!Number.isInteger(n)||n<1||n>max}>{tr("Prolonger","Extend")}</button></form>}
 {!online?<p>{tr("Connexion requise","Connection required")}</p>:pending?<p>{tr("Confirmation en cours","Awaiting confirmation")}</p>:max<1?<p>{tr("Limite de durée atteinte","Duration limit reached")}</p>:null}
 </section>
}
