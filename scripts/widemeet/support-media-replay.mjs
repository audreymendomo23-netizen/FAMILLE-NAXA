import {createWideMeetSupportAdmission} from "../../packages/media-core/widemeet-support-admission.mjs";
// Real WideMeet product authorization + real SFU in a disposable runner only.
import assert from "node:assert/strict";
import {randomUUID,randomBytes,createHash} from "node:crypto";
import {spawn} from "node:child_process";
import {createServer} from "node:http";
import {readFile,writeFile,unlink} from "node:fs/promises";
import {chromium} from "@playwright/test";
import {RoomServiceClient} from "livekit-server-sdk";
import {execFileSync} from "node:child_process";
import {stat,mkdtemp,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join as joinPath} from "node:path";
import {createMediaProxy} from "../../packages/media-core/signaling-proxy.mjs";
const base=process.env.SUPABASE_URL,serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY,anon=process.env.SUPABASE_ANON_KEY;
const key=process.env.LK_TEST_KEY,secret=process.env.LK_TEST_SECRET;
assert.equal(base,"http://127.0.0.1:54321");assert.ok(serviceKey&&anon&&key&&secret);
const upstream="http://127.0.0.1:7880",origin="http://127.0.0.1:4173",auth="http://127.0.0.1:8000",roomApi="http://127.0.0.1:8001";
const sfu=new RoomServiceClient(upstream,key,secret),evicted=new Set();
const readAdmission=createWideMeetSupportAdmission({supabaseUrl:base,serviceKey});
const proxy=createMediaProxy({upstream,key,secret,allowedOrigins:new Set([origin]),readAdmission,onAdmit:async g=>{await sfu.createRoom({name:g.room,emptyTimeout:300,maxParticipants:2})},onRevoke:async g=>{await sfu.removeParticipant(g.room,g.identity);evicted.add(g.identity)},checkEveryMs:500});
const bundle=await readFile("node_modules/livekit-client/dist/livekit-client.umd.js");
const app=createServer((req,res)=>{if(req.url==="/sdk.js"){res.writeHead(200,{"Content-Type":"application/javascript"});res.end(bundle)}else{res.writeHead(200,{"Content-Type":"text/html"});res.end('<!doctype html><title>WideMeet media replay</title><script src="/sdk.js"></script><body></body>')}});
const listen=(s,p)=>new Promise((resolve,reject)=>{s.once("error",reject);s.listen(p,"127.0.0.1",resolve)});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,label,ms=25000){const end=Date.now()+ms;while(Date.now()<end){if(await fn())return;await delay(250)}throw Error("timeout: "+label)}
const children=[];
let browser,callId;
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
 const [w]=await rest("wm_workspaces",{kind:"enterprise",name:"Support media requester fixture"});
 const [other]=await rest("wm_workspaces",{kind:"enterprise",name:"Support agent fixture"});
 const h=await fixture(w.id,"promoteur"),g=await fixture(other.id,"staff"),x=await fixture(other.id,"staff");
 await rest("wm_support_agents",{account_id:g.id,enabled:true});
 await launch("supabase/functions/widemeet-auth/index.ts",8000);
 const hs=await login(h),gs=await login(g),xs=await login(x);
 const ticket_id=randomUUID();callId=randomUUID();
 const s=(token,action,data={})=>good(auth+"/identity",{action:"support-"+action,data:{ticket_id,call_id:callId,...data}},token);
 const fail=(token,action,data={})=>request(auth+"/identity",{action:"support-"+action,data:{ticket_id,call_id:callId,...data}},token);
 await s(hs.access_token,"create",{message_id:randomUUID(),subject:"Synthetic support media",category:"other",body:"Synthetic audio fixture"});
 await s(gs.access_token,"claim");
 assert.equal((await fail(hs.access_token,"call-grant")).status,403);
 await s(hs.access_token,"call-request");assert.equal((await fail(xs.access_token,"call-accept")).status,403);
 await s(gs.access_token,"call-accept");assert.equal((await fail(xs.access_token,"call-grant")).status,403);
 const decode=t=>JSON.parse(Buffer.from(t.split(".")[1],"base64url"));
 const hg=await s(hs.access_token,"call-grant"),gg=await s(gs.access_token,"call-grant");
 assert.deepEqual(decode(hg.token).video.canPublishSources,["microphone"]);assert.deepEqual(decode(gg.token).video.canPublishSources,["microphone"]);
 assert.equal(decode(hg.token).video.room,"wm-support-"+callId);
 await listen(proxy.server,7881);await listen(app,4173);
 browser=await chromium.launch({headless:true,args:["--use-fake-device-for-media-stream","--use-fake-ui-for-media-stream","--autoplay-policy=no-user-gesture-required"]});
 const ctx=await browser.newContext({permissions:["microphone"]}),a=await ctx.newPage(),b=await ctx.newPage();
 async function joinMedia(page,token,share=false){await page.goto(origin);await page.evaluate(async ({token,share})=>{
  const lk=window.LivekitClient,r=new lk.Room({adaptiveStream:false,dynacast:false});window.r=r;window.received=[];
  r.on(lk.RoomEvent.TrackSubscribed,t=>{window.received.push(t);const el=t.attach();el.autoplay=true;document.body.appendChild(el)});
  await r.connect("ws://127.0.0.1:7881",token);await r.localParticipant.setMicrophoneEnabled(true);
  if(share){const canvas=document.createElement("canvas");canvas.width=640;canvas.height=360;const c=canvas.getContext("2d");let i=0;window.draw=setInterval(()=>{c.fillStyle=i++%2?"#003344":"#ffffff";c.fillRect(0,0,640,360);c.fillStyle="#ff9900";c.fillText("Synthetic support screen "+i,40,50)},100);const stream=canvas.captureStream(10);await r.localParticipant.publishTrack(stream.getVideoTracks()[0],{source:lk.Track.Source.ScreenShare})}
 },{token,share})}
 async function seen(page,kind){return page.evaluate(async kind=>{for(const t of window.received){if(t.kind!==kind)continue;const stats=await t.getRTCStatsReport();if(stats)for(const x of stats.values())if(x.type==="inbound-rtp"&&x.bytesReceived>0&&(kind!=="video"||(x.framesDecoded??0)>0))return true}return false},kind)}
 await joinMedia(a,hg.token);await joinMedia(b,gg.token);await until(async()=>await seen(a,"audio")&&await seen(b,"audio"),"bidirectional assistance audio",12000);
 console.log("PASS B5 real isolated support bidirectional audio RTP");
 await s(hs.access_token,"call-heartbeat");await s(gs.access_token,"call-heartbeat");
 const share_id=randomUUID();assert.equal((await fail(gs.access_token,"screen-consent",{share_id})).status,403);
 await s(hs.access_token,"screen-consent",{share_id});
 const sg=await s(hs.access_token,"call-grant");assert.deepEqual(decode(sg.token).video.canPublishSources,["microphone","screen_share"]);
 assert.deepEqual(decode((await s(gs.access_token,"call-grant")).token).video.canPublishSources,["microphone"]);
 await a.evaluate(()=>window.r.disconnect());await joinMedia(a,sg.token,true);await s(hs.access_token,"screen-start",{share_id});
 await until(()=>seen(b,"video"),"agent receives consented synthetic screen RTP",12000);
 console.log("PASS B5 consented screen source carries synthetic video RTP, agent cannot grant screen");
 await s(hs.access_token,"screen-stop",{share_id});
 await until(async()=>evicted.has(h.id)&&!(await sfu.listParticipants("wm-support-"+callId)).some(p=>p.identity===h.id),"screen withdrawal evicts old grant",12000);
 const old=await ctx.newPage();await old.goto(origin);
 assert.equal(await old.evaluate(async token=>{const r=new window.LivekitClient.Room();try{await r.connect("ws://127.0.0.1:7881",token);await r.disconnect();return false}catch{return true}},sg.token),true);
 await s(gs.access_token,"call-end");
 await until(async()=>evicted.has(g.id),"ticket call end evicts agent",12000);
 assert.equal((await fail(hs.access_token,"call-grant")).status,403);
 console.log("PASS B5 screen consent withdrawal and call end revoke actual SFU transport");
}finally{
 if(browser)await browser.close();if(callId)await sfu.deleteRoom("wm-support-"+callId).catch(()=>{});
 await Promise.all([app,proxy.server].map(s=>new Promise(r=>s.close(r))));
 for(const child of children)if(child.exitCode===null){child.kill("SIGTERM");await new Promise(r=>child.once("exit",r))}
}
