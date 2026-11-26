import { useTranslation } from "../locale";
import React, { useEffect, useRef, useState } from "react";
const MAX_BYTES=2*1024*1024;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MIME=new Set(["image/jpeg","image/png","image/webp"]);
export function profilePhotoUrls(authEndpoint:string,orgId:string,memberId:string){
  const endpoint=new URL(authEndpoint);
  if(endpoint.protocol!=="https:" || endpoint.username || endpoint.password || endpoint.pathname.replace(/\/$/,"")!=="/functions/v1/naxa-services-auth" || !UUID.test(orgId)||!UUID.test(memberId)) throw new Error("Configuration du stockage invalide.");
  const path=orgId+"/"+memberId+"/avatar.jpg";
  const base=endpoint.origin+"/storage/v1/object/";
  return {read:base+"authenticated/ns-profile-photos/"+path,write:base+"ns-profile-photos/"+path,remove:base+"ns-profile-photos",path};
}
async function jpeg(file:File):Promise<Blob>{
  if(!MIME.has(file.type)||file.size<1||file.size>MAX_BYTES)throw new Error("Photo JPEG, PNG ou WebP de 2 Mo maximum.");
  const bitmap=await createImageBitmap(file);
  try{
    if(bitmap.width*bitmap.height>20_000_000)throw new Error("Dimensions de photo trop grandes.");
    const scale=Math.min(1,768/Math.max(bitmap.width,bitmap.height));
    const canvas=document.createElement("canvas");
    canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));
    const ctx=canvas.getContext("2d");if(!ctx)throw new Error("Image illisible.");
    ctx.fillStyle="#fff";ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(bitmap,0,0,canvas.width,canvas.height);
    const blob=await new Promise<Blob|null>(resolve=>canvas.toBlob(resolve,"image/jpeg",0.85));
    if(!blob||blob.type!=="image/jpeg"||blob.size<1||blob.size>MAX_BYTES)throw new Error("Photo illisible ou trop volumineuse.");
    return blob;
  }finally{bitmap.close();}
}
async function readPhoto(response:Response):Promise<Blob|null>{
  if(!response.ok){
    const data=await response.json().catch(()=>null);
    if(response.status===404 || (response.status===400 && (String(data?.statusCode)==="404"||data?.error==="not_found"||data?.error==="NoSuchKey")))return null;
    throw new Error("Lecture de la photo impossible.");
  }
  const blob=await response.blob();
  if(blob.size>MAX_BYTES||blob.size===0||!MIME.has(blob.type))throw new Error("Photo serveur invalide.");
  return blob;
}
type Props={authEndpoint:string;anonKey:string;orgId:string;memberId:string;getToken:()=>Promise<string>;initials:string};
export function ProfilePhoto({authEndpoint,anonKey,orgId,memberId,getToken,initials}:Props){
  const t=useTranslation();
  const [photo,setPhoto]=useState<string|null>(null);
  const [busy,setBusy]=useState(false);const [message,setMessage]=useState("");
  const urlRef=useRef<string|null>(null);const lifetime=useRef<AbortController|null>(null);
  const tokenRef=useRef(getToken);tokenRef.current=getToken;
  const input=useRef<HTMLInputElement>(null);
  function display(blob:Blob|null,signal:AbortSignal){
    if(signal.aborted)return;
    if(urlRef.current)URL.revokeObjectURL(urlRef.current);
    urlRef.current=blob?URL.createObjectURL(blob):null;setPhoto(urlRef.current);
  }
  async function headers(signal:AbortSignal){
    const token=await tokenRef.current();
    if(signal.aborted)throw new Error("Session expirée.");
    if(!token||!anonKey)throw new Error("Connexion requise.");
    return {apikey:anonKey,Authorization:"Bearer "+token};
  }
  async function request(method:"GET"|"POST"|"DELETE",signal:AbortSignal,body?:Blob){
    const urls=profilePhotoUrls(authEndpoint,orgId,memberId);
    const auth=await headers(signal);
    const response=await fetch(method==="GET"?urls.read:method==="POST"?urls.write:urls.remove,{
      method,credentials:"omit",cache:"no-store",redirect:"error",signal,
      headers:{...auth,...(method==="POST"?{"Content-Type":"image/jpeg","x-upsert":"true","cache-control":"no-store"}:method==="DELETE"?{"Content-Type":"application/json"}:{})},
      body:method==="POST"?body:method==="DELETE"?JSON.stringify({prefixes:[urls.path]}):undefined,
    });
    if(method==="GET")return readPhoto(response);
    if(!response.ok)throw new Error(method==="POST"?"Enregistrement de la photo impossible.":"Suppression de la photo impossible.");
    return null;
  }
  useEffect(()=>{
    const controller=new AbortController();lifetime.current=controller;
    setBusy(true);setMessage("");
    void request("GET",controller.signal).then(blob=>display(blob,controller.signal)).catch(()=>{if(!controller.signal.aborted)setMessage("Photo indisponible. Réessaie.");}).finally(()=>{if(!controller.signal.aborted)setBusy(false);});
    return ()=>{controller.abort();if(urlRef.current)URL.revokeObjectURL(urlRef.current);urlRef.current=null;};
  },[authEndpoint,anonKey,orgId,memberId]);
  async function change(file?:File){
    const signal=lifetime.current?.signal;if(!signal||signal.aborted||busy)return;
    setBusy(true);setMessage("");
    try{
      const image=file?await jpeg(file):undefined;
      if(signal.aborted)return;
      await request(file?"POST":"DELETE",signal,image);
      const confirmed=await request("GET",signal);
      if(file&&!confirmed||!file&&confirmed)throw new Error("La modification n’a pas été confirmée.");
      display(confirmed,signal);
      if(!signal.aborted)setMessage(file?"Photo enregistrée.":"Photo supprimée.");
    }catch(error){if(!signal.aborted)setMessage(error instanceof Error?error.message:"Photo indisponible.");}
    finally{if(!signal.aborted)setBusy(false);}
  }
  return <div style={{display:"flex",alignItems:"center",gap:8,flexWrap:"wrap"}}>
    <div className="avatar">{photo?<img src={photo} alt={t("Photo de profil")} style={{width:"100%",height:"100%",objectFit:"cover",borderRadius:"inherit"}}/>:initials}</div>
    <input ref={input} type="file" accept="image/jpeg,image/png,image/webp" aria-label={t("Fichier photo de profil")} hidden onChange={event=>{const file=event.currentTarget.files?.[0];event.currentTarget.value="";if(file)void change(file);}}/>
    <button className="btn secondary" type="button" disabled={busy} onClick={()=>input.current?.click()}>{t("Photo de profil")}</button>
    {photo&&<button className="btn secondary" type="button" disabled={busy} onClick={()=>{if(window.confirm("Supprimer votre photo de profil ?"))void change();}}>{t("Supprimer la photo")}</button>}
    {message&&<small role="status">{t(message)}</small>}
  </div>;
}
