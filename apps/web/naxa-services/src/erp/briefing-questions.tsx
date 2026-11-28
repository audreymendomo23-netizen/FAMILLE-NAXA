import React,{useEffect,useRef,useState} from "react";
type Lang="fr"|"en"|"ff-CM"|"es"|"it"|"zh-CN";
type Metric="appointments"|"completed"|"revenue"|"sales"|"uncosted"|"clocks";
type Period={scope:"site"|"personal";appointments:number;completed:number;revenue:number|null;sales:number|null;uncosted:number|null;clocks:number|null};
const metrics:Metric[]=["appointments","completed","revenue","sales","uncosted","clocks"];
const labels:Record<Lang,string[]>={fr:["Rendez-vous","Prestations terminées","Chiffre d’affaires","Ventes confirmées","Ventes sans coût","Pointages"],en:["Appointments","Completed appointments","Revenue","Confirmed sales","Uncosted sales","Clock events"],"ff-CM":["Kawrital","Kawrital timmuɗe","Ceede CFA","Jaaygol tabbitinaangol","Jaaygol alaa njaru","Winndanɗe naatugol"],es:["Citas","Citas completadas","Ingresos","Ventas confirmadas","Ventas sin coste","Registros de asistencia"],it:["Appuntamenti","Appuntamenti completati","Ricavi","Vendite confermate","Vendite senza costo","Presenze"],"zh-CN":["预约","已完成预约","收入","已确认销售","未记录成本的销售","考勤"]};
const ui:Record<Lang,string[]>={fr:["Questions sur le bilan","Choisir un indicateur","Écouter la réponse","Poser une question au micro (local)","Donnée ou voix locale indisponible"],en:["Report questions","Choose a metric","Listen to answer","Ask using local microphone","Data or local voice unavailable"],"ff-CM":["Ƴamɗe jaŋtol","Suɓo humpito","Heɗo jaabawol","Ƴam e daande","Humpito walla daande heɓotaako"],es:["Preguntas sobre el informe","Elegir indicador","Escuchar respuesta","Preguntar con micrófono local","Dato o voz local no disponible"],it:["Domande sul resoconto","Scegli indicatore","Ascolta risposta","Domanda con microfono locale","Dato o voce locale non disponibile"],"zh-CN":["报告问题","选择指标","听取回答","使用本地麦克风提问","数据或本地语音不可用"]};
const allowed=(scope:Period["scope"],metric:Metric)=>scope==="site"||!["revenue","sales","uncosted"].includes(metric);
export function metricAnswer(report:Period,metric:Metric,lang:Lang):string|null{
 if(!metrics.includes(metric)||!allowed(report.scope,metric))return null;
 const n=report[metric];if(n===null||!Number.isSafeInteger(n)||n<0)return null;
 return labels[lang][metrics.indexOf(metric)]+": "+n+(metric==="revenue"?" XAF":"");
}
const normalize=(v:string)=>v.normalize("NFKC").trim().toLocaleLowerCase().replace(/[?？.!。]+$/u,"").trim();
export function matchMetric(question:string,lang:Lang,scope:Period["scope"]):Metric|null{
 const i=labels[lang].findIndex(s=>normalize(s)===normalize(question));return i>=0&&allowed(scope,metrics[i])?metrics[i]:null;
}
type LocalRecognition={processLocally:boolean;lang:string;continuous:boolean;interimResults:boolean;start:()=>void;abort:()=>void;onresult:((event:{results:ArrayLike<ArrayLike<{transcript:string}>>})=>void)|null;onerror:(()=>void)|null;onend:(()=>void)|null};
type LocalConstructor=new()=>LocalRecognition;
export function BriefingQuestions({report,lang}:{report:Period;lang:Lang}){
 const [metric,setMetric]=useState<Metric>("appointments"),[error,setError]=useState(false),[listening,setListening]=useState(false);
 const recognizer=useRef<LocalRecognition|null>(null),utterance=useRef<SpeechSynthesisUtterance|null>(null),alive=useRef(false);
 const [title,choose,listen,ask,unavailable]=ui[lang],answer=metricAnswer(report,metric,lang);
 function stop(){const r=recognizer.current;recognizer.current=null;if(r){r.onresult=null;r.onend=null;r.onerror=null;try{r.abort();}catch{}}if(utterance.current){window.speechSynthesis?.cancel();utterance.current=null;}}
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden"){stop();setListening(false);setMetric("appointments");setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;stop();document.removeEventListener("visibilitychange",hide);};},[]);
 function speak(value:string|null){if(!value||!alive.current||document.visibilityState==="hidden"||!window.speechSynthesis){setError(true);return;}const v=window.speechSynthesis.getVoices().find(v=>v.localService&&v.lang.toLowerCase().split("-")[0]===lang.toLowerCase().split("-")[0]);if(!v){setError(true);return;}if(utterance.current)window.speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(value);u.voice=v;u.lang=v.lang;utterance.current=u;u.onend=()=>{if(utterance.current===u)utterance.current=null;};u.onerror=()=>{if(alive.current&&utterance.current===u){utterance.current=null;setError(true);}};window.speechSynthesis.speak(u);}
 function microphone(){if(!alive.current||document.visibilityState==="hidden"||recognizer.current)return;setError(false);const w=window as unknown as {SpeechRecognition?:LocalConstructor;webkitSpeechRecognition?:LocalConstructor};const C=w.SpeechRecognition??w.webkitSpeechRecognition;if(!C){setError(true);return;}try{const r=new C();if(!("processLocally" in r)){setError(true);return;}r.processLocally=true;if(r.processLocally!==true){setError(true);return;}r.lang=lang;r.continuous=false;r.interimResults=false;recognizer.current=r;setListening(true);
 r.onresult=e=>{if(!alive.current||recognizer.current!==r||document.visibilityState==="hidden")return;const m=matchMetric(e.results[0]?.[0]?.transcript??"",lang,report.scope);if(!m){setError(true);return;}setMetric(m);speak(metricAnswer(report,m,lang));};
 r.onerror=()=>{if(alive.current&&recognizer.current===r){recognizer.current=null;setListening(false);setError(true);}};
 r.onend=()=>{if(alive.current&&recognizer.current===r){recognizer.current=null;setListening(false);}};r.start();
 }catch{recognizer.current=null;setListening(false);setError(true);}}
 return <section aria-label={title}><h4>{title}</h4><label>{choose}<select value={metric} onChange={e=>{stop();setListening(false);setError(false);setMetric(e.target.value as Metric);}}>{metrics.filter(m=>allowed(report.scope,m)).map(m=><option key={m} value={m}>{labels[lang][metrics.indexOf(m)]}</option>)}</select></label><p data-briefing-answer="true" role="status">{answer??unavailable}</p><button type="button" disabled={!answer||listening} onClick={()=>speak(answer)}>{listen}</button><button type="button" disabled={listening} onClick={microphone}>{ask}</button>{error&&<p role="alert">{unavailable}</p>}</section>;
}
