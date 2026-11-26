import React,{useState} from "react";
import {login} from "./session.mjs";
// Real transport only; no demo authentication or fallback to another product.
export function SignIn({locale,base,onSession,onBack}){
 const [identifier,setIdentifier]=useState(""),[password,setPassword]=useState(""),[show,setShow]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState("");
 const tr=(fr,en)=>locale==="en"?en:fr;
 async function submit(e){e.preventDefault();if(busy)return;setBusy(true);setError("");try{const s=await login(base,identifier,password);onSession(s)}catch{setError(tr("Connexion impossible. Vérifiez vos identifiants ou réessayez plus tard.","Unable to sign in. Check your credentials or try again later."))}finally{setPassword("");setBusy(false)}}
 return <section className="card"><h1>{tr("Connexion","Sign in")}</h1><form onSubmit={submit} style={{display:"grid",gap:12}}><label>{tr("Identifiant WideMeet","WideMeet ID")}<input autoComplete="username" required value={identifier} onChange={e=>setIdentifier(e.target.value)} maxLength={27}/></label><label>{tr("Mot de passe","Password")}<input autoComplete="current-password" required type={show?"text":"password"} value={password} onChange={e=>setPassword(e.target.value)} maxLength={256}/></label><label><input type="checkbox" checked={show} onChange={e=>setShow(e.target.checked)}/> {tr("Afficher le mot de passe","Show password")}</label><button type="submit" disabled={busy||!base}>{busy?tr("Connexion…","Signing in…"):tr("Se connecter","Sign in")}</button>{!base&&<p>{tr("Connexion momentanément indisponible.","Sign-in temporarily unavailable.")}</p>}{error&&<p role="alert">{error}</p>}</form><button onClick={onBack}>{tr("Retour","Back")}</button></section>
}
