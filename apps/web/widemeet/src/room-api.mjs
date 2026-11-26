// Separate WideMeet room endpoint on the configured WideMeet origin only.
export async function roomRequest(authBase,action,body,token,fetcher=fetch){
 if(!["list","contacts","read","create","command","media-grant"].includes(action)||typeof token!=="string"||!/^[a-f0-9]{64}$/.test(token))throw Error("INVALID_REQUEST");
 const u=new URL(authBase);
 if(u.protocol!=="https:"||u.username||u.password||u.search||u.hash||!u.pathname.replace(/\/$/,"").endsWith("/widemeet-auth"))throw Error("INVALID_API");
 u.pathname=u.pathname.replace(/\/$/,"").replace(/\/widemeet-auth$/,"/widemeet-room/"+action);
 const r=await fetcher(u,{method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+token},body:JSON.stringify({...body,app_id:"WIDEMEET"}),cache:"no-store",redirect:"error",credentials:"omit"});
 if(!r.ok)throw Error("ROOM_REQUEST_REJECTED");return r.json();
}
