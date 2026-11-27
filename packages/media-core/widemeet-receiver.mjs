// Server-only adapter for the existing WideMeet display lease contract and SFU proxy.
import {createHmac} from "node:crypto";
import {displayLeaseAllowed} from "../widemeet-domain/presentation-display.mjs";
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const leaseId=/^[A-Za-z0-9_-]{22,100}$/;
const prefix="wm-display-";
export const isWideMeetReceiver=identity=>typeof identity==="string"&&identity.startsWith(prefix);
export function receiverIdentity(id){if(typeof id!=="string"||!leaseId.test(id))throw Error("invalid receiver lease");return prefix+id}
function authorized(ctx,lease,now){
 return !!ctx&&uuid.test(ctx.meeting?.id??"")&&displayLeaseAllowed(ctx,lease,now)&&leaseId.test(lease.id??"")&&lease.expiresMs<=now+30000;
}
// Trusted callers must load lease + context transactionally; a client may never provide these records.
export function signReceiverGrant({ctx,lease,key,secret,now=Date.now()}){
 if(!authorized(ctx,lease,now)||typeof key!=="string"||!key||typeof secret!=="string"||secret.length<32)throw Error("receiver forbidden");
 const exp=Math.floor(lease.expiresMs/1000);if(exp<=Math.floor(now/1000))throw Error("receiver expired");
 const identity=receiverIdentity(lease.id),room="wm-"+ctx.meeting.id;
 const claims={iss:key,sub:identity,nbf:Math.floor(now/1000)-2,exp,video:{room,roomJoin:true,canPublish:false,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:[],roomAdmin:false,roomCreate:false,roomRecord:false,roomList:false}};
 const enc=x=>Buffer.from(JSON.stringify(x)).toString("base64url"),unsigned=enc({alg:"HS256",typ:"JWT"})+"."+enc(claims);
 return {identity,room,token:unsigned+"."+createHmac("sha256",secret).update(unsigned).digest("base64url"),expiresAt:exp*1000};
}
// The existing proxy checks this on every handshake and during active signaling.
// Its onRevoke callback MUST remove this identity at the SFU, not only close signaling.
export function createReceiverAdmission({readLease,clock=Date.now}){
 if(typeof readLease!=="function")throw Error("trusted lease reader required");
 return async grant=>{
  if(!grant||grant.app!=="wm"||!isWideMeetReceiver(grant.identity)||grant.canPublish!==false||!Array.isArray(grant.sources)||grant.sources.length!==0)return null;
  const id=grant.identity.slice(prefix.length);if(!leaseId.test(id))return null;
  try{const result=await readLease(id),now=clock();if(!result||result.lease?.id!==id||!authorized(result.ctx,result.lease,now)||grant.room!=="wm-"+result.ctx.meeting.id)return null;
   return {app:"wm",room:grant.room,identity:grant.identity,enabled:true,admitted:true,status:"open",endMs:result.lease.expiresMs,sources:[],canPublish:false};
  }catch{return null}
 };
}
