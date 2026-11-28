import React,{useEffect,useState,useMemo} from 'react';
import {client} from './connected-api.mjs';
import {ConnectCustomer} from './ConnectCustomer';
export function ConnectDuo({url,publicKey,fragment}:{url:string;publicKey:string;fragment:string}){
 const api=useMemo(()=>client(url,publicKey),[url,publicKey]);const [state,S]=useState('pending'),[grill,G]=useState(false);
 const match=/^#duo=([A-Za-z0-9_-]{32,128})&table=([0-9a-f]{64})$/.exec(fragment);
 const qr=match?.[1]??'',table=match?.[2]??'';
 useEffect(()=>{let alive=true;S('pending');if(!qr||!table){S('denied');return}api({action:'connect_pair',qr,table}).then(v=>{if(alive)S(v.approved===true&&v.separate_orders===true&&v.separate_tenders===true?'approved':'denied')}).catch(()=>{if(alive)S('denied')});return()=>{alive=false}},[api,qr,table]);
 if(state!=='approved')return <main><h1>ZIPPLE × GrillaD</h1><p role="status">{state==='pending'?'Vérification du partenariat…':'Partenariat indisponible ou QR non autorisé.'}</p></main>;
 return grill?<><button onClick={()=>G(false)}>Retour aux deux espaces</button><ConnectCustomer url={url} publicKey={publicKey} qr={qr}/></>:<main><h1>Choisissez votre espace</h1><p>Deux commandes, deux règlements séparés auprès de chaque vendeur. Aucun paiement collecté ici.</p><article><h2>Bar ZIPPLE</h2><a href={'https://naxa-zipple.pages.dev/#table='+table} rel="noreferrer">Voir la carte du bar</a></article><article><h2>Grillades GrillaD</h2><button onClick={()=>G(true)}>Voir les grillades</button></article></main>
}
