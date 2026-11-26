import {chromium,firefox,webkit} from "playwright";
import assert from "node:assert/strict";
import {createServer} from "node:http";
import {readFile} from "node:fs/promises";
import {resolve,extname,sep} from "node:path";
const base="http://127.0.0.1:4173";
const root=resolve("apps/web/zipple/dist");
const mime={".html":"text/html",".js":"application/javascript",".css":"text/css",".json":"application/json",".webmanifest":"application/manifest+json",".png":"image/png",".svg":"image/svg+xml",".webp":"image/webp",".jpg":"image/jpeg",".mp4":"video/mp4"};
async function outageServer(){const server=createServer(async(req,res)=>{try{const url=new URL(req.url,"http://127.0.0.1");const file=resolve(root,"."+decodeURIComponent(url.pathname==="/"?"/index.html":url.pathname));if(!file.startsWith(root+sep)){res.writeHead(403).end();return}const bytes=await readFile(file);res.writeHead(200,{"Content-Type":mime[extname(file)]??"application/octet-stream","Cache-Control":"no-store"});res.end(bytes)}catch{res.writeHead(404).end()}});await new Promise((ok,fail)=>{server.once("error",fail);server.listen(0,"127.0.0.1",ok)});return server}
const expected="Servez mieux, gérez en toute sécurité.";
for(const [name,engine] of [["chromium",chromium],["firefox",firefox],["webkit",webkit]]){
 const browser=await engine.launch({headless:true});let server;
 try{
  if(name==="webkit")server=await outageServer();const origin=server?"http://127.0.0.1:"+server.address().port:base;
  const ctx=await browser.newContext({viewport:{width:390,height:844},reducedMotion:"reduce"});
  const page=await ctx.newPage();await page.goto(origin);
  await page.getByRole("heading",{name:expected}).waitFor();
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.equal(await page.getByRole("checkbox",{name:"Rester connecté"}).isChecked(),false);
  const manifest=await (await page.request.get(origin+"/manifest.webmanifest")).json();
  assert.equal(manifest.display,"standalone");assert.equal(manifest.start_url,"/");assert.equal(manifest.id,"/");
  for(const size of [192,512]){
   const icon=manifest.icons.find(x=>x.sizes===size+"x"+size&&x.type==="image/png");assert.ok(icon);
   const image=await page.request.get(origin+icon.src);assert.equal(image.status(),200);
   const bytes=await image.body();assert.equal(bytes.readUInt32BE(16),size);assert.equal(bytes.readUInt32BE(20),size);
   const dims=await page.evaluate(async url=>{const img=new Image();img.src=url;await img.decode();return [img.naturalWidth,img.naturalHeight]},icon.src);assert.deepEqual(dims,[size,size]);
  }
  await page.waitForFunction(()=>!!navigator.serviceWorker?.controller,{},{timeout:30000});
  assert.equal(await page.evaluate(()=>!!document.querySelector('link[rel="apple-touch-icon"]')),true);
  if(name==="chromium"){
   const cdp=await ctx.newCDPSession(page);const {installabilityErrors}=await cdp.send("Page.getInstallabilityErrors");
   assert.deepEqual(installabilityErrors,[],"Chromium installability criteria");console.log("ZIPPLE_PWA_CHROMIUM_INSTALLABILITY_PASS");
  }
  if(server){const stopped=server;server=undefined;await new Promise((ok,fail)=>{stopped.close(error=>error?fail(error):ok());stopped.closeAllConnections()});await assert.rejects(fetch(origin),/fetch failed/);const navigation=await page.reload({waitUntil:"domcontentloaded"});assert.ok(navigation?.fromServiceWorker(),"WebKit navigation must be served by service worker during actual server outage");}
  else{await ctx.setOffline(true);await page.reload();await ctx.setOffline(false)}
  await page.getByRole("heading",{name:expected}).waitFor();
  console.log("ZIPPLE_PWA_"+name.toUpperCase()+"_OFFLINE_PASS");await ctx.close();
 }finally{if(server){server.closeAllConnections();await new Promise(ok=>server.close(ok))}await browser.close()}
}
