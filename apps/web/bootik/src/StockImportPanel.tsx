import React,{useState,useRef}from'react';
import{operation}from './operations.mjs';
export function StockImportPanel({base,session,site,activity}:{base:string,session:any,site:string,activity:string}){
 const [csv,C]=useState(''),[preview,P]=useState<any[]>([]),[message,M]=useState(''),[busy,B]=useState(false);const id=useRef('');
 const call=(action:string,p:object)=>operation(base,session,site,action,{activity_id:activity,...p});
 async function task(fn:()=>Promise<void>){if(busy)return;B(true);M('');try{await fn()}catch{M('Import non confirmé. Vérifiez le fichier et les droits.')}finally{B(false)}}
 function edit(v:string){C(v);P([]);id.current=''}
 return <section><h3>Import CSV par activité</h3><p>Fichier UTF-8 séparé par point-virgule, 1 à 30 lignes, 10 000 caractères maximum. Modèle ouvrable dans Excel. Création uniquement ; les références existantes sont rejetées.</p>
 <button disabled={busy} onClick={()=>task(async()=>{const r=await call('stock-template',{});const url=URL.createObjectURL(new Blob([r.csv],{type:'text/csv;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download='bootik-'+r.profile+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)})}>Télécharger le modèle CSV</button>
 <label>Fichier CSV<input type="file" accept=".csv,text/csv" disabled={busy} onChange={e=>{const f=e.target.files?.[0];if(f)void task(async()=>{if(f.size>10000)throw Error('TOO_LARGE');edit(await f.text())})}}/></label>
 <label>Contenu CSV<textarea value={csv} maxLength={10000} onChange={e=>edit(e.target.value)} disabled={busy}/></label>
 <button disabled={busy||!csv.trim()} onClick={()=>task(async()=>{const r=await call('stock-import-preview',{csv});P(r.rows);id.current=crypto.randomUUID()})}>Analyser le fichier</button>
 {preview.map(x=><p key={x.row}>Ligne {x.row} — {x.status==='create'?x.data.sku+' : création, stock '+x.quantity:'Rejet : '+x.reason}</p>)}
 <button disabled={busy||!preview.length||preview.some(x=>x.status!=='create')||!id.current} onClick={()=>task(async()=>{const r=await call('stock-import-apply',{csv,batch_id:id.current});if(r.batch_id!==id.current||!Array.isArray(r.report))throw Error('INVALID_RECEIPT');M(r.report.length+' article(s) créé(s) avec reçu serveur. Actualisez le catalogue.');P([]);C('');id.current=''})}>Confirmer l’import</button><p role="status">{message}</p></section>
}
