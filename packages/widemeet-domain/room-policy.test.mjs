import test from "node:test";
import assert from "node:assert/strict";
import {createRoom,applyRoom,mediaPermission,pollSummary} from "./room-policy.mjs";
const host={memberId:"host00001",workspaceId:"tenant001",enabled:true,passwordChangeRequired:false,role:"promoteur",plan:"premium",entitlementEndMs:3601000};
const guest={...host,memberId:"guest0001",role:"staff"};
const other={...guest,workspaceId:"tenant002"};
const base=()=>createRoom(host,{id:"meeting001",title:"Meeting",description:"",startMs:1000,durationMinutes:30,hardEndMs:3601000,invitees:[guest.memberId]});
let sequence=0;
function command(room,action,value,target){return {roomId:room.id,requestId:"request_"+String(++sequence).padStart(8,"0"),expectedRevision:room.revision,action,value,target};}
function run(room,actor,action,value,target,now=1000){return applyRoom(room,actor,command(room,action,value,target),now).room;}
function open(){let r=base();r=run(r,guest,"respond","accepted");return run(r,host,"start");}
test("staff cannot create or start; foreign workspace cannot access",()=>{assert.throws(()=>createRoom(guest,{id:"meeting001"}));const r=base();assert.throws(()=>run(r,guest,"start"));assert.throws(()=>run(r,other,"respond","accepted"));});
test("invitation required for media; scheduled rooms do not issue grants",()=>{let r=base();assert.equal(mediaPermission(r,guest,1000),null);r=run(r,host,"start");assert.equal(mediaPermission(r,guest,1000),null);assert.equal(mediaPermission(r,host,1000).room,"wm-meeting001");});
test("pause and resume do not extend time; expiry denies media",()=>{let r=open();const end=r.endMs;r=run(r,host,"pause");assert.equal(mediaPermission(r,host,1000),null);r=run(r,host,"resume");assert.equal(r.endMs,end);assert.equal(mediaPermission(r,guest,end),null);});
test("host moderates; staff cannot; exclusion denies subsequent actions",()=>{let r=open();assert.throws(()=>run(r,guest,"mute",null,host.memberId));r=run(r,host,"mute",null,guest.memberId);assert.equal(mediaPermission(r,guest,1000).microphone,false);r=run(r,host,"screen",true,guest.memberId);assert.equal(mediaPermission(r,guest,1000).screen,true);r=run(r,host,"exclude",null,guest.memberId);assert.equal(mediaPermission(r,guest,1000),null);assert.throws(()=>run(r,guest,"chat","hello"));});
test("exact replay does not mutate; altered payload and stale revision denied",()=>{let r=open();const c=command(r,"chat","hello");const n=applyRoom(r,guest,c,1000).room;assert.equal(applyRoom(n,guest,c,1000).replayed,true);assert.throws(()=>applyRoom(n,guest,{...c,value:"changed"},1000),/idempotency_conflict/);assert.throws(()=>applyRoom(n,guest,{...c,requestId:"different001"},1000),/revision_conflict/);});
test("chat burst, permission, validation and foreign actor rejected",()=>{let r=open();for(let i=0;i<5;i++)r=run(r,guest,"chat","hello");assert.throws(()=>run(r,guest,"chat","hello"),/rate_limit/);assert.throws(()=>run(r,other,"chat","hello"));r=run(r,host,"chat_permission",false,guest.memberId);assert.throws(()=>run(r,guest,"chat","hello",null,12000),/invalid_chat/);});
test("record intent requires consent; withdrawal and pause stop intent",()=>{let r=open();assert.throws(()=>run(r,host,"record",true),/consent_required/);r=run(r,host,"consent",true);r=run(r,guest,"consent",true);r=run(r,host,"record",true);assert.equal(r.recording,"requested");r=run(r,guest,"consent",false);assert.equal(r.recording,"off");assert.equal(mediaPermission(r,host,1000).canRecord,false);});
test("poll creation and closure host-only, one vote per member",()=>{let r=open();assert.throws(()=>run(r,guest,"poll",["yes","no"],"poll00001"));r=run(r,host,"poll",["yes","no"],"poll00001");assert.throws(()=>run(r,guest,"vote",2,"poll00001"));r=run(r,guest,"vote",0,"poll00001");assert.throws(()=>run(r,guest,"vote",1,"poll00001"));r=run(r,host,"close_poll",null,"poll00001");assert.throws(()=>run(r,host,"vote",0,"poll00001"));assert.equal(r.polls[0].votes[guest.memberId],0);});
test("password change gate, no admin or record grant, finite lease",()=>{const r=open();assert.equal(mediaPermission(r,{...host,passwordChangeRequired:true},1000),null);const g=mediaPermission(r,guest,1000);assert.equal(g.canAdmin,false);assert.equal(g.canRecord,false);assert.equal(g.expiresMs,91000);});
test("ending room revokes all subsequent permissions",()=>{let r=open();r=run(r,host,"end");assert.equal(mediaPermission(r,host,1000),null);assert.equal(mediaPermission(r,guest,1000),null);assert.throws(()=>run(r,host,"resume"));});
test("trusted plan limits cannot be raised by room command and Access cannot record",()=>{const r=open();assert.throws(()=>createRoom({...host,entitlementEndMs:2000},{id:"meeting002",title:"Meeting",description:"",startMs:1000,durationMinutes:30,hardEndMs:3601000,invitees:[]}));assert.throws(()=>run(r,{...host,plan:"access"},"record",true),/premium_required/);assert.equal(mediaPermission(r,{...host,entitlementEndMs:1000},1000),null);});
test("late acceptance suspends recording until newly accepted participant consents",()=>{let r=base();r=run(r,host,"start");r=run(r,host,"consent",true);r=run(r,host,"record",true);r=run(r,guest,"respond","accepted");assert.equal(r.recording,"off");assert.throws(()=>run(r,host,"record",true),/consent_required/);r=run(r,guest,"consent",true);r=run(r,host,"record",true);assert.equal(r.recording,"requested");});
test("RSVP can change from declined or maybe before the room starts",()=>{let r=base();r=run(r,guest,"respond","declined");r=run(r,guest,"respond","maybe");r=run(r,guest,"respond","accepted");assert.equal(r.participants[1].response,"accepted");});
test("meeting title is required and description length bounded",()=>{const c={id:"meeting003",title:" ",description:"",startMs:1000,durationMinutes:30,hardEndMs:3601000,invitees:[]};assert.throws(()=>createRoom(host,c));assert.throws(()=>createRoom(host,{...c,title:"Planning",description:"x".repeat(2001)}));assert.equal(createRoom(host,{...c,title:" Planning "}).title,"Planning");});

