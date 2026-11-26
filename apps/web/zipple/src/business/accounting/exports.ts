// Exact integer FCFA export, no fiscal classification invented. Protect spreadsheet consumers from formula injection.
export function csvCell(value:unknown):string{
 let s=String(value??"");
 if(/^[\s\u0000-\u001f]*[=+\-@]/.test(s))s="'"+s;
 return '"'+s.replace(/"/g,'""')+'"';
}
export function csvRows(rows:unknown[][]):string{return "\ufeff"+rows.map(r=>r.map(csvCell).join(";")).join("\r\n")+"\r\n"}
export function downloadCsv(name:string,rows:unknown[][]){const url=URL.createObjectURL(new Blob([csvRows(rows)],{type:"text/csv;charset=utf-8"}));const a=document.createElement("a");a.href=url;a.download=name;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000)}
