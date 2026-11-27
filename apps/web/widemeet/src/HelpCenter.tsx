import React,{useState}from"react";
export const helpTopics=[
 ["Comment rejoindre une réunion ?","How do I join a meeting?","Ouvrez Agenda ou Rejoindre, identifiez-vous et acceptez votre invitation. Une salle avec attente nécessite l’admission de l’organisateur.","Open Calendar or Join, sign in and accept your invitation. Waiting rooms require host admission.","agenda"],
 ["Comment protéger mon compte ?","How do I secure my account?","Dans Sécurité, vérifiez vos appareils et révoquez ceux que vous ne reconnaissez pas. Conservez votre clé de récupération en lieu sûr.","In Security, review devices and revoke unfamiliar ones. Keep your recovery key safe.","security"],
 ["Où retrouver mes comptes rendus ?","Where are my minutes?","Les archives affichent uniquement les documents auxquels votre compte a accès. La publication dépend de la validation du responsable.","Archives show only documents your account may access. Publication requires approval.","archives"],
 ["Pourquoi une réunion ne démarre-t-elle pas ?","Why won't a meeting start?","Vérifiez la connexion, l’invitation, l’admission et les droits de l’organisateur. Les fonctions média nécessitent un réseau.","Check connectivity, invitation, admission and organizer rights. Media requires a network.","agenda"]
];
export function HelpCenter({mode,locale,onOpen,onTab,authenticated,onSignIn}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [query,Q]=useState("");
 const go=(key)=>{if(!authenticated&&key!=="faq"){onSignIn();return}if(["agenda","archives","profile"].includes(key))onTab(key);else onOpen(key)};
 const link=(key,fr,en)=><button onClick={()=>go(key)}>{tr(fr,en)}</button>;
 if(mode==="faq")return <section className="card"><label>{tr("Rechercher dans l’aide","Search help")}<input value={query} onChange={e=>Q(e.target.value)}/></label>{helpTopics.filter(t=>t.slice(0,4).some(v=>v.toLowerCase().includes(query.trim().toLowerCase()))).map(t=><details key={t[0]}><summary>{tr(t[0],t[1])}</summary><p>{tr(t[2],t[3])}</p>{link(t[4],"Ouvrir cet espace","Open this area")}</details>)}</section>;
 const info={
 support:["Assistance WideMeet","WideMeet assistance","Le service de tickets et le Livechat ne sont pas encore connectés. Consultez les solutions disponibles sans transmettre votre mot de passe.","Tickets and live chat are not connected yet. Browse available help without sharing your password."],
 connect:["Affichage distant","Remote display","Le récepteur sécurisé n’est pas encore disponible. Vous pouvez rejoindre vos réunions sur cet appareil ; aucun appairage distant n’est confirmé.","Secure receiver is not yet available. Join meetings on this device; no remote pairing is confirmed."],
 transcription:["Comptes rendus et transcription","Minutes and transcription","La transcription automatique n’est pas disponible. Les comptes rendus manuels autorisés restent accessibles dans les archives.","Automatic transcription is unavailable. Authorized manual minutes remain available in archives."],
 translation:["Langues et écoute","Languages and listening","L’interface est disponible en français et anglais. La traduction vocale simultanée n’est pas disponible.","The interface supports French and English. Simultaneous voice translation is unavailable."],
 admin:["Administration","Administration","La console centrale nécessite une intégration et des droits spécifiques. Aucun accès administratif n’est accordé ici.","Central administration requires a dedicated integration and permissions. No administrative access is granted here."]
 }[mode];
 return <section className="card" style={{display:"grid",gap:12}}><h2>{tr(info[0],info[1])}</h2><p>{tr(info[2],info[3])}</p>{mode==="support"&&<>{link("faq","Consulter la FAQ","Read FAQ")}{link("security","Sécuriser mon compte","Secure my account")}</>}{mode==="connect"&&link("agenda","Ouvrir mon agenda","Open calendar")}{mode==="transcription"&&link("archives","Ouvrir mes comptes rendus","Open minutes")}{mode==="translation"&&link("language","Changer la langue de l’interface","Change interface language")}{mode==="admin"&&link("security","Vérifier mes appareils","Review devices")}</section>;
}
