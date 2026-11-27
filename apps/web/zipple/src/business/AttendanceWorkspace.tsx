import React,{useEffect,useRef,useState} from "react";
type Props={call:(a:string,b?:Record<string,unknown>)=>Promise<any>;en:boolean;online:boolean};
export function AttendanceWorkspace({call,en,online}:Props){
 const tr=(fr:string,eng:string)=>en?eng:fr;
 const [data,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState(""),[notice,N]=useState("");
 const generation=useRef(0),pending=useRef<Record<string,unknown>|null>(null);
 async function load(){const g=generation.current;const result=await call("attendance_snapshot");if(g===generation.current)D(result)}
 useEffect(()=>{generation.current++;void load().catch(()=>E(tr("Pointage indisponible","Attendance unavailable")));return()=>{generation.current++;pending.current=null}},[]);
 async function record(event_type:string){if(busy||!online)return;const g=generation.current;B(true);E("");N("");try{
  let body=pending.current;
  if(!body||body.event_type!==event_type||Math.abs(Date.now()-Date.parse(String(body.gps_at)))>120000){
   const p=await new Promise<GeolocationPosition>((resolve,reject)=>navigator.geolocation.getCurrentPosition(resolve,reject,{enableHighAccuracy:true,maximumAge:0,timeout:20000}));
   if(!Number.isFinite(p.coords.latitude)||!Number.isFinite(p.coords.longitude)||!Number.isFinite(p.coords.accuracy)||p.coords.accuracy<=0||p.coords.accuracy>500||Math.abs(Date.now()-p.timestamp)>120000)throw Error("GPS");
   body={request_id:crypto.randomUUID(),event_type,latitude:p.coords.latitude,longitude:p.coords.longitude,accuracy_m:p.coords.accuracy,gps_at:new Date(p.timestamp).toISOString()};pending.current=body;
  }
  if(g!==generation.current)return;
  const result=await call("attendance_record",body);if(!result?.id)throw Error("UNCONFIRMED");if(g!==generation.current)return;
  pending.current=null;N(tr("Pointage enregistré","Attendance recorded"));await load();
 }catch{if(g===generation.current){E(tr("Pointage non confirmé. Vérifiez la position et la connexion, puis actualisez.","Attendance unconfirmed. Check location and connection, then refresh."));try{await load()}catch{}}}finally{if(g===generation.current)B(false)}}
 const label=(v:string)=>v==="clock_in"?tr("Prise de service","Start shift"):tr("Fin de service","End shift");
 const show=(x:any)=><p key={x.id}>{x.login_id?x.login_id+" · ":""}{label(x.event_type)} · {new Date(x.recorded_at).toLocaleString(en?"en-GB":"fr-CM",{timeZone:"Africa/Douala"})} · {x.latitude}, {x.longitude} (±{Math.round(x.accuracy_m)} m)</p>;
 return <section><h3>{tr("Pointage géolocalisé","Location attendance")}</h3><p>{tr("Votre position est demandée uniquement lors du pointage. La preuve est transmise à votre établissement ; aucun suivi permanent.","Location is requested only when clocking. Evidence is sent to your site; no continuous tracking.")}</p>
 <button disabled={busy||!online} onClick={()=>{E("");void load().catch(()=>E(tr("Pointage indisponible","Attendance unavailable")))}}>{tr("Actualiser le pointage","Refresh attendance")}</button>
 {notice&&<p role="status">{notice}</p>}{error&&<p role="alert">{error}</p>}{data&&<><p>{data.on_shift?(data.on_this_site?tr("Service en cours","Shift active"):tr("Service ouvert dans un autre établissement","Shift active at another site")):tr("Hors service","Off duty")}</p>
 <button disabled={busy||!online||data.on_shift} onClick={()=>void record("clock_in")}>{label("clock_in")}</button><button disabled={busy||!online||!data.on_this_site} onClick={()=>void record("clock_out")}>{label("clock_out")}</button>
 <h4>{tr("Mes pointages récents","My recent attendance")}</h4>{data.mine.map(show)}
 {data.can_manage&&<><h4>{tr("Pointages récents de l’équipe","Recent team attendance")}</h4>{data.team.map(show)}</>}</>}</section>
}
