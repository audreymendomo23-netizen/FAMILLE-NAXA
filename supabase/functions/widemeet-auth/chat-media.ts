// B2 dedicated private binary transport, adapted from recording-storage + B6 post-read revalidation.
// All metadata/ACL decisions come from PostgreSQL; no direct bucket links are returned.
import {CHAT_MEDIA_BUCKET,MAX_CHAT_MEDIA_BYTES,decodeMedia,encodeMedia,mediaDigest,safeMediaName,validMediaBytes} from "../../../packages/widemeet-domain/chat-media.mjs";
export async function chatMedia({base,service,p_hash,action,data,rpc,fetcher=fetch}:any){
 const deny=()=>({status:403,body:{error:"scope"}});
 const fail=()=>({status:409,body:{error:"media_unconfirmed"}});
 const visible=(m:any)=>({id:m.id,kind:m.kind,mime:m.mime,name:m.name,bytes:m.bytes,sha256:m.sha256,state:m.state});
 const call=(path:string,options:RequestInit={})=>fetcher(base+"/storage/v1/"+path,{...options,headers:{apikey:service,Authorization:"Bearer "+service,...(options.headers??{})},redirect:"error",cache:"no-store",signal:AbortSignal.timeout(15000)});
 const scope={peer_id:data.peer_id??null,group_id:data.group_id??null,id:data.id};
 const get=(a:string,d:Record<string,unknown>=scope)=>rpc(a,d);
 if(action==="list"){const r=await get("list");return r?{status:200,body:r}:deny()}
 if(action==="revoke"){const r=await get("revoke");return r?{status:200,body:visible(r)}:deny()} // logical revoke first; purge worker must consume tracked ledger.
 const keyOk=(key:unknown)=>typeof key==="string"&&key.length===73&&key.split("/").every(x=>x.length===36&&x.replaceAll("-","").length===32&&[...x].every(c=>"0123456789abcdef-".includes(c)));
 const bucket=await call("bucket/"+CHAT_MEDIA_BUCKET);
 if(!bucket.ok||(await bucket.json()).public!==false)return fail();
 async function verified(m:any){
  if(!keyOk(m.key)||!Number.isSafeInteger(m.bytes)||m.bytes<1||m.bytes>MAX_CHAT_MEDIA_BYTES)throw Error("invalid_metadata");
  const r=await call("object/authenticated/"+CHAT_MEDIA_BUCKET+"/"+m.key);if(!r.ok||!r.body)throw Error("media_missing");
  const reader=r.body.getReader(),parts:Uint8Array[]=[];let n=0;
  try{for(;;){const {done,value}=await reader.read();if(done)break;n+=value.length;if(n>m.bytes)throw Error("size_mismatch");parts.push(value)}}catch(e){await reader.cancel().catch(()=>{});throw e}
  const b=new Uint8Array(n);let at=0;for(const part of parts){b.set(part,at);at+=part.length}
  if(n!==m.bytes||await mediaDigest(b)!==m.sha256||!validMediaBytes(m.kind,m.mime,b))throw Error("integrity");return b;
 }
 if(action==="upload"){
  let b:Uint8Array,name:string;try{b=decodeMedia(data.content);name=safeMediaName(data.name,data.mime);if(!validMediaBytes(data.kind,data.mime,b))throw Error("invalid_media")}catch{return {status:400,body:{error:"invalid_media"}}}
  const m=await get("reserve",{...scope,kind:data.kind,mime:data.mime,name,bytes:b.length,sha256:await mediaDigest(b)});
  if(!m||!keyOk(m.key))return deny();
  if(m.state==="staged"){
   // No overwrite. Lost upload response is resolved only by verifying existing bytes exactly.
   await call("object/"+CHAT_MEDIA_BUCKET+"/"+m.key,{method:"POST",headers:{"Content-Type":m.mime,"x-upsert":"false","Cache-Control":"no-store"},body:b as Uint8Array<ArrayBuffer>}).catch(()=>null);
  }
  try{await verified(m)}catch{return fail()}
  const ready=await get("publish");return ready?{status:200,body:visible(ready)}:deny();
 }
 if(action==="download"){
  const m=await get("read");if(!m)return deny();
  let b:Uint8Array;try{b=await verified(m)}catch{return fail()}
  // B6 pattern: permissions rechecked AFTER fetching and verifying the binary.
  const again=await get("read");
  if(!again||again.key!==m.key||again.sha256!==m.sha256||again.bytes!==m.bytes||again.state!=="ready")return deny();
  return {status:200,body:{...visible(m),content:encodeMedia(b)}};
 }
 return {status:400,body:{error:"invalid_request"}};
}
