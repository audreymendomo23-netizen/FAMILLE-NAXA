import React,{useEffect,useState,useRef} from "react";
type Props={call:(a:string,b?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean;refresh:()=>Promise<void>};
export function SupplierReturns({call,disabled,en,refresh}:Props){
 const t=(a:string,b:string)=>en?b:a,[d,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 const [receipt,R]=useState(""),[purchase,P]=useState(""),[qty,Q]=useState(""),[amount,A]=useState(""),[method,M]=useState("bank"),[reference,RF]=useState(""),[reason,RS]=useState("");
 const keys=useRef<Record<string,{body:string,id:string}>>({});const lock=disabled||busy;
 async function load(){D(await call("supplier_return_snapshot"))}
 useEffect(()=>{load().catch(e=>E(String(e.message??e)))},[]);
 async function run(action:string,body:Record<string,unknown>){if(lock)return;B(true);E("");try{const s=JSON.stringify(body);if(keys.current[action]?.body!==s)keys.current[action]={body:s,id:crypto.randomUUID()};await call(action,{...body,request_id:keys.current[action].id});delete keys.current[action];R("");P("");Q("");A("");RF("");RS("");await load();await refresh()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 const selected=d?.receipts.find((x:any)=>x.id===receipt),credit=d?.credits.find((x:any)=>x.id===purchase);
 const q=/^\d{1,7}(\.\d{1,3})?$/.test(qty)?Math.round(Number(qty)*1000):NaN,v=/^\d{1,10}$/.test(amount)?Number(amount):NaN,valid=reference.trim().length>=4&&reason.trim().length>=5;
 return <section><h4>{t("Retours et avoirs fournisseurs","Supplier returns and credits")}</h4>{error&&<p role="alert">{error}</p>}{d?.can_write&&<fieldset disabled={lock}><legend>{t("Retour accepté par le fournisseur","Supplier-accepted return")}</legend>
 <label>{t("Réception d'origine","Original receipt")}<select value={receipt} onChange={e=>R(e.target.value)}><option value="">—</option>{d.receipts.map((x:any)=><option key={x.id} value={x.id}>{x.reference} · {x.lot_label} · {x.remaining_milli/1000}</option>)}</select></label>
 <label>{t("Quantité retournée","Returned quantity")}<input value={qty} inputMode="decimal" onChange={e=>Q(e.target.value)}/></label>
 <label>{t("Référence de l'avoir ou du remboursement","Credit or refund reference")}<input value={reference} onChange={e=>RF(e.target.value)}/></label><label>{t("Motif et preuve","Reason and evidence")}<input value={reason} onChange={e=>RS(e.target.value)}/></label>
 <button disabled={!selected||!valid||!(q>0&&q<=Number(selected.remaining_milli))} onClick={()=>run("supplier_return",{receipt_id:receipt,expected_milli:Number(selected.remaining_milli),qty_milli:q,reference,reason})}>{t("Confirmer le retour valorisé","Confirm valued return")}</button>
 <h5>{t("Remboursement déjà reçu (aucun transfert)","Refund already received (no transfer)")}</h5><label>{t("Avoir à recouvrer","Supplier credit receivable")}<select value={purchase} onChange={e=>P(e.target.value)}><option value="">—</option>{d.credits.map((x:any)=><option key={x.id} value={x.id}>{x.reference} · {x.credit_xaf} FCFA</option>)}</select></label>
 <label>{t("Montant reçu FCFA","Received XAF")}<input value={amount} inputMode="numeric" onChange={e=>A(e.target.value)}/></label><label>{t("Moyen","Method")}<select value={method} onChange={e=>M(e.target.value)}>{["bank","cash","mtn_momo","orange_money","card"].map(x=><option key={x}>{x}</option>)}</select></label>
 <button disabled={!credit||!valid||!(v>0&&v<=Number(credit.credit_xaf))} onClick={()=>run("supplier_refund",{purchase_id:purchase,amount_xaf:v,method,reference,reason})}>{t("Enregistrer le remboursement","Record refund")}</button></fieldset>}
 {(d?.returns??[]).map((x:any)=><p key={x.id}>{x.reference} · {x.qty_milli/1000} · {x.cost_xaf} FCFA</p>)}{(d?.refunds??[]).map((x:any)=><p key={x.id}>{x.reference} · {x.amount_xaf} FCFA · {x.method}</p>)}</section>
}
