import test from "node:test";
import assert from "node:assert/strict";
import {chromium} from "playwright";
const origin="https://naxa-zipple.pages.dev";
const edge="https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/zipple-n1";
test("public Pages UI and exact-origin CORS",async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  const page=await browser.newPage();
  // Pages may be building at the same time as GitHub Actions; only qualify the new version.
  let published=false;for(let i=0;i<18;i++){const res=await fetch(origin+"/zipple-restaurant-bar.webp",{cache:"no-store"});if(res.ok&&res.headers.get("content-type")?.includes("image/webp")){published=true;break}await new Promise(r=>setTimeout(r,5000))}assert.equal(published,true,"new photo build not deployed");
  await page.goto(origin,{waitUntil:"networkidle"});
  await page.getByRole("heading",{name:/Servez mieux, gérez en toute sécurité\.|Votre restaurant, bien piloté/}).waitFor();
  const submit=page.getByRole("button",{name:"Se connecter",exact:true});
  assert.equal(await submit.isDisabled(),true,"empty submit must be disabled");
  await page.getByRole("button",{name:"EN",exact:true}).click();
  await page.getByRole("heading",{name:/Serve better, manage securely\.|Manage your restaurant/}).waitFor();
  await page.getByRole("button",{name:"FR",exact:true}).click();
  await page.getByRole("button",{name:"Thème",exact:true}).click();
  assert.equal(await page.locator("main").getAttribute("data-theme"),"dark");
  assert.ok((await page.locator("main").evaluate(e=>getComputedStyle(e).backgroundImage)).includes("zipple-restaurant-bar.webp"));
  assert.equal(await page.getByRole("checkbox",{name:"Rester connecté"}).isChecked(),false);
  const noCookie=await fetch(origin+"/session/refresh",{method:"POST",headers:{origin,"Content-Type":"application/json"},body:"{}",redirect:"error"});assert.equal(noCookie.status,401,"Pages session worker must fail closed without cookie");assert.match(noCookie.headers.get("set-cookie")??"",/HttpOnly; SameSite=Strict; Max-Age=0/);
  console.log("ZIPPLE_PAGES_PHOTO_AND_COOKIE_BOUNDARY_PASS");
  console.log("ZIPPLE_PAGES_UI_PASS");
  const preflight=await fetch(edge+"/login",{method:"OPTIONS",headers:{origin,"access-control-request-method":"POST","access-control-request-headers":"content-type"},redirect:"error"});
  console.log("ZIPPLE_PAGES_PREFLIGHT_STATUS",preflight.status,"ORIGIN",preflight.headers.get("access-control-allow-origin"));
  assert.ok([200,204].includes(preflight.status),"preflight denied");
  assert.equal(preflight.headers.get("access-control-allow-origin"),origin,"exact Pages origin required");
  await page.getByLabel("Identifiant").fill("zipple-pages-ci-negative-"+Date.now());
  await page.getByLabel("Mot de passe",{exact:true}).fill("synthetic-test-only");
  assert.equal(await submit.isEnabled(),true);
  const responsePromise=page.waitForResponse(r=>r.url()===edge+"/login"&&r.request().method()==="POST",{timeout:20000});
  await submit.click();
  const response=await responsePromise;
  assert.ok([401,403].includes(response.status()),"invalid credentials must be refused");
  assert.equal((await response.allHeaders())["access-control-allow-origin"],origin);
  await page.getByRole("alert").waitFor();
  assert.equal(await page.getByLabel("Mot de passe",{exact:true}).inputValue(),"");
  console.log("ZIPPLE_PAGES_CORS_NEGATIVE_LOGIN_PASS");
 }finally{await browser.close()}
});
