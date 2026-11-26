// WideMeet N2/N3 policy, adapted from NS meeting collaboration v13 and media grant.
// Trusted server state only; persistence must serialize on room id. Not a media transport.
const roles=new Set(["owner","promoteur","manager"]);
const reactions=new Set(["like","clap","heart","laugh","agree","celebrate"]);
const fail=reason=>{throw new Error(reason)};
const id=v=>typeof v==="string"&&/^[A-Za-z0-9_-]{8,128}$/.test(v);
function actor(room,a){
 if(!a||a.enabled!==true||a.workspaceId!==room.workspaceId||!id(a.memberId)||a.passwordChangeRequired!==false)fail("forbidden");
 return a.memberId;
}
function participant(room,a){
 const member=actor(room,a);
 const p=room.participants.find(p=>p.memberId===member);
 if(!p||p.excluded||p.response==="declined")fail("forbidden");
 return p;
}
function live(room,now){
 if(!Number.isSafeInteger(now)||!["open","paused"].includes(room.status)||now>=room.endMs)fail("room_unavailable");
}
export function createRoom(a,c){
 if(!a||a.enabled!==true||a.passwordChangeRequired!==false||!roles.has(a.role)||!id(a.memberId)||!id(a.workspaceId)||!id(c.id)||!Number.isSafeInteger(c.startMs)||c.startMs<0||!Number.isSafeInteger(c.durationMinutes)||c.durationMinutes<5||c.durationMinutes>480||!Number.isSafeInteger(c.hardEndMs)||c.hardEndMs<c.startMs+c.durationMinutes*60000||!Array.isArray(c.invitees)||!c.invitees.every(id)||new Set(c.invitees).size!==c.invitees.length||c.invitees.includes(a.memberId))fail("invalid_room");
 return {id:c.id,workspaceId:a.workspaceId,hostId:a.memberId,scheduledMs:c.startMs,durationMinutes:c.durationMinutes,hardEndMs:c.hardEndMs,status:"scheduled",revision:1,participants:[{memberId:a.memberId,response:"accepted",excluded:false,chat:true,mic:true,screen:true,consent:false},...c.invitees.map(memberId=>({memberId,response:"pending",excluded:false,chat:true,mic:true,screen:false,consent:false}))],events:[],polls:[],recording:"off"};
}
export function applyRoom(room,a,c,now){
 const member=actor(room,a);
 if(!id(c.requestId)||!Number.isSafeInteger(c.expectedRevision)||!Number.isSafeInteger(now)||now<0||c.roomId!==room.id)fail("invalid_command");
 const p=participant(room,a),host=member===room.hostId&&roles.has(a.role);
 const payload=JSON.stringify([c.action,c.target??null,c.value??null,c.expectedRevision]);
 const old=room.events.find(e=>e.id===c.requestId);
 if(old){if(old.actor!==member||old.payload!==payload)fail("idempotency_conflict");return {room,replayed:true};}
 if(c.expectedRevision!==room.revision)fail("revision_conflict");
 const n=structuredClone(room),self=n.participants.find(x=>x.memberId===member);
 const needHost=()=>{if(!host)fail("forbidden")};
 const target=()=>{const t=n.participants.find(x=>x.memberId===c.target&&!x.excluded);if(!t||t.memberId===n.hostId)fail("invalid_target");return t};
 switch(c.action){
 case "respond":if(n.status!=="scheduled"||!["accepted","declined"].includes(c.value)||host)fail("invalid_response");self.response=c.value;break;
 case "start":needHost();if(n.status!=="scheduled"||now+n.durationMinutes*60000>n.hardEndMs)fail("room_unavailable");n.status="open";n.startedMs=now;n.endMs=now+n.durationMinutes*60000;break;
 case "pause":needHost();live(n,now);if(n.status!=="open")fail("invalid_state");n.status="paused";n.recording="off";break;
 case "resume":needHost();live(n,now);if(n.status!=="paused")fail("invalid_state");n.status="open";break;
 case "end":needHost();if(!["scheduled","open","paused"].includes(n.status))fail("invalid_state");n.status="ended";n.recording="off";break;
 default:
 live(n,now);if(n.status!=="open"||self.response!=="accepted")fail("room_unavailable");
 switch(c.action){
 case "chat":if(!self.chat||typeof c.value!=="string"||!c.value.trim()||c.value.length>2000)fail("invalid_chat");if(n.events.filter(e=>e.actor===member&&e.action==="chat"&&e.at>now-10000).length>=5)fail("rate_limit");break;
 case "reaction":if(!reactions.has(c.value))fail("invalid_reaction");if(n.events.filter(e=>e.actor===member&&e.action==="reaction"&&e.at>now-10000).length>=5)fail("rate_limit");break;
 case "hand":if(typeof c.value!=="boolean")fail("invalid_hand");self.hand=c.value;break;
 case "mute":needHost();target().mic=false;break;
 case "screen":needHost();if(typeof c.value!=="boolean")fail("invalid_screen");target().screen=c.value;break;
 case "chat_permission":needHost();if(typeof c.value!=="boolean")fail("invalid_chat");target().chat=c.value;break;
 case "exclude":needHost();target().excluded=true;break;
 case "consent":if(typeof c.value!=="boolean")fail("invalid_consent");self.consent=c.value;if(!c.value)n.recording="off";break;
 case "record":needHost();if(typeof c.value!=="boolean")fail("invalid_record");if(c.value&&n.participants.some(x=>!x.excluded&&x.response==="accepted"&&!x.consent))fail("consent_required");n.recording=c.value?"requested":"off";break;
 case "poll":needHost();if(!id(c.target)||n.polls.some(x=>x.id===c.target)||!Array.isArray(c.value)||c.value.length<2||c.value.length>10||!c.value.every(x=>typeof x==="string"&&x.trim()&&x.length<=200)||new Set(c.value).size!==c.value.length)fail("invalid_poll");n.polls.push({id:c.target,options:c.value,open:true,votes:{}});break;
 case "vote":{const poll=n.polls.find(x=>x.id===c.target&&x.open);if(!poll||!Number.isInteger(c.value)||c.value<0||c.value>=poll.options.length||Object.hasOwn(poll.votes,member))fail("invalid_vote");Object.defineProperty(poll.votes,member,{value:c.value,enumerable:true,writable:true,configurable:true});break;}
 case "close_poll":{needHost();const poll=n.polls.find(x=>x.id===c.target&&x.open);if(!poll)fail("invalid_poll");poll.open=false;break;}
 default:fail("unknown_action");
 }
 }
 n.revision++;n.events.push({id:c.requestId,actor:member,action:c.action,payload,at:now});
 return {room:n,replayed:false};
}
export function mediaPermission(room,a,now){
 try{live(room,now);const p=participant(room,a);if(room.status!=="open"||p.response!=="accepted")return null;return {room:"wm-"+room.id,memberId:p.memberId,canSubscribe:true,canPublish:true,microphone:p.mic===true,screen:p.screen===true,canRecord:false,canAdmin:false,expiresMs:Math.min(room.endMs,now+90000)};}catch{return null;}
}
