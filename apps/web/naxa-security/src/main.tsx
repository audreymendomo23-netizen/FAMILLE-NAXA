import React,{useState,useEffect} from "react";
import {createRoot} from "react-dom/client";
import registry from "./screens.json";
import "./security.css";
import {BusinessPanel} from "./BusinessPanel";
import {SessionWorkspace} from "./SessionWorkspace";import {screenTitle,englishTabs,navText} from "./navigation-i18n.mjs";
const tabs=["Accueil","Surveillance","Alertes","Gestion","Profil"];
function fromHash(){return registry.find(s=>location.hash==="#/"+s.id);}
function App(){
 const [selected,setSelected]=useState(fromHash);
 const [tab,setTab]=useState(fromHash()?.tab??"Accueil");
 const [query,setQuery]=useState("");
 const [locale,setLocale]=useState("fr");const tr=(fr:string,en:string)=>navText(fr,en,locale);
 useEffect(()=>{const change=()=>{const screen=fromHash();setSelected(screen);if(screen)setTab(screen.tab);};window.addEventListener("hashchange",change);return()=>window.removeEventListener("hashchange",change)},[]);
 function open(s:typeof registry[number]){location.hash="/"+s.id;setSelected(s);setTab(s.tab)}
 function switchTab(t:string){location.hash="";setTab(t);setSelected(undefined);setQuery("")}
 const shown=registry.filter(s=>s.tab===tab&&((screenTitle(s,locale).toLocaleLowerCase().includes(query.toLocaleLowerCase())||s.title.toLocaleLowerCase().includes(query.toLocaleLowerCase()))||s.id.toLowerCase().includes(query.toLowerCase())));
 return <div className="shell"><header><strong>NAXA SECURITY</strong><small>{tr("Navigation de préparation — aucun équipement connecté","Preparation mode — no connected equipment")}</small><label htmlFor="navigation-locale">{tr("Langue de navigation","Navigation language")}</label><select id="navigation-locale" value={locale} onChange={e=>setLocale(e.target.value)}><option value="fr">Français</option><option value="en">English</option></select>{locale==="en"&&<small>Navigation translated; business forms remain in French. Fulfulde translation is not yet validated.</small>}</header><nav aria-label="Navigation principale">{tabs.map(t=><button key={t} aria-current={tab===t?"page":undefined} onClick={()=>switchTab(t)}>{locale==="en"?englishTabs[t]:t}</button>)}</nav><main>{selected?<><button onClick={()=>switchTab(selected.tab)}>{tr("Retour","Back")}</button><h1>{screenTitle(selected,locale)}</h1><p>{selected.id} · {selected.bulk}</p><BusinessPanel key={selected.id} id={selected.id}/><h2>{tr("Écrans associés","Related screens")}</h2><div className="grid">{registry.filter(s=>s.bulk===selected.bulk&&s.id!==selected.id).map(s=><button key={s.id} onClick={()=>open(s)}>{screenTitle(s,locale)}</button>)}</div></>:<><h1>{locale==="en"?englishTabs[tab]:tab}</h1><label htmlFor="search">{tr("Rechercher un écran","Find a screen")}</label><input id="search" value={query} onChange={e=>setQuery(e.target.value)} /><p>{shown.length} {tr("écrans","screens")}</p><div className="grid">{shown.map(s=><button key={s.id} onClick={()=>open(s)}><span>{screenTitle(s,locale)}</span><small>{s.id}</small></button>)}</div></>}</main></div>
}
if("serviceWorker" in navigator)window.addEventListener("load",()=>navigator.serviceWorker.register("/sw.js").catch(()=>{}));
createRoot(document.getElementById("root")!).render(<React.StrictMode><SessionWorkspace><App/></SessionWorkspace></React.StrictMode>);
