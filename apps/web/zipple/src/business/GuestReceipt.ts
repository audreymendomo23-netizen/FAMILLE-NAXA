type Receipt = {available:boolean;receipt_id:string;order_number:number;site_name:string;settled_at:string;total_xaf:number;paid_xaf:number;refunded_xaf:number;credit_note_xaf:number;methods:{method:string;amount_xaf:number}[];lines:{name:string;qty:number;price_xaf:number}[]};
export async function downloadGuestReceipt(r:Receipt,en:boolean){
 if(!r?.available||!r.receipt_id||!Number.isSafeInteger(r.paid_xaf)||r.paid_xaf<=0)throw Error("UNCONFIRMED");
 const {jsPDF}=await import("jspdf");
 const pdf=new jsPDF({unit:"mm",format:"a4",compress:false});let y=18;
 const t=(a:string,b:string)=>en?b:a;
 const line=(text:string,bold=false)=>{pdf.setFont("helvetica",bold?"bold":"normal");pdf.setFontSize(bold?13:11);for(const part of pdf.splitTextToSize(text.replace(/[\u0000-\u001f\u007f]/g," "),174)){if(y>278){pdf.addPage();y=18}pdf.text(part,18,y);y+=6}};
 const xaf=(n:number)=>String(n)+" FCFA";
 line("ZIPPLE — "+t("Reçu de paiement","Payment receipt"),true);
 line(r.site_name,true);line(t("Reçu : ","Receipt: ")+r.receipt_id);line(t("Commande : ","Order: ")+r.order_number);
 line(t("Règlement confirmé : ","Settlement confirmed: ")+new Date(r.settled_at).toLocaleString(en?"en-CM":"fr-CM",{timeZone:"Africa/Douala"}));y+=4;
 for(const l of r.lines??[])line(l.qty+" × "+l.name+" — "+xaf(l.qty*l.price_xaf));
 y+=4;line(t("Total commande : ","Order total: ")+xaf(r.total_xaf));
 const labels:Record<string,[string,string]>={cash:["Espèces","Cash"],mtn_momo:["MTN MoMo","MTN MoMo"],orange_money:["Orange Money","Orange Money"],bank:["Banque","Bank"],card:["Carte","Card"]};
 for(const m of r.methods??[])line((labels[m.method]?.[en?1:0]??m.method)+" : "+xaf(m.amount_xaf));
 line(t("Montant encaissé : ","Amount collected: ")+xaf(r.paid_xaf),true);
 if(r.credit_note_xaf>0)line(t("Avoirs : ","Credit notes: ")+xaf(r.credit_note_xaf));
 if(r.refunded_xaf>0){line(t("Remboursements : ","Refunds: ")+xaf(r.refunded_xaf));line(t("Net encaissé : ","Net collected: ")+xaf(r.paid_xaf-r.refunded_xaf),true)}
 y+=4;line(t("Merci pour votre visite. Justificatif de paiement, non une facture fiscale.","Thank you for your visit. Payment receipt, not a tax invoice."));
 pdf.save("zipple-recu-"+r.receipt_id+".pdf");
}
