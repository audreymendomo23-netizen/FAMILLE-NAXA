import React,{useEffect,useRef,useState} from "react";
import {BriefingQuestions} from "./briefing-questions";
import {BriefingReminders} from "./briefing-reminders";
import {privateRequest} from "./private-request";
import {downloadLocal} from "./calendar-export";
import type {WebAuthAccount} from "../auth/session";
import {rosterApiOrigin} from "./staff-roster";
export type Report={day:string;generated_at:string;scope:"site"|"personal";finance:{revenue_xaf:number;confirmed_sales_count:number;uncosted_sales_count:number}|null;appointments:{scheduled_count:number;completed_count:number};personal_clock_events:{event_count:number}|null;coverage:string;details?:Record<string,number|null>};
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
const detailLabels:Record<Lang,Record<string,string>>={"fr":{"own_commissions_xaf":"Commissions propres approuvées (FCFA)","tomorrow_appointments":"Rendez-vous demain","tomorrow_shifts":"Horaires personnels demain","post_appointments":"Rendez-vous des postes délégués","post_completed":"Prestations des postes terminées","receipts_xaf":"Encaissements confirmés (FCFA)","pending_payments_xaf":"Paiements en attente (FCFA)","expenses_xaf":"Dépenses (FCFA)","gross_profit_xaf":"Marge brute connue non négative (FCFA)","objective_xaf":"Objectif CA (FCFA)","cash_closed":"Caisses clôturées","cash_variances":"Clôtures avec écart","new_customers":"Nouveaux clients","loyalty_rewards":"Récompenses fidélité","support_requests":"Demandes au support","completed_work":"Travaux terminés","supplier_payments_xaf":"Paiements fournisseurs (FCFA)","receivables_xaf":"Créances ouvertes (FCFA)","followups_due":"Relances dues","stock_low":"Articles au seuil ou en rupture","purchase_open":"Commandes ouvertes","supplier_debt_xaf":"Dette fournisseurs (FCFA)","supplier_overdue_xaf":"Dette fournisseurs échue (FCFA)","work_open":"Travaux en cours","work_overdue":"Travaux en retard","pressing_open":"Tickets pressing ouverts","pressing_overdue":"Tickets pressing en retard","network_sites":"Sites autorisés consolidés","network_revenue_xaf":"CA consolidé autorisé (FCFA)","network_sales":"Ventes consolidées autorisées"},"en":{"own_commissions_xaf":"Own approved commissions (XAF)","tomorrow_appointments":"Tomorrow appointments","tomorrow_shifts":"Own shifts tomorrow","post_appointments":"Delegated workstation appointments","post_completed":"Completed delegated workstation services","receipts_xaf":"Confirmed receipts (XAF)","pending_payments_xaf":"Pending payments (XAF)","expenses_xaf":"Expenses (XAF)","gross_profit_xaf":"Known nonnegative gross profit (XAF)","objective_xaf":"Revenue target (XAF)","cash_closed":"Closed tills","cash_variances":"Closures with variance","new_customers":"New customers","loyalty_rewards":"Loyalty rewards","support_requests":"Support requests","completed_work":"Completed work","supplier_payments_xaf":"Supplier payments (XAF)","receivables_xaf":"Open receivables (XAF)","followups_due":"Due follow-ups","stock_low":"Low or out-of-stock items","purchase_open":"Open purchase orders","supplier_debt_xaf":"Supplier debt (XAF)","supplier_overdue_xaf":"Overdue supplier debt (XAF)","work_open":"Open work orders","work_overdue":"Overdue work orders","pressing_open":"Open pressing tickets","pressing_overdue":"Overdue pressing tickets","network_sites":"Consolidated authorized sites","network_revenue_xaf":"Authorized consolidated revenue (XAF)","network_sales":"Authorized consolidated sales"},"ff-CM":{"own_commissions_xaf":"Komiisiyoŋaji am jaɓaaɗi","tomorrow_appointments":"Kawrital jaŋngo","tomorrow_shifts":"Golle am jaŋngo","post_appointments":"Kawrital nokkuuji","post_completed":"Golle nokkuuji timmuɗe","receipts_xaf":"Njoɓdi tabbitinaandi","pending_payments_xaf":"Njoɓdi fadude","expenses_xaf":"Njaruuji","gross_profit_xaf":"Ceede heddiiɗe","objective_xaf":"Faandaare ceede","cash_closed":"Kaasaaji udditaaɗi","cash_variances":"Kaasaaji ceertuuji","new_customers":"Julaaɓe hesɓe","loyalty_rewards":"Njoddi hoolaare","support_requests":"Ɗaɓɓitanɗe ballal","completed_work":"Golle timmuɗe","supplier_payments_xaf":"Njoɓdi yeeyooɓe","receivables_xaf":"Ceede fadi","followups_due":"Tintine waktuuje","stock_low":"Jawdi famɗi","purchase_open":"Ɗaɓɓitanɗe udditaaɗe","supplier_debt_xaf":"Baasal yeeyooɓe","supplier_overdue_xaf":"Baasal waktu timmi","work_open":"Golle ɗe ngollatee","work_overdue":"Golle leelɗe","pressing_open":"Golle laɓɓingol","pressing_overdue":"Golle laɓɓingol leelɗe","network_sites":"Nokkuuji yamiraaɗi","network_revenue_xaf":"Ceede nokkuuji yamiraaɗi","network_sales":"Jaaygol nokkuuji yamiraaɗi"},"es":{"own_commissions_xaf":"Comisiones propias aprobadas","tomorrow_appointments":"Citas mañana","tomorrow_shifts":"Turnos propios mañana","post_appointments":"Citas de puestos delegados","post_completed":"Servicios delegados completados","receipts_xaf":"Cobros confirmados","pending_payments_xaf":"Pagos pendientes","expenses_xaf":"Gastos","gross_profit_xaf":"Margen bruto conocido no negativo","objective_xaf":"Objetivo de ingresos","cash_closed":"Cajas cerradas","cash_variances":"Cierres con diferencia","new_customers":"Nuevos clientes","loyalty_rewards":"Premios de fidelidad","support_requests":"Solicitudes de soporte","completed_work":"Trabajos completados","supplier_payments_xaf":"Pagos proveedores","receivables_xaf":"Créditos abiertos","followups_due":"Seguimientos pendientes","stock_low":"Artículos con poco stock","purchase_open":"Pedidos abiertos","supplier_debt_xaf":"Deuda proveedores","supplier_overdue_xaf":"Deuda proveedores vencida","work_open":"Trabajos abiertos","work_overdue":"Trabajos atrasados","pressing_open":"Tickets de lavandería abiertos","pressing_overdue":"Tickets de lavandería atrasados","network_sites":"Centros autorizados consolidados","network_revenue_xaf":"Ingresos consolidados autorizados","network_sales":"Ventas consolidadas autorizadas"},"it":{"own_commissions_xaf":"Commissioni proprie approvate","tomorrow_appointments":"Appuntamenti domani","tomorrow_shifts":"Turni propri domani","post_appointments":"Appuntamenti postazioni delegate","post_completed":"Servizi delegati completati","receipts_xaf":"Incassi confermati","pending_payments_xaf":"Pagamenti in attesa","expenses_xaf":"Spese","gross_profit_xaf":"Margine lordo noto non negativo","objective_xaf":"Obiettivo ricavi","cash_closed":"Casse chiuse","cash_variances":"Chiusure con scostamento","new_customers":"Nuovi clienti","loyalty_rewards":"Premi fedeltà","support_requests":"Richieste assistenza","completed_work":"Lavori completati","supplier_payments_xaf":"Pagamenti fornitori","receivables_xaf":"Crediti aperti","followups_due":"Solleciti dovuti","stock_low":"Articoli in esaurimento","purchase_open":"Ordini aperti","supplier_debt_xaf":"Debito fornitori","supplier_overdue_xaf":"Debito fornitori scaduto","work_open":"Lavori aperti","work_overdue":"Lavori in ritardo","pressing_open":"Ticket lavanderia aperti","pressing_overdue":"Ticket lavanderia in ritardo","network_sites":"Sedi autorizzate consolidate","network_revenue_xaf":"Ricavi consolidati autorizzati","network_sales":"Vendite consolidate autorizzate"},"zh-CN":{"own_commissions_xaf":"个人已批准佣金","tomorrow_appointments":"明日预约","tomorrow_shifts":"明日个人班次","post_appointments":"授权工位预约","post_completed":"授权工位已完成服务","receipts_xaf":"已确认收款","pending_payments_xaf":"待确认付款","expenses_xaf":"支出","gross_profit_xaf":"已知非负毛利","objective_xaf":"营业额目标","cash_closed":"已结账收银","cash_variances":"有差异的结账","new_customers":"新客户","loyalty_rewards":"忠诚奖励","support_requests":"支持请求","completed_work":"已完成工作","supplier_payments_xaf":"供应商付款","receivables_xaf":"未收账款","followups_due":"待跟进事项","stock_low":"低库存或缺货","purchase_open":"未完成采购订单","supplier_debt_xaf":"供应商欠款","supplier_overdue_xaf":"逾期供应商欠款","work_open":"进行中工作","work_overdue":"逾期工作","pressing_open":"未完成洗衣单","pressing_overdue":"逾期洗衣单","network_sites":"授权汇总网点","network_revenue_xaf":"授权汇总营业额","network_sales":"授权汇总销售"}};
const personalDetails=new Set(["own_commissions_xaf","tomorrow_appointments","tomorrow_shifts","post_appointments","post_completed"]);
export function validatedDetails(value:unknown,scope:"site"|"personal"):Record<string,number|null>{
 if(!value||typeof value!=="object"||Array.isArray(value))throw Error("INVALID_BRIEFING");const out:Record<string,number|null>={};for(const [k,v] of Object.entries(value)){if(!Object.prototype.hasOwnProperty.call(detailLabels.fr,k))continue;if(scope==="personal"&&!personalDetails.has(k))throw Error("INVALID_BRIEFING");if(v!==null&&(typeof v!=="number"||!Number.isSafeInteger(v)||v<0))throw Error("INVALID_BRIEFING");out[k]=v as number|null;}return out;
}

