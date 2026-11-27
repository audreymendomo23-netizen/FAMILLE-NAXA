// Trusted SFU transport observations, not client heartbeats.
import {randomUUID} from "node:crypto";
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export function createWideMeetPresence({supabaseUrl,serviceKey,sfu,fetcher=fetch}){
 const base=new URL(supabaseUrl);if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey||typeof sfu?.listParticipants!=="function")throw Error("invalid presence configuration");
 const pending=new Map();
 async function observe(roomId){
  if(!uuid.test(roomId))throw Error("invalid room");
  if(pending.has(roomId))return pending.get(roomId);
  const p=(async()=>{const participants=await sfu.listParticipants("wm-"+roomId);
   // LiveKit ParticipantInfo.State.ACTIVE = 2 (ICE connected).
   const identities=[...new Set(participants.filter(p=>p.state===2&&uuid.test(p.identity)).map(p=>p.identity))];
   const r=await fetcher(new URL("/rest/v1/rpc/wm_presence_record",base),{method:"POST",headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"},body:JSON.stringify({p_room:roomId,p_sample:randomUUID(),p_accounts:identities}),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(4000)});
   if(!r.ok)throw Error("presence ledger unavailable");return {persisted:await r.json()===true,observed:identities.length};
  })().finally(()=>pending.delete(roomId));pending.set(roomId,p);return p;
 }
 return {observe};
}
