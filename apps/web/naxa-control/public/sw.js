// Network-only for all authenticated content; never cache API responses or tokens.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{if(event.request.mode!=='navigate'||new URL(event.request.url).origin!==self.location.origin)return;event.respondWith(fetch(event.request,{cache:'no-store'}).catch(()=>new Response('<!doctype html><html lang="fr"><meta charset="utf-8"><title>NAXA CONTROL</title><h1>Connexion requise</h1><p>Reconnectez-vous pour accéder aux comptes. Aucune donnée client disponible hors ligne.</p></html>',{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}})))});
