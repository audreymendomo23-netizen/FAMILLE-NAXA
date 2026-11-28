// Only confirmed, non-provisional summaries. A missing day is never a zero sale.
export function activitySeries(daily){
 const byDay=new Map();
 for(const row of Array.isArray(daily)?daily:[]){
  if(typeof row?.service_day!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(row.service_day)||!Number.isSafeInteger(row.version)||row.version<1)continue;
  if(!byDay.has(row.service_day)||byDay.get(row.service_day).version<row.version)byDay.set(row.service_day,row);
 }
 return [...byDay.values()].filter(row=>row.data?.provisional===false&&typeof row.data.ca==='number'&&Number.isFinite(row.data.ca)).sort((a,b)=>a.service_day.localeCompare(b.service_day)).slice(-7).map(row=>({day:row.service_day,ca:row.data.ca}));
}
