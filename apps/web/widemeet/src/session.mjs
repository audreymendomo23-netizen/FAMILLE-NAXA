// Derived from BOOTIK session.mjs 588252185a8bab4b31f7a9e4ffe5e18f1bef7cc5; no tokens persisted in Web storage.
// This client contract is not server authorization. No sister backend endpoint may be used.
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const tokenOk=v=>typeof v==="string"&&v.length>=20&&v.length<=4096&&!/\s/.test(v);
export function parseSession(j,now=Date.now(),mono=performance.now()){
 if(!j||j.app_id!=="WIDEMEET"||!tokenOk(j.access_token)||!UUID.test(j.member_id??"")||!UUID.test(j.device_id??"")||!Number.isSafeInteger(now)||!Number.isFinite(mono)||!Number.isSafeInteger(j.expires_at)||j.expires_at<=now||!Number.isSafeInteger(j.server_now)||j.server_now<0||j.server_now>=j.expires_at||!Array.isArray(j.workspaces)||!j.workspaces.length||typeof j.require_password_change!=="boolean")throw Error("INVALID_WIDEMEET_SESSION");
 const workspaces=j.workspaces.map(w=>{
 if(!w||!UUID.test(w.id??"")||!["individual","enterprise"].includes(w.kind)||typeof w.name!=="string"||!w.name.trim()||w.enabled!==true||!(w.kind==="individual"?w.role==="owner":["promoteur","manager","staff"].includes(w.role)))throw Error("INVALID_SCOPE");
 return Object.freeze({id:w.id,kind:w.kind,name:w.name,role:w.role,enabled:true});
 });
 if(new Set(workspaces.map(w=>w.id)).size!==workspaces.length||!workspaces.some(w=>w.id===j.active_workspace_id))throw Error("INVALID_SCOPE");
 return Object.freeze({app_id:"WIDEMEET",access_token:j.access_token,member_id:j.member_id,device_id:j.device_id,expires_at:j.expires_at,server_now:j.server_now,observed_wall:now,observed_mono:mono,active_workspace_id:j.active_workspace_id,require_password_change:j.require_password_change,refresh_available:j.refresh_available===true,workspaces:Object.freeze(workspaces)});
}
export function leaseValid(session,now=Date.now(),mono=performance.now()){
 if(!session||!Number.isSafeInteger(now)||!Number.isFinite(mono))return false;
 const elapsed=mono-session.observed_mono;
 if(!Number.isFinite(elapsed)||elapsed<0||now+5000<session.observed_wall+elapsed)return false;
 return now<session.expires_at&&session.server_now+elapsed<session.expires_at;
}
export function workspaceAccess(session,id,now=Date.now(),mono=performance.now()){
 if(!leaseValid(session,now,mono)||session.require_password_change||session.active_workspace_id!==id)return null;
 return session.workspaces.find(w=>w.id===id&&w.enabled===true)??null;
}
export function mayPay(session,id,now=Date.now(),mono=performance.now()){
 const w=workspaceAccess(session,id,now,mono);
 return !!w&&(w.kind==="individual"?w.role==="owner":w.role==="promoteur");
}
export function installationId(){
 const key='widemeet-installation-id';const re=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
 try{const saved=localStorage.getItem(key);if(saved&&re.test(saved))return saved;const id=crypto.randomUUID();localStorage.setItem(key,id);return id}catch{return crypto.randomUUID()}
}

function endpoint(base,action){
 if(typeof base!=="string"||!base)throw Error("WIDEMEET_API_NOT_CONFIGURED");
 const u=new URL(base);
 if(u.protocol!=="https:"||u.username||u.password||u.search||u.hash||!u.pathname.replace(/\/$/,"").endsWith("/widemeet-auth"))throw Error("INVALID_API");
 return new URL(u.href.replace(/\/$/,"")+"/"+action);
}
export async function login(base,identifier,password,fetcher=fetch,device=installationId,remember=null){
 if(typeof identifier!=="string"||!identifier.trim()||typeof password!=="string"||!password)throw Error("INVALID_CREDENTIALS");
 const url=endpoint(base,"login");
 const res=await fetcher(url,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"WIDEMEET",identifier:identifier.trim(),password,installation_id:device(),platform:"web",...(typeof remember==="boolean"?{remember_me:remember}:{})}),cache:"no-store",redirect:"error",credentials:typeof remember==="boolean"?"include":"omit"});
 if(!res.ok)throw Error("LOGIN_REJECTED");const session=parseSession(await res.json());if(typeof remember==="boolean")setRememberPreference(remember&&session.refresh_available);return session;
}
export async function authorizedRequest(base,action,body,token,fetcher=fetch){
 if(!["logout","change-password","onboarding-state","onboarding-step","switch-workspace","identity","recovery-enroll","chat-media","push"].includes(action)||!tokenOk(token))throw Error("FORBIDDEN_ACTION");
 const res=await fetcher(endpoint(base,action),{method:"POST",headers:{"Content-Type":"application/json","Authorization":"Bearer "+token},body:JSON.stringify({...body,app_id:"WIDEMEET"}),cache:"no-store",redirect:"error",credentials:["logout","change-password"].includes(action)?"include":"omit"});
 if(!res.ok)throw Error("REQUEST_REJECTED");return res.status===204?{}:res.json();
}

