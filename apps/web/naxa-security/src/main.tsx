import React,{useState,useEffect} from "react";
import {createRoot} from "react-dom/client";
import registry from "./screens.json";
import "./security.css";
import {BusinessPanel} from "./BusinessPanel";
const tabs=["Accueil","Surveillance","Alertes","Gestion","Profil"];
function fromHash(){return registry.find(s=>location.hash==="#/"+s.id);}
function App(){
 const [selected,setSelected]=useState(fromHash);
 const [tab,setTab]=useState(fromHash()?.tab??"Accueil");
 const [query,setQuery]=useState("");
 useEffect(()=>{const change=()=>{const screen=fromHash();setSelected(screen);if(screen)setTab(screen.tab);};window.addEventListener("hashchange",change);return()=>window.removeEventListener("hashchange",change)},[]);
 function open(s:typeof registry[number]){location.hash="/"+s.id;setSelected(s);setTab(s.tab)}
 function switchTab(t:string){location.hash="";setTab(t);setSelected(undefined);setQuery("")}
 const shown=registry.filter(s=>s.tab===tab&&(s.title.toLocaleLowerCase().includes(query.toLocaleLowerCase())||s.id.toLowerCase().includes(query.toLowerCase())));
 return <div className="shell"><header><strong>NAXA SECURITY</strong><small>Navigation de préparation — aucun équipement connecté</small></header><nav aria-label="Navigation principale">{tabs.map(t=><button key={t} aria-current={tab===t?"page":undefined} onClick={()=>switchTab(t)}>{t}</button>)}</nav><main>{selected?<><button onClick={()=>switchTab(selected.tab)}>Retour</button><h1>{selected.title}</h1><p>{selected.id} · {selected.bulk}</p><BusinessPanel key={selected.id} id={selected.id}/><h2>Écrans associés</h2><div className="grid">{registry.filter(s=>s.bulk===selected.bulk&&s.id!==selected.id).map(s=><button key={s.id} onClick={()=>open(s)}>{s.title}</button>)}</div></>:<><h1>{tab}</h1><label htmlFor="search">Rechercher un écran</label><input id="search" value={query} onChange={e=>setQuery(e.target.value)} /><p>{shown.length} écrans</p><div className="grid">{shown.map(s=><button key={s.id} onClick={()=>open(s)}><span>{s.title}</span><small>{s.id}</small></button>)}</div></>}</main></div>
}
if("serviceWorker" in navigator)window.addEventListener("load",()=>navigator.serviceWorker.register("/sw.js").catch(()=>{}));
createRoot(document.getElementById("root")!).render(<React.StrictMode><App/></React.StrictMode>);
