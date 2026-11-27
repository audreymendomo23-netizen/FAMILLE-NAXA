import React,{useEffect,useRef,useState} from "react";
import {downloadCsv} from "./accounting/exports";
type Props={call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean};
const today=()=>new Intl.DateTimeFormat("sv-SE",{timeZone:"Africa/Douala"}).format(new Date());
export function TaxWorkspace({call,disabled,en}:Props){
 const t=(a:string,b:string)=>en?b:a,[data,D]=useState<any>(null),[report,R]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 const [item,I]=useState(""),[category,C]=useState(""),[rate,T]=useState(""),[evidence,V]=useState(""),[effective,EF]=useState(today),[from,F]=useState(today().slice(0,4)+"-01-01"),[to,TO]=useState(today);
 const pending=useRef<{id:string,body:string}|null>(null);
 async function load(){D(await call("tax_snapshot"))}
 useEffect(()=>{load().catch(e=>E(String(e.message??e)))},[]);
 const lock=disabled||busy||!data;const selected=data?.items.find((x:any)=>x.id===item);
 async function run(fn:()=>Promise<void>){if(lock)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 const bps=/^\d{1,5}$/.test(rate)?Number(rate):NaN;
 const rows=report?[[t("Début","From"),report.from],[t("Fin","To"),report.to],[t("Ventes brutes FCFA","Gross sales XAF"),report.gross_xaf],[t("Reçus non couverts","Uncovered receipts"),report.missing_receipts],[t("Lignes non classées","Unclassified lines"),report.unclassified_lines],[t("Ajustements non ventilés","Unallocated adjustments"),report.unallocated_adjustments_xaf],[t("État de gestion uniquement","Management report only")],[t("Catégorie","Category"),t("Taux (points de base)","Rate (basis points)"),t("TTC FCFA","Gross XAF"),t("HT FCFA","Net XAF"),t("Taxe FCFA","Tax XAF")],...report.categories.map((x:any)=>[x.category??t("Non classé","Unclassified"),x.rate_bps??"",x.gross_xaf,x.net_xaf??"",x.tax_xaf??""])]:[];
 return <section><h4>{t("Fiscalité de gestion — prix TTC","Management tax — gross-inclusive prices")}</h4><p>{t("Aucun taux par défaut. Un comptable doit valider les règles. Les états ne constituent pas une déclaration réglementaire.","No default rate. An accountant must approve the rules. Reports are not statutory filings.")}</p>{error&&<p role="alert">{error}</p>}
 <label>{t("Article","Item")}<select value={item} onChange={e=>I(e.target.value)}><option value="">—</option>{(data?.items??[]).map((x:any)=><option key={x.id} value={x.id}>{x.name} · V{x.version}</option>)}</select></label>
 <label>{t("Catégorie fiscale","Tax category")}<input value={category} onChange={e=>C(e.target.value)}/></label>
 <label>{t("Taux en points de base (100 = 1 %)","Rate in basis points (100 = 1%)")}<input inputMode="numeric" value={rate} onChange={e=>T(e.target.value)}/></label>
 <label>{t("Date d'effet","Effective date")}<input type="date" min={today()} value={effective} onChange={e=>EF(e.target.value)}/></label><label>{t("Référence de validation comptable","Accounting approval reference")}<input value={evidence} onChange={e=>V(e.target.value)}/></label>
 <button disabled={lock||!selected||!category.trim()||!(bps>=0&&bps<=10000)||!effective||effective<today()||evidence.trim().length<5} onClick={()=>run(async()=>{const body={item_id:item,expected_version:selected.version,category,rate_bps:bps,valid_from:effective,validation_reference:evidence},s=JSON.stringify(body);if(pending.current?.body!==s)pending.current={body:s,id:crypto.randomUUID()};await call("tax_rule_set",{...body,request_id:pending.current.id});pending.current=null;V("");await load()})}>{t("Valider la règle fiscale","Approve tax rule")}</button>
 {(data?.rules??[]).map((x:any)=><p key={x.id}>{x.name} · V{x.version} · {x.category} · {x.rate_bps/100}% · {x.valid_from}</p>)}
 <label>{t("Début","From")}<input type="date" value={from} onChange={e=>{F(e.target.value);R(null)}}/></label><label>{t("Fin","To")}<input type="date" value={to} onChange={e=>{TO(e.target.value);R(null)}}/></label><button disabled={lock||!from||!to||from>to||to>today()} onClick={()=>run(async()=>R(await call("tax_report",{from,to})))}>{t("Calculer l'état fiscal de gestion","Calculate management tax report")}</button>
 {report&&<><p>{t("Ventes brutes","Gross sales")} : {report.gross_xaf} FCFA · {t("Reçus non couverts","Uncovered receipts")} : {report.missing_receipts} · {t("Lignes non classées","Unclassified lines")} : {report.unclassified_lines}</p><p>{t("Ajustements non ventilés","Unallocated adjustments")} : {report.unallocated_adjustments_xaf} FCFA</p>{report.categories.map((x:any,i:number)=><p key={i}>{x.category??t("Non classé","Unclassified")} · {x.rate_bps==null?"—":x.rate_bps/100+"%"} · TTC {x.gross_xaf} · HT {x.net_xaf??"—"} · {t("Taxe","Tax")} {x.tax_xaf??"—"}</p>)}<button onClick={()=>downloadCsv("zipple-fiscalite-gestion.csv",rows)}>{t("Exporter le relevé de gestion CSV","Export management CSV")}</button></>}
 </section>
}