export function briefingNarration(r:Report,l:Lang,detailed=true):string{
 const t=copy[l];
 const uncosted=({fr:"Ventes sans coût renseigné",en:"Sales without recorded costs","ff-CM":"Soodugol alaa njaru winndaaɗo",es:"Ventas sin coste registrado",it:"Vendite senza costo registrato","zh-CN":"未记录成本的销售"})[l];
 return [t.intro,r.day,t.appointments+": "+r.appointments.scheduled_count+"; "+t.completed+": "+r.appointments.completed_count+".",r.finance===null?"":t.finance+": "+r.finance.revenue_xaf+(detailed?"; "+t.sales+": "+r.finance.confirmed_sales_count+". "+uncosted+": "+r.finance.uncosted_sales_count+".":"."),!detailed||r.personal_clock_events===null?"":t.clocks+": "+r.personal_clock_events.event_count+".",...(detailed?Object.entries(r.details??{}).map(([k,v])=>detailLabels[l][k]+": "+(v===null?t.unavailable:v)+"."):[]),t.missing].filter(Boolean).join(" ");
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
  personal_clock_events:p===null?null:{event_count:(p as Record<string,unknown>).event_count as number},...(value.details===undefined?{}:{details:validatedDetails(value.details,value.scope)})};

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
 if(![1,2,7,30,366].includes(days)||!briefingDayAllowed(end,now))throw Error("INVALID_BRIEFING_PERIOD");
 const count=days===366?Math.round((Date.parse(end+"T00:00:00Z")-Date.parse(end.slice(0,4)+"-01-01T00:00:00Z"))/86400000)+1:days;
 const dates=Array.from({length:count},(_,i)=>new Date(Date.parse(end+"T00:00:00Z")-(count-1-i)*86400000).toISOString().slice(0,10));
 if(!dates.every(d=>briefingDayAllowed(d,now)))throw Error("INVALID_BRIEFING_PERIOD");
 return dates;
}
export function summarizeBriefingPeriod(dates:string[],values:unknown[]){
 if(!dates.length||dates.length>366||dates.length!==values.length||new Set(dates).size!==dates.length||dates.some((d,i)=>i>0&&Date.parse(d)-Date.parse(dates[i-1])!==86400000))throw Error("INCOMPLETE_BRIEFING_PERIOD");
 const rows=values.map((v,i)=>validateBriefing(v,dates[i]));
 if(rows.some(r=>r.scope!==rows[0].scope))throw Error("BRIEFING_SCOPE_CHANGED");
 const sum=(v:number[])=>{const n=v.reduce((a,b)=>a+b,0);if(!Number.isSafeInteger(n))throw Error("BRIEFING_TOTAL_OVERFLOW");return n;};
 const financeDays=rows.filter(r=>r.finance!==null).length;
 return {rows,scope:rows[0].scope,financeDays,appointments:sum(rows.map(r=>r.appointments.scheduled_count)),completed:sum(rows.map(r=>r.appointments.completed_count)),revenue:financeDays===rows.length?sum(rows.map(r=>r.finance!.revenue_xaf)):null,sales:financeDays===rows.length?sum(rows.map(r=>r.finance!.confirmed_sales_count)):null,uncosted:financeDays===rows.length?sum(rows.map(r=>r.finance!.uncosted_sales_count)):null,clocks:rows.every(r=>r.personal_clock_events!==null)?sum(rows.map(r=>r.personal_clock_events!.event_count)):null};
}
export function briefingPeriodCsv(report:ReturnType<typeof summarizeBriefingPeriod>){
 const rows=report.rows;const site=report.scope==="site";
 const header=["date","appointments","completed","personal_clock_events",...(site?["revenue_xaf","confirmed_sales","uncosted_sales"]:[])];
 return [header,...rows.map(r=>[r.day,r.appointments.scheduled_count,r.appointments.completed_count,r.personal_clock_events?.event_count??"",...(site?[r.finance?.revenue_xaf??"",r.finance?.confirmed_sales_count??"",r.finance?.uncosted_sales_count??""]:[])])].map(r=>r.join(",")).join("\r\n")+"\r\n";
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
type Archive={id:string;scope:"site"|"personal";period_start:string;period_end:string;created_at:string};
function validateArchive(value:unknown):Archive{
 const v=value as Archive,valid=(s:string)=>typeof s==="string"&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&Number.isFinite(Date.parse(s))&&new Date(s+"T00:00:00Z").toISOString().slice(0,10)===s;
 if(!v||typeof v.id!=="string"||!/^[0-9a-f-]{36}$/i.test(v.id)||!["site","personal"].includes(v.scope)||!valid(v.period_start)||!valid(v.period_end)||v.period_start>v.period_end||(Date.parse(v.period_end)-Date.parse(v.period_start))/86400000>365||typeof v.created_at!=="string"||!Number.isFinite(Date.parse(v.created_at)))throw Error("INVALID_ARCHIVE");return v;
}
const archiveLabels:Record<Lang,string[]>={
 fr:["Archives du bilan","Archiver la période","Charger les archives","Ouvrir","Supprimer","Seules les journées terminées peuvent être archivées.","Archive indisponible"],
 en:["Report archives","Archive period","Load archives","Open","Delete","Only completed days can be archived.","Archive unavailable"],
 "ff-CM":["Rese jaŋtol","Resnu sahaa","Loow rese","Uddit","Momtu","Balɗe timmuɗe tan mbaawi resneede.","Rese heɓotaako"],
 es:["Archivos del informe","Archivar período","Cargar archivos","Abrir","Eliminar","Solo se pueden archivar días terminados.","Archivo no disponible"],
 it:["Archivio resoconti","Archivia periodo","Carica archivio","Apri","Elimina","Solo i giorni conclusi possono essere archiviati.","Archivio non disponibile"],
 "zh-CN":["报告档案","归档期间","加载档案","打开","删除","只能归档已结束的日期。","档案不可用"]
};
function BriefingArchives({account,siteId,authEndpoint,anonKey,getToken,day,lang,report}:Props&{day:string;lang:Lang;report:ReturnType<typeof summarizeBriefingPeriod>|null}){
 const [archives,setArchives]=useState<Archive[]|null>(null),[opened,setOpened]=useState<ReturnType<typeof summarizeBriefingPeriod>|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const ctl=useRef<AbortController|null>(null),alive=useRef(false),retry=useRef<{key:string;id:string}|null>(null);
 const [title,save,load,open,remove,hint,unavailable]=archiveLabels[lang],t=copy[lang];
 useEffect(()=>{alive.current=true;const hide=()=>{if(document.visibilityState==="hidden"){ctl.current?.abort();ctl.current=null;setArchives(null);setOpened(null);setBusy(false);setError(false);}};document.addEventListener("visibilitychange",hide);return()=>{alive.current=false;ctl.current?.abort();document.removeEventListener("visibilitychange",hide);};},[]);
 async function act(action:"list"|"save"|"open"|"delete",id?:string){
  if(ctl.current||document.visibilityState==="hidden")return;
  const c=new AbortController();ctl.current=c;setBusy(true);setError(false);setOpened(null);
  const current=()=>alive.current&&ctl.current===c&&!c.signal.aborted&&document.visibilityState!=="hidden";
  const rpc=(name:string,body:object={})=>privateRequest<unknown>(c.signal,current,getToken,(jwt,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/"+name,{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+jwt,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,...body}),signal,cache:"no-store",credentials:"omit",redirect:"error"}));
  try{
   if(action==="save"){
    if(!report||day>=briefingDateBounds().today)throw Error("ARCHIVE_CURRENT_DAY");
    const start=report.rows[0].day,end=report.rows[report.rows.length-1].day,key=start+":"+end+":"+report.scope;
    if(retry.current?.key!==key)retry.current={key,id:crypto.randomUUID()};
    const a=validateArchive(await rpc("ns_archive_briefing",{p_id:retry.current.id,p_start:start,p_end:end}));
    if(a.id!==retry.current.id||a.scope!==report.scope||a.period_start!==start||a.period_end!==end)throw Error("INVALID_ARCHIVE_RECEIPT");if(current())retry.current=null;
   }else if(action==="delete"){if(await rpc("ns_delete_briefing_archive",{p_id:id})!==true)throw Error("INVALID_ARCHIVE_RECEIPT");}
   else if(action==="open"){
    const raw=await rpc("ns_read_briefing_archive",{p_id:id}) as Archive&{snapshot:unknown[]};const a=validateArchive(raw);
    if(a.id!==id||!Array.isArray(raw.snapshot))throw Error("INVALID_ARCHIVE_RECEIPT");
    const days=(Date.parse(a.period_end)-Date.parse(a.period_start))/86400000+1;
    const dates=Array.from({length:days},(_,i)=>new Date(Date.parse(a.period_start)+i*86400000).toISOString().slice(0,10));
    const result=summarizeBriefingPeriod(dates,raw.snapshot);if(result.scope!==a.scope)throw Error("INVALID_ARCHIVE_SCOPE");if(current())setOpened(result);
   }
   const list=await rpc("ns_list_briefing_archives");if(!Array.isArray(list)||list.length>100)throw Error("INVALID_ARCHIVE_LIST");
   const rows=list.map(validateArchive);if(new Set(rows.map(r=>r.id)).size!==rows.length)throw Error("INVALID_ARCHIVE_LIST");if(current())setArchives(rows);
  }catch{if(current()){setOpened(null);setArchives(null);setError(true);}}finally{if(current()){ctl.current=null;setBusy(false);}}
 }
 return <section aria-label={title} aria-busy={busy}><h3>{title}</h3><p>{hint}</p><button className="btn secondary" disabled={busy||!report||day>=briefingDateBounds().today} onClick={()=>void act("save")}>{save}</button><button className="btn secondary" disabled={busy} onClick={()=>void act("list")}>{load}</button>{error&&<p role="alert">{unavailable}</p>}{archives?.map(a=><article key={a.id} data-archive-id={a.id}><strong>{a.period_start} — {a.period_end}</strong><p>{new Date(a.created_at).toLocaleString(lang==="ff-CM"?"fr-CM":lang,{timeZone:"Africa/Douala"})}</p><button disabled={busy} onClick={()=>void act("open",a.id)}>{open}</button><button disabled={busy} onClick={()=>{if(window.confirm(remove+" ?"))void act("delete",a.id);}}>{remove}</button></article>)}{opened&&<div data-archive-opened={opened.rows.length}><p>{t.appointments}: {opened.appointments} · {t.completed}: {opened.completed}</p>{opened.scope==="site"&&opened.revenue!==null&&<p>{t.finance}: {opened.revenue}</p>}<button className="btn secondary" onClick={()=>downloadLocal(briefingPeriodCsv(opened),"naxa-archive.csv","text/csv;charset=utf-8")}>CSV</button></div>}</section>;
}
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
   const dates=briefingPeriodDays(day,days);
   const values=await privateRequest<unknown>(c.signal,current,getToken,(token,signal)=>fetch(rosterApiOrigin(authEndpoint)+"/rest/v1/rpc/ns_briefing_period",{method:"POST",headers:{apikey:anonKey,Authorization:"Bearer "+token,"Content-Type":"application/json"},body:JSON.stringify({p_org:account.organization_id,p_site:siteId,p_start:dates[0],p_end:dates[dates.length-1]}),signal,cache:"no-store",credentials:"omit",redirect:"error"}));
   if(!Array.isArray(values))throw Error("INVALID_BRIEFING_PERIOD");
   const result=summarizeBriefingPeriod(dates,values);
   if(current())setReport(result);
  }catch{if(current()){setReport(null);setError(true);c.abort();controller.current=null;setBusy(false);}}
  finally{if(current())setBusy(false);}
 }
 return <section aria-label={title} aria-busy={busy}><h3>{title}</h3><p>{note}</p>
 <label>{duration}<select value={days} disabled={busy} onChange={e=>{clear();setDays(Number(e.target.value));}}>{[1,2,7,30,366].map(d=><option key={d} value={d}>{d===366?({fr:"Année à la date choisie",en:"Year to selected date","ff-CM":"Hitaande haa ñalnde suɓaande",es:"Año hasta la fecha",it:"Anno fino alla data","zh-CN":"年初至所选日期"})[lang]:d+" "+unit}</option>)}</select></label>
 <button className="btn secondary" disabled={busy||!briefingDayAllowed(day)} onClick={()=>void load()}>{calculate}</button>
 {error&&<p role="alert">{unavailable}</p>}
 {report&&<div data-briefing-period-result={report.rows.length}><button type="button" className="btn secondary" onClick={()=>downloadLocal(briefingPeriodCsv(report),"naxa-bilan-"+day+".csv","text/csv;charset=utf-8")}>{({fr:"Exporter le bilan CSV",en:"Export report CSV","ff-CM":"Yaltin jaŋtol CSV",es:"Exportar informe CSV",it:"Esporta resoconto CSV","zh-CN":"导出 CSV 报告"})[lang]}</button><p>{report.rows[0].day} — {report.rows[report.rows.length-1].day}</p>
 <p>{t.appointments}: {report.appointments} · {t.completed}: {report.completed}</p>
 {report.scope==="site"&&<p>{report.revenue===null?missing:revenue+": "+report.revenue} ({report.financeDays}/{report.rows.length} {unit})</p>}
 {report.clocks!==null&&<p>{t.clocks}: {report.clocks}</p>}
 <BriefingQuestions key={lang+":"+report.rows[0].day+":"+report.rows.length} report={report} lang={lang}/>
 <ul>{report.rows.map(r=><li key={r.day}>{r.day} · {t.appointments}: {r.appointments.scheduled_count} · {t.completed}: {r.appointments.completed_count}{r.finance!==null?" · "+revenue+": "+r.finance.revenue_xaf:""}</li>)}</ul></div>}{import.meta.env.VITE_NAXA_SERVICES_BRIEFING_ARCHIVE_ENABLED==="true"&&<BriefingArchives account={account} siteId={siteId} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken} day={day} lang={lang} report={report}/>}</section>;
}
export function DailyBriefing(props:Props){
 return <ScopedDailyBriefing key={JSON.stringify([props.account.organization_id,props.account.member_id,props.account.role_code,props.siteId,props.authEndpoint,props.anonKey])} {...props}/>;
}
function ScopedDailyBriefing({account,siteId,authEndpoint,anonKey,getToken}:Props){
 const [lang,setLang]=useState<Lang>(account.default_locale);
 const [detailed,setDetailed]=useState(true);
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
  stop();setError(false);const u=new SpeechSynthesisUtterance(briefingNarration(r,lang,detailed));u.voice=voice;u.lang=voice.lang;u.rate=speed;audio.current=u;
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
 <label>{({fr:"Présentation du bilan",en:"Report detail","ff-CM":"Feere jaŋtol",es:"Detalle del informe",it:"Dettaglio resoconto","zh-CN":"报告详细程度"})[lang]}<select value={detailed?"detail":"summary"} disabled={loading} onChange={e=>{stop();setDetailed(e.target.value==="detail");}}><option value="summary">{({fr:"Résumé",en:"Summary","ff-CM":"Tonngol",es:"Resumen",it:"Sintesi","zh-CN":"摘要"})[lang]}</option><option value="detail">{({fr:"Détaillé",en:"Detailed","ff-CM":"Humpito timmungo",es:"Detallado",it:"Dettagliato","zh-CN":"详细"})[lang]}</option></select></label>
 {error&&<p role="alert">{t.unavailable}</p>}{report&&<p>{briefingNarration(report,lang,detailed)}</p>}<BriefingReminders account={account} siteId={siteId} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken} lang={lang}/><PeriodBriefing key={day} account={account} siteId={siteId} authEndpoint={authEndpoint} anonKey={anonKey} getToken={getToken} day={day} lang={lang}/></section>;
}
