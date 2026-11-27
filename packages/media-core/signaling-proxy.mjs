// Generic media signaling reverse proxy. Production must bind SFU HTTP privately;
// only this gateway may be public. ICE/DTLS ports are not HTTP signaling ports.
import http from "node:http";
import {WebSocket,WebSocketServer} from "ws";
import {verifyJoinToken,allowedJoin} from "./signaling-policy.mjs";
export function createMediaProxy({upstream,key,secret,readAdmission,allowedOrigins,onRevoke,onAdmit=async()=>{},allowNative=false,checkEveryMs=1000}){
 const origin=new URL(upstream);
 if(!["http:","https:"].includes(origin.protocol)||origin.username||origin.password||origin.pathname!=="/"||origin.search||origin.hash)throw Error("invalid upstream");
 if(typeof onRevoke!=="function")throw Error("SFU revocation callback required");
 const active=new Set(),leases=new Map(),wss=new WebSocketServer({noServer:true,maxPayload:1024*1024});
 const leaseKey=g=>g.room+'\n'+g.identity;
 const checked=async req=>{
  try{
   const u=new URL(req.url,"http://proxy.invalid");
   if(!["/rtc","/rtc/v1","/rtc/validate"].includes(u.pathname)||!(req.headers.origin?allowedOrigins.has(req.headers.origin):allowNative))return null;
   const raw=u.searchParams.get("access_token")??(req.headers.authorization??"").replace(/^Bearer /i,"");
   const grant=verifyJoinToken(raw,{key,secret});
   if(!grant||leases.get(leaseKey(grant))?.revoking||!allowedJoin(grant,await readAdmission(grant)))return null;
   return {u,grant};
  }catch{return null}
 };
 const deny=(socket)=>{socket.write("HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");socket.destroy()};
 const server=http.createServer(async(req,res)=>{
  const requestOrigin=req.headers.origin;if(requestOrigin&&allowedOrigins.has(requestOrigin)){res.setHeader("Access-Control-Allow-Origin",requestOrigin);res.setHeader("Vary","Origin");res.setHeader("Access-Control-Allow-Headers","authorization");res.setHeader("Access-Control-Allow-Methods","GET,OPTIONS");}
  if(req.method==="OPTIONS"&&requestOrigin&&allowedOrigins.has(requestOrigin)){res.writeHead(204);res.end();return;}
  if(req.method!=="GET"){res.writeHead(405);res.end();return;}
  const access=await checked(req);
  if(!access||access.u.pathname!=="/rtc/validate"){res.writeHead(403);res.end();return}
  try{
   const url=new URL(access.u.pathname+access.u.search,origin);
   const response=await fetch(url,{headers:{...(req.headers.authorization?{authorization:req.headers.authorization}:{})},redirect:"error",signal:AbortSignal.timeout(5000)});
   res.writeHead(response.status,{"Content-Type":response.headers.get("content-type")??"text/plain","Cache-Control":"no-store"});res.end(Buffer.from(await response.arrayBuffer()));
  }catch{res.writeHead(502);res.end()}
 });
 server.on("upgrade",async(req,socket,head)=>{
  socket.pause();const access=await checked(req);
  if(!access||access.u.pathname==="/rtc/validate"){deny(socket);return}
  try{
   await onAdmit(access.grant);
   if(leases.get(leaseKey(access.grant))?.revoking||!allowedJoin(access.grant,await readAdmission(access.grant))){deny(socket);return}
  }catch{deny(socket);return}
  if(socket.destroyed)return;
  wss.handleUpgrade(req,socket,head,client=>{
   const target=new URL(access.u.pathname+access.u.search,origin);target.protocol=origin.protocol==="https:"?"wss:":"ws:";
   const peer=new WebSocket(target,{maxPayload:1024*1024,handshakeTimeout:5000,headers:{...(req.headers.authorization?{authorization:req.headers.authorization}:{})}});
   const entry={client,peer,grant:access.grant};active.add(entry);
   leases.set(leaseKey(access.grant),{grant:access.grant,revoking:false});
   const queue=[];let queuedBytes=0;
   const close=()=>{active.delete(entry);client.terminate();peer.terminate()};
   client.on("error",close);peer.on("error",close);client.on("close",close);peer.on("close",close);
   client.on("message",(data,binary)=>{
    if(peer.readyState===WebSocket.OPEN)peer.send(data,{binary});
    else if(peer.readyState===WebSocket.CONNECTING){queuedBytes+=data.length;if(queuedBytes>1024*1024){close();return}queue.push([data,binary])}
    else close()
   });
   peer.on("open",()=>{for(const [data,binary] of queue)peer.send(data,{binary});queue.length=0});
   peer.on("message",(data,binary)=>{if(client.readyState===WebSocket.OPEN)client.send(data,{binary})});
  });socket.resume();
 });
 // A token's expiry restricts *new* joins. Existing authorized signaling is
 // checked against live room rights, not forcibly cut every 90 seconds.
 function disconnect(room,identity){for(const e of active){if(e.grant.room===room&&(!identity||e.grant.identity===identity)){e.client.terminate();e.peer.terminate();active.delete(e)}}}
 let running=false;
 const timer=setInterval(async()=>{
  if(running)return;running=true;
  try{await Promise.all([...leases.entries()].map(async ([k,e])=>{
   let allowed=false;if(!e.revoking)try{allowed=allowedJoin({...e.grant,expiresAt:Date.now()+1000},await readAdmission(e.grant))}catch{}
   if(leases.get(k)!==e)return; // a newer confirmed connection superseded this lease
   if(!allowed){
    e.revoking=true;disconnect(e.grant.room,e.grant.identity);
    try{await onRevoke(e.grant);if(leases.get(k)===e)leases.delete(k)}
    catch{ /* retain revocation fence and retry on next tick */ }
   }
  }))}finally{running=false}
 },checkEveryMs);timer.unref();
 server.on("close",()=>{clearInterval(timer);leases.clear();for(const e of active){e.client.terminate();e.peer.terminate()}wss.close()});
 // B2 source confirmation requires an actual open signaling socket bound to the same device session.
 function sourceActive(room,identity,sessionHash){const l=leases.get(room+"\n"+identity);return !!l&&!l.revoking&&l.grant.sessionHash===sessionHash&&[...active].some(e=>e.grant.room===room&&e.grant.identity===identity&&e.grant.sessionHash===sessionHash&&e.client.readyState===WebSocket.OPEN&&e.peer.readyState===WebSocket.OPEN)}
 return {server,disconnect,sourceActive};
}
