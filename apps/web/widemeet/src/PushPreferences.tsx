import React,{useEffect,useRef,useState}from"react";
import{authorizedRequest}from"./session.mjs";
import{resolveFirebasePush}from"./firebase-config.mjs";
const {config,vapid,configured}=resolveFirebasePush(import.meta.env);
async function sdk(){
 if(!configured||!navigator.serviceWorker||!("Notification" in window))throw Error("unconfigured");
 const app=await import("firebase/app"),m=await import("firebase/messaging");if(!await m.isSupported())throw Error("unsupported");
 const existing=app.getApps().find(a=>a.name==="widemeet-push"),firebase=existing??app.initializeApp(config,"widemeet-push");
 if(firebase.options.projectId!==config.projectId||firebase.options.appId!==config.appId)throw Error("project");
 return {m,messaging:m.getMessaging(firebase)};
}
export async function getFirebasePushToken(){
  const {m,messaging}=await sdk();if(Notification.permission!=="granted")throw Error("permission");
  const registration=await Promise.race([navigator.serviceWorker.ready,new Promise((_,reject)=>setTimeout(()=>reject(Error("worker")),10000))]);
  const token=await m.getToken(messaging,{vapidKey:vapid,serviceWorkerRegistration:registration});
 return {m,messaging,token};
}
export function PushPreferences({base,session,locale,onNotice}){
 const tr=(fr,en)=>locale==="en"?en:fr,storageKey="wm.push.optin."+session.member_id+"."+session.active_workspace_id;
 const [enabled,E]=useState(false),[busy,B]=useState(false),[error,X]=useState(false);const live=useRef(true),working=useRef(false);
 const req=(action,data={})=>authorizedRequest(base,"push",{action,...data},session.access_token);
 const opted=()=>{try{return localStorage.getItem(storageKey)==="yes"}catch{return false}};
 const consent=v=>{try{v?localStorage.setItem(storageKey,"yes"):localStorage.removeItem(storageKey)}catch{}};
 async function bind(){
  const {token}=await getFirebasePushToken();
  const result=await req("register",{platform:"web",token});if(result.enabled!==true)throw Error("unconfirmed");
  if(live.current){consent(true);E(true)}
 }
 async function work(fn){if(working.current)return;working.current=true;B(true);X(false);try{await fn()}catch{if(live.current)X(true)}finally{working.current=false;if(live.current)B(false)}}
 useEffect(()=>{live.current=true;let dead=false,off;async function start(){try{const r=await req("status");if(dead)return;E(r.enabled===true);if(opted()&&configured&&Notification.permission==="granted")await work(bind);if(!dead&&configured&&Notification.permission==="granted"){const {m,messaging}=await sdk();if(!dead)off=m.onMessage(messaging,()=>onNotice?.())}}catch{if(!dead)X(true)}}void start();const t=setInterval(()=>{if(opted()&&configured){if(Notification.permission==="granted")void work(bind);else void work(async()=>{await req("revoke");consent(false);E(false)})}},60000);return()=>{dead=true;live.current=false;clearInterval(t);off?.()}},[session.access_token]);
 return <section aria-label={tr("Notifications push","Push notifications")}><p>{enabled?tr("Push activé pour cette session","Push enabled for this session"):tr("Push désactivé","Push disabled")}</p>{!configured&&<p>{tr("Les notifications sont momentanément indisponibles.","Notifications are temporarily unavailable.")}</p>}{error&&<p role="alert">{tr("Activation ou révocation non confirmée.","Activation or revocation unconfirmed.")}</p>}
 <button disabled={busy||!configured||enabled} onClick={()=>work(async()=>{if(await Notification.requestPermission()!=="granted")throw Error("permission");await bind()})}>{tr("Activer les notifications push","Enable push notifications")}</button>
 <button disabled={busy} onClick={()=>work(async()=>{consent(false);const r=await req("revoke");if(r.revoked!==true)throw Error("revoke");E(false);if(configured){const {m,messaging}=await sdk();await m.deleteToken(messaging).catch(()=>{})}})}>{tr("Désactiver les notifications push","Disable push notifications")}</button></section>
}
