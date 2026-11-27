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

export function boundedPresentationSize(sourceWidth,sourceHeight,profile){
 if(!Number.isFinite(sourceWidth)||!Number.isFinite(sourceHeight)||sourceWidth<2||sourceHeight<2||!profile||!Number.isFinite(profile.width)||!Number.isFinite(profile.height)||profile.width<2||profile.height<2)throw Error("invalid_dimensions");
 const landscape=sourceWidth>=sourceHeight,maxW=landscape?profile.width:profile.height,maxH=landscape?profile.height:profile.width;
 const scale=Math.min(1,maxW/sourceWidth,maxH/sourceHeight);
 return {width:Math.max(2,2*Math.floor(sourceWidth*scale/2)),height:Math.max(2,2*Math.floor(sourceHeight*scale/2)),frameRate:profile.fps};
}
// Actual browser screen track only: no camera sender is touched.
export async function configurePresentationTrack(track,profile,sourceSize){
 const media=track?.mediaStreamTrack,sender=track?.sender;
 if(!media||media.kind!=="video"||typeof media.applyConstraints!=="function"||!sender||typeof sender.getParameters!=="function")throw Error("screen_track_unavailable");
 const size=boundedPresentationSize(sourceSize.width,sourceSize.height,profile);
 await media.applyConstraints({width:{max:size.width},height:{max:size.height},frameRate:{max:size.frameRate},aspectRatio:{ideal:sourceSize.width/sourceSize.height}});
 const params=sender.getParameters();if(!params.encodings?.length)throw Error("screen_encoding_unavailable");
 for(const e of params.encodings){e.maxBitrate=profile.maxBitrate;e.maxFramerate=profile.fps}
 await sender.setParameters(params);return size;
}
