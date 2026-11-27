// WideMeet room gateway candidate. Uses NS media grant design and the WideMeet domain policy.
import {createRoom,applyRoom,mediaPermission,pollSummary} from "../../../packages/widemeet-domain/room-policy.mjs";
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
 const admitted=self.response==="accepted"&&(room.lobbyRequired!==true||self.memberId===room.hostId||self.lobbyStatus==="admitted");
 const result={id:room.id,title:room.title,description:room.description,hostId:room.hostId,status:room.status,revision:room.revision,scheduledMs:room.scheduledMs,durationMinutes:room.durationMinutes,endMs:room.endMs??null,response:self.response,cancelled:room.cancelled===true,admissionLocked:room.admissionLocked===true,lobbyRequired:room.lobbyRequired===true,lobbyStatus:self.lobbyStatus??null,serverNowMs:Date.now(),recording:admitted?room.recording:"off",recordingPaused:admitted&&room.recordingPaused===true,participants:admitted?room.participants.filter((p:any)=>!p.excluded).map((p:any)=>({memberId:p.memberId,response:p.response,lobbyStatus:p.lobbyStatus??null,hand:p.hand===true,mic:p.mic===true,screen:p.screen===true})):[],events:admitted?room.events.filter((e:any)=>["chat","reaction"].includes(e.action)||e.action==="private_chat"&&(e.actor===actor.memberId||JSON.parse(e.payload)[1]===actor.memberId)).slice(-100).map((e:any)=>({id:e.id,actor:e.actor,action:e.action,target:e.action==="private_chat"?JSON.parse(e.payload)[1]:null,value:JSON.parse(e.payload)[2],at:e.at})):[],polls:admitted?room.polls.map((p:any)=>pollSummary(p,actor.memberId)):[]};
 // Do not return raw receipts, votes, consent ledger, or provider recording state.
 return result;
}
async function project(room:any,actor:any,p_hash:string){
 const result=projection(room,actor);
 if(Deno.env.get("WM_RECORDING_QUALIFIED")!=="true")return result;
 try{
 const recordingStatus=await rpc("wm_recording_status",{p_hash,p_room:room.id});
 return {...result,recordingStatus:recordingStatus??{phase:"off"}};
 }catch{return {...result,recordingStatus:{phase:"unconfirmed"}}}
}
const enc=(s:Uint8Array)=>btoa(String.fromCharCode(...s)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
const json=(v:unknown)=>enc(new TextEncoder().encode(JSON.stringify(v)));
async function signGrant(grant:any,now:number,sessionHash:string){
 if(!/^[a-f0-9]{64}$/.test(sessionHash))throw Error("media_unavailable");
 if(Deno.env.get("WM_MEDIA_QUALIFIED")!=="true")throw Error("media_unavailable");
 const key=Deno.env.get("WM_LIVEKIT_API_KEY")??"",secret=Deno.env.get("WM_LIVEKIT_API_SECRET")??"";
 const endpoint=new URL(Deno.env.get("WM_LIVEKIT_URL")??"");
 if(endpoint.protocol!=="wss:"||endpoint.username||endpoint.password||endpoint.pathname!=="/"||endpoint.search||endpoint.hash||!/^[A-Za-z0-9_-]{8,128}$/.test(key)||secret.length<32)throw Error("media_unavailable");
 const exp=Math.floor(grant.expiresMs/1000),nbf=Math.floor(now/1000)-5;
 if(exp<=Math.floor(now/1000))throw Error("media_unavailable");
 const claims={iss:key,sub:grant.memberId,nbf,exp,wm_session_hash:sessionHash,video:{room:grant.room,roomJoin:true,canPublish:grant.canPublish,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:["camera",...(grant.microphone?["microphone"]:[]),...(grant.screen?["screen_share"]:[]),...(grant.microphone&&grant.screen?["screen_share_audio"]:[])],roomAdmin:false,roomCreate:false,roomRecord:false,roomList:false}};
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
 const action=new URL(request.url).pathname.split("/").filter(Boolean).at(-1);
 if(action==="tasks"){
 if(Deno.env.get("WM_MINUTES_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 if(!["list","create","submit","approve","return","cancel"].includes(b.action)||!b.data||typeof b.data!=="object"||Array.isArray(b.data))return send(400,{error:"invalid_request"});
 const result=await rpc("wm_task_action",{p_hash,p_action:b.action,p_data:b.data});
 return result?send(200,result):send(403,{error:"forbidden"});
 }
 if(action==="minutes"){
 if(Deno.env.get("WM_MINUTES_QUALIFIED")!=="true")return send(503,{error:"unavailable"});
 if(!["list","prepare","read","draft","approve","publish","revoke"].includes(b.action)||!b.data||typeof b.data!=="object"||Array.isArray(b.data))return send(400,{error:"invalid_request"});
 const result=await rpc("wm_minutes_action",{p_hash,p_action:b.action,p_data:b.data});
 return result?send(200,result):send(403,{error:"forbidden"});
 }
 if(action==="pass-list"){
 const session=(await rpc("wm_session_context",{p_hash}))?.[0];if(!session||session.password_change_required)return send(403,{error:"forbidden"});
 return send(200,await rpc("wm_pass_list",{p_hash}));
 }
 if(action==="list"||action==="contacts"){
 const regular=(await rpc("wm_room_actor",{p_hash}))?.[0];
 if(!regular){const passes=await rpc("wm_pass_list",{p_hash});if(!Array.isArray(passes)||!passes.length)return send(403,{error:"forbidden"});}
 return send(200,await rpc(action==="list"?"wm_room_list":"wm_room_contacts",{p_hash}));
 }
 if(!uuid.test(b.room_id??""))return send(400,{error:"invalid_room"});
 const p_room=b.room_id.toLowerCase();
 const passId=action==="create"&&b.pass_id!=null?b.pass_id:null;
 if(passId!==null&&!uuid.test(passId))return send(400,{error:"invalid_pass"});
 const a=(await rpc(passId!==null?"wm_pass_actor":"wm_room_actor_for",passId!==null?{p_hash,p_intent:passId}:{p_hash,p_room:action==="create"?null:p_room}))?.[0];
 if(!a||!["owner","promoteur","manager","staff"].includes(a.role)||!["access","premium"].includes(a.plan)||!Number.isSafeInteger(a.entitlement_end_ms)||a.entitlement_end_ms<=now)return send(403,{error:"forbidden"});
 const actor={memberId:a.account_id,workspaceId:a.workspace_id,enabled:true,passwordChangeRequired:false,role:a.role,plan:a.plan,entitlementEndMs:a.entitlement_end_ms,capacity:Number.isInteger(a.capacity)?a.capacity:undefined};
 if(action==="create"){
 if(!Array.isArray(b.invitees)||b.invitees.length>100||!b.invitees.every((id:unknown)=>typeof id==="string"&&uuid.test(id)))return send(400,{error:"invalid_invitees"});
 const state=createRoom(actor,{id:p_room,title:b.title,description:b.description??"",startMs:b.scheduled_ms,durationMinutes:b.duration_minutes,hardEndMs:actor.entitlementEndMs,invitees:b.invitees.map((id:string)=>id.toLowerCase())});
 if(passId!==null&&b.invitees.length+1>a.capacity)return send(409,{error:"capacity_exceeded"});
 if(await rpc(passId!==null?"wm_pass_room_create":"wm_room_create",passId!==null?{p_hash,p_intent:passId,p_state:state}:{p_hash,p_state:state})!==true)return send(409,{error:"conflict_or_scope"});
 return send(201,await project(state,actor,p_hash));
 }
 const room=await rpc("wm_room_read",{p_hash,p_room});
 if(!room)return send(404,{error:"unavailable"});
 if(action==="read")return send(200,await project(room,actor,p_hash));
 if(action==="command"){
 const command={roomId:p_room,requestId:b.request_id,expectedRevision:b.expected_revision,action:b.action,target:b.target,value:b.value};
 if(command.action==="invite_member"&&!uuid.test(command.target??""))return send(400,{error:"invalid_invitees"});
 const next=applyRoom(room,actor,command,now);
 if(!next.replayed&&command.action==="record"&&command.value===true&&Deno.env.get("WM_RECORDING_QUALIFIED")==="true"){const status=await rpc("wm_recording_status",{p_hash,p_room});if(["starting","active","stopping"].includes(status?.phase))return send(409,{error:"recording_busy"});}
 if(!next.replayed&&await rpc("wm_room_write",{p_hash,p_room,p_expected:room.revision,p_role:actor.role,p_plan:actor.plan,p_state:next.room})!==true)return send(409,{error:"revision_or_scope_changed"});
 return send(200,await project(next.room,actor,p_hash));
 }
 if(action==="media-grant"){
 const grant=mediaPermission(room,actor,now);if(!grant)return send(403,{error:"forbidden"});
 // Remains disabled until SFU eviction and actual audio/video Replay qualify.
 return send(200,await signGrant(grant,now,p_hash));
 }
 return send(404,{error:"unavailable"});
 }catch(e){const code=e instanceof Error?e.message:"unavailable";const publicErrors=new Set(["forbidden","invalid_room","invalid_command","invalid_response","invalid_state","invalid_target","invalid_chat","invalid_reaction","invalid_hand","invalid_screen","invalid_poll","invalid_vote","invalid_record","invalid_consent","consent_required","premium_required","entitlement_required","room_unavailable","revision_conflict","idempotency_conflict","rate_limit","unknown_action","media_unavailable","limit_exceeded","invalid_request","not_active"]);return send(publicErrors.has(code)?409:503,{error:publicErrors.has(code)?code:"unavailable"});}
});
