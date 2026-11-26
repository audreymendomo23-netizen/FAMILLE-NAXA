// Local export of the already authorized report. No new API, storage or remote processing.
export type ReportData={daily:Record<string,unknown>[];monthly:Record<string,unknown>[];annual:Record<string,unknown>[]};
export type Cell=string|number|null;
export function financialRows(data:ReportData,periods:[string,string,string],headers:string[]):Cell[][]{
 const number=(v:unknown):number|null=>typeof v==="number"&&Number.isFinite(v)?v:null;
 const rows:Cell[][]=[headers];
 for(const [index,key] of (["daily","monthly","annual"] as const).entries()){
  const periodKey=["performance_day","performance_month","performance_year"][index];
  for(const row of data[key])rows.push([periods[index],typeof row[periodKey]==="string"?String(row[periodKey]):null,number(row.revenue_xaf),number(row.cost_of_goods_xaf??row.known_cost_of_goods_xaf),number(row.gross_profit_xaf),number(row.confirmed_sales_count),number(row.uncosted_sales_count)]);
 }
 return rows;
}
const xml=(s:string)=>s.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g,"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
const encoder=new TextEncoder();
function crc32(data:Uint8Array){let crc=0xffffffff;for(const byte of data){crc^=byte;for(let bit=0;bit<8;bit++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return (crc^0xffffffff)>>>0;}
function zip(files:Record<string,string>):Uint8Array{
 const parts:Uint8Array[]=[],central:Uint8Array[]=[];let offset=0,centralSize=0;
 for(const [path,content] of Object.entries(files)){
  const name=encoder.encode(path),body=encoder.encode(content),crc=crc32(body);
  const local=new Uint8Array(30+name.length),l=new DataView(local.buffer);
  l.setUint32(0,0x04034b50,true);l.setUint16(4,20,true);l.setUint16(12,33,true);l.setUint32(14,crc,true);l.setUint32(18,body.length,true);l.setUint32(22,body.length,true);l.setUint16(26,name.length,true);local.set(name,30);
  const cd=new Uint8Array(46+name.length),c=new DataView(cd.buffer);
  c.setUint32(0,0x02014b50,true);c.setUint16(4,20,true);c.setUint16(6,20,true);c.setUint16(14,33,true);c.setUint32(16,crc,true);c.setUint32(20,body.length,true);c.setUint32(24,body.length,true);c.setUint16(28,name.length,true);c.setUint32(42,offset,true);cd.set(name,46);
  parts.push(local,body);central.push(cd);offset+=local.length+body.length;centralSize+=cd.length;
 }
 const end=new Uint8Array(22),e=new DataView(end.buffer);e.setUint32(0,0x06054b50,true);e.setUint16(8,central.length,true);e.setUint16(10,central.length,true);e.setUint32(12,centralSize,true);e.setUint32(16,offset,true);
 const result=new Uint8Array(offset+centralSize+end.length);let cursor=0;for(const part of [...parts,...central,end]){result.set(part,cursor);cursor+=part.length;}return result;
}
export function financialXlsx(rows:Cell[][]):Uint8Array{
 if(rows.length>100000||rows.some(r=>r.length>26))throw Error("REPORT_TOO_LARGE");
 const ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main",rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships",pkg="http://schemas.openxmlformats.org/package/2006/relationships";
 const sheet=rows.map((row,i)=>'<row r="'+(i+1)+'">'+row.map((value,j)=>{
  const address=String.fromCharCode(65+j)+(i+1);
  if(value===null)return '<c r="'+address+'"/>';
  if(typeof value==="number"&&Number.isFinite(value))return '<c r="'+address+'"><v>'+value+'</v></c>';
  // Explicit inline strings never execute as spreadsheet formulas.
  return '<c r="'+address+'" t="inlineStr"><is><t xml:space="preserve">'+xml(String(value))+'</t></is></c>';
 }).join("")+'</row>').join("");
 const declaration='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
 return zip({
 "[Content_Types].xml":declaration+'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
 "_rels/.rels":declaration+'<Relationships xmlns="'+pkg+'"><Relationship Id="rId1" Type="'+rel+'/officeDocument" Target="xl/workbook.xml"/></Relationships>',
 "xl/workbook.xml":declaration+'<workbook xmlns="'+ns+'" xmlns:r="'+rel+'"><sheets><sheet name="Performance" sheetId="1" r:id="rId1"/></sheets></workbook>',
 "xl/_rels/workbook.xml.rels":declaration+'<Relationships xmlns="'+pkg+'"><Relationship Id="rId1" Type="'+rel+'/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
 "xl/worksheets/sheet1.xml":declaration+'<worksheet xmlns="'+ns+'"><sheetData>'+sheet+'</sheetData></worksheet>'
 });
}
export function downloadFinancialXlsx(rows:Cell[][]){
 const data=financialXlsx(rows),url=URL.createObjectURL(new Blob([data],{type:"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}));
 const link=document.createElement("a");link.href=url;link.download="naxa-services-performance.xlsx";document.body.append(link);link.click();link.remove();window.setTimeout(()=>URL.revokeObjectURL(url),1000);
}
export function printFinancialReport(rows:Cell[][],title:string){
 const popup=window.open("","_blank","width=900,height=700");if(!popup)throw Error("PRINT_UNAVAILABLE");popup.opener=null;
 const doc=popup.document;doc.title=title;
 const style=doc.createElement("style");style.textContent="body{font:12px sans-serif;padding:20px;color:#111}h1{font-size:18px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #999;padding:6px;text-align:left}thead{display:table-header-group}tr{break-inside:avoid}";doc.head.append(style);
 const h=doc.createElement("h1");h.textContent=title;doc.body.append(h);
 const table=doc.createElement("table"),head=table.createTHead(),body=table.createTBody();
 rows.forEach((row,index)=>{const tr=(index===0?head:body).insertRow();row.forEach(value=>{const td=doc.createElement(index===0?"th":"td");td.textContent=value===null?"—":String(value);tr.append(td);});});doc.body.append(table);
 popup.addEventListener("afterprint",()=>popup.close(),{once:true});popup.focus();popup.print();
}
