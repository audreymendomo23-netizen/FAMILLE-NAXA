import React,{useEffect,useState} from "react";
import QRCode from "qrcode";
// Adapted from NAXA QRCodePaiement.tsx: same local encoder, no external QR service.
export function TableQr({link,en}:{link:string;en:boolean}){
 const [src,S]=useState(""),[error,E]=useState(false);
 useEffect(()=>{let live=true;S("");E(false);QRCode.toDataURL(link,{errorCorrectionLevel:"M",margin:4,width:360,color:{dark:"#000000",light:"#ffffff"}}).then((v:string)=>{if(live)S(v)}).catch(()=>{if(live)E(true)});return()=>{live=false}},[link]);
 return <figure>{error?<p role="alert">{en?"QR unavailable; use the link.":"QR indisponible ; utilisez le lien."}</p>:src?<><img width={240} height={240} src={src} alt={en?"Table order QR":"QR de commande de table"}/><figcaption><a href={src} download="zipple-table-qr.png">{en?"Save printable QR":"Enregistrer le QR imprimable"}</a></figcaption></>:<p role="status">{en?"Generating QR…":"Génération du QR…"}</p>}</figure>
}