test("extension uses existing clock, host-only, bounded and idempotent",()=>{let r=open();const end=r.endMs,c=command(r,"extend",15);assert.throws(()=>applyRoom(r,guest,c,1000),/forbidden/);r=applyRoom(r,host,c,1000).room;assert.equal(r.endMs,end+900000);assert.equal(applyRoom(r,host,c,1000).replayed,true);assert.throws(()=>run(r,host,"extend",16),/limit_exceeded/);assert.throws(()=>run(r,host,"extend",1,null,r.endMs),/room_unavailable/);});
test("premium survey is private until close, multiple choices and quorum",()=>{let r=open();const config={question:"Preferred dates",kind:"multiple",options:["Monday","Tuesday","Friday"],anonymous:true,visibility:"closed",quorum:100,threshold:50};assert.throws(()=>run(r,{...host,plan:"access"},"survey",config,"survey001"),/premium_required/);r=run(r,host,"survey",config,"survey001");r=run(r,guest,"survey_vote",[0,2],"survey001");let summary=pollSummary(r.polls[0],guest.memberId);assert.equal(summary.counts,null);assert.equal(summary.responses,null);assert.equal(summary.votes,undefined);assert.throws(()=>run(r,guest,"survey_vote",[1],"survey001"),/invalid_vote/);r=run(r,host,"survey_vote",[0],"survey001");r=run(r,host,"close_poll",null,"survey001");summary=pollSummary(r.polls[0],host.memberId);assert.deepEqual(summary.counts,[2,0,1]);assert.equal(summary.responses,2);assert.equal(summary.responseRate,100);assert.equal(summary.quorumMet,true);assert.deepEqual(summary.accepted,[true,false,true]);});
test("survey eligibility snapshot and invalid or duplicate selections",()=>{let r=base();r=run(r,host,"start");const config={question:"Score",kind:"rating",options:["1","2","3","4","5"],anonymous:true,visibility:"live",quorum:100,threshold:60};r=run(r,host,"survey",config,"survey002");r=run(r,guest,"respond","accepted");assert.throws(()=>run(r,guest,"survey_vote",[0],"survey002"),/invalid_vote/);assert.throws(()=>run(r,host,"survey_vote",[0,0],"survey002"),/invalid_vote/);assert.throws(()=>run(r,host,"survey_vote",[0,1],"survey002"),/invalid_vote/);assert.throws(()=>run(r,host,"vote",0,"survey002"),/invalid_vote/);r=run(r,host,"survey_vote",[4],"survey002");assert.equal(pollSummary(r.polls[0],host.memberId).quorumMet,true);});
test("failed quorum never declares an accepted option",()=>{let r=open();r=run(r,host,"survey",{question:"Decision",kind:"single",options:["yes","no"],anonymous:true,visibility:"live",quorum:100,threshold:50},"survey003");r=run(r,guest,"survey_vote",[0],"survey003");r=run(r,host,"close_poll",null,"survey003");const s=pollSummary(r.polls[0],host.memberId);assert.equal(s.quorumMet,false);assert.equal(s.accepted,null);});

