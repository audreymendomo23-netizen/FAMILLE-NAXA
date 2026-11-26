import React,{useState,useRef}from"react";
import{authorizedRequest}from"./session.mjs";
export function ChangePassword({base,session,locale,onChanged,onCancel}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [old,setOld]=useState(""),[next,setNext]=useState(""),[confirm,setConfirm]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const request=useRef(null);
 async function submit(e){e.preventDefault();if(busy||next.length<12||next!==confirm||old===next)return;
 if(!request.current)request.current=crypto.randomUUID();setBusy(true);setError(false);
 try{const result=await authorizedRequest(base,"change-password",{current_password:old,new_password:next,request_id:request.current},session.access_token);
 if(result?.changed!==true||result?.reconnect!==true)throw Error("unconfirmed");onChanged();}
 catch{setError(true)}finally{setOld("");setNext("");setConfirm("");setBusy(false)}}
 return <section className="card"><h2>{tr("Modifier le mot de passe","Change password")}</h2><form onSubmit={submit} style={{display:"grid",gap:12}}>
 <label>{tr("Mot de passe actuel","Current password")}<input required type="password" autoComplete="current-password" value={old} maxLength={256} onChange={e=>setOld(e.target.value)}/></label>
 <label>{tr("Nouveau mot de passe (12 caractères minimum)","New password (at least 12 characters)")}<input required type="password" autoComplete="new-password" value={next} minLength={12} maxLength={256} onChange={e=>setNext(e.target.value)}/></label>
 <label>{tr("Confirmer le nouveau mot de passe","Confirm new password")}<input required type="password" autoComplete="new-password" value={confirm} onChange={e=>setConfirm(e.target.value)} maxLength={256}/></label>
 <button disabled={busy||!old||old===next||next.length<12||next!==confirm}>{tr("Modifier et se reconnecter","Change and sign in again")}</button>
 {error&&<p role="alert">{tr("Modification non confirmée. Réessayez avec les mêmes informations ou contactez le support.","Change not confirmed. Retry with the same details or contact support.")}</p>}
 </form><button disabled={busy} onClick={onCancel}>{tr("Se déconnecter","Sign out")}</button></section>
}
