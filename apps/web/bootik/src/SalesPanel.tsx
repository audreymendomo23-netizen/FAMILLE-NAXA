import React,{useEffect,useRef,useState}from'react';
import{operation,syncSale}from './operations.mjs';
import{enqueue,scoped,flush,discardConflict,loadCatalog,saveCatalog}from './outbox';
type Item={balance_id:string,display_name:string,available:string|number,unit_price_fcfa:string|number};
export function SalesPanel({base,session,site}:{base:string,session:any,site:string}){
 const org=session.organization_id,member=session.member_id;
 const [items,I]=useState<Item[]>([]),[selected,S]=useState(''),[qty,Q]=useState('1'),[events,E]=useState<any[]>([]),[message,M]=useState(''),[busy,B]=useState(false),[updated,U]=useState(0);
 const [automatic,Auto]=useState(false);const inFlight=useRef(false);const alive=useRef(true);useEffect(()=>{alive.current=true;void (async()=>{try{const c=await loadCatalog(org,member,site);const es=await scoped(org,member,site);if(alive.current){I(c.items);U(c.updatedAt);E(es)}}catch{if(alive.current)M('Stockage local indisponible')}})();return()=>{alive.current=false}},[org,member,site]);
 async function task(fn:()=>Promise<void>){if(inFlight.current)return;inFlight.current=true;B(true);try{await fn()}catch{if(alive.current)M('Opération non confirmée. Vérifiez la connexion et les droits.')}finally{if(alive.current){E(await scoped(org,member,site).catch(()=>[]));B(false)}inFlight.current=false}}
 const item=items.find(i=>i.balance_id===selected);
 const quantity=Number(qty),price=Number(item?.unit_price_fcfa);
 const authorized=()=>alive.current&&session.expires_at>Date.now()&&session.sites.some((s:any)=>s.id===site);
 const synchronize=async()=>{const n=await flush({orgId:org,memberId:member,siteId:site},e=>syncSale(base,session,site,e),authorized);M(n+' réponse(s) traitée(s). Consultez le statut de chaque vente.');};
 useEffect(()=>{if(!automatic)return;const resume=()=>{if(navigator.onLine&&authorized())void task(synchronize)};window.addEventListener('online',resume);resume();return()=>window.removeEventListener('online',resume)},[automatic,org,member,site,session]);
 return <article><h2>Catalogue, caisse et synchronisation</h2><p>{updated?'Dernier catalogue local : '+new Date(updated).toLocaleString('fr-FR'):'Aucun catalogue local'}</p>
 <button disabled={busy} onClick={()=>task(async()=>{const v=await operation(base,session,site,'catalog',{});if(!Array.isArray(v.items)||!v.items.every((i:any)=>typeof i.balance_id==='string'&&typeof i.display_name==='string'&&Number.isFinite(Number(i.available))&&Number.isSafeInteger(Number(i.unit_price_fcfa))))throw Error('INVALID_CATALOG');await saveCatalog(org,member,site,v.items);if(alive.current){I(v.items);U(Date.now());S('');M('Catalogue actualisé')}})}>Actualiser le catalogue</button>
 <label>Article<select aria-label="Article" value={selected} disabled={busy} onChange={e=>S(e.target.value)}><option value="">Choisir</option>{items.map(i=><option key={i.balance_id} value={i.balance_id}>{i.display_name} — {i.unit_price_fcfa} FCFA — stock {i.available}</option>)}</select></label>
 <label>Quantité<input type="number" min="0.000001" step="0.000001" value={qty} disabled={busy} onChange={e=>Q(e.target.value)}/></label>
 <button disabled={busy||!item||!Number.isFinite(quantity)||quantity<=0||!Number.isSafeInteger(price)||price<0} onClick={()=>task(async()=>{if(!authorized()||!item)throw Error('SCOPE_DENIED');const id=crypto.randomUUID();await enqueue({eventId:id,orgId:org,memberId:member,siteId:site,sequence:Date.now(),aggregateType:'sale',payload:JSON.stringify({balance_id:item.balance_id,quantity,unit_price_fcfa:price,idempotency_key:id}),state:'queued'});M('Vente mise en attente. Aucun stock ni encaissement confirmé.');})}>Mettre la vente en file</button>
 <button disabled={busy} onClick={()=>task(async()=>{const n=await flush({orgId:org,memberId:member,siteId:site},e=>syncSale(base,session,site,e),authorized);M(n+' réponse(s) traitée(s). Consultez le statut de chaque vente.');})}>Synchroniser</button>
 <label><input type="checkbox" checked={automatic} disabled={busy} onChange={e=>Auto(e.target.checked)}/> Synchroniser automatiquement au retour du réseau</label>
 <p>{events.filter(e=>e.state==='queued').length} en attente · {events.filter(e=>e.state==='conflict'||e.state==='rejected').length} à corriger</p>
 {events.slice(-20).reverse().map(e=><div key={e.eventId}><span>{e.eventId.slice(0,8)} — {e.state==='acknowledged'?'Confirmée':e.state==='queued'?'En attente':e.state==='discarded'?'Abandonnée':'Conflit / refus'}</span>{['conflict','rejected'].includes(e.state)&&<button disabled={busy} onClick={()=>task(async()=>{await discardConflict(e);M('Conflit abandonné localement ; recréez une vente corrigée si nécessaire.')})}>Abandonner</button>}</div>)}
 <p role="status">{message}</p></article>
}
