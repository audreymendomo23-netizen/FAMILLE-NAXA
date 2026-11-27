import React,{useEffect,useState,useRef} from "react";
type Props={call:(a:string,b?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean;data:any;kinds:Record<string,string>;refresh:()=>Promise<void>};
export function LedgerMappings({call,disabled,en,data,kinds,refresh}:Props){
 const t=(f:string,e:string)=>en?e:f;
 const [open,O]=useState(false),[config,C]=useState<any>(null),[kind,K]=useState("expense"),[d,D]=useState(""),[c,CR]=useState(""),[j,J]=useState(""),[why,W]=useState(""),[rule,R]=useState(""),[source,S]=useState(""),[label,L]=useState(""),[busy,B]=useState(false),[error,E]=useState("");
 const key=useRef<Record<string,{encoded:string,id:string}>>({}),active=config?.rules.find((x:any)=>x.kind===kind&&x.active),selected=config?.rules.find((x:any)=>x.id===rule&&x.active);
 async function load(){C(await call("ledger_mapping_snapshot"))}
 async function run(fn:()=>Promise<void>){if(disabled||busy)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:t("Opération non confirmée","Operation unconfirmed"))}finally{B(false)}}
 async function mutate(a:string,b:Record<string,unknown>){const encoded=JSON.stringify(b);if(key.current[a]?.encoded!==encoded)key.current[a]={encoded,id:crypto.randomUUID()};await call(a,{...b,request_id:key.current[a].id});delete key.current[a]}
 useEffect(()=>{if(open)void run(load)},[open]);
 return <section><button onClick={()=>O(!open)}>{t("Affectations comptables validées","Approved accounting mappings")}</button>{open&&<><p>{t("Paramétrez avec votre comptable les comptes, journaux et règles. Chaque version est conservée ; aucune écriture ni taxe n’est créée sans validation.","Configure accounts, journals and rules with your accountant. Each version is retained; no posting or tax is assumed without approval.")}</p>{error&&<p role="alert">{error}</p>}
 <button disabled={disabled||busy} onClick={()=>run(load)}>{t("Actualiser les affectations","Refresh mappings")}</button>
 {config&&<><label>{t("Type de source comptable","Accounting source kind")}<select value={kind} onChange={e=>{K(e.target.value);D("");CR("");J("");W("")}}>{Object.entries(kinds).map(([k,v])=><option key={k} value={k}>{v}</option>)}</select></label>
 <p>{t("Version active","Active version")}: {active?.version??0}</p>
 {[[t("Compte débité classé","Classified debit account"),d,D],[t("Compte crédité classé","Classified credit account"),c,CR]].map(([name,value,set]:any,i)=><label key={i}>{name}<select aria-label={name} value={value} onChange={e=>set(e.target.value)}><option value="">—</option>{config.accounts.map((x:any)=><option key={x.id} value={x.id}>{x.code} · {x.label}</option>)}</select></label>)}
 <label>{t("Journal de l’affectation","Mapping journal")}<input maxLength={30} value={j} onChange={e=>J(e.target.value)}/></label><label>{t("Justification de la validation","Approval evidence")}<input maxLength={500} value={why} onChange={e=>W(e.target.value)}/></label>
 <button disabled={disabled||busy||!d||!c||d===c||!j.trim()||why.trim().length<5} onClick={()=>run(async()=>{await mutate("ledger_mapping_set",{kind,expected_version:active?.version??0,debit_account:d,credit_account:c,journal:j.trim(),reason:why.trim()});await load();W("")})}>{t("Valider cette version d’affectation","Approve this mapping version")}</button>
 {config.rules.map((x:any)=><p key={x.id}>{kinds[x.kind]??x.kind} · V{x.version} · {x.debit_code} / {x.credit_code} · {x.active?t("Active","Active"):t("Historique","History")}</p>)}
 <label>{t("Affectation à appliquer","Mapping to apply")}<select value={rule} onChange={e=>{R(e.target.value);S("")}}><option value="">—</option>{config.rules.filter((x:any)=>x.active).map((x:any)=><option key={x.id} value={x.id}>{kinds[x.kind]} · V{x.version} · {x.debit_code} / {x.credit_code}</option>)}</select></label>
 <label>{t("Source à comptabiliser selon l’affectation","Source to post using mapping")}<select value={source} onChange={e=>S(e.target.value)}><option value="">—</option>{data.pending.filter((x:any)=>x.kind===selected?.kind).map((x:any)=><option key={x.source_id} value={x.source_id}>{x.label} · {x.amount_xaf} FCFA</option>)}</select></label>
 <label>{t("Libellé de l’écriture affectée","Mapped posting description")}<input maxLength={250} value={label} onChange={e=>L(e.target.value)}/></label>
 <button disabled={disabled||busy||!selected||!source||label.trim().length<5} onClick={()=>run(async()=>{await mutate("ledger_post_mapped",{mapping_id:rule,source_id:source,label:label.trim()});S("");L("");await refresh();await load()})}>{t("Confirmer l’écriture affectée","Confirm mapped posting")}</button></>}
 </>}</section>
}
