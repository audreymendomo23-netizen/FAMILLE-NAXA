import React from "react";
export type ChoiceMap=Record<string,string>;
export function choicesValid(groups:any[],selected:ChoiceMap={}){
 return groups.every(g=>{const id=selected[g.id];return id?g.options.some((o:any)=>o.component_id===id&&o.available):!g.required});
}
export function choiceDelta(groups:any[],selected:ChoiceMap={}){
 return groups.reduce((n,g)=>n+(g.options.find((o:any)=>o.component_id===selected[g.id])?.delta_xaf??0),0);
}
export function serializeChoices(groups:any[],selected:ChoiceMap={}){
 return groups.filter(g=>selected[g.id]).map(g=>({group_id:g.id,component_id:selected[g.id]}));
}
export function OrderChoices({groups,selected,onChange,en,itemName,disabled}:{groups:any[];selected:ChoiceMap;onChange:(s:ChoiceMap)=>void;en:boolean;itemName:string;disabled:boolean}){
 return <>{groups.map(g=><label key={g.id}>{itemName} · {g.name} {g.required?"*":en?"(optional)":"(facultatif)"}<select aria-label={itemName+" · "+g.name} disabled={disabled} value={selected[g.id]??""} onChange={e=>onChange({...selected,[g.id]:e.target.value})}><option value="">—</option>{g.options.map((o:any)=><option disabled={!o.available} key={o.component_id} value={o.component_id}>{o.name}{o.delta_xaf?" ("+(o.delta_xaf>0?"+":"")+o.delta_xaf+" FCFA)":""}{!o.available?en?" — unavailable":" — épuisé":""}</option>)}</select></label>)}</>
}
