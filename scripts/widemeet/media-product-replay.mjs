// Real WideMeet product authorization + real SFU in a disposable runner only.
import assert from "node:assert/strict";
import {randomUUID,randomBytes,createHash} from "node:crypto";
import {spawn} from "node:child_process";
import {createServer} from "node:http";
import {readFile,writeFile,unlink} from "node:fs/promises";
import {chromium} from "@playwright/test";
import {RoomServiceClient,EgressClient} from "livekit-server-sdk";
import {createWideMeetPresence} from "../../packages/media-core/widemeet-presence.mjs";
import {createWideMeetRecordingStorage} from "../../packages/media-core/widemeet-recording-storage.mjs";
import {createWideMeetRecorder} from "../../packages/media-core/widemeet-recorder.mjs";
import {execFileSync} from "node:child_process";
import {stat,mkdtemp,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join as joinPath} from "node:path";
import {createWideMeetTranscription} from "../../packages/media-core/widemeet-transcription.mjs";
import {createMediaProxy} from "../../packages/media-core/signaling-proxy.mjs";
import {connectUiOrigin,connectUiWss,startConnectUiReplay} from "./connect-ui-replay.mjs";
import {createWideMeetAdmission} from "../../packages/media-core/widemeet-admission.mjs";
const base=process.env.SUPABASE_URL,serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY,anon=process.env.SUPABASE_ANON_KEY;
const key=process.env.LK_TEST_KEY,secret=process.env.LK_TEST_SECRET;
assert.equal(base,"http://127.0.0.1:54321");assert.ok(serviceKey&&anon&&key&&secret);
const upstream="http://127.0.0.1:7880",origin="http://127.0.0.1:4173",auth="http://127.0.0.1:8000",roomApi="http://127.0.0.1:8001";
const sfu=new RoomServiceClient(upstream,key,secret),evicted=new Set();
const connectUi=process.env.WM_CONNECT_QUALIFIED==="true";
if(connectUi){process.env.WM_LIVEKIT_URL=connectUiWss;process.env.WM_ALLOWED_ORIGINS=[process.env.WM_ALLOWED_ORIGINS,connectUiOrigin].filter(Boolean).join(",")}
const readAdmission=createWideMeetAdmission({supabaseUrl:base,serviceKey,sourceActive:async (room,identity,hash)=>proxy.sourceActive(room,identity,hash)&&(await sfu.listParticipants(room)).some(p=>p.identity===identity&&p.state===2)});
const proxy=createMediaProxy({upstream,key,secret,allowedOrigins:new Set([origin,...(connectUi?[connectUiOrigin]:[])]),readAdmission,onAdmit:async g=>{await sfu.createRoom({name:g.room,emptyTimeout:300,maxParticipants:20})},onRevoke:async g=>{await sfu.removeParticipant(g.room,g.identity);evicted.add(g.identity)},checkEveryMs:500});
const bundle=await readFile("node_modules/livekit-client/dist/livekit-client.umd.js");
const app=createServer((req,res)=>{if(req.url==="/sdk.js"){res.writeHead(200,{"Content-Type":"application/javascript"});res.end(bundle)}else{res.writeHead(200,{"Content-Type":"text/html"});res.end('<!doctype html><title>WideMeet media replay</title><script src="/sdk.js"></script><body></body>')}});
const listen=(s,p)=>new Promise((resolve,reject)=>{s.once("error",reject);s.listen(p,"127.0.0.1",resolve)});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,label,ms=25000){const end=Date.now()+ms;while(Date.now()<end){if(await fn())return;await delay(250)}throw Error("timeout: "+label)}
const children=[],roomCopy="supabase/functions/widemeet-room/replay-media-local.ts";
let browser,rid;
async function json(url,body,token=serviceKey,apikey=serviceKey){
 const r=await fetch(url,{method:"POST",headers:{apikey,Authorization:"Bearer "+token,"Content-Type":"application/json",Prefer:"return=representation"},body:JSON.stringify(body)});
 return {status:r.status,data:await r.json().catch(()=>null)};
}
async function ok(url,body,token=serviceKey,apikey=serviceKey){
 const r=await json(url,body,token,apikey);assert.ok(r.status>=200&&r.status<300,"HTTP "+r.status+" "+new URL(url).pathname+" "+String(r.data?.error??""));return r.data;
}
const rest=(table,body)=>ok(base+"/rest/v1/"+table,body);
const request=(url,body,token=anon)=>json(url,{...body,app_id:"WIDEMEET"},token,anon);
const good=(url,body,token=anon)=>ok(url,{...body,app_id:"WIDEMEET"},token,anon);
async function fixture(w,role){
 const email="wm-media-"+randomUUID()+"@example.test",password="Qa7!"+randomBytes(18).toString("hex"),login="WM-"+randomBytes(8).toString("hex").toUpperCase();
 const user=await ok(base+"/auth/v1/admin/users",{email,password,email_confirm:true,app_metadata:{app_code:"widemeet"}});
 const [a]=await rest("wm_accounts",{auth_user_id:user.id,login_id:login,auth_alias:email,display_name:"Media "+role});
 await rest("wm_memberships",{account_id:a.id,workspace_id:w,role});
 return {id:a.id,login,password};
}
async function launch(file,port){
 const child=spawn("deno",["run","--allow-env","--allow-net=127.0.0.1:54321,0.0.0.0:"+port+",127.0.0.1:"+port,file],{stdio:["ignore","ignore","inherit"]});children.push(child);
 await until(async()=>{try{return (await fetch("http://127.0.0.1:"+port,{method:"OPTIONS"})).ok}catch{return false}},"gateway "+port,15000);
}
async function login(f){return good(auth+"/login",{identifier:f.login,password:f.password,installation_id:randomUUID(),platform:"web"})}
try{
 const [w]=await rest("wm_workspaces",{kind:"enterprise",name:"Media replay"});
 await rest("wm_room_entitlements",{workspace_id:w.id,plan:"premium",valid_until:new Date(Date.now()+7200000).toISOString(),enabled:true});
 const external=process.env.WM_EXTERNAL_GUESTS_QUALIFIED==="true";
 const guestWorkspace=external?(await rest("wm_workspaces",{kind:"enterprise",name:"External media guest fixture"}))[0]:w;
 const h=await fixture(w.id,"promoteur"),g=await fixture(guestWorkspace.id,"staff");
 const code=await readFile("supabase/functions/widemeet-room/index.ts","utf8");
 const anchor="Deno.serve(async request=>{";assert.equal(code.split(anchor).length,2);
 await writeFile(roomCopy,code.replace(anchor,"Deno.serve({port:8001},async request=>{"));
 await launch("supabase/functions/widemeet-auth/index.ts",8000);await launch(roomCopy,8001);
 const hs=await login(h),gs=await login(g);
 rid=randomUUID();
 let state=await good(roomApi+"/create",{room_id:rid,title:"Media integration",description:"Isolated",scheduled_ms:Date.now(),duration_minutes:30,invitees:external?[]:[g.id]},hs.access_token);
 async function cmd(token,action,value=null,target=null){state=await good(roomApi+"/command",{room_id:rid,request_id:randomUUID(),expected_revision:state.revision,action,value,target},token);return state;}
 let inviteId;
 if(external){
  await cmd(hs.access_token,"lobby_config",true);
  inviteId=randomUUID();const token=randomBytes(32).toString("hex");
  await good(roomApi+"/external-invite",{action:"issue",data:{room_id:rid,invite_id:inviteId,login_id:g.login,token}},hs.access_token);
  assert.equal((await good(roomApi+"/external-invite",{action:"redeem",data:{token}},gs.access_token)).room_id,rid);
  state=await good(roomApi+"/read",{room_id:rid},hs.access_token);
  assert.equal((await request(roomApi+"/media-grant",{room_id:rid},gs.access_token)).status,403);
  await cmd(hs.access_token,"start");await cmd(gs.access_token,"lobby_request");
  assert.equal((await request(roomApi+"/media-grant",{room_id:rid},gs.access_token)).status,403);
  await cmd(hs.access_token,"lobby_admit",null,g.id);
 }else{assert.equal((await request(roomApi+"/media-grant",{room_id:rid},gs.access_token)).status,403);await cmd(gs.access_token,"respond","accepted");await cmd(hs.access_token,"start");}
 const hg=await good(roomApi+"/media-grant",{room_id:rid},hs.access_token),gg=await good(roomApi+"/media-grant",{room_id:rid},gs.access_token);
 assert.equal(hg.url,connectUi?connectUiWss:"wss://127.0.0.1:7881");assert.equal(gg.url,hg.url);
 // Test private signaling on loopback only; TLS/public routing separately qualified.
 await listen(proxy.server,7881);await listen(app,4173);
 browser=await chromium.launch({headless:true,args:["--use-fake-device-for-media-stream","--use-fake-ui-for-media-stream","--autoplay-policy=no-user-gesture-required"]});
 const ctx=await browser.newContext({permissions:["camera","microphone"]}),a=await ctx.newPage(),b=await ctx.newPage();
 async function joinMedia(page,t){await page.goto(origin);await page.evaluate(async token=>{
 const lk=window.LivekitClient,r=new lk.Room({adaptiveStream:false,dynacast:false});window.r=r;window.received=[];
 r.on(lk.RoomEvent.TrackSubscribed,track=>{window.received.push(track);const el=track.attach();el.autoplay=true;document.body.appendChild(el)});
 await r.connect("ws://127.0.0.1:7881",token);await r.localParticipant.setMicrophoneEnabled(true);await r.localParticipant.setCameraEnabled(true);
 },t)}
 await joinMedia(a,hg.token);await joinMedia(b,gg.token);
 const inbound=page=>page.evaluate(async()=>{const seen={audio:false,video:false};for(const t of window.received){const s=await t.getRTCStatsReport();if(!s)continue;for(const x of s.values())if(x.type==="inbound-rtp"&&x.bytesReceived>0){if(t.kind==="audio")seen.audio=true;if(t.kind==="video"&&(x.framesDecoded??0)>0)seen.video=true}}return seen.audio&&seen.video});
 await until(async()=>await inbound(a)&&await inbound(b),"real WideMeet bidirectional RTP");
 console.log("PASS actual WideMeet opaque sessions, Edge-issued media grants, PostgreSQL admission and bidirectional SFU RTP");
 if(process.env.WM_CONNECT_QUALIFIED==="true"){
  const receiverSession=await login(h),code=randomBytes(32).toString("hex"),connect=(token,action,data)=>good(roomApi+"/connect",{action,data},token),deny=(token,action,data)=>request(roomApi+"/connect",{action,data},token);
  const room_id=rid,name="B2 replay display";
  await connect(receiverSession.access_token,"offer",{code,name});
  assert.equal((await connect(receiverSession.access_token,"receive",{code})).pending,true);
  assert.equal((await deny(hs.access_token,"preview",{room_id,code})).status,403);
  await connect(hs.access_token,"policy",{room_id,enabled:true});
  assert.equal((await deny(gs.access_token,"preview",{room_id,code})).status,403);
  assert.equal((await connect(hs.access_token,"preview",{room_id,code})).receiver_name,name);
  assert.equal((await deny(hs.access_token,"confirm",{room_id,code,receiver_name:"wrong"})).status,403);
  await connect(hs.access_token,"confirm",{room_id,code,receiver_name:name});
  assert.equal((await deny(hs.access_token,"confirm",{room_id,code,receiver_name:name})).status,403);
  assert.equal((await deny(gs.access_token,"receive",{code})).status,403);
  const display=await connect(receiverSession.access_token,"receive",{code});
  assert.ok(display.identity.startsWith("wm-display-"));assert.equal(display.source_hash,undefined);assert.equal(display.ctx,undefined);
  const screen=await ctx.newPage();await screen.goto(origin);
  await screen.evaluate(async token=>{const lk=window.LivekitClient,r=new lk.Room({adaptiveStream:false,dynacast:false});window.r=r;window.received=[];r.on(lk.RoomEvent.TrackSubscribed,t=>{window.received.push(t);const el=t.attach();el.autoplay=true;el.muted=true;document.body.appendChild(el)});await r.connect("ws://127.0.0.1:7881",token)},display.token);
  await until(()=>inbound(screen),"B2 product receiver inbound RTP");
  const info=(await sfu.listParticipants("wm-"+rid)).find(p=>p.identity===display.identity);assert.ok(info);assert.equal(info.permission.canPublish,false);assert.equal(info.tracks.length,0);
  const renewed=await connect(receiverSession.access_token,"receive",{code});assert.equal(renewed.identity,display.identity);
  await connect(hs.access_token,"source-stop",{room_id});
  await until(async()=>evicted.has(display.identity)&&!(await sfu.listParticipants("wm-"+rid)).some(p=>p.identity===display.identity),"B2 product receiver removed");
  assert.equal((await deny(receiverSession.access_token,"receive",{code})).status,403);
  assert.ok((await sfu.listParticipants("wm-"+rid)).some(p=>p.identity===h.id));
  await screen.close();
  // Actual second pairing, followed by host policy revocation. No duplicate publishing participant.
  const nextCode=randomBytes(32).toString("hex");
  await connect(receiverSession.access_token,"offer",{code:nextCode,name});
  await connect(hs.access_token,"confirm",{room_id,code:nextCode,receiver_name:name});
  const second=await connect(receiverSession.access_token,"receive",{code:nextCode});
  const secondScreen=await ctx.newPage();await secondScreen.goto(origin);
  await secondScreen.evaluate(async token=>{const lk=window.LivekitClient,r=new lk.Room({adaptiveStream:false,dynacast:false});window.r=r;window.received=[];r.on(lk.RoomEvent.TrackSubscribed,t=>{window.received.push(t);const el=t.attach();el.autoplay=true;el.muted=true;document.body.appendChild(el)});await r.connect("ws://127.0.0.1:7881",token)},second.token);
  await until(()=>inbound(secondScreen),"B2 second pairing inbound RTP");
  await connect(hs.access_token,"policy",{room_id,enabled:false});
  await until(async()=>evicted.has(second.identity)&&!(await sfu.listParticipants("wm-"+rid)).some(p=>p.identity===second.identity),"B2 policy revoked display");
  await connect(hs.access_token,"policy",{room_id,enabled:true});
  assert.equal((await deny(receiverSession.access_token,"receive",{code:nextCode})).status,403);
  await secondScreen.close();
  console.log("PASS B2 Connect re-pair, actual host policy evicts receiver and policy re-enable never resurrects lease");
  console.log("PASS B2 product Connect: same-account separate device offer, host policy, confirmation, RTP, renewal and revocation");
  await startConnectUiReplay({browser,sourceSession:hs,receiverSession,roomId:rid,roomApi,evicted,sfu,proxyServer:proxy.server});
 }
 if(external)console.log("PASS real cross-workspace named guest with no subscription, explicit lobby admission and bidirectional media");
 let finishAtEnd=null;
 const presence=createWideMeetPresence({supabaseUrl:base,serviceKey,sfu});
 if(process.env.WM_PRESENCE_QUALIFIED==="true"){assert.equal((await presence.observe(rid)).persisted,true);await delay(1100);assert.equal((await presence.observe(rid)).persisted,true);}
 if(process.env.WM_RECORDING_QUALIFIED==="true"){
 const enableStorage=process.env.WM_RECORDING_STORAGE_QUALIFIED==="true";
 if(enableStorage)await ok(base+"/storage/v1/bucket",{id:"wm-recordings",name:"wm-recordings",public:false,file_size_limit:134217728,allowed_mime_types:["audio/ogg"]});
 const storage=enableStorage?createWideMeetRecordingStorage({supabaseUrl:base,serviceKey}):null;
 const recorder=createWideMeetRecorder({supabaseUrl:base,serviceKey,storage,egress:new EgressClient(upstream,key,secret),outputDirectory:process.env.WM_EGRESS_OUT,verifyAudio:async file=>{
 const p=JSON.parse(execFileSync("ffprobe",["-v","error","-show_streams","-show_format","-of","json",file],{encoding:"utf8"}));
 assert.ok(p.streams.some(x=>x.codec_type==="audio")&&p.streams.every(x=>x.codec_type!=="video")&&Number(p.format.duration)>1);
 execFileSync("ffmpeg",["-v","error","-xerror","-i",file,"-map","0:a:0","-f","null","-"]);
 }});
 const getRuns=async()=>{const res=await fetch(base+"/rest/v1/wm_recording_runs?room_id=eq."+rid+"&order=created_at.desc",{headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey}});assert.ok(res.ok);return res.json()};
 const phase=async expected=>{await recorder.reconcile(rid);return (await getRuns())[0]?.phase===expected};
 await cmd(hs.access_token,"consent",true);
 const denied=await request(roomApi+"/command",{room_id:rid,request_id:randomUUID(),expected_revision:state.revision,action:"record",value:true},hs.access_token);assert.equal(denied.status,409);
 await recorder.reconcile(rid);assert.equal((await getRuns()).length,0);
 await cmd(gs.access_token,"consent",true);await cmd(hs.access_token,"record",true);
 await until(()=>phase("active"),"consented actual Egress active",90000);
 const statusActive=await good(roomApi+"/read",{room_id:rid},gs.access_token);assert.equal(statusActive.recordingStatus.phase,"active");assert.equal(statusActive.recordingStatus.provider_id,undefined);
 await delay(2500);
 const first=(await getRuns())[0];assert.ok(first.provider_id);
 await cmd(gs.access_token,"consent",false);
 assert.equal((await getRuns())[0].phase,"stopping");
 assert.equal((await good(roomApi+"/read",{room_id:rid},hs.access_token)).recordingStatus.phase,"stopping");
 await until(()=>phase("discarded"),"withdrawal Egress stop and quarantine removal",90000);
 assert.equal(await stat(process.env.WM_EGRESS_OUT+"/"+first.object_name).then(()=>true,()=>false),false);
 console.log("PASS actual participant consent withdrawal fences recording, stops Egress and discards private segment");
 await cmd(gs.access_token,"consent",true);await cmd(hs.access_token,"record",true);
 await until(()=>phase("active"),"second recording active",90000);await delay(3000);
 await cmd(hs.access_token,"record_pause");assert.equal(state.status,"open");assert.equal(state.recordingPaused,true);
 await cmd(gs.access_token,"chat","Meeting continues during recording pause");
 await until(()=>phase("complete"),"verified independent recording pause",90000);
 assert.ok(await inbound(a)&&await inbound(b));
 console.log("PASS actual independent recording pause preserves verified segment while meeting audio/video remains connected");
 await cmd(hs.access_token,"record",true);await until(()=>phase("active"),"resumed recording active",90000);await delay(3000);
 await cmd(hs.access_token,"record",false);
 await until(()=>phase("complete"),"verified normal recording completion",90000);
 assert.equal((await good(roomApi+"/read",{room_id:rid},hs.access_token)).recordingStatus.phase,"complete");
 const final=(await getRuns())[0];assert.match(final.content_sha256,/^[a-f0-9]{64}$/);assert.ok(final.bytes>1000);
 const st=await stat(process.env.WM_EGRESS_OUT+"/"+final.object_name);assert.equal(st.mode&0o777,0o600);
 console.log("PASS actual consent-driven recording normal stop, private audio-only verified file and SHA-256 ledger");
 finishAtEnd=async()=>{await cmd(hs.access_token,"record",true);await until(()=>phase("active"),"recording active before host end",90000);await delay(3000);await cmd(hs.access_token,"end");await until(()=>phase("complete"),"host-end recording finalization",90000);console.log("PASS actual host ends room with recording active; valid audio retained rather than discarded")};
 if(enableStorage){assert.equal(final.storage_key,rid+"/"+final.id+".ogg");assert.ok(final.stored_at);const unauth=await fetch(base+"/storage/v1/object/public/wm-recordings/"+final.storage_key);assert.ok(!unauth.ok);assert.equal((await request(roomApi+"/recordings",{room_id:rid},hs.access_token)).status,403);}
 }
 const freshGuest=await good(roomApi+"/media-grant",{room_id:rid},gs.access_token);
 if(external){await good(roomApi+"/external-invite",{action:"revoke",data:{room_id:rid,invite_id:inviteId}},hs.access_token);state=await good(roomApi+"/read",{room_id:rid},hs.access_token)}else await cmd(hs.access_token,"exclude",null,g.id);
 await until(async()=>evicted.has(g.id)&&!(await sfu.listParticipants("wm-"+rid)).some(p=>p.identity===g.id),"database-driven SFU eviction");
 assert.ok([403,404].includes((await request(roomApi+"/media-grant",{room_id:rid},gs.access_token)).status));
 assert.ok(freshGuest.expires_at>Date.now(),"revocation test must precede expiry");
 const fresh=await ctx.newPage();await fresh.goto(origin);
 const denied=await fresh.evaluate(async token=>{const r=new window.LivekitClient.Room();try{await r.connect("ws://127.0.0.1:7881",token);await r.disconnect();return false}catch{return true}},freshGuest.token);
 assert.equal(denied,true);
 console.log("PASS actual WideMeet moderation mutation evicts guest from SFU and rejects old unexpired grant");
 if(process.env.WM_PRESENCE_QUALIFIED==="true"){await delay(1100);assert.equal((await presence.observe(rid)).observed,1);await delay(1100);assert.equal((await presence.observe(rid)).persisted,true);}
 if(finishAtEnd)await finishAtEnd();else await cmd(hs.access_token,"end");
 await until(async()=>evicted.has(h.id),"room closure eviction");
 console.log("PASS room closure revokes host transport");
 if(process.env.WM_RECORDING_STORAGE_QUALIFIED==="true"){const archive=await good(roomApi+"/recordings",{room_id:rid},hs.access_token);assert.equal(archive.items.length,3);assert.equal((await request(roomApi+"/recordings",{room_id:rid},gs.access_token)).status,403);const file=archive.items.at(-1),body={app_id:"WIDEMEET",room_id:rid,recording_id:file.recording_id,request_id:randomUUID()};const download=async token=>fetch(roomApi+"/recording-download",{method:"POST",headers:{apikey:anon,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify(body)});assert.equal((await download(gs.access_token)).status,403);const res=await download(hs.access_token);assert.equal(res.status,200);const data=Buffer.from(await res.arrayBuffer());assert.equal(data.length,file.bytes);assert.equal(createHash("sha256").update(data).digest("hex"),file.sha256);console.log("PASS actual N3 private Storage upload/readback, host-only export after closure, forbidden guest and SHA-256 integrity");}
 if(process.env.WM_TRANSCRIPTION_QUALIFIED==="true"){
 const temp=await mkdtemp(joinPath(tmpdir(),"wm-asr-replay-"));
 try{
  const wav=joinPath(temp,"synthetic.wav"),ogg=joinPath(temp,"synthetic.ogg");
  execFileSync("espeak-ng",["-v","en-us","-s","125","-w",wav,"Today we discuss the project. The meeting is about the project. Thank you for attending the meeting."]);
  execFileSync("ffmpeg",["-v","error","-y","-i",wav,"-c:a","libopus",ogg]);
  const bytes=await readFile(ogg),sha=createHash("sha256").update(bytes).digest("hex"),id=randomUUID();
  const storage=createWideMeetRecordingStorage({supabaseUrl:base,serviceKey});const key=await storage.put({id,room_id:rid},bytes,sha);
  await rest("wm_recording_runs",{id,room_id:rid,request_id:randomUUID(),phase:"complete",disposition:"retain",object_name:id+".ogg",started_at:new Date(Date.now()-10000).toISOString(),finished_at:new Date().toISOString(),content_sha256:sha,bytes:bytes.length,stored_at:new Date().toISOString(),storage_key:key});
  const tr=(token,action,data)=>request(roomApi+"/transcription",{action,data},token),tk=(token,action,data)=>good(roomApi+"/transcription",{action,data},token),data={room_id:rid,recording_id:id};
  assert.equal((await tr(gs.access_token,"request",data)).status,403);
  assert.equal((await tk(hs.access_token,"request",data)).status,"queued");assert.equal((await tk(hs.access_token,"request",data)).status,"queued");
  const engine=createWideMeetTranscription({supabaseUrl:base,serviceKey,python:process.env.WM_ASR_PYTHON,modelDir:process.env.WM_ASR_MODEL});
  assert.deepEqual(await engine.runOne(),{claimed:true,completed:true});
  const result=await tk(hs.access_token,"read",data);assert.equal(result.status,"complete");assert.equal(result.result.language,"en");assert.ok(result.result.segments.length>0);assert.match(result.result.segments.map(x=>x.text).join(" "),/project|meeting/i);
  assert.equal((await tr(gs.access_token,"read",data)).status,403);assert.deepEqual(await engine.runOne(),{claimed:false});
  console.log("PASS actual local Whisper ASR on separate synthetic speech fixture in private Storage; host-only queue, hash verification and timestamped output");
 }finally{await rm(temp,{recursive:true,force:true})}
 }
 if(process.env.WM_PRESENCE_QUALIFIED==="true"){const report=await good(roomApi+"/presence",{room_id:rid},hs.access_token);assert.equal(report.basis,"sfu_samples_not_continuous_presence");assert.ok(report.samples>=4&&report.coverage_ms>0);const hr=report.rows.find(x=>x.member_id===h.id),gr=report.rows.find(x=>x.member_id===g.id);assert.ok(hr.samples_seen>=4&&gr.samples_seen===2&&gr.estimated_ms>0&&hr.estimated_ms>=gr.estimated_ms);assert.equal((await request(roomApi+"/presence",{room_id:rid},gs.access_token)).status,403);console.log("PASS actual N4 SFU active transport samples, exclusion and restricted closed meeting report");}
}finally{
 if(browser)await browser.close();if(rid)await sfu.deleteRoom("wm-"+rid).catch(()=>{});
 await Promise.all([app,proxy.server].map(s=>new Promise(r=>s.close(r))));
 for(const child of children)if(child.exitCode===null){child.kill("SIGTERM");await new Promise(r=>child.once("exit",r))}
 await unlink(roomCopy).catch(()=>{});
}
