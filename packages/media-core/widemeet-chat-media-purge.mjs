// Adapted from the B6 verified absence contract; separate conversation bucket.
// Logical revoke precedes physical removal. No public endpoint and no production scheduling.
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
export async function purgeRevokedChatMedia({base,serviceKey,fetcher=fetch,limit=50}){
 const u=new URL(base);if(u.origin!=="http://127.0.0.1:54321"||u.pathname!=="/"||u.username||u.password||u.hash||u.search||!serviceKey||!Number.isInteger(limit)||limit<1||limit>100)throw Error("isolated storage only");
 const bucket="wm-chat-media",headers={apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"};
 async function call(path,body,method="POST"){const r=await fetcher(new URL(path,u),{method,headers,...(body===undefined?{}:{body:JSON.stringify(body)}),redirect:"error",cache:"no-store",signal:AbortSignal.timeout(15000)});if(!r.ok)throw Error("private cleanup unconfirmed");return r.json()}
 if((await call("/storage/v1/bucket/"+bucket,undefined,"GET")).public!==false)throw Error("bucket must be private");
 const candidates=await call("/rest/v1/rpc/wm_chat_media_purge_candidates",{p_limit:limit});
 if(!Array.isArray(candidates?.items)||candidates.items.length>limit)throw Error("invalid ledger");
 let removed=0;
 for(const x of candidates.items){
  const parts=typeof x.key==="string"?x.key.split("/"):[];
  if(parts.length!==2||!parts.every(v=>uuid.test(v))||parts[1]!==x.id)throw Error("invalid ledger key");
  await call("/storage/v1/object/"+bucket,{prefixes:[x.key]},"DELETE");
  const items=await call("/storage/v1/object/list/"+bucket,{prefix:parts[0],search:parts[1],limit:100,offset:0});
  if(!Array.isArray(items)||items.length>=100||items.some(v=>!v||typeof v.name!=="string"||v.name===parts[1]))throw Error("absence not confirmed");
  if(await call("/rest/v1/rpc/wm_chat_media_purge_ack",{p_id:x.id})!==true)throw Error("ack not confirmed");
  removed++;
 }
 return {removed};
}
