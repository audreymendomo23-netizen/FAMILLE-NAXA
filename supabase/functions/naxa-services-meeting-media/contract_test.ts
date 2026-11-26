import {parseMediaGrant,signJoinToken,validMediaUrl} from "./media_contract.ts";
import {handleMediaRequest} from "./index.ts";
const id="70000000-0000-4000-8000-000000000105",member="60000000-0000-4000-8000-000000000092";
const g={meeting_id:id,member_id:member,room:"ns-"+id,host:false,revision:2,screen_allowed:false,microphone_allowed:true};
const env={base:"https://qa.example.invalid",anon:"test-anon-key-not-real-123",url:"wss://media.example.invalid",key:"TEST_KEY_123",secret:"fixture-secret-not-real-at-least-32",enabled:true,allowedOrigins:["https://app.example.invalid"]};
const check=(v:unknown)=>{if(!v)throw Error("ASSERTION_FAILED");};
function throws(fn:()=>unknown){let fail=false;try{fn()}catch{fail=true;}check(fail);}
function decode(s:string){return JSON.parse(atob(s.replace(/-/g,"+").replace(/_/g,"/").padEnd(Math.ceil(s.length/4)*4,"=")));}
Deno.test("opaque scoped grants and join-only short token",async()=>{
 throws(()=>parseMediaGrant({...g,room:"another"},id));throws(()=>parseMediaGrant({...g,host:"true"},id));throws(()=>validMediaUrl("ws://media.example.invalid"));
 const jwt=await signJoinToken(g,env.key,env.secret,1000);const [h,b,s]=jwt.split(".");const payload=decode(b);
 check(decode(h).alg==="HS256"&&payload.sub===member&&payload.exp===1090&&payload.video.room===g.room);
 check(payload.video.roomJoin&&!payload.video.roomAdmin&&!payload.video.roomRecord&&!payload.video.roomCreate&&!payload.video.canPublishData);
 check(payload.video.canPublishSources.join(",")==="camera,microphone");
 const host=decode((await signJoinToken({...g,host:true,screen_allowed:true},env.key,env.secret,1000)).split(".")[1]);check(host.video.canPublishSources.includes("screen_share")&&!host.video.roomAdmin&&!host.video.roomRecord);
 const limited=decode((await signJoinToken({...g,screen_allowed:true,microphone_allowed:false},env.key,env.secret,1000)).split(".")[1]);check(limited.video.canPublishSources.join(",")==="camera,screen_share");
 throws(()=>parseMediaGrant({...g,microphone_allowed:undefined},id));
 const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(env.secret),{name:"HMAC",hash:"SHA-256"},false,["verify"]);
 const bytes=Uint8Array.from(atob(s.replace(/-/g,"+").replace(/_/g,"/").padEnd(Math.ceil(s.length/4)*4,"=")),c=>c.charCodeAt(0));
 check(await crypto.subtle.verify("HMAC",key,bytes,new TextEncoder().encode(h+"."+b)));
});
Deno.test("endpoint denies disabled, origin and unauthorized RPC, never uses client claims",async()=>{
 const req=(origin="https://app.example.invalid")=>new Request("https://edge.example.invalid",{method:"POST",headers:{origin,authorization:"Bearer fixture","Content-Type":"application/json"},body:JSON.stringify({meeting_id:id,host:true,member_id:id})});
 let calls=0;
 const mock:typeof fetch=async(input)=>{calls++;return String(input).includes("/auth/v1/user")?new Response(JSON.stringify({id:member}),{status:200}):new Response(JSON.stringify(g),{status:200});};
 check((await handleMediaRequest(req(),{...env,enabled:false},mock)).status===503&&calls===0);
 check((await handleMediaRequest(req("https://bad.example.invalid"),env,mock)).status===403&&calls===0);
 const deny:typeof fetch=async(input)=>String(input).includes("/auth/v1/user")?new Response("{}",{status:200}):new Response("{}",{status:403});
 check((await handleMediaRequest(req(),env,deny)).status===403);
 const response=await handleMediaRequest(req(),env,mock);check(response.status===200);const body=await response.json();
 check(decode(body.token.split(".")[1]).sub===member&&!decode(body.token.split(".")[1]).video.canPublishSources.includes("screen_share"));
 check(!JSON.stringify(body).includes(env.secret)&&response.headers.get("Cache-Control")==="no-store");
});
