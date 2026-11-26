// Real WideMeet product authorization + real SFU in a disposable runner only.
import assert from "node:assert/strict";
import {randomUUID,randomBytes} from "node:crypto";
import {spawn} from "node:child_process";
import {createServer} from "node:http";
import {readFile,writeFile,unlink} from "node:fs/promises";
import {chromium} from "@playwright/test";
import {RoomServiceClient} from "livekit-server-sdk";
import {createMediaProxy} from "../../packages/media-core/signaling-proxy.mjs";
import {createWideMeetAdmission} from "../../packages/media-core/widemeet-admission.mjs";
const base=process.env.SUPABASE_URL,serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY,anon=process.env.SUPABASE_ANON_KEY;
const key=process.env.LK_TEST_KEY,secret=process.env.LK_TEST_SECRET;
assert.equal(base,"http://127.0.0.1:54321");assert.ok(serviceKey&&anon&&key&&secret);
const upstream="http://127.0.0.1:7880",origin="http://127.0.0.1:4173",auth="http://127.0.0.1:8000",roomApi="http://127.0.0.1:8001";
const sfu=new RoomServiceClient(upstream,key,secret),evicted=new Set();
const readAdmission=createWideMeetAdmission({supabaseUrl:base,serviceKey});
const proxy=createMediaProxy({upstream,key,secret,allowedOrigins:new Set([origin]),readAdmission,onAdmit:async g=>{await sfu.createRoom({name:g.room,emptyTimeout:300,maxParticipants:20})},onRevoke:async g=>{await sfu.removeParticipant(g.room,g.identity);evicted.add(g.identity)},checkEveryMs:500});
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
 const h=await fixture(w.id,"promoteur"),g=await fixture(w.id,"staff");
 const code=await readFile("supabase/functions/widemeet-room/index.ts","utf8");
 const anchor="Deno.serve(async request=>{";assert.equal(code.split(anchor).length,2);
 await writeFile(roomCopy,code.replace(anchor,"Deno.serve({port:8001},async request=>{"));
 await launch("supabase/functions/widemeet-auth/index.ts",8000);await launch(roomCopy,8001);
 const hs=await login(h),gs=await login(g);
 rid=randomUUID();
 let state=await good(roomApi+"/create",{room_id:rid,title:"Media integration",description:"Isolated",scheduled_ms:Date.now(),duration_minutes:30,invitees:[g.id]},hs.access_token);
 async function cmd(token,action,value=null,target=null){state=await good(roomApi+"/command",{room_id:rid,request_id:randomUUID(),expected_revision:state.revision,action,value,target},token);return state;}
 assert.equal((await request(roomApi+"/media-grant",{room_id:rid},gs.access_token)).status,403);
 await cmd(gs.access_token,"respond","accepted");await cmd(hs.access_token,"start");
 const hg=await good(roomApi+"/media-grant",{room_id:rid},hs.access_token),gg=await good(roomApi+"/media-grant",{room_id:rid},gs.access_token);
 assert.equal(hg.url,"wss://127.0.0.1:7881");assert.equal(gg.url,hg.url);
 // Test private signaling on loopback only; TLS/public routing separately qualified.
 await listen(proxy.server,7881);await listen(app,4173);
 browser=await chromium.launch({headless:true,args:["--use-fake-device-for-media-stream","--use-fake-ui-for-media-stream","--autoplay-policy=no-user-gesture-required"]});
 const ctx=await browser.newContext({permissions:["camera","microphone"]}),a=await ctx.newPage(),b=await ctx.newPage();
 async function join(page,t){await page.goto(origin);await page.evaluate(async token=>{
 const lk=window.LivekitClient,r=new lk.Room({adaptiveStream:false,dynacast:false});window.r=r;window.received=[];
 r.on(lk.RoomEvent.TrackSubscribed,track=>{window.received.push(track);const el=track.attach();el.autoplay=true;document.body.appendChild(el)});
 await r.connect("ws://127.0.0.1:7881",token);await r.localParticipant.setMicrophoneEnabled(true);await r.localParticipant.setCameraEnabled(true);
 },t)}
 await join(a,hg.token);await join(b,gg.token);
 const inbound=page=>page.evaluate(async()=>{const seen={audio:false,video:false};for(const t of window.received){const s=await t.getRTCStatsReport();if(!s)continue;for(const x of s.values())if(x.type==="inbound-rtp"&&x.bytesReceived>0){if(t.kind==="audio")seen.audio=true;if(t.kind==="video"&&(x.framesDecoded??0)>0)seen.video=true}}return seen.audio&&seen.video});
 await until(async()=>await inbound(a)&&await inbound(b),"real WideMeet bidirectional RTP");
 console.log("PASS actual WideMeet opaque sessions, Edge-issued media grants, PostgreSQL admission and bidirectional SFU RTP");
 await cmd(hs.access_token,"exclude",null,g.id);
 await until(async()=>evicted.has(g.id)&&!(await sfu.listParticipants("wm-"+rid)).some(p=>p.identity===g.id),"database-driven SFU eviction");
 assert.equal((await request(roomApi+"/media-grant",{room_id:rid},gs.access_token)).status,404);
 assert.ok(gg.expires_at>Date.now(),"revocation test must precede expiry");
 const fresh=await ctx.newPage();await fresh.goto(origin);
 const denied=await fresh.evaluate(async token=>{const r=new window.LivekitClient.Room();try{await r.connect("ws://127.0.0.1:7881",token);await r.disconnect();return false}catch{return true}},gg.token);
 assert.equal(denied,true);
 console.log("PASS actual WideMeet moderation mutation evicts guest from SFU and rejects old unexpired grant");
 await cmd(hs.access_token,"end");
 await until(async()=>evicted.has(h.id),"room closure eviction");
 console.log("PASS room closure revokes host transport");
}finally{
 if(browser)await browser.close();if(rid)await sfu.deleteRoom("wm-"+rid).catch(()=>{});
 await Promise.all([app,proxy.server].map(s=>new Promise(r=>s.close(r))));
 for(const child of children)if(child.exitCode===null){child.kill("SIGTERM");await new Promise(r=>child.once("exit",r))}
 await unlink(roomCopy).catch(()=>{});
}
