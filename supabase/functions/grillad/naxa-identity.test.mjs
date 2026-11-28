import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyNaxaIdentity} from './naxa-identity.mjs';
const token='header.payload.signature',config={publishableKey:'fixture'},id='10000000-0000-4000-8000-000000000001';
const good={id,role:'authenticated',is_anonymous:false,email:'private@example.invalid',user_metadata:{role:'admin'}};
test('identity comes only from pinned NAXA server, not client claims',async()=>{
 const result=await verifyNaxaIdentity(token,config,async(url,init)=>{
 assert.equal(url,'https://ykgjfindlgseegmznaog.supabase.co/auth/v1/user');assert.equal(init.headers.Authorization,'Bearer '+token);assert.equal(init.redirect,'error');return Response.json(good)});
 assert.deepEqual(result,{issuer:'https://ykgjfindlgseegmznaog.supabase.co/auth/v1',subject:id});
});
test('rejects missing config or malformed credential without network',async()=>{
 const fail=()=>assert.fail('network forbidden');assert.equal(await verifyNaxaIdentity(token,{},fail),null);assert.equal(await verifyNaxaIdentity('bad',config,fail),null);
});
test('rejects anonymous, invalid role, invalid subject, absent anonymous flag',async()=>{
 for(const user of [{...good,is_anonymous:true},{...good,role:'anon'},{...good,id:'bad'},{...good,is_anonymous:undefined}])assert.equal(await verifyNaxaIdentity(token,config,async()=>Response.json(user)),null);
});
test('fails closed on rejected or unavailable upstream',async()=>{
 for(const status of [401,403,429,500])assert.equal(await verifyNaxaIdentity(token,config,async()=>new Response(null,{status})),null);
 assert.equal(await verifyNaxaIdentity(token,config,async()=>{throw Error('offline')}),null);
});
