import React,{useState,useEffect} from "react";
import {estimateDailyReceipts,recoverySignals} from "./pilotage.mjs";
type Props={call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean};
const fmt=(v:number|null)=>v==null?"—":new Intl.NumberFormat("fr-CM").format(v)+" FCFA";
export function PilotageWorkspace({call,disabled,en}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const day=new Intl.DateTimeFormat("sv-SE",{timeZone:"Africa/Douala"}).format(new Date());
 const [start,S]=useState(day.slice(0,7)+"-01"),[end,EN]=useState(day),[data,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 async function load(){if(disabled||busy)return;B(true);E("");D(null);try{D(await call("pilotage",{start,end}))}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{void load()},[]);
 const forecast=data?estimateDailyReceipts(data):null;
 const labels:Record<string,string>={STOCK:t("Contrôler les matières au seuil","Review ingredients at reorder threshold"),LATE:t("Examiner les commandes en retard","Review overdue orders"),COST:t("Compléter les coûts manquants","Complete missing sale costs"),CASH:t("Examiner les écarts de caisse","Review cash variances")};
 return <section><h3>{t("Pilotage et recommandations","Performance and recommendations")}</h3>
 <label>{t("Début de période","Period start")}<input type="date" value={start} max={day} onChange={e=>{S(e.target.value);D(null)}}/></label><label>{t("Fin de période","Period end")}<input type="date" value={end} max={day} onChange={e=>{EN(e.target.value);D(null)}}/></label>
 <button disabled={disabled||busy||!start||!end||start>end} onClick={load}>{t("Calculer les indicateurs","Calculate metrics")}</button>
 {error&&<p role="alert">{error}</p>}{data&&<>
 <p>{data.start} — {data.end} · Africa/Douala</p>
 <div className="business-panel"><strong>{t("Ventes enregistrées","Recorded sales")}</strong>{fmt(data.recorded_xaf)} · {data.receipts} {t("reçus","receipts")}</div>
 <p>{t("Remboursements enregistrés","Recorded refunds")} : {fmt(data.refunds_xaf??0)}</p><p>{t("Ventes nettes des remboursements","Sales net of refunds")} : {fmt(data.recorded_xaf-(data.refunds_xaf??0))}</p><p>{t("Encaissements bruts","Gross collections")} : {fmt(data.collected_xaf??data.recorded_xaf)}</p><p>{t("Coût des ventes connu","Known sale cost")} : {fmt(data.known_cost_xaf)}</p><p>{t("Marge sur ventes brutes avant remboursements","Margin on gross sales before refunds")} : {fmt(data.gross_margin_xaf)}</p>
 {data.uncosted_receipts>0&&<p>{data.uncosted_receipts} {t("reçus sans coût complet : marge non calculable.","receipts without full cost: margin unavailable.")}</p>}
 <p>{t("Charges enregistrées","Recorded expenses")} : {fmt(data.expenses_xaf)}</p><p>{t("Avis clients","Customer reviews")} : {data.feedback_average??"—"}/5 · {data.feedback_count} {t("avis","reviews")}</p>
 {data.feedback_count<10&&<p>{t("Échantillon insuffisant pour classer les performances.","Insufficient sample for ranking performance.")}</p>}
 <h4>{t("Ventes par poste","Sales by station")}</h4>{data.posts.map((p:any)=><p key={p.post}>{p.post} · {fmt(p.recorded_xaf)} · {p.portions} {t("portions","portions")}</p>)}
 <h4>{t("Projection indicative","Indicative projection")}</h4>{forecast?<p>{fmt(forecast.daily_xaf)} / {t("jour — moyenne des 28 jours précédents comportant des reçus. Ce n'est pas un objectif ni une garantie.","day — mean of preceding 28 days with receipts. Not a target or guarantee.")}</p>:<p>{t("Historique insuffisant : 28 jours consécutifs avec ventes enregistrées requis.","Insufficient history: 28 consecutive days with recorded sales required.")}</p>}
 <h4>{t("Points de vigilance","Review signals")}</h4>{recoverySignals(data).map(x=><p key={x.code}>{labels[x.code]} : {x.value}</p>)}<p>{t("Règles explicables, sans décision automatique. Stocks et retards représentent l'état courant ; autres chiffres limités à la période choisie.","Explainable rules, no automatic decision. Stock and overdue orders are current; other figures use the chosen period.")}</p></>}
 </section>
}
