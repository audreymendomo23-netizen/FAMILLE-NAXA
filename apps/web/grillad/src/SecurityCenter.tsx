import {GrilladWhepPlayer} from './GrilladWhepPlayer';
import React,{useState,useEffect} from 'react';
import {cameraPage} from './security-center.mjs';
const label=(s:string)=>({online:'En ligne',offline:'Hors ligne',unknown:'État inconnu'} as Record<string,string>)[s]??'État inconnu';
export function SecurityCenter({security,request}:{security:any;request:(body:any)=>Promise<any>}){
 const [page,P]=useState(0),[selected,S]=useState('');const cams=security?.available&&Array.isArray(security.cameras)?security.cameras:[];const p=cameraPage(cams,page);const current=cams.find((c:any)=>c.id===selected);useEffect(()=>{if(selected&&!current)S('')},[selected,current]);
 return <section><h2>Centre de surveillance</h2><p>{security?.available?'Site lié à NAXA SECURITY.':'Aucune liaison autorisée.'} Le direct nécessite une autorisation vidéo délivrée par le relais. Aucun faux flux.</p>
 <div style={{display:'grid',gridTemplateColumns:'repeat(2,minmax(0,1fr))',gap:8}}>{p.slots.map((c:any,i:number)=><article key={c?.id??'empty'+i} style={{minHeight:110}}>{c?<button className="quiet" onClick={()=>S(c.id)}><strong>{c.name}</strong><p>{label(c.status)}</p><small>Inventaire · aucun flux ouvert</small></button>:<p>Emplacement libre</p>}</article>)}</div><p>Page {p.index+1} / {p.pages}</p><button disabled={p.index===0} onClick={()=>P(p.index-1)}>Précédent</button><button disabled={p.index+1>=p.pages} onClick={()=>P(p.index+1)}>Suivant</button>
 {current&&<article><h3>{current.name}</h3><p>{label(current.status)} · {current.observed_at}</p>{security?.live_request_available&&current.status==='online'?<GrilladWhepPlayer key={current.id} cameraId={current.id} request={request}/>:<p>Vidéo en direct indisponible sans session autorisée du relais.</p>}<button onClick={()=>S('')}>Fermer le détail</button></article>}
 <h2>Incidents</h2>{(security?.available?security.incidents??[]:[]).map((i:any)=><article key={i.id}>{i.category} · {i.observed_at}</article>)}</section>
}
