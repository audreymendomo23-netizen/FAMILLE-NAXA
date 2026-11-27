import {ConvertedPurchases} from "./ConvertedPurchases";
import {InventoryGains} from "./InventoryGains";
import {resolveInventoryScan} from "./inventory-scan";
import {SupplierReturns} from "./SupplierReturns";
import {downloadPurchaseOrder,purchaseWhatsAppLink,type PurchaseOrderDocument} from "./PurchaseOrderDocument";
import React,{useEffect,useState,useRef} from "react";
// Adaptation of NAXA Services StockOperationsPage: server-confirmed supplier, purchase, receipt, payment.
type Props={ingredients:any[];lots:any[];call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean;refreshStock:()=>Promise<void>;queueErp?:(action:string,payload:Record<string,unknown>)=>Promise<void>};
const money=(n:number)=>new Intl.NumberFormat("fr-CM").format(n)+" FCFA";
const qty=(n:number)=>String(n/1000);
function milli(v:string){if(!/^\d{1,9}(\.\d{1,3})?$/.test(v))throw Error("INVALID_QUANTITY");return Math.round(Number(v)*1000)}
function amount(v:string){if(!/^\d{1,10}$/.test(v)||Number(v)>2147483647)throw Error("INVALID_AMOUNT");return Number(v)}
export function ProcurementWorkspace({ingredients,lots,call,disabled,en,refreshStock,queueErp}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [data,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 const [name,N]=useState(""),[phone,P]=useState(""),[wa,W]=useState(""),[terms,TE]=useState("30");
 const [supplier,SU]=useState(""),[ingredient,I]=useState(""),[ref,R]=useState(""),[quantity,Q]=useState(""),[total,TO]=useState("");
 const [draftLines,DL]=useState<{ingredient_id:string;qty_milli:number;total_xaf:number}[]>([]);
 const [purchaseSearch,PS]=useState(""),[receiptFilter,RF]=useState("all");
 const [purchase,PU]=useState(""),[received,RE]=useState(""),[lot,L]=useState(""),[expiry,EX]=useState("");
 const [payment,PA]=useState(""),[method,ME]=useState("bank"),[paymentRef,PR]=useState("");
 const [lotId,LI]=useState(""),[count,CO]=useState(""),[reason,RS]=useState(""),[scan,SC]=useState("");
 function selectScan(){const id=resolveInventoryScan(scan,lots,ingredients);LI(id??"");CO("");RS("");E(id?"":t("Code inconnu ou ambigu : sélectionnez le lot manuellement.","Unknown or ambiguous code: select the batch manually."));if(id)SC("")}
 const pending=useRef<Record<string,{body:string,id:string}>>({});
 async function idem(action:string,body:Record<string,unknown>){const payload=JSON.stringify(body);if(pending.current[action]?.body!==payload)pending.current[action]={body:payload,id:crypto.randomUUID()};const v=await call(action,{...body,request_id:pending.current[action].id});delete pending.current[action];return v}
 async function load(){D(await call("procurement_snapshot"))}
 async function run(fn:()=>Promise<void>){if(disabled||busy)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{let live=true;call("procurement_snapshot").then(v=>{if(live)D(v)}).catch(()=>{if(live)E("OPERATION_UNAVAILABLE")});return()=>{live=false}},[]);
 const suppliers:any[]=data?.suppliers??[],purchases:any[]=data?.purchases??[];const selected=purchases.find(x=>x.id===purchase),selectedLot=lots.find(x=>x.id===lotId);
 const batches:any[]=data?.batches??[];
 function purchaseLabel(x:any){const b=batches.find(g=>g.purchase_ids.includes(x.id));return b?b.reference+" / "+(b.purchase_ids.indexOf(x.id)+1)+" · "+(ingredients.find(i=>i.id===x.ingredient_id)?.name??"") :x.reference}
 const lock=disabled||busy;
 const remaining=selected?Number(selected.qty_milli)-Number(selected.received_milli):0;
 const receiptValid=!!selected&&Number.isSafeInteger(remaining)&&remaining>0&&(()=>{try{const q=milli(received);return Number.isSafeInteger(q)&&q>0&&q<=remaining&&q<=1000000000}catch{return false}})();
 const filteredPurchases=purchases.filter(x=>{const rest=Number(x.qty_milli)-Number(x.received_milli);return (receiptFilter==="all"||(receiptFilter==="pending"?rest>0:rest===0))&&[purchaseLabel(x),suppliers.find(y=>y.id===x.supplier_id)?.name].some(v=>String(v??"").toLocaleLowerCase().includes(purchaseSearch.trim().toLocaleLowerCase()))});
 const visiblePurchases=selected&&!filteredPurchases.some(x=>x.id===selected.id)?[selected,...filteredPurchases]:filteredPurchases;
 const selectedSupplier=suppliers.find(x=>x.id===selected?.supplier_id);
 const selectedBatch=batches.find(b=>b.purchase_ids.includes(purchase));
 const documentRows=selectedBatch?selectedBatch.purchase_ids.map((id:string)=>purchases.find(x=>x.id===id)):selected?[selected]:[];
 const document:PurchaseOrderDocument|null=selectedSupplier&&documentRows.length&&documentRows.every((x:any)=>x&&x.supplier_id===selectedSupplier.id&&ingredients.some(i=>i.id===x.ingredient_id))?{reference:selectedBatch?.reference??selected.reference,supplier:selectedSupplier.name,lines:documentRows.map((x:any)=>{const i=ingredients.find(v=>v.id===x.ingredient_id);return {name:i.name,unit:i.unit,qtyMilli:Number(x.qty_milli),totalXaf:Number(x.total_xaf),receivedMilli:Number(x.received_milli)}})}:null;
 const whatsappLink=(()=>{try{return document?purchaseWhatsAppLink(selectedSupplier.whatsapp,document,en):null}catch{return null}})();
 return <section>
 <h4>{t("Fournisseurs, achats et inventaires","Suppliers, purchases and inventory counts")}</h4>
 {error&&<p role="alert">{t("Opération non confirmée : ","Operation unconfirmed: ")}{error}</p>}
 {data&&<><p>{t("Dette fournisseur enregistrée","Recorded supplier debt")} : {money(data.debt_xaf)}</p><p>{t("Avoirs fournisseurs à recouvrer","Supplier credits receivable")} : {money(data.supplier_receivable_xaf??0)}</p><p>{t("Pertes valorisées","Recorded inventory losses")} : {money(data.loss_cost_xaf)}</p></>}
 <button disabled={lock} onClick={()=>run(async()=>{await load();await refreshStock()})}>{t("Actualiser les achats","Refresh purchases")}</button>
 <h4>{t("Fiche fournisseur","Supplier record")}</h4>
 <label>{t("Nom du fournisseur","Supplier name")}<input value={name} onChange={e=>N(e.target.value)}/></label>
 <label>{t("Téléphone fournisseur","Supplier phone")}<input value={phone} onChange={e=>P(e.target.value)}/></label>
 <label>WhatsApp<input value={wa} onChange={e=>W(e.target.value)}/></label>
 <label>{t("Délai de règlement (jours)","Payment terms (days)")}<input type="number" min="0" max="365" value={terms} onChange={e=>TE(e.target.value)}/></label>
 <button disabled={lock||name.trim().length<2} onClick={()=>run(async()=>{await call("supplier_add",{name,phone,whatsapp:wa.replace(/\D/g,""),terms_days:amount(terms)});N("");await load()})}>{t("Créer le fournisseur","Create supplier")}</button>
 <h4>{t("Commande d'achat","Purchase order")}</h4>
 <label>{t("Fournisseur de la commande","Purchase supplier")}<select aria-label={t("Fournisseur de la commande","Purchase supplier")} value={supplier} onChange={e=>SU(e.target.value)}><option value="">—</option>{suppliers.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
 <label>{t("Matière commandée","Ordered ingredient")}<select aria-label={t("Matière commandée","Ordered ingredient")} value={ingredient} onChange={e=>I(e.target.value)}><option value="">—</option>{ingredients.map(x=><option key={x.id} value={x.id}>{x.name} ({x.unit})</option>)}</select></label>
 <label>{t("Référence de commande","Purchase reference")}<input value={ref} onChange={e=>R(e.target.value)}/></label>
 <label>{t("Quantité commandée","Ordered quantity")}<input inputMode="decimal" value={quantity} onChange={e=>Q(e.target.value)}/></label>
 <label>{t("Coût total commandé FCFA","Purchase total XAF")}<input inputMode="numeric" value={total} onChange={e=>TO(e.target.value)}/></label>
 <button disabled={lock||!ingredient||!quantity||!total||draftLines.length>=49} onClick={()=>{try{const q=milli(quantity),v=amount(total);if(q<1||q>1000000000||v<1)throw Error("INVALID_QUANTITY");DL([...draftLines,{ingredient_id:ingredient,qty_milli:q,total_xaf:v}]);I("");Q("");TO("");E("")}catch(e){E(e instanceof Error?e.message:"INVALID_QUANTITY")}}}>{t("Ajouter une autre ligne","Add another line")}</button>
 {draftLines.map((x,i)=><p key={i}>{ingredients.find(v=>v.id===x.ingredient_id)?.name} · {qty(x.qty_milli)} · {money(x.total_xaf)} <button disabled={lock} onClick={()=>DL(draftLines.filter((_,j)=>j!==i))}>{t("Retirer","Remove")} {i+1}</button></p>)}
 <button disabled={lock||!supplier||!ingredient||!ref||!quantity||!total} onClick={()=>run(async()=>{const line={ingredient_id:ingredient,qty_milli:milli(quantity),total_xaf:amount(total)};if(draftLines.length){const group=await idem("purchase_batch_create",{supplier_id:supplier,reference:ref,lines:[...draftLines,line]});PU(group.purchase_ids[0]);DL([])}else{const id=await idem("purchase_create",{supplier_id:supplier,reference:ref,...line});PU(id)}R("");Q("");TO("");await load()})}>{t("Créer la commande","Create purchase")}</button>
 {batches.map(b=><p key={b.id}>{b.reference} · {b.purchase_ids.length} {t("lignes","lines")} · {money(b.total_xaf)} · {t("Dette","Debt")} : {money(b.debt_xaf??(b.received_cost-b.paid_xaf))}</p>)}
 <h4>{t("Réception et règlement","Receipt and payment")}</h4>
 <label>{t("Rechercher une commande fournisseur","Search supplier purchases")}<input aria-label={t("Rechercher une commande fournisseur","Search supplier purchases")} maxLength={160} value={purchaseSearch} onChange={e=>{PS(e.target.value);PU("");RE("");PA("")}}/></label><label>{t("État de réception","Receipt status")}<select aria-label={t("État de réception","Receipt status")} value={receiptFilter} onChange={e=>{RF(e.target.value);PU("");RE("");PA("")}}><option value="all">{t("Toutes","All")}</option><option value="pending">{t("À réceptionner","Pending receipt")}</option><option value="complete">{t("Réceptionnées","Received")}</option></select></label><p>{filteredPurchases.length} / {purchases.length} {t("lignes reçues du serveur","lines received from server")}</p><label>{t("Commande à traiter","Purchase to process")}<select aria-label={t("Commande à traiter","Purchase to process")} value={purchase} onChange={e=>PU(e.target.value)}><option value="">—</option>{visiblePurchases.map(x=><option key={x.id} value={x.id}>{purchaseLabel(x)}</option>)}</select></label>
 {selected&&<p>{t("Reste à réceptionner","Remaining to receive")} : {qty(remaining)}</p>}{selected&&<p>{t("Reçu","Received")} : {qty(selected.received_milli)}/{qty(selected.qty_milli)} · {t("Reste à régler","Outstanding")} : {money(Math.max(0,selected.net_balance_xaf??(selected.received_cost-selected.paid_xaf)))}</p>}
 {document&&<div><button disabled={lock} onClick={()=>run(async()=>{await downloadPurchaseOrder(document,en)})}>{t("Télécharger le bon de commande PDF","Download purchase order PDF")}</button>{whatsappLink&&!lock&&<a href={whatsappLink} target="_blank" rel="noopener noreferrer">{t("Préparer le message WhatsApp fournisseur","Prepare supplier WhatsApp message")}</a>}<p>{t("Le message est préparé seulement. Vérifiez le destinataire et envoyez-le dans WhatsApp ; aucun envoi automatique.","Message prepared only. Check recipient and send in WhatsApp; no automatic delivery.")}</p></div>}
 <label>{t("Quantité réceptionnée","Quantity received")}<input inputMode="decimal" value={received} onChange={e=>RE(e.target.value)}/></label>
 <label>{t("Lot de réception","Receipt lot")}<input value={lot} onChange={e=>L(e.target.value)}/></label>
 <label>{t("Péremption du lot","Lot expiry")}<input type="date" value={expiry} onChange={e=>EX(e.target.value)}/></label>
 <button disabled={lock||!receiptValid||!lot.trim()} onClick={()=>run(async()=>{await idem("purchase_receive",{purchase_id:purchase,qty_milli:milli(received),label:lot,expires_on:expiry||null});RE("");L("");await load();await refreshStock()})}>{t("Confirmer la réception","Confirm receipt")}</button>
 <p>{t("Règlement externe déjà effectué ; aucun débit API.","External payment already made; no API debit.")}</p>
 <label>{t("Montant du règlement FCFA","Payment amount XAF")}<input inputMode="numeric" value={payment} onChange={e=>PA(e.target.value)}/></label>
 <label>{t("Moyen de règlement fournisseur","Supplier payment method")}<select value={method} onChange={e=>ME(e.target.value)}>{["bank","cash","mtn_momo","orange_money","card"].map(x=><option key={x}>{x}</option>)}</select></label>
 <label>{t("Référence du règlement","Payment reference")}<input value={paymentRef} onChange={e=>PR(e.target.value)}/></label>
 <button disabled={lock||!purchase||!payment||paymentRef.length<4} onClick={()=>run(async()=>{await idem("supplier_pay",{purchase_id:purchase,amount_xaf:amount(payment),method,reference:paymentRef});PA("");PR("");await load()})}>{t("Enregistrer le règlement","Record payment")}</button>
 <h4>{t("Comptage physique par lot","Physical lot count")}</h4>
 <label>{t("Scanner le code du lot ou SKU","Scan batch code or SKU")}<input value={scan} maxLength={100} onChange={e=>SC(e.target.value)} onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();if(!busy)selectScan()}}}/></label><button disabled={busy||!scan.trim()} onClick={selectScan}>{t("Identifier le lot","Identify batch")}</button>
 <label>{t("Lot à inventorier","Lot to count")}<select aria-label={t("Lot à inventorier","Lot to count")} value={lotId} onChange={e=>{LI(e.target.value);CO("")}}><option value="">—</option>{lots.map(x=><option key={x.id} value={x.id}>{x.lot_label} · {qty(x.remaining_milli)}</option>)}</select></label>
 {selectedLot&&<p>{t("Quantité attendue","Expected quantity")} : {qty(selectedLot.remaining_milli)}</p>}
 <label>{t("Quantité physique comptée","Physical count")}<input inputMode="decimal" value={count} onChange={e=>CO(e.target.value)}/></label>
 <label>{t("Motif du comptage","Count reason")}<input value={reason} onChange={e=>RS(e.target.value)}/></label>
 <button disabled={lock||!selectedLot||count===""||reason.trim().length<5} onClick={()=>run(async()=>{await idem("count_lot",{lot_id:lotId,expected_milli:Number(selectedLot.remaining_milli),counted_milli:milli(count),reason});CO("");RS("");await load();await refreshStock()})}>{t("Valider le comptage","Confirm count")}</button>{queueErp&&<button disabled={busy||!selectedLot||count===""||reason.trim().length<5} onClick={async()=>{B(true);E("");try{const q=milli(count);if(q>Number(selectedLot.remaining_milli))throw Error("COUNT_REQUIRES_REVIEW");await queueErp("count_lot",{lot_id:lotId,expected_milli:Number(selectedLot.remaining_milli),counted_milli:q,reason:reason.trim()});CO("");RS("");E(t("Comptage en attente de validation serveur.","Count awaiting server confirmation."))}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}}>{t("Mettre le comptage en attente hors connexion","Queue count offline")}</button>}
 <SupplierReturns call={call} disabled={lock} en={en} refresh={async()=>{await load();await refreshStock()}}/>
 <ConvertedPurchases call={call} disabled={lock} en={en} refresh={async()=>{await load();await refreshStock()}}/>
 <InventoryGains call={call} disabled={lock} en={en} lot={selectedLot} refresh={async()=>{await load();await refreshStock()}}/>
 </section>
}
