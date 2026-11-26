const CACHE="zipple-shell-v5";
const STATIC=["/","/manifest.webmanifest","/zipple-logo.jpg","/zipple-brand.svg","/zipple-cloche.svg","/zipple-restaurant-bar.webp","/icon.svg","/icon-192.png","/icon-512.png","/zipple-precache.json"];
self.addEventListener("install",e=>e.waitUntil((async()=>{
 const response=await fetch("/zipple-precache.json",{cache:"no-store"});if(!response.ok)throw Error("ZIPPLE_PRECACHE_MISSING");
 const assets=await response.json();if(!Array.isArray(assets)||!assets.length||assets.some(x=>typeof x!=="string"||!/^\/assets\/[A-Za-z0-9._/-]+$/.test(x)||x.includes("..")))throw Error("ZIPPLE_PRECACHE_INVALID");
 const cache=await caches.open(CACHE);await cache.addAll([...STATIC,...assets]);
 // Optional media must not prevent the application shell being installed.
 try{const video=await fetch("/zipple-startup.mp4",{cache:"no-store"});if(video.ok&&video.headers.get("content-type")?.includes("video/mp4"))await cache.put("/zipple-startup.mp4",video)}catch{}
})()));
self.addEventListener("activate",e=>e.waitUntil((async()=>{const keys=await caches.keys();await Promise.all(keys.filter(k=>k.startsWith("zipple-shell-")&&k!==CACHE).map(k=>caches.delete(k)));await self.clients.claim()})()));
self.addEventListener("fetch",e=>{const u=new URL(e.request.url);if(e.request.method!=="GET"||u.origin!==self.location.origin||e.request.headers.has("authorization")||e.request.headers.has("range")||u.pathname.startsWith("/api/")||u.pathname.startsWith("/session/"))return;
 if(e.request.mode==="navigate"){e.respondWith(fetch(e.request).catch(async()=>{const c=await caches.open(CACHE);return (await c.match("/"))||Response.error()}));return}
 if(!u.pathname.startsWith("/assets/")&&!STATIC.includes(u.pathname)&&u.pathname!=="/zipple-startup.mp4")return;
 e.respondWith((async()=>{const c=await caches.open(CACHE);const hit=await c.match(e.request);if(hit)return hit;const result=await fetch(e.request);if(result.ok&&result.type==="basic"&&(u.pathname!=="/zipple-startup.mp4"||result.headers.get("content-type")?.includes("video/mp4")))await c.put(e.request,result.clone());return result})());
});
