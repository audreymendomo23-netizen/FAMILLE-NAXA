import React,{useState} from 'react';
import {AtelierAuthVisual} from './AtelierAuthVisual';
import {ColdDrafts} from './OfflineDrafts';
import {translate} from './grillad-locale.mjs';
type Stage='login'|'invite'|'recovery';
export function AtelierAuthPages({locale,onLocale,busy,message,clearMessage,onLogin,onRecovery}:{locale:string;onLocale:(v:string)=>void;busy:boolean;message:string;clearMessage:()=>void;onLogin:(f:FormData)=>void;onRecovery:(f:FormData)=>void}){
 const [stage,setStage]=useState<Stage>('login'),[show,Show]=useState(false),[error,ErrorText]=useState('');const tr=(k:string)=>translate(k,locale);
 function go(next:Stage){if(busy)return;setStage(next);Show(false);ErrorText('');clearMessage()}
 function submit(e:React.FormEvent<HTMLFormElement>){e.preventDefault();if(busy)return;const f=new FormData(e.currentTarget);if(stage==='invite'&&f.get('password')!==f.get('confirm')){ErrorText('Les mots de passe ne correspondent pas.');return}ErrorText('');if(stage==='recovery')onRecovery(f);else onLogin(f)}
 const field=(name:string,label:string,type='text',autoComplete='off')=><label className="atelier-field"><span>{tr(label)}</span><input name={name} type={type} autoComplete={autoComplete} required aria-label={tr(label)} disabled={busy}/></label>;
 return <div className={'app auth-shell atelier-auth-pages '+(stage==='login'?'atelier-login':'atelier-secondary')}><header>{stage!=='login'&&<button className="atelier-back" type="button" disabled={busy} aria-label={tr('Retour à la connexion')} onClick={()=>go('login')}>←</button>}<strong className="atelier-wordmark">Grilla<span>D</span></strong><label className="atelier-language"><span>{tr('Langue')}</span><select aria-label={tr('Langue')} value={locale} onChange={e=>onLocale(e.target.value)}><option value="fr">Français</option><option value="en">English</option><option value="ff-CM">Fulfulde</option></select></label></header>
 <main>{stage==='login'&&<AtelierAuthVisual locale={locale} subtitle={tr('Accès professionnel GRILLAD')}/>}
 <section className="auth-panel atelier-form-panel" key={stage} aria-busy={busy}><h1>{tr(stage==='login'?'Connexion':stage==='invite'?'Première connexion':'Mot de passe oublié')}</h1><p className="atelier-auth-description">{tr(stage==='login'?'Accédez à votre espace de gestion.':stage==='invite'?'Activez votre compte avec les informations reçues de votre administrateur.':'Saisissez votre numéro de téléphone. Votre demande sera examinée par l’administrateur.')}</p>
 <form onSubmit={submit} data-auth-stage={stage}>
 {stage==='invite'&&<>{field('invite_request','Référence invitation')}{field('invite_token','Code invitation','password')}</>}
 {field('phone',stage==='recovery'?'Téléphone de récupération':'Téléphone (+237…)','tel','tel')}
 {stage!=='recovery'&&<><label className="atelier-field"><span>{tr('Mot de passe')}</span><div className="atelier-password"><input name="password" aria-label={tr('Mot de passe')} required type={show?'text':'password'} autoComplete={stage==='invite'?'new-password':'current-password'} disabled={busy}/><button type="button" className="atelier-eye" aria-label={tr(show?'Masquer le mot de passe':'Afficher le mot de passe')} aria-pressed={show} onClick={()=>Show(x=>!x)}><svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>{show&&<path d="m3 3 18 18"/>}</svg></button></div></label>{stage==='invite'&&field('confirm','Confirmer le mot de passe','password','new-password')}</>}
 <button className="atelier-submit" disabled={busy}>{tr(stage==='login'?'Se connecter':stage==='invite'?'Activer mon compte':'Envoyer la demande')}</button></form>
 {(error||message)&&<p role="status" className="atelier-auth-message">{tr(error||message)}</p>}
 {stage==='login'?<><div className="atelier-auth-links"><button type="button" disabled={busy} onClick={()=>go('recovery')}>{tr('Mot de passe oublié')}</button><button type="button" disabled={busy} onClick={()=>go('invite')}>{tr('Première connexion avec invitation')}</button></div><div className="atelier-offline"><ColdDrafts/></div></>:<button className="atelier-return" disabled={busy} onClick={()=>go('login')}>{tr('Retour à la connexion')}</button>}
 </section></main></div>
}
