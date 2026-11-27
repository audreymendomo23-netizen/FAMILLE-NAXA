import React,{useEffect,useState} from "react";
export function serviceClock(order:any,now:number){
 if(!order.promised_at)return null;
 const end=order.guest_served_at??order.served_at;const target=Date.parse(order.promised_at);const clock=end?Date.parse(end):now;
 if(!Number.isFinite(target)||!Number.isFinite(clock))return null;
 const ms=target-clock;const seconds=ms>=0?Math.ceil(ms/1000):Math.floor(ms/1000);return {seconds,phase:end?"done":ms>0?"remaining":"late"};
}
const duration=(s:number)=>{const n=Math.abs(s);return Math.floor(n/60)+" min "+String(n%60).padStart(2,"0")+" s"};
export function ServiceClock({order,serverNow,en}:{order:any;serverNow?:string;en:boolean}){
 const [tick,T]=useState(performance.now()),[anchor,A]=useState<{server:number;mono:number}|null>(null);
 useEffect(()=>{const server=serverNow?Date.parse(serverNow):NaN;if(Number.isFinite(server)){const mono=performance.now();A({server,mono});T(mono)}},[serverNow]);
 useEffect(()=>{const timer=setInterval(()=>T(performance.now()),1000);return()=>clearInterval(timer)},[]);
 const done=!!(order.guest_served_at??order.served_at),elapsed=anchor?Math.max(0,tick-anchor.mono):0,clock=anchor?anchor.server+elapsed:NaN;
 const x=serviceClock(order,clock);if(order.status==="cancelled"||!order.promised_at)return null;
 const stale=!done&&(!anchor||elapsed>15000);
 if(!x||stale)return <p role="status" data-clock-target={order.promised_at} data-clock-fresh="false">{en?"Service time — awaiting synchronization":"Délai de service — synchronisation attendue"}</p>;
 return <p role="status" data-clock-target={order.promised_at} data-clock-phase={x.phase} data-clock-fresh="true">{x.phase==="remaining"?(en?"Remaining: ":"Temps restant : ")+duration(x.seconds):x.phase==="late"?(en?"Delay: ":"Retard : ")+duration(x.seconds):x.seconds>=0?(en?"Served early: ":"Service en avance : ")+duration(x.seconds):(en?"Served late: ":"Service en retard : ")+duration(x.seconds)}{order.eta_saturated&&" · "+(en?"High station workload":"Forte charge des postes")}</p>
}