/** Server-confirmed workspace switch, never change the active workspace locally. */
export async function switchWorkspace(base,session,workspaceId,fetcher=fetch){
 if(!workspaceAccess(session,session.active_workspace_id)||!session.workspaces.some(w=>w.id===workspaceId&&w.enabled))throw Error("FORBIDDEN_SCOPE");
 const raw=await authorizedRequest(base,"switch-workspace",{workspace_id:workspaceId},session.access_token,fetcher);
 const next=parseSession({...raw,refresh_available:session.refresh_available});
 if(next.member_id!==session.member_id||next.active_workspace_id!==workspaceId||next.expires_at>session.expires_at)throw Error("INVALID_SCOPE");
 return next;
}

export async function requestRecovery(base,identifier,fetcher=fetch,device=installationId){
 if(typeof identifier!=="string"||!/^WM-[A-Z0-9]{8,24}$/.test(identifier.trim().toUpperCase()))throw Error("INVALID_IDENTIFIER");
 const res=await fetcher(endpoint(base,"request-recovery"),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"WIDEMEET",identifier:identifier.trim().toUpperCase(),installation_id:device(),platform:"web"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!res.ok)throw Error("RECOVERY_REJECTED");const payload=await res.json();if(payload?.accepted!==true)throw Error("RECOVERY_UNCONFIRMED");return true;
}

export async function identityAction(base,session,action,data={},fetcher=fetch){
 if(!workspaceAccess(session,session.active_workspace_id))throw Error("FORBIDDEN_SCOPE");
 return authorizedRequest(base,"identity",{action,data},session.access_token,fetcher);
}
export async function registerAccount(base,form,fetcher=fetch,device=installationId){
 if(!["individual","enterprise"].includes(form.kind)||!form.display_name?.trim()||!form.workspace_name?.trim()||typeof form.password!=="string"||form.password.length<12||form.password.length>256||form.accepted_terms!==true||!UUID.test(form.request_id??""))throw Error("INVALID_REGISTRATION");
 const res=await fetcher(endpoint(base,"register"),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({...form,app_id:"WIDEMEET",installation_id:device(),terms_version:"wm-replay-draft-20261126",privacy_version:"wm-replay-draft-20261126"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!res.ok)throw Error("REGISTRATION_REJECTED");const data=await res.json();if(!/^WM-[A-Z0-9]{8,24}$/.test(data.login_id??"")||data.kind!==form.kind)throw Error("REGISTRATION_UNCONFIRMED");return data;
}

const rememberKey="widemeet.remember.preference";
export function setRememberPreference(value){try{if(value===true)localStorage.setItem(rememberKey,"yes");else localStorage.removeItem(rememberKey)}catch{}}
export function rememberPreference(){try{return localStorage.getItem(rememberKey)==="yes"}catch{return false}}
export async function refreshSession(base,fetcher=fetch,device=installationId){
 const res=await fetcher(endpoint(base,"refresh"),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"WIDEMEET",installation_id:device(),platform:"web"}),cache:"no-store",redirect:"error",credentials:"include"});
 if(!res.ok)throw Error("REFRESH_REJECTED");
 const raw=await res.json();
 if(raw.refresh_available!==true||raw.require_password_change!==false||"refresh_token" in raw)throw Error("REFRESH_UNCONFIRMED");
 return parseSession(raw);
}

export async function enrollRecoveryKey(base,session,password,fetcher=fetch,supervised=false){
 if(!workspaceAccess(session,session.active_workspace_id)||typeof password!=="string"||!password||password.length>256)throw Error("INVALID_REQUEST");
 const data=await authorizedRequest(base,"recovery-enroll",{current_password:password,...(supervised?{supervised:true}:{})},session.access_token,fetcher);
 if(!/^[a-f0-9]{64}$/.test(data?.recovery_key??""))throw Error("RECOVERY_UNCONFIRMED");
 return data.recovery_key;
}
export async function recoverWithKey(base,{identifier,key,password,requestId,supervised=false},fetcher=fetch,device=installationId){
 if(!/^WM-[A-Z0-9]{8,24}$/.test(identifier.trim().toUpperCase())||! /^[a-f0-9]{64}$/.test(key.trim().toLowerCase())||typeof password!=="string"||password.length<12||password.length>256||!UUID.test(requestId))throw Error("INVALID_REQUEST");
 const r=await fetcher(endpoint(base,"recover-key"),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"WIDEMEET",identifier:identifier.trim().toUpperCase(),recovery_key:key.trim().toLowerCase(),new_password:password,request_id:requestId,installation_id:device(),platform:"web",...(supervised?{supervised:true}:{})}),cache:"no-store",redirect:"error",credentials:"include"});
 if(!r.ok)throw Error("RECOVERY_REJECTED");
 const j=await r.json();if(j?.recovered!==true||j.reconnect!==true)throw Error("RECOVERY_UNCONFIRMED");
 setRememberPreference(false);return true;
}

export async function requestSupervisedRecovery(base,identifier,key,fetcher=fetch,device=installationId){
 const id=identifier.trim().toUpperCase(),code=key.trim().toLowerCase();
 if(!/^WM-[A-Z0-9]{8,24}$/.test(id)||!/^[a-f0-9]{64}$/.test(code))throw Error("INVALID_REQUEST");
 const r=await fetcher(endpoint(base,"request-recovery"),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"WIDEMEET",identifier:id,recovery_key:code,supervised:true,installation_id:device(),platform:"web"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!r.ok)throw Error("RECOVERY_REJECTED");const j=await r.json();if(!UUID.test(j?.case_id??""))throw Error("RECOVERY_UNCONFIRMED");return j.case_id;
}
