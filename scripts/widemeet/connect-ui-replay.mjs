// Disposable real React Connect components + Edge + actual WSS signaling + SFU.
// The source's existing authenticated SDK call is maintained by the parent recipe.
import assert from "node:assert/strict";
import {createServer as httpsServer} from "node:https";
import {mkdtemp,readFile,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {execFileSync} from "node:child_process";
export const connectUiOrigin="https://127.0.0.1:4174";
export const connectUiWss="wss://127.0.0.1:7884";
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const listen=(server,port)=>new Promise((resolve,reject)=>{server.once("error",reject);server.listen(port,"127.0.0.1",resolve)});
async function until(fn,label,ms=20000){const end=Date.now()+ms;while(Date.now()<end){if(await fn())return;await delay(200)}throw Error(label)}
export async function startConnectUiReplay({browser,sourceSession,receiverSession,roomId,roomApi,evicted,sfu,proxyServer}){
 assert.equal(roomApi,"http://127.0.0.1:8001");
 const {build}=await import("esbuild");
 const bundle=await build({stdin:{contents:`import React from "react";import{createRoot}from"react-dom/client";import{ConnectSource,ConnectReceiver}from"./apps/web/widemeet/src/Connect.tsx";const root=createRoot(document.getElementById("root"));window.mountConnect=(kind,session,roomId)=>{const props={base:location.origin+"/functions/v1/widemeet-auth",session,locale:"fr"};root.render(kind==="source"?React.createElement(ConnectSource,{...props,roomId,isHost:true}):React.createElement(ConnectReceiver,{...props,onExit:()=>root.render(null)}))};`,resolveDir:process.cwd(),loader:"tsx"},bundle:true,write:false,format:"esm",platform:"browser",define:{"process.env.NODE_ENV":'"production"'}});
 const temp=await mkdtemp(join(tmpdir(),"wm-connect-ui-"));
 let app,signaling,context;const sockets=new Set();
 try{
  const key=join(temp,"key.pem"),cert=join(temp,"cert.pem");
  execFileSync("openssl",["req","-x509","-newkey","rsa:2048","-nodes","-keyout",key,"-out",cert,"-days","1","-subj","/CN=127.0.0.1","-addext","subjectAltName=IP:127.0.0.1"],{stdio:"ignore"});
  const tls={key:await readFile(key),cert:await readFile(cert)};
  // Terminate TLS directly in Node HTTPS and reuse the SAME checked HTTP/upgrade
  // handlers as the successful loopback SDK replay. No raw TCP forwarding, no
  // alternate authorization path, no relaxation of origin or grant validation.
  assert.equal(proxyServer.listenerCount("upgrade"),1);
  signaling=httpsServer(tls,(req,res)=>proxyServer.emit("request",req,res));
  signaling.on("upgrade",(req,socket,head)=>proxyServer.emit("upgrade",req,socket,head));
  signaling.on("connection",socket=>{sockets.add(socket);socket.on("close",()=>sockets.delete(socket))});
  signaling.on("tlsClientError",()=>{});
  app=httpsServer(tls,async(req,res)=>{
   try{
    if(req.url==="/bundle.js"){res.writeHead(200,{"Content-Type":"application/javascript","Cache-Control":"no-store"});return res.end(bundle.outputFiles[0].contents)}
    if(req.url==="/"){res.writeHead(200,{"Content-Type":"text/html","Cache-Control":"no-store"});return res.end('<!doctype html><meta charset="utf-8"><title>Connect UI replay</title><div id="root"></div><script type="module" src="/bundle.js"></script>')}
    if(req.url!=="/functions/v1/widemeet-room/connect"||req.method!=="POST"){res.writeHead(404);return res.end()}
    const chunks=[];let n=0;for await(const c of req){n+=c.length;if(n>16384)throw Error("body");chunks.push(c)}
    const r=await fetch(roomApi+"/connect",{method:"POST",headers:{"Content-Type":"application/json",Authorization:req.headers.authorization??"",Origin:connectUiOrigin},body:Buffer.concat(chunks),redirect:"error"});
    res.writeHead(r.status,{"Content-Type":"application/json","Cache-Control":"no-store"});res.end(Buffer.from(await r.arrayBuffer()));
   }catch{res.writeHead(502);res.end()}
  });
  await Promise.all([listen(signaling,7884),listen(app,4174)]);
  context=await browser.newContext({ignoreHTTPSErrors:true});
  const source=await context.newPage(),receiver=await context.newPage(),diagnostics=[];
  for(const [label,page] of [["source",source],["receiver",receiver]]){
   page.on("response",r=>{const u=new URL(r.url());if(u.pathname.endsWith("/widemeet-room/connect")){let action="unknown";try{action=r.request().postDataJSON()?.action??"unknown"}catch{}if(["offer","preview","confirm","receive","source-status","source-stop","receiver-stop","policy"].includes(action))diagnostics.push(label+" "+action+" HTTP "+r.status())}else if(u.pathname==="/rtc/validate")diagnostics.push(label+" rtc validate HTTP "+r.status())});
   page.on("requestfailed",r=>{const u=new URL(r.url());if(u.port==="7884"||u.port==="4174")diagnostics.push(label+" request failed "+u.pathname+" "+(r.failure()?.errorText??"unknown"))});
   page.on("websocket",ws=>{const u=new URL(ws.url());if(u.port==="7884"){diagnostics.push(label+" WSS created "+u.pathname);ws.on("close",()=>diagnostics.push(label+" WSS closed"));ws.on("socketerror",()=>diagnostics.push(label+" WSS error"));let received=false,sent=false;ws.on("framereceived",()=>{if(!received){received=true;diagnostics.push(label+" WSS first inbound frame")}});ws.on("framesent",()=>{if(!sent){sent=true;diagnostics.push(label+" WSS first outbound frame")}})}});
  }
  for(const [page,kind,session] of [[source,"source",sourceSession],[receiver,"receiver",receiverSession]]){
   await page.goto(connectUiOrigin);await page.waitForFunction(()=>typeof window.mountConnect==="function");
   await page.evaluate(({kind,session,roomId})=>window.mountConnect(kind,session,roomId),{kind,session,roomId});
  }
  // Check the TLS listener itself without any credential: it must reject the upgrade.
  const denied=await context.request.get("https://127.0.0.1:7884/rtc/validate",{headers:{Origin:connectUiOrigin}});assert.equal(denied.status(),403,"TLS route must enforce existing admission");
  await receiver.getByLabel("Nom de l’écran",{exact:true}).fill("B2 écran interface");
  await receiver.getByRole("button",{name:"Créer un code",exact:true}).click();
  const qr=receiver.getByRole("img",{name:"QR d’appairage Connect",exact:true});await qr.waitFor();
  const code=await receiver.locator("output").textContent();assert.match(code,/^[a-f0-9]{64}$/);
  await source.getByLabel("Code de l’écran",{exact:true}).fill("wm-connect:"+code);
  await source.getByRole("button",{name:"Vérifier l’écran",exact:true}).click();
  await source.getByText("Confirmer cet écran : B2 écran interface",{exact:true}).waitFor();
  const [confirmResponse]=await Promise.all([source.waitForResponse(r=>r.url().endsWith("/widemeet-room/connect")&&r.request().postDataJSON()?.action==="confirm"),source.getByRole("button",{name:"Confirmer l’appairage",exact:true}).click()]);
  assert.equal(confirmResponse.status(),200);assert.equal((await confirmResponse.json()).confirmed,true);
  try{await receiver.getByRole("status").filter({hasText:/^Affichage connecté$/}).waitFor({timeout:20000})}catch(e){
   // Only fixed UI status/HTTP diagnostics, no token, code, full request URL or private data.
   console.error("B2_CONNECT_UI_DIAGNOSTICS",JSON.stringify({events:diagnostics.slice(-35),alert:await receiver.getByRole("alert").count(),waiting:await receiver.getByText("En attente de confirmation",{exact:true}).count(),idle:await receiver.getByRole("button",{name:"Créer un code",exact:true}).count(),displayCount:(await sfu.listParticipants("wm-"+roomId)).filter(p=>p.identity.startsWith("wm-display-")).length}));throw e
  }
  await receiver.waitForFunction(()=>[...document.querySelectorAll("video")].some(v=>v.videoWidth>0&&v.readyState>=2),{},{timeout:20000});
  assert.equal(await receiver.getByRole("button",{name:/micro|caméra|partager|chat/i}).count(),0);
  assert.equal(await receiver.locator("audio").evaluateAll(els=>els.every(a=>a.muted)),true);
  const displays=(await sfu.listParticipants("wm-"+roomId)).filter(p=>p.identity.startsWith("wm-display-"));
  assert.equal(displays.length,1);const display=displays[0];assert.equal(display.permission.canPublish,false);assert.equal(display.tracks.length,0);
  await source.getByText("Récepteur autorisé : B2 écran interface",{exact:true}).waitFor();
  await source.getByRole("button",{name:"Arrêter l’affichage",exact:true}).click();
  await until(async()=>evicted.has(display.identity)&&!(await sfu.listParticipants("wm-"+roomId)).some(p=>p.identity===display.identity),"receiver UI revoke");
  await receiver.locator("video").first().waitFor({state:"detached",timeout:20000});
  await receiver.getByRole("button",{name:"Créer un code",exact:true}).waitFor();
  assert.ok((await sfu.listParticipants("wm-"+roomId)).some(p=>p.identity===sourceSession.member_id));
  console.log("PASS B2 actual Connect source/receiver React UI: QR, confirmation, WSS, decoded video, muted audio, read-only grant, stop and purge");
 }finally{
  if(context)await context.close();for(const socket of sockets)socket.destroy();
  await Promise.all([app,signaling].filter(Boolean).map(server=>new Promise(resolve=>server.close(resolve))));
  await rm(temp,{recursive:true,force:true});
 }
}
