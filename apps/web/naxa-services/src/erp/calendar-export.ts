// Explicit local download: no calendar provider or network service.
export function calendarEvent(input:{id:string;title:string;start:string;end:string;revision:number;status:"CONFIRMED"|"CANCELLED"},now=Date.now()){
 if(!/^[0-9a-f-]{36}$/i.test(input.id)||!Number.isSafeInteger(input.revision)||input.revision<1||!["CONFIRMED","CANCELLED"].includes(input.status))throw Error("INVALID_CALENDAR_EVENT");
 const start=Date.parse(input.start),end=Date.parse(input.end);
 if(!Number.isFinite(start)||!Number.isFinite(end)||end<=start||!Number.isFinite(now))throw Error("INVALID_CALENDAR_EVENT");
 const stamp=(n:number)=>new Date(n).toISOString().replace(/[-:]/g,"").replace(/\.\d{3}Z$/,"Z");
 const escape=(s:string)=>s.replace(/\\/g,"\\\\").replace(/\r\n|\r|\n/g,"\\n").replace(/[,;]/g,c=>"\\"+c);
 // Fold UTF-8 lines at 75 octets including the continuation space.
 const fold=(line:string)=>{let out="",part="",bytes=0;for(const c of line){const n=new TextEncoder().encode(c).length;if(bytes+n>75){out+=part+"\r\n";part=" ";bytes=1;}part+=c;bytes+=n;}return out+part;};
 return ["BEGIN:VCALENDAR","VERSION:2.0","PRODID:-//NAXA SERVICES//Local calendar//EN","CALSCALE:GREGORIAN","BEGIN:VEVENT","UID:"+input.id+"@naxa-services","DTSTAMP:"+stamp(now),"DTSTART:"+stamp(start),"DTEND:"+stamp(end),"SEQUENCE:"+input.revision,"STATUS:"+input.status,"SUMMARY:"+escape(input.title),"CLASS:PRIVATE","END:VEVENT","END:VCALENDAR"].map(fold).join("\r\n")+"\r\n";
}
export function downloadLocal(content:string,name:string,mime:string){
 if(document.visibilityState==="hidden")return;
 const url=URL.createObjectURL(new Blob([content],{type:mime}));const a=document.createElement("a");a.href=url;a.download=name;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
