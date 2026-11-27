// Candidate scheduled function. No schedule/deployment is created by this source.
// Invoke with a dedicated server-side secret only; business data never returned.
Deno.serve(async req=>{
 const expected=Deno.env.get('GRILLAD_DAILY_SECRET')??'';
 if(req.method!=='POST'||expected.length<32||req.headers.get('x-grillad-job-secret')!==expected)return new Response(null,{status:403});
 const base=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!base||!key)return new Response(null,{status:503});
 try{const r=await fetch(base+'/rest/v1/rpc/grillad_daily_tick',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({p_limit:100}),redirect:'error',signal:AbortSignal.timeout(30000)});return new Response(r.ok?await r.text():null,{status:r.ok?200:503,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}})}catch{return new Response(null,{status:503})}
});
