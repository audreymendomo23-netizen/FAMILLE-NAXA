import {readdir,readFile,mkdir,writeFile} from "node:fs/promises";
import path from "node:path";
const roots=["apps/android/naxa-services/src/main/java","apps/web/naxa-services/src"];
const testRoots=["apps/android/naxa-services/src/androidTest","apps/android/naxa-services/src/test","apps/web/naxa-services/e2e","apps/web/naxa-services/src","supabase/tests/drafts"];
const walk=async dir=>(await Promise.all((await readdir(dir,{withFileTypes:true})).map(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]))).flat();
const files=(await Promise.all(roots.map(walk))).flat().filter(f=>/\.(kt|tsx)$/.test(f)&&!f.includes(".test."));
const interactions=[];const copyCandidates=[];const tests=[];
const event=/\b(onClick|onLongClick|onValueChange|onCheckedChange|onDismissRequest|onSelectionChange|onSubmit|onChange|onMouseDown|onKeyDown|onNavigate|onConfirm|onBack|onSave|onDelete|onLogout|onSelect|onLogin|onToggleTheme|onForgot|onLocale|onNext|onSkip|onComplete)\s*=|\b(rememberLauncherForActivityResult|pointerInput|BackHandler|DropdownMenuItem|NavigationBarItem)\s*\(/g;
const jargon=/\b(?:backend|outbox|idempotence|idempotent|jwt|rls|rpc|sql|api key|service_role|passerelle|prototype|projection métier|connecteur|workflow|jeton|technique|recette|serveur|server)\b/i;
for(const file of files){
 const source=await readFile(file,"utf8");const lines=source.split("\n");
 for(let i=0;i<lines.length;i++){
  const line=lines[i];
  if(!line.trim()||line.trim().startsWith("//"))continue;
  for(const match of line.matchAll(event))interactions.push({file,line:i+1,column:match.index+1,event:match[1]??match[2],context:line.trim().slice(Math.max(0,match.index-100),match.index+180)});
  if(jargon.test(line)&&/(?:Text\(|Notice\(|<p\b|<small\b|<h[123]\b|<span\b|label\s*=|notice\s*=|message\s*=|throw new Error)/.test(line))copyCandidates.push({file,line:i+1,excerpt:line.trim().slice(0,400)});
 }
}
const testFiles=[...new Set((await Promise.all(testRoots.map(walk))).flat())].filter(f=>/\.spec\.ts$|\.test\.[tj]sx?$|Test\.kt$|\.sql$/.test(f));
for(const file of testFiles){
 const source=await readFile(file,"utf8");const lines=source.split("\n");
 for(let i=0;i<lines.length;i++)if(/\btest\s*\(|@Test\b|\bPASS:|\bDeno\.test\(/.test(lines[i]))tests.push({file,line:i+1,description:lines[i].trim().slice(0,250)});
}
await mkdir("artifacts/naxa-services-commercial",{recursive:true});
const report={scope:"Static inventory of UI interaction call sites and existing tests. A call site is not a demonstrated end-to-end test.",interactions,copyCandidates,tests};
await writeFile("artifacts/naxa-services-commercial/interaction-inventory.json",JSON.stringify(report,null,2));
const tsv=(rows,keys)=>[keys.join("\t"),...rows.map(r=>keys.map(k=>String(r[k]??"").replace(/[\r\n\t]/g," ")).join("\t"))].join("\n");
await writeFile("artifacts/naxa-services-commercial/interactions.tsv",tsv(interactions,["file","line","column","event","context"]));
await writeFile("artifacts/naxa-services-commercial/copy-review.tsv",tsv(copyCandidates,["file","line","excerpt"]));
await writeFile("artifacts/naxa-services-commercial/test-catalogue.tsv",tsv(tests,["file","line","description"]));
console.log("Commercial audit:",files.length,"UI source files,",interactions.length,"interaction call sites,",copyCandidates.length,"candidate copy lines,",tests.length,"test markers.");
const login=await readFile("apps/web/naxa-services/src/main.tsx","utf8");
for(const forbidden of ["Session Web conservée uniquement","Pas d'inscription libre","Les jetons restent en mémoire","JOURNAL SERVEUR","Connecteur à livrer"])if(login.includes(forbidden))throw new Error("Forbidden customer copy: "+forbidden);
if(interactions.length<100||tests.length<20)throw new Error("Incomplete inventory scope");
