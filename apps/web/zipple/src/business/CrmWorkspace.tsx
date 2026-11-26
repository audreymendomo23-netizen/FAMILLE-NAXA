import React,{useEffect,useState,useRef} from "react";
// Adapted from NAXA Services CustomerFollowupsPage: professional-only voluntary record, follow-up and completion.
type Props={orders:any[];call:(action:string,body?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean};
export function CrmWorkspace({orders,call,disabled,en}:Props){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [data,D]=useState<any>(null),[busy,B]=useState(false),[error,E]=useState("");
 const [name,N]=useState(""),[phone,P]=useState(""),[consent,C]=useState(false),[customer,CU]=useState(""),[order,O]=useState("");
 const [title,T]=useState(""),[channel,CH]=useState("telephone"),[due,DU]=useState("");
 const pending=useRef<{body:string,id:string}|null>(null);
 const lock=disabled||busy;
 const customers:any[]=data?.customers??[],followups:any[]=data?.followups??[],history:any[]=data?.history??[];
 const selected=customers.find(c=>c.id===customer);
 async function load(){D(await call("crm_snapshot"))}
 async function run(fn:()=>Promise<void>){if(lock)return;B(true);E("");try{await fn()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}
 useEffect(()=>{let live=true;call("crm_snapshot").then(v=>{if(live)D(v)}).catch(()=>{if(live)E("OPERATION_UNAVAILABLE")});return()=>{live=false}},[]);
 return <section>
 <h3>{t("Relation client","Customer relationship")}</h3>
 <p>{t("Fiches professionnelles facultatives. Aucune inscription client, aucun compte ni envoi automatique de message.","Optional professional records. No customer registration, account or automatic message.")}</p>
 {error&&<p role="alert">{t("Opération non confirmée : ","Operation unconfirmed: ")}{error}</p>}
 <button disabled={lock} onClick={()=>run(load)}>{t("Actualiser les clients","Refresh customers")}</button>
 <h4>{t("Créer une fiche client","Create customer record")}</h4>
 <label>{t("Nom d’usage","Display name")}<input value={name} onChange={e=>N(e.target.value)} maxLength={160}/></label>
 <label>{t("Téléphone volontaire (facultatif)","Voluntary phone (optional)")}<input type="tel" value={phone} onChange={e=>P(e.target.value)} maxLength={32}/></label>
 <label className="remember"><input type="checkbox" checked={consent} onChange={e=>C(e.target.checked)}/>{t("Le client a volontairement communiqué ces informations.","The customer voluntarily provided this information.")}</label>
 <button disabled={lock||!name.trim()||!consent} onClick={()=>run(async()=>{const id=await call("customer_add",{name,phone:phone.replace(/\D/g,"")});CU(id);N("");P("");C(false);await load()})}>{t("Enregistrer la fiche","Save customer record")}</button>
 <label>{t("Client sélectionné","Selected customer")}<select aria-label={t("Client sélectionné","Selected customer")} value={customer} onChange={e=>CU(e.target.value)}><option value="">—</option>{customers.map(c=><option key={c.id} value={c.id}>{c.display_name}{c.phone?" · "+c.phone:""}</option>)}</select></label>
 {selected&&<>
 <h4>{t("Rattacher une commande non réglée","Link an unsettled order")}</h4>
 <label>{t("Commande","Order")}<select aria-label={t("Commande à rattacher","Order to link")} value={order} onChange={e=>O(e.target.value)}><option value="">—</option>{orders.filter(o=>o.status!=="cancelled"&&!history.some(h=>h.order_id===o.id)).map(o=><option key={o.id} value={o.id}>{o.id.slice(0,8)} · {o.total_xaf} FCFA · {o.status}</option>)}</select></label>
 <button disabled={lock||!order} onClick={()=>run(async()=>{await call("customer_attach",{customer_id:customer,order_id:order});O("");await load()})}>{t("Rattacher la commande","Link order")}</button>
 <h4>{t("Historique du site","Site history")}</h4>{history.filter(h=>h.customer_id===customer).map(h=><p key={h.order_id}>{h.order_id.slice(0,8)} · {h.total_xaf} FCFA · {h.paid?t("Réglée","Paid"):t("Non réglée","Unpaid")}</p>)}
 <h4>{t("Planifier un suivi","Schedule a follow-up")}</h4>
 <label>{t("Objet du suivi","Follow-up subject")}<input value={title} onChange={e=>T(e.target.value)} maxLength={160}/></label>
 <label>{t("Canal de suivi","Follow-up channel")}<select value={channel} onChange={e=>CH(e.target.value)}><option value="telephone">{t("Téléphone","Phone")}</option><option value="whatsapp">WhatsApp</option><option value="in_person">{t("Sur place","In person")}</option></select></label>
 <label>{t("Échéance du suivi","Follow-up due date")}<input type="date" value={due} onChange={e=>DU(e.target.value)}/></label>
 <button disabled={lock||!title.trim()||!due} onClick={()=>run(async()=>{const b={customer_id:customer,title,channel,due_on:due},serialized=JSON.stringify(b);if(pending.current?.body!==serialized)pending.current={body:serialized,id:crypto.randomUUID()};await call("followup_create",{...b,request_id:pending.current.id});pending.current=null;T("");DU("");await load()})}>{t("Créer le suivi","Create follow-up")}</button>
 {followups.filter(f=>f.customer_id===customer).map(f=><div key={f.id} className="business-panel"><p>{f.title} · {f.due_on} · {f.channel}</p>{f.completed_at?<p>{t("Terminé","Completed")}</p>:<button disabled={lock} onClick={()=>run(async()=>{await call("followup_complete",{followup_id:f.id});await load()})}>{t("Clôturer le suivi","Complete follow-up")}</button>}</div>)}
 </>}
 <p>{t("Récompenses de fidélité et parrainage client : barème commercial à valider avant activation.","Loyalty and customer referral rewards: commercial policy required before activation.")}</p>
 </section>
}
