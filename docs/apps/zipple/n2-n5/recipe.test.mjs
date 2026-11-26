import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {randomUUID,createHash} from "node:crypto";
import {quote,referralWave} from "../contracts/zipple-policy.mjs";
import {packagePrice} from "../../../../packages/billing-core/src/index.js";
const db=new pg.Pool({connectionString:process.env.DATABASE_URL});
const uid=()=>randomUUID(),hash=()=>createHash("sha256").update(uid()).digest("hex");
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0]??{})[0];
async function tenant(name){
 const org=uid(),site=uid(),member=uid(),auth=uid(),access=hash();
 await db.query("insert into auth.users(id) values($1)",[auth]);
 await db.query("insert into zp_organizations values($1,$2,true)",[org,name]);
 await db.query("insert into zp_members(id,org_id,auth_user_id,login_id,auth_alias,role_code) values($1,$2,$3,$4,$5,'promoteur')",[member,org,auth,uid(),uid()+"@example.test"]);
 await db.query("insert into zp_sites values($1,$2,$3,true)",[site,org,name]);
 await db.query("insert into zp_site_scopes values($1,$2,$3)",[member,org,site]);
 await db.query("insert into zp_sessions(member_id,access_hash,access_until) values($1,$2,now()+interval '1 hour')",[member,access]);
 return {org,site,member,access};
}
const intent=(t,plan,cadence,key=uid())=>scalar("select zp_quote_intent($1,$2,$3,$4,'mtn_momo',$5)",[t.access,t.site,plan,cadence,key]);
const pay=(i,ref=uid(),amount=i.amount_xaf)=>scalar("select zp_confirm_subscription($1,'mtn_momo',$2,$3,'XAF')",[i.id,ref,amount]);
const order=(t,channel,lines,key=uid(),session=null,guest=null)=>scalar("select zp_create_order($1,$2,$3,$4,$5,$6,$7)",[guest?null:t.access,guest,t.site,channel,session,key,JSON.stringify(lines)]);
test("N2 through N4 real PostgreSQL: reuse commercial policy, isolation, stock and guest lifecycle",async()=>{
 try{
 const a=await tenant("Restaurant"),b=await tenant("Snack");
 for(const plan of ["ACCESS","PREMIUM"])for(const cadence of ["monthly","annual"]){const i=await intent(a,plan,cadence);assert.equal(i.amount_xaf,quote(plan,cadence).amount);if(cadence==="annual")assert.equal(i.amount_xaf,packagePrice(quote(plan,"monthly").amount,12))}
 await assert.rejects(intent(a,"ACCESS","quarterly"),/OFFER_DENIED/);
 await assert.rejects(scalar("select zp_quote_intent($1,$2,'ACCESS','monthly','mtn_momo',$3)",[a.access,b.site,uid()]),/DENIED/);
 const k=uid(),i=await intent(a,"PREMIUM","monthly",k);assert.equal((await intent(a,"PREMIUM","monthly",k)).id,i.id);
 await assert.rejects(intent(a,"ACCESS","monthly",k),/IDEMPOTENCY_CONFLICT/);
 await assert.rejects(pay(i,uid(),1),/PAYMENT_MISMATCH/);
 assert.equal(await scalar("select zp_paid_plan($1)",[a.org]),null);
 const ref=uid(),pid=await pay(i,ref);assert.equal(await pay(i,ref),pid);assert.equal(await scalar("select zp_paid_plan($1)",[a.org]),"PREMIUM");
 await pay(await intent(b,"ACCESS","annual"));
 await scalar("select zp_site_mode($1,$2,'restaurant',true,true)",[a.access,a.site]);
 await assert.rejects(scalar("select zp_site_mode($1,$2,'snack_bar',false,true)",[b.access,b.site]),/check constraint/);
 await scalar("select zp_site_mode($1,$2,'snack_bar',false,false)",[b.access,b.site]);
 const add=(t,name,post,price,qty)=>scalar("select zp_add_menu_item($1,$2,$3,$4,$5,$6)",[t.access,t.site,name,post,price,qty]);
 const food=await add(a,"Plat","kitchen",2500,2),drink=await add(a,"Boisson","bar",1000,4),snack=await add(b,"Menu","snack",1800,2);
 await assert.rejects(add(b,"Cocktail","bar",1000,2),/POST_DENIED/);
 await assert.rejects(order(b,"delivery",[{item_id:snack,qty:1}]),/CHANNEL_DENIED/);
 await assert.rejects(order(b,"counter",[{item_id:food,qty:1}]),/ITEM_UNAVAILABLE/);
 await assert.rejects(order(a,"takeaway",[{item_id:food,qty:2},{item_id:food,qty:-1}]),/INVALID_QUANTITY/);
 const key=uid(),lines=[{item_id:food,qty:1},{item_id:drink,qty:2}];
 const sale=await order(a,"takeaway",lines,key);assert.equal(Number(sale.total_xaf),4500);assert.equal((await order(a,"takeaway",lines,key)).id,sale.id);
 await assert.rejects(order(a,"takeaway",[{item_id:food,qty:2}],key),/IDEMPOTENCY_CONFLICT/);
 const last=await Promise.allSettled([order(a,"takeaway",[{item_id:food,qty:1}]),order(a,"takeaway",[{item_id:food,qty:1}])]);assert.equal(last.filter(x=>x.status==="fulfilled").length,1);assert.equal(last.filter(x=>x.status==="rejected").length,1);
 const table=uid(),ts=uid(),qr=hash(),g1=hash(),g2=hash();await db.query("insert into zp_tables(id,org_id,site_id,label,qr_hash) values($1,$2,$3,'T1',$4)",[table,a.org,a.site,qr]);
 await assert.rejects(scalar("select zp_open_guest($1,$2)",[qr,g1]),/DENIED/);
 await db.query("insert into zp_table_sessions(id,table_id,org_id,site_id) values($1,$2,$3,$4)",[ts,table,a.org,a.site]);
 await scalar("select zp_open_guest($1,$2)",[qr,g1]);await scalar("select zp_open_guest($1,$2)",[qr,g2]);
 const anonymous=await order(a,"table",[{item_id:drink,qty:1}],uid(),ts,g1);assert.equal((await scalar("select zp_guest_order($1,$2)",[g1,anonymous.id])).id,anonymous.id);assert.equal(await scalar("select zp_guest_order($1,$2)",[g2,anonymous.id]),null);
 await db.query("update zp_table_sessions set closed_at=now() where id=$1",[ts]);assert.equal(await scalar("select zp_guest_order($1,$2)",[g1,anonymous.id]),null);await assert.rejects(order(a,"table",[{item_id:drink,qty:1}],uid(),ts,g1),/DENIED/);
 for(let n=0;n<5;n++){const t=await tenant("Referral "+n);await db.query("insert into zp_referral_links(referred_org,referrer_org) values($1,$2)",[t.org,a.org]);await pay(await intent(t,"ACCESS","monthly"));}
 assert.equal(await scalar("select zp_claim_referral($1,$2)",[a.access,a.site]),referralWave(5,"monthly").completedWaves);assert.equal(await scalar("select zp_claim_referral($1,$2)",[a.access,a.site]),0);
 assert.equal(await scalar("select count(*)::int from pg_tables where schemaname='public' and tablename like 'zp_%' and not rowsecurity"),0);
 assert.equal(await scalar("select has_function_privilege('authenticated','public.zp_confirm_subscription(uuid,text,text,integer,text)','execute')"),false);
 assert.equal(await scalar("select has_table_privilege('anon','public.zp_orders','select')"),false);
 console.log("ZIPPLE_N2_N4_REAL_POSTGRES_PASS");
 }finally{await db.end()}
});
