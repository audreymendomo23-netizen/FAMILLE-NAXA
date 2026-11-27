// Adapted from NAXA SERVICES notification_contract.ts + notifications/index.ts.
export const OAUTH="https://oauth2.googleapis.com/token";
const b64=b=>{let v="";for(let i=0;i<b.length;i+=16384)v+=String.fromCharCode(...b.subarray(i,i+16384));return btoa(v)};
const unb64=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
const enc=new TextEncoder();
const url64=b=>b64(b).replaceAll("+","-").replaceAll("/","_").replace(/=+$/,"");
const hex=b=>Array.from(b,x=>x.toString(16).padStart(2,"0")).join("");
export async function fingerprint(token){return hex(new Uint8Array(await crypto.subtle.digest("SHA-256",enc.encode(token))))}
export function validPushToken(t){return typeof t==="string"&&t.length>=30&&t.length<=4096&&!/\s/.test(t)}
async function key(raw){if(typeof raw!=="string"||! /^[a-f0-9]{64}$/.test(raw))throw Error("PUSH_ENCRYPTION_UNAVAILABLE");return crypto.subtle.importKey("raw",Uint8Array.from(raw.match(/../g),x=>parseInt(x,16)),"AES-GCM",false,["encrypt","decrypt"])}
export async function encryptToken(token,raw){
 if(!validPushToken(token))throw Error("INVALID_PUSH_TOKEN");
 const iv=crypto.getRandomValues(new Uint8Array(12)),fp=await fingerprint(token);
 const bytes=await crypto.subtle.encrypt({name:"AES-GCM",iv,additionalData:enc.encode("WIDEMEET:"+fp)},await key(raw),enc.encode(token));
 return {fingerprint:fp,ciphertext:b64(new Uint8Array(bytes)),iv:b64(iv)};
}
export async function decryptToken(row,raw){
 const bytes=await crypto.subtle.decrypt({name:"AES-GCM",iv:unb64(row.iv),additionalData:enc.encode("WIDEMEET:"+row.fingerprint)},await key(raw),unb64(row.ciphertext));
 const token=new TextDecoder().decode(bytes);if(!validPushToken(token)||await fingerprint(token)!==row.fingerprint)throw Error("PUSH_TOKEN_INTEGRITY");return token;
}
export function serviceAccount(raw,project){
 if(typeof project!=="string"||!/^widemeet-[a-z0-9-]{1,20}[a-z0-9]$/.test(project))throw Error("WIDEMEET_FCM_PROJECT_REQUIRED");
 const a=JSON.parse(raw);if(a.project_id!==project||typeof a.client_email!=="string"||!a.client_email.endsWith("@"+project+".iam.gserviceaccount.com")||typeof a.private_key!=="string"||!a.private_key.includes("-----BEGIN PRIVATE KEY-----")||(a.token_uri!=null&&a.token_uri!==OAUTH))throw Error("FCM_SCOPE");
 return a;
}
export async function accessToken(a,fetcher=fetch){
 const now=Math.floor(Date.now()/1000),unsigned=url64(enc.encode(JSON.stringify({alg:"RS256",typ:"JWT"})))+"."+url64(enc.encode(JSON.stringify({iss:a.client_email,scope:"https://www.googleapis.com/auth/firebase.messaging",aud:OAUTH,iat:now,exp:now+3600})));
 const privateKey=await crypto.subtle.importKey("pkcs8",unb64(a.private_key.replaceAll("\\n","\n").replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,"")),{name:"RSASSA-PKCS1-v1_5",hash:"SHA-256"},false,["sign"]);
 const assertion=unsigned+"."+url64(new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5",privateKey,enc.encode(unsigned))));
 const r=await fetcher(OAUTH,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:new URLSearchParams({grant_type:"urn:ietf:params:oauth:grant-type:jwt-bearer",assertion}),redirect:"error",signal:AbortSignal.timeout(10000)});
 const j=await r.json().catch(()=>null);if(!r.ok||typeof j?.access_token!=="string"||!j.access_token)throw Error("FCM_AUTH_UNCONFIRMED");return j.access_token;
}
export async function sendPush({project,access,token,id,fetcher=fetch}){
 // Generic lock-screen message, no meeting title, account, room, transcript, token or URL in payload.
 if(!/^widemeet-[a-z0-9-]{1,20}[a-z0-9]$/.test(project)||!validPushToken(token)||!/^[0-9a-f-]{36}$/.test(id))throw Error("FCM_SCOPE");
 try{
 const r=await fetcher("https://fcm.googleapis.com/v1/projects/"+project+"/messages:send",{method:"POST",headers:{Authorization:"Bearer "+access,"Content-Type":"application/json"},body:JSON.stringify({message:{token,notification:{title:"WideMeet",body:"Nouvelle notification / New notification"},data:{app_id:"WIDEMEET",notification_id:id},android:{notification:{tag:id},ttl:"120s"},webpush:{headers:{TTL:"120"},notification:{tag:id}}}}),redirect:"error",signal:AbortSignal.timeout(10000)});
 const j=await r.json().catch(()=>null);const prefix="projects/"+project+"/messages/";
 if(r.ok&&typeof j?.name==="string"&&j.name.startsWith(prefix)&&/^[A-Za-z0-9_:%.-]{1,256}$/.test(j.name.slice(prefix.length)))return {status:"accepted",reference:j.name,error:null,revoke:false};
 const code=j?.error?.details?.find(x=>typeof x?.errorCode==="string")?.errorCode??j?.error?.status;
 if(["UNREGISTERED","SENDER_ID_MISMATCH"].includes(code))return {status:"rejected",reference:null,error:code,revoke:true};
 // No automatic retry on ambiguous provider outcome (prevents duplicate display).
 return {status:"uncertain",reference:null,error:"PROVIDER_UNCONFIRMED",revoke:false};
 }catch{return {status:"uncertain",reference:null,error:"PROVIDER_UNCONFIRMED",revoke:false}}
}
export async function dispatchPush({rpc,encryptionKey,project,access,fetcher=fetch,limit=25}){
 const batch=await rpc("wm_push_claim",{p_limit:limit});if(!Array.isArray(batch?.items)||batch.items.length>limit)throw Error("INVALID_CLAIMS");
 let accepted=0,uncertain=0,rejected=0,cancelled=0;
 for(const row of batch.items){
  const claim={p_id:row.id,p_claim:row.claim_token};let outcome;
  try{
   const target=await rpc("wm_push_target",claim);
   if(!target)outcome={status:"cancelled",reference:null,error:"SCOPE_LOST",revoke:false};
   else{
    const token=await decryptToken(target,encryptionKey);
    const again=await rpc("wm_push_target",claim);
    if(!again||again.fingerprint!==target.fingerprint)outcome={status:"cancelled",reference:null,error:"SCOPE_LOST",revoke:false};
    else outcome=await sendPush({project,access,token,id:row.id,fetcher});
   }
  }catch{outcome={status:"uncertain",reference:null,error:"TARGET_UNCONFIRMED",revoke:false}}
  if(await rpc("wm_push_finish",{...claim,p_status:outcome.status,p_reference:outcome.reference,p_error:outcome.error,p_revoke:outcome.revoke})!==true)throw Error("OUTCOME_UNCONFIRMED");
  if(outcome.status==="accepted")accepted++;else if(outcome.status==="rejected")rejected++;else if(outcome.status==="cancelled")cancelled++;else uncertain++;
 }
 return {accepted,rejected,uncertain,cancelled};
}
