import React,{useEffect,useRef,useState}from"react";
import{Room,RoomEvent}from"livekit-client";
import{QRCodeSVG}from"qrcode.react";
import{roomRequest}from"./room-api.mjs";
const newCode=()=>Array.from(crypto.getRandomValues(new Uint8Array(32)),x=>x.toString(16).padStart(2,"0")).join("");
const validCode=s=>/^[a-f0-9]{64}$/.test(s);
function request(base,session,action,data){return roomRequest(base,"connect",{action,data},session.access_token)}
// Source is mounted only for an actual joined media call. Host policy is opt-in.
export function ConnectSource({base,session,locale,roomId,isHost}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [state,S]=useState(null),[code,C]=useState(""),[preview,P]=useState(null),[busy,B]=useState(false),[error,E]=useState(false);
 const running=useRef(false),epoch=useRef(0);
 const req=(a,d={})=>request(base,session,a,{room_id:roomId,...d});
 async function refresh(){S(await req("source-status"))}
 async function work(fn){if(running.current)return;running.current=true;epoch.current++;B(true);E(false);try{await fn()}catch{S(null);P(null);E(true)}finally{running.current=false;B(false)}}
 useEffect(()=>{let dead=false,poll=false;async function tick(){if(dead||poll||running.current)return;poll=true;const n=epoch.current;try{const v=await req("source-status");if(!dead&&n===epoch.current&&!running.current)S(v)}catch{if(!dead&&n===epoch.current){S(null);P(null);E(true)}}finally{poll=false}}void tick();const t=setInterval(tick,4000);return()=>{dead=true;clearInterval(t);void req("source-stop").catch(()=>{})}},[roomId,session.device_id,session.access_token]);
 return <section className="card" aria-label="WideMeet Connect"><h3>WideMeet Connect</h3>
 {error&&<p role="alert">{tr("Affichage non confirmé ou indisponible.","Display unconfirmed or unavailable.")}</p>}
 {isHost&&<button disabled={busy||!state} onClick={()=>work(async()=>{await req("policy",{enabled:!state.enabled});await refresh()})}>{state?.enabled?tr("Interdire l’affichage distant","Disallow remote display"):tr("Autoriser l’affichage distant","Allow remote display")}</button>}
 {state?.receiver_name?<><p>{tr("Récepteur autorisé : ","Authorized display: ")}{state.receiver_name}</p><button disabled={busy} onClick={()=>work(async()=>{await req("source-stop");await refresh()})}>{tr("Arrêter l’affichage","Stop display")}</button></>:state?.enabled?<><label>{tr("Code de l’écran","Display code")}<input value={code} autoComplete="off" maxLength={75} onChange={e=>{C(e.target.value.trim().toLowerCase().replace(/^wm-connect:/,""));P(null)}} disabled={busy}/></label><button disabled={busy||!validCode(code)} onClick={()=>work(async()=>P(await req("preview",{code})))}>{tr("Vérifier l’écran","Check display")}</button>{preview&&<><p>{tr("Confirmer cet écran : ","Confirm this display: ")}{preview.receiver_name}</p><button disabled={busy} onClick={()=>work(async()=>{await req("confirm",{code,receiver_name:preview.receiver_name});C("");P(null);await refresh()})}>{tr("Confirmer l’appairage","Confirm pairing")}</button></>}</>:<p>{tr("L’organisateur doit autoriser l’affichage distant.","The organizer must allow remote display.")}</p>}
 </section>
}
// Separate authenticated browser session: deliberately no mic, camera, chat or room controls.
export function ConnectReceiver({base,session,locale,onExit}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [name,N]=useState(""),[code,C]=useState(""),[status,S]=useState("idle"),[error,E]=useState(false),[identity,I]=useState(""),[deadline,D]=useState(0),[seconds,SEC]=useState(60);
 const tiles=useRef(null),room=useRef(null),serial=useRef(0),attempt=useRef(""),busy=useRef(false);
 const req=(a,d)=>request(base,session,a,d);
 useEffect(()=>{if(status!=="waiting"||!deadline)return;const tick=()=>SEC(Math.max(0,Math.ceil((deadline-performance.now())/1000)));tick();const t=setInterval(tick,250);return()=>clearInterval(t)},[status,deadline]);
 const clear=()=>{tiles.current?.replaceChildren();I("")};
 async function stop(notify=true){serial.current++;const c=attempt.current;attempt.current="";const r=room.current;room.current=null;clear();C("");D(0);SEC(60);S("idle");if(r)await r.disconnect().catch(()=>{});if(notify&&c)await req("receiver-stop",{code:c}).catch(()=>{})}
 useEffect(()=>()=>{serial.current++;const c=attempt.current;attempt.current="";const r=room.current;room.current=null;if(r)void r.disconnect().catch(()=>{});if(c)void req("receiver-stop",{code:c}).catch(()=>{})},[session.device_id,session.access_token]);
 async function offer(){if(busy.current||!name.trim())return;busy.current=true;E(false);const c=newCode();attempt.current=c;const n=++serial.current;S("offering");try{await req("offer",{code:c,name:name.trim()});if(n===serial.current){C(c);D(performance.now()+60000);SEC(60);S("waiting")}}catch{if(n===serial.current){await stop();E(true)}}finally{busy.current=false}}
 useEffect(()=>{if(!code)return;let dead=false,poll=false;const n=serial.current;async function tick(){if(dead||poll||n!==serial.current)return;poll=true;try{
 const g=await req("receive",{code});if(dead||n!==serial.current)return;if(g.pending===true)return;
 if(!Number.isSafeInteger(g.expires_at)||g.expires_at<=Date.now()||typeof g.identity!=="string"||!g.identity.startsWith("wm-display-")||typeof g.token!=="string")throw Error("invalid grant");
 if(room.current)return;const u=new URL(g.url);if(u.protocol!=="wss:"||u.username||u.password||u.pathname!=="/"||u.search||u.hash)throw Error("invalid endpoint");
 // Read-only receiver: keep subscriptions active even while the first video tile is not visible.
 const r=new Room({adaptiveStream:false,dynacast:false});room.current=r;
 r.on(RoomEvent.TrackSubscribed,t=>{if(room.current!==r||n!==serial.current)return;const el=t.attach();el.autoplay=true;el.muted=true;el.playsInline=true;if(t.kind==="video"){el.style.width="100%";el.style.maxHeight="75vh";el.style.objectFit="contain"}tiles.current?.appendChild(el)});
 r.on(RoomEvent.TrackUnsubscribed,t=>{for(const el of t.detach())el.remove()});
 r.on(RoomEvent.Disconnected,()=>{if(room.current===r&&n===serial.current){void stop();E(true)}});
 r.on(RoomEvent.Reconnecting,()=>{if(room.current===r&&n===serial.current){void stop();E(true)}});
 await r.connect(u.origin,g.token);if(n!==serial.current||dead){await r.disconnect();return}I(g.identity);S("connected");C(code);
 }catch(e){if(!dead&&n===serial.current){const kind=String(e?.name??"");const msg=String(e?.message??"");const category=/ICE|peer connection|negotiat/i.test(msg)?"peer":/timed? out|timeout/i.test(msg)?"timeout":/signal|websocket/i.test(msg)?"signaling":"other";console.warn("WM_CONNECT_RECEIVER_FAILURE",["ConnectionError","Error","DOMException"].includes(kind)?kind:"Other",category);await stop();E(true)}}finally{poll=false}}
 void tick();const t=setInterval(tick,5000);return()=>{dead=true;clearInterval(t)}},[code,session.access_token]);
 return <section className="card" aria-label={tr("Récepteur WideMeet","WideMeet receiver")}><button onClick={()=>{void stop();onExit?.()}}>{tr("Quitter le récepteur","Exit receiver")}</button><h2>{tr("Écran distant (lecture seule)","Remote display (view only)")}</h2><p>{tr("Connectez-vous sur un autre appareil avec le même compte. L’écran est muet : le son reste sur la source.","Sign in on another device with the same account. The display is muted: sound stays on the source.")}</p>
 {error&&<p role="alert">{tr("Appairage ou affichage terminé/non confirmé. Créez un nouveau code.","Pairing or display ended/unconfirmed. Create a new code.")}</p>}
 {status==="idle"?<><label>{tr("Nom de l’écran","Display name")}<input value={name} maxLength={80} onChange={e=>N(e.target.value)}/></label><button disabled={!name.trim()} onClick={offer}>{tr("Créer un code","Create code")}</button></>:status==="offering"?<p role="status">{tr("Création…","Creating…")}</p>:<>{status==="waiting"&&<><p>{tr("Code valable 60 secondes, à saisir sur la source.","Code valid for 60 seconds; enter it on the source.")}</p>{seconds>0?<><p>{tr("Temps restant indicatif : ","Estimated time remaining: ")}{seconds} s</p><QRCodeSVG value={"wm-connect:"+code} size={220} marginSize={4} level="M" role="img" aria-label={tr("QR d’appairage Connect","Connect pairing QR")}/><output style={{overflowWrap:"anywhere"}}>{code}</output><button onClick={()=>void navigator.clipboard.writeText(code).catch(()=>E(true))}>{tr("Copier le code","Copy code")}</button></>:<p>{tr("Code masqué après le délai indicatif. Le serveur confirme ou refuse l’appairage.","Code hidden after estimated expiry. The server confirms or denies pairing.")}</p>}</>}<p role="status">{status==="connected"?tr("Affichage connecté","Display connected"):tr("En attente de confirmation","Waiting for confirmation")}</p><button onClick={()=>void stop()}>{tr("Arrêter","Stop")}</button></>}
 <div style={{position:"relative"}}><div ref={tiles}/>{identity&&<div aria-hidden="true" style={{position:"absolute",inset:0,pointerEvents:"none",display:"grid",placeItems:"center",color:"white",textShadow:"0 1px 4px black",opacity:.7}}>{session.display_name??session.member_id} · {name}</div>}</div></section>
}
