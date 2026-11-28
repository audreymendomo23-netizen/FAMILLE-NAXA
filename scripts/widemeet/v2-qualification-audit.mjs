import {readFileSync,writeFileSync} from "node:fs";
import assert from "node:assert/strict";
const replay=readFileSync("scripts/widemeet/replay.mjs","utf8");
const cases=[
["01.1",[],"Master original: captures comparées, logo et photos sources non intégrés"],
["01.2",["actual Edge/PostgREST room create","real opaque session logout and revocation"],"Captures et salle Meet conforme au master"],
["01.3",["PASS V2 professional position","PASS V2 Chromium professional directory"],"Poste/fiche sur toutes surfaces et parité Android"],
["01.4",["PASS V2 Chromium professional directory"],"Android Compose et responsive/captures à qualifier"],
["02.1",["workspace private chat exact retry","B2 group cursor","B2 Web group actual attachment upload/download"],"Parité V2 et UI master"],
["02.2",[],"Appels directs: signalisation et transport réel; Meet seul ne suffit pas"],
["02.3",["B2 collective group: three accounts","B2 real private Storage verified deletion"],"Suppression message pour soi/tous et reçus complets"],
["02.4",[],"Présence masquable, non-divulgation et filtre En ligne"],
["03.1",["PASS V2 enterprise feed and official announcement","PASS V2 private company post attachment","PASS V2 company team targeting","PASS V2 company agency targeting","PASS V2 Chromium private professional video"],"Qualification vidéo et audience Android/Web/PWA, quotas à arbitrer"],
["03.2",["B4 actual Edge majority rules","PASS V2 company interactions","PASS V2 Chromium reaction","PASS V2 company poll","PASS V2 Chromium company poll"],"Réactions/commentaires/favoris/sondages dans le fil, modération et vidéos"],
["03.3",["actual N4 recipient-scoped in-app notice","PASS V2 enterprise feed and official announcement"],"Ciblage, pièces jointes et qualification UI"],
["03.4",["PASS V2 Chromium enterprise news","PASS V2 Chromium private image preview","PASS V2 company notices"],"Fiche professionnelle cliquable, notifications UI et parité complète à qualifier"],
["04.1",[],"Courrier interne, brouillons, destinataires, signature, réponses"],
["04.2",["actual N4 closed-room minutes versioning","B2 actual private Storage chat file/voice integrity"],"Index transversal sans copies, provenance et révocation"],
["04.3",[],"Raccord des 4 lots, administration, navigation et abonnements"],
["04.4",["B6 real authenticated privacy rights"],"Qualification finale distincte; registre historique 269 non assimilé à 269 succès"]
];
assert.equal(cases.length,16);assert.equal(new Set(cases.map(c=>c[0])).size,16);
const bulk=process.argv[2];assert.match(bulk,/^0[1-4]$/);
const rows=cases.filter(c=>c[0].startsWith(bulk+".")).map(([id,markers,remaining])=>{for(const marker of markers)assert.ok(replay.includes(marker),"Missing existing replay marker "+marker);return {id:"V2-"+id,markers,remaining,status:markers.length?"EXISTING_RECIPE_PENDING_EXECUTION_EVIDENCE":"V2_RECIPE_NOT_YET_IMPLEMENTED"}});
assert.equal(rows.length,4);
writeFileSync(process.argv[3],JSON.stringify({sha:process.env.GITHUB_SHA||"local",bulk,rows,qualified:0,note:"Coverage audit only. Existing runtime workflow jobs must supply their own evidence; no V2 closure inferred."},null,2));
console.log("PASS coverage audit only: V2-"+bulk+"; 4 actions, no product qualification inferred.");
