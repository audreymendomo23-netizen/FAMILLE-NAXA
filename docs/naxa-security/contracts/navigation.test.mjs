import assert from "node:assert/strict";import {readFileSync} from "node:fs";import test from "node:test";
const root=new URL("../../../",import.meta.url);
const screens=JSON.parse(readFileSync(new URL("apps/web/naxa-security/src/screens.json",root),"utf8"));
const kt=readFileSync(new URL("apps/android/naxa-security/src/main/java/cm/naxa/naxasecurity/SecurityScreens.kt",root),"utf8");
test("181 unique screens and six bulk counts",()=>{assert.equal(screens.length,181);assert.equal(new Set(screens.map(s=>s.id)).size,181);for(const [b,n] of Object.entries({B1:25,B2:25,B3:30,B4:33,B5:35,B6:33}))assert.equal(screens.filter(s=>s.bulk===b).length,n)});
test("five tabs and exact Android parity",()=>{assert.deepEqual([...new Set(screens.map(s=>s.tab))].sort(),["Accueil","Surveillance","Alertes","Gestion","Profil"].sort());for(const s of screens)assert.ok(kt.includes("SecurityScreen("+[s.id,s.title,s.tab,s.bulk].map(JSON.stringify).join(",")+")"),s.id);assert.equal((kt.match(/SecurityScreen\("/g)||[]).length,181)});
