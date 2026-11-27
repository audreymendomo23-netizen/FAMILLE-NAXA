import assert from "node:assert/strict";
import {chromium} from "@playwright/test";
import {build} from "esbuild";
import {createServer} from "node:http";
import {readFile,writeFile} from "node:fs/promises";
import {resolve,extname,sep} from "node:path";
import {liveSend} from "./live-fcm-identity.mjs";
const root=resolve("apps/web/widemeet/dist");
await build({entryPoints:["apps/web/widemeet/e2e/fixtures/fcm-live.mjs"],outfile:resolve(root,"__qualification-client.js"),bundle:true,platform:"browser",format:"esm",minify:true,define:{"process.env.NODE_ENV":JSON.stringify("production"),"import.meta.env":JSON.stringify({VITE_WIDEMEET_PUSH_ENABLED:"true"})}});
await writeFile(resolve(root,"__qualification.html"),'<!doctype html><meta charset="utf-8"><title>WideMeet FCM test</title><script type="module" src="/__qualification-client.js"></script>');
const types={".js":"text/javascript",".html":"text/html",".css":"text/css",".png":"image/png",".svg":"image/svg+xml",".webmanifest":"application/manifest+json",".woff2":"font/woff2"};
const server=createServer(async(req,res)=>{try{const p=new URL(req.url,"http://127.0.0.1").pathname,file=resolve(root,"."+ (p==="/"?"/index.html":p));if(!file.startsWith(root+sep)){res.writeHead(403).end();return}const data=await readFile(file);res.writeHead(200,{"Content-Type":types[extname(file)]??"application/octet-stream","Cache-Control":"no-store"});res.end(data)}catch{res.writeHead(404).end()}});
await new Promise(r=>server.listen(4173,"127.0.0.1",r));
let browser,page;
try{
 browser=await chromium.launch({channel:"chrome",headless:false,ignoreDefaultArgs:["--disable-background-networking","--disable-component-update","--disable-sync"],args:["--no-sandbox"]});
 const context=await browser.newContext();await context.grantPermissions(["notifications"],{origin:"http://127.0.0.1:4173"});
 page=await context.newPage();await page.goto("http://127.0.0.1:4173/__qualification.html");await page.waitForFunction(()=>!!window.qualification);
 const token=await page.evaluate(()=>Promise.race([window.qualification.open(),new Promise((_,reject)=>setTimeout(()=>reject(Error("FCM token timeout")),60000))]));
 assert.ok(typeof token==="string"&&token.length>=30,"FCM token registration");console.log("PASS WM FCM actual Web registration");
 const foreground=await liveSend("web-foreground",token);
 await page.waitForFunction(id=>window.qualification.has(id),foreground,{timeout:100000});console.log("PASS WM FCM actual Chromium foreground receipt");
 const other=await context.newPage();await other.goto("about:blank");await other.bringToFront();
 await page.waitForFunction(()=>document.visibilityState==="hidden",null,{timeout:10000});
 const background=await liveSend("web-background",token);
 await page.waitForFunction(id=>window.qualification.background(id),background,{timeout:100000});console.log("PASS WM FCM actual PWA service-worker background notification");
 await page.bringToFront();await page.evaluate(()=>window.qualification.close());console.log("PASS WM FCM Web token cleanup");
}finally{
 if(page&&!page.isClosed())await Promise.race([page.evaluate(()=>window.qualification?.close()).catch(()=>{}),new Promise(r=>setTimeout(r,10000))]);
 await browser?.close();await new Promise(r=>server.close(r));
}
