import assert from "node:assert/strict";import {chromium} from "playwright";
const base="https://idupfjbkwjcavyisxteo.supabase.co",factor="10000000-0000-4000-8000-000000000001",challenge="10000000-0000-4000-8000-000000000002",id="20000000-0000-4000-8000-000000000001";
const browser=await chromium.launch();let calls=[],resolved=false,denied=false;
try{
 const ctx=await browser.newContext({viewport:{width:390,height:844}});const p=await ctx.newPage();
 await p.route(base+"/**",async route=>{
  const req=route.request(),path=new URL(req.url()).pathname,token=req.headers().authorization??"",body=req.postDataJSON()??{};
  const json=(status,data)=>route.fulfill({status,contentType:"application/json",headers:{"access-control-allow-origin":"*","access-control-allow-headers":"authorization,content-type,apikey","access-control-allow-methods":"GET,POST,OPTIONS"},body:JSON.stringify(data)});
  if(req.method()==="OPTIONS")return json(200,{});
  calls.push({path,token,body});
  if(path==="/auth/v1/token")return json(200,{access_token:"aal1-fixture"});
  if(path==="/auth/v1/user")return json(200,{factors:[{id:factor,factor_type:"totp",status:"verified",friendly_name:"CI TOTP"}]});
  if(path.endsWith("/challenge"))return json(200,{id:challenge});
  if(path.endsWith("/verify"))return json(200,{access_token:"aal2-fixture"});
  if(path.endsWith("/list"))return denied?json(403,{error:"DENIED"}):json(200,{requests:resolved?[]:[{id,login_id:"fixture",org_id:"org-qa",state:"pending",created_at:"2026-11-26T12:00:00Z"}]});
  if(path.endsWith("/complete")){assert.equal(token,"Bearer aal2-fixture");assert.equal(body.request_id,id);assert.equal(body.app_id,"ZIPPLE");resolved=true;return json(200,{resolved:true})}
  if(path.endsWith("/logout"))return route.fulfill({status:204,headers:{"access-control-allow-origin":"*"}});
  return json(404,{});
 });
 const enter=async()=>{await p.getByLabel("Adresse technique de l’opérateur").fill("operator@example.test");await p.getByLabel("Mot de passe opérateur").fill("fixture-only");await p.getByRole("button",{name:"Se connecter"}).click();await p.getByRole("heading",{name:"Authentification renforcée"}).waitFor();await p.getByLabel("Code de l’authentificateur").fill("123456");await p.getByRole("button",{name:"Vérifier"}).click()};
 await p.goto("http://127.0.0.1:4174/");await enter();await p.getByRole("heading",{name:"Demandes de récupération"}).waitFor();
 assert.ok(calls.filter(x=>x.path.includes("/admin/recovery/")).every(x=>x.token==="Bearer aal2-fixture"));
 await p.getByRole("button",{name:"Traiter",exact:true}).click();
 const complete=p.getByRole("button",{name:"Confirmer la récupération"});assert.equal(await complete.isDisabled(),true);
 await p.getByLabel("Motif vérifié").fill("Fixture identity verified");await p.getByLabel("Nouveau mot de passe temporaire").fill("Temporary-fixture-only");
 assert.equal(await complete.isDisabled(),true);await p.getByRole("checkbox").check();await complete.click();
 await p.getByText("Aucune demande ouverte.").waitFor();
 assert.equal(await p.evaluate(()=>localStorage.length+sessionStorage.length),0);
 await p.getByRole("button",{name:"Déconnexion"}).click();await p.getByRole("heading",{name:"Connexion opérateur"}).waitFor();
 denied=true;await enter();await p.getByText("Ce compte ne dispose pas des droits ZIPPLE requis.").waitFor();await p.getByRole("heading",{name:"Connexion opérateur"}).waitFor();
 console.log("ZIPPLE_ADMIN_CONSOLE_BROWSER_PASS");
}finally{await browser.close()}
