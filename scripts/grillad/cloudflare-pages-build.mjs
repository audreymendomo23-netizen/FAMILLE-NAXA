// GRILLAD only: static candidate, no deployment or provider credentials.
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
export function validate(env){
 for(const [k,v] of Object.entries(env)){
  if(!k.startsWith('VITE_'))continue;
  if(/SECRET|SERVICE_ROLE|PRIVATE_KEY|PASSWORD|TOKEN/i.test(k)||/^sb_secret_/i.test(v??''))throw Error('PRIVATE_WEB_CONFIG');
  if(/^[\w-]+\.[\w-]+\.[\w-]+$/.test(v??'')){
   let claims;try{claims=JSON.parse(Buffer.from(v.split('.')[1],'base64url').toString())}catch{}
   if(claims?.role==='service_role')throw Error('PRIVATE_WEB_CONFIG');
  }
 }
 if(env.VITE_GRILLAD_API_URL){
  const u=new URL(env.VITE_GRILLAD_API_URL);
  if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash||u.port||!u.hostname.endsWith('.supabase.co')||u.pathname!=='/functions/v1/grillad')throw Error('GRILLAD_API_SCOPE');
 }
 if(env.GRILLAD_RELEASE==='1'&&!env.VITE_GRILLAD_API_URL)throw Error('GRILLAD_API_REQUIRED');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 validate(process.env);
 const r=spawnSync('npm',['run','build','--workspace','@famille/grillad-web'],{stdio:'inherit',shell:false});
 if(r.error)throw r.error;process.exitCode=r.status??1;
}
