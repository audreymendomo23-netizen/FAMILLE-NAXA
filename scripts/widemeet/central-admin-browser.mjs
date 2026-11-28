import assert from "node:assert/strict";
import {spawn} from "node:child_process";
import {chromium} from "@playwright/test";
const port=4387,local="http://127.0.0.1:"+port,project="https://idupfjbkwjcavyisxteo.supabase.co";
const server=spawn("npx",["vite","preview","--host","127.0.0.1","--port",String(port),"--strictPort"],{cwd:new URL("../../apps/web/admin-console/",import.meta.url).pathname,stdio:"inherit"});
let browser;
try{
 for(let i=0;i<80;i++){try{if((await fetch(local)).ok)break}catch{}if(i===79)throw Error("preview unavailable");await new Promise(r=>setTimeout(r,250))}
 browser=await chromium.launch();
 for(const role of ["admin","agent","denied"]){
  const page=await browser.newPage();let claimed=false,replied=false,routeCalls=[];
  const factor="10000000-0000-4000-8000-000000000001",ticket="20000000-0000-4000-8000-000000000001";
  await page.route(project+"/**",async route=>{
   const request=route.request(),u=new URL(request.url()),path=u.pathname;
   const out=(status,value)=>route.fulfill({status,contentType:"application/json",headers:{"access-control-allow-origin":local,"access-control-allow-headers":"authorization,apikey,content-type","access-control-allow-methods":"GET,POST,OPTIONS"},body:JSON.stringify(value)});
   if(request.method()==="OPTIONS")return out(200,{});
   if(path==="/auth/v1/token")return out(200,{access_token:"fixture-aal1"});
   if(path==="/auth/v1/user")return out(200,{factors:[{id:factor,factor_type:"totp",status:"verified"}]});
   if(path.endsWith("/challenge"))return out(200,{id:factor});
   if(path.endsWith("/verify"))return out(200,{access_token:"fixture-aal2"});
   if(path.endsWith("/logout"))return out(200,{});
   if(path.includes("/zipple-n1/"))return out(403,{});
   if(path.endsWith("/widemeet-auth/central")){
    assert.equal(request.headers().authorization,"Bearer fixture-aal2");
    const b=request.postDataJSON();assert.equal(b.app_id,"WIDEMEET");routeCalls.push(b.action);
    if(role==="denied")return out(403,{});
    if(b.action==="capabilities")return out(200,{admin:role==="admin",agent:role==="agent"});
    if(role==="admin"&&b.action==="overview")return out(200,{individuals:7,companies:2,confirmed_xaf:12345});
    if(role==="admin"&&b.action==="agent-list")return out(200,{items:[]});
    if(role==="agent"&&b.action==="support-queue")return out(200,{items:[{id:ticket,category:"account",status:claimed?"assigned":"open",subject:claimed?"Sujet client":null,assigned:claimed}],transport_ready:false});
    if(role==="agent"&&b.action==="support-claim"){claimed=true;return out(200,{claimed:true})}
    if(role==="agent"&&b.action==="support-read"&&claimed)return out(200,{id:ticket,viewer:"agent",subject:"Sujet client",status:replied?"waiting":"assigned",assignment_version:"1",messages:[{id:"1",body:"Demande client",author_kind:"requester",created_at:"2026-11-28T00:00:00Z"},...(replied?[{id:"2",body:"Réponse agent",author_kind:"agent",created_at:"2026-11-28T00:00:01Z"}]:[])],transport_ready:false});
    if(role==="agent"&&b.action==="support-reply"&&claimed){assert.equal(b.data.body,"Réponse agent");assert.match(b.data.message_id,/^[0-9a-f-]{36}$/);replied=true;return out(200,{sent:true})}
    return out(403,{});
   }
   return out(404,{});
  });
  await page.goto(local);
  await page.getByLabel("Adresse technique de l’opérateur").fill("fixture@example.test");
  await page.getByLabel("Mot de passe opérateur").fill("fixture-password");
  await page.getByRole("button",{name:"Se connecter",exact:true}).click();
  await page.getByLabel("Code de l’authentificateur").fill("123456");
  await page.getByRole("button",{name:"Vérifier",exact:true}).click();
  if(role==="admin"){
   await page.getByText("Particuliers",{exact:false}).first().waitFor();assert.equal(await page.getByRole("button",{name:"Service client",exact:true}).count(),0);
   await page.getByRole("button",{name:"Agents support",exact:true}).click();await page.getByText("Habilitations WideMeet").waitFor();
  }else if(role==="agent"){
   await page.getByText("Masqué avant attribution").waitFor();assert.equal(await page.getByRole("button",{name:"Pilotage",exact:true}).count(),0);
   await page.getByRole("button",{name:"Prendre en charge",exact:true}).click();await page.getByText("Demande client",{exact:true}).waitFor();
   await page.getByLabel("Réponse").fill("Réponse agent");await page.getByRole("button",{name:"Envoyer",exact:true}).click();await page.getByText("Réponse agent",{exact:true}).waitFor();assert.ok(replied);
  }else{
   await page.getByText("Ce compte ne dispose pas des droits administratifs ou support requis.").waitFor();assert.equal(await page.getByRole("button",{name:"WideMeet",exact:true}).count(),0);
  }
  assert.ok(routeCalls.includes("capabilities"));await page.close();
 }
 console.log("WIDEMEET_CENTRAL_BROWSER_PASS");
}finally{if(browser)await browser.close();server.kill();}
