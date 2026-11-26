// Pure policy only. Load every context field from trusted server records, never client claims.
// Intent/lease IDs require CSPRNG on server, hash stored credential; redemption and issuance atomically locked.
// The SFU must actively disconnect receivers on revoke/expiry; this module does not transport or record media.
export const PRESENTATION_PROFILES=Object.freeze(Object.fromEntries(Object.entries({"low":{"width":640,"height":360,"fps":10,"maxBitrate":450000},"medium":{"width":1280,"height":720,"fps":15,"maxBitrate":1200000},"high":{"width":1920,"height":1080,"fps":30,"maxBitrate":2500000}}).map(([k,v])=>[k,Object.freeze(v)])));
export function presentationProfile(preferred,networkCeiling,policyCeiling){
 const ranks=["low","medium","high"];
 if(![preferred,networkCeiling,policyCeiling].every(v=>ranks.includes(v)))throw new Error("invalid_quality");
 const effective=ranks[Math.min(...[preferred,networkCeiling,policyCeiling].map(v=>ranks.indexOf(v)))];
 return {preferred,effective,...PRESENTATION_PROFILES[effective]};
}
function assertDisplayContext(ctx,nowMs){
 const {meeting,actor,source,receiver,policy}=ctx??{};
 if(!meeting||!meeting.id||!meeting.orgId||!Number.isSafeInteger(nowMs)||nowMs<0||nowMs>Number.MAX_SAFE_INTEGER-60000||!Number.isSafeInteger(meeting.endMs)||nowMs>=meeting.endMs||meeting.status!=="open")throw new Error("meeting_unavailable");
 if(!["standard","confidential"].includes(meeting.confidentiality))throw new Error("display_forbidden");
 if(policy?.displayEnabled!==true||actor?.enabled!==true||actor?.displayAllowed!==true||actor.orgId!==meeting.orgId||actor.meetingId!==meeting.id||!actor.memberId||source?.active!==true||source.memberId!==actor.memberId||source.orgId!==meeting.orgId||source.meetingId!==meeting.id||!source.id)throw new Error("forbidden");
 if(receiver?.approved!==true||receiver?.active!==true||receiver?.kind!=="widemeet_receiver"||receiver.memberId!==actor.memberId||receiver.orgId!==meeting.orgId||!receiver.id||receiver.id===source.id)throw new Error("receiver_forbidden");
 if(meeting.confidentiality==="confidential"&&(policy.confidentialDisplayAllowed!==true||receiver.confidentialQualified!==true))throw new Error("receiver_not_qualified");
}
export function makeDisplayIntent(ctx,nowMs,intentId){
 assertDisplayContext(ctx,nowMs);
 if(typeof intentId!=="string"||!/^[A-Za-z0-9_-]{22,128}$/.test(intentId))throw new Error("invalid_intent");
 const {meeting,actor,source,receiver}=ctx;
 return {id:intentId,orgId:meeting.orgId,meetingId:meeting.id,memberId:actor.memberId,sourceId:source.id,receiverId:receiver.id,expiresMs:Math.min(nowMs+60000,meeting.endMs),used:false};
}
export function redeemDisplayIntent(ctx,intent,nowMs,leaseId){
 assertDisplayContext(ctx,nowMs);
 const {meeting,actor,source,receiver}=ctx;
 if(typeof leaseId!=="string"||!/^[A-Za-z0-9_-]{22,128}$/.test(leaseId))throw new Error("invalid_lease");
 if(!intent||intent.used!==false||!Number.isSafeInteger(intent.expiresMs)||nowMs>=intent.expiresMs||intent.orgId!==meeting.orgId||intent.meetingId!==meeting.id||intent.memberId!==actor.memberId||intent.sourceId!==source.id||intent.receiverId!==receiver.id)throw new Error("intent_invalid");
 return {intent:{...intent,used:true},lease:{id:leaseId,orgId:meeting.orgId,meetingId:meeting.id,memberId:actor.memberId,sourceId:source.id,receiverId:receiver.id,expiresMs:Math.min(nowMs+30000,meeting.endMs),revoked:false,canSubscribe:true,canPublish:false,canRecord:false,canChat:false,canControl:false}};
}
export function displayLeaseAllowed(ctx,lease,nowMs){
 try{assertDisplayContext(ctx,nowMs);const {meeting,actor,source,receiver}=ctx;
 return !!lease&&lease.revoked===false&&Number.isSafeInteger(lease.expiresMs)&&nowMs<lease.expiresMs&&lease.orgId===meeting.orgId&&lease.meetingId===meeting.id&&lease.memberId===actor.memberId&&lease.sourceId===source.id&&lease.receiverId===receiver.id&&lease.canSubscribe===true&&["canPublish","canRecord","canChat","canControl"].every(k=>lease[k]===false);
 }catch{return false}
}
