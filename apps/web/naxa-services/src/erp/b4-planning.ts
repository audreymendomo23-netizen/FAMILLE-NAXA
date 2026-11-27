// Keep the recurring charge's contractual amount separate from each payment.
export function mergeB4Data(prior:Record<string,unknown>|undefined, payload:Record<string,unknown>, result:Record<string,unknown>, action:unknown):Record<string,unknown>{
 const next={...prior,...payload};
 if(action==="recurring_charge.payment_recorded"){
  if(typeof prior?.amount_xaf==="number")next.amount_xaf=prior.amount_xaf;
  else delete next.amount_xaf;
  next.last_payment_xaf=payload.amount_xaf;
  // No speculative change of due date or balance before a server receipt.
  if(typeof result.next_due_at==="string")next.next_due_at=result.next_due_at;
  if(typeof result.active==="boolean")next.active=result.active;
  if(typeof result.remaining_xaf==="number"&&typeof result.next_due_at==="string"){
   const sameDue=Date.parse(result.next_due_at)===Date.parse(String(payload.reference_due_at));
   if(result.active===false)next.remaining_xaf=0;
   else if(sameDue)next.remaining_xaf=result.remaining_xaf;
   else if(typeof next.amount_xaf==="number")next.remaining_xaf=next.amount_xaf;
   else delete next.remaining_xaf;
  }
 }else if(action==="recurring_charge.saved"){
  if(prior&& (prior.next_due_at!==payload.next_due_at||prior.amount_xaf!==payload.amount_xaf))delete next.remaining_xaf;
  if(typeof result.active==="boolean")next.active=result.active;
 }else if(action==="recurring_charge.deactivated"&&typeof result.active==="boolean"){
  next.active=result.active;
 }
 if(typeof result.paid_xaf==="number")next.paid_xaf=result.paid_xaf;
 return next;
}
export function staleChargeReceipt(action:unknown,prior:Record<string,unknown>|undefined,recordedAt:unknown,cursor?:unknown):boolean{
 if(typeof action!=="string"||!action.startsWith("recurring_charge."))return false;
 if(typeof cursor==="number"&&Number.isSafeInteger(cursor)&&cursor>0&&typeof prior?.server_sync_cursor==="number"&&Number.isSafeInteger(prior.server_sync_cursor))return cursor<prior.server_sync_cursor;
 if(typeof recordedAt!=="string"||typeof prior?.server_recorded_at!=="string")return false;
 const previous=Date.parse(prior.server_recorded_at),incoming=Date.parse(recordedAt);
 return Number.isFinite(previous)&&Number.isFinite(incoming)&&incoming<previous;
}
export function objectivePeriod(period:string,now=new Date()){
 const p=new Intl.DateTimeFormat("en-CA",{timeZone:"Africa/Douala",year:"numeric",month:"2-digit",day:"2-digit"}).formatToParts(now);
 const v=(key:string)=>Number(p.find(x=>x.type===key)?.value);
 const y=v("year"),m=v("month")-1,d=v("day");
 if(!["daily","monthly","annual"].includes(period))throw Error("Période invalide");
 const start=new Date(Date.UTC(y,period==="annual"?0:m,period==="daily"?d:1));
 const endExclusive=new Date(period==="annual"?Date.UTC(y+1,0,1):period==="monthly"?Date.UTC(y,m+1,1):Date.UTC(y,m,d+1));
 const end=new Date(endExclusive.getTime()-86400000);
 return {period_start:start.toISOString().slice(0,10),period_end:end.toISOString().slice(0,10),due_at:new Date(endExclusive.getTime()-3600001).toISOString()};
}

// The atomic RPC receipt includes a commit-ordered cursor, even when it omits recorded_at.
export function chargeReceiptCursor(action:unknown,cursor:unknown):Record<string,unknown>{return typeof action==="string"&&action.startsWith("recurring_charge.")&&typeof cursor==="number"&&Number.isSafeInteger(cursor)&&cursor>0?{server_sync_cursor:cursor}:{};}
