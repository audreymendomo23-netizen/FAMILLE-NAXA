import React,{useEffect,useState} from "react";
type Props={call:(a:string,b?:Record<string,unknown>)=>Promise<any>;en:boolean;disabled:boolean;role:string;posts:string[];refresh:()=>Promise<void>};
export function SubstationWorkspace({call,en,disabled,role,posts,refresh}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;const [data,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState(""),[label,L]=useState(""),[post,P]=useState(posts[0]??"kitchen"),[slots,S]=useState("1");
 const lock=disabled||busy;async function load(){D(await call("substation_snapshot"))}
 async function run(fn:()=>Promise<void>){if(lock)return;B(true);E("");try{await fn();await load();await refresh()}catch{E(t("Opération non confirmée","Operation unconfirmed"))}finally{B(false)}}
 useEffect(()=>{let active=true;call("substation_snapshot").then(v=>{if(active)D(v)}).catch(()=>{if(active)E(t("Sous-postes indisponibles","Substations unavailable"))});return()=>{active=false}},[]);
 return <details><summary>{t("Sous-postes de préparation","Preparation substations")}</summary>{error&&<p role="alert">{error}</p>}
 <label>{t("Nom du sous-poste","Substation name")}<input maxLength={80} value={label} onChange={e=>L(e.target.value)}/></label>
 <label>{t("Poste principal","Parent station")}<select value={post} onChange={e=>P(e.target.value)}>{posts.map(p=><option key={p}>{p}</option>)}</select></label>
 <label>{t("Capacité simultanée","Parallel capacity")}<input type="number" min="1" max="100" value={slots} onChange={e=>S(e.target.value)}/></label>
 <button disabled={lock||label.trim().length<2||!Number.isInteger(Number(slots))||Number(slots)<1||Number(slots)>100||!posts.includes(post)} onClick={()=>run(async()=>{await call("substation_configure",{post,label,parallel_slots:Number(slots)});L("")})}>{t("Enregistrer le sous-poste","Save substation")}</button>
 {(data?.stations??[]).map((s:any)=><p key={s.id}>{s.label} · {s.post} · {s.parallel_slots}</p>)}
 <h4>{t("Affectation des articles","Item routing")}</h4>{(data?.items??[]).map((i:any)=><label key={i.id}>{i.name}<select aria-label={t("Sous-poste pour ","Substation for ")+i.name} value={i.substation_id??""} disabled={lock} onChange={e=>{const v=e.target.value;void run(async()=>{await call("substation_assign",{item_id:i.id,substation_id:v||null})})}}><option value="">{t("Poste principal","Parent station")}</option>{(data?.stations??[]).filter((s:any)=>s.post===i.post).map((s:any)=><option key={s.id} value={s.id}>{s.label}</option>)}</select></label>)}
 {role==="promoteur"&&<><h4>{t("Habilitations des sous-postes","Substation permissions")}</h4>{(data?.staff??[]).map((m:any)=><div key={m.id}><p>{m.login}</p>{(data?.stations??[]).map((s:any)=><label key={s.id}><input type="checkbox" disabled={lock} checked={(m.stations??[]).includes(s.id)} onChange={e=>{const enabled=e.target.checked;void run(async()=>{await call("substation_grant",{member_id:m.id,substation_id:s.id,enabled})})}}/>{s.label}</label>)}</div>)}</>}
 </details>
}
