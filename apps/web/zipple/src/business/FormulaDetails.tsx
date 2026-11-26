import React,{useEffect,useState} from "react";
import {FormulaGroupEditor} from "./FormulaGroupEditor";
export function FormulaDetails({item,items,call,disabled,en,refresh}:{item:any;items:any[];call:(a:string,b?:Record<string,unknown>)=>Promise<any>;disabled:boolean;en:boolean;refresh:()=>Promise<void>}){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const [components,C]=useState<any[]>([]),[ready,R]=useState(false),[qty,Q]=useState<Record<string,string>>({}),[busy,B]=useState(false),[error,E]=useState("");
 async function load(){const x=await call("formula_snapshot");C(x.filter((c:any)=>c.formula_id===item.id));R(true)}
 useEffect(()=>{load().catch(()=>E("OPERATION_UNAVAILABLE"))},[item.id]);
 const chosen=Object.entries(qty).filter(([,v])=>Number(v)>0);
 return <section><h4>{t("Composition de la formule","Formula composition")}</h4>{error&&<p role="alert">{error}</p>}
 {components.length?<>{components.map(c=><p key={c.component_id}>{items.find(i=>i.id===c.component_id)?.name??"—"} × {c.qty}</p>)}<p>{t("Stock vendable calculé à partir des composants","Sellable stock calculated from components")} : {item.sellable_qty??0}</p></>:ready&&<>{items.filter(i=>i.id!==item.id&&i.kind!=="formula").map(i=><label key={i.id}>{i.name} · {i.post}<input type="number" min="0" max="100" value={qty[i.id]??""} onChange={e=>Q(v=>({...v,[i.id]:e.target.value}))}/></label>)}<button disabled={disabled||busy||chosen.length<1||chosen.length>20||chosen.some(([,v])=>!Number.isInteger(Number(v))||Number(v)>100)} onClick={async()=>{B(true);E("");try{await call("formula_define",{formula_id:item.id,components:chosen.map(([component_id,v])=>({component_id,qty:Number(v)}))});await load();await refresh()}catch(e){E(e instanceof Error?e.message:"OPERATION_UNAVAILABLE")}finally{B(false)}}}>{t("Enregistrer la composition","Save composition")}</button><p>{t("La formule doit avoir zéro stock propre. Les composants sont réservés au moment de la commande.","Formula has no own stock. Components are reserved when ordering.")}</p></>}
 {components.length>0&&<FormulaGroupEditor item={item} items={items} components={components} call={call} disabled={disabled} en={en} refresh={refresh}/>}
 </section>
}
