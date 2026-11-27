// Minimal local PDF exporter: no data leaves the device. ASCII transliteration for built-in Helvetica.
const ascii=s=>String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/[^\x20-\x7e]/g,'?');
const esc=s=>ascii(s).replace(/[\\()]/g,'\\$&');
export function pdfBytes(title,lines){
 const flat=[title,...lines].flatMap(s=>{const t=ascii(s);return t.match(/.{1,88}/g)||['']});
 const pages=[];for(let i=0;i<flat.length;i+=45)pages.push(flat.slice(i,i+45));
 const objects=['<< /Type /Catalog /Pages 2 0 R >>','', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'];
 const kids=[];
 for(const p of pages){const page=objects.length+1,stream=page+1;kids.push(page+' 0 R');const content='BT /F1 11 Tf 45 790 Td 16 TL '+p.map((s,i)=>(i?'T* ':'')+'('+esc(s)+') Tj').join('\n')+' ET\n';objects.push('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents '+stream+' 0 R >>','<< /Length '+content.length+' >>\nstream\n'+content+'endstream')}
 objects[1]='<< /Type /Pages /Count '+kids.length+' /Kids ['+kids.join(' ')+'] >>';
 let out='%PDF-1.4\n';const offsets=[0];objects.forEach((s,i)=>{offsets.push(out.length);out+=(i+1)+' 0 obj\n'+s+'\nendobj\n'});const xref=out.length;out+='xref\n0 '+offsets.length+'\n0000000000 65535 f \n'+offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')+'trailer\n<< /Size '+offsets.length+' /Root 1 0 R >>\nstartxref\n'+xref+'\n%%EOF\n';return new TextEncoder().encode(out)
}
export function downloadPdf(filename,title,lines){const u=URL.createObjectURL(new Blob([pdfBytes(title,lines)],{type:'application/pdf'}));const a=document.createElement('a');a.href=u;a.download=filename;a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)}
export function receiptLines(r){return [r.organization,r.site,'Reference : '+r.id,'Date : '+r.at,r.cancelled?'ANNULE - ne vaut pas paiement':'Vente confirmee par GRILLAD',...r.lines.map(l=>l.name+' x '+l.qty+' @ '+l.price+' = '+l.total+' FCFA'),'Total initial : '+r.total+' FCFA','Total net : '+r.net_total+' FCFA']}
export function reportLines(r){const money=n=>n==null?'Non attribue / inconnu':n+' FCFA';return ['Periode : '+r.from+' / '+r.to,'CA : '+money(r.ca),'Direct : '+money(r.direct_ca),'Connect : '+money(r.connect_ca),'Cout : '+money(r.cost),'Depenses : '+money(r.expenses),'Encaissements especes : '+money(r.encaissements),'Achats documentaires (non imputes) : '+money(r.purchase_amount),...(r.purchases_by_supplier??[]).map(s=>s.supplier+' : '+money(s.amount)),'Ventes : '+r.sales_count+' / Unites : '+r.quantity,...r.sites.map(s=>s.name+' : CA '+money(s.ca)+' / depenses '+money(s.expenses)),'Donnees confirmees serveur uniquement']}
