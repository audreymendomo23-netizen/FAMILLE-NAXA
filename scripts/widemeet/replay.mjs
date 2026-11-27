// Disposable GoTrue/PostgREST/Edge replay; no hosted access, no production keys, no paid entitlement.
import assert from "node:assert/strict";
import {randomUUID,randomBytes} from "node:crypto";
import {spawn} from "node:child_process";
import {readFile,writeFile,unlink,stat} from "node:fs/promises";
import {createServer} from "node:https";
import {resolve,extname,sep} from "node:path";
import {chromium} from "@playwright/test";
const base=process.env.SUPABASE_URL,service=process.env.SUPABASE_SERVICE_ROLE_KEY,anon=process.env.SUPABASE_ANON_KEY;
assert.equal(base,"http://127.0.0.1:54321");assert.ok(service&&anon);
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const children=[];
let server,browser;
const roomCopy="supabase/functions/widemeet-room/replay-local.ts";
const pass=s=>console.log("PASS "+s);
async function json(url,body,token=service,key=service,method="POST"){
 const r=await fetch(url,{method,headers:{apikey:key,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation"},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const data=await r.json().catch(()=>null);return {status:r.status,data};
}
async function success(url,body,token=service,key=service,method="POST"){
 const r=await json(url,body,token,key,method);assert.ok(r.status>=200&&r.status<300,"HTTP "+r.status+" at "+new URL(url).pathname);return r.data;
}
const rest=(table,body)=>success(base+"/rest/v1/"+table,body);
async function createWorkspace(name){
 const [w]=await rest("wm_workspaces",{kind:"enterprise",name});await rest("wm_room_entitlements",{workspace_id:w.id,plan:"premium",valid_until:new Date(Date.now()+7200000).toISOString(),enabled:true});return w.id;
}
async function fixture(w,role){
 const email="wm-replay-"+randomUUID()+"@example.test",password="Qa7!"+randomBytes(18).toString("hex"),login="WM-"+randomBytes(8).toString("hex").toUpperCase();
 const user=await success(base+"/auth/v1/admin/users",{email,password,email_confirm:true,app_metadata:{app_code:"widemeet"}});
 const [a]=await rest("wm_accounts",{auth_user_id:user.id,login_id:login,auth_alias:email,display_name:"Replay "+role});
 await rest("wm_memberships",{account_id:a.id,workspace_id:w,role});return{id:a.id,login,password};
}
async function launch(file,port){
 const child=spawn("deno",["run","--allow-env","--allow-net=127.0.0.1:54321,0.0.0.0:"+port+",127.0.0.1:"+port,file],{stdio:["ignore","ignore","inherit"]});children.push(child);
 for(let i=0;i<60;i++){try{if((await fetch("http://127.0.0.1:"+port,{method:"OPTIONS"})).ok)return;}catch{}if(child.exitCode!==null)break;await wait(250)}
 throw Error("GATEWAY_START_FAILED_"+port);
}
const auth="http://127.0.0.1:8000",room="http://127.0.0.1:8001";
const request=(url,body,token)=>json(url,{...body,app_id:"WIDEMEET"},token??anon,anon);
async function ok(url,body,token){const r=await request(url,body,token);assert.ok(r.status>=200&&r.status<300,"HTTP "+r.status+" "+new URL(url).pathname+" "+String(r.data?.error??""));return r.data}
async function login(f){return ok(auth+"/login",{identifier:f.login,password:f.password,installation_id:randomUUID(),platform:"web"});}
try{
 const w=await createWorkspace("Replay A"),other=await createWorkspace("Replay B");
 const h=await fixture(w,"promoteur"),g=await fixture(w,"staff"),o=await fixture(other,"promoteur");
 const code=await readFile("supabase/functions/widemeet-room/index.ts","utf8");
 const anchor="Deno.serve(async request=>{";
 assert.equal(code.split(anchor).length,2);
 await writeFile(roomCopy,code.replace(anchor,"Deno.serve({port:8001},async request=>{"));
 await launch("supabase/functions/widemeet-auth/index.ts",8000);await launch(roomCopy,8001);
 let individualSession;
 // Register real GoTrue accounts through the product gateway (test-only policy versions).
 for(const kind of ["individual","enterprise"]){
 const password="Qa7!"+randomBytes(18).toString("hex"),registration={installation_id:randomUUID(),request_id:randomUUID(),kind,display_name:"Replay "+kind,workspace_name:"Registration "+kind,password,accepted_terms:true,terms_version:"wm-replay-draft-20261126",privacy_version:"wm-replay-draft-20261126"};
 const registered=await ok(auth+"/register",registration);
 assert.match(registered.login_id,/^WM-[A-Z0-9]{8,24}$/);
 assert.deepEqual(await ok(auth+"/register",registration),registered);
 const session=await login({login:registered.login_id,password});
 assert.equal(session.workspaces.length,1);
 assert.equal(session.workspaces[0].kind,kind);
 if(kind==="individual")individualSession=session;
 assert.equal((await request(room+"/list",{},session.access_token)).status,403);
 assert.ok((await request(auth+"/register",{...registration,display_name:"Changed"})).status>=400);
 }
 pass("actual autonomous individual and enterprise registration, stable retry, no automatic entitlement");
 // Exercise the pass using a synthetic receipt in this disposable database only.
 assert.ok(individualSession);
 const ps=individualSession.access_token;
 const passIntent=await ok(auth+"/identity",{action:"billing-create",data:{request_id:randomUUID(),offer:"pass",period:"once",capacity:20,channel:"OM"}},ps);
 assert.equal(passIntent.amount,1000);
 assert.deepEqual(await ok(room+"/pass-list",{},ps),[]);
 const settled=await success(base+"/rest/v1/rpc/wm_settle_verified_receipt",{p_id:passIntent.id,p_channel:"OM",p_reference:"fixture-pass-"+randomUUID(),p_amount:1000,p_currency:"XAF",p_proof_hash:randomBytes(32).toString("hex"),p_paid_at:new Date().toISOString()});
 assert.equal(settled,true);
 const paidPasses=await ok(room+"/pass-list",{},ps);assert.equal(paidPasses.length,1);assert.equal(paidPasses[0].room_id,null);
 const meeting={room_id:randomUUID(),title:"Paid pass replay",description:"Isolated fixture",scheduled_ms:Date.now(),duration_minutes:30,invitees:[],pass_id:passIntent.id};
 const attempts=await Promise.all([request(room+"/create",meeting,ps),request(room+"/create",{...meeting,room_id:randomUUID()},ps)]);
 assert.equal(attempts.filter(x=>x.status===201).length,1);
 assert.equal(attempts.filter(x=>x.status>=400).length,1);
 const passRoom=attempts.find(x=>x.status===201).data;
 const replayedCreate={...meeting,room_id:passRoom.id};assert.equal((await request(room+"/create",replayedCreate,ps)).status,200);assert.ok((await request(room+"/create",{...replayedCreate,title:"Changed"},ps)).status>=400);pass("actual N1 exact paid room creation replay consumes no additional pass");
 const after=await ok(room+"/pass-list",{},ps);assert.equal(after[0].room_id,passRoom.id);assert.ok(Date.parse(after[0].valid_until)<=Date.now()+86400000);
 assert.equal((await ok(room+"/list",{},ps)).length,1);
 const noPass={...meeting,room_id:randomUUID()};delete noPass.pass_id;
 assert.equal((await request(room+"/create",noPass,ps)).status,403);
 const guestLogin=await login(g),unrelatedLogin=await login(o);
 const passLobby=await ok(room+"/command",{room_id:passRoom.id,request_id:randomUUID(),expected_revision:passRoom.revision,action:"lobby_config",value:true},ps);
 const inviteToken=randomBytes(32).toString("hex"),inviteId=randomUUID(),exReq=(token,action,data)=>request(room+"/external-invite",{action,data},token),exOk=(token,action,data)=>ok(room+"/external-invite",{action,data},token);
 await exOk(ps,"issue",{room_id:passRoom.id,invite_id:inviteId,login_id:g.login,token:inviteToken});
 assert.equal((await exReq(unrelatedLogin.access_token,"redeem",{token:inviteToken})).status,403);
 assert.equal((await exOk(guestLogin.access_token,"redeem",{token:inviteToken})).room_id,passRoom.id);
 assert.equal((await exOk(guestLogin.access_token,"redeem",{token:inviteToken})).room_id,passRoom.id);
 const guestRoom=await ok(room+"/read",{room_id:passRoom.id},guestLogin.access_token);assert.equal(guestRoom.participants.length,0);
 assert.ok((await ok(room+"/list",{},guestLogin.access_token)).some(x=>x.id===passRoom.id));
 assert.equal((await request(room+"/command",{room_id:passRoom.id,request_id:randomUUID(),expected_revision:guestRoom.revision,action:"start"},guestLogin.access_token)).status,409);
 assert.equal((await request(room+"/media-grant",{room_id:passRoom.id},guestLogin.access_token)).status,403);
 const startedPass=await ok(room+"/command",{room_id:passRoom.id,request_id:randomUUID(),expected_revision:guestRoom.revision,action:"start"},ps);
 const requested=await ok(room+"/command",{room_id:passRoom.id,request_id:randomUUID(),expected_revision:startedPass.revision,action:"lobby_request"},guestLogin.access_token);
 const admitted=await ok(room+"/command",{room_id:passRoom.id,request_id:randomUUID(),expected_revision:requested.revision,action:"lobby_admit",target:g.id},ps);
 assert.equal((await ok(room+"/read",{room_id:passRoom.id},guestLogin.access_token)).lobbyStatus,"admitted");
 await exOk(ps,"revoke",{room_id:passRoom.id,invite_id:inviteId});
 assert.ok((await request(room+"/read",{room_id:passRoom.id},guestLogin.access_token)).status>=400);
 assert.equal((await exReq(guestLogin.access_token,"redeem",{token:inviteToken})).status,403);
 pass("actual N1-N2 named external guest on paid pass, no cross-account token reuse, lobby and revocation");
 const currentPass=await ok(room+"/read",{room_id:passRoom.id},ps);
 assert.equal(startedPass.status,"open");
 const endedPass=await ok(room+"/command",{room_id:passRoom.id,request_id:randomUUID(),expected_revision:currentPass.revision,action:"end"},ps);
 assert.equal(endedPass.status,"ended");
 assert.ok((await request(room+"/create",{...meeting,room_id:randomUUID()},ps)).status>=400);
 pass("actual N1 paid-pass fixture binds exactly one concurrent room, agenda, scoped lifecycle and no global entitlement");

 const hs=await login(h),gs=await login(g),os=await login(o);
 // A separate fixture proves real password rotation without disturbing the room accounts.
 const rotationUser=await fixture(other,"manager");
 const oldSession=await login(rotationUser),otherDevice=await login(rotationUser);
 const newPassword="Qa8!"+randomBytes(18).toString("hex"),changeId=randomUUID();
 const changed=await ok(auth+"/change-password",{current_password:rotationUser.password,new_password:newPassword,request_id:changeId},oldSession.access_token);
 assert.equal(changed.changed,true);assert.equal(changed.reconnect,true);
 assert.equal((await request(room+"/list",{},oldSession.access_token)).status,403);
 assert.equal((await request(room+"/list",{},otherDevice.access_token)).status,403);
 assert.equal((await request(auth+"/login",{identifier:rotationUser.login,password:rotationUser.password,installation_id:randomUUID(),platform:"web"})).status,401);
 const rotated=await login({login:rotationUser.login,password:newPassword});assert.equal(rotated.member_id,rotationUser.id);
 pass("actual GoTrue password rotation and revocation of two devices");
 // Independent synthetic recovery fixture. Never print the password or key.
 const recoverable=await fixture(other,"staff");
 const recoverSession=await login(recoverable),recoverOther=await login(recoverable);
 assert.equal((await request(auth+"/recovery-enroll",{current_password:"incorrect"},recoverSession.access_token)).status,401);
 const keyResult=await ok(auth+"/recovery-enroll",{current_password:recoverable.password},recoverSession.access_token);
 assert.match(keyResult.recovery_key,/^[a-f0-9]{64}$/);
 const replacement="Qa9!"+randomBytes(18).toString("hex"),recoveryRequest={identifier:recoverable.login,recovery_key:keyResult.recovery_key,new_password:replacement,request_id:randomUUID(),installation_id:randomUUID(),platform:"web"};
 assert.equal((await request(auth+"/recover-key",{...recoveryRequest,recovery_key:randomBytes(32).toString("hex")})).status,401);
 assert.equal((await ok(auth+"/recover-key",recoveryRequest)).recovered,true);
 assert.equal((await request(room+"/list",{},recoverSession.access_token)).status,403);
 assert.equal((await request(room+"/list",{},recoverOther.access_token)).status,403);
 assert.equal((await request(auth+"/recover-key",recoveryRequest)).status,401);
 assert.equal((await request(auth+"/login",{identifier:recoverable.login,password:recoverable.password,installation_id:randomUUID(),platform:"web"})).status,401);
 assert.equal((await login({login:recoverable.login,password:replacement})).member_id,recoverable.id);
 pass("actual offline recovery proof, one-use key, GoTrue credential replacement and two-device revocation");

 assert.equal(hs.member_id,h.id);assert.equal(gs.member_id,g.id);assert.equal(os.active_workspace_id,other);
 const centerReq=(token,action,data={})=>request(auth+"/identity",{action:"center-"+action,data},token);
 const centerOk=(token,action,data={})=>ok(auth+"/identity",{action:"center-"+action,data},token);
 const privateData={peer_id:g.id,message_id:randomUUID(),body:"Synthetic private workspace message"};
 assert.ok((await centerOk(hs.access_token,"contacts",{query:"staff"})).items.some(x=>x.member_id===g.id));
 assert.deepEqual((await centerOk(hs.access_token,"contacts",{query:"not present"})).items,[]);
 assert.equal((await centerReq(hs.access_token,"contacts",{query:"x".repeat(101)})).status,403);
 await centerOk(hs.access_token,"send",privateData);await centerOk(hs.access_token,"send",privateData);
 assert.equal((await centerReq(hs.access_token,"send",{...privateData,body:"changed"})).status,403);
 assert.equal((await centerReq(hs.access_token,"send",{...privateData,peer_id:o.id})).status,403);
 assert.equal((await centerReq(os.access_token,"thread",{peer_id:g.id})).status,403);
 assert.equal((await centerOk(gs.access_token,"thread",{peer_id:h.id})).items.length,1);
 assert.equal((await centerReq(hs.access_token,"seen",{peer_id:g.id,message_id:privateData.message_id})).status,403);
 await centerOk(gs.access_token,"seen",{peer_id:h.id,message_id:privateData.message_id});
 assert.ok((await centerOk(hs.access_token,"thread",{peer_id:g.id,query:"workspace"})).items[0].read_at);
 assert.deepEqual((await centerOk(gs.access_token,"thread",{peer_id:h.id,query:"not present"})).items,[]);
 assert.equal((await centerReq(gs.access_token,"statistics",{days:30})).status,403);
 const consolidated=await centerOk(hs.access_token,"statistics",{days:30});assert.equal(consolidated.scope,"enterprise");assert.ok(Number.isInteger(consolidated.polls_closed)&&consolidated.polls_closed>=0);assert.ok(Number.isInteger(consolidated.tasks_done)&&consolidated.tasks_done>=0);
 assert.equal((await centerReq(hs.access_token,"statistics",{days:999})).status,403);
 pass("workspace private chat exact retry, peer/tenant denial, search, explicit read acknowledgement and role-scoped summary");

 // Dedicated support agents, no implicit rights for a tenant promoter.
 const sa=await fixture(other,"staff"),sb=await fixture(other,"staff"),sas=await login(sa),sbs=await login(sb);
 await rest("wm_support_agents",{account_id:sa.id,enabled:true});await rest("wm_support_agents",{account_id:sb.id,enabled:true});
 const sr=(token,action,data={})=>request(auth+"/identity",{action:"support-"+action,data},token);
 const sk=(token,action,data={})=>ok(auth+"/identity",{action:"support-"+action,data},token);
 assert.equal((await sk(hs.access_token,"capabilities")).agent,false);
 const supportTicket={ticket_id:randomUUID(),message_id:randomUUID(),subject:"Synthetic support request",category:"meeting",body:"Synthetic issue"};
 await sk(hs.access_token,"create",supportTicket);await sk(hs.access_token,"create",supportTicket);
 assert.equal((await sr(gs.access_token,"read",{ticket_id:supportTicket.ticket_id})).status,403);
 assert.equal((await sr(os.access_token,"queue")).status,403);
 assert.equal((await sr(sas.access_token,"read",{ticket_id:supportTicket.ticket_id})).status,403);
 assert.equal((await sr(sas.access_token,"reply",{ticket_id:supportTicket.ticket_id,message_id:randomUUID(),body:"Must not write before claim"})).status,403);
 assert.equal((await sr(sas.access_token,"close",{ticket_id:supportTicket.ticket_id})).status,403);
 const claim=await Promise.all([sr(sas.access_token,"claim",{ticket_id:supportTicket.ticket_id}),sr(sbs.access_token,"claim",{ticket_id:supportTicket.ticket_id})]);
 assert.equal(claim.filter(x=>x.status===200).length,1);
 const winner=claim[0].status===200?sas:sbs,loser=claim[0].status===200?sbs:sas;
 assert.equal((await sr(loser.access_token,"read",{ticket_id:supportTicket.ticket_id})).status,403);
 const replyData={ticket_id:supportTicket.ticket_id,message_id:randomUUID(),body:"Synthetic answer"};
 await sk(winner.access_token,"reply",replyData);await sk(winner.access_token,"reply",replyData);
 assert.equal((await sk(hs.access_token,"read",{ticket_id:supportTicket.ticket_id})).messages.length,2);
 // B5: feedback and assignment lifecycle, same disposable real accounts.
 assert.equal((await sr(hs.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:5})).status,403);
 assert.equal((await sr(loser.access_token,"release",{ticket_id:supportTicket.ticket_id})).status,403);
 assert.equal((await sr(hs.access_token,"release",{ticket_id:supportTicket.ticket_id})).status,403);
 await sk(winner.access_token,"release",{ticket_id:supportTicket.ticket_id});
 await sk(winner.access_token,"release",{ticket_id:supportTicket.ticket_id});
 assert.equal((await sr(winner.access_token,"read",{ticket_id:supportTicket.ticket_id})).status,403);
 await sk(loser.access_token,"claim",{ticket_id:supportTicket.ticket_id});
 assert.equal((await sr(winner.access_token,"release",{ticket_id:supportTicket.ticket_id})).status,403);
 await sk(hs.access_token,"close",{ticket_id:supportTicket.ticket_id});
 assert.equal((await sr(loser.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:5})).status,403);
 assert.equal((await sr(hs.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:6})).status,403);
 assert.equal((await sr(hs.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:"5"})).status,403);
 assert.equal((await sk(hs.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:4})).saved,true);
 assert.equal((await sk(hs.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:4})).saved,true);
 assert.equal((await sr(hs.access_token,"feedback",{ticket_id:supportTicket.ticket_id,rating:5})).status,403);
 assert.equal((await sk(hs.access_token,"read",{ticket_id:supportTicket.ticket_id})).feedback,4);
 assert.equal((await sk(loser.access_token,"read",{ticket_id:supportTicket.ticket_id})).feedback,null);
 pass("B5 real requester feedback, exact replay, reassignment, old agent revocation and private rating");
 assert.equal((await sr(winner.access_token,"reply",{...replyData,message_id:randomUUID()})).status,403);
 pass("private support ticket: exact retry, cross-account denial, atomic agent claim, isolated reply and closure");

 const denied=await request(auth+"/login",{identifier:h.login,password:"wrong",installation_id:randomUUID(),platform:"web"});assert.equal(denied.status,401);
 const rec=await ok(auth+"/request-recovery",{identifier:h.login,installation_id:randomUUID(),platform:"web"});const unknown=await ok(auth+"/request-recovery",{identifier:"WM-UNKNOWN123",installation_id:randomUUID(),platform:"web"});assert.deepEqual(rec,unknown);assert.equal(rec.accepted,true);
 pass("actual GoTrue login and neutral recovery intake");
 const identity=(token,action,data={})=>ok(auth+"/identity",{action,data},token);
 const identityRequest=(token,action,data={})=>request(auth+"/identity",{action,data},token);
 const original=await identity(hs.access_token,"profile");
 const languagePref={interface:"fr",spoken:"ff",listening:"en",subtitles:"original",pdf:"en",rate:"1.25"};
 assert.deepEqual(await identity(hs.access_token,"language-save",languagePref),languagePref);
 assert.deepEqual(await identity(hs.access_token,"language-preferences"),languagePref);
 assert.equal((await identity(gs.access_token,"language-preferences")).spoken,"auto");
 assert.equal((await identityRequest(gs.access_token,"language-preferences",{account_id:h.id})).status,403);
 assert.equal((await identityRequest(hs.access_token,"language-save",{...languagePref,interface:"ff"})).status,403);
 assert.equal((await identityRequest(hs.access_token,"language-save",{...languagePref,rate:1.25})).status,403);
 assert.equal((await identityRequest(hs.access_token,"language-save",{...languagePref,account_id:g.id})).status,403);
 assert.equal((await identity(hs.access_token,"language-reset")).listening,"original");
 pass("actual individual language preferences persisted, strict validation, reset and account isolation");
 // Synthetic 8x8 JPEG; no real personal data. Private self-profile only.
 const photo="/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAAIAAgBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AP//Z";
 assert.equal((await identity(hs.access_token,"photo-read")).jpeg,null);
 assert.equal((await identityRequest(hs.access_token,"photo-save",{jpeg:"bm90IGFuIGltYWdl"})).status,400);
 assert.equal((await identity(hs.access_token,"photo-save",{jpeg:photo})).updated,true);
 assert.equal((await identity(hs.access_token,"photo-read")).jpeg,photo);
 assert.equal((await identity(gs.access_token,"photo-read")).jpeg,null);
 assert.equal((await identityRequest(gs.access_token,"photo-read",{account_id:h.id})).status,403);
 assert.equal((await identityRequest(gs.access_token,"photo-delete",{account_id:h.id})).status,403);
 assert.equal((await identity(hs.access_token,"photo-delete")).updated,true);
 assert.equal((await identity(hs.access_token,"photo-read")).jpeg,null);
 pass("actual N1 private profile JPEG save/read/delete, validation and account isolation");

 assert.equal(original.role,"promoteur");
 await identity(hs.access_token,"profile-update",{display_name:"Replay promoteur",locale:"fr"});
 for(let step=1;step<=5;step++)assert.equal((await identity(hs.access_token,"onboarding-step",{step})).step,step);
 assert.equal((await identity(hs.access_token,"profile")).onboarding_step,5);
 await identity(hs.access_token,"favorite",{member_id:g.id,enabled:true});
 assert.equal((await identity(hs.access_token,"contacts")).contacts.find(x=>x.member_id===g.id).favorite,true);
 assert.equal((await identityRequest(hs.access_token,"favorite",{member_id:o.id,enabled:true})).status,403);
 const groupId=randomUUID();
 const groupData={id:groupId,name:"Replay group",member_ids:[g.id]};
 assert.equal((await identityRequest(hs.access_token,"group-save",{...groupData,member_ids:[o.id]})).status,403);
 await identity(hs.access_token,"group-save",groupData);
 await identity(hs.access_token,"group-save",{...groupData,name:"Edited replay group"});
 assert.deepEqual((await identity(hs.access_token,"groups")).groups,[{id:groupId,name:"Edited replay group",member_ids:[g.id]}]);
 assert.deepEqual((await identity(gs.access_token,"groups")).groups,[]);
 assert.equal((await identityRequest(gs.access_token,"group-delete",{id:groupId})).status,403);
 assert.equal((await identityRequest(os.access_token,"group-save",{...groupData,member_ids:[]})).status,403);
 await identity(hs.access_token,"group-delete",{id:groupId});
 assert.deepEqual((await identity(hs.access_token,"groups")).groups,[]);
 pass("actual N1 contact group CRUD and account/workspace isolation");
 // Separate enterprise: direct manager assignment does not leak rights to unassigned staff.
 const scopeW=await createWorkspace("Manager scope replay");
 const scopeOwner=await fixture(scopeW,"promoteur"),scopeManager=await fixture(scopeW,"manager"),scopeStaff=await fixture(scopeW,"staff"),scopeOther=await fixture(scopeW,"staff");
 const so=await login(scopeOwner),sm=await login(scopeManager),ss=await login(scopeStaff),su=await login(scopeOther);
 assert.equal((await identityRequest(sm.access_token,"revoke-member",{member_id:scopeStaff.id})).status,403);
 assert.equal((await identityRequest(sm.access_token,"manager-assign",{member_id:scopeStaff.id,manager_id:scopeManager.id})).status,403);
 assert.equal((await identityRequest(so.access_token,"manager-assign",{member_id:scopeStaff.id,manager_id:o.id})).status,403);
 await identity(so.access_token,"manager-assign",{member_id:scopeStaff.id,manager_id:scopeManager.id});
 const scopedContacts=(await identity(sm.access_token,"contacts")).contacts;
 assert.equal((await identity(so.access_token,"dashboard")).team_count,3);
 assert.equal((await identity(sm.access_token,"dashboard")).team_count,1);
 assert.equal((await identity(ss.access_token,"dashboard")).team_count,null);

 assert.deepEqual(scopedContacts.filter(c=>c.can_revoke).map(c=>c.member_id),[scopeStaff.id]);
 assert.equal((await identityRequest(sm.access_token,"revoke-member",{member_id:scopeOther.id})).status,403);
 assert.equal((await identityRequest(sm.access_token,"revoke-member",{member_id:scopeOwner.id})).status,403);
 await identity(so.access_token,"manager-assign",{member_id:scopeStaff.id,manager_id:null});
 assert.equal((await identityRequest(sm.access_token,"revoke-member",{member_id:scopeStaff.id})).status,403);
 await identity(so.access_token,"manager-assign",{member_id:scopeStaff.id,manager_id:scopeManager.id});
 const revokedChat={peer_id:scopeStaff.id,message_id:randomUUID(),body:"Revocation fixture"};
 await centerOk(sm.access_token,"send",revokedChat);
 assert.equal((await centerOk(sm.access_token,"statistics",{days:30})).scope,"organizer");
 await identity(sm.access_token,"revoke-member",{member_id:scopeStaff.id});
 assert.equal((await centerReq(sm.access_token,"thread",{peer_id:scopeStaff.id})).status,403);
 assert.equal((await centerReq(ss.access_token,"thread",{peer_id:scopeManager.id})).status,403);
 assert.equal((await identityRequest(ss.access_token,"profile")).status,403);
 assert.equal((await identity(su.access_token,"profile")).role,"staff");
 assert.equal((await identity(sm.access_token,"dashboard")).team_count,0);
 assert.equal((await identity(so.access_token,"dashboard")).team_count,2);
 pass("actual N1 role-scoped dashboard counters after assignment and revocation");
 assert.ok(!(await identity(so.access_token,"contacts")).contacts.some(c=>c.member_id===scopeStaff.id));
 pass("actual N1 manager scope, promoter-only assignment, foreign and unassigned denials, scoped revocation");

 assert.equal((await identityRequest(gs.access_token,"billing")).status,403);
 assert.equal((await identity(hs.access_token,"billing")).plan,"premium");
 const billingRequest={request_id:randomUUID(),offer:"premium",period:"month",capacity:50,channel:"OM"};
 assert.equal((await identityRequest(gs.access_token,"billing-create",billingRequest)).status,403);
 const intent=await identity(hs.access_token,"billing-create",billingRequest);
 assert.equal(intent.amount,10000);assert.equal(intent.currency,"XAF");assert.equal(intent.status,"pending");
 assert.deepEqual(await identity(hs.access_token,"billing-create",billingRequest),intent);
 assert.equal((await identityRequest(hs.access_token,"billing-create",{...billingRequest,channel:"MOMO"})).status,403);
 const listed=(await identity(hs.access_token,"billing-list")).intents;assert.ok(listed.some(x=>x.id===intent.id&&x.status==="pending"));
 assert.equal((await identityRequest(os.access_token,"billing-cancel",{id:intent.id})).status,403);
 assert.equal((await identity(hs.access_token,"billing-cancel",{id:intent.id})).status,"cancelled");
 assert.equal((await identity(hs.access_token,"billing")).plan,"premium");
 pass("actual N1 isolated payment intent creation, exact quote, replay, payer and tenant isolation, cancellation; no transfer");

 assert.equal((await identity(hs.access_token,"dashboard")).role,"promoteur");
 await identity(hs.access_token,"invite",{login_id:o.login,role:"staff"});
 const incoming=(await identity(os.access_token,"invitations")).invitations;
 assert.equal(incoming.length,1);
 assert.equal((await identityRequest(gs.access_token,"respond-invite",{id:incoming[0].id,accept:true})).status,403);
 await identity(os.access_token,"respond-invite",{id:incoming[0].id,accept:true});
 const fresh=await login(o);assert.equal(fresh.workspaces.length,2);
 const switched=await ok(auth+"/switch-workspace",{workspace_id:w},fresh.access_token);
 assert.equal(switched.active_workspace_id,w);
 assert.equal((await identity(switched.access_token,"profile")).role,"staff");
 await identity(hs.access_token,"revoke-member",{member_id:o.id});
 assert.equal((await identityRequest(switched.access_token,"profile")).status,403);
 // Original foreign session remains confined to its own company.
 assert.equal((await identity(os.access_token,"profile")).workspace_name,"Replay B");
 pass("actual N1 profile and onboarding persistence, scoped favorites, payer-only billing, invitation and membership revocation");
 const renewable=await fixture(other,"manager"),installation=randomUUID();
 const first=await ok(auth+"/login",{identifier:renewable.login,password:renewable.password,installation_id:installation,platform:"android",remember_me:true});
 assert.match(first.refresh_token,/^[a-f0-9]{64}$/);
 const renewed=await ok(auth+"/refresh",{refresh_token:first.refresh_token,installation_id:installation,platform:"android"});
 assert.notEqual(renewed.refresh_token,first.refresh_token);
 assert.notEqual(renewed.access_token,first.access_token);
 assert.equal(renewed.member_id,renewable.id);
 assert.equal((await identityRequest(first.access_token,"profile")).status,403);
 assert.equal((await request(auth+"/refresh",{refresh_token:first.refresh_token,installation_id:installation,platform:"android"})).status,401);
 assert.equal((await request(auth+"/refresh",{refresh_token:renewed.refresh_token,installation_id:randomUUID(),platform:"android"})).status,401);
 const second=await ok(auth+"/login",{identifier:renewable.login,password:renewable.password,installation_id:randomUUID(),platform:"android",remember_me:true});
 const devices=(await identity(renewed.access_token,"devices")).devices;
 assert.ok(devices.some(d=>d.id===second.device_id&&!d.current));
 await identity(renewed.access_token,"revoke-device",{id:second.device_id});
 assert.equal((await identityRequest(second.access_token,"profile")).status,403);
 await ok(auth+"/logout",{},renewed.access_token);
 assert.equal((await request(auth+"/refresh",{refresh_token:renewed.refresh_token,installation_id:installation,platform:"android"})).status,401);
 pass("actual N1 native refresh rotation, old secret and wrong installation denial, device revocation and logout");


 const contacts=await ok(room+"/contacts",{},hs.access_token);assert.equal(contacts.length,1);assert.equal(contacts[0].member_id,g.id);
 const rid=randomUUID(),create={room_id:rid,title:"Replay real meeting",description:"Scoped control plane",scheduled_ms:Date.now(),duration_minutes:30,invitees:[g.id]};
 assert.equal((await request(room+"/create",create,gs.access_token)).status,409);
 assert.equal((await request(room+"/create",{...create,invitees:[o.id]},hs.access_token)).status,409);
 let state=await ok(room+"/create",create,hs.access_token);
 assert.equal(state.status,"scheduled");
 assert.equal((await request(room+"/read",{room_id:rid},os.access_token)).status,404);
 assert.equal((await ok(room+"/list",{},os.access_token)).length,0);
 async function cmd(token,action,value=null,target=null){state=await ok(room+"/command",{room_id:rid,request_id:randomUUID(),expected_revision:state.revision,action,value,target},token);return state;}
 await cmd(gs.access_token,"respond","accepted");
 await cmd(hs.access_token,"reschedule",{title:"Replay revised meeting",description:"Updated agenda",scheduledMs:Date.now()+60000,durationMinutes:30});
 assert.equal(state.participants.find(p=>p.memberId===g.id).response,"pending");
 await cmd(gs.access_token,"respond","accepted");await cmd(hs.access_token,"start");assert.equal(state.status,"open");
 await cmd(gs.access_token,"chat","Hello from real account");
 assert.equal(state.events[0].value,"Hello from real account");
 await cmd(gs.access_token,"private_chat","Private fixture message",h.id);
 assert.ok(state.events.some(e=>e.action==="private_chat"&&e.target===h.id));
 const receivedPrivate=await ok(room+"/read",{room_id:rid},hs.access_token);
 assert.ok(receivedPrivate.events.some(e=>e.action==="private_chat"&&e.value==="Private fixture message"));
 assert.equal((await request(room+"/read",{room_id:rid},os.access_token)).status,404);
 pass("actual rescheduling requires new RSVP, private message delivery and foreign tenant denial");
 await cmd(gs.access_token,"hand",true);
 await cmd(hs.access_token,"mute",null,g.id);
 assert.equal(state.participants.find(p=>p.memberId===g.id).mic,false);
 await cmd(hs.access_token,"consent",true);await cmd(gs.access_token,"consent",true);await cmd(hs.access_token,"record",true);
 assert.equal(state.recording,"requested");await cmd(gs.access_token,"consent",false);assert.equal(state.recording,"off");
 const pid=randomUUID();await cmd(hs.access_token,"poll",["Yes","No"],pid);await cmd(gs.access_token,"vote",0,pid);assert.equal(state.polls[0].counts[0],1);assert.equal(state.polls[0].votes,undefined);await cmd(hs.access_token,"close_poll",null,pid);
 const originalDeadline=state.endMs;
 await cmd(hs.access_token,"extend",15);assert.equal(state.endMs,originalDeadline+900000);
 const sid=randomUUID();await cmd(hs.access_token,"survey",{question:"Choose dates",kind:"multiple",options:["A","B","C"],anonymous:true,visibility:"closed",quorum:100,threshold:50},sid);
 await cmd(gs.access_token,"survey_vote",[0,2],sid);let survey=state.polls.find(p=>p.id===sid);
 assert.equal(survey.counts,null);assert.equal(survey.responses,null);assert.equal(survey.votes,undefined);
 await cmd(hs.access_token,"survey_vote",[0],sid);await cmd(hs.access_token,"close_poll",null,sid);survey=state.polls.find(p=>p.id===sid);
 assert.deepEqual(survey.counts,[2,0,1]);assert.equal(survey.quorumMet,true);assert.deepEqual(survey.accepted,[true,false,true]);
 pass("real duration extension and delayed anonymous multiple choice survey");
 const nid=randomUUID();
 await cmd(hs.access_token,"survey",{question:"Nominative test",kind:"single",options:["A","B"],anonymous:false,editable:true,visibility:"closed",quorum:0,threshold:50},nid);
 await cmd(gs.access_token,"survey_vote",[0],nid);assert.equal(state.polls.find(p=>p.id===nid).nominativeResponses,null);
 await cmd(gs.access_token,"survey_vote",[1],nid);await cmd(hs.access_token,"close_poll",null,nid);
 assert.deepEqual(state.polls.find(p=>p.id===nid).nominativeResponses,[{memberId:g.id,selection:[1]}]);
 pass("actual editable nominative survey preserves secrecy until closure");
 await cmd(hs.access_token,"pause");await cmd(hs.access_token,"resume");await cmd(hs.access_token,"exclude",null,g.id);
 assert.equal((await request(room+"/read",{room_id:rid},gs.access_token)).status,404);
 await cmd(hs.access_token,"end");assert.equal(state.status,"ended");
 pass("actual Edge/PostgREST room create, RSVP, chat, moderation, consent, vote, exclusion, tenant isolation; no media capture");
 // Isolated N4 fixture: three admitted members, explicit selective publication.
 const minuteW=await createWorkspace("Minutes isolated replay"),mh=await fixture(minuteW,"promoteur"),mg=await fixture(minuteW,"staff"),mo=await fixture(minuteW,"staff");
 const mhs=await login(mh),mgs=await login(mg),mos=await login(mo),mid=randomUUID();
 let ms=await ok(room+"/create",{room_id:mid,title:"Minutes qualification",description:"Synthetic meeting",scheduled_ms:Date.now(),duration_minutes:10,invitees:[mg.id]},mhs.access_token);
 async function mcmd(token,action,value=null,target=null){ms=await ok(room+"/command",{room_id:mid,request_id:randomUUID(),expected_revision:ms.revision,action,value,target},token)}
 await mcmd(mhs.access_token,"lobby_config",true);
 const agendaId=randomUUID();await mcmd(mhs.access_token,"set_agenda",[{id:agendaId,title:"Synthetic agenda",minutes:5,owner:mg.id}]);await mcmd(mhs.access_token,"confidentiality","confidential");
 await mcmd(mgs.access_token,"respond","accepted");await mcmd(mhs.access_token,"start");
 const waiting=await ok(room+"/read",{room_id:mid},mgs.access_token);assert.equal(waiting.lobbyRequired,true);assert.equal(waiting.participants.length,0);assert.equal(waiting.events.length,0);
 assert.equal((await request(room+"/media-grant",{room_id:mid},mgs.access_token)).status,403);
 await mcmd(mgs.access_token,"lobby_request");await mcmd(mhs.access_token,"lobby_reject",null,mg.id);
 await mcmd(mgs.access_token,"lobby_request");await mcmd(mhs.access_token,"lobby_admit",null,mg.id);
 assert.equal((await ok(room+"/read",{room_id:mid},mgs.access_token)).lobbyStatus,"admitted");
 await mcmd(mhs.access_token,"agenda_status","active",agendaId);await mcmd(mhs.access_token,"agenda_status","done",agendaId);assert.equal((await ok(room+"/read",{room_id:mid},mgs.access_token)).agenda[0].status,"done");assert.equal(ms.confidentiality,"confidential");
 assert.equal((await request(room+"/command",{room_id:mid,request_id:randomUUID(),expected_revision:ms.revision,action:"screen",target:mg.id,value:true},mhs.access_token)).status,409);
 pass("actual structured agenda progression and confidential screen restriction");
 pass("actual N2 internal waiting room rejects live state until explicit admission and permits controlled retry");
 await mcmd(mhs.access_token,"invite_member",null,mo.id);
 await mcmd(mhs.access_token,"lock_admission",true);
 const lateAccept={room_id:mid,request_id:randomUUID(),expected_revision:ms.revision,action:"respond",value:"accepted"};
 assert.equal((await request(room+"/command",lateAccept,mos.access_token)).status,409);
 await mcmd(mhs.access_token,"lock_admission",false);await mcmd(mos.access_token,"respond","accepted");await mcmd(mos.access_token,"lobby_request");await mcmd(mhs.access_token,"lobby_admit",null,mo.id);
 await mcmd(mgs.access_token,"private_chat","Private among two of three",mh.id);
 assert.ok((await ok(room+"/read",{room_id:mid},mhs.access_token)).events.some(e=>e.value==="Private among two of three"));
 assert.ok(!(await ok(room+"/read",{room_id:mid},mos.access_token)).events.some(e=>e.value==="Private among two of three"));
 pass("actual N2 late invitation, admission lock/unlock and private chat denied to admitted third member");
 await mcmd(mhs.access_token,"set_moderator",["microphone"],mg.id);await mcmd(mgs.access_token,"mute",null,mo.id);
 assert.equal((await ok(room+"/read",{room_id:mid},mos.access_token)).participants.find(p=>p.memberId===mo.id).mic,false);
 const forbiddenMod={room_id:mid,request_id:randomUUID(),expected_revision:ms.revision,action:"exclude",target:mo.id};assert.equal((await request(room+"/command",forbiddenMod,mgs.access_token)).status,409);
 await mcmd(mhs.access_token,"set_moderator",[],mg.id);assert.equal((await request(room+"/command",{...forbiddenMod,request_id:randomUUID(),expected_revision:ms.revision,action:"allow_mic"},mgs.access_token)).status,409);
 pass("actual N2 temporary moderator permission, denied escalation and immediate revocation");
 await mcmd(mhs.access_token,"end");
 await success(base+"/rest/v1/wm_room_entitlements?workspace_id=eq."+minuteW,{valid_until:new Date(Date.now()+60*86400000).toISOString()},service,service,"PATCH");
 const series={series_id:randomUUID(),room_ids:[randomUUID(),randomUUID(),randomUUID()],title:"Series fixture",description:"UTC recurring",scheduled_ms:Date.now()+60000,duration_minutes:10,invitees:[mg.id],recurrence:"weekly",interval:1};
 assert.equal((await request(room+"/series-create",series,mgs.access_token)).status,403);
 const badSeries={...series,series_id:randomUUID(),room_ids:[randomUUID(),mid,randomUUID()]};
 assert.equal((await request(room+"/series-create",badSeries,mhs.access_token)).status,409);
 assert.ok(!(await ok(room+"/list",{},mhs.access_token)).some(x=>x.id===badSeries.room_ids[0]));
 assert.equal((await ok(room+"/series-create",series,mhs.access_token)).count,3);
 assert.equal((await ok(room+"/series-create",series,mhs.access_token)).count,3);
 const dates=(await ok(room+"/list",{},mhs.access_token)).filter(x=>series.room_ids.includes(x.id)).map(x=>x.scheduled_ms).sort((a,b)=>a-b);
 assert.equal(dates.length,3);assert.equal(dates[1]-dates[0],604800000);
 assert.equal((await request(room+"/series-cancel",{series_id:series.series_id},mgs.access_token)).status,403);
 assert.equal((await ok(room+"/series-cancel",{series_id:series.series_id},mhs.access_token)).cancelled,3);
 assert.ok((await ok(room+"/list",{},mhs.access_token)).filter(x=>series.room_ids.includes(x.id)).every(x=>x.status==="ended"));
 pass("actual N2 atomic recurrence creation, retry, rollback, tenant rights and whole series cancellation");
 const mreq=(token,action,data={})=>request(room+"/minutes",{action,data},token);
 const mok=(token,action,data={})=>ok(room+"/minutes",{action,data},token);
 const prep=await mok(mhs.access_token,"prepare",{room_id:mid});assert.equal(prep.latest_version,0);assert.equal(prep.premium,true);
 assert.ok(prep.snapshot.participants.every(x=>x.attendance==="unknown"));
 // Valid rights at closure, not a live subscription for archive access.
 await success(base+"/rest/v1/wm_room_entitlements?workspace_id=eq."+minuteW,{valid_until:new Date(Date.now()-60000).toISOString()},service,service,"PATCH");
 const mv1=randomUUID(),draft={room_id:mid,version_id:mv1,expected_version:0,body:"Synthetic human minutes"};
 assert.equal((await mreq(mgs.access_token,"draft",draft)).status,403);
 assert.equal((await mok(mhs.access_token,"draft",draft)).version,1);
 assert.deepEqual(await mok(mhs.access_token,"draft",draft),{version_id:mv1,version:1});
 assert.equal((await mreq(mhs.access_token,"draft",{...draft,body:"Altered"})).status,403);
 const publication={room_id:mid,version_id:mv1,recipients:[mg.id]};
 assert.equal((await mreq(mhs.access_token,"publish",publication)).status,403);
 assert.equal((await mreq(mgs.access_token,"read",publication)).status,403);
 assert.equal((await mreq(mhs.access_token,"export",{...publication,request_id:randomUUID()})).status,403);
 await mok(mhs.access_token,"approve",publication);
 assert.equal((await mreq(mhs.access_token,"publish",{...publication,recipients:[o.id]})).status,403);
 await mok(mhs.access_token,"publish",publication);
 assert.equal((await mreq(mos.access_token,"read",publication)).status,403);
 assert.equal((await mreq(os.access_token,"read",publication)).status,403);
 assert.ok((await mok(mgs.access_token,"list")).items.some(x=>x.room_id===mid&&x.unread));
 assert.equal((await mok(mgs.access_token,"read",publication)).body,draft.body);
 const guestNotices=await ok(room+"/notices",{},mgs.access_token),otherNotices=await ok(room+"/notices",{},mos.access_token);const notice=guestNotices.items.find(x=>x.k==="minutes:"+mv1);assert.ok(notice);assert.ok(!otherNotices.items.some(x=>x.k===notice.k));assert.equal((await request(room+"/notices",{read:notice.k},mos.access_token)).status,403);assert.equal((await ok(room+"/notices",{read:notice.k},mgs.access_token)).read,true);assert.ok((await ok(room+"/notices",{},mgs.access_token)).items.find(x=>x.k===notice.k).read_at);pass("actual N4 recipient-scoped in-app notice, read receipt and forbidden third party");
 const exportRequest={...publication,request_id:randomUUID()};assert.equal((await mreq(mos.access_token,"export",exportRequest)).status,403);const exportData=await mok(mgs.access_token,"export",exportRequest);assert.equal(exportData.body,draft.body);assert.equal(exportData.verification_id,mv1);assert.ok(exportData.recipient_name);assert.equal((await mreq(mhs.access_token,"export",exportRequest)).status,403);pass("actual N4 exact published PDF export payload, recipient watermark identity and audit request isolation");
 const treq=(token,action,data={})=>request(room+"/tasks",{action,data},token);
 const tok=(token,action,data={})=>ok(room+"/tasks",{action,data},token);
 const task={id:randomUUID(),room_id:mid,version_id:mv1,assignee_id:mg.id,title:"Verify human decision",due_at:new Date(Date.now()+86400000).toISOString()};
 assert.equal((await treq(mgs.access_token,"create",task)).status,403);
 assert.equal((await treq(mhs.access_token,"create",{...task,assignee_id:mo.id})).status,403);
 assert.equal((await tok(mhs.access_token,"create",task)).revision,1);
 assert.equal((await tok(mhs.access_token,"create",task)).revision,1);
 assert.equal((await tok(mos.access_token,"list")).items.length,0);
 assert.equal((await tok(os.access_token,"list")).items.length,0);
 assert.equal((await tok(mgs.access_token,"list")).items[0].id,task.id);
 const evidence={id:task.id,expected_revision:1,evidence:"Synthetic proof"};
 assert.equal((await treq(mos.access_token,"submit",evidence)).status,403);
 await tok(mgs.access_token,"submit",evidence);
 assert.equal((await treq(mgs.access_token,"approve",{id:task.id,expected_revision:2})).status,403);
 await tok(mhs.access_token,"return",{id:task.id,expected_revision:2});
 await tok(mgs.access_token,"submit",{...evidence,expected_revision:3});
 await tok(mhs.access_token,"approve",{id:task.id,expected_revision:4});
 assert.equal((await tok(mgs.access_token,"list")).items[0].state,"done");
 pass("actual N4 task assignment, evidence, correction, approval, idempotence and tenant/recipient isolation");
 const reportBody={app_id:"WIDEMEET",room_id:mid,request_id:randomUUID(),locale:"fr"};const reportReq=token=>fetch(room+"/report-xlsx",{method:"POST",headers:{apikey:anon,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify(reportBody)});assert.equal((await reportReq(mgs.access_token)).status,403);const excel=await reportReq(mhs.access_token);assert.equal(excel.status,200);const xlsx=Buffer.from(await excel.arrayBuffer());assert.equal(xlsx.subarray(0,2).toString(),"PK");assert.ok(xlsx.includes(Buffer.from("Verify human decision")));pass("actual N4 authorized Excel report, real OOXML and recipient denial");

 assert.ok((await mok(mgs.access_token,"list")).items.some(x=>x.room_id===mid&&!x.unread));
 const mv2=randomUUID(),rev={room_id:mid,version_id:mv2,expected_version:1,body:"Revised synthetic human minutes"};
 await mok(mhs.access_token,"draft",rev);
 assert.equal((await mreq(mgs.access_token,"read",rev)).status,403);
 await mok(mhs.access_token,"approve",rev);await mok(mhs.access_token,"publish",{...rev,recipients:[mg.id]});
 assert.equal((await mreq(mgs.access_token,"read",publication)).status,403);
 assert.equal((await tok(mgs.access_token,"list")).items.length,0);
 assert.equal((await mok(mgs.access_token,"read",rev)).body,rev.body);
 await mok(mhs.access_token,"revoke",rev);assert.equal((await mreq(mgs.access_token,"read",rev)).status,403);
 pass("actual N4 closed-room minutes versioning, expiry-independent archives, approval, selected recipients, read audit and revocation");

 assert.equal((await request(room+"/media-grant",{room_id:rid},hs.access_token)).status,403);
 await ok(auth+"/logout",{},hs.access_token);assert.equal((await request(room+"/list",{},hs.access_token)).status,403);pass("real opaque session logout and revocation");
 // Test real browser with TLS restricted to isolated loopback. No mock HTTP or fake login.
 const dir=resolve("apps/web/widemeet/dist");
 server=createServer({key:await readFile(process.env.WM_REPLAY_KEY),cert:await readFile(process.env.WM_REPLAY_CERT)},async(req,res)=>{
 try{
 const u=new URL(req.url,"https://127.0.0.1:8443");
 if(u.pathname.startsWith("/functions/v1/widemeet-auth/")||u.pathname.startsWith("/functions/v1/widemeet-room/")){
 const target=u.pathname.includes("/widemeet-auth/")?auth:room;
 const chunks=[];for await(const chunk of req)chunks.push(chunk);
 const rr=await fetch(target+u.pathname,{method:req.method,headers:{...req.headers,host:"127.0.0.1",connection:"close"},body:req.method==="POST"?Buffer.concat(chunks):undefined});
 res.writeHead(rr.status,Object.fromEntries(rr.headers));res.end(Buffer.from(await rr.arrayBuffer()));return;
 }
 const p=resolve(dir,"."+u.pathname);if(p!==dir&&!p.startsWith(dir+sep)){res.writeHead(403);res.end();return}
 const file=(await stat(p).catch(()=>null))?.isFile()?p:resolve(dir,"index.html");
 const types={".html":"text/html",".js":"text/javascript",".css":"text/css",".json":"application/json",".png":"image/png",".svg":"image/svg+xml",".webmanifest":"application/manifest+json"};
 res.writeHead(200,{"Content-Type":types[extname(file)]??"application/octet-stream","Cache-Control":"no-store"});res.end(await readFile(file));
 }catch{res.writeHead(502);res.end();}
 });
 await new Promise((r,reject)=>{server.once("error",reject);server.listen(8443,"127.0.0.1",r)});
 browser=await chromium.launch({headless:true});
 const hc=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"}),gc=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"}),hp=await hc.newPage(),gp=await gc.newPage();
 async function sign(page,f,remember=false){
 await page.goto("https://127.0.0.1:8443");
 await page.getByRole("button",{name:"Se connecter",exact:true}).click();
 await page.getByLabel("Identifiant WideMeet",{exact:true}).fill(f.login);
 await page.getByLabel("Mot de passe",{exact:true}).fill(f.password);
 if(remember)await page.getByLabel("Rester connecté",{exact:true}).check();
 await page.getByRole("button",{name:"Se connecter",exact:true}).click();
 await page.getByText("Replay A",{exact:true}).waitFor();
 await page.getByRole("navigation").getByRole("button",{name:"Agenda"}).click();
 await page.getByRole("region",{name:"Réunions"}).waitFor();
 }
 await sign(hp,h,true);await hp.getByRole("region",{name:"Réunions"}).getByRole("button",{name:"Nouvelle réunion",exact:true}).click();
 await hp.getByLabel("Titre",{exact:true}).fill("Replay browser room");
 await hp.getByLabel("Replay staff",{exact:true}).check();
 await hp.getByRole("button",{name:"Créer",exact:true}).click();
 await hp.getByRole("heading",{name:"Replay browser room",exact:true}).waitFor();
 await sign(gp,g);await gp.getByRole("button",{name:/Replay browser room/}).click();
 await gp.getByRole("button",{name:"Accepter",exact:true}).click();
 await hp.getByRole("button",{name:"Actualiser",exact:true}).click();await hp.getByRole("button",{name:"Ouvrir la salle",exact:true}).click();
 await hp.getByText("Audio et vidéo indisponibles pour le moment.",{exact:true}).waitFor();
 await gp.getByRole("button",{name:"Actualiser",exact:true}).click();await gp.getByLabel("Message",{exact:true}).fill("Bonjour réel");
 await gp.getByRole("button",{name:"Envoyer",exact:true}).click();await gp.getByText(/Bonjour réel/).waitFor();
 // Host must receive the message through automatic polling, not a manual refresh.
 await hp.getByText(/Bonjour réel/).waitFor({timeout:15000});
 pass("two real browser accounts: login, agenda, creation, RSVP, start, chat and automatic refresh");
 const cookies=await hc.cookies();const refreshCookie=cookies.find(c=>c.name==="__Host-widemeet_refresh");assert.ok(refreshCookie?.httpOnly&&refreshCookie?.secure&&refreshCookie?.sameSite==="Strict");
 await hp.reload();await hp.getByText("Replay A",{exact:true}).waitFor({timeout:20000});
 assert.equal(await hp.evaluate(()=>localStorage.getItem("widemeet.remember.preference")),"yes");
 assert.equal(await hp.evaluate(()=>Object.values(localStorage).some(v=>/^[a-f0-9]{64}$/.test(v))),false);
 assert.equal(await hp.evaluate(()=>document.cookie.includes("__Host-widemeet_refresh")),false);
 pass("actual remembered Web session restored after reload using HttpOnly secure cookie without exposed refresh token");
 await hp.getByRole("navigation").getByRole("button",{name:"Profil",exact:true}).click();
 const picker=hp.getByLabel("Choisir une photo",{exact:true});
 await picker.waitFor();
 await picker.setInputFiles({name:"synthetic-profile.jpg",mimeType:"image/jpeg",buffer:Buffer.from(photo,"base64")});
 const photoPreview=hp.getByRole("img",{name:"Votre photo de profil",exact:true});
 await photoPreview.waitFor({timeout:15000});
 assert.ok(await photoPreview.evaluate(img=>img.complete&&img.naturalWidth>0));
 await hp.getByRole("button",{name:"Supprimer la photo",exact:true}).click();
 await photoPreview.waitFor({state:"detached",timeout:15000});
 pass("actual Web profile photo selection, re-encoding, private preview and removal");
 // All new meeting centers must render real authorized data, not placeholder navigation.
 await hp.getByRole("navigation").getByRole("button",{name:"Chat",exact:true}).click();
 const search=hp.getByLabel("Rechercher une réunion",{exact:true});
 await search.fill("Replay browser room");
 await hp.getByRole("button",{name:/Replay browser room/}).click();
 await hp.getByRole("heading",{name:"Replay browser room",exact:true}).waitFor();
 await hp.getByText(/Bonjour réel/).waitFor();
 async function menuPage(label){
  await hp.getByRole("button",{name:"Options",exact:true}).click();
  await hp.getByRole("button",{name:label+" ›",exact:true}).click();
 }
 for(const label of ["Réunions simultanées","Votes et enquêtes","Statistiques"]){
  await menuPage(label);
  await hp.getByRole("heading",{name:label,exact:true}).first().waitFor();
  await hp.getByLabel("Rechercher une réunion",{exact:true}).fill("Replay browser room");
  await hp.getByRole("button",{name:/Replay browser room/}).waitFor();
 }
 await hp.getByRole("navigation").getByRole("button",{name:"Accueil",exact:true}).click();
 await hp.getByRole("button",{name:"Mes rapports",exact:true}).click();
 await hp.getByRole("heading",{name:"Archives et comptes rendus",exact:true}).waitFor();
 pass("real browser workspace chat, concurrent rooms, polls, visible statistics and reports routes backed by GoTrue and Edge");
 await hp.getByRole("navigation").getByRole("button",{name:"Chat",exact:true}).click();
 await hp.getByRole("button",{name:"Messages privés",exact:true}).click();
 await hp.getByLabel("Rechercher un contact",{exact:true}).fill("staff");await hp.getByRole("button",{name:"Rechercher",exact:true}).click();await hp.getByRole("button",{name:"Replay staff",exact:true}).click();
 await hp.getByText("Synthetic private workspace message",{exact:true}).waitFor();
 await hp.getByLabel("Votre message",{exact:true}).fill("Synthetic private browser message");
 await hp.getByRole("button",{name:"Envoyer",exact:true}).click();
 await hp.getByText("Synthetic private browser message",{exact:true}).waitFor();
 await gp.getByRole("navigation").getByRole("button",{name:"Chat",exact:true}).click();
 await gp.getByRole("button",{name:"Messages privés",exact:true}).click();
 await gp.getByRole("button",{name:/Replay promoteur/}).click();
 await gp.getByText("Synthetic private browser message",{exact:true}).waitFor();
 const directIncoming=gp.locator("article").filter({hasText:"Synthetic private browser message"});
 await directIncoming.getByRole("button",{name:"Marquer comme lu",exact:true}).click();
 await directIncoming.getByText(/Consultation déclarée/).waitFor();
 await hp.locator("article").filter({hasText:"Synthetic private browser message"}).getByText(/Consultation déclarée/).waitFor({timeout:15000});
 await menuPage("Statistiques");
 await hp.getByRole("heading",{name:"Bilan consolidé Premium",exact:true}).waitFor();
 const period=hp.getByRole("combobox",{name:"Période écoulée",exact:true});await period.selectOption("7");assert.equal(await period.inputValue(),"7");
 await hp.getByText("Toutes les réunions de votre entreprise",{exact:true}).waitFor();await hp.getByText("Votes clôturés explicitement",{exact:true}).waitFor();await hp.getByText("Tâches approuvées",{exact:true}).waitFor();
 pass("real two-browser direct chat, explicit read acknowledgement, automatic refresh and consolidated statistics period");

 await menuPage("Traduction et écoute");
 await hp.getByRole("combobox",{name:"Langue parlée préférée",exact:true}).selectOption("ff");
 await hp.getByLabel("Langue d’écoute préférée",{exact:true}).selectOption("en");
 await hp.getByLabel("Vitesse de lecture",{exact:true}).selectOption("1.25");
 await hp.getByRole("button",{name:"Enregistrer mes préférences",exact:true}).click();
 await hp.getByText("Préférences enregistrées.",{exact:true}).waitFor();
 await menuPage("Langue");
 await hp.getByLabel("Langue parlée préférée",{exact:true}).waitFor();
 assert.equal(await hp.getByLabel("Langue parlée préférée",{exact:true}).inputValue(),"ff");
 assert.equal(await hp.getByLabel("Vitesse de lecture",{exact:true}).inputValue(),"1.25");
 hp.once("dialog",d=>d.accept());await hp.getByRole("button",{name:"Réinitialiser",exact:true}).click();
 await hp.getByText("Préférences enregistrées.",{exact:true}).waitFor();
 assert.equal(await hp.getByLabel("Langue d’écoute préférée",{exact:true}).inputValue(),"original");
 pass("real browser language and listening preference pages persist and reset account settings");
 await menuPage("Livechat et support");
 await hp.getByLabel("Sujet",{exact:true}).fill("Replay support browser");
 await hp.getByLabel("Description du problème",{exact:true}).fill("Synthetic browser issue");
 await hp.getByRole("button",{name:"Envoyer la demande",exact:true}).click();
 await hp.getByRole("heading",{name:"Replay support browser",exact:true}).waitFor({timeout:20000});
 const browserSupportHost=await login(h);
 const browserSupportList=await sk(browserSupportHost.access_token,"list");
 const browserSupportTicket=browserSupportList.items.find(x=>x.subject==="Replay support browser");assert.ok(browserSupportTicket);
 const browserAgent=await login(sa);
 await sk(browserAgent.access_token,"claim",{ticket_id:browserSupportTicket.id});
 await sk(browserAgent.access_token,"reply",{ticket_id:browserSupportTicket.id,message_id:randomUUID(),body:"Synthetic agent browser answer"});
 await hp.getByText("Synthetic agent browser answer",{exact:true}).waitFor({timeout:20000});
 await hp.getByLabel("Votre message",{exact:true}).fill("Synthetic requester acknowledgement");
 await hp.getByRole("button",{name:"Envoyer",exact:true}).click();
 await hp.getByText("Synthetic requester acknowledgement",{exact:true}).waitFor();
 assert.equal((await sk(browserAgent.access_token,"read",{ticket_id:browserSupportTicket.id})).messages.length,3);
 hp.once("dialog",d=>d.accept());await hp.getByRole("button",{name:"Clôturer",exact:true}).click();
 await hp.getByText("Clôturée",{exact:true}).waitFor();
 pass("real browser support intake, agent claim/reply, automatic refresh, requester message and closure");

 // Exercise the external invitation deep link through real GoTrue, Edge and Chromium.
 const deepGuest=await fixture(other,"staff");
 const deepHost=await login(h),deepRoomId=randomUUID(),deepToken=randomBytes(32).toString("hex"),deepInviteId=randomUUID();
 const deepRoom=await ok(room+"/create",{room_id:deepRoomId,title:"Replay invitation link",description:"Isolated",scheduled_ms:Date.now(),duration_minutes:30,invitees:[]},deepHost.access_token);
 await ok(room+"/command",{room_id:deepRoomId,request_id:randomUUID(),expected_revision:deepRoom.revision,action:"lobby_config",value:true},deepHost.access_token);
 await ok(room+"/external-invite",{action:"issue",data:{room_id:deepRoomId,invite_id:deepInviteId,login_id:deepGuest.login,token:deepToken}},deepHost.access_token);
 const deepContext=await browser.newContext({ignoreHTTPSErrors:true,locale:"fr-FR"});
 try{
  const dp=await deepContext.newPage();
  let releaseList;const delayedList=new Promise(r=>{releaseList=r});let listArrived=false;
  await dp.route("**/widemeet-room/list",async route=>{if(!listArrived){listArrived=true;await delayedList}await route.continue()});
  await dp.goto("https://127.0.0.1:8443/#invite="+deepToken);
  await dp.getByLabel("Identifiant WideMeet",{exact:true}).fill(deepGuest.login);
  await dp.getByLabel("Mot de passe",{exact:true}).fill(deepGuest.password);
  await dp.getByRole("button",{name:"Se connecter",exact:true}).click();
  const field=dp.getByLabel("Code d’invitation",{exact:true});
  await field.waitFor({timeout:20000});
  assert.equal(await field.inputValue(),deepToken);
  assert.equal(await dp.evaluate(()=>location.hash),"");
  try{const until=Date.now()+10000;while(!listArrived&&Date.now()<until)await wait(50);assert.equal(listArrived,true);assert.equal(await dp.getByRole("button",{name:"Rejoindre",exact:true}).isDisabled(),true)}finally{releaseList()}
  const redeemed=dp.waitForResponse(r=>r.url().endsWith("/widemeet-room/external-invite")&&r.request().method()==="POST");
  await dp.getByRole("button",{name:"Rejoindre",exact:true}).click();
  assert.equal((await redeemed).status(),200);
  await dp.getByRole("heading",{name:"Replay invitation link",exact:true}).waitFor({timeout:20000});
  // A second link while already signed in must reopen the invitation entry, not silently redeem it.
  await dp.evaluate(t=>{location.hash="invite="+t},deepToken);
  await field.waitFor({timeout:20000});assert.equal(await field.inputValue(),deepToken);
  assert.equal(await dp.evaluate(()=>location.hash),"");
  pass("real external invitation URL: manual GoTrue sign-in, exact token, explicit redemption, room access and signed-in hash navigation");
 }finally{await deepContext.close()}


}finally{
 if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));
 for(const child of children)if(child.exitCode===null){child.kill("SIGTERM");await new Promise(r=>child.once("exit",r));}
 await unlink(roomCopy).catch(()=>{});
}
