import test from "node:test";import assert from "node:assert/strict";import {parseSession,permitsSite,login} from "../../../../apps/web/zipple/src/session.mjs";
const now=Date.now(),s={app_id:"ZIPPLE",access_token:"x".repeat(30),member_id:"m",organization_id:"o",organization_name:"test",role:"promoteur",sites:[{id:"s",name:"Site"}],expires_at:now+60000};
test("scope and site",()=>{let x=parseSession(s,now);assert.equal(permitsSite(x,"s",now),true);assert.equal(permitsSite(x,"other",now),false);assert.equal(permitsSite(x,"s",now+60001),false)});
for(const patch of [{app_id:"NAXA_SERVICES"},{role:"admin"},{sites:[]},{sites:[{id:"s",name:"S"},{id:"s",name:"S"}]},{expires_at:now-1},{member_id:""},{organization_id:""},{access_token:"bad"}])test("invalid "+JSON.stringify(patch),()=>assert.throws(()=>parseSession({...s,...patch},now)));
test("no endpoint fails closed",async()=>assert.rejects(login("","a","b"),/NOT_CONFIGURED/));
test("no insecure endpoint",async()=>assert.rejects(login("http://example.com","a","b"),/NOT_CONFIGURED/));
test("server contract",async()=>{let x=await login("https://example.test","demo","secret",async(url,opt)=>{assert.equal(url.href,"https://example.test/login");assert.equal(opt.redirect,"error");assert.equal(JSON.parse(opt.body).app_id,"ZIPPLE");return {ok:true,json:async()=>s}});assert.equal(x.organization_id,"o")});
test("reject server failure",async()=>assert.rejects(login("https://example.test","demo","secret",async()=>({ok:false})),/LOGIN_REJECTED/));
