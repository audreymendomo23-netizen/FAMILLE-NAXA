import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
const apps = [["kiosko","Kiosko"],["bootik","Bootik"],["zipple","Zipple"],["naxa-services","NAXA Services"],["cotiz","CotiZ"],["loyable","Loyable"],["naxa-hotel","NAXA Hotel"],["campus237","Campus237"],["naxa-security","NAXA Security"],["grillad","GrillaD"]];
const files = new Map(); const put=(p,c)=>files.set(p,c);
put("settings.gradle.kts", `pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }\ndependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }\nrootProject.name = "FamilleNAXA"\ninclude(":core-android", ${apps.map(([id])=>`":${id}"`).join(", ")})\n\n${apps.map(([id])=>`project(":${id}").projectDir = file("apps/android/${id}")`).join("\n")}\nproject(":core-android").projectDir = file("packages/core-android")`);
put("build.gradle.kts", `plugins { id("com.android.application") version "8.6.1" apply false; id("com.android.library") version "8.6.1" apply false; id("org.jetbrains.kotlin.android") version "2.0.20" apply false; id("org.jetbrains.kotlin.plugin.compose") version "2.0.20" apply false; id("org.jetbrains.kotlin.kapt") version "2.0.20" apply false }\n`);
put("gradle.properties","org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8\nandroid.useAndroidX=true\nkotlin.code.style=official\n");
put("package.json",JSON.stringify({name:"famille-naxa",private:true,workspaces:["packages/contracts","packages/design-system","packages/assistant","packages/offline-web","packages/core-web","packages/billing-core","apps/web/*"],scripts:{"build:web":"npm run build --workspaces --if-present","test:contracts":"npm test --workspace @famille/contracts","test:assistant":"npm test --workspace @famille/assistant-rules","test:core-web":"npm test --workspace @naxa/core-web","test:billing":"npm test --workspace @famille/billing-core"}},null,2));
put("tsconfig.base.json",JSON.stringify({compilerOptions:{target:"ES2022",module:"ESNext",moduleResolution:"Bundler",strict:true,skipLibCheck:true,noEmit:true,jsx:"react-jsx"}},null,2));
put("packages/contracts/package.json",JSON.stringify({name:"@famille/contracts",version:"0.1.0",private:true,type:"module",exports:{".":"./src/index.ts"},scripts:{test:"vitest run"},devDependencies:{typescript:"^5.6.3",vitest:"^2.1.4"}},null,2));
put("packages/contracts/src/index.ts", `export type AppId = ${apps.map(([id])=>`"${id}"`).join(" | ")};\nexport type DomainKind="catalog"|"profile"|"inventory"|"sale"|"payment"|"subscription"|"booking"|"delivery"|"security";\nexport type ConflictDecision="accept"|"manual_review"|"compensate";\nexport function decideConflict(kind:DomainKind,expected:number,actual:number):ConflictDecision{if(expected===actual)return "accept";if(["sale","payment","subscription"].includes(kind))return "manual_review";if(kind==="inventory")return "compensate";return "manual_review"}\nexport type PaymentState="declared"|"captured"|"submitted"|"verified"|"rejected"|"reversed";\nexport type NotificationState="created"|"queued"|"sent"|"received"|"read"|"actioned"|"failed";\nexport interface SyncEnvelope<T=unknown>{eventId:string;appId:AppId;organizationId:string;locationId?:string;actorId:string;deviceId:string;aggregateType:DomainKind;aggregateId:string;aggregateVersion:number;deviceSequence:number;occurredAt:string;schemaVersion:1;payload:T}\n`);
put("packages/contracts/src/index.test.ts",`import {it,expect} from "vitest";import {decideConflict} from "./index";it("requires review for financial conflicts",()=>expect(decideConflict("payment",1,2)).toBe("manual_review"));it("compensates stock conflicts",()=>expect(decideConflict("inventory",1,2)).toBe("compensate"));`);
put("packages/design-system/package.json",JSON.stringify({name:"@famille/design-system",version:"0.1.0",private:true,exports:{"./tokens.css":"./src/tokens.css"}},null,2));
put("packages/design-system/src/tokens.css", ":root{--naxa-brand:#174c3c;--naxa-accent:#e3a72f;--naxa-surface:#fff;--naxa-text:#17211d;--naxa-success:#197A33;--naxa-danger:#C62828;--naxa-warning:#8F5400;--naxa-link:#003D99;font-family:Montserrat,Poppins,Nunito,system-ui,sans-serif;color-scheme:light}\n[data-app=\"kiosko\"]{--naxa-brand:#0D2E57;--naxa-accent:#89B255}\n[data-app=\"bootik\"]{--naxa-brand:#052163;--naxa-accent:#FC7820}\n[data-app=\"zipple\"]{--naxa-brand:#0E224D;--naxa-accent:#F56202}\n[data-app=\"naxa-services\"]{--naxa-brand:#111111;--naxa-accent:#DD3A33;--naxa-surface:#111111;--naxa-text:#FFFFFF;color-scheme:dark}\n[data-app=\"cotiz\"]{--naxa-brand:#012952;--naxa-accent:#018A44;--naxa-red:#D81224;--naxa-yellow:#FDCC1D}\n[data-app=\"loyable\"]{--naxa-brand:#002C98;--naxa-accent:#FD6213}\n[data-app=\"naxa-hotel\"]{--naxa-brand:#2058F4;--naxa-accent:#FDA601}\n[data-theme=\"dark\"]{--naxa-surface:#151b18;--naxa-text:#f2f5f3;color-scheme:dark}\nbody{margin:0;background:var(--naxa-surface);color:var(--naxa-text);font-family:Montserrat,Poppins,Nunito,system-ui,sans-serif}\na{color:var(--naxa-link)}button{min-height:44px}\n@media(prefers-reduced-motion:reduce){*,*::before,*::after{scroll-behavior:auto!important;animation-duration:.01ms!important;transition-duration:.01ms!important}}\n/* Three later app palettes are pending validation; no colors are invented. */");
put("packages/assistant/package.json",JSON.stringify({name:"@famille/assistant-rules",version:"0.1.0",private:true,type:"module",exports:{".":"./src/index.ts"},scripts:{test:"vitest run"},devDependencies:{vitest:"^2.1.4"}},null,2));
put("packages/assistant/src/index.ts", `export interface Signal { key:string; value:number; threshold:number; explanation:string }
export interface Recommendation { status:"review"|"ok"; reasons:string[]; requiresHumanDecision:true }
export function explainSignals(signals:Signal[]):Recommendation { const reasons=signals.filter(s=>s.value>s.threshold).map(s=>s.explanation); return {status:reasons.length?"review":"ok",reasons,re​​quiresHumanDecision:true} }`.replace("re​​quires","requires"));
put("packages/assistant/src/index.test.ts", `import {it,expect} from "vitest";import {explainSignals} from "./index";it("explains anomalies and leaves the decision to a human",()=>expect(explainSignals([{key:"late",value:4,threshold:2,explanation:"Retard à examiner"}])).toEqual({status:"review",reasons:["Retard à examiner"],requiresHumanDecision:true}));`);
put("apps/web/admin-console/package.json",JSON.stringify({name:"@famille/admin-console",version:"0.1.0",private:true,type:"module",scripts:{build:"vite build",dev:"vite --host 0.0.0.0"},dependencies:{"@famille/contracts":"file:../../../packages/contracts","@famille/design-system":"file:../../../packages/design-system","@famille/offline-web":"file:../../../packages/offline-web",react:"^18.3.1","react-dom":"^18.3.1"},devDependencies:{"@vitejs/plugin-react":"^4.3.3",vite:"^5.4.10",typescript:"^5.6.3","@types/react":"^18.3.12","@types/react-dom":"^18.3.1"}},null,2));
put("apps/web/admin-console/index.html",`<!doctype html><html lang="fr"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><link rel="manifest" href="/manifest.webmanifest"/><title>Administration Famille NAXA</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>`);
put("apps/web/admin-console/manifest.webmanifest",JSON.stringify({name:"Administration Famille NAXA",short_name:"Admin NAXA",start_url:"/",display:"standalone",theme_color:"#174c3c",lang:"fr"}));
put("apps/web/admin-console/vite.config.ts",`import {defineConfig} from "vite";import react from "@vitejs/plugin-react";export default defineConfig({plugins:[react()]});`);
put("apps/web/admin-console/src/main.tsx",`import React from "react";import{createRoot}from"react-dom/client";import"@famille/design-system/tokens.css";if("serviceWorker" in navigator){window.addEventListener("load",()=>navigator.serviceWorker.register("/sw.js").catch(()=>{}))}function App(){return <main><h1>Administration Famille NAXA</h1><p>Console Web initialisée. MFA, droits, journaux et workflows doivent être intégrés avant usage opérationnel.</p></main>}createRoot(document.getElementById("root")!).render(<React.StrictMode><App/></React.StrictMode>);`);
for(const [id,label] of apps){const pkg="cm.naxa."+id.replaceAll("-","");put("apps/android/"+id+"/build.gradle.kts",`plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("org.jetbrains.kotlin.plugin.compose"); id("org.jetbrains.kotlin.kapt") }\nandroid { namespace="${pkg}"; compileSdk=35; defaultConfig { applicationId="${pkg}"; minSdk=26; targetSdk=35; versionCode=1; versionName="0.1.0" }; compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }; kotlinOptions { jvmTarget="17" }; buildFeatures { compose=true } }\ndependencies { implementation(platform("androidx.compose:compose-bom:2024.10.01")); implementation("androidx.activity:activity-compose:1.9.3"); implementation("androidx.compose.ui:ui"); implementation("androidx.compose.material3:material3"); implementation(project(":core-android")); implementation("androidx.room:room-runtime:2.6.1"); implementation("androidx.room:room-ktx:2.6.1"); kapt("androidx.room:room-compiler:2.6.1") }`);put("apps/android/"+id+"/src/main/AndroidManifest.xml",`<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="${label}" android:allowBackup="false" android:theme="@android:style/Theme.Material.Light.NoActionBar"><activity android:name=".MainActivity" android:exported="true"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>`);put("apps/android/"+id+"/src/main/java/"+pkg.replaceAll(".","/")+"/MainActivity.kt",`package ${pkg}\nimport android.os.Bundle\nimport androidx.activity.ComponentActivity\nimport androidx.activity.compose.setContent\nimport androidx.compose.material3.*\nimport androidx.compose.foundation.layout.*\nimport androidx.compose.ui.Modifier\nimport androidx.compose.ui.unit.dp\nclass MainActivity:ComponentActivity(){override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{MaterialTheme{Column(Modifier.fillMaxSize().padding(24.dp)){Text("${label}",style=MaterialTheme.typography.headlineMedium);Text("Socle natif Famille NAXA — parcours métier à intégrer.")}}}}}`);put("apps/android/"+id+"/src/main/java/"+pkg.replaceAll(".","/")+"/OfflineQueue.kt", `package ${pkg}
import androidx.room.*
@Entity(tableName="offline_events")
data class OfflineEvent(@PrimaryKey val eventId:String,val appId:String,val aggregateType:String,val payloadJson:String,val deviceSequence:Long,val createdAtEpochMs:Long,val state:String="queued")
@Dao interface OfflineEventDao {
 @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun enqueue(event:OfflineEvent):Long
 @Query("SELECT * FROM offline_events WHERE state='queued' ORDER BY deviceSequence") suspend fun queued():List<OfflineEvent>
 @Query("UPDATE offline_events SET state=:state WHERE eventId=:eventId") suspend fun updateState(eventId:String,state:String):Int
}
@Database(entities=[OfflineEvent::class],version=1,exportSchema=false)
abstract class OfflineQueueDb:RoomDatabase(){abstract fun events():OfflineEventDao}
`);
put("packages/offline-web/package.json",JSON.stringify({name:"@famille/offline-web",version:"0.1.0",private:true,type:"module",exports:{".":"./src/index.ts"}},null,2));
put("packages/offline-web/src/index.ts", `export type QueueState="queued"|"sending"|"acknowledged"|"conflict"|"rejected";export interface QueueItem{eventId:string;payload:string;state:QueueState;createdAt:number}
const DB="famille-naxa-offline";const STORE="events";function openDb():Promise<IDBDatabase>{return new Promise((resolve,reject)=>{const request=indexedDB.open(DB,1);request.onupgradeneeded=()=>request.result.createObjectStore(STORE,{keyPath:"eventId"});request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)})}
export async function enqueue(item:QueueItem):Promise<void>{const db=await openDb();await new Promise<void>((resolve,reject)=>{const tx=db.transaction(STORE,"readwrite");tx.objectStore(STORE).put(item);tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error)});db.close()}
export async function listQueued():Promise<QueueItem[]>{const db=await openDb();const result=await new Promise<QueueItem[]>((resolve,reject)=>{const r=db.transaction(STORE).objectStore(STORE).getAll();r.onsuccess=()=>resolve((r.result as QueueItem[]).filter(x=>x.state==="queued"));r.onerror=()=>reject(r.error)});db.close();return result}
export async function setQueueState(eventId:string,state:QueueState):Promise<void>{const db=await openDb();await new Promise<void>((resolve,reject)=>{const tx=db.transaction(STORE,"readwrite");const store=tx.objectStore(STORE);const r=store.get(eventId);r.onsuccess=()=>{if(r.result)store.put({...r.result,state})};tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error)});db.close()}
`);
put("apps/android/"+id+"/src/main/java/"+pkg.replaceAll(".","/")+"/OfflineQueue.kt", `package ${pkg}
import androidx.room.*
@Entity(tableName="offline_events")
data class OfflineEvent(@PrimaryKey val eventId:String,val appId:String,val aggregateType:String,val payloadJson:String,val deviceSequence:Long,val createdAtEpochMs:Long,val state:String="queued")
@Dao interface OfflineEventDao {
 @Insert(onConflict=OnConflictStrategy.IGNORE) suspend fun enqueue(event:OfflineEvent):Long
 @Query("SELECT * FROM offline_events WHERE state='queued' ORDER BY deviceSequence") suspend fun queued():List<OfflineEvent>
 @Query("UPDATE offline_events SET state=:state WHERE eventId=:eventId") suspend fun updateState(eventId:String,state:String):Int
}
@Database(entities=[OfflineEvent::class],version=1,exportSchema=false)
abstract class OfflineQueueDb:RoomDatabase(){abstract fun events():OfflineEventDao}
`);
put("apps/web/"+id+"/package.json",JSON.stringify({name:"@famille/"+id+"-web",version:"0.1.0",private:true,type:"module",scripts:{build:"vite build",dev:"vite --host 0.0.0.0"},dependencies:{"@famille/contracts":"file:../../../packages/contracts","@famille/design-system":"file:../../../packages/design-system",react:"^18.3.1","react-dom":"^18.3.1"},devDependencies:{"@vitejs/plugin-react":"^4.3.3",vite:"^5.4.10",typescript:"^5.6.3","@types/react":"^18.3.12","@types/react-dom":"^18.3.1"}},null,2));put("apps/web/"+id+"/public/sw.js", `const CACHE="famille-shell-v1";self.addEventListener("install",e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(["/","/manifest.webmanifest"]))));self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))));self.addEventListener("fetch",e=>{const u=new URL(e.request.url);if(e.request.method==="GET"&&u.origin===self.location.origin&&(u.pathname.startsWith("/assets/")||u.pathname==="/manifest.webmanifest"))e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request).then(r=>{if(r.ok){const copy=r.clone();caches.open(CACHE).then(c=>c.put(e.request,copy))}return r}).catch(()=>caches.match("/"))))});`);
put("apps/web/"+id+"/index.html",`<!doctype html><html lang="fr"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><link rel="manifest" href="/manifest.webmanifest"/><title>${label}</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>`);put("apps/web/"+id+"/manifest.webmanifest",JSON.stringify({name:label,short_name:label,start_url:"/",display:"standalone",theme_color:"#174c3c",lang:"fr"}));put("apps/web/"+id+"/vite.config.ts",`import {defineConfig} from "vite";import react from "@vitejs/plugin-react";export default defineConfig({plugins:[react()]});`);put("apps/web/"+id+"/src/main.tsx",`import React from "react";import{createRoot}from"react-dom/client";import"@famille/design-system/tokens.css";if("serviceWorker" in navigator){window.addEventListener("load",()=>navigator.serviceWorker.register("/sw.js").catch(()=>{}))}document.documentElement.dataset.app="${id}";function App(){return <main><h1>${label}</h1><p>Socle Web responsive et PWA Famille NAXA.</p></main>}createRoot(document.getElementById("root")!).render(<React.StrictMode><App/></React.StrictMode>);`);}
put("infra/SECURITY_BASELINE.md", "# Sécurité transversale\nBackend Supabase NAXA partagé. Auth et ressources métier canoniques. Aucun service_role dans les clients. Contrôle serveur app/organisation/lieu/acteur/statut/abonnement. Capture SMS/notification distincte de vérification indépendante. Aucune migration réelle exécutée par ce générateur.\n");
put("infra/RELEASE_MANIFEST.md", "# Distribution\nAPK hors Play Store. Avant publication : artefact signé, SHA-256 artefact et certificat, version minimale, manifeste signé, vérification côté serveur et procédure de révocation. Aucun artefact n’est publié par ce générateur.\n");

