import {chromium,firefox,webkit} from "playwright";
import assert from "node:assert/strict";
const origin="http://127.0.0.1:4173";
const expected="Servez mieux, gérez en toute sécurité.";
for(const [name,engine] of [["chromium",chromium],["firefox",firefox],["webkit",webkit]]){
 const browser=await engine.launch({headless:true});
 try{
  const ctx=await browser.newContext({viewport:{width:390,height:844},reducedMotion:"reduce"});
  const page=await ctx.newPage();await page.goto(origin);
  await page.getByRole("heading",{name:expected}).waitFor();
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.equal(await page.getByRole("checkbox",{name:"Rester connecté"}).isChecked(),false);
  const manifest=await (await page.request.get(origin+"/manifest.webmanifest")).json();
  assert.equal(manifest.display,"standalone");assert.equal(manifest.start_url,"/");assert.equal(manifest.id,"/");
  for(const size of [192,512]){
   const icon=manifest.icons.find(x=>x.sizes===size+"x"+size&&x.type==="image/png");assert.ok(icon);
   const image=await page.request.get(origin+icon.src);assert.equal(image.status(),200);
   const bytes=await image.body();assert.equal(bytes.readUInt32BE(16),size);assert.equal(bytes.readUInt32BE(20),size);
   const dims=await page.evaluate(async url=>{const img=new Image();img.src=url;await img.decode();return [img.naturalWidth,img.naturalHeight]},icon.src);assert.deepEqual(dims,[size,size]);
  }
  await page.waitForFunction(()=>!!navigator.serviceWorker?.controller,{},{timeout:30000});
  assert.equal(await page.evaluate(()=>!!document.querySelector('link[rel="apple-touch-icon"]')),true);
  if(name==="chromium"){
   const cdp=await ctx.newCDPSession(page);const {installabilityErrors}=await cdp.send("Page.getInstallabilityErrors");
   assert.deepEqual(installabilityErrors,[],"Chromium installability criteria");console.log("ZIPPLE_PWA_CHROMIUM_INSTALLABILITY_PASS");
  }
  await ctx.setOffline(true);await page.reload();await page.getByRole("heading",{name:expected}).waitFor();await ctx.setOffline(false);
  console.log("ZIPPLE_PWA_"+name.toUpperCase()+"_OFFLINE_PASS");await ctx.close();
 }finally{await browser.close()}
}
