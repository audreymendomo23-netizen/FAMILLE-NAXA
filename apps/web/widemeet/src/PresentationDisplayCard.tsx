import React from "react";
import {PRESENTATION_PROFILES} from "../../../../packages/widemeet-domain/presentation-display.mjs";
// Adapter only. Caller supplies real publisher permission, SDK state and authenticated receiver commands.
export function PresentationDisplayCard({locale="fr",preferred="medium",effective=null,canPresent=false,canDisplay=false,online=false,pending=false,receiver=null,onQuality,onPair,onDisconnect}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 return <section className="card" aria-label={tr("Présentation et affichage","Presentation and display")}>
 <h2>{tr("Qualité de présentation","Presentation quality")}</h2>
 <fieldset disabled={!online||pending||!canPresent}><legend>{tr("Qualité souhaitée","Preferred quality")}</legend>{Object.entries(PRESENTATION_PROFILES).map(([key,p])=><label key={key} style={{display:"block"}}><input type="radio" name="presentation-quality" checked={preferred===key} onChange={()=>onQuality(key)}/> {key[0].toUpperCase()+key.slice(1)} Quality · {p.height}p</label>)}</fieldset>
 <p>{tr("Qualité effective : ","Effective quality: ")}{effective&&PRESENTATION_PROFILES[effective]?PRESENTATION_PROFILES[effective].height+"p":tr("Non confirmée","Unconfirmed")}</p>
 <h2>WideMeet Connect</h2>
 {receiver?<><p>{tr("Affichage sur : ","Displaying on: ")}{receiver.name}</p><button disabled={!online||pending} onClick={()=>onDisconnect(receiver.id)}>{tr("Arrêter l’affichage","Stop display")}</button></>:<button disabled={!online||pending||!canDisplay} onClick={onPair}>{tr("Connecter un écran","Connect a display")}</button>}
 {!canDisplay&&!receiver&&<p>{tr("Affichage externe non autorisé pour cette réunion.","External display is not allowed for this meeting.")}</p>}
 </section>
}
