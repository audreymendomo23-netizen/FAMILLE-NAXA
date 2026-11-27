import React,{useState} from 'react';
export function DirectBasket({items,disabled,submit}:{items:any[];disabled:boolean;submit:(lines:any[])=>void}){
 const [open,O]=useState(false),[quantities,Q]=useState<Record<string,number>>({});
 const lines=items.filter(x=>(quantities[x.id]??0)>0).map(x=>({item:x.id,qty:quantities[x.id],price:x.price}));
 const total=lines.reduce((n,x)=>n+x.qty*x.price,0);
 const valid=lines.length>0&&lines.length<=20&&lines.every(x=>Number.isSafeInteger(x.qty)&&x.qty>0&&x.qty<=items.find(i=>i.id===x.item).remaining);
 return <article><button className="quiet" onClick={()=>O(!open)} disabled={disabled}>{open?'Fermer le panier':'Vente de plusieurs articles'}</button>{open&&<><h2>Panier de vente</h2>{items.map(x=><label key={x.id} className="setting">{x.name} · {x.price} F · {x.remaining} restants <input type="number" min="0" max={x.remaining} value={quantities[x.id]??0} aria-label={'Panier '+x.name} onChange={e=>Q({...quantities,[x.id]:Number(e.target.value)})} disabled={disabled}/></label>)}<p>Total indicatif : {total} F</p><button disabled={disabled||!valid} onClick={()=>{submit(lines);Q({});O(false)}}>Valider le panier</button></>}</article>
}