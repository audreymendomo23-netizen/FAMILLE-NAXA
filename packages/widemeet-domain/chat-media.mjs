// Shared B2 binary validation and integrity. No public URLs, no browser service keys.
export const MAX_CHAT_MEDIA_BYTES=1048576;
export const CHAT_MEDIA_BUCKET="wm-chat-media";
const extensions={"application/pdf":".pdf","image/jpeg":".jpg","image/png":".png","audio/ogg":".ogg","audio/webm":".webm","audio/mp4":".m4a","video/mp4":".mp4","video/webm":".webm"};
const ascii=(bytes,offset,value)=>[...value].every((c,i)=>bytes[offset+i]===c.charCodeAt(0));
export function safeMediaName(name,mime){
 if(typeof name!=="string"||!extensions[mime])throw Error("invalid_media");
 const ext=extensions[mime],base=name.normalize("NFKC").replace(/[^\p{L}\p{N} ._-]/gu,"_").trim().replace(/^\.+/,"").replace(/\.[^.]{1,10}$/,"").slice(0,100).trim();
 return (base||"document")+ext;
}
export function validMediaBytes(kind,mime,b){
 if(!(b instanceof Uint8Array)||b.length<8||b.length>MAX_CHAT_MEDIA_BYTES)return false;
 if(kind==="file"){
  if(mime==="application/pdf")return ascii(b,0,"%PDF-");
  if(mime==="image/jpeg")return b[0]===255&&b[1]===216&&b.at(-2)===255&&b.at(-1)===217;
  if(mime==="image/png")return [137,80,78,71,13,10,26,10].every((v,i)=>b[i]===v);
 }
 if(kind==="video"){
  // Bounded container inspection. Reject audio-only WebM, incomplete MP4 and mislabeled bytes.
  const contains=seq=>{outer:for(let i=0;i<=b.length-seq.length;i++){for(let j=0;j<seq.length;j++)if(b[i+j]!==seq[j])continue outer;return true}return false};
  if(mime==="video/webm")return [26,69,223,163].every((v,i)=>b[i]===v)&&contains([119,101,98,109])&&contains([86,95,86,80])&&contains([31,67,182,117]);
  if(mime==="video/mp4"){
   let at=0,ftyp=false,moov=false,mdat=false;
   const view=new DataView(b.buffer,b.byteOffset,b.byteLength);
   while(at+8<=b.length){const size=view.getUint32(at);if(size<8||size>b.length-at)return false;
    if(ascii(b,at+4,"ftyp"))ftyp=at===0;
    if(ascii(b,at+4,"moov"))moov=true;
    if(ascii(b,at+4,"mdat"))mdat=size>8;
    at+=size;
   }
   return at===b.length&&ftyp&&moov&&mdat&&contains([118,105,100,101]);
  }
 }
 if(kind==="voice"){
  if(mime==="audio/ogg")return ascii(b,0,"OggS");
  if(mime==="audio/webm")return [26,69,223,163].every((v,i)=>b[i]===v);
  if(mime==="audio/mp4")return ascii(b,4,"ftyp");
 }
 return false;
}
export async function mediaDigest(bytes){
 return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",bytes)),n=>n.toString(16).padStart(2,"0")).join("");
}
export function encodeMedia(bytes){let out="";for(let i=0;i<bytes.length;i+=16384)out+=String.fromCharCode(...bytes.subarray(i,i+16384));return btoa(out)}
export function decodeMedia(raw){
 if(typeof raw!=="string"||raw.length>Math.ceil(MAX_CHAT_MEDIA_BYTES/3)*4||raw.length%4!==0)throw Error("invalid_media");
 const bytes=Uint8Array.from(atob(raw),c=>c.charCodeAt(0));if(bytes.length>MAX_CHAT_MEDIA_BYTES||encodeMedia(bytes)!==raw)throw Error("invalid_media");return bytes;
}
