import {defineConfig} from "vite";
import react from "@vitejs/plugin-react";
import {readFileSync,writeFileSync,readdirSync} from "node:fs";
import {resolve} from "node:path";
import {createHash} from "node:crypto";
// Conservative commercial candidate; default/test modes retain existing qualification coverage.
export default defineConfig(({mode})=>{
 if(mode==="commercial"){
  for(const feature of ["BRIEFING_ARCHIVE","TRANSVERSE_OPERATIONS","COMMISSION_CONFIG","COMMISSION_SETTLEMENT","BILLING_V23","ATTENDANCE","MEETINGS","BRIEFING"]){
   process.env["VITE_NAXA_SERVICES_"+feature+"_ENABLED"]="false";
  }
 }
 return {plugins:[react(),{
 name:"naxa-offline-shell-manifest",apply:"build",
 closeBundle(){
  const dist=resolve(process.cwd(),"dist");
  const walk=(dir:string):string[]=>readdirSync(resolve(dist,dir),{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(dir+e.name+"/"):[dir+e.name]);
  const assets=walk("assets/").sort().map(s=>"/"+s);
  if(!assets.some(s=>s.endsWith(".js"))||!assets.some(s=>s.endsWith(".css")))throw Error("INCOMPLETE_OFFLINE_SHELL");
  const html=readFileSync(resolve(dist,"index.html"));
  const path=resolve(dist,"sw.js");const sw=readFileSync(path,"utf8");
  const version=createHash("sha256").update(html).update(assets.join("\n")).update(sw).digest("hex").slice(0,20);
  writeFileSync(path,sw.replace('"__NAXA_SHELL_VERSION__"',JSON.stringify(version)).replace('["__NAXA_BUILD_ASSETS__"]',JSON.stringify(assets)));
 }
}]};
});