test("N2 host-only schedule revision invalidates prior RSVP, cancel terminal",()=>{
 let r=base();r=run(r,guest,"respond","accepted");
 const v={title:"Revised meeting",description:"New agenda",scheduledMs:61000,durationMinutes:10};
 assert.throws(()=>run(r,guest,"reschedule",v),/forbidden/);
 r=run(r,host,"reschedule",v);assert.equal(r.title,v.title);assert.equal(r.scheduledMs,v.scheduledMs);assert.equal(r.participants[1].response,"pending");
 assert.throws(()=>run(r,host,"reschedule",{...v,scheduledMs:0}),/invalid_room/);
 assert.throws(()=>run(r,guest,"cancel"),/forbidden/);r=run(r,host,"cancel");assert.equal(r.cancelled,true);assert.equal(r.status,"ended");assert.throws(()=>run(r,host,"start"));
});
test("N2 private messages require admitted destination and share public-chat rate limit",()=>{
 let r=open();assert.throws(()=>run(r,guest,"private_chat","private","foreign001"),/invalid_chat/);
 assert.throws(()=>run(r,guest,"private_chat","private",guest.memberId),/invalid_chat/);
 r=run(r,guest,"private_chat","private",host.memberId);assert.deepEqual(JSON.parse(r.events.at(-1).payload).slice(0,3),["private_chat",host.memberId,"private"]);
 for(let i=0;i<4;i++)r=run(r,guest,"chat","public");assert.throws(()=>run(r,guest,"private_chat","extra",host.memberId),/rate_limit/);
 r=run(r,host,"exclude",null,guest.memberId);assert.throws(()=>run(r,host,"private_chat","denied",guest.memberId),/invalid_chat/);
});
test("N3 explicit editable nominative survey exposes identities only when results visible",()=>{
 let r=open();r=run(r,host,"survey",{question:"Choice",kind:"single",options:["A","B"],anonymous:false,editable:true,visibility:"closed",quorum:0,threshold:50},"survey004");
 r=run(r,guest,"survey_vote",[0],"survey004");let s=pollSummary(r.polls[0],guest.memberId);assert.equal(s.nominativeResponses,null);assert.deepEqual(s.ownSelection,[0]);
 r=run(r,guest,"survey_vote",[1],"survey004");r=run(r,host,"close_poll",null,"survey004");s=pollSummary(r.polls[0],host.memberId);assert.deepEqual(s.counts,[0,1]);assert.deepEqual(s.nominativeResponses,[{memberId:guest.memberId,selection:[1]}]);assert.throws(()=>run(r,guest,"survey_vote",[0],"survey004"),/invalid_vote/);
});
test("N3 exclusion stops recording request and anonymous ballots never expose identities",()=>{
 let r=open();r=run(r,host,"consent",true);r=run(r,guest,"consent",true);r=run(r,host,"record",true);
 r=run(r,host,"survey",{question:"Secret",kind:"multiple",options:["A","B"],anonymous:true,editable:true,visibility:"live",quorum:0,threshold:50},"survey005");
 r=run(r,guest,"survey_vote",[0,1],"survey005");assert.equal(pollSummary(r.polls[0],host.memberId).nominativeResponses,null);
 r=run(r,host,"exclude",null,guest.memberId);assert.equal(r.recording,"off");
});

