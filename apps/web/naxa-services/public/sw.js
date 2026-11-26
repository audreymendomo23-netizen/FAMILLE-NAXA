const CACHE = "naxa-services-shell-" + "__NAXA_SHELL_VERSION__";
const BUILD_ASSETS = ["__NAXA_BUILD_ASSETS__"];
const CORE_ASSETS = ["/", "/manifest.webmanifest", "/naxa-services-icon.svg", "/media/office.jpg", "/media/workspace.jpg", "/media/printing.jpg", "/media/teamwork.jpg", "/media/stationery.jpg", "/media/wood-stock.jpg", "/media/furniture.jpg", "/media/painting.jpg"];
const ASSETS = new Set([...CORE_ASSETS,...BUILD_ASSETS]);
self.addEventListener("install", event => {
  event.waitUntil((async()=>{
    if(BUILD_ASSETS.includes("__NAXA_BUILD_ASSETS__"))throw Error("OFFLINE_MANIFEST_NOT_BUILT");
    const cache=await caches.open(CACHE);
    try{await cache.addAll([...ASSETS].map(path=>new Request(path,{cache:"reload"})));}
    catch(error){await caches.delete(CACHE);throw error;}
    // Activate only when the old shell no longer controls an open tab.
  })());
});
self.addEventListener("activate",event=>{
 event.waitUntil((async()=>{
  for(const key of await caches.keys())if((key==="famille-shell-v1"||key.startsWith("naxa-services-shell-"))&&key!==CACHE)await caches.delete(key);
  await self.clients.claim();
 })());
});
self.addEventListener("fetch",event=>{
 const req=event.request,url=new URL(req.url);
 if(req.method!=="GET"||url.origin!==self.location.origin)return;
 if(req.mode==="navigate"){
   event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    return await cache.match("/")||fetch(req);
   })());return;
 }
 if(!ASSETS.has(url.pathname)||url.search)return;
 event.respondWith((async()=>{
  const cache=await caches.open(CACHE);
  return await cache.match(url.pathname)||fetch(req);
 })());
});
