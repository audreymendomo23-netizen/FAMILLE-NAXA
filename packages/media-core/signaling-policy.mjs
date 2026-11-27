// Shared NAXA media policy: no browser holds a server key. The SFU signaling
// endpoint is private; the public gateway must authorize every handshake.
import {createHmac,timingSafeEqual} from "node:crypto";
const apps=new Set(["wm","ns"]);
const validName=s=>typeof s==="string"&&/^(wm|ns)-[a-z0-9-]{8,100}$/.test(s);
export function verifyJoinToken(token,{key,secret,now=Date.now()}){
 try{
 if(typeof token!=="string"||token.length>8192||typeof secret!=="string"||secret.length<32)return null;
 const parts=token.split(".");if(parts.length!==3||parts.some(p=>!p||!/^[A-Za-z0-9_-]+$/.test(p)))return null;
 const [h,b,s]=parts,header=JSON.parse(Buffer.from(h,"base64url")),claims=JSON.parse(Buffer.from(b,"base64url"));
 if(header.alg!=="HS256"||claims.iss!==key||typeof claims.sub!=="string"||!claims.sub||claims.sub.length>128||!Number.isSafeInteger(claims.exp)||claims.exp*1000<=now||!Number.isSafeInteger(claims.nbf)||claims.nbf*1000>now+5000||claims.exp*1000>now+120000)return null;
 const expected=createHmac("sha256",secret).update(h+"."+b).digest(),actual=Buffer.from(s,"base64url");
 if(actual.length!==expected.length||!timingSafeEqual(actual,expected))return null;
 const v=claims.video;if(!v||v.roomJoin!==true||!validName(v.room)||v.roomAdmin||v.roomCreate||v.roomRecord||v.roomList||v.canSubscribe!==true||v.canPublishData!==false||v.canUpdateOwnMetadata!==false)return null;
 const sources=v.canPublishSources;if(!Array.isArray(sources)||sources.some(x=>!["camera","microphone","screen_share","screen_share_audio"].includes(x))||new Set(sources).size!==sources.length)return null;
 return {app:v.room.split("-")[0],room:v.room,identity:claims.sub,sessionHash:typeof claims.wm_session_hash==="string"?claims.wm_session_hash:null,expiresAt:claims.exp*1000,sources,canPublish:v.canPublish===true};
 }catch{return null}
}
export function allowedJoin(grant,state,now=Date.now()){
 if(!grant||!state||!apps.has(grant.app)||state.app!==grant.app||state.room!==grant.room||state.identity!==grant.identity||state.enabled!==true||state.admitted!==true||state.status!=="open"||!Number.isSafeInteger(state.endMs)||state.endMs<=now||grant.expiresAt<=now||!Array.isArray(state.sources)||grant.sources.some(s=>!state.sources.includes(s))||grant.canPublish&&!state.canPublish)return false;
 return true;
}
