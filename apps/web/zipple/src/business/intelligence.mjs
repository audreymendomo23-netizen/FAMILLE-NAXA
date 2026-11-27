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

/** Estimate material cost using only the visible, non-expired lots, not a full production quote. */
export function recipePlan(erp,catalog,weighted,itemId,portions,change,today,now){
 if(!Array.isArray(erp?.recipes)||!Array.isArray(erp?.ingredients)||!Array.isArray(erp?.lots)||!Array.isArray(catalog?.items)||!Array.isArray(weighted?.rules)||!Number.isInteger(portions)||portions<1||portions>10000||!Number.isInteger(change)||change< -100||change>500||!Number.isFinite(dayNumber(today))||!Number.isFinite(now))return null;
 const item=catalog.items.find(i=>i.id===itemId),components=erp.recipes.filter(c=>c.item_id===itemId);
 if(!item||!components.length||weighted.rules.some(r=>r.item_id===itemId))return null;
 const detail=[];let total=0;let complete=true;
 for(const c of components){
  const ingredient=erp.ingredients.find(i=>i.id===c.ingredient_id);
  if(!ingredient||!whole(c.qty_milli)||c.qty_milli===0||!whole(ingredient.available_milli))return null;
  const needed=c.qty_milli*portions;if(!Number.isSafeInteger(needed))return null;
  const lots=erp.lots.filter(l=>l.ingredient_id===c.ingredient_id&&whole(l.remaining_milli)&&l.remaining_milli>0&&whole(l.remaining_cost)&&(!l.expires_on||Number.isFinite(dayNumber(l.expires_on))&&l.expires_on>=today)&&(!l.usable_until||Number.isFinite(Date.parse(l.usable_until))&&Date.parse(l.usable_until)>now));
  const available=lots.reduce((n,l)=>n+l.remaining_milli,0),cost=lots.reduce((n,l)=>n+l.remaining_cost,0);
  const reliable=Number.isSafeInteger(available)&&Number.isSafeInteger(cost)&&available===ingredient.available_milli&&available>=needed&&available>0;
  const estimate=reliable?cost/available*needed:null;
  if(estimate===null)complete=false;else total+=estimate;
  detail.push({id:ingredient.id,name:ingredient.name,unit:ingredient.unit,needed,available:ingredient.available_milli,shortage:Math.max(0,needed-ingredient.available_milli),estimate:estimate===null?null:Math.round(estimate)});
 }
 const historical=(Array.isArray(erp.batches)?erp.batches:[]).filter(b=>b.item_id===itemId&&whole(b.cost_xaf)&&whole(b.servings)&&b.servings>0).sort((x,y)=>String(y.created_at).localeCompare(String(x.created_at)))[0];
 const valid=complete&&Number.isSafeInteger(Math.round(total))&&Number.isSafeInteger(Math.round(total*(1+change/100)));
 const price=whole(item.price_xaf)?item.price_xaf:null;
 return {detail,basePrice:price,materialCost:valid?Math.round(total):null,unitCost:valid?Math.round(total/portions):null,scenarioUnit:valid?Math.round(total*(1+change/100)/portions):null,historicalUnit:historical?Math.round(historical.cost_xaf/historical.servings):null,historicalDate:historical?.created_at??null};
}
export function wasteSummary(expiry,braise,procurement,start,end){
 if(!Number.isFinite(dayNumber(start))||!Number.isFinite(dayNumber(end))||start>end)return null;
 const inPeriod=x=>{const timestamp=Date.parse(x);if(!Number.isFinite(timestamp))return false;const local=new Date(timestamp+3600000).toISOString().slice(0,10);return local>=start&&local<=end};
 const expired=Array.isArray(expiry?.losses)?expiry.losses.filter(x=>inPeriod(x.created_at)&&whole(x.loss_cost)&&whole(x.servings)):null;
 // Braise yields aggregate losses over their entire life, not loss-event date; do not label as period losses.
 const yields=Array.isArray(braise?.yields)?braise.yields.filter(x=>whole(x.loss_cost)&&whole(x.discarded_servings)):null;
 const atRisk=Array.isArray(expiry?.batches)?expiry.batches.filter(b=>b.expired===true&&whole(b.remaining_cost_xaf)&&whole(b.remaining_servings)):null;
 return {expired:expired?{count:expired.length,servings:expired.reduce((a,b)=>a+b.servings,0),cost:expired.reduce((a,b)=>a+b.loss_cost,0)}:null,
 braise:yields?{servings:yields.reduce((a,b)=>a+b.discarded_servings,0),cost:yields.reduce((a,b)=>a+b.loss_cost,0)}:null,
 atRisk:atRisk?{count:atRisk.length,cost:atRisk.reduce((a,b)=>a+b.remaining_cost_xaf,0)}:null,
 inventory:whole(procurement?.loss_cost_xaf)?procurement.loss_cost_xaf:null};
}
export function workforceDay(planning,day){
 if(!Array.isArray(planning?.rows)||!Number.isFinite(dayNumber(day)))return null;
 const start=Date.parse(day+"T00:00:00+01:00"),end=start+86400000;
 const shifts=planning.rows.filter(r=>["open","in_progress","done"].includes(r.state)&&r.assignee_id&&Number.isFinite(Date.parse(r.starts_at))&&Number.isFinite(Date.parse(r.due_at))&&Date.parse(r.starts_at)<end&&Date.parse(r.due_at)>start&&Date.parse(r.due_at)>Date.parse(r.starts_at));
 const hours=Array.from({length:24},(_,h)=>({hour:h,staff:new Set(shifts.filter(r=>Date.parse(r.starts_at)<start+(h+1)*3600000&&Date.parse(r.due_at)>start+h*3600000).map(r=>r.assignee_id)).size}));
 return {shifts:shifts.length,people:new Set(shifts.map(r=>r.assignee_id)).size,hours};
}
export function anomalyReview(metrics){
 if(!metrics)return null;
 const rows=[];
 for(const [key,code,unit] of [["absolute_cash_variance_xaf","CASH","XAF"],["refunds_xaf","REFUNDS","XAF"],["credit_notes_xaf","CREDIT_NOTES","XAF"],["uncosted_receipts","COST","count"],["current_late_orders","LATE","count"]]){
  const value=metrics[key];rows.push({code,unit,value:whole(value)?value:null});
 }
 return rows;
}