put("packages/core-android/build.gradle.kts", `plugins { id("com.android.library"); id("org.jetbrains.kotlin.android") }
android { namespace="cm.naxa.core"; compileSdk=35; defaultConfig { minSdk=26 }; compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }; kotlinOptions { jvmTarget="17" } }
dependencies { implementation("androidx.core:core-ktx:1.15.0"); implementation("androidx.work:work-runtime-ktx:2.9.1") }`);
put("packages/core-android/src/main/AndroidManifest.xml", `<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.POST_NOTIFICATIONS"/></manifest>`);
put("packages/core-android/src/main/java/cm/naxa/core/notifications/NotificationChannels.kt", `package cm.naxa.core.notifications
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
object NotificationChannels {
 const val CRITICAL="critical"; const val OPERATIONS="operations"; const val SUBSCRIPTION="subscription"; const val INFORMATION="information"; const val AI_COACHING="ai_coaching"
 fun create(context:Context) { if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.O) { val m=context.getSystemService(NotificationManager::class.java); m.createNotificationChannels(listOf(NotificationChannel(CRITICAL,"Critique",NotificationManager.IMPORTANCE_HIGH),NotificationChannel(OPERATIONS,"Opérations",NotificationManager.IMPORTANCE_DEFAULT),NotificationChannel(SUBSCRIPTION,"Abonnement",NotificationManager.IMPORTANCE_HIGH),NotificationChannel(INFORMATION,"Information",NotificationManager.IMPORTANCE_LOW),NotificationChannel(AI_COACHING,"Coaching IA",NotificationManager.IMPORTANCE_DEFAULT))) } }
 fun post(context:Context,channel:String,id:Int,title:String,body:String,smallIcon:Int,intent:PendingIntent?=null):Boolean { if(Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(context,Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return false; return try { val b=NotificationCompat.Builder(context,channel).setSmallIcon(smallIcon).setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)).setAutoCancel(true); if(intent!=null)b.setContentIntent(intent); NotificationManagerCompat.from(context).notify(id,b.build()); true } catch(_:SecurityException){false} }
}
`);
put("packages/core-android/src/main/java/cm/naxa/core/notifications/BriefingScheduler.kt", `package cm.naxa.core.notifications
import android.content.Context
import androidx.work.*
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.concurrent.TimeUnit
object BriefingScheduler {
 fun schedule(context:Context,hour:Int,minute:Int,title:String,body:String,iconRes:Int,channel:String=NotificationChannels.OPERATIONS,replace:Boolean=true) {
  require(hour in 0..23 && minute in 0..59)
  val now=LocalDateTime.now(); var next=now.toLocalDate().atTime(LocalTime.of(hour,minute)); if(!next.isAfter(now))next=next.plusDays(1)
  val data=workDataOf("title" to title,"body" to body,"icon" to iconRes,"channel" to channel,"hour" to hour,"minute" to minute)
  val request=OneTimeWorkRequestBuilder<BriefingWorker>().setInputData(data).setInitialDelay(Duration.between(now,next).toMillis().coerceAtLeast(0),TimeUnit.MILLISECONDS).build()
  val name="naxa-briefing-$channel"; val manager=WorkManager.getInstance(context); if(replace)manager.cancelUniqueWork(name)
  manager.enqueueUniqueWork(name,if(replace)ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.APPEND_OR_REPLACE,request)
 }
}
`);
put("packages/core-android/src/main/java/cm/naxa/core/notifications/BriefingWorker.kt", `package cm.naxa.core.notifications
import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
class BriefingWorker(context:Context,params:WorkerParameters):Worker(context,params) {
 override fun doWork():Result {
  val title=inputData.getString("title")?:return Result.failure(); val body=inputData.getString("body")?:return Result.failure()
  val icon=inputData.getInt("icon",0); val channel=inputData.getString("channel")?:NotificationChannels.OPERATIONS
  val hour=inputData.getInt("hour",7); val minute=inputData.getInt("minute",0)
  if(icon!=0)NotificationChannels.post(applicationContext,channel,channel.hashCode(),title,body,icon)
  BriefingScheduler.schedule(applicationContext,hour,minute,title,body,icon,channel,replace=false)
  return Result.success()
 }
}
`);
put("packages/billing-core/package.json",JSON.stringify({name:"@famille/billing-core",version:"0.1.0",private:true,type:"module",scripts:{test:"node --test"},engines:{node:">=20"}},null,2));
put("packages/billing-core/src/index.js", `export function validateMonthlyPrice(v){if(!Number.isSafeInteger(v)||v<0)throw new RangeError("invalid_fcfa_amount");return v}
export function roundDownToHundred(v){if(!Number.isSafeInteger(v)||v<0)throw new RangeError("invalid_fcfa_amount");return Math.floor(v/100)*100}
export function packagePrice(monthly,months){validateMonthlyPrice(monthly);if(months===3)return roundDownToHundred(Math.floor(monthly*27/10));if(months===6)return monthly*5;if(months===12)return monthly*10;throw new RangeError("unsupported_package")}
export function upgradeProrata(oldPrice,newPrice,days){validateMonthlyPrice(oldPrice);validateMonthlyPrice(newPrice);if(!Number.isInteger(days)||days<0||days>30)throw new RangeError("invalid_remaining_days");if(newPrice<=oldPrice||days===0)return 0;return Math.max(100,Math.round((newPrice-oldPrice)*days/30))}
export function giftMonthsAllowed(used,requested){for(const n of [used,requested])if(!Number.isSafeInteger(n)||n<0)throw new RangeError("invalid_gift_months");return Math.max(0,Math.min(requested,3-used))}
export function provisionalAccessUntil(now,alreadyGranted){if(!(now instanceof Date)||Number.isNaN(now.getTime()))throw new TypeError("invalid_date");return alreadyGranted?null:new Date(now.getTime()+86400000)}
`);
put("packages/billing-core/test/billing.test.js", `import test from "node:test";import assert from "node:assert/strict";import {packagePrice,upgradeProrata,giftMonthsAllowed,provisionalAccessUntil} from "../src/index.js";
test("3-month offer discounted 10%, rounded down to 100 FCFA",()=>assert.equal(packagePrice(1150,3),3100));
test("6 and 12 months charge 5 and 10 months",()=>{assert.equal(packagePrice(1000,6),5000);assert.equal(packagePrice(1000,12),10000)});
test("upgrade example 1000 to 3000 with 15 days left",()=>assert.equal(upgradeProrata(1000,3000,15),1000));
test("upgrade minimum is 100 FCFA",()=>assert.equal(upgradeProrata(1000,1001,1),100));
test("gift ceiling is 3 months per year",()=>{assert.equal(giftMonthsAllowed(0,2),2);assert.equal(giftMonthsAllowed(2,2),1);assert.equal(giftMonthsAllowed(3,1),0)});
test("24-hour provisional access can be issued only once",()=>{const d=new Date("2026-11-14T10:00:00Z");assert.equal(provisionalAccessUntil(d,true),null);assert.equal(provisionalAccessUntil(d,false).toISOString(),"2026-11-15T10:00:00.000Z")});
`);
for(const [path,body] of files){const target=join(process.cwd(),path);await mkdir(dirname(target),{recursive:true});await writeFile(target,body,"utf8");}
console.log("Generated "+files.size+" source files: 10 native Android modules, 10 responsive Web/PWA targets and shared contracts.");