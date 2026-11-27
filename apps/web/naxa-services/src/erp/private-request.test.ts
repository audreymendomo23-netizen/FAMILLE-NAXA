import {describe,it,expect,vi} from "vitest";
import {privateRequest} from "./private-request";
describe("private request lifecycle across RH, meetings and reports",()=>{
 it("does not send a request when scope changes during token refresh",async()=>{
  const c=new AbortController();let finish:(v:string)=>void=()=>{};const token=new Promise<string>(r=>{finish=r;});const send=vi.fn();
  const request=privateRequest(c.signal,()=>true,()=>token,send);c.abort();finish("old-token");
  await expect(request).rejects.toThrow("SESSION_CHANGED");expect(send).not.toHaveBeenCalled();
 });
 it("refuses a stale response even when the server already received the request",async()=>{
  const c=new AbortController();let active=true;
  const send=vi.fn(async()=>{active=false;return new Response(JSON.stringify({private:true}));});
  await expect(privateRequest(c.signal,()=>active,async()=>"token",send)).rejects.toThrow("SESSION_CHANGED");expect(send).toHaveBeenCalledTimes(1);
 });
 it("checks scope again after asynchronous JSON decoding",async()=>{
  const c=new AbortController();const send=vi.fn(async()=>({ok:true,json:async()=>{c.abort();return {private:true};}} as Response));
  await expect(privateRequest(c.signal,()=>true,async()=>"token",send)).rejects.toThrow("SESSION_CHANGED");
 });
 it("preserves valid responses and rejects server errors and absent lifecycle",async()=>{
  const c=new AbortController();const send=vi.fn(async()=>new Response(JSON.stringify({ok:true})));
  await expect(privateRequest(c.signal,()=>true,async()=>"token",send)).resolves.toEqual({ok:true});
  await expect(privateRequest(undefined,()=>true,async()=>"token",send)).rejects.toThrow("SESSION_CHANGED");
  await expect(privateRequest(c.signal,()=>true,async()=>"token",async()=>new Response("",{status:403}))).rejects.toThrow("PRIVATE_REQUEST_FAILED");
 });
});

it("does not transmit if a component is replaced without aborting the previous signal",async()=>{const c=new AbortController();let current=true;let finish:(v:string)=>void=()=>{};const token=new Promise<string>(r=>{finish=r;});const send=vi.fn();const pending=privateRequest(c.signal,()=>current,()=>token,send);current=false;finish("stale");await expect(pending).rejects.toThrow("SESSION_CHANGED");expect(send).not.toHaveBeenCalled();});
