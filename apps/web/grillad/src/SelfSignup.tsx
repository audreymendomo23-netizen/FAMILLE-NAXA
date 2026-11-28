import React,{useState} from 'react';
import {translate} from './grillad-locale.mjs';
export function SelfSignup({locale,busy,mode,request,done,back}:{locale:string;busy:boolean;mode:'signup'|'reset';request:(body:any)=>Promise<any>;done:(s:any)=>void;back:()=>void}){
 const tr=(v:string)=>translate(v,locale);const [step,Step]=useState(0),[draft,Draft]=useState<Record<string,string>>({}),[error,ErrorText]=useState(''),[show,Show]=useState(false);
 const field=(k:string,l:string,type='text')=><label className="atelier-field"><span>{tr(l)}</span><input name={k} type={type} required disabled={busy} autoComplete={type==='password'?'new-password':undefined}/></label>;
 async function submit(e:React.FormEvent<HTMLFormElement>){e.preventDefault();if(busy)return;const f=Object.fromEntries(new FormData(e.currentTarget));ErrorText('');try{
  if(mode==='signup'&&step===0){const {password,confirm,...profile}=f;if(password!==confirm)throw Error('Les mots de passe ne correspondent pas.');await request({action:'signup_start',...profile,password});Draft(Object.fromEntries(Object.entries(profile).map(([k,v])=>[k,String(v)])));Step(1)}
  else if(mode==='signup'){const s=await request({action:'signup_complete',...draft,verification:f.verification});done(s)}
  else if(step===0){await request({action:'recovery_email',email:f.email});Draft({email:String(f.email)});Step(1)}
  else{if(f.password!==f.confirm)throw Error('Les mots de passe ne correspondent pas.');const s=await request({action:'recovery_complete',...draft,verification:f.verification,password:f.password});Step(2);ErrorText(s.sessions_revoked?'Mot de passe modifié.':'Mot de passe modifié. Déconnexion des autres appareils non confirmée.')}
 }catch(e:any){ErrorText(e?.message==='Les mots de passe ne correspondent pas.'?e.message:'Vérifiez les informations et le code reçu, puis réessayez. Mot de passe : au moins 10 caractères, une lettre, un chiffre et un caractère spécial.')}}
 return <section className="auth-panel atelier-form-panel" aria-busy={busy}><h1>{tr(mode==='signup'?(step===0?'Créer mon compte':'Vérifier mon adresse e-mail'):(step===0?'Mot de passe oublié':'Créer un nouveau mot de passe'))}</h1>
 {mode==='signup'&&<p>{tr('72 heures gratuites, sans paiement.')}</p>}{step===1&&<p>{tr('Copiez le code ou le lien de vérification reçu par e-mail, sans ouvrir le lien.')}</p>}
 {step!==2&&<form key={step} onSubmit={submit}>
 {step===0&&<>{mode==='signup'&&field('name','Nom et prénom')}{field('email','Adresse e-mail','email')}{mode==='signup'&&<>{field('phone','Téléphone (+237…)','tel')}{field('organization','Nom de l’entreprise')}{field('site_name','Premier point de vente')}<details><summary>{tr('Conditions d’utilisation et confidentialité')}</summary><p>{tr('Essai gratuit de 72 heures, sans prélèvement automatique. Les données servent à fournir et sécuriser le service. Après expiration, les opérations sont bloquées jusqu’au renouvellement.')}</p></details><label><input type="checkbox" name="terms" value="grillad-2026-11-28-v1" required/>{tr('J’accepte les conditions d’utilisation et la politique de confidentialité')}</label></>}</>}
 {step===1&&field('verification','Code ou lien de vérification')}
 {(mode==='signup'&&step===0||mode==='reset'&&step===1)&&<>{field('password','Mot de passe',show?'text':'password')}{field('confirm','Confirmer le mot de passe',show?'text':'password')}<button type="button" onClick={()=>Show(x=>!x)}>{tr(show?'Masquer le mot de passe':'Afficher le mot de passe')}</button></>}
 <button disabled={busy} className="atelier-submit">{tr(step===0?'Continuer':mode==='signup'?'Démarrer mon essai gratuit':'Enregistrer le nouveau mot de passe')}</button></form>}
 {error&&<p role="status">{tr(error)}</p>}<button disabled={busy} onClick={back}>{tr('Retour à la connexion')}</button></section>
}
