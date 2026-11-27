import test from 'node:test';import assert from 'node:assert/strict';import {handle} from '../../../supabase/functions/grillad/handler.mjs';
const org='12345678-1234-1234-1234-123456789abc',site='12345678-1234-1234-1234-123456789abd',event='12345678-1234-1234-1234-123456789abe',item='12345678-1234-1234-1234-123456789abf';
const env={url:'https://fixture.supabase.co',key:'public-fixture',service:'server-only-fixture',firebaseProject:'grillad-fixture',origins:['https://grillad.test']};
const scope={p_org:org,p_site:site};const cases=[];
function mutate(operation,payload){cases.push({name:operation,body:{action:'mutate',org,site,event,operation,payload},rpc:'grillad_action',params:{...scope,p_event:event,p_action:operation,p_payload:payload}})}
function add(action,body={},params=scope){cases.push({name:action,body:{action,org,site,...body},rpc:'grillad_'+action,params})}
const req=(body,token)=>new Request(env.url+'/functions/v1/grillad',{method:'POST',headers:{Origin:'https://grillad.test',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body)});
function route(c){return async()=>{let calls=0;const r=await handle(req(c.body,'caller-fixture'),env,async(url,init)=>{calls++;assert.equal(url,env.url+'/rest/v1/rpc/'+c.rpc);assert.equal(init.headers.Authorization,'Bearer caller-fixture');assert.deepEqual(JSON.parse(init.body),c.params);return Response.json({confirmed:true})});assert.equal(calls,1);assert.equal(r.status,200);assert.deepEqual(await r.json(),{result:{confirmed:true}})}}
function anonymous(c){return async()=>{let calls=0;const r=await handle(req(c.body),env,async()=>{calls++;throw Error()});assert.equal(r.status,401);assert.equal(calls,0)}}

mutate('cash_recount_request',{cash:item,counted:1850,reason:'Recomptage'});mutate('cash_recount_decide',{request:item,decision:'approved',reason:'Vérifié'});
mutate('record_purchase',{supplier:'Marché test',input_name:'Poulet',unit:'kg',quantity:2.5,amount:5000});mutate('cancel_purchase',{purchase:item,reason:'Erreur'});
mutate('missing_arrival_request',{departure:item,seconds:30,reason:'Oubli'});mutate('missing_arrival_decide',{request:item,decision:'approved',reason:'Vérifié'});
for(const [i,c] of cases.entries()){test('GRC-'+String(94+i*2).padStart(3,'0')+' '+c.name+' caller',route(c));test('GRC-'+String(95+i*2).padStart(3,'0')+' '+c.name+' anonymous denied',anonymous(c))}
