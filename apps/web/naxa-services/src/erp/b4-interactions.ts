export type B4Record={id:string;title:string;state:string;status?:string;revision?:number;aggregateType?:string;siteId?:string;data?:Record<string,unknown>};
export const confirmed=(r:B4Record)=>r.state==="Confirmé"||r.state==="Confirmé · autre appareil";
export function transferScope(r:B4Record,site:string,canManage:boolean,allowed:string[]){
 const d=r.data??{},source=String(d.source_site_id??""),destination=String(d.destination_site_id??"");
 if(!canManage||!confirmed(r)||!Number.isSafeInteger(r.revision)||(r.revision??0)<1||source===destination||!allowed.includes(source)||!allowed.includes(destination))return [];
 if(r.status==="open"&&site===source)return ["approved","rejected"];
 if(r.status==="approved"&&site===destination)return ["received"];
 return [];
}
export function transferSnapshot(r:B4Record){
 const d=r.data??{},source=d.source_site_id,destination=d.destination_site_id,item=d.inventory_item_id,sku=d.sku_snapshot,unit=d.unit,quantity=Number(d.quantity);
 if(typeof source!=="string"||typeof destination!=="string"||source===destination||typeof item!=="string"||typeof sku!=="string"||!sku.trim()||typeof unit!=="string"||!unit.trim()||!Number.isFinite(quantity)||quantity<=0)throw Error("Données du transfert incomplètes.");
 return {transfer_id:r.id,source_site_id:source,destination_site_id:destination,inventory_item_id:item,sku_snapshot:sku.trim().toUpperCase(),unit,quantity};
}
export function rewardRows(entries:B4Record[],site:string){
 const redeemed=new Set(entries.filter(r=>r.aggregateType==="loyalty_reward"&&confirmed(r)&&r.data?.reward_event_id===r.id).map(r=>r.id));
 const pending=new Set(entries.filter(r=>r.aggregateType==="loyalty_reward"&&!confirmed(r)&&r.state.startsWith("En attente")).map(r=>r.id));
 const out=new Map<string,{id:string;customerId:string;programId:string;wave:number;description:string;redeemed:boolean;pending:boolean}>();
 for(const r of entries){
  if(r.aggregateType!=="loyalty_activity"||!confirmed(r)||r.siteId!==site)continue;
  const d=r.data??{},result=d.server_result as Record<string,unknown>|undefined;
  if(typeof d.customer_id!=="string"||typeof d.program_id!=="string"||!Array.isArray(result?.reward_events))continue;
  for(const v of result.reward_events){if(!v||typeof v!=="object"||typeof v.event_id!=="string"||!Number.isSafeInteger(v.wave_number)||v.reward_status!=="available")continue;
   out.set(v.event_id,{id:v.event_id,customerId:d.customer_id,programId:d.program_id,wave:v.wave_number,description:String(v.description??""),redeemed:redeemed.has(v.event_id),pending:pending.has(v.event_id)});
  }
 }
 return [...out.values()];
}
