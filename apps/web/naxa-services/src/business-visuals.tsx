import React, {useEffect,useState} from "react";

const general=["office.jpg","workspace.jpg","printing.jpg","teamwork.jpg"];
const selections:Record<string,string[]>={
  impression:["printing.jpg","stationery.jpg"],
  menuiserie:["wood-stock.jpg","furniture.jpg"],
  domicile:["painting.jpg","teamwork.jpg"],
};
export function BusinessBackdrop({activity,kind="hero"}:{activity?:string;kind?:"hero"|"auth"}){
  const photos=kind==="auth"?general:selections[activity??""]??["office.jpg","workspace.jpg"];
  const [index,setIndex]=useState(0);
  useEffect(()=>{
    setIndex(0);
    const media=window.matchMedia("(prefers-reduced-motion: reduce)");
    let timer:number|undefined;
    const start=()=>{if(timer!==undefined)window.clearInterval(timer);timer=undefined;if(!media.matches&&!document.hidden)timer=window.setInterval(()=>setIndex(i=>(i+1)%photos.length),4000);};
    start();media.addEventListener("change",start);document.addEventListener("visibilitychange",start);
    return()=>{if(timer!==undefined)window.clearInterval(timer);media.removeEventListener("change",start);document.removeEventListener("visibilitychange",start);};
  },[activity,kind,photos.length]);
  return <div className="business-backdrop" aria-hidden="true" data-testid={kind+"-photos"} data-photo-index={index}>
    {photos.map((name,i)=><img key={name} src={"/media/"+name} alt="" draggable={false} className={i===index%photos.length?"current":""}/>)}
    <div className="business-scrim"/>
  </div>;
}
export function NightTorch({active}:{active:boolean}){
  return active?<div className="night-torch" aria-hidden="true" data-testid="night-torch"><div className="night-torch-beam"/><div className="night-torch-body"><i/></div></div>:null;
}
