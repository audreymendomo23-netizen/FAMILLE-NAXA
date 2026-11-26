import React,{useEffect,useState,useRef} from "react";
type Props={call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean};
export function ContainerWorkspace({call,disabled,en}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [d,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 const [side,S]=useState("supplier"),[party,P]=useState(""),[label,L]=useState(""),[deposit,DE]=useState("0"),[account,A]=useState(""),[kind,K]=useState("issued"),[quantity,Q]=useState(""),[reason,R]=useState("");
 const key=useRef<{body:string,id:string}|null>(null);
 const lock=disabled||busy;
 async function load(){D(await call("container_snapshot"))}
 async function run(fn:()=>Promise<void>){if(lock)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{let live=true;call("container_snapshot").then(v=>{if(live)D(v)}).catch(()=>{if(live)E("OPERATION_UNAVAILABLE")});return()=>{live=false}},[]);
 return <section><h4>{t("Consignes et emballages","Returnable packaging")}</h4><p>{t("Suivi physique des emballages à rendre. La valeur de référence n'est ni une dette comptabilisée ni un remboursement.","Physical tracking of returnable packaging. Reference value is not a posted debt or refund.")}</p>
 {error&&<p role="alert">{error}</p>}<button disabled={lock} onClick={()=>run(load)}>{t("Actualiser les consignes","Refresh containers")}</button>
 <label>{t("Contrepartie","Counterparty")}<select value={side} onChange={e=>{S(e.target.value);P("")}}><option value="supplier">{t("Fournisseur","Supplier")}</option><option value="customer">{t("Client","Customer")}</option></select></label>
 <label>{t("Fiche de contrepartie","Counterparty record")}<select aria-label={t("Fiche de contrepartie","Counterparty record")} value={party} onChange={e=>P(e.target.value)}><option value="">—</option>{(side==="supplier"?d?.suppliers??[]:d?.customers??[]).map((x:any)=><option key={x.id} value={x.id}>{x.name}</option>)}</select></label>
 <label>{t("Type d'emballage","Packaging type")}<input value={label} onChange={e=>L(e.target.value)}/></label>
 <label>{t("Valeur unitaire de référence FCFA","Reference unit value XAF")}<input type="number" min="0" value={deposit} onChange={e=>DE(e.target.value)}/></label>
 <button disabled={lock||!party||!label.trim()||deposit===""} onClick={()=>run(async()=>{const id=await call("container_account",{supplier_id:side==="supplier"?party:null,customer_id:side==="customer"?party:null,label,unit_deposit_xaf:Number(deposit)});A(id);L("");await load()})}>{t("Créer le suivi de consigne","Create packaging account")}</button>
 {(d?.accounts??[]).map((x:any)=><p key={x.id}>{x.counterparty} · {x.label} · {x.outstanding} {t("à rendre","outstanding")} · {x.reference_exposure_xaf} FCFA</p>)}
 <label>{t("Emballage suivi","Packaging account")}<select aria-label={t("Emballage suivi","Packaging account")} value={account} onChange={e=>A(e.target.value)}><option value="">—</option>{(d?.accounts??[]).map((x:any)=><option key={x.id} value={x.id}>{x.label} · {x.counterparty}</option>)}</select></label>
 <label>{t("Mouvement","Movement")}<select value={kind} onChange={e=>K(e.target.value)}><option value="issued">{t("Mis en circulation / reçu du fournisseur","Issued / received from supplier")}</option><option value="returned">{t("Rendu","Returned")}</option><option value="lost">{t("Perdu / cassé","Lost / broken")}</option></select></label>
 <label>{t("Quantité","Quantity")}<input type="number" min="1" value={quantity} onChange={e=>Q(e.target.value)}/></label>
 <label>{t("Motif","Reason")}<input maxLength={500} value={reason} onChange={e=>R(e.target.value)}/></label>
 <button disabled={lock||!account||!quantity||(kind==="lost"&&reason.trim().length<5)} onClick={()=>run(async()=>{const body={account_id:account,kind,qty:Number(quantity),reason},encoded=JSON.stringify(body);if(key.current?.body!==encoded)key.current={body:encoded,id:crypto.randomUUID()};await call("container_move",{...body,request_id:key.current.id});key.current=null;Q("");R("");await load()})}>{t("Enregistrer le mouvement","Record movement")}</button>
 {(d?.events??[]).map((x:any)=><p key={x.id}>{x.kind} · {x.qty} · {x.reason}</p>)}
 </section>
}
