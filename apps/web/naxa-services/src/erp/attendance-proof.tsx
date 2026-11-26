import React,{useEffect,useRef,useState} from "react";
import type {WebAuthAccount} from "../auth/session";
import {rosterApiOrigin} from "./staff-roster";
export type AttendanceAction="staff_clock_in"|"staff_break_start"|"staff_break_end"|"staff_clock_out";
const actions:AttendanceAction[]=["staff_clock_in","staff_break_start","staff_break_end","staff_clock_out"];
type Policy={event_type:AttendanceAction;revision:number;require_gps:boolean;require_selfie:boolean};
type GPS={latitude:number;longitude:number;accuracy:number;at:string};
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>;action:AttendanceAction|null;onClose:()=>void;onSubmit:(id:string,occurred:string,action:AttendanceAction)=>Promise<void>};
export function AttendanceProofPanel({account,siteId,authEndpoint,anonKey,getToken,action,onClose,onSubmit}:Props){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const labels:Record<AttendanceAction,string>={staff_clock_in:tr("Prise de service","Start shift","Fuɗɗo golle"),staff_break_start:tr("Début de pause","Start break","Fuɗɗo fowtude"),staff_break_end:tr("Fin de pause","End break","Timmin fowtude"),staff_clock_out:tr("Fin de service","End shift","Timmin golle")};
 const [policies,setPolicies]=useState<Policy[]>([]),[loaded,setLoaded]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const [gps,setGps]=useState<GPS|null>(null),[photo,setPhoto]=useState<{blob:Blob;at:string}|null>(null),[camera,setCamera]=useState(false),[reload,setReload]=useState(0);
 const live=useRef(false),stream=useRef<MediaStream|null>(null),video=useRef<HTMLVideoElement|null>(null),controller=useRef<AbortController|null>(null),gen=useRef(0),token=useRef(getToken);
 token.current=getToken;
 const manager=["promoter","network_manager","site_manager"].includes(account.role_code);
 const rule=(a:AttendanceAction):Policy=>policies.find(p=>p.event_type===a)??{event_type:a,revision:0,require_gps:false,require_selfie:false};
 const policy=action?rule(action):null;
 function stop(){stream.current?.getTracks().forEach(t=>t.stop());stream.current=null;if(video.current)video.current.srcObject=null;setCamera(false);}
 async function req<T>(path:string,body?:Record<string,unknown>):Promise<T>{
  const jwt=await token.current();const signal=controller.current?.signal;
  if(!live.current||signal?.aborted||!jwt||!anonKey)throw Error("SESSION_CHANGED");
  const r=await fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/"+path,{method:body?"POST":"GET",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:body?JSON.stringify(body):undefined,cache:"no-store",credentials:"omit",redirect:"error",signal});
  if(!r.ok)throw Error("ATTENDANCE_REQUEST_FAILED");return await r.json() as T;
 }
 useEffect(()=>{live.current=true;controller.current=new AbortController();const c=controller.current;setLoaded(false);
  void req<Policy[]>("ns_attendance_policies?select=event_type,revision,require_gps,require_selfie&org_id=eq."+encodeURIComponent(account.organization_id)+"&site_id=eq."+encodeURIComponent(siteId)).then(p=>{if(!c.signal.aborted){setPolicies(p);setLoaded(true);setError(false);}}).catch(()=>{if(!c.signal.aborted){setError(true);setLoaded(false);}});
  return()=>{live.current=false;c.abort();gen.current++;stream.current?.getTracks().forEach(t=>t.stop());stream.current=null;};
 },[account.organization_id,account.member_id,siteId,reload]);
 useEffect(()=>{gen.current++;stop();setGps(null);setPhoto(null);},[action,reload]);
 // Backgrounding must not keep the camera alive or leave reusable evidence.
 useEffect(()=>{function hide(){if(document.visibilityState!=="hidden")return;gen.current++;stop();setGps(null);setPhoto(null);}
 document.addEventListener("visibilitychange",hide);return()=>document.removeEventListener("visibilitychange",hide);},[]);
 async function obtainGPS(){
  const g=gen.current;setBusy(true);setError(false);setGps(null);
  try{if(!navigator.onLine||!navigator.geolocation)throw Error();
   const p=await new Promise<GeolocationPosition>((resolve,reject)=>navigator.geolocation.getCurrentPosition(resolve,reject,{enableHighAccuracy:true,maximumAge:0,timeout:20000}));
   const c=p.coords;if(!Number.isFinite(c.latitude)||!Number.isFinite(c.longitude)||!Number.isFinite(c.accuracy)||c.accuracy<=0||c.accuracy>500||Math.abs(Date.now()-p.timestamp)>120000)throw Error();
   if(live.current&&g===gen.current)setGps({latitude:c.latitude,longitude:c.longitude,accuracy:c.accuracy,at:new Date(p.timestamp).toISOString()});
  }catch{if(live.current&&g===gen.current)setError(true);}finally{if(live.current)setBusy(false);}
 }
 async function openCamera(){
  const g=gen.current;setBusy(true);setError(false);setPhoto(null);
  try{if(!navigator.onLine||!navigator.mediaDevices?.getUserMedia)throw Error();
   const s=await navigator.mediaDevices.getUserMedia({audio:false,video:{facingMode:{exact:"user"},width:{ideal:960},height:{ideal:720}}});
   if(!live.current||g!==gen.current){s.getTracks().forEach(t=>t.stop());return;}
   const facing=s.getVideoTracks()[0]?.getSettings().facingMode;if(facing&&facing!=="user"){s.getTracks().forEach(t=>t.stop());throw Error();}
   stream.current=s;setCamera(true);if(!video.current)throw Error();video.current.srcObject=s;await video.current.play();
  }catch{if(live.current){stop();setError(true);}}finally{if(live.current)setBusy(false);}
 }
 async function takePhoto(){
  const g=gen.current;setBusy(true);setError(false);
  try{const v=video.current;if(!v||!stream.current||!v.videoWidth||!v.videoHeight)throw Error();
   const canvas=document.createElement("canvas"),ratio=Math.min(1,960/Math.max(v.videoWidth,v.videoHeight));
   canvas.width=Math.round(v.videoWidth*ratio);canvas.height=Math.round(v.videoHeight*ratio);const ctx=canvas.getContext("2d");if(!ctx)throw Error();
   ctx.drawImage(v,0,0,canvas.width,canvas.height);const at=new Date().toISOString();
   const blob=await new Promise<Blob|null>(resolve=>canvas.toBlob(resolve,"image/jpeg",.8));canvas.width=0;canvas.height=0;
   if(!blob||blob.size<=0||blob.size>2097152||blob.type!=="image/jpeg")throw Error();
   if(live.current&&g===gen.current){setPhoto({blob,at});stop();}
  }catch{if(live.current){stop();setError(true);}}finally{if(live.current)setBusy(false);}
 }
 async function confirm(){
  if(!action||!policy||!loaded||busy||!navigator.onLine)return;const g=gen.current;setBusy(true);setError(false);
  try{
   if((policy.require_gps&&(!gps||Math.abs(Date.now()-Date.parse(gps.at))>120000))||(policy.require_selfie&&(!photo||Math.abs(Date.now()-Date.parse(photo.at))>120000)))throw Error();
   const id=crypto.randomUUID(),occurred=new Date().toISOString(),jwt=await token.current();if(!live.current||g!==gen.current||!jwt)throw Error();
   if(policy.require_selfie&&photo){const path=[account.organization_id,siteId,account.member_id,id+".jpg"].map(encodeURIComponent).join("/");
    const r=await fetch(rosterApiOrigin(authEndpoint)+"/storage/v1/object/ns-attendance-selfies/"+path,{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"image/jpeg","x-upsert":"false"},body:photo.blob,cache:"no-store",credentials:"omit",redirect:"error",signal:controller.current?.signal});if(!r.ok)throw Error();}
   if(!live.current||g!==gen.current)throw Error();
   const result=await req<{proof_ref:string;staged:boolean}>("rpc/ns_stage_attendance_proof",{p_event_id:id,p_org:account.organization_id,p_site:siteId,p_post:null,p_event:action,p_occurred:occurred,p_revision:policy.revision,p_latitude:policy.require_gps?gps?.latitude:null,p_longitude:policy.require_gps?gps?.longitude:null,p_accuracy:policy.require_gps?gps?.accuracy:null,p_gps_at:policy.require_gps?gps?.at:null,p_selfie_at:policy.require_selfie?photo?.at:null});
   if(!live.current||g!==gen.current||result.proof_ref!==id||!result.staged)throw Error();
   await onSubmit(id,occurred,action);if(live.current&&g===gen.current){setGps(null);setPhoto(null);onClose();}
  }catch{if(live.current&&g===gen.current){setGps(null);setPhoto(null);setError(true);}}finally{if(live.current)setBusy(false);}
 }
 async function save(p:Policy,g:boolean,s:boolean){
  setBusy(true);setError(false);
  try{await req("rpc/ns_set_attendance_policy",{p_org:account.organization_id,p_site:siteId,p_event:p.event_type,p_revision:p.revision,p_gps:g,p_selfie:s});if(live.current)setReload(x=>x+1);}
  catch{if(live.current){setError(true);setLoaded(false);}}finally{if(live.current)setBusy(false);}
 }
 return <><section className="module-main-card"><h2>{tr("Preuves de service","Attendance evidence","Seedeeji golle")}</h2>
 {error&&<p role="alert">{tr("Action non confirmée. Vérifiez la connexion, les permissions ou la règle du responsable.","Action not confirmed. Check connection, permissions or your manager's rule.","Golle tabbitinaaka. Ƴeewto ceŋol e yamirooje.")}</p>}
 <button className="btn secondary" disabled={busy} onClick={()=>setReload(x=>x+1)}>{tr("Actualiser les règles","Refresh rules","Hesɗitin yamirooje")}</button>
 {manager&&loaded&&<div>{actions.map(a=>{const p=rule(a);return <fieldset key={a}><legend>{labels[a]}</legend><label><input type="checkbox" checked={p.require_gps} disabled={busy||!!action} onChange={e=>void save(p,e.target.checked,p.require_selfie)}/> GPS</label><label><input type="checkbox" checked={p.require_selfie} disabled={busy||!!action} onChange={e=>void save(p,p.require_gps,e.target.checked)}/> Selfie</label></fieldset>;})}</div>}
 {action&&<div role="region" aria-label={labels[action]}><h3>{labels[action]}</h3><p>{tr("La preuve est collectée uniquement pour ce pointage. Une connexion est nécessaire.","Evidence is collected only for this attendance event. Connection required.","Seedeeji ko ngam golle ɗee tan. Ceŋol ena sokli.")}</p>
 {loaded&&policy&&<>{policy.require_gps&&<button className="btn secondary" disabled={busy} onClick={()=>void obtainGPS()}>{gps?tr("Position obtenue — reprendre","Position captured — retake","Nokkuure heɓiima"):tr("Obtenir ma position","Get my location","Heɓ nokkuure am")}</button>}
 {policy.require_selfie&&<><video ref={video} autoPlay playsInline muted style={{display:camera?"block":"none",width:"100%",maxWidth:"360px"}}/><button className="btn secondary" disabled={busy} onClick={()=>void (camera?takePhoto():openCamera())}>{camera?tr("Prendre le selfie","Take selfie","Ɓam natal"):photo?tr("Selfie pris — reprendre","Selfie captured — retake","Natal heɓiima"):tr("Ouvrir la caméra avant","Open front camera","Uddit kamera")}</button></>}
 <button className="btn primary" disabled={busy||!navigator.onLine||(policy.require_gps&&!gps)||(policy.require_selfie&&!photo)} onClick={()=>void confirm()}>{tr("Confirmer mon pointage","Confirm my attendance","Tabbitin golle am")}</button></>}
 <button className="btn secondary" disabled={busy} onClick={()=>{stop();onClose();}}>{tr("Annuler","Cancel","Haaytu")}</button></div>}</section>{!action&&<AttendanceReview key={account.organization_id+":"+account.member_id+":"+siteId} account={account} siteId={siteId} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken}/>}</>;
}

