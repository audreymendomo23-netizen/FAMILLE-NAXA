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
 return Object.freeze({app_id:"WIDEMEET",access_token:j.access_token,member_id:j.member_id,device_id:j.device_id,expires_at:j.expires_at,server_now:j.server_now,observed_wall:now,observed_mono:mono,active_workspace_id:j.active_workspace_id,require_password_change:j.require_password_change,workspaces:Object.freeze(workspaces)});
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
export async function login(base,identifier,password,fetcher=fetch,device=installationId){
 if(typeof identifier!=="string"||!identifier.trim()||typeof password!=="string"||!password)throw Error("INVALID_CREDENTIALS");
 const url=endpoint(base,"login");
 const res=await fetcher(url,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"WIDEMEET",identifier:identifier.trim(),password,installation_id:device(),platform:"web"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!res.ok)throw Error("LOGIN_REJECTED");return parseSession(await res.json());
}
export async function authorizedRequest(base,action,body,token,fetcher=fetch){
 if(!["logout","change-password","onboarding-state","onboarding-step","switch-workspace"].includes(action)||!tokenOk(token))throw Error("FORBIDDEN_ACTION");
 const res=await fetcher(endpoint(base,action),{method:"POST",headers:{"Content-Type":"application/json","Authorization":"Bearer "+token},body:JSON.stringify({...body,app_id:"WIDEMEET"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!res.ok)throw Error("REQUEST_REJECTED");return res.status===204?{}:res.json();
}

/** Server-confirmed workspace switch, never change the active workspace locally. */
export async function switchWorkspace(base,session,workspaceId,fetcher=fetch){
 if(!workspaceAccess(session,session.active_workspace_id)||!session.workspaces.some(w=>w.id===workspaceId&&w.enabled))throw Error("FORBIDDEN_SCOPE");
 const raw=await authorizedRequest(base,"switch-workspace",{workspace_id:workspaceId},session.access_token,fetcher);
 const next=parseSession(raw);
 if(next.member_id!==session.member_id||next.active_workspace_id!==workspaceId||next.expires_at>session.expires_at)throw Error("INVALID_SCOPE");
 return next;
}
