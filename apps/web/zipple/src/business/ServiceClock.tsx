import React,{useEffect,useState} from "react";
export function serviceClock(order:any,now:number){
 if(!order.promised_at)return null;
 const end=order.guest_served_at??order.served_at;const target=Date.parse(order.promised_at);const clock=end?Date.parse(end):now;
 if(!Number.isFinite(target)||!Number.isFinite(clock))return null;
 const seconds=Math.ceil((target-clock)/1000);return {seconds,phase:end?"done":seconds>0?"remaining":"late"};
}
const duration=(s:number)=>{const n=Math.abs(s);return Math.floor(n/60)+" min "+String(n%60).padStart(2,"0")+" s"};
export function ServiceClock({order,serverNow,en}:{order:any;serverNow?:string;en:boolean}){
 const [clock,C]=useState(Date.now()),[offset,O]=useState(0);
 useEffect(()=>{if(serverNow)O(Date.parse(serverNow)-Date.now())},[serverNow]);
 useEffect(()=>{const timer=setInterval(()=>C(Date.now()),1000);return()=>clearInterval(timer)},[]);
 const x=serviceClock(order,clock+offset);if(!x||order.status==="cancelled")return null;
 return <p role="status">{x.phase==="remaining"?(en?"Remaining: ":"Temps restant : ")+duration(x.seconds):x.phase==="late"?(en?"Delay: ":"Retard : ")+duration(x.seconds):x.seconds>=0?(en?"Served early: ":"Service en avance : ")+duration(x.seconds):(en?"Served late: ":"Service en retard : ")+duration(x.seconds)}{order.eta_saturated&&" · "+(en?"High station workload":"Forte charge des postes")}</p>
}
