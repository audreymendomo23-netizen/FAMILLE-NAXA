import {spawnSync} from "node:child_process";
import {pathToFileURL} from "node:url";
export function validate(env){
 if(env.VITE_WIDEMEET_PAGES_PROXY!=="true")throw Error("Pages same-origin proxy required");
 if(env.VITE_WIDEMEET_AUTH_URL)throw Error("External API URL forbidden in Pages build");
 for(const [name,value] of Object.entries(env)){
  if(!name.startsWith("VITE_"))continue;
  if(/SECRET|SERVICE_ROLE|PRIVATE_KEY|PASSWORD|TOKEN/i.test(name)||/^sb_secret_/i.test(value??""))throw Error("Private config in frontend");
  if(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value??"")){let claims;try{claims=JSON.parse(Buffer.from(value.split(".")[1],"base64url").toString("utf8"))}catch{}if(claims?.role==="service_role")throw Error("Service role forbidden")}
 }
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){validate(process.env);const r=spawnSync("npm",["run","build","--workspace","@famille/widemeet-web"],{stdio:"inherit",shell:false});if(r.error)throw r.error;process.exitCode=r.status??1}
