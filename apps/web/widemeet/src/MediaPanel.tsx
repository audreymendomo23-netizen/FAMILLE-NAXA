import React,{useEffect,useRef,useState}from"react";
import{Room,RoomEvent,Track}from"livekit-client";
import{roomRequest}from"./room-api.mjs";
export function MediaPanel({base,session,roomId,locale,watermark,micAllowed,screenAllowed}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const current=useRef(null),generation=useRef(0),tiles=useRef(null);
 const [status,setStatus]=useState("idle"),[mic,setMic]=useState(false),[camera,setCamera]=useState(false),[screen,setScreen]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const [captionLanguage,setCaptionLanguage]=useState("off"),[caption,setCaption]=useState(null),[captionState,setCaptionState]=useState("idle");
 useEffect(()=>{setCaption(null);if(status!=="connected"||captionLanguage==="off")return;let closed=false,timer,expiry;async function poll(){try{const v=await roomRequest(base,"transcription",{action:"live-captions",data:{room_id:roomId,language:captionLanguage}},session.access_token);if(closed)return;clearTimeout(expiry);if(v.status==="ready"&&Number.isFinite(v.ttl_ms)&&v.ttl_ms>0){setCaption(v);setCaptionState("ready");expiry=setTimeout(()=>setCaption(null),Math.min(v.ttl_ms,5000))}else{setCaption(null);setCaptionState(v.status)}}catch{if(!closed){setCaption(null);setCaptionState("unavailable")}}if(!closed)timer=setTimeout(poll,1500)}void poll();return()=>{closed=true;clearTimeout(timer);clearTimeout(expiry);setCaption(null)}},[status,captionLanguage,session.access_token,roomId]);
 const clear=()=>{tiles.current?.replaceChildren();setMic(false);setCamera(false);setScreen(false)};
 async function leave(){
  generation.current++;const r=current.current;current.current=null;clear();setStatus("idle");setBusy(false);
  if(r)await r.disconnect().catch(()=>{});
 }
 useEffect(()=>()=>{generation.current++;const r=current.current;current.current=null;if(r)void r.disconnect().catch(()=>{})},[session.device_id,roomId]);
 useEffect(()=>{const r=current.current;if(!r)return;if(!micAllowed&&mic){void r.localParticipant.setMicrophoneEnabled(false).catch(()=>leave());setMic(false)}if(!screenAllowed&&screen){void r.localParticipant.setScreenShareEnabled(false).catch(()=>leave());setScreen(false)}},[micAllowed,screenAllowed,mic,screen]);
 async function join(){
  if(busy||current.current)return;
  const serial=++generation.current;setBusy(true);setError(false);setStatus("connecting");
  let r;
  try{
   const grant=await roomRequest(base,"media-grant",{room_id:roomId},session.access_token);
   if(generation.current!==serial)return;
   const u=new URL(grant.url);
   if(u.protocol!=="wss:"||u.username||u.password||u.pathname!=="/"||u.search||u.hash||typeof grant.token!=="string"||!Number.isSafeInteger(grant.expires_at)||grant.expires_at<=Date.now())throw Error("invalid grant");
   r=new Room({adaptiveStream:true,dynacast:true});current.current=r;
   const active=()=>current.current===r&&generation.current===serial;
   const remove=t=>{for(const el of t.detach())el.remove()};
   const attach=t=>{if(!active())return;const el=t.attach();el.autoplay=true;el.playsInline=true;if(t.kind==="video"){el.style.width="100%";el.style.maxHeight="300px";el.style.objectFit="contain"}tiles.current?.appendChild(el)};
   r.on(RoomEvent.TrackSubscribed,attach);r.on(RoomEvent.TrackUnsubscribed,remove);
   r.on(RoomEvent.LocalTrackPublished,p=>{if(p.track?.kind==="video"){const el=p.track.attach();el.muted=true;el.playsInline=true;el.style.width="100%";el.style.maxHeight="240px";tiles.current?.appendChild(el)}});
   r.on(RoomEvent.LocalTrackUnpublished,p=>{if(p.track)remove(p.track);if(p.source===Track.Source.ScreenShare)setScreen(false)});
   r.on(RoomEvent.Reconnecting,()=>{if(active())setStatus("reconnecting")});
   r.on(RoomEvent.Reconnected,()=>{if(active())setStatus("connected")});
   r.on(RoomEvent.Disconnected,()=>{if(active()){current.current=null;clear();setStatus("disconnected");setBusy(false)}});
   await r.connect(u.origin,grant.token);
   if(!active()){await r.disconnect();return}
   setStatus("connected"); // no automatic microphone or camera activation
  }catch{if(r)await r.disconnect().catch(()=>{});if(generation.current===serial){current.current=null;clear();setError(true);setStatus("idle")}}
  finally{if(generation.current===serial)setBusy(false)}
 }
 async function toggle(source){
  const r=current.current;if(!r||busy||status!=="connected")return;
  setBusy(true);setError(false);
  try{
   if(source==="mic"&&micAllowed){const next=!mic;await r.localParticipant.setMicrophoneEnabled(next);if(current.current===r)setMic(next)}
   if(source==="camera"){const next=!camera;await r.localParticipant.setCameraEnabled(next);if(current.current===r)setCamera(next)}
   if(source==="screen"&&screenAllowed){const next=!screen;await r.localParticipant.setScreenShareEnabled(next,{audio:false});if(current.current===r)setScreen(next)}
  }catch{setError(true)}finally{if(current.current===r)setBusy(false)}
 }
 return <section aria-label={tr("Appel audio et vidéo","Audio and video call")} style={{display:"grid",gap:8}}>
 <p role="status">{{idle:tr("Prêt à rejoindre","Ready to join"),connecting:tr("Connexion…","Connecting…"),connected:tr("Connecté à la réunion","Connected to meeting"),reconnecting:tr("Reconnexion…","Reconnecting…"),disconnected:tr("Connexion terminée","Connection ended")}[status]}</p>
 <div style={{position:"relative"}}><div ref={tiles} style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(min(100%,180px),1fr))",gap:8}}/>{status==="connected"&&watermark&&<div aria-hidden="true" style={{position:"absolute",inset:0,pointerEvents:"none",display:"grid",alignContent:"space-around",justifyItems:"center",overflow:"hidden"}}>{[0,1,2].map(i=><span key={i} style={{color:"white",textShadow:"0 1px 3px black",opacity:0.65,fontSize:"0.75rem",transform:"rotate(-12deg)",overflowWrap:"anywhere",textAlign:"center"}}>{watermark}</span>)}</div>}</div>
 {status==="connected"&&<section aria-label={tr("Sous-titres en direct","Live captions")}><label>{tr("Sous-titres (audio consenti)","Captions (consented audio)")}<select value={captionLanguage} onChange={e=>{setCaption(null);setCaptionState("idle");setCaptionLanguage(e.target.value)}}>{[["off",tr("Désactivés","Off")],["original",tr("Original","Original")],["fr","Français"],["en","English"],["ff","Fulfulde"],["es","Español"],["it","Italiano"],["zh","中文"]].map(([code,name])=><option key={code} value={code}>{name}</option>)}</select></label>{captionLanguage!=="off"&&<p role="status" aria-live="polite">{caption?caption.text||tr("Silence","Silence"):captionState==="unavailable"?tr("Sous-titres indisponibles ou consentement absent.","Captions unavailable or consent missing."):tr("En attente de parole enregistrée avec consentement.","Waiting for consented recorded speech.")}</p>}{caption?.fallback&&<p>{tr("Traduction indisponible : langue originale.","Translation unavailable: original language.")}</p>}{caption?.uncertain&&<p>{tr("Texte à vérifier.","Text needs review.")}</p>}{caption&&caption.language!==caption.source_language&&<p>{caption.original}</p>}</section>}
 {status==="connected"?<div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
 <button disabled={busy||!micAllowed} onClick={()=>toggle("mic")}>{mic?tr("Couper mon micro","Mute my microphone"):tr("Activer mon micro","Enable my microphone")}</button>
 <button disabled={busy} onClick={()=>toggle("camera")}>{camera?tr("Couper ma caméra","Disable my camera"):tr("Activer ma caméra","Enable my camera")}</button>
 <button disabled={busy||!screenAllowed} onClick={()=>toggle("screen")}>{screen?tr("Arrêter le partage","Stop sharing"):tr("Partager mon écran","Share my screen")}</button>
 <button onClick={()=>current.current?.startAudio().catch(()=>setError(true))}>{tr("Activer le son","Enable sound")}</button>
 <button onClick={leave}>{tr("Quitter l’appel","Leave call")}</button>
 </div>:status==="reconnecting"||status==="connecting"?<button onClick={leave}>{tr("Annuler la connexion","Cancel connection")}</button>:<button disabled={busy} onClick={join}>{tr("Rejoindre l’appel","Join call")}</button>}
 {error&&<p role="alert">{tr("Connexion ou périphérique indisponible. Réessayez.","Connection or device unavailable. Try again.")}</p>}
 </section>
}
