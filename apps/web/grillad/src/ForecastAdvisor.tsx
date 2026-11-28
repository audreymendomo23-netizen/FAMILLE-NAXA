import React from 'react';
export function ForecastAdvisor({prediction}:{prediction:any}){
 const rows=Array.isArray(prediction?.items)?prediction.items:[];
 const candidates=rows.filter((x:any)=>Number.isFinite(x.additional_preparation)&&x.additional_preparation>0&&x.quantity!=null);
 return <article><h2>Assistant de pilotage</h2><p>Conseils calculés à partir des prévisions serveur et des quantités disponibles, à confirmer par le responsable.</p>{!rows.length?<p>Historique insuffisant : aucun conseil chiffré.</p>:<>{candidates.length?candidates.map((x:any)=><p key={x.item}>Vérifier {x.name} : préparer jusqu’à {x.additional_preparation} unités supplémentaires selon la demande estimée.</p>):<p>Aucun besoin supplémentaire identifié parmi les prévisions disponibles.</p>}{rows.some((x:any)=>x.quantity==null)&&<p>Certains articles ont un historique insuffisant. Ne pas extrapoler automatiquement.</p>}</>}<p>Aucune vente, dépense ou modification automatique.</p></article>
}
