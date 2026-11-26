import{createServer}from'node:http';import pg from'pg';import{captureCredit,reconcilePending}from'./payment-worker.mjs';
if(!process.env.BOOTIK_PAYMENT_DATABASE_URL)throw Error('BOOTIK_PAYMENT_DATABASE_URL required');
const db=new pg.Pool({connectionString:process.env.BOOTIK_PAYMENT_DATABASE_URL,max:3});
let reconciling=false;
async function runReconciliation(){if(reconciling)return;reconciling=true;try{await reconcilePending(db)}catch{console.error('BOOTIK payment reconciliation requires inspection')}finally{reconciling=false}}
const timer=setInterval(runReconciliation,15000);timer.unref();
createServer(async(req,res)=>{
 const headers={'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
 if(req.method!=='POST'||req.url!=='/capture-credit'){res.writeHead(404,headers).end();return}
 try{let data='';for await(const c of req){data+=c;if(Buffer.byteLength(data)>16384){res.writeHead(413,headers).end();return}}
 const token=String(req.headers.authorization||'').replace(/^Bearer /,'');
 const id=await captureCredit(db,token,JSON.parse(data));await runReconciliation();
 res.writeHead(200,headers).end(JSON.stringify({app_id:'BOOTIK',state:'captured',capture_id:id}));
 }catch{res.writeHead(400,headers).end(JSON.stringify({error:'CAPTURE_REJECTED'}))}
}).listen(Number(process.env.BOOTIK_PAYMENT_PORT||8788),'127.0.0.1');
