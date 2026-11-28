// Browser hardware boundary: Chromium's real getUserMedia pipeline, with deterministic Y4M input.
import {chromium} from "playwright";
import QRCode from "qrcode";
import assert from "node:assert/strict";
import {mkdtemp,writeFile,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
const origin="http://127.0.0.1:4173",api="https://idupfjbkwjcavyisxteo.supabase.co";
const code="50000000-0000-0000-0000-000000000441."+"a".repeat(64);
const user="00000000-0000-0000-0000-000000000441",org="10000000-0000-0000-0000-000000000441",site="20000000-0000-0000-0000-000000000441";
assert.equal(process.env.SECURITY_VIRTUAL_LAB,"1");
const directory=await mkdtemp(join(tmpdir(),"security-camera-"));
async function videoFile(name,withQr){
 const width=640,height=480,y=Buffer.alloc(width*height,235),uv=Buffer.alloc(width*height/4,128);
 if(withQr){const m=QRCode.create(code,{errorCorrectionLevel:"M"}).modules,scale=Math.floor(400/(m.size+8)),x0=Math.floor((width-m.size*scale)/2),y0=Math.floor((height-m.size*scale)/2);for(let r=0;r<m.size;r++)for(let c=0;c<m.size;c++)if(m.get(r,c))for(let yy=0;yy<scale;yy++)y.fill(16,(y0+r*scale+yy)*width+x0+c*scale,(y0+r*scale+yy)*width+x0+(c+1)*scale)}
 const frame=Buffer.concat([Buffer.from("FRAME\n"),y,uv,uv]),path=join(directory,name);
 await writeFile(path,Buffer.concat([Buffer.from("YUV4MPEG2 W640 H480 F10:1 Ip A1:1 C420jpeg\n"),...Array(10).fill(frame)]));return path
}
async function run(file,shouldRead){
 const browser=await chromium.launch({headless:true,args:["--use-fake-device-for-media-stream","--use-fake-ui-for-media-stream","--use-file-for-fake-video-capture="+file]});
 const ctx=await browser.newContext({serviceWorkers:"block",permissions:["camera"]});
 let writes=0;
 await ctx.addInitScript(()=>{const md=navigator.mediaDevices;if(!md)return;const original=md.getUserMedia.bind(md);window.__labTracks=[];md.getUserMedia=async(...args)=>{const stream=await original(...args);window.__labTracks.push(...stream.getTracks());return stream}});
 await ctx.route("**/*",async route=>{const req=route.request(),u=new URL(req.url());if(u.origin===origin)return route.continue();if(u.origin!==api)return route.abort();
 const send=(body,status=200)=>route.fulfill({status,contentType:"application/json",headers:{"access-control-allow-origin":"*","access-control-allow-headers":"*","access-control-allow-methods":"GET,POST,OPTIONS"},body:JSON.stringify(body)});
 if(req.method()==="OPTIONS")return send({});
 if(u.pathname==="/auth/v1/token")return send({access_token:"virtual-camera-only",user:{id:user},expires_in:3600});
 if(u.pathname==="/rest/v1/sec_sites"&&req.method()==="GET")return send([{id:site,organization_id:org,name:"Virtual lab"}]);
 if(req.method()==="POST")writes++;
 return send({},403);
 });
 try{
  const page=await ctx.newPage();await page.goto(origin+"/");await page.getByText("Connexion SECURITY",{exact:true}).click();await page.getByLabel("Identifiant de recette (e-mail provisionné)").fill("camera@example.invalid");await page.getByLabel("Mot de passe",{exact:true}).fill("synthetic");await page.getByRole("button",{name:"Connexion",exact:true}).click();await page.getByText("Accès SECURITY confirmé.").waitFor();
  await page.goto(origin+"/#/B4.26");const pass=page.getByRole("region",{name:"Passage temporaire"}),scanner=pass.getByRole("region",{name:"Lecture QR locale"});
  await scanner.getByRole("button",{name:"Scanner le QR",exact:true}).click();
  if(shouldRead){await scanner.getByText("Code lu. Confirmez au serveur.",{exact:true}).waitFor();assert.equal(await pass.getByLabel("Code de passage",{exact:true}).inputValue(),code);assert.equal(await pass.getByRole("button",{name:"Vérifier le QR et consigner l’entrée"}).isEnabled(),true)}
  else{await scanner.getByText("Présentez le QR à la caméra.",{exact:true}).waitFor();await page.waitForFunction(()=>document.querySelector("video")?.readyState>=2);assert.equal(await pass.getByLabel("Code de passage",{exact:true}).inputValue(),"");await scanner.getByRole("button",{name:"Arrêter la caméra",exact:true}).click()}
  await page.waitForFunction(()=>window.__labTracks.length>0&&window.__labTracks.every(t=>t.readyState==="ended"));assert.equal(writes,0,"Camera-only operation must not write any server record");
  console.log("PASS VIRTUAL camera "+(shouldRead?"QR decoded and camera released":"blank input ignored and camera stopped")+"; physical_certified=false");
 }finally{await ctx.close();await browser.close()}
}
try{await run(await videoFile("qr.y4m",true),true);await run(await videoFile("blank.y4m",false),false)}finally{await rm(directory,{recursive:true,force:true})}
