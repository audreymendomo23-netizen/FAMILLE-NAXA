// Deterministic evidence-based assistant. Does not claim vision, causal detection or LLM inference.
export function operationalBrief(scope,incidents,observations,correlations,now){
 if(!scope||!Number.isFinite(now)||![incidents,observations,correlations].every(Array.isArray))throw Error("INVALID_INPUT");
 const scoped=r=>r&&r.organization_id===scope.organization&&r.site_id===scope.site;
 const unique=xs=>[...new Map(xs.filter(scoped).filter(r=>typeof r.id==="string").map(r=>[r.id,r])).values()];
 const i=unique(incidents),o=unique(observations),f=unique(correlations);
 const latest=new Map();for(const v of o){const t=Date.parse(v.observed_at);if(!Number.isFinite(t)||t>now||typeof v.device_id!=="string")continue;const prev=latest.get(v.device_id);if(!prev||Date.parse(prev.observed_at)<t)latest.set(v.device_id,v)}
 const open=i.filter(x=>x.state!=="closed"),crit=open.filter(x=>x.priority==="P1"),faults=[...latest.values()].filter(x=>now-Date.parse(x.observed_at)<=120000&&["fault","offline"].includes(x.status)),stale=[...latest.values()].filter(x=>now-Date.parse(x.observed_at)>120000);
 // Historical source events, never infer that an earlier alarm is currently active.
 const fire=f.filter(x=>["alarm","evacuation","prealarm"].includes(x.source_state)),related=fire.filter(x=>x.association==="temporal_association"&&Number(x.nearby_warnings)>0);
 return {incidentCount:i.length,openCount:open.length,criticalCount:crit.length,faultCount:faults.length,staleCount:stale.length,fireEventCount:fire.length,relatedCount:related.length,requiresHumanDecision:true,
 evidence:[...crit.map(x=>({id:x.id,kind:"critical_incident"})),...faults.map(x=>({id:x.id,kind:"device_fault"})),...related.map(x=>({id:x.id,kind:"historical_temporal_association"}))],
 recommendations:[...(crit.length?["Consulter les incidents prioritaires et suivre les procédures du site."]:[]),...(fire.length?["Consulter l’état du système incendie local ; les événements historiques ne prouvent pas l’état actuel."]:[]),...(faults.length?["Vérifier les appareils en défaut et examiner les ordres de maintenance."]:[]),...(stale.length?["Vérifier les données anciennes avant toute conclusion."]:[]),...(!i.length&&!o.length&&!f.length?["Aucune donnée chargée : impossible de conclure sur la sécurité."]:[])]};
}
