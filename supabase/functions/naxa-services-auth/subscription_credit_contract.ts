type Channel = "mtn_momo" | "orange_money";
export type CreditProof = {ref:string;amount:number;payer:string;destination:string;occurredAt:string};
export function parseSubscriptionCredit(sms:unknown,channel:Channel,destination:string,capturedAt:string):CreditProof|null {
 if(typeof sms!=="string"||sms.length<12||sms.length>8000)return null;
 const t=sms.normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/\s+/g," ").trim();
 const captured=new Date(capturedAt);if(!Number.isFinite(captured.getTime()))return null;
 let ref:string|undefined, amount:string|undefined,payer:string|undefined,occurredAt=captured.toISOString();
 if(channel==="mtn_momo"){
  const a=t.match(/(?:vous avez recu|you have received) ([0-9][0-9 .,]*)\s*(?:xaf|fcfa)\s*(?:de|from)\s+.+?\(([0-9]{8,15})\)\s+(?:sur votre compte mobile money|to your mobile money account)\s+(?:a|at)\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/);
  if(!a)return null;
  ref=t.match(/(?:financial transaction id|identifiant de transaction financiere)\s*:\s*([a-z0-9-]+)/)?.[1];
  amount=a[1];payer=a[2];const at=new Date(a[3].replace(" ","T")+"+01:00");if(!Number.isFinite(at.getTime()))return null;occurredAt=at.toISOString();
 }else if(channel==="orange_money"){
  const a=t.match(/payment de ([0-9]{8,15})\s+.+?\s+par ([0-9]{8,15})\s+.+?\s+reussi[.]?\s+informations detaillees:\s*id transaction:\s*([a-z0-9.]+),\s*montant transaction:\s*([0-9][0-9 .,]*)\s*fcfa/);
  if(!a||a[1].slice(-9)!==destination.slice(-9))return null;
  payer=a[2];ref=a[3];amount=a[4];
 }else return null;
 const normalized=(ref??"").toUpperCase().replace(/[^A-Z0-9]/g,"");const number=Number((amount??"").replace(/\D/g,""));const phone=(payer??"").slice(-9);
 if(normalized.length<6||normalized.length>100||!Number.isSafeInteger(number)||number<=0||!/^6\d{8}$/.test(phone))return null;
 return {ref:normalized,amount:number,payer:phone,destination,occurredAt};
}
