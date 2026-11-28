// Portable encrypted business archive, compatible with Android implementation.
const b64=bytes=>{let s='';for(let i=0;i<bytes.length;i+=8192)s+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(s)};
export async function encryptBackup(data,password,cryptoImpl=globalThis.crypto){
 if(!['grillad-business-export-v1','grillad-business-export-v2'].includes(data?.format)||typeof password!=='string'||password.length<12)throw Error('BACKUP_INPUT');
 const enc=new TextEncoder(),salt=cryptoImpl.getRandomValues(new Uint8Array(16)),iv=cryptoImpl.getRandomValues(new Uint8Array(12)),iterations=600000;
 const material=await cryptoImpl.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveKey']);
 const key=await cryptoImpl.subtle.deriveKey({name:'PBKDF2',salt,iterations,hash:'SHA-256'},material,{name:'AES-GCM',length:256},false,['encrypt']);
 const ciphertext=await cryptoImpl.subtle.encrypt({name:'AES-GCM',iv,additionalData:enc.encode('grillad-backup-v1')},key,enc.encode(JSON.stringify(data)));
 return {format:'grillad-backup-v1',kdf:'PBKDF2-SHA256',iterations,salt:b64(salt),iv:b64(iv),ciphertext:b64(new Uint8Array(ciphertext))};
}

export async function inspectBackup(archive,password,expected,cryptoImpl=globalThis.crypto){
 if(archive?.format!=='grillad-backup-v1'||archive.kdf!=='PBKDF2-SHA256'||archive.iterations!==600000||typeof password!=='string'||password.length<12||typeof archive.ciphertext!=='string'||archive.ciphertext.length>6000000)throw Error('BACKUP_FORMAT');
 const b=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0)),salt=b(archive.salt),iv=b(archive.iv);if(salt.length!==16||iv.length!==12)throw Error('BACKUP_FORMAT');
 const enc=new TextEncoder(),m=await cryptoImpl.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveKey']);const k=await cryptoImpl.subtle.deriveKey({name:'PBKDF2',salt,iterations:600000,hash:'SHA-256'},m,{name:'AES-GCM',length:256},false,['decrypt']);
 const d=JSON.parse(new TextDecoder().decode(await cryptoImpl.subtle.decrypt({name:'AES-GCM',iv,additionalData:enc.encode(archive.format)},k,b(archive.ciphertext))));
 const base=['items','cash','cash_recounts','preparations','stock_adjustments','sales','cash_receipts','expenses','purchases','targets','dimension_targets','service_policy','service_revisions','daily_summary'];const names=d.format==='grillad-business-export-v2'?[...base,'attendance_policy','attendance','attendance_corrections','missing_departures','missing_arrivals','notice_preference','notice_read']:base;
 if(!['grillad-business-export-v1','grillad-business-export-v2'].includes(d.format)||d.org!==expected.org||d.site!==expected.site||Object.keys(d.tables??{}).length!==names.length||names.some(n=>!Array.isArray(d.tables[n])||d.tables[n].length>10000||d.tables[n].some(r=>r.org!==expected.org||r.site!==expected.site)))throw Error('BACKUP_SCOPE');
 if(d.format==='grillad-business-export-v2'&&d.tables.attendance.some(r=>r.photo!==null))throw Error('BACKUP_PHOTO');
 return {generated_at:d.generated_at,counts:Object.fromEntries(names.map(n=>[n,d.tables[n].length])),restorable:false,reason:'PARTIAL_BUSINESS_EXPORT'};
}
