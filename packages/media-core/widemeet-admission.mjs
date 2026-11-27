// Server-only bridge to existing WideMeet authorization. No sister data or client
// supplied roles. Pass service key via environment, never in browser bundles.
import {mediaPermission} from "../widemeet-domain/room-policy.mjs";
import {createReceiverAdmission,isWideMeetReceiver} from "./widemeet-receiver.mjs";
export function createWideMeetAdmission({supabaseUrl,serviceKey,fetcher=fetch,sourceActive=async()=>false}){
 const base=new URL(supabaseUrl);
 if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||typeof serviceKey!=="string"||!serviceKey)throw Error("invalid backend");
 async function rpc(name,body){
 const r=await fetcher(new URL("/rest/v1/rpc/"+name,base),{method:"POST",headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"},body:JSON.stringify(body),cache:"no-store",redirect:"error",signal:AbortSignal.timeout(3000)});
 if(!r.ok)throw Error("admission unavailable");return r.json();
 }
 const receiver=createReceiverAdmission({readLease:async id=>{
  const v=await rpc("wm_display_context",{p_id:id});
  if(!v||!await sourceActive("wm-"+v.ctx.meeting.id,v.ctx.actor.memberId,v.source_hash))return null;
  return v;
 }});
 return async grant=>{
 if(isWideMeetReceiver(grant?.identity))return receiver(grant);
 if(grant.app!=="wm"||!/^[a-f0-9]{64}$/.test(grant.sessionHash??"")||!/^wm-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(grant.room))return null;
 const p_hash=grant.sessionHash,p_room=grant.room.slice(3);
 const [actors,room]=await Promise.all([rpc("wm_room_actor_for",{p_hash,p_room}),rpc("wm_room_read",{p_hash,p_room})]);
 const a=actors?.[0];
 if(!a||a.account_id!==grant.identity||!room)return null;
 const now=Date.now(),actor={memberId:a.account_id,workspaceId:a.workspace_id,enabled:true,passwordChangeRequired:false,role:a.role,plan:a.plan,entitlementEndMs:a.entitlement_end_ms};
 const permission=mediaPermission(room,actor,now);
 if(!permission||permission.room!==grant.room||permission.memberId!==grant.identity)return null;
 return {app:"wm",room:grant.room,identity:grant.identity,enabled:true,admitted:true,status:"open",endMs:Math.min(room.endMs,actor.entitlementEndMs),sources:["camera",...(permission.microphone?["microphone"]:[]),...(permission.screen?["screen_share"]:[]),...(permission.microphone&&permission.screen?["screen_share_audio"]:[])],canPublish:permission.canPublish};
 };
}
