import test from "node:test";import assert from "node:assert/strict";import pg from "pg";import {createFixture,passwordHash} from "./postgres-fixture.mjs";import {login,authorizedRequest} from "../../../../apps/web/zipple/src/session.mjs";
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL});
test("N1 actual SQL-backed auth and replay isolation",async()=>{
try{
 await pool.query("insert into zipple_n1.members values ('m','ZIPPLE','a','fixture',$1,'promoteur',true),('other','NAXA_SERVICES','b','other',$1,'promoteur',true)",[passwordHash("test-only")]);
 await pool.query("insert into zipple_n1.sites values ('s','ZIPPLE','a','Site',true),('x','ZIPPLE','b','Other',true),('ns','NAXA_SERVICES','b','NS',true)");
 await pool.query("insert into zipple_n1.scopes values ('m','s'),('m','x'),('other','ns')");
 const handler=await createFixture(pool);
 const fetcher=(u,opt)=>handler(new Request(u,opt));
 const base="https://zipple.test";
 await assert.rejects(login(base,"fixture","wrong",fetcher));
 await assert.rejects(login(base,"other","test-only",fetcher));
 const s=await login(base,"fixture","test-only",fetcher);
 assert.deepEqual(s.sites.map(x=>x.id),["s"]);
 const body={event_id:"event",organization_id:"a",member_id:"m",site_id:"s",sequence:1,payload:{test:true}};
 const send=b=>authorizedRequest(base,"sync",b,s.access_token,fetcher);
 assert.equal((await send(body)).state,"acknowledged");
 assert.equal((await send(body)).state,"acknowledged");
 assert.equal((await send({...body,payload:{test:false}})).state,"conflict");
 await assert.rejects(send({...body,site_id:"x"}));await assert.rejects(send({...body,organization_id:"b"}));await assert.rejects(send({...body,member_id:"other"}));
 assert.equal(Number((await pool.query("select count(*) from zipple_n1.receipts")).rows[0].count),1);
 await authorizedRequest(base,"logout",{},s.access_token,fetcher);await assert.rejects(send(body));
 console.log("ZIPPLE_N1_SQL_INTEGRATION_PASS");
}finally{await pool.end()}
});
