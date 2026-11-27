import assert from 'node:assert/strict';
import {chromium} from '@playwright/test';
const origin='https://famille-naxa.pages.dev';
const browser=await chromium.launch({headless:true});
try {
 for(const width of [320,390,1440]){
  const context=await browser.newContext({viewport:{width,height:900}});
  try{
   const page=await context.newPage();
   const r=await page.goto(origin+'/',{waitUntil:'domcontentloaded'});
   assert.equal(r.status(),200);assert.equal(new URL(page.url()).origin,origin);
   await page.getByLabel('Identifiant NAXA Services').waitFor();
   await page.getByLabel('Mot de passe',{exact:true}).waitFor();
   assert.equal(await page.locator('.side-nav').count(),0,'no ERP before sign-in');
   const identifier=page.getByLabel('Identifiant NAXA Services');
   const password=page.getByLabel('Mot de passe',{exact:true});
   const submit=page.getByRole('button',{name:'Se connecter',exact:true});
   for(const control of [identifier,password,submit]){assert.ok(await control.isVisible());assert.ok(await control.isEnabled());}
   await identifier.focus();assert.ok(await identifier.evaluate(el=>document.activeElement===el));
   await identifier.press('Tab');
   assert.ok(await password.evaluate(el=>document.activeElement===el),'keyboard focus moves from login to password');
   assert.ok(await page.evaluate(()=>{const el=document.activeElement;return el instanceof HTMLElement&&el.getBoundingClientRect().width>0&&el.getBoundingClientRect().height>0;}),'focused password control is visible');
   assert.equal(await password.getAttribute('type'),'password');
   assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),'no horizontal overflow at '+width);
   await page.evaluate(()=>navigator.serviceWorker.ready.then(()=>true));
   await page.waitForFunction(()=>Boolean(navigator.serviceWorker.controller));
   const cacheState=await page.evaluate(async()=>{
    const keys=await caches.keys(), entries=[];
    for(const key of keys){const cache=await caches.open(key);for(const req of await cache.keys()) entries.push({key,url:req.url});}
    return {keys,entries};
   });
   assert.ok(cacheState.keys.some(k=>/^naxa-services-shell-[a-f0-9]{20}$/.test(k)));
   assert.ok(cacheState.entries.some(e=>new URL(e.url).pathname.startsWith('/assets/')&&e.url.endsWith('.js')));
   assert.ok(cacheState.entries.some(e=>new URL(e.url).pathname.startsWith('/assets/')&&e.url.endsWith('.css')));
   assert.ok(cacheState.entries.every(e=>new URL(e.url).origin===origin&&!/\/(auth|rest|storage|functions)\/v1\//.test(new URL(e.url).pathname)));
   await context.setOffline(true);
   await page.close();
   const offline=await context.newPage();
   await offline.goto(origin+'/');
   await offline.getByLabel('Identifiant NAXA Services').waitFor();
   assert.equal(await offline.locator('.side-nav').count(),0);
   console.log('PASS hosted PWA shell and offline navigation at '+width+'px; no API cache or unauthenticated ERP');
  }finally{await context.close();}
 }
}finally{await browser.close();}
