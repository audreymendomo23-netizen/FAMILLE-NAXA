// Isolated recovery: authenticate archive, consult the CURRENT ledger before any upload.
// Never restore a historical database as the authoritative purge ledger.
import {createHash} from "node:crypto";
import {openArchive} from "./widemeet-b6-backup.mjs";
const digest=b=>createHash("sha256").update(b).digest("hex");
export async function restoreEligibleAudio({archive,key,lookup,storage}){
 if(typeof lookup!=="function"||typeof storage?.put!=="function"||typeof storage?.removeVerified!=="function")throw Error("restore guard configuration");
 const entries=openArchive(archive,key);
 const check=async e=>{
  const [room_id,file]=e.path.split("/"),id=file.slice(0,-4),row=await lookup(id);
  if(!row||row.id!==id||row.room_id!==room_id||row.storage_key!==e.path||row.phase!=="complete"||row.disposition!=="retain"||row.purge_requested_at!==null||row.purged_at!==null||!Number.isFinite(Date.parse(row.finished_at))||Date.parse(row.finished_at)<=Date.now()-90*86400000)return null;
  if(row.content_sha256!==digest(e.bytes)||row.bytes!==e.bytes.length)throw Error("ledger digest mismatch");
  return {id,room_id};
 };
 let restored=0,skipped=0;
 // Preflight every entry before writing anything; a failed lookup never defaults to permit.
 for(const e of entries)await check(e);
 for(const e of entries){
  const row=await check(e);if(!row){skipped++;continue}
  await storage.put(row,e.bytes,digest(e.bytes));
  try{if(!await check(e))throw Error("authorization changed during restore")}
  catch(e2){await storage.removeVerified(e.path);throw e2}
  restored++;
 }
 return {restored,skipped};
}
