import React,{useState,useRef} from "react";
import {enrollRecoveryKey,recoverWithKey} from "./session.mjs";
export function RecoveryEnrollment({base,session,locale}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [password,P]=useState(""),[key,K]=useState(""),[busy,B]=useState(false),[error,E]=useState(false);
 async function submit(e){e.preventDefault();if(busy)return;B(true);E(false);try{K(await enrollRecoveryKey(base,session,password))}catch{E(true)}finally{P("");B(false)}}
 return <fieldset><legend>{tr("Clé de récupération","Recovery key")}</legend><p>{tr("Conservez votre clé hors ligne, sans la partager. Une nouvelle clé invalide la précédente.","Keep your key offline and never share it. A new key invalidates the previous one.")}</p>{key?<><code style={{overflowWrap:"anywhere"}}>{key}</code><button onClick={()=>K("")}>{tr("J’ai conservé ma clé","I saved my key")}</button></>:<form onSubmit={submit}><label>{tr("Mot de passe actuel","Current password")}<input type="password" autoComplete="current-password" required value={password} onChange={e=>P(e.target.value)}/></label><button disabled={busy||!password}>{tr("Générer une clé","Generate key")}</button></form>}{error&&<p role="alert">{tr("Action non confirmée.","Action not confirmed.")}</p>}</fieldset>
}
export function RecoveryForm({base,locale,initialIdentifier,onBack,onRecovered}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [identifier,I]=useState(initialIdentifier??""),[key,K]=useState(""),[password,P]=useState(""),[confirm,C]=useState(""),[busy,B]=useState(false),[error,E]=useState(false);
 const request=useRef(null);
 const valid=/^WM-[A-Z0-9]{8,24}$/.test(identifier.trim().toUpperCase())&&/^[a-f0-9]{64}$/i.test(key.trim())&&password.length>=12&&password===confirm;
 async function submit(e){e.preventDefault();if(!valid||busy)return;B(true);E(false);if(!request.current)request.current=crypto.randomUUID();try{await recoverWithKey(base,{identifier,key,password,requestId:request.current});K("");P("");C("");onRecovered(identifier.trim().toUpperCase())}catch{E(true)}finally{B(false)}}
 const locked=busy||!!request.current;
 return <section className="card"><h1>{tr("Récupérer mon compte","Recover account")}</h1><form onSubmit={submit}><label>{tr("Identifiant WideMeet","WideMeet ID")}<input value={identifier} disabled={locked} onChange={e=>I(e.target.value)} maxLength={27}/></label><label>{tr("Clé de récupération","Recovery key")}<input type="password" autoComplete="off" value={key} disabled={locked} onChange={e=>K(e.target.value)} maxLength={64}/></label><label>{tr("Nouveau mot de passe","New password")}<input type="password" autoComplete="new-password" value={password} disabled={locked} onChange={e=>P(e.target.value)} maxLength={256}/></label><label>{tr("Confirmer","Confirm")}<input type="password" autoComplete="new-password" value={confirm} disabled={locked} onChange={e=>C(e.target.value)} maxLength={256}/></label><button disabled={!valid||busy}>{error?tr("Réessayer la même demande","Retry same request"):tr("Récupérer","Recover")}</button></form>{error&&<p role="alert">{tr("Récupération non confirmée. Réessayez avec la même demande ou contactez le support.","Recovery not confirmed. Retry the same request or contact support.")}</p>}<button disabled={busy} onClick={onBack}>{tr("Retour","Back")}</button></section>
}
