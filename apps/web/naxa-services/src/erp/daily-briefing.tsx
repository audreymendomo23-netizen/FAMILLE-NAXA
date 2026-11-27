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
 const uncosted=({fr:"Ventes sans coût renseigné",en:"Sales without recorded costs","ff-CM":"Soodugol alaa njaru winndaaɗo",es:"Ventas sin coste registrado",it:"Vendite senza costo registrato","zh-CN":"未记录成本的销售"})[l];
 return [t.intro,r.day,t.appointments+": "+r.appointments.scheduled_count+"; "+t.completed+": "+r.appointments.completed_count+".",r.finance===null?"":t.finance+": "+r.finance.revenue_xaf+"; "+t.sales+": "+r.finance.confirmed_sales_count+". "+uncosted+": "+r.finance.uncosted_sales_count+".",r.personal_clock_events===null?"":t.clocks+": "+r.personal_clock_events.event_count+".",t.missing].filter(Boolean).join(" ");
}

export function validateBriefing(value:unknown,day:string):Report {
 const object=(v:unknown):v is Record<string,unknown>=>!!v&&typeof v==="object"&&!Array.isArray(v);
 const count=(v:unknown):v is number=>typeof v==="number"&&Number.isSafeInteger(v)&&v>=0;
 if(!object(value)||value.day!==day||typeof value.generated_at!=="string"||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/.test(value.generated_at)||!Number.isFinite(Date.parse(value.generated_at))||value.coverage!=="partial_confirmed_server_facts"||(value.scope!=="site"&&value.scope!=="personal"))throw Error("INVALID_BRIEFING");
 const a=value.appointments,f=value.finance,p=value.personal_clock_events;
 if(!object(a)||!count(a.scheduled_count)||!count(a.completed_count)||a.completed_count>a.scheduled_count)throw Error("INVALID_BRIEFING");
 if(f!==null&&(!object(f)||!count(f.revenue_xaf)||!count(f.confirmed_sales_count)||!count(f.uncosted_sales_count)||f.uncosted_sales_count>f.confirmed_sales_count))throw Error("INVALID_BRIEFING");
 if(value.scope==="personal"&&f!==null)throw Error("INVALID_BRIEFING");
 if(p!==null&&(!object(p)||!count(p.event_count)))throw Error("INVALID_BRIEFING");
 return {day,generated_at:value.generated_at,coverage:value.coverage,scope:value.scope,
  appointments:{scheduled_count:a.scheduled_count as number,completed_count:a.completed_count as number},
  finance:f===null?null:{revenue_xaf:(f as Record<string,unknown>).revenue_xaf as number,confirmed_sales_count:(f as Record<string,unknown>).confirmed_sales_count as number,uncosted_sales_count:(f as Record<string,unknown>).uncosted_sales_count as number},
  personal_clock_events:p===null?null:{event_count:(p as Record<string,unknown>).event_count as number}};

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
export function briefingPeriodDays(end:string,days:number,now=Date.now()):string[]{
 if(![2,7,30].includes(days)||!briefingDayAllowed(end,now))throw Error("INVALID_BRIEFING_PERIOD");
 const dates=Array.from({length:days},(_,i)=>new Date(Date.parse(end+"T00:00:00Z")-(days-1-i)*86400000).toISOString().slice(0,10));
 if(!dates.every(d=>briefingDayAllowed(d,now)))throw Error("INVALID_BRIEFING_PERIOD");
 return dates;
}
export function summarizeBriefingPeriod(dates:string[],values:unknown[]){
 if(!dates.length||dates.length!==values.length||new Set(dates).size!==dates.length)throw Error("INCOMPLETE_BRIEFING_PERIOD");
 const rows=values.map((v,i)=>validateBriefing(v,dates[i]));
 if(rows.some(r=>r.scope!==rows[0].scope))throw Error("BRIEFING_SCOPE_CHANGED");
 const sum=(v:number[])=>{const n=v.reduce((a,b)=>a+b,0);if(!Number.isSafeInteger(n))throw Error("BRIEFING_TOTAL_OVERFLOW");return n;};
 const financeDays=rows.filter(r=>r.finance!==null).length;
 return {rows,scope:rows[0].scope,financeDays,appointments:sum(rows.map(r=>r.appointments.scheduled_count)),completed:sum(rows.map(r=>r.appointments.completed_count)),revenue:financeDays===rows.length?sum(rows.map(r=>r.finance!.revenue_xaf)):null,clocks:rows.every(r=>r.personal_clock_events!==null)?sum(rows.map(r=>r.personal_clock_events!.event_count)):null};
}
type Props={account:WebAuthAccount;siteId:string;authEndpoint:string;anonKey:string;getToken:()=>Promise<string>};
const periodCopy:Record<Lang,[string,string,string,string,string,string,string,string]>={
 fr:["Bilan par période","Durée du bilan","Calculer la période","Jours","Données financières incomplètes : total indisponible","Chiffre d’affaires confirmé (FCFA)","Données journalières partielles.","Période indisponible"],
 en:["Period report","Report duration","Calculate period","Days","Incomplete finance data: total unavailable","Confirmed revenue (XAF)","Partial daily records.","Period unavailable"],
 "ff-CM":["Jaŋtol sahaa","Juuteendi jaŋtol","Lim jaŋtol sahaa","Balɗe","Humpito ceede timmaani","Ceede tabbitinaaɗe (FCFA)","Humpito ñalnde timmaani.","Sahaa heɓotaako"],
 es:["Informe por período","Duración del informe","Calcular período","Días","Datos financieros incompletos: total no disponible","Ingresos confirmados (XAF)","Datos diarios parciales.","Período no disponible"],
 it:["Resoconto per periodo","Durata del resoconto","Calcola periodo","Giorni","Dati finanziari incompleti: totale non disponibile","Ricavi confermati (XAF)","Dati giornalieri parziali.","Periodo non disponibile"],
 "zh-CN":["期间报告","报告时长","计算期间","天","财务数据不完整：总计不可用","已确认收入（XAF）","每日数据不完整。","期间不可用"]
};
function PeriodBriefing({account,siteId,authEndpoint,anonKey,getToken,day,lang}:Props&{day:string;lang:Lang}){
 const [days,setDays]=useState(7),[busy,setBusy]=useState(false),[error,setError]=useState(false),[report,setReport]=useState<ReturnType<typeof summarizeBriefingPeriod>|null>(null);
 const controller=useRef<AbortController|null>(null),alive=useRef(false);
 const [title,duration,calculate,unit,missing,revenue,note,unavailable]=periodCopy[lang],t=copy[lang];
 function clear(){controller.current?.abort();controller.current=null;setReport(null);setBusy(false);setError(false);}
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden")clear();};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;controller.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function load(){
  if(busy||document.visibilityState==="hidden")return;
  clear();const c=new AbortController();controller.current=c;setBusy(true);
  const current=()=>alive.current&&controller.current===c&&!c.signal.aborted&&document.visibilityState!=="hidden";
  try{
   if(!anonKey)throw Error("BRIEFING_UNAVAILABLE");
   const dates=briefingPeriodDays(day,days),values:unknown[]=[];
   for(let i=0;i<dates.length;i+=3){
    if(!current())return;
    const batch=await Promise.all(dates.slice(i,i+3).map(d=>privateRequest<unknown>(c.signal,current,getToken,(token,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/ns_daily_briefing",{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,p_day:d}),signal,cache:"no-store",credentials:"omit",redirect:"error"}))));
    values.push(...batch);
   }
   const result=summarizeBriefingPeriod(dates,values);
   if(current())setReport(result);
  }catch{if(current()){setReport(null);setError(true);c.abort();controller.current=null;setBusy(false);}}
  finally{if(current())setBusy(false);}
 }
 return <section aria-label={title} aria-busy={busy}><h3>{title}</h3><p>{note}</p>
 <label>{duration}<select value={days} disabled={busy} onChange={e=>{clear();setDays(Number(e.target.value));}}>{[2,7,30].map(d=><option key={d} value={d}>{d} {unit}</option>)}</select></label>
 <button className="btn secondary" disabled={busy||!briefingDayAllowed(day)} onClick={()=>void load()}>{calculate}</button>
 {error&&<p role="alert">{unavailable}</p>}
 {report&&<div data-briefing-period-result={report.rows.length}><p>{report.rows[0].day} — {report.rows[report.rows.length-1].day}</p>
 <p>{t.appointments}: {report.appointments} · {t.completed}: {report.completed}</p>
 {report.scope==="site"&&<p>{report.revenue===null?missing:revenue+": "+report.revenue} ({report.financeDays}/{report.rows.length} {unit})</p>}
 {report.clocks!==null&&<p>{t.clocks}: {report.clocks}</p>}
 <ul>{report.rows.map(r=><li key={r.day}>{r.day} · {t.appointments}: {r.appointments.scheduled_count} · {t.completed}: {r.appointments.completed_count}{r.finance!==null?" · "+revenue+": "+r.finance.revenue_xaf:""}</li>)}</ul></div>}</section>;
}
export function DailyBriefing(props:Props){
 return <ScopedDailyBriefing key={JSON.stringify([props.account.organization_id,props.account.member_id,props.account.role_code,props.siteId,props.authEndpoint,props.anonKey])} {...props}/>;
}
function ScopedDailyBriefing({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const [lang,setLang]=useState<Lang>(account.default_locale);
 const [day,setDay]=useState(()=>briefingDateBounds().today);
 const bounds=briefingDateBounds();
 const dateLabel=({fr:"Date du bilan",en:"Report date","ff-CM":"Ñalnde jaŋtol",es:"Fecha del informe",it:"Data del resoconto","zh-CN":"报告日期"})[lang];
 const languageLabel=({fr:"Langue du bilan",en:"Report language","ff-CM":"Ɗemngal jaŋtol",es:"Idioma del informe",it:"Lingua del resoconto","zh-CN":"报告语言"})[lang];
 const speedLabel=({fr:"Vitesse de lecture",en:"Playback speed","ff-CM":"Yaawde janngugol",es:"Velocidad de lectura",it:"Velocità di lettura","zh-CN":"播放速度"})[lang];
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
 return <section className="module-main-card" aria-label={t.title} aria-busy={loading}><h2>{t.title}</h2>
 <label>{dateLabel}<input type="date" aria-label={dateLabel} value={day} min={bounds.earliest} max={bounds.today} required onChange={e=>{stop();controller.current?.abort();controller.current=null;setReport(null);setLoading(false);setError(false);setDay(e.target.value);}}/></label>
 <label>{languageLabel}<select aria-label={languageLabel} disabled={loading} value={lang} onChange={e=>{stop();setLang(e.target.value as Lang);setError(false);}}>{Object.entries(languages).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
 <label>{speedLabel}<select aria-label={speedLabel} disabled={loading} value={speed} onChange={e=>{stop();setSpeed(Number(e.target.value));}}>{[.8,1,1.2,1.5].map(s=><option key={s} value={s}>{s}×</option>)}</select></label>
 <button className="btn primary" disabled={loading||!briefingDayAllowed(day)} onClick={()=>{if(playing){stop();return;}void load().then(r=>{if(r&&mounted.current&&!r.abort.signal.aborted&&controller.current===r.abort)speak(r.data);});}}>{playing?t.stop:t.play}</button>
 {playing&&<button className="btn secondary" onClick={()=>{if(!audio.current)return;if(paused)window.speechSynthesis.resume();else window.speechSynthesis.pause();setPaused(!paused);}}>{({fr:paused?"Reprendre":"Pause",en:paused?"Resume":"Pause","ff-CM":paused?"Jokku":"Fowtu",es:paused?"Continuar":"Pausa",it:paused?"Riprendi":"Pausa","zh-CN":paused?"继续":"暂停"})[lang]}</button>}
 <button className="btn secondary" disabled={loading||!briefingDayAllowed(day)} onClick={()=>void load()}>{t.load}</button>
 {error&&<p role="alert">{t.unavailable}</p>}{report&&<p>{briefingNarration(report,lang)}</p>}<PeriodBriefing key={day} account={account} siteId={siteId} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken} day={day} lang={lang}/></section>;
}
