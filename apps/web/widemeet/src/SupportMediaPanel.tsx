import React,{useEffect,useRef,useState}from"react";
import{Room,RoomEvent,Track}from"livekit-client";
import{identityAction}from"./session.mjs";
// Support only; no meeting identifiers, camera, system audio or data publishing.
export function SupportMediaPanel({base,session,ticket,locale}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [call,C]=useState(null),[busy,B]=useState(false),[error,E]=useState(false),[connected,J]=useState(false),[mic,M]=useState(false),[screen,S]=useState(false);
 const room=useRef(null),callRef=useRef(null),live=useRef(false),locked=useRef(false),epoch=useRef(0),tiles=useRef(null),requestId=useRef(null);
 const req=(action,data={})=>identityAction(base,session,"support-"+action,{ticket_id:ticket.id,...data});
 const setCall=v=>{callRef.current=v;if(live.current)C(v)};
 async function disconnect(){epoch.current++;const r=room.current;room.current=null;tiles.current?.replaceChildren();if(live.current){J(false);M(false);S(false)}if(r)await r.disconnect().catch(()=>{})}
 async function work(fn){if(locked.current)return;locked.current=true;B(true);E(false);try{await fn()}catch{await disconnect();if(live.current)E(true)}finally{locked.current=false;if(live.current)B(false)}}
 const command=async(action,data={})=>{const v=await req(action,{call_id:callRef.current?.id,...data});if(!live.current)return;setCall(v);if(v.state!=="active"&&room.current)await disconnect();return v};
 useEffect(()=>{live.current=true;let disposed=false;const poll=async()=>{if(disposed||locked.current)return;locked.current=true;B(true);try{let v=await req("call-read");if(disposed)return;if(v.state==="active")v=await req("call-heartbeat",{call_id:v.id});if(disposed)return;if(room.current&&(v.state!=="active"||v.id!==callRef.current?.id))await disconnect();if(room.current&&callRef.current?.screen_id&&!v.screen_id)await disconnect();setCall(v)}catch{if(!disposed){await disconnect();setCall(null);E(true)}}finally{locked.current=false;if(!disposed)B(false)}};void poll();const timer=setInterval(poll,3000);return()=>{disposed=true;live.current=false;clearInterval(timer);void disconnect()}},[ticket.id,session.device_id,session.access_token]);
 async function join(){if(room.current||callRef.current?.state!=="active")return;const serial=++epoch.current;
 const grant=await req("call-grant",{call_id:callRef.current.id});if(!live.current||serial!==epoch.current)return;
 const u=new URL(grant.url);if(u.protocol!=="wss:"||u.username||u.password||u.pathname!=="/"||u.search||u.hash||!grant.token||grant.expires_at<=Date.now())throw Error("invalid grant");
 const r=new Room({adaptiveStream:true,dynacast:true});room.current=r;
 const active=()=>live.current&&room.current===r&&serial===epoch.current;
 r.on(RoomEvent.TrackSubscribed,t=>{if(!active())return;if(t.source!==Track.Source.Microphone&&t.source!==Track.Source.ScreenShare)return;const el=t.attach();el.autoplay=true;el.playsInline=true;if(t.kind==="video")el.style.width="100%";tiles.current?.appendChild(el)});
 r.on(RoomEvent.TrackUnsubscribed,t=>{for(const el of t.detach())el.remove()});
 r.on(RoomEvent.LocalTrackUnpublished,p=>{if(active()&&p.source===Track.Source.ScreenShare){S(false);const v=callRef.current;if(v?.screen_id&&!locked.current)void work(async()=>{await command("screen-stop",{share_id:v.screen_id});await disconnect()})}});
 r.on(RoomEvent.Disconnected,()=>{if(active()){room.current=null;tiles.current?.replaceChildren();J(false);M(false);S(false)}});
 await r.connect(u.origin,grant.token);if(!active()){await r.disconnect();return}J(true);
 }
 async function capture(){const r=room.current,v=callRef.current;if(!r||v?.screen_state!=="consented"||!v.screen_id)return;try{await r.localParticipant.setScreenShareEnabled(true,{audio:false});if(!live.current||room.current!==r){await r.localParticipant.setScreenShareEnabled(false);return}await command("screen-start",{share_id:v.screen_id});S(true)}catch(e){await r.localParticipant.setScreenShareEnabled(false).catch(()=>{});await command("screen-stop",{share_id:v.screen_id}).catch(()=>{});throw e}}
 const owner=ticket.viewer==="requester";
 return <section className="card"><h3>{tr("Appel d’assistance privé","Private support call")}</h3><p>{tr("Seul votre agent attribué peut rejoindre. Aucun accès à vos réunions. Le micro et l’écran restent désactivés sans votre action.","Only your assigned agent can join. No access to meetings. Microphone and screen stay off until you act.")}</p>
 {call?.state==="idle"&&owner&&<button disabled={busy} onClick={()=>work(async()=>{requestId.current??=crypto.randomUUID();await command("call-request",{call_id:requestId.current});requestId.current=null})}>{tr("Demander un appel audio","Request audio call")}</button>}
 {call?.state==="requested"&&<><p role="status">{tr("En attente de l’agent","Waiting for agent")}</p>{!owner&&<><button disabled={busy} onClick={()=>work(()=>command("call-accept"))}>{tr("Accepter","Accept")}</button><button disabled={busy} onClick={()=>work(()=>command("call-decline"))}>{tr("Refuser","Decline")}</button></>}</>}
 {call?.state==="active"&&<>{!connected?<button disabled={busy} onClick={()=>work(join)}>{tr("Rejoindre l’assistance","Join support call")}</button>:<><button disabled={busy} onClick={()=>work(async()=>{const r=room.current;if(!r)return;await r.localParticipant.setMicrophoneEnabled(!mic);if(room.current===r)M(!mic)})}>{mic?tr("Couper le micro","Mute microphone"):tr("Activer le micro","Enable microphone")}</button><button onClick={()=>room.current?.startAudio().catch(()=>E(true))}>{tr("Activer le son","Enable sound")}</button></>}
 {owner&&!call.screen_id&&<button disabled={busy} onClick={()=>{if(confirm(tr("Autoriser votre écran à être partagé uniquement avec cet agent ?","Allow your screen to be shared only with this agent?")))void work(async()=>{await command("screen-consent",{share_id:crypto.randomUUID()});await disconnect()})}}>{tr("Autoriser le partage d’écran","Authorize screen sharing")}</button>}
 {owner&&connected&&call.screen_state==="consented"&&<button disabled={busy} onClick={()=>work(capture)}>{tr("Choisir un écran à partager","Choose screen to share")}</button>}
 {call.screen_id&&<button disabled={busy} onClick={()=>work(async()=>{await room.current?.localParticipant.setScreenShareEnabled(false).catch(()=>{});await command("screen-stop",{share_id:call.screen_id});await disconnect()})}>{tr("Retirer le consentement / arrêter","Withdraw consent / stop")}</button>}
 {screen&&<p role="status">{tr("Votre écran est partagé","Your screen is shared")}</p>}
 </>}
 {["requested","active"].includes(call?.state)&&<button disabled={busy} onClick={()=>work(async()=>{await command("call-end");await disconnect()})}>{tr("Terminer l’assistance","End support call")}</button>}
 <div ref={tiles}/>{error&&<p role="alert">{tr("Action non confirmée. Réessayez.","Action unconfirmed. Retry.")}</p>}</section>
}
