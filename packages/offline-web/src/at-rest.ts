/** Origin-local at-rest encryption. The non-extractable key is persisted as a
 * CryptoKey; this protects raw records, not a compromised browser/origin. */
export type SealedValue={version:1;iv:number[];ciphertext:ArrayBuffer};
const KEY="naxa-services-web:aes-gcm:v1";
const encoder=new TextEncoder();
function valid(key:unknown):key is CryptoKey{return typeof CryptoKey!=="undefined"&&key instanceof CryptoKey&&key.type==="secret"&&!key.extractable&&key.algorithm.name==="AES-GCM"&&key.usages.includes("encrypt")&&key.usages.includes("decrypt");}
async function lookup(db:IDBDatabase,store:string):Promise<unknown>{
 return new Promise((resolve,reject)=>{const r=db.transaction(store).objectStore(store).get(KEY);r.onsuccess=()=>resolve(r.result?.value);r.onerror=()=>reject(r.error);});
}
async function keyFor(db:IDBDatabase,store:string,create:boolean):Promise<CryptoKey>{
 if(!globalThis.crypto?.subtle)throw Error("NS_LOCAL_CRYPTO_UNAVAILABLE");
 const existing=await lookup(db,store);
 if(existing!==undefined){if(!valid(existing))throw Error("NS_LOCAL_KEY_INVALID");return existing;}
 if(!create)throw Error("NS_LOCAL_KEY_MISSING");
 const candidate=await crypto.subtle.generateKey({name:"AES-GCM",length:256},false,["encrypt","decrypt"]);
 // Read again inside a serialized write transaction so concurrent tabs cannot
 // create different keys for the same origin.
 return new Promise((resolve,reject)=>{
  const tx=db.transaction(store,"readwrite"),s=tx.objectStore(store),r=s.get(KEY);
  let chosen:CryptoKey=candidate;
  r.onsuccess=()=>{const value=r.result?.value;if(value!==undefined){if(!valid(value)){tx.abort();return;}chosen=value;}else s.add({key:KEY,value:candidate});};
  r.onerror=()=>tx.abort();tx.oncomplete=()=>resolve(chosen);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error??Error("NS_LOCAL_KEY_TRANSACTION_ABORTED"));
 });
}
export async function digest(value:string):Promise<string>{
 const bytes=await crypto.subtle.digest("SHA-256",encoder.encode(value));
 return Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,"0")).join("");
}
export async function seal(db:IDBDatabase,store:string,aad:string,clear:string):Promise<SealedValue>{
 const key=await keyFor(db,store,true),iv=crypto.getRandomValues(new Uint8Array(12));
 const bytes=encoder.encode(clear);
 try{return {version:1,iv:Array.from(iv),ciphertext:await crypto.subtle.encrypt({name:"AES-GCM",iv,additionalData:encoder.encode(aad),tagLength:128},key,bytes)};}
 finally{bytes.fill(0);}
}
export async function unseal(db:IDBDatabase,store:string,aad:string,value:SealedValue):Promise<string>{
 if(value.version!==1||!Array.isArray(value.iv)||value.iv.length!==12||value.iv.some(n=>!Number.isInteger(n)||n<0||n>255)||!(value.ciphertext instanceof ArrayBuffer)||value.ciphertext.byteLength<16)throw Error("NS_LOCAL_CIPHER_INVALID");
 const key=await keyFor(db,store,false);
 const clear=new Uint8Array(await crypto.subtle.decrypt({name:"AES-GCM",iv:Uint8Array.from(value.iv),additionalData:encoder.encode(aad),tagLength:128},key,value.ciphertext));
 try{return new TextDecoder("utf-8",{fatal:true}).decode(clear);}finally{clear.fill(0);}
}
