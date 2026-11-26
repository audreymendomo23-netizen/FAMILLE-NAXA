// LiveKit-compatible candidate. No provider connection or paid service is created by this code.
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
type Grant={meeting_id:string;member_id:string;room:string;host:boolean;revision:number};
export function parseMediaGrant(input:unknown,meetingId:string):Grant {
 if(!input||typeof input!=="object"||Array.isArray(input))throw Error("INVALID_MEDIA_GRANT");
 const g=input as Record<string,unknown>;
 if(typeof g.meeting_id!=="string"||g.meeting_id!==meetingId||!uuid.test(meetingId)||typeof g.member_id!=="string"||!uuid.test(g.member_id)||g.room!=="ns-"+meetingId||typeof g.host!=="boolean"||typeof g.revision!=="number"||!Number.isSafeInteger(g.revision)||g.revision<2)throw Error("INVALID_MEDIA_GRANT");
 return {meeting_id:meetingId,member_id:g.member_id,room:g.room as string,host:g.host,revision:g.revision};
}
const encode=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
const json=(value:unknown)=>encode(new TextEncoder().encode(JSON.stringify(value)));
export async function signJoinToken(grant:Grant,apiKey:string,secret:string,now=Math.floor(Date.now()/1000)):Promise<string>{
 const g=parseMediaGrant(grant,grant.meeting_id);
 if(!/^[A-Za-z0-9_-]{8,128}$/.test(apiKey)||secret.length<32||!Number.isSafeInteger(now)||now<1)throw Error("MEDIA_CONFIG_INVALID");
 const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
 // Join-only grant; even the organizer must use a server-checked moderation/egress endpoint.
 const claims={iss:apiKey,sub:g.member_id,nbf:now-5,exp:now+90,video:{room:g.room,roomJoin:true,canPublish:true,canSubscribe:true,canPublishData:false,canUpdateOwnMetadata:false,canPublishSources:g.host?["camera","microphone","screen_share","screen_share_audio"]:["camera","microphone"],roomAdmin:false,roomCreate:false,roomRecord:false,roomList:false}};
 const data=json({alg:"HS256",typ:"JWT"})+"."+json(claims);
 const sig=await crypto.subtle.sign("HMAC",key,new TextEncoder().encode(data));
 return data+"."+encode(new Uint8Array(sig));
}
export function validMediaUrl(raw:string):string{
 const u=new URL(raw);
 if(u.protocol!=="wss:"||u.username||u.password||u.pathname!=="/"||u.search||u.hash)throw Error("MEDIA_CONFIG_INVALID");
 return u.origin;
}
