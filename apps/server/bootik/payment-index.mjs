import{createServer}from'node:http';import{createHash,timingSafeEqual}from'node:crypto';import pg from'pg';import{captureCredit,reconcilePending,confirmRefund}from'./payment-worker.mjs';
if(!process.env.BOOTIK_PAYMENT_DATABASE_URL)throw Error('BOOTIK_PAYMENT_DATABASE_URL required');
const db=new pg.Pool({connectionString:process.env.BOOTIK_PAYMENT_DATABASE_URL,max:3});
const refundDb=process.env.BOOTIK_REFUND_DATABASE_URL?new pg.Pool({connectionString:process.env.BOOTIK_REFUND_DATABASE_URL,max:2}):null;
const refundToken=process.env.BOOTIK_BILLING_EVENT_TOKEN||'';
const digest=v=>createHash('sha256').update(v).digest();
let reconciling=false;
async function runReconciliation(){if(reconciling)return;reconciling=true;try{await reconcilePending(db)}catch{console.error('BOOTIK payment reconciliation requires inspection')}finally{reconciling=false}}
const timer=setInterval(runReconciliation,15000);timer.unref();
createServer(async(req,res)=>{
 const headers={'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
 if(req.method!=='POST'||!['/capture-credit','/confirm-refund'].includes(req.url)){res.writeHead(404,headers).end();return}
 try{let data='';for await(const c of req){data+=c;if(Buffer.byteLength(data)>16384){res.writeHead(413,headers).end();return}}
 const token=String(req.headers.authorization||'').replace(/^Bearer /,'');
 if(req.url==='/confirm-refund'){
 if(!refundDb||refundToken.length<32){res.writeHead(503,headers).end();return}
 if(!timingSafeEqual(digest(token),digest(refundToken))){res.writeHead(403,headers).end();return}
 const id=await confirmRefund(refundDb,JSON.parse(data));res.writeHead(200,headers).end(JSON.stringify({app_id:'BOOTIK',state:'refunded',paid_period_id:id}));return;
 }
 const id=await captureCredit(db,token,JSON.parse(data));await runReconciliation();
 res.writeHead(200,headers).end(JSON.stringify({app_id:'BOOTIK',state:'captured',capture_id:id}));
 }catch{res.writeHead(400,headers).end(JSON.stringify({error:'CAPTURE_REJECTED'}))}
}).listen(Number(process.env.BOOTIK_PAYMENT_PORT||8788),'127.0.0.1');
