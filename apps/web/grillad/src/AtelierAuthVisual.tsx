import React,{useEffect,useState} from 'react';
const photos=[{src:'/photos/atelier-braise.jpg',width:516,height:387},{src:'/photos/atelier-service.jpg',width:597,height:452},{src:'/photos/atelier-table.jpg',width:495,height:495}];
const copy={fr:['Mettre en pause les photos','Reprendre les photos'],en:['Pause photos','Resume photos'],'ff-CM':['Dartin nate','Jokku nate']} as const;
export function AtelierAuthVisual({locale,subtitle}:{locale:string;subtitle:string}){
 const [index,setIndex]=useState(0),[paused,setPaused]=useState(false),[reduced,setReduced]=useState(()=>typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches),[visible,setVisible]=useState(()=>document.visibilityState==='visible');
 useEffect(()=>{const media=matchMedia('(prefers-reduced-motion: reduce)');const update=()=>setReduced(media.matches);media.addEventListener('change',update);const visibility=()=>setVisible(document.visibilityState==='visible');document.addEventListener('visibilitychange',visibility);return()=>{media.removeEventListener('change',update);document.removeEventListener('visibilitychange',visibility)}},[]);
 useEffect(()=>{if(paused||reduced||!visible)return;const id=window.setInterval(()=>setIndex(i=>(i+1)%photos.length),5000);return()=>window.clearInterval(id)},[paused,reduced,visible]);
 const labels=copy[locale as keyof typeof copy]??copy.fr;
 return <section className="auth-intro atelier-auth"><div className="auth-brand">GrillaD</div><p>{subtitle}</p><div className="atelier-photo-frame" aria-hidden="true">{photos.map((p,i)=><img key={p.src} src={p.src} width={p.width} height={p.height} alt="" className={i===index?'atelier-photo active':'atelier-photo'} decoding="async" loading="eager"/>)}</div>{!reduced&&<button type="button" className="atelier-photo-control" onClick={()=>setPaused(p=>!p)} aria-pressed={paused}>{paused?labels[1]:labels[0]}</button>}</section>
}
