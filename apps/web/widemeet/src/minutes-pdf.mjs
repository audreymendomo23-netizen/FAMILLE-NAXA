// Exact approved server version only; never use unsaved editor content.
export async function createMinutesPdf(data,locale="fr"){
 if(!data?.published_at||!data.approved_at||typeof data.body!=="string"||typeof data.recipient_name!=="string"||data.verification_id!==data.version_id)throw Error("INVALID_EXPORT");
 const tr=(fr,en)=>locale==="en"?en:fr,fmt=x=>new Date(x).toLocaleString(locale,{timeZone:"Africa/Douala"});
 const [p,f]=await Promise.all([import("pdfmake/build/pdfmake.js"),import("pdfmake/build/vfs_fonts.js")]);const pdf=p.default??p;pdf.addVirtualFileSystem(f.default??f);
 const doc={pageSize:"A4",pageMargins:[45,55,45,60],defaultStyle:{font:"Roboto",fontSize:11,lineHeight:1.2,color:"#18222b"},header:{text:"WideMeet  |  "+tr("Compte rendu","Meeting minutes"),bold:true,color:"#315c31",fontSize:10,margin:[45,25,45,0]},footer:(page,pages)=>({margin:[45,12,45,0],fontSize:8,color:"#52606d",columns:[{text:tr("Copie destinée à ","Copy intended for ")+data.recipient_name,width:"*"},{text:page+" / "+pages,alignment:"right",width:45}]}),content:[
 {text:data.snapshot?.title??tr("Réunion","Meeting"),fontSize:21,bold:true,margin:[0,0,0,14]},
 ...[["scheduled_ms",tr("Date programmée","Scheduled date")],["started_ms",tr("Début enregistré","Recorded start")],["closed_ms",tr("Clôture enregistrée","Recorded closure")]].filter(([k])=>Number.isSafeInteger(data.snapshot?.[k])).map(([k,label])=>({text:label+" : "+fmt(data.snapshot[k])})),
 ...(Number.isSafeInteger(data.snapshot?.started_ms)&&Number.isSafeInteger(data.snapshot?.closed_ms)&&data.snapshot.closed_ms>=data.snapshot.started_ms?[{text:tr("Durée de réunion (hors distinction des pauses)","Meeting elapsed duration (not excluding pauses)")+" : "+Math.floor((data.snapshot.closed_ms-data.snapshot.started_ms)/60000)+" min"}]:[]),
 {text:tr("Version validée et publiée","Approved and published version")+" "+data.version,bold:true},
 {text:tr("Validation","Approval")+" : "+fmt(data.approved_at)},{text:tr("Publication","Publication")+" : "+fmt(data.published_at)},{text:tr("Identifiant de vérification","Verification identifier")+" : "+data.verification_id,fontSize:9,margin:[0,0,0,15]},
 {text:tr("Compte rendu rédigé et validé par un humain","Human-authored and approved minutes"),bold:true,margin:[0,0,0,8]},{text:data.body},
 {text:tr("Copie locale : une révocation ultérieure ne rappelle pas le fichier exporté.","Local copy: later revocation cannot recall an exported file."),fontSize:9,italics:true,margin:[0,18,0,0]}
 ]};
 return new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(Error("PDF_UNAVAILABLE")),30000);try{pdf.createPdf(doc).getBlob(blob=>{clearTimeout(t);resolve(blob)})}catch(e){clearTimeout(t);reject(e)}});
}
