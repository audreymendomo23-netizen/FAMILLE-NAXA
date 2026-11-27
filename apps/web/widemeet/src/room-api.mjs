// Separate WideMeet room endpoint on the configured WideMeet origin only.
async function roomResponse(authBase,action,body,token,fetcher=fetch){
 if(!["list","contacts","pass-list","read","create","command","media-grant","minutes","tasks","series-create","series-cancel","presence","recordings","recording-download","notices"].includes(action)||typeof token!=="string"||!/^[a-f0-9]{64}$/.test(token))throw Error("INVALID_REQUEST");
 const u=new URL(authBase);
 if(u.protocol!=="https:"||u.username||u.password||u.search||u.hash||!u.pathname.replace(/\/$/,"").endsWith("/widemeet-auth"))throw Error("INVALID_API");
 u.pathname=u.pathname.replace(/\/$/,"").replace(/\/widemeet-auth$/,"/widemeet-room/"+action);
 const r=await fetcher(u,{method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+token},body:JSON.stringify({...body,app_id:"WIDEMEET"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!r.ok)throw Error("ROOM_REQUEST_REJECTED");return r;
}

export async function roomRequest(authBase,action,body,token,fetcher=fetch){if(action==="recording-download")throw Error("INVALID_REQUEST");return (await roomResponse(authBase,action,body,token,fetcher)).json();}
export async function downloadRecording(authBase,roomId,item,token,fetcher=fetch){
 if(!Number.isSafeInteger(item.bytes)||item.bytes<1000||item.bytes>128*1024*1024||!/^[a-f0-9]{64}$/.test(item.sha256))throw Error("INVALID_RECORDING");
 const r=await roomResponse(authBase,"recording-download",{room_id:roomId,recording_id:item.recording_id,request_id:crypto.randomUUID()},token,fetcher);
 if(r.headers.get("content-type")?.split(";")[0]!=="audio/ogg"||!r.body)throw Error("INVALID_RECORDING");
 const reader=r.body.getReader(),chunks=[];let size=0;
 try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>item.bytes)throw Error("INVALID_RECORDING");chunks.push(value)}}catch(e){await reader.cancel().catch(()=>{});throw e}
 if(size!==item.bytes)throw Error("INVALID_RECORDING");
 const blob=new Blob(chunks,{type:"audio/ogg"}),digest=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",await blob.arrayBuffer())),x=>x.toString(16).padStart(2,"0")).join("");
 if(digest!==item.sha256)throw Error("INVALID_RECORDING");return blob;
}
