export const roomCenters=Object.freeze(["chat","rooms","statistics","polls"]);
export const roomCenterText={
 chat:["Messagerie des réunions","Meeting chat","Choisissez une réunion pour consulter les messages autorisés et échanger dans la salle ouverte.","Choose a meeting to view authorized messages and chat in the open room."],
 rooms:["Réunions simultanées","Concurrent meetings","Consultez les salles ouvertes ou en pause auxquelles vous avez accès. Ouvrir une autre salle quitte l’écran courant.","View open or paused rooms you can access. Opening another room leaves the current screen."],
 statistics:["Statistiques des réunions","Meeting statistics","Indicateurs des réunions visibles dans cet espace (200 maximum), pas une consolidation de toute l’entreprise.","Indicators cover visible meetings in this workspace (maximum 200), not company-wide totals."],
 polls:["Votes et enquêtes","Polls and surveys","Choisissez une réunion pour retrouver les votes autorisés et y participer selon vos droits.","Choose a meeting to view authorized polls and participate according to your permissions."]};
export function filterRooms(rows,center,query="",status="all"){
 const q=query.trim().toLocaleLowerCase();
 return rows.filter(r=>r&&typeof r.id==="string"&&(center!=="rooms"||["open","paused"].includes(r.status))&&(status==="all"||r.status===status)&&(!q||String(r.title??"").toLocaleLowerCase().includes(q)));
}
export function roomCounts(rows){const counts={scheduled:0,open:0,paused:0,ended:0};for(const r of rows)if(Object.hasOwn(counts,r.status))counts[r.status]++;return counts;}
