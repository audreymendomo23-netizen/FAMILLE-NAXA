import {createServer} from 'node:http';
import {randomBytes} from 'node:crypto';
import {writeFileSync,readFileSync} from 'node:fs';
import {handle} from '../../supabase/functions/grillad/handler.mjs';
const {GRILLAD_CI_LOCAL,GRILLAD_LOCAL_API:url,GRILLAD_LOCAL_ANON:key,GRILLAD_LOCAL_SERVICE:service,RUNNER_TEMP}=process.env;
if(GRILLAD_CI_LOCAL!=='1'||!['http://127.0.0.1:54321','http://localhost:54321'].includes(url)||!key||!service||!RUNNER_TEMP)throw Error('LOCAL_ONLY');
const file=RUNNER_TEMP+'/grillad-real-accounts.json';
async function provision(){
 const accounts={};for(const [role,phone] of [['owner','+237600000001'],['seller','+237600000002'],['manager','+237600000003']]){
  const password=randomBytes(24).toString('base64url')+'Aa9!';
  const r=await fetch(url+'/auth/v1/admin/users',{method:'POST',headers:{apikey:service,Authorization:'Bearer '+service,'Content-Type':'application/json'},body:JSON.stringify({phone,password,phone_confirm:true}),redirect:'error'});
  if(!r.ok)throw Error('Local Auth provisioning '+role+' HTTP '+r.status);const u=await r.json();
  if(!u.id||!u.phone_confirmed_at)throw Error('Local Auth user not confirmed');
  accounts[role]={phone,password,id:u.id};
  // Verify actual password grant before browser setup; never print credentials or JWTs.
  const login=await fetch(url+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({phone,password}),redirect:'error'});
  if(!login.ok){const e=await login.json().catch(()=>({}));throw Error('Local phone password grant '+role+' HTTP '+login.status+' code='+String(e.error_code??e.code??'unknown').replace(/[^a-zA-Z0-9_-]/g,''));}
  const session=await login.json();if(session.user?.id!==u.id||!session.access_token)throw Error('Local Auth identity mismatch');
  const logout=await fetch(url+'/auth/v1/logout?scope=local',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+session.access_token},redirect:'error'});
  if(!logout.ok)throw Error('Local Auth preflight logout failed');
  console.log('PASS: actual local phone password grant '+role);
 }
 writeFileSync(file,JSON.stringify(accounts),{mode:0o600,flag:'wx'});
 console.log('PASS: three distinct local Auth users provisioned (no SMS)');
}
function serve(){
 const env={url,key,service,firebaseProject:'grillad',origins:['http://127.0.0.1:4181']};
 createServer(async(req,res)=>{try{
  if(req.url!=='/functions/v1/grillad'){res.writeHead(404);res.end();return}
  const chunks=[];for await(const c of req)chunks.push(c);
  const body=Buffer.concat(chunks);const hdr=new Headers();for(const [k,v] of Object.entries(req.headers))if(typeof v==='string')hdr.set(k,v);
  const request=new Request('http://127.0.0.1:4182'+req.url,{method:req.method,headers:hdr,...(req.method==='POST'?{body}: {})});
  const out=await handle(request,env);res.writeHead(out.status,Object.fromEntries(out.headers));res.end(Buffer.from(await out.arrayBuffer()));
 }catch{res.writeHead(500);res.end('local gateway error')}}).listen(4182,'127.0.0.1',()=>console.log('Local GRILLAD handler ready'));
}
if(process.argv[2]==='provision')await provision();else if(process.argv[2]==='serve')serve();else throw Error('command');
