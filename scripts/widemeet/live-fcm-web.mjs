import assert from "node:assert/strict";
import {chromium} from "@playwright/test";
import {build} from "esbuild";
import {createServer} from "node:http";
import {readFile,writeFile,mkdtemp,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {resolve,extname,sep} from "node:path";
import {liveSend} from "./live-fcm-identity.mjs";
const root=resolve("apps/web/widemeet/dist");
await build({entryPoints:["apps/web/widemeet/e2e/fixtures/fcm-live.mjs"],outfile:resolve(root,"__qualification-client.js"),bundle:true,platform:"browser",format:"esm",minify:true,define:{"process.env.NODE_ENV":JSON.stringify("production"),"import.meta.env":JSON.stringify({VITE_WIDEMEET_PUSH_ENABLED:"true"})}});
await writeFile(resolve(root,"__qualification.html"),'<!doctype html><meta charset="utf-8"><title>WideMeet FCM test</title><script type="module" src="/__qualification-client.js"></script>');
const types={".js":"text/javascript",".html":"text/html",".css":"text/css",".png":"image/png",".svg":"image/svg+xml",".webmanifest":"application/manifest+json",".woff2":"font/woff2"};
const server=createServer(async(req,res)=>{try{const p=new URL(req.url,"http://127.0.0.1").pathname,file=resolve(root,"."+ (p==="/"?"/index.html":p));if(!file.startsWith(root+sep)){res.writeHead(403).end();return}const data=await readFile(file);res.writeHead(200,{"Content-Type":types[extname(file)]??"application/octet-stream","Cache-Control":"no-store"});res.end(data)}catch{res.writeHead(404).end()}});
await new Promise(r=>server.listen(4173,"127.0.0.1",r));
const profile=await mkdtemp(resolve(tmpdir(),"wm-fcm-profile-"));
let context,page;
try{
 // PushManager is unavailable or denied in off-the-record Chrome contexts. Use a fresh regular profile.
 context=await chromium.launchPersistentContext(profile,{channel:"chrome",headless:false,ignoreDefaultArgs:["--disable-background-networking","--disable-component-update","--disable-sync"],args:["--no-sandbox"]});
 await context.grantPermissions(["notifications"],{origin:"http://127.0.0.1:4173"});
 page=context.pages()[0]??await context.newPage();await page.goto("http://127.0.0.1:4173/__qualification.html");await page.waitForFunction(()=>!!window.qualification);
 const token=await page.evaluate(()=>Promise.race([window.qualification.open(),new Promise((_,reject)=>setTimeout(()=>reject(Error("FCM token timeout")),60000))]));
 assert.ok(typeof token==="string"&&token.length>=30,"FCM token registration");console.log("PASS WM FCM actual Web registration");
 if(process.env.WM_FCM_BACKGROUND_ONLY!=="true"){
  const foreground=await liveSend("web-foreground",token);
  await page.waitForFunction(id=>window.qualification.has(id),foreground,{timeout:100000});console.log("PASS WM FCM actual Chromium foreground receipt");
 }
 // Eliminate reliance on focus/visibility emulation under Xvfb. No app window may remain open.
 const other=await context.newPage();await other.goto("about:blank");
 const swUrl="http://127.0.0.1:4173/sw.js";
 const worker=context.serviceWorkers().find(w=>w.url()===swUrl);
 assert.ok(worker,"active WideMeet service worker");
 await page.close();page=null;
 const windows=await worker.evaluate(async()=> (await self.clients.matchAll({type:"window",includeUncontrolled:true})).length);
 assert.equal(windows,0,"no visible or hidden WideMeet window before real push");
 const background=await liveSend("web-background",token);
 const deadline=Date.now()+100000;let found=false;
 while(Date.now()<deadline){
  const current=context.serviceWorkers().find(w=>w.url()===swUrl);
  if(current){try{found=await current.evaluate(async id=>(await self.registration.getNotifications({tag:id})).some(n=>n.tag===id&&n.title==="WideMeet"),background)}catch{/* worker may stop or restart */}}
  if(found)break;
  await new Promise(r=>setTimeout(r,500));
 }
 assert.ok(found,"real background notification with no application window");console.log("PASS WM FCM actual PWA service-worker background notification");
 page=await context.newPage();await page.goto("http://127.0.0.1:4173/__qualification.html");await page.waitForFunction(()=>!!window.qualification);
 await page.evaluate(async()=>{await window.qualification.open();await window.qualification.close()});console.log("PASS WM FCM Web token cleanup");
}finally{
 if(page&&!page.isClosed())await Promise.race([page.evaluate(()=>window.qualification?.close()).catch(()=>{}),new Promise(r=>setTimeout(r,10000))]);
 await context?.close();await rm(profile,{recursive:true,force:true});await new Promise(r=>server.close(r));
}
