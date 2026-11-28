// Portable encrypted business archive, compatible with Android implementation.
const b64=bytes=>{let s='';for(let i=0;i<bytes.length;i+=8192)s+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(s)};
export async function encryptBackup(data,password,cryptoImpl=globalThis.crypto){
 if(data?.format!=='grillad-business-export-v1'||typeof password!=='string'||password.length<12)throw Error('BACKUP_INPUT');
 const enc=new TextEncoder(),salt=cryptoImpl.getRandomValues(new Uint8Array(16)),iv=cryptoImpl.getRandomValues(new Uint8Array(12)),iterations=600000;
 const material=await cryptoImpl.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveKey']);
 const key=await cryptoImpl.subtle.deriveKey({name:'PBKDF2',salt,iterations,hash:'SHA-256'},material,{name:'AES-GCM',length:256},false,['encrypt']);
 const ciphertext=await cryptoImpl.subtle.encrypt({name:'AES-GCM',iv,additionalData:enc.encode('grillad-backup-v1')},key,enc.encode(JSON.stringify(data)));
 return {format:'grillad-backup-v1',kdf:'PBKDF2-SHA256',iterations,salt:b64(salt),iv:b64(iv),ciphertext:b64(new Uint8Array(ciphertext))};
}
