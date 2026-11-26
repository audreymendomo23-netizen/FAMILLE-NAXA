import {spawnSync} from "node:child_process";
import {pathToFileURL} from "node:url";
import {publicKeyAllowed} from "../../apps/web/admin-console/src/zipple-recovery.mjs";
export function validateAdmin(env){
 if(env.VITE_ADMIN_SUPABASE_URL!=="https://idupfjbkwjcavyisxteo.supabase.co"||!publicKeyAllowed(env.VITE_ADMIN_PUBLIC_KEY))throw Error("ZIPPLE admin requires exact Supabase project and public Auth key");
 for(const [name,value] of Object.entries(env)){
  if(!name.startsWith("VITE_"))continue;
  if(name!=="VITE_ADMIN_SUPABASE_URL"&&name!=="VITE_ADMIN_PUBLIC_KEY")throw Error("Unexpected public environment variable: "+name);
  if(/^sb_secret_/i.test(value??""))throw Error("Private key forbidden");
 }
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 validateAdmin(process.env);
 const result=spawnSync("npm",["run","build","--workspace","@famille/admin-console"],{stdio:"inherit",shell:false});
 if(result.error)throw result.error;process.exitCode=result.status??1;
}
