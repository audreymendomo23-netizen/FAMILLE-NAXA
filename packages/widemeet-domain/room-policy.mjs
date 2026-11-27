// WideMeet N2/N3 policy, adapted from NS meeting collaboration v13 and media grant.
// Trusted server state only; persistence must serialize on room id. Not a media transport.
import {extendMeeting} from "./meeting-clock.mjs";
const roles=new Set(["owner","promoteur","manager"]);
export const moderatorPermissions=Object.freeze(["admission","microphone","screen","chat","exclude","poll","pause","end"]);
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
 if(!a||a.enabled!==true||a.passwordChangeRequired!==false||!["access","premium"].includes(a.plan)||!Number.isSafeInteger(a.entitlementEndMs)||!roles.has(a.role)||!id(a.memberId)||!id(a.workspaceId)||!id(c.id)||typeof c.title!=="string"||!c.title.trim()||c.title.length>120||typeof c.description!=="string"||c.description.length>2000||!Number.isSafeInteger(c.startMs)||c.startMs<0||!Number.isSafeInteger(c.durationMinutes)||c.durationMinutes<5||c.durationMinutes>480||!Number.isSafeInteger(c.hardEndMs)||c.hardEndMs>a.entitlementEndMs||c.hardEndMs<c.startMs+c.durationMinutes*60000||!Array.isArray(c.invitees)||!c.invitees.every(id)||new Set(c.invitees).size!==c.invitees.length||c.invitees.includes(a.memberId))fail("invalid_room");
 const capacity=Math.min(100,a.capacity??(a.plan==="access"?20:50));if(c.invitees.length+1>capacity)fail("invalid_room");
 return {capacity,confidentiality:"standard",agenda:[],id:c.id,workspaceId:a.workspaceId,hostId:a.memberId,title:c.title.trim(),description:c.description.trim(),scheduledMs:c.startMs,durationMinutes:c.durationMinutes,hardEndMs:c.hardEndMs,status:"scheduled",revision:1,participants:[{memberId:a.memberId,response:"accepted",excluded:false,chat:true,mic:true,screen:true,consent:false},...c.invitees.map(memberId=>({memberId,response:"pending",excluded:false,chat:true,mic:true,screen:false,consent:false}))],events:[],polls:[],recording:"off"};
}
export function applyRoom(room,a,c,now){
 const member=actor(room,a);
 if(!id(c.requestId)||!Number.isSafeInteger(c.expectedRevision)||!Number.isSafeInteger(now)||now<0||c.roomId!==room.id)fail("invalid_command");
 const p=room.participants.find(x=>x.memberId===member&&!x.excluded),host=member===room.hostId&&roles.has(a.role);
 if(!p||p.response==="declined"&&c.action!=="respond")fail("forbidden");
 if(!Number.isSafeInteger(a.entitlementEndMs)||now>=a.entitlementEndMs||!["access","premium"].includes(a.plan))fail("entitlement_required");
 const payload=JSON.stringify([c.action,c.target??null,c.value??null,c.expectedRevision]);
 const old=room.events.find(e=>e.id===c.requestId);
 if(old){if(old.actor!==member||old.payload!==payload)fail("idempotency_conflict");return {room,replayed:true};}
 if(c.expectedRevision!==room.revision)fail("revision_conflict");
 const n=structuredClone(room),self=n.participants.find(x=>x.memberId===member);
 const needHost=()=>{if(!host)fail("forbidden")};
 const needModerator=permission=>{if(!host&&(!(self.moderatorPermissions??[]).includes(permission)||self.response!=="accepted"||n.lobbyRequired===true&&self.lobbyStatus!=="admitted"))fail("forbidden")};
 const target=()=>{const t=n.participants.find(x=>x.memberId===c.target&&!x.excluded);if(!t||t.memberId===n.hostId)fail("invalid_target");return t};
 switch(c.action){
 case "respond":if(!["scheduled","open"].includes(n.status)||!["accepted","declined","maybe"].includes(c.value)||host||n.status==="open"&&(now>=n.endMs||n.admissionLocked===true&&self.response!=="accepted"&&c.value==="accepted"))fail("invalid_response");self.response=c.value;if(c.value!=="accepted")delete self.lobbyStatus;if(c.value==="accepted"&&!self.consent||c.value!=="accepted")n.recording="off";break;
 case "reschedule":{
 needHost();if(n.status!=="scheduled")fail("invalid_state");
 const v=c.value;
 if(!v||typeof v.title!=="string"||!v.title.trim()||v.title.length>120||typeof v.description!=="string"||v.description.length>2000||!Number.isSafeInteger(v.scheduledMs)||v.scheduledMs<now||!Number.isInteger(v.durationMinutes)||v.durationMinutes<5||v.durationMinutes>480||v.scheduledMs+v.durationMinutes*60000>Math.min(n.hardEndMs,a.entitlementEndMs))fail("invalid_room");
 if((n.agenda??[]).reduce((sum,x)=>sum+x.minutes,0)>v.durationMinutes)fail("invalid_room");
 n.title=v.title.trim();n.description=v.description.trim();n.scheduledMs=v.scheduledMs;n.durationMinutes=v.durationMinutes;
 for(const x of n.participants)if(x.memberId!==n.hostId&&!x.excluded){x.response="pending";x.consent=false;delete x.lobbyStatus}
 break;
 }
 case "confidentiality":{
 needHost();if(n.status!=="scheduled"||!["standard","confidential"].includes(c.value))fail("invalid_state");
 n.confidentiality=c.value;if(c.value==="confidential")for(const x of n.participants)x.screen=false;else self.screen=true;break;
 }
 case "set_agenda":{
 needHost();if(!["scheduled","open"].includes(n.status)||n.status==="open"&&now>=n.endMs||!Array.isArray(c.value)||c.value.length>20)fail("invalid_room");
 if(new Set(c.value.map(x=>x?.id)).size!==c.value.length||!c.value.every(x=>x&&id(x.id)&&typeof x.title==="string"&&x.title.trim()&&x.title.length<=150&&Number.isInteger(x.minutes)&&x.minutes>=1&&x.minutes<=480&&(x.owner===null||n.participants.some(p=>p.memberId===x.owner&&!p.excluded)))||c.value.reduce((sum,x)=>sum+x.minutes,0)>n.durationMinutes)fail("invalid_room");
 n.agenda=c.value.map(x=>({id:x.id,title:x.title.trim(),minutes:x.minutes,owner:x.owner,status:(n.agenda??[]).find(old=>old.id===x.id&&old.title===x.title.trim()&&old.owner===x.owner&&old.minutes===x.minutes)?.status??"pending"}));break;
 }
 case "agenda_status":{
 needHost();live(n,now);if(n.status!=="open"||!["active","done","pending"].includes(c.value))fail("invalid_state");
 const item=(n.agenda??[]).find(x=>x.id===c.target);if(!item||c.value==="active"&&n.agenda.some(x=>x.id!==item.id&&x.status==="active"))fail("invalid_state");
 item.status=c.value;break;
 }
 case "set_moderator":{
 needHost();if(!["scheduled","open"].includes(n.status)||n.status==="open"&&now>=n.endMs||!Array.isArray(c.value)||new Set(c.value).size!==c.value.length||!c.value.every(x=>moderatorPermissions.includes(x)))fail("invalid_command");
 target().moderatorPermissions=[...c.value].sort();break;
 }
 case "lobby_config":{
 needHost();if(n.status!=="scheduled"||typeof c.value!=="boolean")fail("invalid_state");
 n.lobbyRequired=c.value;for(const x of n.participants)if(x.memberId!==n.hostId)delete x.lobbyStatus;break;
 }
 case "lobby_request":{
 live(n,now);if(n.status!=="open"||n.lobbyRequired!==true||host||self.response!=="accepted"||n.admissionLocked===true||["admitted","waiting"].includes(self.lobbyStatus))fail("forbidden");
 self.lobbyStatus="waiting";break;
 }
 case "lobby_admit":case "lobby_reject":{
 needModerator("admission");live(n,now);const t=target();
 if(n.status!=="open"||n.lobbyRequired!==true||t.response!=="accepted"||t.lobbyStatus!=="waiting"||c.action==="lobby_admit"&&n.admissionLocked===true)fail("invalid_state");
 t.lobbyStatus=c.action==="lobby_admit"?"admitted":"rejected";t.consent=false;n.recording="off";break;
 }
 case "invite_member":{
 needHost();if(!["scheduled","open"].includes(n.status)||n.status==="open"&&now>=n.endMs||!id(c.target)||n.participants.some(x=>x.memberId===c.target)||n.participants.length>=Math.min(n.capacity??50,100,a.capacity??(a.plan==="access"?20:50)))fail("invalid_target");
 n.participants.push({memberId:c.target,response:"pending",excluded:false,chat:true,mic:true,screen:false,consent:false});break;
 }
 case "lock_admission":needModerator("admission");live(n,now);if(typeof c.value!=="boolean")fail("invalid_command");n.admissionLocked=c.value;break;
 case "cancel":needHost();if(n.status!=="scheduled")fail("invalid_state");n.status="ended";n.cancelled=true;n.recording="off";break;
 case "start":needHost();if(n.status!=="scheduled"||now+n.durationMinutes*60000>Math.min(n.hardEndMs,a.entitlementEndMs))fail("room_unavailable");n.status="open";n.startedMs=now;n.endMs=now+n.durationMinutes*60000;break;
 case "extend":{
 needHost();live(n,now);
 const extended=extendMeeting({id:n.id,orgId:n.workspaceId,organizerId:n.hostId,status:n.status,startMs:n.startedMs,endMs:n.endMs,hardEndMs:Math.min(n.hardEndMs,a.entitlementEndMs,n.startedMs+480*60000),revision:n.revision},{meetingId:n.id,requestId:c.requestId,expectedRevision:c.expectedRevision,minutes:c.value},{enabled:true,orgId:a.workspaceId,memberId:member},now);
 n.endMs=extended.meeting.endMs;break;
 }
 case "pause":needModerator("pause");live(n,now);if(n.status!=="open")fail("invalid_state");n.status="paused";n.recording="off";break;
 case "resume":needModerator("pause");live(n,now);if(n.status!=="paused")fail("invalid_state");n.status="open";break;
 case "end":if(n.status==="scheduled")needHost();else needModerator("end");if(!["scheduled","open","paused"].includes(n.status))fail("invalid_state");n.status="ended";n.recording="off";break;
 default:
 live(n,now);if(n.status!=="open"||self.response!=="accepted"||n.lobbyRequired===true&&!host&&self.lobbyStatus!=="admitted")fail("room_unavailable");
 switch(c.action){
 case "chat":if(!self.chat||typeof c.value!=="string"||!c.value.trim()||c.value.length>2000)fail("invalid_chat");if(n.events.filter(e=>e.actor===member&&["chat","private_chat"].includes(e.action)&&e.at>now-10000).length>=5)fail("rate_limit");break;
 case "private_chat":{
 if(!self.chat||typeof c.value!=="string"||!c.value.trim()||c.value.length>2000||c.target===member||!n.participants.some(x=>x.memberId===c.target&&!x.excluded&&x.response==="accepted"&&(n.lobbyRequired!==true||x.memberId===n.hostId||x.lobbyStatus==="admitted")))fail("invalid_chat");
 if(n.events.filter(e=>e.actor===member&&["chat","private_chat"].includes(e.action)&&e.at>now-10000).length>=5)fail("rate_limit");break;
 }
 case "reaction":if(!reactions.has(c.value))fail("invalid_reaction");if(n.events.filter(e=>e.actor===member&&e.action==="reaction"&&e.at>now-10000).length>=5)fail("rate_limit");break;
 case "hand":if(typeof c.value!=="boolean")fail("invalid_hand");self.hand=c.value;break;
 case "mute":needModerator("microphone");target().mic=false;break;
 case "allow_mic":needModerator("microphone");target().mic=true;break;
 case "screen":needModerator("screen");if(typeof c.value!=="boolean"||c.value===true&&n.confidentiality==="confidential")fail("invalid_screen");target().screen=c.value;break;
 case "chat_permission":needModerator("chat");if(typeof c.value!=="boolean")fail("invalid_chat");target().chat=c.value;break;
 case "exclude":needModerator("exclude");target().excluded=true;n.recording="off";break;
 case "consent":if(typeof c.value!=="boolean")fail("invalid_consent");self.consent=c.value;if(!c.value)n.recording="off";break;
 case "record_pause":needHost();if(n.recording!=="requested")fail("invalid_record");n.recording="off";n.recordingPaused=true;break;
 case "record":needHost();if(c.value===true&&a.plan!=="premium")fail("premium_required");if(typeof c.value!=="boolean")fail("invalid_record");if(c.value&&n.participants.some(x=>!x.excluded&&x.response==="accepted"&&!x.consent))fail("consent_required");n.recording=c.value?"requested":"off";n.recordingPaused=false;break;
 case "poll":needModerator("poll");if(!id(c.target)||n.polls.some(x=>x.id===c.target)||!Array.isArray(c.value)||c.value.length<2||c.value.length>10||!c.value.every(x=>typeof x==="string"&&x.trim()&&x.length<=200)||new Set(c.value).size!==c.value.length)fail("invalid_poll");n.polls.push({id:c.target,options:c.value,open:true,votes:{}});break;
 case "vote":{const poll=n.polls.find(x=>x.id===c.target&&x.open);if(!poll||poll.kind||!Number.isInteger(c.value)||c.value<0||c.value>=poll.options.length||Object.hasOwn(poll.votes,member))fail("invalid_vote");Object.defineProperty(poll.votes,member,{value:c.value,enumerable:true,writable:true,configurable:true});break;}
 case "survey":{
 needModerator("poll");if(a.plan!=="premium")fail("premium_required");
 const v=c.value;
 if(!id(c.target)||n.polls.some(x=>x.id===c.target)||!v||typeof v!=="object"||typeof v.question!=="string"||!v.question.trim()||v.question.length>200||!Array.isArray(v.options)||v.options.length<2||v.options.length>10||!v.options.every(x=>typeof x==="string"&&x.trim()&&x.length<=200)||new Set(v.options.map(x=>x.trim())).size!==v.options.length||!["single","multiple","rating"].includes(v.kind)||typeof v.anonymous!=="boolean"||v.editable!==undefined&&typeof v.editable!=="boolean"||!["live","closed"].includes(v.visibility)||!Number.isInteger(v.quorum)||v.quorum<0||v.quorum>100||!Number.isInteger(v.threshold)||v.threshold<1||v.threshold>100||v.kind==="rating"&&![5,10].includes(v.options.length))fail("invalid_poll");
 const eligible=n.participants.filter(x=>!x.excluded&&x.response==="accepted"&&(n.lobbyRequired!==true||x.memberId===n.hostId||x.lobbyStatus==="admitted")).map(x=>x.memberId);
 n.polls.push({id:c.target,question:v.question.trim(),kind:v.kind,options:v.options.map(x=>x.trim()),anonymous:v.anonymous,editable:v.editable===true,visibility:v.visibility,quorum:v.quorum,threshold:v.threshold,eligible,open:true,votes:{}});break;
 }
 case "survey_vote":{
 const poll=n.polls.find(x=>x.id===c.target&&x.open&&x.kind);
 if(!poll||!poll.eligible.includes(member)||Object.hasOwn(poll.votes,member)&&!poll.editable||!Array.isArray(c.value)||!c.value.length||new Set(c.value).size!==c.value.length||!c.value.every(i=>Number.isInteger(i)&&i>=0&&i<poll.options.length)||poll.kind!=="multiple"&&c.value.length!==1)fail("invalid_vote");
 Object.defineProperty(poll.votes,member,{value:[...c.value].sort((x,y)=>x-y),enumerable:true,writable:true,configurable:true});break;
 }
 case "close_poll":{needModerator("poll");const poll=n.polls.find(x=>x.id===c.target&&x.open);if(!poll)fail("invalid_poll");poll.open=false;break;}
 default:fail("unknown_action");
 }
 }
 n.revision++;n.events.push({id:c.requestId,actor:member,action:c.action,payload,at:now});
 return {room:n,replayed:false};
}
export function mediaPermission(room,a,now){
 try{live(room,now);if(!["access","premium"].includes(a.plan)||!Number.isSafeInteger(a.entitlementEndMs)||now>=a.entitlementEndMs)return null;const p=participant(room,a);if(room.status!=="open"||p.response!=="accepted"||room.lobbyRequired===true&&p.memberId!==room.hostId&&p.lobbyStatus!=="admitted")return null;return {room:"wm-"+room.id,memberId:p.memberId,canSubscribe:true,canPublish:true,microphone:p.mic===true,screen:p.screen===true&&room.confidentiality!=="confidential",canRecord:false,canAdmin:false,expiresMs:Math.min(room.endMs,a.entitlementEndMs,now+90000)};}catch{return null;}
}

export function pollSummary(p,memberId){
 const voters=Object.keys(p.votes),visible=!p.kind||p.visibility==="live"||!p.open;
 const counts=visible?p.options.map((_,i)=>Object.values(p.votes).filter(v=>Array.isArray(v)?v.includes(i):v===i).length):null;
 const eligible=p.eligible?.length??null;
 const responseRate=eligible===null?null:eligible?100*voters.length/eligible:0;
 const quorumMet=eligible===null?null:responseRate>=p.quorum;
 return {id:p.id,question:p.question??null,kind:p.kind??"simple",options:p.options,open:p.open,anonymous:p.anonymous??true,editable:p.editable===true,ownSelection:p.kind&&Object.hasOwn(p.votes,memberId)?p.votes[memberId]:null,nominativeResponses:visible&&p.kind&&p.anonymous===false?Object.entries(p.votes).map(([memberId,selection])=>({memberId,selection})):null,counts,voted:Object.hasOwn(p.votes,memberId),eligible,responses:visible?voters.length:null,responseRate:visible?responseRate:null,quorumMet:visible?quorumMet:null,threshold:p.threshold??null,accepted:visible&&!p.open&&quorumMet&&voters.length?counts.map(n=>n*100/voters.length>=p.threshold):null};
}
