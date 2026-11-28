import React from 'react';
import {activitySeries} from './activity-series.mjs';
export function ActivityTrend({daily,tr,locale}:{daily:any;tr:(s:string)=>string;locale:string}){
 const points=activitySeries(daily) as {day:string;ca:number}[];
 const low=Math.min(0,...points.map(p=>p.ca)),high=Math.max(0,...points.map(p=>p.ca)),span=high-low||1;
 const coords=points.map((p,i)=>({x:points.length===1?160:16+i*288/(points.length-1),y:102-(p.ca-low)*84/span}));
 const path=coords.map((p,i)=>(i?'L':'M')+p.x+' '+p.y).join(' ');
 const amount=(n:number)=>new Intl.NumberFormat(locale==='en'?'en-CM':'fr-CM').format(n)+' F';
 return <article className="atelier-activity"><h2>{tr("Évolution du chiffre d’affaires")}</h2><p>{tr("Services clôturés")}</p>{points.length===0?<p>{tr("Aucune synthèse de service disponible.")}</p>:<><svg viewBox="0 0 320 120" aria-hidden="true" className="activity-plot"><line x1="16" x2="304" y1={102+low*84/span} y2={102+low*84/span} className="activity-zero"/><path key={path} d={path} pathLength="1" className="activity-line"/>{coords.map((p,i)=><circle key={points[i].day} cx={p.x} cy={p.y} r="3.5" className="activity-dot"/>)}</svg><ul className="activity-values">{points.map(p=><li key={p.day}><time dateTime={p.day}>{p.day.slice(5)}</time><strong>{amount(p.ca)}</strong></li>)}</ul></>}</article>;
}
