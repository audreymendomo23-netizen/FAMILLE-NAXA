import React,{useEffect,useRef,useState}from"react";
import{Room,RoomEvent,Track}from"livekit-client";
import{presentationProfile,configurePresentationTrack}from"../../../../packages/widemeet-domain/presentation-display.mjs";
import{roomRequest}from"./room-api.mjs";
import{ConnectSource}from"./Connect";
import{identityAction}from"./session.mjs";
import{LiveListening}from"./LiveListening";
export function MediaPanel({base,session,roomId,locale,watermark,micAllowed,screenAllowed,isHost=false,presentationCeiling="high"}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const current=useRef(null),generation=useRef(0),tiles=useRef(null),sourceSize=useRef(null),qualitySerial=useRef(0);
 const preferenceKey="wm.presentation."+session.member_id;
 const [preferred,setPreferred]=useState(()=>{try{const v=localStorage.getItem(preferenceKey);return ["low","medium","high"].includes(v)?v:"medium"}catch{return "medium"}}),[network,setNetwork]=useState("high"),[measured,setMeasured]=useState(null),[applied,setApplied]=useState(null);
 const profile=presentationProfile(preferred,network,["low","medium","high"].includes(presentationCeiling)?presentationCeiling:"low");
 const [status,setStatus]=useState("idle"),[mic,setMic]=useState(false),[camera,setCamera]=useState(false),[screen,setScreen]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const [languagePrefs,setLanguagePrefs]=useState(null);const captionTouched=useRef(false);
 useEffect(()=>{let live=true;setLanguagePrefs(null);identityAction(base,session,"language-preferences").then(p=>{if(!live)return;setLanguagePrefs(p)}).catch(()=>{});return()=>{live=false}},[base,session.access_token,session.member_id]);
 const [captionLanguage,setCaptionLanguage]=useState("off"),[caption,setCaption]=useState(null),[captionState,setCaptionState]=useState("idle");
 useEffect(()=>{setCaption(null);if(status!=="connected"||captionLanguage==="off")return;let closed=false,timer,expiry;async function poll(){try{const v=await roomRequest(base,"transcription",{action:"live-captions",data:{room_id:roomId,language:captionLanguage}},session.access_token);if(closed)return;clearTimeout(expiry);if(v.status==="ready"&&Number.isFinite(v.ttl_ms)&&v.ttl_ms>0){setCaption(v);setCaptionState("ready");expiry=setTimeout(()=>setCaption(null),Math.min(v.ttl_ms,5000))}else{setCaption(null);setCaptionState(v.status)}}catch{if(!closed){setCaption(null);setCaptionState("unavailable")}}if(!closed)timer=setTimeout(poll,1500)}void poll();return()=>{closed=true;clearTimeout(timer);clearTimeout(expiry);setCaption(null)}},[status,captionLanguage,session.access_token,roomId]);
 const clear=()=>{tiles.current?.replaceChildren();setMic(false);setCamera(false);setScreen(false);sourceSize.current=null;setMeasured(null);setApplied(null);setNetwork("high")};
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
   r.on(RoomEvent.ConnectionQualityChanged,(q,p)=>{if(active()&&p===r.localParticipant)setNetwork(q==="poor"||q==="lost"?"low":q==="excellent"?"high":"medium")});
   r.on(RoomEvent.Reconnecting,()=>{if(active()){setNetwork("low");setStatus("reconnecting")}});
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
   if(source==="screen"&&screenAllowed){const next=!screen;
    await r.localParticipant.setScreenShareEnabled(next,{audio:false,contentHint:"detail"},{screenShareEncoding:{maxBitrate:profile.maxBitrate,maxFramerate:profile.fps},simulcast:false});
    if(current.current===r){if(next){const t=r.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.track;const settings=t?.mediaStreamTrack?.getSettings();if(!settings?.width||!settings?.height)throw Error("screen source unavailable");sourceSize.current={width:settings.width,height:settings.height};await configurePresentationTrack(t,profile,sourceSize.current);setApplied(profile.effective)}else{sourceSize.current=null;setApplied(null);setMeasured(null)}setScreen(next)}
   }
  }catch{if(source==="screen"&&current.current===r){await r.localParticipant.setScreenShareEnabled(false).catch(()=>leave());sourceSize.current=null;setScreen(false);setApplied(null);setMeasured(null)}setError(true)}finally{if(current.current===r)setBusy(false)}
 }
 useEffect(()=>{if(!screen||status!=="connected"||!sourceSize.current)return;const r=current.current,t=r?.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.track;if(!r||!t)return;const n=++qualitySerial.current;let dead=false;async function change(){try{await configurePresentationTrack(t,profile,sourceSize.current);if(!dead&&n===qualitySerial.current&&current.current===r)setApplied(profile.effective)}catch{if(!dead&&current.current===r){setError(true);setApplied(null);await r.localParticipant.setScreenShareEnabled(false).catch(()=>leave());setScreen(false)}}}void change();return()=>{dead=true}},[profile.effective,screen,status]);
 useEffect(()=>{if(!screen)return;let dead=false,last;const timer=setInterval(async()=>{try{const t=current.current?.localParticipant.getTrackPublication(Track.Source.ScreenShare)?.track;const stats=await t?.getRTCStatsReport();if(dead||!stats)return;let best;for(const v of stats.values())if(v.type==="outbound-rtp"&&(v.kind==="video"||v.mediaType==="video")&&(!best||(v.frameWidth??0)>(best.frameWidth??0)))best=v;if(!best)return;const kbps=last&&best.timestamp>last.timestamp&&best.bytesSent>=last.bytesSent?Math.round(8*(best.bytesSent-last.bytesSent)/(best.timestamp-last.timestamp)):null;last=best;setMeasured({width:best.frameWidth,height:best.frameHeight,fps:best.framesPerSecond,kbps})}catch{if(!dead)setMeasured(null)}},2000);return()=>{dead=true;clearInterval(timer)}},[screen]);
 return <section aria-label={tr("Appel audio et vidéo","Audio and video call")} style={{display:"grid",gap:8}}>
 <p role="status">{{idle:tr("Prêt à rejoindre","Ready to join"),connecting:tr("Connexion…","Connecting…"),connected:tr("Connecté à la réunion","Connected to meeting"),reconnecting:tr("Reconnexion…","Reconnecting…"),disconnected:tr("Connexion terminée","Connection ended")}[status]}</p>
 <div style={{position:"relative"}}><div ref={tiles} style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(min(100%,180px),1fr))",gap:8}}/>{status==="connected"&&watermark&&<div aria-hidden="true" style={{position:"absolute",inset:0,pointerEvents:"none",display:"grid",alignContent:"space-around",justifyItems:"center",overflow:"hidden"}}>{[0,1,2].map(i=><span key={i} style={{color:"white",textShadow:"0 1px 3px black",opacity:0.65,fontSize:"0.75rem",transform:"rotate(-12deg)",overflowWrap:"anywhere",textAlign:"center"}}>{watermark}</span>)}</div>}</div>
 {status==="connected"&&<section aria-label={tr("Sous-titres en direct","Live captions")}>{!captionTouched.current&&languagePrefs?.subtitles&&<button type="button" onClick={()=>{captionTouched.current=true;setCaptionLanguage(languagePrefs.subtitles)}}>{tr("Utiliser ma langue de sous-titres","Use my preferred subtitle language")}</button>}<label>{tr("Sous-titres (audio consenti)","Captions (consented audio)")}<select value={captionLanguage} onChange={e=>{setCaption(null);setCaptionState("idle");captionTouched.current=true;setCaptionLanguage(e.target.value)}}>{[["off",tr("Désactivés","Off")],["original",tr("Original","Original")],["fr","Français"],["en","English"],["ff","Fulfulde"],["es","Español"],["it","Italiano"],["zh","中文"],["wes","Cameroon Pidgin English"],["ewo","Ewondo"],["dua","Duala"],["bas","Basaa"],["bbj","Ghomala’"],["bum","Bulu"],["bax","Bamoun"],["ybb","Yemba"],["mhk","Mungaka"],["ar","العربية"],["pt","Português"],["de","Deutsch"]].map(([code,name])=><option key={code} value={code}>{name}</option>)}</select></label>{captionLanguage!=="off"&&<p role="status" aria-live="polite">{caption?caption.text||tr("Silence","Silence"):captionState==="unavailable"?tr("Sous-titres indisponibles ou consentement absent.","Captions unavailable or consent missing."):tr("En attente de parole enregistrée avec consentement.","Waiting for consented recorded speech.")}</p>}{caption?.fallback&&<p>{tr("Traduction indisponible : langue originale.","Translation unavailable: original language.")}</p>}{caption?.uncertain&&<p>{tr("Texte à vérifier.","Text needs review.")}</p>}{caption&&caption.language!==caption.source_language&&<p>{caption.original}</p>}<LiveListening key={session.member_id+":"+roomId} base={base} session={session} roomId={roomId} locale={locale} preferences={languagePrefs}/></section>}
 {status==="connected"?<div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
 <button disabled={busy||!micAllowed} onClick={()=>toggle("mic")}>{mic?tr("Couper mon micro","Mute my microphone"):tr("Activer mon micro","Enable my microphone")}</button>
 <button disabled={busy} onClick={()=>toggle("camera")}>{camera?tr("Couper ma caméra","Disable my camera"):tr("Activer ma caméra","Enable my camera")}</button>
 <label>{tr("Qualité de présentation","Presentation quality")}<select aria-label={tr("Qualité de présentation","Presentation quality")} value={preferred} disabled={!screenAllowed||busy} onChange={e=>{setPreferred(e.target.value);try{localStorage.setItem(preferenceKey,e.target.value)}catch{}}}>{["low","medium","high"].map(x=><option key={x} value={x}>{x==="low"?"Low Quality":x==="medium"?"Medium Quality":"High Quality"}</option>)}</select></label><p>{tr("Qualité adaptée : ","Adapted quality: ")}{({low:"Low Quality",medium:"Medium Quality",high:"High Quality"}[profile.effective]??tr("Indisponible","Unavailable"))}{screen&&applied?` · ${tr("Qualité appliquée","Applied quality")}: ${({low:"Low Quality",medium:"Medium Quality",high:"High Quality"}[applied]??tr("Indisponible","Unavailable"))}`:""}{screen&&measured?.width?` · ${tr("Mesurée","Measured")}: ${measured.width}×${measured.height}${measured.fps?` · ${measured.fps} fps`:""}${measured.kbps!=null?` · ${measured.kbps} kbit/s`:""}`:screen?` · ${tr("Qualité effective indisponible","Actual quality unavailable")}`:""}</p>
 <button disabled={busy||!screenAllowed} onClick={()=>toggle("screen")}>{screen?tr("Arrêter le partage","Stop sharing"):tr("Partager mon écran","Share my screen")}</button>
 <button onClick={()=>current.current?.startAudio().catch(()=>setError(true))}>{tr("Activer le son","Enable sound")}</button>
 <button onClick={leave}>{tr("Quitter l’appel","Leave call")}</button>
 </div>:status==="reconnecting"||status==="connecting"?<button onClick={leave}>{tr("Annuler la connexion","Cancel connection")}</button>:<button disabled={busy} onClick={join}>{tr("Rejoindre l’appel","Join call")}</button>}
 {status==="connected"&&import.meta.env.VITE_WIDEMEET_CONNECT_ENABLED==="true"&&<ConnectSource base={base} session={session} locale={locale} roomId={roomId} isHost={isHost}/>}
 {error&&<p role="alert">{tr("Connexion ou périphérique indisponible. Réessayez.","Connection or device unavailable. Try again.")}</p>}
 </section>
}
