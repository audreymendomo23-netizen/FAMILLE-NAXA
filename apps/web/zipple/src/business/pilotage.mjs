// Adapted from NAXA Services PerformanceEngine.kt: avg28 and remaining-days projection.
// Only complete observed days with confirmed receipts are used. No zero imputation.
export function estimateDailyReceipts(snapshot){
 const history=snapshot?.history_28;
 if(!Array.isArray(history)||history.length!==28||typeof snapshot.today!=="string")return null;
 const today=Date.parse(snapshot.today+"T00:00:00Z");if(!Number.isFinite(today))return null;
 const days=new Map();
 for(const row of history){
  if(typeof row.day!=="string"||!Number.isSafeInteger(row.recorded_xaf)||row.recorded_xaf<0||days.has(row.day))return null;
  days.set(row.day,row.recorded_xaf);
 }
 let total=0;
 for(let i=1;i<=28;i++){const day=new Date(today-i*86400000).toISOString().slice(0,10);if(!days.has(day))return null;total+=days.get(day);if(!Number.isSafeInteger(total))return null}
 return {daily_xaf:Math.round(total/28),days:28,method:"mean_28_recorded_days"};
}
export function recoverySignals(s){
 const out=[];
 if(s.current_low_stock>0)out.push({code:"STOCK",value:s.current_low_stock});
 if(s.current_late_orders>0)out.push({code:"LATE",value:s.current_late_orders});
 if(s.uncosted_receipts>0)out.push({code:"COST",value:s.uncosted_receipts});
 if(s.absolute_cash_variance_xaf>0)out.push({code:"CASH",value:s.absolute_cash_variance_xaf});
 return out;
}