test("late invitations are host-only, admission lock preserves existing attendees",()=>{
 let r=open();const newcomer={...guest,memberId:"late00001"};
 assert.throws(()=>run(r,guest,"invite_member",null,newcomer.memberId),/forbidden/);
 r=run(r,host,"invite_member",null,newcomer.memberId);assert.equal(r.participants.at(-1).response,"pending");
 assert.throws(()=>run(r,host,"invite_member",null,newcomer.memberId),/invalid_target/);
 r=run(r,host,"lock_admission",true);assert.throws(()=>run(r,newcomer,"respond","accepted"),/invalid_response/);
 assert.ok(mediaPermission(r,guest,1000));assert.equal(mediaPermission(r,newcomer,1000),null);
 r=run(r,host,"lock_admission",false);r=run(r,newcomer,"respond","accepted");assert.ok(mediaPermission(r,newcomer,1000));
});
test("recording pause does not pause the room; only host may restart after consent",()=>{
 let r=open();r=run(r,host,"consent",true);r=run(r,guest,"consent",true);r=run(r,host,"record",true);
 assert.throws(()=>run(r,guest,"record_pause"),/forbidden/);
 r=run(r,host,"record_pause");assert.equal(r.recording,"off");assert.equal(r.recordingPaused,true);assert.equal(r.status,"open");
 r=run(r,guest,"chat","Meeting continues");assert.ok(mediaPermission(r,guest,1000));
 r=run(r,guest,"consent",false);assert.throws(()=>run(r,host,"record",true),/consent_required/);
 r=run(r,guest,"consent",true);r=run(r,host,"record",true);assert.equal(r.recordingPaused,false);
});

test("N2 lobby separates RSVP from admission and fences all live collaboration",()=>{
 let r=base();r=run(r,host,"lobby_config",true);r=run(r,guest,"respond","accepted");r=run(r,host,"start");
 assert.equal(mediaPermission(r,guest,1000),null);assert.throws(()=>run(r,guest,"chat","not admitted"),/room_unavailable/);
 r=run(r,guest,"lobby_request");assert.equal(r.participants[1].lobbyStatus,"waiting");
 assert.throws(()=>run(r,guest,"lobby_admit",null,guest.memberId),/forbidden/);
 r=run(r,host,"lock_admission",true);assert.throws(()=>run(r,host,"lobby_admit",null,guest.memberId),/invalid_state/);
 r=run(r,host,"lock_admission",false);r=run(r,host,"lobby_reject",null,guest.memberId);assert.equal(mediaPermission(r,guest,1000),null);
 r=run(r,guest,"lobby_request");r=run(r,host,"lobby_admit",null,guest.memberId);
 assert.ok(mediaPermission(r,guest,1000));r=run(r,guest,"chat","admitted");assert.equal(r.events.at(-1).action,"chat");
 r=run(r,guest,"respond","declined");assert.equal(mediaPermission(r,guest,1000),null);
});

