import {createServer} from 'node:http';
import pg from 'pg';
import {createBootikService} from './service.mjs';
if(!process.env.BOOTIK_DATABASE_URL)throw Error('BOOTIK_DATABASE_URL required');
const db=new pg.Pool({connectionString:process.env.BOOTIK_DATABASE_URL,max:8});
const handle=createBootikService(db);
const origin=process.env.BOOTIK_WEB_ORIGIN||'';
createServer(async(req,res)=>{
 const headers={'Cache-Control':'no-store','Content-Type':'application/json','X-Content-Type-Options':'nosniff'};
 if(origin&&req.headers.origin===origin){headers['Access-Control-Allow-Origin']=origin;headers['Vary']='Origin';headers['Access-Control-Allow-Headers']='Authorization, Content-Type';headers['Access-Control-Allow-Methods']='POST, OPTIONS'}
 if(req.method==='OPTIONS'){res.writeHead(204,headers).end();return}
 if(req.method!=='POST'||!['/login','/logout','/recovery','/operation'].includes(req.url)){res.writeHead(404,headers).end();return}
 try{let data='';for await(const chunk of req){data+=chunk;if(Buffer.byteLength(data)>16384){res.writeHead(413,headers).end();return}}
 const result=await handle(req.url.slice(1),JSON.parse(data),String(req.headers.authorization||'').replace(/^Bearer /,''),req.socket.remoteAddress||'local');
 res.writeHead(result.status,headers).end(result.status===204?'':JSON.stringify(result.body));
 }catch{res.writeHead(400,headers).end(JSON.stringify({error:'REQUEST_REJECTED'}))}
}).listen(Number(process.env.PORT||8787),'127.0.0.1');
