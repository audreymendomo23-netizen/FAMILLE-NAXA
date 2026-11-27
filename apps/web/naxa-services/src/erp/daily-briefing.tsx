import React,{useEffect,useRef,useState} from "react";
import {privateRequest} from "./private-request";
import type {WebAuthAccount} from "../auth/session";
import {rosterApiOrigin} from "./staff-roster";
export type Report={day:string;generated_at:string;scope:"site"|"personal";finance:{revenue_xaf:number;confirmed_sales_count:number;uncosted_sales_count:number}|null;appointments:{scheduled_count:number;completed_count:number};personal_clock_events:{event_count:number}|null;coverage:string};
type Lang="fr"|"en"|"ff-CM"|"es"|"it"|"zh-CN";
const languages:Record<Lang,string>={fr:"Français",en:"English","ff-CM":"Fulfulde",es:"Español",it:"Italiano","zh-CN":"中文"};
const copy:Record<Lang,{title:string;intro:string;appointments:string;completed:string;finance:string;sales:string;clocks:string;missing:string;play:string;stop:string;unavailable:string;load:string}> = {
 fr:{title:"Mon bilan",intro:"Voici votre bilan partiel, établi à partir des données confirmées.",appointments:"Rendez-vous",completed:"terminés",finance:"Chiffre d’affaires en francs CFA",sales:"ventes confirmées",clocks:"Pointages personnels",missing:"Les autres indicateurs ne sont pas disponibles dans ce bilan.",play:"Écouter mon bilan",stop:"Arrêter",unavailable:"Voix locale ou données indisponibles.",load:"Actualiser"},
 en:{title:"My report",intro:"Here is your partial report, based on confirmed records.",appointments:"Appointments",completed:"completed",finance:"Revenue in CFA francs",sales:"confirmed sales",clocks:"Personal clock events",missing:"Other indicators are not available in this report.",play:"Listen to my report",stop:"Stop",unavailable:"Local voice or data unavailable.",load:"Refresh"},
 "ff-CM":{title:"Jaŋtol am",intro:"Ɗoo ko jaŋtol maa ummoraade e humpito tabbitinaango.",appointments:"Kawrital",completed:"timmuɗe",finance:"Ceede soodugol CFA",sales:"soodugol tabbitinaaɗo",clocks:"Winndanɗe naatugol",missing:"Humpito goɗɗo heɓotaako e jaŋtol ngol.",play:"Heɗo jaŋtol am",stop:"Dartin",unavailable:"Daande walla humpito heɓotaako.",load:"Hesɗitin"},
 es:{title:"Mi informe",intro:"Este es tu informe parcial basado en datos confirmados.",appointments:"Citas",completed:"completadas",finance:"Ingresos en francos CFA",sales:"ventas confirmadas",clocks:"Registros personales de asistencia",missing:"Los demás indicadores no están disponibles en este informe.",play:"Escuchar mi informe",stop:"Detener",unavailable:"Voz local o datos no disponibles.",load:"Actualizar"},
 it:{title:"Il mio resoconto",intro:"Ecco il tuo resoconto parziale basato sui dati confermati.",appointments:"Appuntamenti",completed:"completati",finance:"Ricavi in franchi CFA",sales:"vendite confermate",clocks:"Registrazioni personali delle presenze",missing:"Gli altri indicatori non sono disponibili in questo resoconto.",play:"Ascolta il mio resoconto",stop:"Interrompi",unavailable:"Voce locale o dati non disponibili.",load:"Aggiorna"},
 "zh-CN":{title:"我的日报",intro:"这是根据已确认数据生成的部分报告。",appointments:"预约",completed:"已完成",finance:"营业收入（非洲金融共同体法郎）",sales:"已确认销售",clocks:"个人考勤记录",missing:"其他指标暂未包含在此报告中。",play:"收听我的日报",stop:"停止",unavailable:"本地语音或数据不可用。",load:"刷新"}
};
export function briefingNarration(r:Report,l:Lang):string{
 const t=copy[l];
 return [t.intro,r.day,t.appointments+": "+r.appointments.scheduled_count+"; "+t.completed+": "+r.appointments.completed_count+".",r.finance===null?"":t.finance+": "+r.finance.revenue_xaf+"; "+t.sales+": "+r.finance.confirmed_sales_count+".",r.personal_clock_events===null?"":t.clocks+": "+r.personal_clock_events.event_count+".",t.missing].filter(Boolean).join(" ");
}