test("temporary moderator delegation grants only explicit permissions and cannot record or delegate",()=>{
 let r=open();const third={...guest,memberId:"other0003"};r=run(r,host,"invite_member",null,third.memberId);r=run(r,third,"respond","accepted");
 r=run(r,host,"set_moderator",["microphone","poll"],guest.memberId);
 r=run(r,guest,"mute",null,third.memberId);assert.equal(mediaPermission(r,third,1000).microphone,false);
 assert.throws(()=>run(r,guest,"exclude",null,third.memberId),/forbidden/);assert.throws(()=>run(r,guest,"record",true),/forbidden/);assert.throws(()=>run(r,guest,"set_moderator",["end"],third.memberId),/forbidden/);assert.throws(()=>run(r,guest,"end"),/forbidden/);
 r=run(r,guest,"poll",["Yes","No"],"poll00001");r=run(r,guest,"close_poll",null,"poll00001");
 r=run(r,host,"set_moderator",[],guest.memberId);assert.throws(()=>run(r,guest,"allow_mic",null,third.memberId),/forbidden/);
});

test("structured agenda respects time and assignment; confidentiality is immutable during meeting and disables screen grants",()=>{
 let r=base();r=run(r,host,"set_agenda",[{id:"agenda001",title:"Review",minutes:15,owner:guest.memberId}]);assert.equal(r.agenda[0].status,"pending");
 assert.throws(()=>run(r,host,"set_agenda",[{id:"agenda002",title:"Too long",minutes:31,owner:null}]),/invalid_room/);
 assert.throws(()=>run(r,guest,"set_agenda",[]),/forbidden/);assert.throws(()=>run(r,host,"confidentiality","strict"),/invalid_state/);
 r=run(r,host,"confidentiality","confidential");r=run(r,guest,"respond","accepted");r=run(r,host,"start");assert.equal(mediaPermission(r,host,1000).screen,false);
 assert.throws(()=>run(r,host,"screen",true,guest.memberId),/invalid_screen/);assert.throws(()=>run(r,host,"confidentiality","standard"),/invalid_state/);
 r=run(r,host,"agenda_status","active","agenda001");r=run(r,host,"agenda_status","done","agenda001");assert.equal(r.agenda[0].status,"done");
});

test("timed polls reject boundary votes and reveal closed survey only at the server deadline",()=>{
 let r=open();r=run(r,host,"poll",{options:["A","B"],durationSeconds:15},"timed0001");const p=r.polls[0];
 assert.throws(()=>run(r,guest,"vote",0,p.id,16000),/invalid_vote/);
 r=run(r,guest,"vote",0,p.id,15999);assert.equal(pollSummary(r.polls[0],guest.memberId,16000).open,false);
 r=run(r,host,"survey",{question:"Timed",kind:"single",options:["Yes","No"],anonymous:true,editable:true,visibility:"closed",quorum:0,threshold:50,durationSeconds:15},"timed0002");assert.equal(pollSummary(r.polls[1],guest.memberId,15999).counts,null);
 assert.deepEqual(pollSummary(r.polls[1],guest.memberId,16000).counts,[0,0]);
 assert.throws(()=>run(r,guest,"survey_vote",[0],"timed0002",16000),/invalid_vote/);
});

test("B6 unsupported confidentiality modes fail closed instead of issuing media grants",()=>{const r=open();for(const confidentiality of ["strict","highly_confidential","unknown",false,{}])assert.equal(mediaPermission({...r,confidentiality},host,1000),null);assert.equal(mediaPermission({...r,confidentiality:"confidential"},host,1000).screen,false);assert.equal(mediaPermission(r,host,1000).screen,true);});

