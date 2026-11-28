import React,{useEffect,useRef,useState}from"react";
import{roomRequest}from"./room-api.mjs";
import{liveSpeechWindow,listeningRate}from"./live-speech.mjs";
export function LiveListening({base,session,roomId,locale,preferences}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [enabled,E]=useState(false),[target,T]=useState("en"),[state,S]=useState("idle");
 const chosen=useRef(false),spoken=useRef(new Set());
 useEffect(()=>{if(!chosen.current&&["original","en","fr","ff","es","it","zh","wes","ewo","dua","bas","bbj","bum","bax","ybb","mhk","ar","pt","de"].includes(preferences?.listening))T(preferences.listening)},[preferences]);
 useEffect(()=>{
  if(!enabled)return;
  if(target!=="en"){S("unavailable");return;}
  const synth=window.speechSynthesis;let closed=false,timer,expiry,active=null;
  function stop(){clearTimeout(expiry);if(active){synth?.cancel();active=null}}
  async function poll(){
   const began=performance.now();
   try{
    const v=await roomRequest(base,"transcription",{action:"live-captions",data:{room_id:roomId,language:target}},session.access_token);
    if(closed)return;
    const item=liveSpeechWindow(v,target,Number(v.ttl_ms)-(performance.now()-began));
    if(!item){stop();S(v.status==="waiting"?"waiting":"unavailable")}
    else if(!synth){stop();S("voice")}
    else if(!spoken.current.has(item.key)){
     stop();const voice=synth.getVoices().find(x=>x.localService&&x.lang.toLowerCase().split("-")[0]===target);
     if(!voice){S("voice")}else{
      const u=new SpeechSynthesisUtterance(item.text);u.voice=voice;u.lang=voice.lang;u.rate=listeningRate(preferences?.rate);
      active=u;spoken.current.add(item.key);if(spoken.current.size>256)spoken.current.delete(spoken.current.values().next().value);
      u.onend=()=>{if(!closed&&active===u){active=null;S("ready")}};
      u.onerror=()=>{if(!closed&&active===u){active=null;S("voice")}};
      synth.speak(u);S("playing");expiry=setTimeout(()=>{stop();if(!closed)S("waiting")},item.ttl);
     }
    }
   }catch{if(!closed){stop();S("unavailable")}}
   if(!closed)timer=setTimeout(poll,1000);
  }
  void poll();return()=>{closed=true;clearTimeout(timer);stop()};
 },[enabled,target,base,session.access_token,roomId,preferences?.rate]);
 return <section aria-label={tr("Écoute traduite","Translated listening")}><h3>{tr("Écoute traduite","Translated listening")}</h3><p>{tr("Écoutez les passages traduits du français vers l’anglais lorsque l’enregistrement est autorisé. La piste originale reste audible. Utilisez un casque pour éviter les échos.","Listen to French speech translated into English when recording is permitted. Original audio remains audible. Use headphones to avoid echo.")}</p><label>{tr("Langue d’écoute","Listening language")}<select value={target} onChange={e=>{chosen.current=true;T(e.target.value);S("idle")}}>{[["original",tr("Piste originale","Original audio")],["en","English"],["fr","Français"],["ff","Fulfulde"],["es","Español"],["it","Italiano"],["zh","中文"],["wes","Cameroon Pidgin English"],["ewo","Ewondo"],["dua","Duala"],["bas","Basaa"],["bbj","Ghomala’"],["bum","Bulu"],["bax","Bamoun"],["ybb","Yemba"],["mhk","Mungaka"],["ar","العربية"],["pt","Português"],["de","Deutsch"]].map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label><button type="button" onClick={()=>{E(v=>!v);S("idle")}}>{enabled?tr("Arrêter l’écoute traduite","Stop translated listening"):tr("Activer l’écoute traduite","Enable translated listening")}</button>{enabled&&<p role="status">{state==="playing"?tr("Écoute en cours…","Playing…"):state==="voice"?tr("Voix indisponible sur cet appareil.","Voice unavailable on this device."):state==="unavailable"||target!=="en"?tr("Traduction indisponible. Écoutez la piste originale.","Translation unavailable. Listen to original audio."):tr("En attente d’un passage traduit.","Waiting for translated speech.")}</p>}</section>
}