type EvidenceRow={event_id:string;member_name:string;event_type:AttendanceAction;occurred_at:string;required_gps:boolean;required_selfie:boolean;latitude:number|null;longitude:number|null;accuracy_m:number|null;gps_captured_at:string|null;selfie_path:string|null;selfie_captured_at:string|null;policy_revision:number};
function AttendanceReview({account,siteId,authEndpoint,anonKey,getToken}:Pick<Props,"account"|"siteId"|"authEndpoint"|"anonKey"|"getToken">){
 const tr=(fr:string,en:string,ff:string)=>account.default_locale==="en"?en:account.default_locale==="ff-CM"?ff:fr;
 const labels:Record<AttendanceAction,string>={staff_clock_in:tr("Prise de service","Start shift","Fuɗɗo golle"),staff_break_start:tr("Début de pause","Start break","Fuɗɗo fowtude"),staff_break_end:tr("Fin de pause","End break","Timmin fowtude"),staff_clock_out:tr("Fin de service","End shift","Timmin golle")};
 const [rows,setRows]=useState<EvidenceRow[]>([]),[shown,setShown]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(false),[photo,setPhoto]=useState<{id:string;url:string}|null>(null);
 const controller=useRef<AbortController|null>(null),objectUrl=useRef<string|null>(null),alive=useRef(true),epoch=useRef(0);
 function clearPhoto(){if(objectUrl.current)URL.revokeObjectURL(objectUrl.current);objectUrl.current=null;setPhoto(null);}
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;epoch.current++;controller.current?.abort();if(objectUrl.current)URL.revokeObjectURL(objectUrl.current);objectUrl.current=null;};},[]);
 function close(){epoch.current++;controller.current?.abort();clearPhoto();setRows([]);setShown(false);setBusy(false);}
 async function load(){
  const n=++epoch.current;controller.current?.abort();const c=new AbortController();controller.current=c;clearPhoto();setRows([]);setShown(true);setBusy(true);setError(false);
  try{const jwt=await getToken();if(c.signal.aborted||!jwt)throw Error();
   const r=await fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/ns_attendance_review",{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,p_limit:50}),cache:"no-store",redirect:"error",credentials:"omit",signal:c.signal});
   if(!r.ok)throw Error();const data=await r.json() as EvidenceRow[];if(alive.current&&n===epoch.current&&!c.signal.aborted)setRows(data);
  }catch{if(alive.current&&n===epoch.current)setError(true);}finally{if(alive.current&&n===epoch.current)setBusy(false);}
 }
 async function view(row:EvidenceRow){
  if(!row.selfie_path)return;const n=++epoch.current;controller.current?.abort();const c=new AbortController();controller.current=c;clearPhoto();setBusy(true);setError(false);
  try{const parts=row.selfie_path.split("/");if(parts.length!==4||parts[0]!==account.organization_id||parts[1]!==siteId||parts[3]!==row.event_id+".jpg"||!parts.slice(0,3).every(x=>/^[0-9a-f-]{36}$/i.test(x)))throw Error();
   const jwt=await getToken();if(!jwt||c.signal.aborted)throw Error();
   const r=await fetch(rosterApiOrigin(authEndpoint)+"/storage/v1/object/authenticated/ns-attendance-selfies/"+parts.map(encodeURIComponent).join("/"),{headers:{apikey:anonKey,Authorization:"Bearer "+jwt},cache:"no-store",credentials:"omit",redirect:"error",signal:c.signal});if(!r.ok)throw Error();const b=await r.blob();if(b.type!=="image/jpeg"||!b.size||b.size>2097152)throw Error();
   if(alive.current&&n===epoch.current&&!c.signal.aborted){const url=URL.createObjectURL(b);objectUrl.current=url;setPhoto({id:row.event_id,url});}
  }catch{if(alive.current&&n===epoch.current){setError(true);setRows([]);}}finally{if(alive.current&&n===epoch.current)setBusy(false);}
 }
 return <section className="module-main-card" aria-labelledby="ns-attendance-review-title"><h3 id="ns-attendance-review-title">{tr("Consulter les preuves","Review evidence","Ƴeewto seedeeji")}</h3>
 <button className="btn secondary" onClick={()=>shown?close():void load()}>{shown?tr("Fermer","Close","Uddu"):tr("Afficher les preuves autorisées","Show authorized evidence","Hollu seedeeji")}</button>
 {shown&&<><button className="btn secondary" disabled={busy} onClick={()=>void load()}>{tr("Actualiser","Refresh","Hesɗitin")}</button>
 {error&&<p role="alert">{tr("Preuve indisponible ou accès retiré.","Evidence unavailable or access withdrawn.","Seedee heɓotaako.")}</p>}
 {!busy&&!error&&!rows.length&&<p>{tr("Aucune preuve disponible.","No evidence available.","Alaa seedee.")}</p>}
 {rows.map(row=><article key={row.event_id}><strong>{row.member_name}</strong><p>{labels[row.event_type]} · {new Date(row.occurred_at).toLocaleString(account.default_locale==="en"?"en-GB":"fr-FR",{timeZone:"Africa/Douala"})}</p>
 <p>GPS: {row.latitude===null?tr("Non fourni","Not supplied","Alaa"):`${row.latitude.toFixed(5)}, ${row.longitude?.toFixed(5)} (±${row.accuracy_m} m)`} · {tr("Règle","Policy","Yamiroore")} {row.policy_revision}</p>
 {row.selfie_path&&<button className="btn secondary" disabled={busy} onClick={()=>photo?.id===row.event_id?clearPhoto():void view(row)}>{photo?.id===row.event_id?tr("Masquer","Hide","Suuɗ"):tr("Voir le selfie","View selfie","Yi'u natal")}</button>}
 {photo?.id===row.event_id&&<img src={photo.url} alt={tr("Selfie du pointage","Attendance selfie","Natal golle")} style={{maxWidth:"240px",width:"100%"}}/>}</article>)}</>}
 </section>;
}
