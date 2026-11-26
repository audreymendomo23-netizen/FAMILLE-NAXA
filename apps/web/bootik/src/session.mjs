export function parseSession(j,now=Date.now()){
 if(!j||j.app_id!=="BOOTIK"||typeof j.access_token!=="string"||j.access_token.length<20||typeof j.member_id!=="string"||!j.member_id||typeof j.organization_id!=="string"||!j.organization_id||!["promoteur","manager","staff"].includes(j.role)||!Number.isSafeInteger(j.expires_at)||j.expires_at<=now||!Array.isArray(j.sites)||!j.sites.length||j.sites.some(s=>!s||typeof s.id!=="string"||!s.id||typeof s.name!=="string")||new Set(j.sites.map(s=>s.id)).size!==j.sites.length)throw Error("INVALID_BOOTIK_SESSION");
 const hasLease=j.server_now!==undefined||j.offline_until!==undefined||j.scope_stamp!==undefined;if(hasLease&&(!Number.isSafeInteger(j.server_now)||!Number.isSafeInteger(j.offline_until)||j.server_now>=j.expires_at||j.offline_until<j.server_now||j.offline_until>j.expires_at||typeof j.scope_stamp!=='string'||!/^[0-9a-f]{32}$/.test(j.scope_stamp)))throw Error('INVALID_LEASE');
 return Object.freeze({...j,...(hasLease?{observed_wall:now,observed_mono:performance.now()}:{}),sites:Object.freeze(j.sites.map(s=>Object.freeze({...s})))});
}
export function leaseValid(session,now=Date.now(),mono=performance.now(),offline=false){
 if(!session)return false;if(session.server_now===undefined)return session.expires_at>now;
 const elapsed=mono-session.observed_mono;if(!Number.isFinite(elapsed)||elapsed<0||now+5000<session.observed_wall+elapsed)return false;
 return session.server_now+elapsed<Math.min(session.expires_at,offline?session.offline_until:session.expires_at);
}
export function permitsSite(session,id,now=Date.now(),mono=performance.now()){return leaseValid(session,now,mono,false)&&session.sites.some(s=>s.id===id)}
export function permitsOffline(session,id,now=Date.now(),mono=performance.now()){return leaseValid(session,now,mono,true)&&session.sites.some(s=>s.id===id)}
export function installationId(){
 const key='bootik-installation-id';const re=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
 try{const saved=localStorage.getItem(key);if(saved&&re.test(saved))return saved;const id=crypto.randomUUID();localStorage.setItem(key,id);return id}catch{return crypto.randomUUID()}
}
export async function login(base,identifier,password,fetcher=fetch){
 if(!identifier.trim()||!password)throw Error("INVALID_CREDENTIALS");
 if(!base||!/^https:\/\//.test(base))throw Error("BOOTIK_API_NOT_CONFIGURED");
 const endpoint=new URL(base.replace(/\/$/,"")+"/login");if(endpoint.username||endpoint.password)throw Error("INVALID_API");
 const res=await fetcher(endpoint,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"BOOTIK",identifier:identifier.trim(),password,installation_id:installationId(),platform:'web'}),cache:"no-store",redirect:"error"});
 if(!res.ok)throw Error("LOGIN_REJECTED");return parseSession(await res.json());
}

export async function authorizedRequest(base,action,body,token,fetcher=fetch){
 if(!["logout","recovery","sync","change-password","onboarding-state","onboarding-step"].includes(action)||!base||!/^https:\/\//.test(base))throw Error("BOOTIK_API_NOT_CONFIGURED");
 const url=new URL(base.replace(/\/$/,"")+"/"+action);if(url.username||url.password)throw Error("INVALID_API");
 const headers={"Content-Type":"application/json",...(token?{"Authorization":"Bearer "+token}:{})};
 const res=await fetcher(url,{method:"POST",headers,body:JSON.stringify({...body,app_id:"BOOTIK"}),cache:"no-store",redirect:"error"});
 if(!res.ok)throw Error("REQUEST_REJECTED");return res.status===204?{}:res.json();
}
