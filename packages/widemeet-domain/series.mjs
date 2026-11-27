// Bounded enterprise calendar series in UTC; no hidden DST adjustment.
export function seriesDates(start,kind,count,interval=1){
 if(!Number.isSafeInteger(start)||start<0||!["daily","weekly","monthly"].includes(kind)||!Number.isInteger(count)||count<2||count>12||!Number.isInteger(interval)||interval<1||interval>12)throw Error("invalid_series");
 const d=new Date(start);if(!Number.isFinite(d.getTime()))throw Error("invalid_series");
 return Array.from({length:count},(_,i)=>{
  const date=new Date(start);
  if(kind==="daily"||kind==="weekly")date.setUTCDate(d.getUTCDate()+i*interval*(kind==="weekly"?7:1));
  else {date.setUTCDate(1);date.setUTCMonth(d.getUTCMonth()+i*interval);const last=new Date(Date.UTC(date.getUTCFullYear(),date.getUTCMonth()+1,0)).getUTCDate();date.setUTCDate(Math.min(d.getUTCDate(),last));}
  const value=date.getTime();if(!Number.isSafeInteger(value))throw Error("invalid_series");return value;
 });
}
