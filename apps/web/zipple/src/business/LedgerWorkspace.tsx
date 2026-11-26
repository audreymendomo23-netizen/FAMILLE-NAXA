import React,{useState,useEffect,useRef} from "react";
import {calculerBalance} from "./accounting/calculs";
import type {CompteComptable,EcritureComptable} from "./accounting/types";
type Props={call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean};
export function LedgerWorkspace({call,disabled,en}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [data,D]=useState<any>(null),[busy,B]=useState(false),[err,E]=useState("");
 const [code,C]=useState(""),[label,L]=useState(""),[section,S]=useState(""),[source,SO]=useState(""),[journal,J]=useState(""),[debit,DE]=useState(""),[credit,CR]=useState(""),[desc,DS]=useState(""),[date,DT]=useState(""),[reason,R]=useState("");
 const pending=useRef<{body:string,id:string}|null>(null);
 const lock=disabled||busy;
 async function load(){D(await call("ledger_snapshot"))}
 async function run(fn:()=>Promise<void>){if(lock)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{let live=true;call("ledger_snapshot").then(x=>{if(live)D(x)}).catch(()=>{if(live)E(t("Accès comptable indisponible.","Accounting access unavailable."))});return()=>{live=false}},[]);
 const accounts:CompteComptable[]=(data?.accounts??[]).map((x:any)=>({id:x.id,code:x.code,libelle:x.label,sectionEtats:x.section,statut:"valide"}));
 const entries:EcritureComptable[]=(data?.entries??[]).map((x:any)=>({id:x.id,etablissementId:"current",dateEcriture:x.entry_date,journalCode:x.journal_code,libelle:x.label,referenceSource:x.source_id,lignes:[{compteId:x.debit_account,libelle:x.label,debitFcfa:x.amount_xaf,creditFcfa:0},{compteId:x.credit_account,libelle:x.label,debitFcfa:0,creditFcfa:x.amount_xaf}]}));
 const balance=calculerBalance(entries,accounts);
 const event=(data?.pending??[]).find((x:any)=>x.kind+":"+x.source_id===source);
 const kinds:Record<string,string>={sale:t("Vente","Sale"),credit_sale:t("Vente à crédit","Credit sale"),credit_payment:t("Règlement de créance","Credit collection"),sale_cost:t("Coût des ventes","Cost of sales"),purchase_receipt:t("Réception achat","Purchase receipt"),supplier_payment:t("Règlement fournisseur","Supplier payment"),expense:t("Dépense","Expense"),inventory_loss:t("Perte de stock","Inventory loss"),deposit_in:t("Consigne entrante","Deposit inflow"),deposit_out:t("Consigne sortante","Deposit outflow")};
 const money=(v:bigint|string)=>new Intl.NumberFormat("fr-CM").format(BigInt(v))+" FCFA";
 return <section><h4>{t("Journal comptable et balance","Accounting journal and trial balance")}</h4>
 <p>{t("Comptes et affectations validés par le responsable. Aucun compte fiscal ou taux de taxe n'est présumé.","Accounts and postings approved by the owner. No tax account or rate is assumed.")}</p>
 {err&&<p role="alert">{err}</p>}<button disabled={lock} onClick={()=>run(load)}>{t("Actualiser le journal","Refresh journal")}</button>
 {data&&<><p>{t("Événements en attente","Pending source events")} : {data.pending.length} · {t("Ventes au coût inconnu","Sales with unknown cost")} : {data.unknown_cost_receipts}</p>
 <h5>{t("Plan de comptes","Chart of accounts")}</h5><label>{t("Code du compte","Account code")}<input value={code} onChange={e=>C(e.target.value)}/></label><label>{t("Intitulé du compte","Account name")}<input value={label} onChange={e=>L(e.target.value)}/></label><label>{t("Section comptable","Account section")}<input value={section} onChange={e=>S(e.target.value)}/></label><button disabled={lock||!code.trim()||label.trim().length<2||section.trim().length<2} onClick={()=>run(async()=>{await call("ledger_account_add",{code,label,section});C("");L("");S("");await load()})}>{t("Valider le compte","Approve account")}</button>
 {accounts.map(x=><p key={x.id}>{x.code} · {x.libelle} · {x.sectionEtats}</p>)}
 <h5>{t("Comptabiliser une opération confirmée","Post a confirmed operation")}</h5><label>{t("Événement comptable","Accounting event")}<select value={source} onChange={e=>SO(e.target.value)}><option value="">—</option>{data.pending.map((x:any)=><option key={x.kind+":"+x.source_id} value={x.kind+":"+x.source_id}>{kinds[x.kind]??x.kind} · {x.label} · {money(x.amount_xaf)} · {x.entry_date}</option>)}</select></label>
 {event&&<p>{money(event.amount_xaf)} · {event.entry_date}</p>}
 <label>{t("Code journal","Journal code")}<input value={journal} onChange={e=>J(e.target.value)}/></label>
 <label>{t("Compte débit","Debit account")}<select value={debit} onChange={e=>DE(e.target.value)}><option value="">—</option>{accounts.map(x=><option key={x.id} value={x.id}>{x.code} · {x.libelle}</option>)}</select></label>
 <label>{t("Compte crédit","Credit account")}<select value={credit} onChange={e=>CR(e.target.value)}><option value="">—</option>{accounts.map(x=><option key={x.id} value={x.id}>{x.code} · {x.libelle}</option>)}</select></label>
 <label>{t("Libellé de l’écriture","Entry description")}<input value={desc} onChange={e=>DS(e.target.value)}/></label>
 <button disabled={lock||!event||!debit||!credit||debit===credit||!journal.trim()||desc.trim().length<5} onClick={()=>run(async()=>{const body={kind:event.kind,source_id:event.source_id,journal,debit_account:debit,credit_account:credit,label:desc};const encoded=JSON.stringify(body);if(pending.current?.body!==encoded)pending.current={body:encoded,id:crypto.randomUUID()};await call("ledger_post",{...body,request_id:pending.current.id});pending.current=null;SO("");DS("");await load()})}>{t("Valider l’écriture équilibrée","Post balanced entry")}</button>
 <h5>{t("Journal validé","Posted journal")}</h5>{entries.map(x=><div key={x.id}><p>{x.dateEcriture} · {x.journalCode} · {x.libelle}</p>{x.lignes.map((l,i)=><p key={i}>{accounts.find(a=>a.id===l.compteId)?.code} · {t("Débit","Debit")} {money(BigInt(l.debitFcfa))} · {t("Crédit","Credit")} {money(BigInt(l.creditFcfa))}</p>)}</div>)}
 <h5>{t("Balance des comptes","Trial balance")}</h5>{balance.lignes.map(x=><p key={x.compteId}>{x.code} · {x.libelle} · {t("Solde débit","Debit balance")} {money(x.soldeDebitFcfa)} · {t("Solde crédit","Credit balance")} {money(x.soldeCreditFcfa)}</p>)}<p>{t("Total débit","Total debit")} {money(balance.totalDebitFcfa)} · {t("Total crédit","Total credit")} {money(balance.totalCreditFcfa)}</p>
 <h5>{t("Clôture de période","Period close")}</h5><p>{t("Clôturé jusqu’au","Closed through")} : {data.closed_through??"—"}</p><label>{t("Date de clôture comptable","Accounting closing date")}<input type="date" value={date} onChange={e=>DT(e.target.value)}/></label><label>{t("Motif de clôture","Closing reason")}<input value={reason} onChange={e=>R(e.target.value)}/></label><button disabled={lock||!date||reason.trim().length<5} onClick={()=>run(async()=>{await call("ledger_close",{through_date:date,reason});await load()})}>{t("Clôturer la période","Close period")}</button>
 </>}
 </section>
}
