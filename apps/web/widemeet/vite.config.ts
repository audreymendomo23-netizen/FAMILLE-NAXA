import {defineConfig,loadEnv} from "vite";import react from "@vitejs/plugin-react";import {build} from "esbuild";
// Reuse the existing shell worker; no second competing service worker scope.
// Firebase initialization is bundled only for a dedicated, explicitly configured WideMeet project.
export default defineConfig(({mode})=>{
 const env={...loadEnv(mode,process.cwd(),"VITE_"),...process.env};
 const config={apiKey:env.VITE_WIDEMEET_FIREBASE_API_KEY,appId:env.VITE_WIDEMEET_FIREBASE_APP_ID,projectId:env.VITE_WIDEMEET_FIREBASE_PROJECT_ID,messagingSenderId:env.VITE_WIDEMEET_FIREBASE_SENDER_ID};
 const push=env.VITE_WIDEMEET_PUSH_ENABLED==="true"&&Object.values(config).every(Boolean)&&/^widemeet-[a-z0-9-]{1,20}[a-z0-9]$/.test(config.projectId??"");
 return {plugins:[react(),{name:"widemeet-shell",async generateBundle(_o,bundle){
 const urls=["/","/manifest.webmanifest","/brand/logo.png","/brand/icon.svg",...Object.keys(bundle).filter(x=>x.startsWith("assets/")).map(x=>"/"+x)];
 const cache="widemeet-shell-"+Object.keys(bundle).filter(x=>x.startsWith("assets/")).sort().join("|");
 let source=`const C=${JSON.stringify(cache)},U=${JSON.stringify(urls)};self.addEventListener("install",e=>e.waitUntil(caches.open(C).then(c=>c.addAll(U))));self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x.startsWith("widemeet-shell-")&&x!==C).map(x=>caches.delete(x))))));self.addEventListener("fetch",e=>{const u=new URL(e.request.url);if(e.request.method!=="GET"||u.origin!==self.location.origin)return;if(e.request.mode==="navigate"){e.respondWith(fetch(e.request).catch(()=>caches.open(C).then(c=>c.match("/"))));return}if(U.includes(u.pathname))e.respondWith(caches.open(C).then(c=>c.match(u.pathname)).then(r=>r||fetch(e.request)));});`;
 if(push){
 const worker=await build({stdin:{contents:`import{initializeApp}from"firebase/app";import{getMessaging,onBackgroundMessage}from"firebase/messaging/sw";const app=initializeApp(${JSON.stringify(config)});onBackgroundMessage(getMessaging(app),()=>{});`,resolveDir:process.cwd(),loader:"js"},bundle:true,write:false,platform:"browser",format:"iife",minify:true,define:{"process.env.NODE_ENV":'"production"'}});
 source+=`\nself.addEventListener("notificationclick",e=>{if(e.notification.title!=="WideMeet")return;e.stopImmediatePropagation();e.notification.close();e.waitUntil(self.clients.matchAll({type:"window",includeUncontrolled:true}).then(async cs=>{const c=cs.find(x=>new URL(x.url).origin===self.location.origin);if(c){await c.focus();c.postMessage({app_id:"WIDEMEET",action:"refresh-notices"})}else await self.clients.openWindow("/")}))});\n`+worker.outputFiles[0].text;
 }
 this.emitFile({type:"asset",fileName:"sw.js",source});
 }}]};
});
