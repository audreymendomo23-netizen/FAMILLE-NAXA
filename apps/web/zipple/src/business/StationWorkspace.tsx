import React,{useEffect,useState} from "react";
export function StationWorkspace({call,en,online}:{call:(a:string,b?:Record<string,unknown>)=>Promise<any>;en:boolean;online:boolean}){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [data,D]=useState<any>(null),[error,E]=useState(""),[busy,B]=useState(false);
 async function load(){D(await call("station_snapshot"))}
 async function run(fn:()=>Promise<void>){if(busy||!online)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{let live=true;const refresh=()=>call("station_snapshot").then(v=>{if(live)D(v)}).catch(()=>{if(live)D(null)});void refresh();const timer=setInterval(refresh,5000);return()=>{live=false;clearInterval(timer)}},[]);
 return <section><h2>{t("Postes de préparation","Preparation stations")}</h2>{error&&<p role="alert">{error}</p>}<button disabled={!online||busy} onClick={()=>run(load)}>{t("Actualiser","Refresh")}</button>
 {data?.lines?.map((l:any)=>{const next=({received:"preparing",preparing:"ready",ready:"served"} as any)[l.state];return <div key={l.order_id+l.item_id}><p>#{l.number} · {l.name} × {l.qty} · {l.post} · {l.state}</p>{next&&<button disabled={!online||busy} onClick={()=>run(async()=>{await call("line_advance",{order_id:l.order_id,item_id:l.item_id,next});await load()})}>{t("Étape suivante","Next step")}</button>}</div>})}
 {data?.items?.map((i:any)=><div key={i.id}>{i.name} · {i.available_qty}<button disabled={!online||busy} onClick={()=>run(async()=>{await call("station_availability",{item_id:i.id,active:!i.active});await load()})}>{i.active?t("Suspendre","Suspend"):t("Réactiver","Reactivate")}</button></div>)}
 {data&&data.posts?.length===0&&data.items?.length===0&&<p>{t("Aucun poste attribué.","No station assigned.")}</p>}</section>
}
