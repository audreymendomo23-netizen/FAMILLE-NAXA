import assert from "node:assert/strict";
import {createHmac,randomBytes,randomUUID} from "node:crypto";
import {createServer} from "node:http";
import {readFile,readdir,stat} from "node:fs/promises";
import {execFileSync} from "node:child_process";
import {chromium} from "@playwright/test";
import {RoomServiceClient,EgressClient,EncodedFileOutput,EncodedFileType,EgressStatus} from "livekit-server-sdk";
import {createMediaProxy} from "../../packages/media-core/signaling-proxy.mjs";
const key=process.env.LK_TEST_KEY,secret=process.env.LK_TEST_SECRET;
assert.ok(key&&secret&&secret.length>=32);
const room="wm-"+randomUUID(),origin="http://127.0.0.1:4173",upstream="http://127.0.0.1:7880";
const service=new RoomServiceClient(upstream,key,secret);
const admissions=new Map();
for(const identity of ["host","guest"])admissions.set(identity,{app:"wm",room,identity,enabled:true,admitted:true,status:"open",endMs:Date.now()+300000,sources:["camera","microphone","screen_share"],canPublish:true});
function token(identity,roomName=room){
 const now=Math.floor(Date.now()/1000),encode=x=>Buffer.from(JSON.stringify(x)).toString("base64url");
 const a=encode({alg:"HS256",typ:"JWT"})+"."+encode({iss:key,sub:identity,nbf:now-2,exp:now+90,video:{room:roomName,roomJoin:true,canPublish:true,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:["camera","microphone","screen_share"],roomCreate:false,roomAdmin:false,roomRecord:false,roomList:false}});
 return a+"."+createHmac("sha256",secret).update(a).digest("base64url");
}
const evicted=new Set();
const proxy=createMediaProxy({upstream,key,secret,allowedOrigins:new Set([origin]),readAdmission:async g=>admissions.get(g.identity),onRevoke:async g=>{await service.removeParticipant(g.room,g.identity);evicted.add(g.identity)},checkEveryMs:500});
const bundle=await readFile("node_modules/livekit-client/dist/livekit-client.umd.js");
const app=createServer((req,res)=>{if(req.url==="/sdk.js"){res.writeHead(200,{"Content-Type":"application/javascript"});res.end(bundle)}else{res.writeHead(200,{"Content-Type":"text/html"});res.end('<!doctype html><title>Media replay</title><script src="/sdk.js"></script><body></body>')}});
const listen=(s,p)=>new Promise((resolve,reject)=>{s.once("error",reject);s.listen(p,"127.0.0.1",resolve)});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let browser;
async function until(fn,label,ms=25000){const end=Date.now()+ms;while(Date.now()<end){if(await fn())return;await delay(250)}throw Error("timeout: "+label)}
try{
 await listen(proxy.server,7881);await listen(app,4173);
 await service.createRoom({name:room,emptyTimeout:300,maxParticipants:2});
 browser=await chromium.launch({headless:true,args:["--use-fake-device-for-media-stream","--use-fake-ui-for-media-stream","--autoplay-policy=no-user-gesture-required"]});
 const context=await browser.newContext({permissions:["camera","microphone"]});
 const a=await context.newPage(),b=await context.newPage();
 for(const page of [a,b])await page.goto(origin);
 async function join(page,t){
 await page.evaluate(async t=>{
  const lk=window.LivekitClient;const r=new lk.Room({adaptiveStream:false,dynacast:false});window.r=r;window.received=[];
  r.on(lk.RoomEvent.TrackSubscribed,(track)=>{window.received.push(track);const el=track.attach();el.autoplay=true;document.body.appendChild(el)});
  await r.connect("ws://127.0.0.1:7881",t);
  await r.localParticipant.setMicrophoneEnabled(true);await r.localParticipant.setCameraEnabled(true);
 },t);
 }
 const oldGuest=token("guest");await join(a,token("host"));await join(b,oldGuest);
 async function inbound(page){return page.evaluate(async()=>{
 const seen={audio:false,video:false};
 for(const t of window.received){const s=await t.getRTCStatsReport();if(!s)continue;for(const x of s.values())if(x.type==="inbound-rtp"&&x.bytesReceived>0){if(t.kind==="audio")seen.audio=true;if(t.kind==="video"&&(x.framesDecoded??0)>0)seen.video=true}}
 return seen.audio&&seen.video;
 })}
 await until(async()=>await inbound(a)&&await inbound(b),"bidirectional audio/video RTP");
 console.log("PASS actual bidirectional SFU audio/video RTP with synthetic browser devices");
 // Publish a synthetic screen track through the same transport. No physical capture implied.
 await a.evaluate(async()=>{const lk=window.LivekitClient,c=document.createElement("canvas");c.width=640;c.height=360;document.body.appendChild(c);let n=0;setInterval(()=>{const ctx=c.getContext("2d");ctx.fillStyle=n++%2?"red":"blue";ctx.fillRect(0,0,640,360)},100);const t=c.captureStream(10).getVideoTracks()[0];await window.r.localParticipant.publishTrack(t,{source:lk.Track.Source.ScreenShare})});
 await until(()=>b.evaluate(()=>window.received.some(t=>t.source===window.LivekitClient.Track.Source.ScreenShare)),"screen track");
 console.log("PASS screen-share track routed by SFU");
 if(process.env.WM_TEST_EGRESS==="true"){
 const egress=new EgressClient(upstream,key,secret);
 const started=await egress.startRoomCompositeEgress(room,new EncodedFileOutput({fileType:EncodedFileType.OGG,filepath:"/out/"+room+".ogg"}),{audioOnly:true});
 const id=started.egressId;assert.ok(id);
 let stopped=false;
 try{
 await until(async()=>{const [info]=await egress.listEgress({egressId:id});return info?.status===EgressStatus.EGRESS_ACTIVE},"audio egress active",90000);
 await delay(5000);
 await egress.stopEgress(id);stopped=true;
 await until(async()=>{const [info]=await egress.listEgress({egressId:id});if([EgressStatus.EGRESS_FAILED,EgressStatus.EGRESS_ABORTED].includes(info?.status))throw Error("egress failed");return info?.status===EgressStatus.EGRESS_COMPLETE},"audio egress complete",90000);
 const out=process.env.WM_EGRESS_OUT;assert.ok(out);
 const files=(await readdir(out)).filter(x=>x.endsWith(".ogg"));assert.equal(files.length,1);
 const p=out+"/"+files[0];assert.ok((await stat(p)).size>1000);
 const probe=JSON.parse(execFileSync("ffprobe",["-v","error","-show_streams","-show_format","-of","json",p],{encoding:"utf8"}));
 assert.ok(probe.streams.some(x=>x.codec_type==="audio"));assert.ok(probe.streams.every(x=>x.codec_type!=="video"));assert.ok(Number(probe.format.duration)>1);
 console.log("PASS actual server audio-only Egress, nonempty file, decoded audio stream and no video");
 }finally{if(!stopped)await egress.stopEgress(id).catch(()=>{})}
 }
 admissions.get("guest").enabled=false;
 await until(async()=>evicted.has("guest")&&!(await service.listParticipants(room)).some(p=>p.identity==="guest"),"guest SFU eviction");
 assert.ok((await service.listParticipants(room)).some(p=>p.identity==="host"));
 const fresh=await context.newPage();await fresh.goto(origin);
 const denied=await fresh.evaluate(async t=>{const r=new window.LivekitClient.Room();try{await r.connect("ws://127.0.0.1:7881",t);await r.disconnect();return false}catch{return true}},oldGuest);
 assert.equal(denied,true);console.log("PASS revoked participant cannot reconnect with unexpired signed token");
 const wrong=await fresh.evaluate(async t=>{const r=new window.LivekitClient.Room();try{await r.connect("ws://127.0.0.1:7881",t);await r.disconnect();return false}catch{return true}},token("host","ns-"+randomUUID()));
 assert.equal(wrong,true);console.log("PASS cross-product room denied");
}finally{
 if(browser)await browser.close();await service.deleteRoom(room).catch(()=>{});
 await Promise.all([app,proxy.server].map(s=>new Promise(r=>s.close(r))));
}