test("B6 unsupported confidentiality fails closed for room mutations except safe closure",()=>{const r={...open(),confidentiality:"highly_confidential"};assert.throws(()=>run(r,host,"chat","private"),/unsupported_confidentiality/);assert.throws(()=>run(r,host,"record",true),/unsupported_confidentiality/);assert.equal(run(r,host,"end").status,"ended");});

test("B4 targeted rating: frozen eligible list, no unauthorized vote, explicit denominator",()=>{
 let r=open();const config={question:"Rate",kind:"rating",options:Array.from({length:10},(_,i)=>String(i+1)),anonymous:true,visibility:"closed",quorum:100,threshold:50,eligibleIds:[guest.memberId]};
 assert.throws(()=>run(r,host,"survey",{...config,eligibleIds:["foreign001"]},"target001"),/invalid_poll/);
 assert.throws(()=>run(r,host,"survey",{...config,eligibleIds:[guest.memberId,guest.memberId]},"target001"),/invalid_poll/);
 r=run(r,host,"survey",config,"target001");
 assert.equal(pollSummary(r.polls[0],host.memberId,1000).canVote,false);assert.equal(pollSummary(r.polls[0],guest.memberId,1000).canVote,true);
 assert.throws(()=>run(r,host,"survey_vote",[9],"target001"),/invalid_vote/);
 r=run(r,guest,"survey_vote",[9],"target001");assert.equal(pollSummary(r.polls[0],host.memberId,1000).nonresponses,null);
 r=run(r,host,"close_poll",null,"target001");const p=pollSummary(r.polls[0],host.memberId,1000);
 assert.equal(p.eligible,1);assert.equal(p.responses,1);assert.equal(p.nonresponses,0);assert.equal(p.optionShares[9],100);assert.equal(p.nominativeResponses,null);assert.equal(p.quorumMet,true);
});

test("B4 simple and absolute majority distinguish abstention and nonresponse",()=>{
 const cfg={question:"Decision",kind:"single",options:["Oui","Non","Abstention"],anonymous:true,visibility:"closed",quorum:100,threshold:50,abstentionIndex:2};
 for(const mode of ["simple_majority","absolute_majority","threshold"]){
 let r=open();r=run(r,host,"survey",{...cfg,decisionMode:mode},"majority1");r=run(r,host,"survey_vote",[0],"majority1");r=run(r,guest,"survey_vote",[2],"majority1");
 let s=pollSummary(r.polls[0],host.memberId,1000);assert.equal(s.abstentions,null);assert.equal(s.expressed,null);assert.equal(s.accepted,null);
 r=run(r,host,"close_poll",null,"majority1");s=pollSummary(r.polls[0],host.memberId,1000);
 assert.equal(s.abstentions,1);assert.equal(s.expressed,1);assert.equal(s.nonresponses,0);assert.equal(s.quorumMet,true);assert.equal(s.accepted[0],mode!=="absolute_majority");assert.equal(s.accepted[2],false);assert.equal(s.decisionDenominator,mode==="absolute_majority"?2:1);
 }
 let r=open();assert.throws(()=>run(r,host,"survey",{...cfg,kind:"multiple",decisionMode:"simple_majority"},"majority1"),/invalid_poll/);assert.throws(()=>run(r,host,"survey",{...cfg,abstentionIndex:3},"majority1"),/invalid_poll/);
 r=run(r,host,"survey",{...cfg,decisionMode:"simple_majority"},"majority1");r=run(r,host,"survey_vote",[2],"majority1");r=run(r,guest,"survey_vote",[2],"majority1");r=run(r,host,"close_poll",null,"majority1");assert.equal(pollSummary(r.polls[0],host.memberId,1000).accepted,null);
});
