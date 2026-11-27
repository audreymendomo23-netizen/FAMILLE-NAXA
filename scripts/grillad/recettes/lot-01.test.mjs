// 50 independent HTTP gateway contract tests; upstream simulated, never production.
import test from 'node:test';
import assert from 'node:assert/strict';
import {handle} from '../../../supabase/functions/grillad/handler.mjs';
const org='12345678-1234-1234-1234-123456789abc',site='12345678-1234-1234-1234-123456789abd',event='12345678-1234-1234-1234-123456789abe',item='12345678-1234-1234-1234-123456789abf';
const env={url:'https://fixture.supabase.co',key:'public-fixture',service:'server-only-fixture',origins:['https://grillad.test']};
const scope={p_org:org,p_site:site};
const mutations=[
 ['add_item',{name:'Poulet',family:'Poulet',price:1000,cost:500}],
 ['prepare',{item,qty:4}],['sell',{item,qty:1}],['sell_basket',{lines:[{item,qty:2,price:1000}]}],
 ['cancel_sale',{sale:item,reason:'Correction'}],['cancel_basket',{sale:item,reason:'Correction'}],
 ['open_cash',{opening:100}],['close_cash',{counted:100,reason:'Contrôle'}],['expense',{label:'Bois',value:200}],
 ['target',{day:'2026-11-27',amount:5000}],['change_price',{item,price:1200,reason:'Révision'}],
 ['change_cost',{item,cost:600,reason:'Révision'}],['set_item_active',{item,active:false,reason:'Archive'}]
];
const cases=mutations.map(([operation,payload])=>({name:operation,body:{action:'mutate',org,site,event,operation,payload},rpc:'grillad_action',params:{...scope,p_event:event,p_action:operation,p_payload:payload}}));
function add(action,body={},params={}){cases.push({name:action,body:{action,org,site,...body},rpc:'grillad_'+action,params:{...scope,...params}})}
add('snapshot',{from:'2026-11-01',to:'2026-11-27'},{p_from:'2026-11-01',p_to:'2026-11-27'});
add('receipt',{sale:item},{p_sale:item});
add('report',{from:'2026-11-01',to:'2026-11-27',network:false,family:'Poulet',actor:item,item},{p_from:'2026-11-01',p_to:'2026-11-27',p_network:false,p_family:'Poulet',p_actor:item,p_item:item});
add('attendance_status');
add('attendance_photo',{id:item},{p_id:item});
add('attendance_capture',{event,kind:'arrival',at:'2026-11-27T12:00:00Z',lat:0,lon:0,accuracy:10,photo:'fixture'},{p_event:event,p_kind:'arrival',p_at:'2026-11-27T12:00:00Z',p_lat:0,p_lon:0,p_accuracy:10,p_photo:'fixture'});
add('notice_feed');add('notice_ack',{id:'event:'+event},{p_id:'event:'+event});
add('notice_set',{category:'stock',enabled:false},{p_category:'stock',p_enabled:false});
add('prediction');add('security_list');
add('connect_transition',{order:item,event,next:'handed',received:2000},{p_order:item,p_event:event,p_next:'handed',p_received:2000,p_reason:null});
assert.equal(cases.length,25);
const request=(body,token)=>new Request('https://fixture.supabase.co/functions/v1/grillad',{method:'POST',headers:{Origin:'https://grillad.test',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body)});
for(const [i,c] of cases.entries()){
 test('GRC-'+String(i*2+1).padStart(3,'0')+' '+c.name+' scoped RPC with caller identity',async()=>{let calls=0;const result=await handle(request(c.body,'caller-fixture'),env,async(url,init)=>{calls++;assert.equal(url,env.url+'/rest/v1/rpc/'+c.rpc);assert.equal(init.headers.Authorization,'Bearer caller-fixture');assert.equal(init.headers.apikey,env.key);assert.deepEqual(JSON.parse(init.body),c.params);return Response.json({confirmed:true})});assert.equal(calls,1);assert.equal(result.status,200);assert.deepEqual(await result.json(),{result:{confirmed:true}});assert.equal(result.headers.get('cache-control'),'no-store')});
 test('GRC-'+String(i*2+2).padStart(3,'0')+' '+c.name+' refuses anonymous caller before RPC',async()=>{let calls=0;const result=await handle(request(c.body),env,async()=>{calls++;throw Error('no upstream allowed')});assert.equal(result.status,401);assert.equal(calls,0)});
}
