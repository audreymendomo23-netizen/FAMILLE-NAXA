import React,{useEffect,useRef,useState}from"react";
import{identityAction}from"./session.mjs";
async function encodePhoto(file){
 if(!file||file.size>8*1024*1024||!["image/jpeg","image/png","image/webp"].includes(file.type))throw Error("invalid photo");
 const image=await createImageBitmap(file);
 try{
 if(!image.width||!image.height||image.width>16000||image.height>16000)throw Error("invalid dimensions");
 const scale=Math.min(1,256/Math.max(image.width,image.height)),canvas=document.createElement("canvas");
 canvas.width=Math.max(1,Math.round(image.width*scale));canvas.height=Math.max(1,Math.round(image.height*scale));
 const ctx=canvas.getContext("2d");if(!ctx)throw Error("image unavailable");
 ctx.fillStyle="#fff";ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(image,0,0,canvas.width,canvas.height);
 for(const quality of [.82,.65,.45,.25]){const encoded=canvas.toDataURL("image/jpeg",quality);if(encoded.startsWith("data:image/jpeg;base64,")&&encoded.length<=87384)return encoded.split(",")[1]}
 throw Error("photo too large");
 }finally{image.close()}
}
export function ProfilePhoto({base,session,locale}){
 const tr=(fr,en)=>locale==="en"?en:fr;
 const [jpeg,setJpeg]=useState(null),[busy,setBusy]=useState(false),[error,setError]=useState(false),[notice,setNotice]=useState("");
 const mounted=useRef(false);
 const req=(action,data={})=>identityAction(base,session,action,data);
 async function load(){const r=await req("photo-read");if(mounted.current)setJpeg(typeof r.jpeg==="string"&&r.jpeg.length<=87384&&/^[A-Za-z0-9+/]+={0,2}$/.test(r.jpeg)?r.jpeg:null)}
 useEffect(()=>{mounted.current=true;setBusy(true);load().catch(()=>{if(mounted.current)setError(true)}).finally(()=>{if(mounted.current)setBusy(false)});return()=>{mounted.current=false}},[]);
 async function save(file){if(!file||busy)return;setBusy(true);setError(false);setNotice("");try{const next=await encodePhoto(file);if(!mounted.current)return;await req("photo-save",{jpeg:next});await load();if(mounted.current)setNotice(tr("Photo enregistrée","Photo saved"))}catch{if(mounted.current)setError(true)}finally{if(mounted.current)setBusy(false)}}
 async function remove(){if(busy)return;setBusy(true);setError(false);setNotice("");try{await req("photo-delete");await load();if(mounted.current)setNotice(tr("Photo supprimée","Photo removed"))}catch{if(mounted.current)setError(true)}finally{if(mounted.current)setBusy(false)}}
 return <fieldset><legend>{tr("Ma photo de profil","My profile photo")}</legend>{jpeg&&<img src={"data:image/jpeg;base64,"+jpeg} alt={tr("Votre photo de profil","Your profile photo")} style={{width:96,height:96,objectFit:"cover",borderRadius:"50%"}}/>}<label>{tr("Choisir une photo","Choose a photo")}<input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={e=>{const f=e.target.files?.[0];e.target.value="";void save(f)}}/></label>{jpeg&&<button type="button" disabled={busy} onClick={remove}>{tr("Supprimer la photo","Remove photo")}</button>}{busy&&<p role="status">{tr("Chargement…","Loading…")}</p>}{error&&<p role="alert">{tr("Photo non confirmée. Choisissez une image valide et réessayez.","Photo not confirmed. Choose a valid image and try again.")}</p>}{notice&&<p role="status">{notice}</p>}</fieldset>
}
