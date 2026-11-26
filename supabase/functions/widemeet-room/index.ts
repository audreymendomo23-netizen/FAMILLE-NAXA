// WideMeet room gateway candidate. Uses NS media grant design and the WideMeet domain policy.
import {createRoom,applyRoom,mediaPermission} from "../../../packages/widemeet-domain/room-policy.mjs";
const base=(Deno.env.get("SUPABASE_URL")??"").replace(/\/$/,"");
const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
const origins=new Set((Deno.env.get("WM_ALLOWED_ORIGINS")??"").split(",").map(x=>x.trim()).filter(Boolean));
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const hash=async (s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s))),x=>x.toString(16).padStart(2,"0")).join("");
async function rpc(name:string,body:Record<string,unknown>){
 const r=await fetch(base+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"},body:JSON.stringify(body),redirect:"error",cache:"no-store"});
 if(!r.ok)throw Error("backend_unavailable");return r.status===204?null:await r.json();
}
function projection(room:any,actor:any){
 const self=room.participants.find((p:any)=>p.memberId===actor.memberId&&!p.excluded);
 if(!self)throw Error("forbidden");
 const admitted=self.response==="accepted";
 const result={id:room.id,hostId:room.hostId,status:room.status,revision:room.revision,scheduledMs:room.scheduledMs,durationMinutes:room.durationMinutes,endMs:room.endMs??null,response:self.response,recording:admitted?room.recording:"off",participants:admitted?room.participants.filter((p:any)=>!p.excluded).map((p:any)=>({memberId:p.memberId,response:p.response,hand:p.hand===true,mic:p.mic===true,screen:p.screen===true})):[],events:admitted?room.events.filter((e:any)=>["chat","reaction"].includes(e.action)).slice(-100).map((e:any)=>({id:e.id,actor:e.actor,action:e.action,value:JSON.parse(e.payload)[2],at:e.at})):[],polls:admitted?room.polls.map((p:any)=>({id:p.id,options:p.options,open:p.open,counts:p.options.map((_:unknown,i:number)=>Object.values(p.votes).filter(v=>v===i).length),voted:Object.hasOwn(p.votes,actor.memberId)})):[]};
 // Do not return raw receipts, votes, consent ledger, or provider recording state.
 return result;
}
const enc=(s:Uint8Array)=>btoa(String.fromCharCode(...s)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
const json=(v:unknown)=>enc(new TextEncoder().encode(JSON.stringify(v)));
async function signGrant(grant:any,now:number){
 if(Deno.env.get("WM_MEDIA_QUALIFIED")!=="true")throw Error("media_unavailable");
 const key=Deno.env.get("WM_LIVEKIT_API_KEY")??"",secret=Deno.env.get("WM_LIVEKIT_API_SECRET")??"";
 const endpoint=new URL(Deno.env.get("WM_LIVEKIT_URL")??"");
 if(endpoint.protocol!=="wss:"||endpoint.username||endpoint.password||endpoint.pathname!=="/"||endpoint.search||endpoint.hash||!/^[A-Za-z0-9_-]{8,128}$/.test(key)||secret.length<32)throw Error("media_unavailable");
 const exp=Math.floor(grant.expiresMs/1000),nbf=Math.floor(now/1000)-5;
 if(exp<=Math.floor(now/1000))throw Error("media_unavailable");
 const claims={iss:key,sub:grant.memberId,nbf,exp,video:{room:grant.room,roomJoin:true,canPublish:grant.canPublish,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:["camera",...(grant.microphone?["microphone"]:[]),...(grant.screen?["screen_share"]:[]),...(grant.microphone&&grant.screen?["screen_share_audio"]:[])],roomAdmin:false,roomCreate:false,roomRecord:false,roomList:false}};
 const k=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
 const data=json({alg:"HS256",typ:"JWT"})+"."+json(claims);
 const sig=await crypto.subtle.sign("HMAC",k,new TextEncoder().encode(data));
 return {url:endpoint.origin,token:data+"."+enc(new Uint8Array(sig)),expires_at:exp*1000};
}
Deno.serve(async request=>{
 const origin=request.headers.get("origin");
 const cors:Record<string,string>=origin&&origins.has(origin)?{"Access-Control-Allow-Origin":origin,"Vary":"Origin","Access-Control-Allow-Headers":"content-type,authorization,apikey","Access-Control-Allow-Methods":"POST,OPTIONS"}:{};
 const send=(status:number,body:unknown)=>new Response(status===204?null:JSON.stringify(body),{status,headers:{"Content-Type":"application/json","Cache-Control":"no-store",...cors}});
 if(origin&&!origins.has(origin))return send(403,{error:"forbidden"});
 if(request.method==="OPTIONS")return send(204,null);
 if(request.method!=="POST")return send(405,{error:"method"});
 if(Deno.env.get("WM_ROOM_QUALIFIED")!=="true"||!base||!service)return send(503,{error:"unavailable"});
 try{
 const token=(request.headers.get("authorization")??"").replace(/^Bearer /i,"");
 if(!/^[a-f0-9]{64}$/.test(token))return send(401,{error:"credentials"});
 const text=await request.text();if(text.length>16384)return send(413,{error:"too_large"});
 const b=JSON.parse(text);if(b?.app_id!=="WIDEMEET")return send(403,{error:"forbidden"});
 const p_hash=await hash(token),now=Date.now();
 const a=(await rpc("wm_room_actor",{p_hash}))?.[0];
 if(!a||!["owner","promoteur","manager","staff"].includes(a.role)||!["access","premium"].includes(a.plan)||!Number.isSafeInteger(a.entitlement_end_ms)||a.entitlement_end_ms<=now)return send(403,{error:"forbidden"});
 const actor={memberId:a.account_id,workspaceId:a.workspace_id,enabled:true,passwordChangeRequired:false,role:a.role,plan:a.plan,entitlementEndMs:a.entitlement_end_ms};
 const action=new URL(request.url).pathname.split("/").filter(Boolean).at(-1);
 if(!uuid.test(b.room_id??""))return send(400,{error:"invalid_room"});
 const p_room=b.room_id.toLowerCase();
 if(action==="create"){
 if(!Array.isArray(b.invitees)||b.invitees.length>100||!b.invitees.every((id:unknown)=>typeof id==="string"&&uuid.test(id)))return send(400,{error:"invalid_invitees"});
 const state=createRoom(actor,{id:p_room,startMs:b.scheduled_ms,durationMinutes:b.duration_minutes,hardEndMs:actor.entitlementEndMs,invitees:b.invitees.map((id:string)=>id.toLowerCase())});
 if(await rpc("wm_room_create",{p_hash,p_state:state})!==true)return send(409,{error:"conflict_or_scope"});
 return send(201,projection(state,actor));
 }
 const room=await rpc("wm_room_read",{p_hash,p_room});
 if(!room)return send(404,{error:"unavailable"});
 if(action==="read")return send(200,projection(room,actor));
 if(action==="command"){
 const command={roomId:p_room,requestId:b.request_id,expectedRevision:b.expected_revision,action:b.action,target:b.target,value:b.value};
 const next=applyRoom(room,actor,command,now);
 if(!next.replayed&&await rpc("wm_room_write",{p_hash,p_room,p_expected:room.revision,p_role:actor.role,p_plan:actor.plan,p_state:next.room})!==true)return send(409,{error:"revision_or_scope_changed"});
 return send(200,projection(next.room,actor));
 }
 if(action==="media-grant"){
 const grant=mediaPermission(room,actor,now);if(!grant)return send(403,{error:"forbidden"});
 // Remains disabled until SFU eviction and actual audio/video Replay qualify.
 return send(200,await signGrant(grant,now));
 }
 return send(404,{error:"unavailable"});
 }catch(e){const code=e instanceof Error?e.message:"unavailable";const publicErrors=new Set(["forbidden","invalid_room","invalid_command","invalid_response","invalid_state","invalid_target","invalid_chat","invalid_reaction","invalid_hand","invalid_screen","invalid_poll","invalid_vote","invalid_record","invalid_consent","consent_required","premium_required","entitlement_required","room_unavailable","revision_conflict","idempotency_conflict","rate_limit","unknown_action","media_unavailable"]);return send(publicErrors.has(code)?409:503,{error:publicErrors.has(code)?code:"unavailable"});}
});
