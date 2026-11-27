// Local, deterministic query interpretation. No generative provider and no external personal data.
const normalize=q=>String(q).normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().trim();
export function questionTopic(question){
 const q=normalize(question);
 if(!q||q.length>300)return null;
 if(/\b(modifier|supprimer|payer|effacer|annuler|delete|change|pay|cancel|ignore|password|secret|token|mot de passe)\b/.test(q))return null;
 const match=[["group",/\b(multisite|multi.site|groupe|group|consolidation|consolide)\b/],["cash",/\b(caisse|cash|encaissements?|collections?)\b/],["feedback",/\b(avis|satisfaction|feedback|reviews?)\b/],["stock",/\b(stock|stocks|ruptures?|inventory)\b/],["credit",/\b(creances?|ardoises?|debt|receivables?)\b/],["margin",/\b(marge|marges|margin|profit|couts?|costs?)\b/],["sales",/\b(ventes?|sales|revenu|revenue|chiffre d.affaires|ca)\b/]].filter(([,r])=>r.test(q));
 return match.length===1?match[0][0]:null;
}
export function answerRows(topic,source){
 const fields={sales:["recorded_xaf","refunds_xaf","credit_notes_xaf","receipts"],cash:["collected_xaf","absolute_cash_variance_xaf"],margin:["known_cost_xaf","gross_margin_xaf","uncosted_receipts","expenses_xaf"],stock:["current_low_stock"],credit:["due","late","count"],feedback:["feedback_count","feedback_average"],group:["sites_included","sites_total","revenue_xaf","expenses_xaf","result_xaf","unclassified","pending_sources","unknown_cost_receipts"]}[topic];
 if(!fields)return [];
 return fields.map(key=>{const v=source?.[key];return {key,value:typeof v==="number"&&Number.isFinite(v)||typeof v==="string"&&/^-?\d+(?:\.\d+)?$/.test(v)?String(v):null}});
}
export function feedbackReasons(metrics){
 if(!Array.isArray(metrics?.feedback_reasons))return null;
 const allowed=new Set(["wait","accuracy","quality","temperature","presentation","welcome","other"]);
 return metrics.feedback_reasons.filter(r=>allowed.has(r.reason)&&Number.isSafeInteger(r.count)&&r.count>0).sort((a,b)=>b.count-a.count||a.reason.localeCompare(b.reason));
}
export function extractDocument(text){
 const lines=String(text).slice(0,12000).split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
 const totals=[];
 for(const line of lines){
  const m=line.match(/^(?:TOTAL\s*(?:TTC|A PAYER|À PAYER)?|NET\s*(?:A|À)\s*PAYER|AMOUNT\s*DUE|GRAND\s*TOTAL)\s*[:=]?\s*([\d][\d .\u00a0\u202f]*)(?:\s*(?:FCFA|XAF|F CFA))?\s*$/i);
  if(m){const raw=m[1].trim();if(/\.\d{1,2}$/.test(raw))continue;const n=Number(raw.replace(/[ .\u00a0\u202f]/g,""));if(Number.isSafeInteger(n)&&n>0&&n<=2147483647)totals.push(n)}
 }
 const refs=lines.flatMap(l=>{const m=l.match(/^(?:FACTURE|INVOICE|BON|REFERENCE|RÉFÉRENCE|REF)\s*(?:N[°ºo.]?\s*)?[:#]?\s*([A-Z0-9][A-Z0-9/_-]{3,79})$/i);return m?[m[1]]:[]});
 const dates=lines.flatMap(l=>{const m=l.match(/^DATE\s*[:]?\s*(\d{4}-\d{2}-\d{2})$/i);if(!m)return [];const n=Date.parse(m[1]+"T00:00:00Z");return Number.isFinite(n)&&new Date(n).toISOString().slice(0,10)===m[1]?[m[1]]:[]});
 const unique=a=>[...new Set(a)];return {amount:unique(totals).length===1?String(totals[0]):"",reference:unique(refs).length===1?refs[0]:"",date:unique(dates).length===1?dates[0]:"",ambiguous:unique(totals).length>1};
}