export function validateBriefing(value:unknown,day:string):Report {
 const object=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==="object"&&!Array.isArray(v);
 const count=(v:unknown):v is number=>typeof v==="number"&&Number.isSafeInteger(v)&&v>=0;
 if(!object(value)||value.day!==day||typeof value.generated_at!=="string"||!Number.isFinite(Date.parse(value.generated_at))||value.coverage!=="partial_confirmed_server_facts"||(value.scope!=="site"&&value.scope!=="personal"))throw Error("INVALID_BRIEFING");
 const a=value.appointments,f=value.finance,p=value.personal_clock_events;
 if(!object(a)||!count(a.scheduled_count)||!count(a.completed_count)||a.completed_count>a.scheduled_count)throw Error("INVALID_BRIEFING");
 if(f!==null&&(!object(f)||!count(f.revenue_xaf)||!count(f.confirmed_sales_count)||!count(f.uncosted_sales_count)||f.uncosted_sales_count>f.confirmed_sales_count))throw Error("INVALID_BRIEFING");
 if(value.scope==="personal"&&f!==null)throw Error("INVALID_BRIEFING");
 if(p!==null&&(!object(p)||!count(p.event_count)))throw Error("INVALID_BRIEFING");
 return value as Report;
}
export function briefingDateBounds(now=Date.now()){
 const today=new Date(now+3600000).toISOString().slice(0,10);
 const earliest=new Date(Date.parse(today+"T00:00:00Z")-366*86400000).toISOString().slice(0,10);
 return {today,earliest};
}
export function briefingDayAllowed(day:string,now=Date.now()){
 const {today,earliest}=briefingDateBounds(now);
 return /^\d{4}-\d{2}-\d{2}$/.test(day)&&day>=earliest&&day<=today&&Number.isFinite(Date.parse(day+"T00:00:00Z"))&&new Date(day+"T00:00:00Z").toISOString().slice(0,10)===day;
}
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
export function DailyBriefing({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const [lang,setLang]=useState<Lang>(account.default_locale);
 const [day,setDay]=useState(()=>briefingDateBounds().today);
 const bounds=briefingDateBounds();
 const dateLabel=({fr:"Date du bilan",en:"Report date","ff-CM":"Ñalnde jaŋtol",es:"Fecha del informe",it:"Data del resoconto","zh-CN":"报告日期"})[lang];
 const [report,setReport]=useState<Report|null>(null),[error,setError]=useState(false),[loading,setLoading]=useState(false),[playing,setPlaying]=useState(false),[paused,setPaused]=useState(false),[speed,setSpeed]=useState(1);
 const controller=useRef<AbortController|null>(null),audio=useRef<SpeechSynthesisUtterance|null>(null),mounted=useRef(false);
 const t=copy[lang];
 function stop(){if(audio.current){audio.current.onend=null;audio.current.onerror=null;window.speechSynthesis?.cancel();audio.current=null;}setPlaying(false);setPaused(false);}
 useEffect(()=>{mounted.current=true;const hide=()=>{if(document.visibilityState!=="hidden")return;controller.current?.abort();controller.current=null;stop();setReport(null);setLoading(false);};document.addEventListener("visibilitychange",hide);return()=>{mounted.current=false;document.removeEventListener("visibilitychange",hide);controller.current?.abort();if(audio.current){audio.current.onend=null;audio.current.onerror=null;window.speechSynthesis?.cancel();audio.current=null;}};},[]);
 async function load(){
  stop();controller.current?.abort();const abort=new AbortController();controller.current=abort;setLoading(true);setError(false);setReport(null);
  const requestedDay=day;
  try{
   if(!anonKey||!briefingDayAllowed(requestedDay))throw Error("BRIEFING_UNAVAILABLE");
   const result=await privateRequest<unknown>(abort.signal,()=>mounted.current&&controller.current===abort&&document.visibilityState!=="hidden",getToken,(token,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/ns_daily_briefing",{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,p_day:requestedDay}),signal,cache:"no-store",credentials:"omit"}));
   const data=validateBriefing(result,requestedDay);
   if(abort.signal.aborted||!mounted.current||controller.current!==abort||document.visibilityState==="hidden")return;
   setReport(data);
   return {data,abort};
  }catch{if(!abort.signal.aborted&&mounted.current)setError(true);}
  finally{if(!abort.signal.aborted&&mounted.current)setLoading(false);}
 }
 function speak(r:Report){
  if(document.visibilityState==="hidden"||!mounted.current)return;
  if(!window.speechSynthesis){setError(true);return;}
  // Only a local voice: never transmit business data to a browser cloud voice.
  const voice=window.speechSynthesis.getVoices().find(v=>v.localService&&v.lang.toLowerCase().split("-")[0]===lang.toLowerCase().split("-")[0]);
  if(!voice){setError(true);return;}
  stop();setError(false);const u=new SpeechSynthesisUtterance(briefingNarration(r,lang));u.voice=voice;u.lang=voice.lang;u.rate=speed;audio.current=u;
  u.onend=()=>{if(audio.current===u){audio.current=null;setPlaying(false);setPaused(false);}};u.onerror=()=>{if(audio.current===u){audio.current=null;setPlaying(false);setPaused(false);setError(true);}};
  setPaused(false);setPlaying(true);window.speechSynthesis.speak(u);
 }
 if(!siteId)return null;
 return <section className="module-main-card" aria-label={t.title}><h2>{t.title}</h2>
 <label>{dateLabel}<input type="date" aria-label={dateLabel} value={day} min={bounds.earliest} max={bounds.today} required onChange={e=>{stop();controller.current?.abort();controller.current=null;setReport(null);setLoading(false);setError(false);setDay(e.target.value);}}/></label>
 <label><select aria-label="Language / Langue" disabled={loading} value={lang} onChange={e=>{stop();setLang(e.target.value as Lang);setError(false);}}>{Object.entries(languages).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
 <label><select aria-label="Speed / Vitesse" disabled={loading} value={speed} onChange={e=>{stop();setSpeed(Number(e.target.value));}}>{[.8,1,1.2,1.5].map(s=><option key={s} value={s}>{s}×</option>)}</select></label>
 <button className="btn primary" disabled={loading||!briefingDayAllowed(day)} onClick={()=>{if(playing){stop();return;}void load().then(r=>{if(r&&mounted.current&&!r.abort.signal.aborted&&controller.current===r.abort)speak(r.data);});}}>{playing?t.stop:t.play}</button>
 {playing&&<button className="btn secondary" onClick={()=>{if(!audio.current)return;if(paused)window.speechSynthesis.resume();else window.speechSynthesis.pause();setPaused(!paused);}}>{({fr:paused?"Reprendre":"Pause",en:paused?"Resume":"Pause","ff-CM":paused?"Jokku":"Fowtu",es:paused?"Continuar":"Pausa",it:paused?"Riprendi":"Pausa","zh-CN":paused?"继续":"暂停"})[lang]}</button>}
 <button className="btn secondary" disabled={loading||!briefingDayAllowed(day)} onClick={()=>void load()}>{t.load}</button>
 {error&&<p role="alert">{t.unavailable}</p>}{report&&<p>{briefingNarration(report,lang)}</p>}</section>;
}
