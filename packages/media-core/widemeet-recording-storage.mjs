// Server-only private bucket adapter. No public/signed URL leaves the service.
import {createHash} from "node:crypto";
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
const keyPattern=/^[a-f0-9-]{36}\/[a-f0-9-]{36}\.ogg$/;
const bucket="wm-recordings";
export function createWideMeetRecordingStorage({supabaseUrl,serviceKey,fetcher=fetch}){
 const base=new URL(supabaseUrl);if(!["http:","https:"].includes(base.protocol)||base.username||base.password||base.pathname!=="/"||base.search||base.hash||!serviceKey)throw Error("invalid storage");
 const headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey};
 const call=(path,options={})=>fetcher(new URL("/storage/v1/"+path,base),{...options,headers:{...headers,...options.headers},cache:"no-store",redirect:"error",signal:AbortSignal.timeout(30000)});
 async function checkBucket(){const r=await call("bucket/"+bucket);if(!r.ok||(await r.json()).public!==false)throw Error("private recording bucket unavailable")}
 async function verify(key,sha,size){
  const r=await call("object/authenticated/"+bucket+"/"+key);if(!r.ok)throw Error("recording storage unavailable");
  const bytes=Buffer.from(await r.arrayBuffer());if(bytes.length!==size||createHash("sha256").update(bytes).digest("hex")!==sha)throw Error("recording integrity failure");
 }
 async function put(row,bytes,sha){
  if(!uuid.test(row.room_id)||!uuid.test(row.id)||!Buffer.isBuffer(bytes)||bytes.length<1000||bytes.length>128*1024*1024||!/^[a-f0-9]{64}$/.test(sha))throw Error("invalid recording");
  await checkBucket();const key=row.room_id+"/"+row.id+".ogg";
  const r=await call("object/"+bucket+"/"+key,{method:"POST",headers:{"Content-Type":"audio/ogg","x-upsert":"false","Cache-Control":"no-store"},body:bytes});
  if(!r.ok)throw Error("private upload failed");
  try{await verify(key,sha,bytes.length)}catch(e){await remove(key).catch(()=>{});throw e}
  return key;
 }
 async function remove(key){if(!keyPattern.test(key))throw Error("invalid key");await checkBucket();const r=await call("object/"+bucket,{method:"DELETE",headers:{"Content-Type":"application/json"},body:JSON.stringify({prefixes:[key]})});if(!r.ok)throw Error("private delete failed")}
 // Delete, then verify the exact object is absent in the private bucket.
 async function removeVerified(key){
  const parts=key.split("/");
  if(parts.length!==2||!uuid.test(parts[0])||!parts[1].endsWith(".ogg")||!uuid.test(parts[1].slice(0,-4)))throw Error("invalid key");
  await remove(key);
  const r=await call("object/list/"+bucket,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({prefix:parts[0],search:parts[1],limit:100,offset:0})});
  if(!r.ok)throw Error("private absence check failed");
  const items=await r.json();
  if(!Array.isArray(items)||items.length>=100||items.some(item=>!item||typeof item.name!=="string"||item.name===parts[1]))throw Error("private deletion not confirmed");
 }
 return {put,remove,removeVerified};
}
