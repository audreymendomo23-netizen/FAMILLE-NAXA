// Candidate scheduled job: no schedule or deployment is created by this source.
Deno.serve(async req=>{
 const expected=Deno.env.get('GRILLAD_DAILY_SECRET')??'';
 if(req.method!=='POST'||expected.length<32||req.headers.get('x-grillad-job-secret')!==expected)return new Response(null,{status:403});
 const base=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!base||!key)return new Response(null,{status:503});
 const rpc=async(name:string,params:Record<string,unknown>)=>{
  const r=await fetch(base+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(params),redirect:'error',signal:AbortSignal.timeout(30000)});
  if(!r.ok)throw Error('JOB_REFUSED');return await r.json();
 };
 const results=await Promise.allSettled([rpc('grillad_daily_tick',{p_limit:100}),rpc('grillad_purge_attendance_photos',{}),rpc('grillad_central_reconcile',{p_limit:100})]);
 const status=results.every(x=>x.status==='fulfilled')?200:503;
 return new Response(JSON.stringify({daily:results[0].status==='fulfilled',purge:results[1].status==='fulfilled',central:results[2].status==='fulfilled'}),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
});
