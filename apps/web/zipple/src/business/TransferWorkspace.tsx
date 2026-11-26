import React,{useEffect,useRef,useState} from "react";
import {PreparedTransferWorkspace} from "./PreparedTransferWorkspace";
// Reuses the NAXA Services stock movement form pattern; all effects are server confirmed.
type Props={ingredients:any[];lots:any[];call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean;refreshStock:()=>Promise<void>};
const milli=(v:string)=>{if(!/^\d{1,7}(\.\d{1,3})?$/.test(v))throw Error("INVALID_QUANTITY");return Math.round(Number(v)*1000)};
export function TransferWorkspace({ingredients,lots,call,disabled,en,refreshStock}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [data,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 const [dest,DE]=useState(""),[lot,L]=useState(""),[item,I]=useState(""),[qty,Q]=useState("");
 const [receive,RE]=useState<Record<string,string>>({}),[reason,RS]=useState<Record<string,string>>({});
 const key=useRef<{body:string,id:string}|null>(null);
 const lock=disabled||busy;const srcLot=lots.find(l=>l.id===lot),srcIngredient=ingredients.find(i=>i.id===srcLot?.ingredient_id);
 const destinations:any[]=data?.sites??[],destination=destinations.find(x=>x.id===dest);
 const matching=(destination?.ingredients??[]).filter((i:any)=>srcIngredient?.sku&&i.sku===srcIngredient.sku&&i.unit===srcIngredient.unit);
 async function load(){D(await call("transfer_snapshot"))}
 async function run(fn:()=>Promise<void>){if(lock)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{let live=true;call("transfer_snapshot").then(v=>{if(live)D(v)}).catch(e=>{if(live)E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")});return()=>{live=false}},[]);
 return <section><h4>{t("Transferts inter-établissements","Inter-site transfers")}</h4><p>{t("Premium : transfert de matières par lot entre établissements autorisés, sans vente.","Premium: lot transfer between authorized sites, without a sale.")}</p>
 {error&&<p role="alert">{error==="PREMIUM_REQUIRED"?t("Offre Premium requise.","Premium plan required."):error}</p>}
 <button disabled={lock} onClick={()=>run(async()=>{await load();await refreshStock()})}>{t("Actualiser les transferts","Refresh transfers")}</button>
 {data&&<>
 <label>{t("Lot source","Source lot")}<select aria-label={t("Lot source","Source lot")} value={lot} onChange={e=>{L(e.target.value);I("")}}><option value="">—</option>{lots.filter(l=>l.remaining_milli>0).map(l=><option key={l.id} value={l.id}>{l.lot_label} · {l.remaining_milli/1000}</option>)}</select></label>
 <label>{t("Établissement destinataire","Destination site")}<select aria-label={t("Établissement destinataire","Destination site")} value={dest} onChange={e=>{DE(e.target.value);I("")}}><option value="">—</option>{destinations.map(s=><option key={s.id} value={s.id}>{s.name}</option>)}</select></label>
 <label>{t("Matière correspondante","Matching ingredient")}<select aria-label={t("Matière correspondante","Matching ingredient")} value={item} onChange={e=>I(e.target.value)}><option value="">—</option>{matching.map((i:any)=><option key={i.id} value={i.id}>{i.name} · {i.sku} · {i.unit}</option>)}</select></label>
 <label>{t("Quantité à transférer","Transfer quantity")}<input inputMode="decimal" value={qty} onChange={e=>Q(e.target.value)}/></label>
 <button disabled={lock||!lot||!dest||!item||!qty} onClick={()=>run(async()=>{const body={source_lot:lot,destination_site:dest,destination_ingredient:item,qty_milli:milli(qty)},encoded=JSON.stringify(body);if(key.current?.body!==encoded)key.current={body:encoded,id:crypto.randomUUID()};await call("transfer_request",{...body,request_id:key.current.id});key.current=null;Q("");await load()})}>{t("Demander le transfert","Request transfer")}</button>
 {(data.transfers??[]).map((x:any)=><div className="business-panel" key={x.id}><strong>{x.id.slice(0,8)} · {x.qty_milli/1000} · {x.state}</strong><p>{x.source_site===data.site_id?t("Sortant","Outgoing"):t("Entrant","Incoming")}</p>
 {x.source_site===data.site_id&&x.state==="requested"&&<button disabled={lock} onClick={()=>run(async()=>{await call("transfer_decide",{transfer_id:x.id,decision:"approved"});await load()})}>{t("Approuver","Approve")}</button>}
 {x.source_site===data.site_id&&["requested","approved"].includes(x.state)&&<button disabled={lock} onClick={()=>run(async()=>{await call("transfer_decide",{transfer_id:x.id,decision:"cancelled"});await load()})}>{t("Annuler","Cancel")}</button>}
 {x.source_site===data.site_id&&x.state==="approved"&&<button disabled={lock} onClick={()=>run(async()=>{await call("transfer_dispatch",{transfer_id:x.id});await load();await refreshStock()})}>{t("Confirmer le départ","Confirm dispatch")}</button>}
 {x.destination_site===data.site_id&&x.state==="in_transit"&&<><label>{t("Quantité reçue","Received quantity")}<input inputMode="decimal" value={receive[x.id]??String(x.qty_milli/1000)} onChange={e=>RE(v=>({...v,[x.id]:e.target.value}))}/></label><label>{t("Motif d'écart","Discrepancy reason")}<input maxLength={500} value={reason[x.id]??""} onChange={e=>RS(v=>({...v,[x.id]:e.target.value}))}/></label><button disabled={lock} onClick={()=>run(async()=>{await call("transfer_receive",{transfer_id:x.id,qty_milli:milli(receive[x.id]??String(x.qty_milli/1000)),reason:reason[x.id]??""});await load();await refreshStock()})}>{t("Confirmer la réception","Confirm receipt")}</button></>}
 {x.state==="received"&&<p>{t("Reçu","Received")} : {x.received_milli/1000} · {t("Écart valorisé","Valued discrepancy")} : {x.transferred_cost-x.received_cost} FCFA</p>}
 </div>)}
 </>}
 <PreparedTransferWorkspace call={call} disabled={disabled} en={en} refreshStock={refreshStock}/>
 </section>
}
