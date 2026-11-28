import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync,readdirSync} from "node:fs";
import {fileURLToPath} from "node:url";
import {join} from "node:path";
const web=fileURLToPath(new URL(".",import.meta.url));
const android=fileURLToPath(new URL("../../../android/widemeet/src/main/java/cm/naxa/widemeet/",import.meta.url));
function walk(root){return readdirSync(root,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(join(root,e.name)):[join(root,e.name)]);}
const banned=/limite de recette|test limit:|observations SFU|SFU samples|présences non qualifiées|attendance not qualified|mode hautement confidentiel non qualifié|highly confidential mode not qualified|qualification Android supplémentaire|additional Android qualification|sur environnement qualifié|qualified environment\)|configuration WideMeet indisponible|WideMeet configuration unavailable|chiffrement de bout en bout qualifié|qualified end-to-end encryption|la console centrale nécessite une intégration|central administration requires a dedicated integration|simulation d’intention|test intent — no transfer|créer une intention de test|create test intent|décisions et actions candidates|candidate decisions and actions|annotation humaine, révision|human annotation, revision|sélection extractive|extractive selection|configuration appliquée|configuration applied|plafond demandé|requested ceiling/i;
test("commercial UI copy excludes known development references in French and English",()=>{for(const f of [...walk(web).filter(f=>f.endsWith(".tsx")),...walk(android).filter(f=>f.endsWith(".kt"))])assert.doesNotMatch(readFileSync(f,"utf8"),banned,f);});
test("commercial subscription screens never invoke simulated payment actions",()=>{for(const f of [join(web,"IdentityPanel.tsx"),join(android,"IdentityPanel.kt")]){const source=readFileSync(f,"utf8");assert.doesNotMatch(source,/["']billing-(?:list|cancel)["']/);assert.doesNotMatch(source,/mutate\(["']billing-create["']/);assert.match(source,/Paiement en ligne momentanément indisponible/);}});
