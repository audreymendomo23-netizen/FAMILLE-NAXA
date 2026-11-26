export function parseSession(j,now=Date.now()){
 if(!j||j.app_id!=="ZIPPLE"||typeof j.access_token!=="string"||j.access_token.length<20||typeof j.member_id!=="string"||!j.member_id||typeof j.organization_id!=="string"||!j.organization_id||!["promoteur","manager","staff"].includes(j.role)||!Number.isSafeInteger(j.expires_at)||j.expires_at<=now||!Array.isArray(j.sites)||!j.sites.length||j.sites.some(s=>!s||typeof s.id!=="string"||!s.id||typeof s.name!=="string")||new Set(j.sites.map(s=>s.id)).size!==j.sites.length)throw Error("INVALID_ZIPPLE_SESSION");
 return Object.freeze({...j,sites:Object.freeze(j.sites.map(s=>Object.freeze({...s})))});
}
export function permitsSite(session,id,now=Date.now()){return !!session&&session.expires_at>now&&session.sites.some(s=>s.id===id)}
export async function login(base,identifier,password,fetcher=fetch){
 if(!identifier.trim()||!password)throw Error("INVALID_CREDENTIALS");
 if(!base||!/^https:\/\//.test(base))throw Error("ZIPPLE_API_NOT_CONFIGURED");
 const endpoint=new URL(base.replace(/\/$/,"")+"/login");if(endpoint.username||endpoint.password)throw Error("INVALID_API");
 const res=await fetcher(endpoint,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({app_id:"ZIPPLE",identifier:identifier.trim(),password}),cache:"no-store",redirect:"error"});
 if(!res.ok)throw Error("LOGIN_REJECTED");return parseSession(await res.json());
}

export async function authorizedRequest(base,action,body,token,fetcher=fetch){
 if(!["logout","recovery","sync"].includes(action)||!base||!/^https:\/\//.test(base))throw Error("ZIPPLE_API_NOT_CONFIGURED");
 const url=new URL(base.replace(/\/$/,"")+"/"+action);if(url.username||url.password)throw Error("INVALID_API");
 const headers={"Content-Type":"application/json",...(token?{"Authorization":"Bearer "+token}:{})};
 const res=await fetcher(url,{method:"POST",headers,body:JSON.stringify({...body,app_id:"ZIPPLE"}),cache:"no-store",redirect:"error"});
 if(!res.ok)throw Error("REQUEST_REJECTED");return res.status===204?{}:res.json();
}
