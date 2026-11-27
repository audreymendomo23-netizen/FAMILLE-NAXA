// Isolated archive rehearsal, adapted from NAXA's manifest/hash and private archive pattern.
// No hosted bucket enumeration, no production credentials, no database restore claim.
import {createCipheriv,createDecipheriv,createHash,randomBytes} from "node:crypto";
import {mkdtemp,mkdir,writeFile,readFile,rm} from "node:fs/promises";
import {join} from "node:path";
const MAGIC=Buffer.from("WMB6v1");
const keyPattern=/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\.ogg$/;
const MAX=16*1024*1024;
const digest=b=>createHash("sha256").update(b).digest("hex");
function checkKey(key){if(!Buffer.isBuffer(key)||key.length!==32)throw Error("32-byte archive key required")}
function validate(entries){
 if(!Array.isArray(entries)||entries.length<1||entries.length>100)throw Error("invalid archive entries");
 const seen=new Set();let total=0;
 for(const e of entries){
  if(!e||typeof e.path!=="string"||!keyPattern.test(e.path)||seen.has(e.path)||!Buffer.isBuffer(e.bytes)||e.bytes.length<1)throw Error("invalid archive object");
  seen.add(e.path);total+=e.bytes.length;if(total>MAX)throw Error("archive too large");
 }
}
export function sealArchive(entries,key){
 checkKey(key);validate(entries);
 const payload=Buffer.from(JSON.stringify(entries.map(e=>({path:e.path,sha256:digest(e.bytes),size:e.bytes.length,data:e.bytes.toString("base64")}))));
 const iv=randomBytes(12),cipher=createCipheriv("aes-256-gcm",key,iv);cipher.setAAD(MAGIC);
 return Buffer.concat([MAGIC,iv,cipher.update(payload),cipher.final(),cipher.getAuthTag()]);
}
export function openArchive(archive,key){
 checkKey(key);
 if(!Buffer.isBuffer(archive)||archive.length<35||archive.length>MAX*2||!archive.subarray(0,6).equals(MAGIC))throw Error("invalid archive envelope");
 const decipher=createDecipheriv("aes-256-gcm",key,archive.subarray(6,18));decipher.setAAD(MAGIC);decipher.setAuthTag(archive.subarray(-16));
 const clear=Buffer.concat([decipher.update(archive.subarray(18,-16)),decipher.final()]);
 const manifest=JSON.parse(clear.toString("utf8"));if(!Array.isArray(manifest)||manifest.length>100)throw Error("invalid manifest");
 const entries=manifest.map(e=>{
  if(!e||typeof e.data!=="string"||typeof e.sha256!=="string"||!Number.isSafeInteger(e.size))throw Error("invalid manifest entry");
  const bytes=Buffer.from(e.data,"base64");if(bytes.toString("base64")!==e.data||bytes.length!==e.size||digest(bytes)!==e.sha256)throw Error("archive integrity failed");return {path:e.path,bytes};
 });
 validate(entries);return entries;
}
export async function restoreArchive(archive,key,tempParent){
 const entries=openArchive(archive,key); // authenticate and validate all objects before writing any file
 const root=await mkdtemp(join(tempParent,"wm-b6-restore-"));
 try{
  for(const e of entries){const [folder,name]=e.path.split("/");const dir=join(root,folder);await mkdir(dir,{mode:0o700,recursive:true});const file=join(dir,name);await writeFile(file,e.bytes,{flag:"wx",mode:0o600});if(digest(await readFile(file))!==digest(e.bytes))throw Error("restore verification failed")}
  return {root,restored:entries.length};
 }catch(e){await rm(root,{recursive:true,force:true});throw e}
}
