export type PurchaseOrderLine={name:string;unit:string;qtyMilli:number;totalXaf:number;receivedMilli:number};
export type PurchaseOrderDocument={reference:string;supplier:string;lines:PurchaseOrderLine[]};
export function purchaseOrderText(order:PurchaseOrderDocument,en:boolean){
 const t=(fr:string,eng:string)=>en?eng:fr;
 const lines=order.lines;
 if(!order.reference||!order.supplier||!lines.length||lines.some(l=>!l.name||!Number.isSafeInteger(l.qtyMilli)||l.qtyMilli<=0||!Number.isSafeInteger(l.totalXaf)||l.totalXaf<=0||!Number.isSafeInteger(l.receivedMilli)||l.receivedMilli<0||l.receivedMilli>l.qtyMilli))throw Error("INVALID_PURCHASE_DOCUMENT");
 const clean=(v:string)=>v.replace(/[\u0000-\u001f\u007f]/g," ").trim();
 return ["ZIPPLE - "+t("Bon de commande fournisseur","Supplier purchase order"),t("Référence : ","Reference: ")+clean(order.reference),t("Fournisseur : ","Supplier: ")+clean(order.supplier),...lines.map(l=>clean(l.name)+" - "+l.qtyMilli/1000+" "+clean(l.unit)+" - "+l.totalXaf+" FCFA - "+t("Reçu : ","Received: ")+l.receivedMilli/1000+" "+clean(l.unit)),t("Total commande : ","Order total: ")+lines.reduce((sum,l)=>sum+l.totalXaf,0)+" FCFA",t("Bon de commande, non une facture ni une preuve de paiement.","Purchase order, not an invoice or payment receipt.")].join("\n");
}
export function purchaseWhatsAppLink(phone:string,order:PurchaseOrderDocument,en:boolean){
 if(!/^[0-9]{9,15}$/.test(phone))return null;
 return "https://wa.me/"+phone+"?text="+encodeURIComponent(purchaseOrderText(order,en));
}
export async function downloadPurchaseOrder(order:PurchaseOrderDocument,en:boolean){
 const content=purchaseOrderText(order,en);const {jsPDF}=await import("jspdf");
 const pdf=new jsPDF({unit:"mm",format:"a4",compress:false});pdf.setFont("helvetica","normal");pdf.setFontSize(11);
 let y=18;for(const line of content.split("\n"))for(const part of pdf.splitTextToSize(line,174)){if(y>278){pdf.addPage();y=18}pdf.text(part,18,y);y+=7}
 pdf.save("zipple-bon-"+order.reference.replace(/[^a-zA-Z0-9_-]/g,"_").slice(0,80)+".pdf");
}
