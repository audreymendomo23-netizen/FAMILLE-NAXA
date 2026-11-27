// Minimal real OOXML workbook (stored ZIP, no external dependency or formulas).
const enc=new TextEncoder();
const esc=v=>String(v??"").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFE\uFFFF]/g,"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
const xml=s=>enc.encode('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+s);
const ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main";
function sheet(rows){
 return xml('<worksheet xmlns="'+ns+'"><sheetData>'+rows.map((r,i)=>'<row r="'+(i+1)+'">'+r.map((v,j)=>{const pos=String.fromCharCode(65+j)+(i+1);return typeof v==="number"&&Number.isFinite(v)?'<c r="'+pos+'"><v>'+v+'</v></c>':'<c r="'+pos+'" t="inlineStr"><is><t xml:space="preserve">'+esc(v)+'</t></is></c>'}).join("")+'</row>').join("")+'</sheetData></worksheet>');
}
function crc(a){let c=0xffffffff;for(const b of a){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}return(c^0xffffffff)>>>0}
function zip(files){
 const locals=[],central=[];let offset=0,total=0;
 function record(size,fill){const b=new Uint8Array(size);fill(new DataView(b.buffer));return b}
 for(const [name,data] of files){const n=enc.encode(name),sum=crc(data),len=data.length;
  const local=record(30,d=>{d.setUint32(0,0x04034b50,true);d.setUint16(4,20,true);d.setUint16(12,33,true);d.setUint32(14,sum,true);d.setUint32(18,len,true);d.setUint32(22,len,true);d.setUint16(26,n.length,true)});
  const cd=record(46,d=>{d.setUint32(0,0x02014b50,true);d.setUint16(4,20,true);d.setUint16(6,20,true);d.setUint16(14,33,true);d.setUint32(16,sum,true);d.setUint32(20,len,true);d.setUint32(24,len,true);d.setUint16(28,n.length,true);d.setUint32(42,offset,true)});
  locals.push(local,n,data);central.push(cd,n);offset+=local.length+n.length+len;total+=cd.length+n.length;
 }
 const end=record(22,d=>{d.setUint32(0,0x06054b50,true);d.setUint16(8,files.length,true);d.setUint16(10,files.length,true);d.setUint32(12,total,true);d.setUint32(16,offset,true)});
 const out=new Uint8Array(offset+total+end.length);let at=0;for(const b of [...locals,...central,end]){out.set(b,at);at+=b.length}return out;
}
export function buildReportXlsx(report,locale="fr"){
 if(!report||typeof report.title!=="string"||typeof report.recipient!=="string"||!Array.isArray(report.tasks)||!Array.isArray(report.polls)||report.tasks.length>100||report.polls.length>1000)throw Error("invalid_report");
 const tr=(fr,en)=>locale==="en"?en:fr,p=report.presence??{rows:[],samples:0,coverage_ms:0};
 const num=v=>typeof v==="number"&&Number.isFinite(v)?v:"";
 const flag=v=>v===true?tr("Oui","Yes"):v===false?tr("Non","No"):"";
 const rows=[
  [["WideMeet",tr("Rapport de réunion","Meeting report")],[tr("Réunion","Meeting"),report.title],[tr("Identifiant","Identifier"),report.room_id],[tr("Clôture","Closed"),report.closed_at],[tr("Destinataire","Recipient"),report.recipient],[tr("Observations SFU","SFU samples"),p.samples],[tr("Couverture estimée (ms)","Estimated coverage (ms)"),Number(p.coverage_ms??0)],[tr("Limite","Limitation"),tr("Connexions observées, pas une présence humaine continue.","Observed connections, not continuous human attendance.")],[tr("Intervalles sans observation","Unobserved gaps"),num(p.unobserved_gap_count)],[tr("Durée sans observation (ms)","Unobserved gap duration (ms)"),num(p.unobserved_gap_ms)]],
  [[tr("Participant","Participant"),tr("État","State"),tr("Observations","Samples"),tr("Durée estimée (ms)","Estimated duration (ms)"),tr("Réponse invitation","Invitation response"),tr("Première observation","First observation"),tr("Dernière observation","Last observation"),tr("Arrivées observées","Observed arrivals"),tr("Départs observés","Observed departures")],...(p.rows??[]).map(x=>[x.display_name,x.attendance,Number(x.samples_seen),Number(x.estimated_ms),x.response??"",x.first_seen??"",x.last_seen??"",num(x.observed_arrivals),num(x.observed_departures)])],
  [[tr("Tâche","Task"),tr("Responsable","Assignee"),tr("Échéance","Due"),tr("État","State")],...report.tasks.map(x=>[x.title,x.assignee,x.due_at,x.state])],
  [[tr("Question","Question"),tr("Option","Option"),tr("Réponses option","Option responses"),tr("Éligibles","Eligible"),tr("Répondants","Respondents"),tr("Non-répondants","Nonrespondents"),tr("Participation (%)","Response rate (%)"),tr("Quorum (%)","Quorum (%)"),tr("Quorum atteint","Quorum met"),tr("Seuil (%)","Threshold (%)"),tr("Part des répondants (%)","Respondent share (%)"),tr("Seuil atteint","Threshold met")],...report.polls.flatMap(x=>x.options.map(o=>[x.question??tr("Vote","Poll"),o.label,Number(o.count),num(x.eligible),num(x.responses),num(x.nonresponses),num(x.response_rate),num(x.quorum),flag(x.quorum_met),num(x.threshold),num(o.share_pct),flag(o.accepted)]))]
 ];
 const names=[tr("Synthèse","Summary"),tr("Présences","Attendance"),tr("Tâches","Tasks"),tr("Votes","Polls")];
 const rel="http://schemas.openxmlformats.org/package/2006/relationships",docrel="http://schemas.openxmlformats.org/officeDocument/2006/relationships";
 return zip([
  ["[Content_Types].xml",xml('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'+names.map((_,i)=>'<Override PartName="/xl/worksheets/sheet'+(i+1)+'.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join("")+'</Types>')],
  ["_rels/.rels",xml('<Relationships xmlns="'+rel+'"><Relationship Id="rId1" Type="'+docrel+'/officeDocument" Target="xl/workbook.xml"/></Relationships>')],
  ["xl/workbook.xml",xml('<workbook xmlns="'+ns+'" xmlns:r="'+docrel+'"><sheets>'+names.map((n,i)=>'<sheet name="'+esc(n)+'" sheetId="'+(i+1)+'" r:id="rId'+(i+1)+'"/>').join("")+'</sheets></workbook>')],
  ["xl/_rels/workbook.xml.rels",xml('<Relationships xmlns="'+rel+'">'+names.map((_,i)=>'<Relationship Id="rId'+(i+1)+'" Type="'+docrel+'/worksheet" Target="worksheets/sheet'+(i+1)+'.xml"/>').join("")+'</Relationships>')],
  ...rows.map((r,i)=>["xl/worksheets/sheet"+(i+1)+".xml",sheet(r)])
 ]);
}
