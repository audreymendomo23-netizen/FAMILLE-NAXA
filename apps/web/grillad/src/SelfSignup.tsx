import React,{useState} from 'react';
import {translate} from './grillad-locale.mjs';
export function SelfSignup({locale,busy,request,done,back}:{locale:string;busy:boolean;request:(body:any)=>Promise<any>;done:(s:any)=>void;back:()=>void}){
 const tr=(v:string)=>translate(v,locale);const [error,ErrorText]=useState(''),[show,Show]=useState(false);
 const field=(k:string,l:string,type='text')=><label className="atelier-field"><span>{tr(l)}</span><input name={k} type={type} required disabled={busy} autoComplete={k==='username'?'username':k==='password'||k==='confirm'?'new-password':undefined}/></label>;
 async function submit(e:React.FormEvent<HTMLFormElement>){e.preventDefault();if(busy)return;const {password,confirm,...profile}=Object.fromEntries(new FormData(e.currentTarget));ErrorText('');if(password!==confirm){ErrorText('Les mots de passe ne correspondent pas.');return}try{done(await request({action:'signup_internal',...profile,password}))}catch{ErrorText('Vérifiez votre identifiant, vos informations et votre mot de passe, puis réessayez.')}}
 return <section className="auth-panel atelier-form-panel" aria-busy={busy}><h1>{tr('Créer mon compte')}</h1><p>{tr('72 heures gratuites, sans paiement.')}</p><form onSubmit={submit}>
 {field('name','Nom et prénom')}{field('username','Nom d’utilisateur')}{field('phone','Téléphone (+237…)','tel')}{field('organization','Nom de l’entreprise')}{field('site_name','Premier point de vente')}
 <details><summary>{tr('Conditions d’utilisation et confidentialité')}</summary><p>{tr('Essai gratuit de 72 heures, sans prélèvement automatique. Les données servent à fournir et sécuriser le service. Après expiration, les opérations sont bloquées jusqu’au renouvellement.')}</p></details>
 <label><input type="checkbox" name="terms" value="grillad-2026-11-28-v1" required/>{tr('J’accepte les conditions d’utilisation et la politique de confidentialité')}</label>
 {field('password','Mot de passe',show?'text':'password')}{field('confirm','Confirmer le mot de passe',show?'text':'password')}<button type="button" onClick={()=>Show(x=>!x)}>{tr(show?'Masquer le mot de passe':'Afficher le mot de passe')}</button>
 <button disabled={busy} className="atelier-submit">{tr('Démarrer mon essai gratuit')}</button></form>{error&&<p role="status">{tr(error)}</p>}<button disabled={busy} onClick={back}>{tr('Retour à la connexion')}</button></section>
}
