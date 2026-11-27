// Read-only planning on authorized ZIPPLE snapshots. No external AI, no automatic writes.
const whole=v=>typeof v==="number"&&Number.isSafeInteger(v)&&v>=0;
const dayNumber=s=>typeof s==="string"&&/^\d{4}-\d{2}-\d{2}$/.test(s)?Date.parse(s+"T00:00:00Z")/86400000:NaN;
export function stockPlan(erp,today,days=7){
 const now=dayNumber(today);if(!Array.isArray(erp?.ingredients)||!Array.isArray(erp?.lots)||!Number.isFinite(now)||!Number.isInteger(days)||days<0||days>30)return null;
 const items=new Map(erp.ingredients.map(i=>[i.id,i]));
 const reorder=erp.ingredients.filter(i=>whole(i.available_milli)&&whole(i.reorder_milli)&&i.available_milli<=i.reorder_milli).map(i=>({id:i.id,name:i.name,unit:i.unit,available:i.available_milli,threshold:i.reorder_milli,shortfall:Math.max(0,i.reorder_milli-i.available_milli)}));
 const expiring=erp.lots.flatMap(l=>{const i=items.get(l.ingredient_id);if(!i||!whole(l.remaining_milli)||l.remaining_milli===0)return [];const date=dayNumber(l.expires_on);const timed=typeof l.usable_until==="string"?Date.parse(l.usable_until):NaN;const timedDay=Number.isFinite(timed)?Math.floor((timed+3600000)/86400000):Infinity;const expiry=Math.min(Number.isFinite(date)?date:Infinity,timedDay);if(!Number.isFinite(expiry)||expiry>now+days)return [];return [{id:l.id,name:i.name,unit:i.unit,lot:l.lot_label,qty:l.remaining_milli,days:expiry-now}]});
 return {reorder,expiring:expiring.sort((a,b)=>a.days-b.days)};
}
export function priceScenario(cost,price,target){
 if(!whole(cost)||!whole(price)||price===0||cost>2147483647||price>2147483647||!Number.isInteger(target)||target<0||target>=100)return null;
 const suggested=Math.ceil(cost*100/(100-target));
 if(suggested>2147483647)return null;
 return {margin:price-cost,marginPct:Math.round((price-cost)*10000/price)/100,suggested};
}
export function receivables(credit,today){
 if(!Array.isArray(credit?.sales)||!Number.isFinite(dayNumber(today)))return null;
 const open=credit.sales.filter(s=>whole(s.balance_xaf)&&s.balance_xaf>0&&Number.isFinite(dayNumber(s.due_on)));
 return {due:open.filter(s=>s.due_on===today).reduce((a,b)=>a+b.balance_xaf,0),late:open.filter(s=>s.due_on<today).reduce((a,b)=>a+b.balance_xaf,0),count:open.filter(s=>s.due_on<=today).length};
}
export function forecastBacktest(snapshot){
 const today=dayNumber(snapshot?.today),h=snapshot?.history_28;if(!Number.isFinite(today)||!Array.isArray(h)||h.length!==28)return null;
 const map=new Map(h.map(r=>[dayNumber(r.day),r.recorded_xaf]));const values=Array.from({length:28},(_,i)=>map.get(today-28+i));
 if(!values.every(whole))return null;
 let error=0,actual=0;for(let i=7;i<28;i++){const predicted=values.slice(i-7,i).reduce((a,b)=>a+b,0)/7;error+=Math.abs(predicted-values[i]);actual+=values[i]}
 const next=values.slice(-7).reduce((a,b)=>a+b,0)/7;
 if(!Number.isSafeInteger(Math.round(error))||!Number.isSafeInteger(actual))return null;
 return {daily:Math.round(next),mae:Math.round(error/21),wape:actual>0?Math.round(error/actual*1000)/10:null,observations:21};
}
