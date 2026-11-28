import { mkdir, writeFile, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { existsSync } from "node:fs";
// Mature ZIPPLE must never be regenerated in a working checkout. Legacy CI preview is disposable and read-only.
if (existsSync(join(process.cwd(), "apps/android/zipple/src/main/java/cm/naxa/zipple/ZippleAuth.kt")) && !(process.env.GITHUB_ACTIONS === "true" && process.argv.includes("--legacy-ci-preview"))) {
  console.error("ZIPPLE protected: legacy generator refused before any writes. Use dedicated application gates.");
  process.exit(2);
}


// Only disposable CI preview uses the available stable SDK; real app targets are untouched.
const previewSdk = process.env.GITHUB_ACTIONS === "true" && process.argv.includes("--legacy-ci-preview") ? 36 : 37;
const apps = [
  ["kiosko", "Kiosko", "K"], ["bootik", "Bootik", "B"], ["zipple", "Zipple", "Z"],
  ["naxa-services", "NAXA Services", "NS"], ["cotiz", "CotiZ", "C"],
  ["loyable", "Loyable", "L"], ["naxa-hotel", "NAXA Hotel", "H"],
  ["campus237", "Campus237", "C2"], ["naxa-security", "NAXA Security", "S"],
  ["grillad", "GrillaD", "G"],
];
const files = new Map();
const put = (p, c) => files.set(p, c.endsWith("\n") ? c : c + "\n");
const lines = (a) => a.join("\n") + "\n";
const json = (v) => JSON.stringify(v, null, 2) + "\n";
const nsOf = (id) => "cm.naxa." + id.replaceAll("-", "");
const javaPath = (ns) => ns.split(".").join("/");
const workspace = [
  "packages/contracts", "packages/design-system", "packages/assistant",
  "packages/offline-web", "packages/core-web", "packages/billing-core",
  ...apps.map(([id]) => "apps/web/" + id),
];

put("settings.gradle.kts", lines([
  "pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }",
  "dependencyResolutionManagement {",
  "    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)",
  "    repositories { google(); mavenCentral() }",
  "}",
  'rootProject.name = "FamilleNAXA"',
  "include(" + [":core-android", ...apps.map(([id]) => ":" + id)].map((x) => '"' + x + '"').join(", ") + ")",
  ...apps.map(([id]) => 'project(":' + id + '").projectDir = file("apps/android/' + id + '")'),
  'project(":core-android").projectDir = file("packages/core-android")',
]));
put("build.gradle.kts", lines([
  "plugins {",
  "    alias(libs.plugins.android.application) apply false",
  "    alias(libs.plugins.android.library) apply false",
  "    alias(libs.plugins.kotlin.android) apply false",
  "    alias(libs.plugins.kotlin.compose) apply false",
  "    alias(libs.plugins.kotlin.kapt) apply false",
  "}",
]));
put("gradle.properties", lines([
  "org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8",
  "org.gradle.parallel=true",
  "org.gradle.caching=true",
  "android.useAndroidX=true",
  "kotlin.code.style=official",
  "# AGP 9.3 enables built-in Kotlin; this transitional baseline uses KGP 2.4.21 explicitly.",
  "android.builtInKotlin=false",
  "android.newDsl=false",
]));
put("gradle/libs.versions.toml", lines([
  "[versions]",
  (previewSdk === 36 ? 'agp = "8.10.1"' : 'agp = "9.3.1"'),
  (previewSdk === 36 ? 'kotlin = "2.2.0"' : 'kotlin = "2.4.21"'),
  (previewSdk === 36 ? 'compose-bom = "2025.06.01"' : 'compose-bom = "2026.09.00"'),
  'activity-compose = "1.13.0"',
  'room = "2.8.5"',
  'work-manager = "2.12.0"',
  'core-ktx = "1.15.0"',
  'biometric = "1.1.0"',
  'fragment-ktx = "1.8.5"',
  'security-crypto = "1.1.0-alpha06"',
  'datastore = "1.2.0"',
  'junit = "4.13.2"',
  'androidx-junit = "1.2.1"',
  'espresso = "3.6.1"',
  'ktor = "3.0.3"',
  'supabase = "3.5.0"',
  'camerax = "1.5.1"',
  'mlkit-barcode = "18.3.1"',
  'firebase-messaging = "25.0.0"',
  "",
  "[libraries]",
  "androidx-activity-compose = { module = \"androidx.activity:activity-compose\", version.ref = \"activity-compose\" }",
  "androidx-compose-bom = { module = \"androidx.compose:compose-bom\", version.ref = \"compose-bom\" }",
  "androidx-compose-ui = { module = \"androidx.compose.ui:ui\" }",
  "androidx-compose-material3 = { module = \"androidx.compose.material3:material3\" }",
  "androidx-compose-ui-test-junit4 = { module = \"androidx.compose.ui:ui-test-junit4\" }",
  "androidx-compose-ui-test-manifest = { module = \"androidx.compose.ui:ui-test-manifest\" }",
  "androidx-room-runtime = { module = \"androidx.room:room-runtime\", version.ref = \"room\" }",
  "androidx-room-ktx = { module = \"androidx.room:room-ktx\", version.ref = \"room\" }",
  "androidx-room-compiler = { module = \"androidx.room:room-compiler\", version.ref = \"room\" }",
  "androidx-work-runtime = { module = \"androidx.work:work-runtime-ktx\", version.ref = \"work-manager\" }",
  "androidx-core-ktx = { module = \"androidx.core:core-ktx\", version.ref = \"core-ktx\" }",
  "androidx-biometric = { module = \"androidx.biometric:biometric\", version.ref = \"biometric\" }",
  "androidx-fragment-ktx = { module = \"androidx.fragment:fragment-ktx\", version.ref = \"fragment-ktx\" }",
  "androidx-security-crypto = { module = \"androidx.security:security-crypto\", version.ref = \"security-crypto\" }",
  "androidx-datastore-preferences = { module = \"androidx.datastore:datastore-preferences\", version.ref = \"datastore\" }",
  "junit = { module = \"junit:junit\", version.ref = \"junit\" }",
  "androidx-test-junit = { module = \"androidx.test.ext:junit\", version.ref = \"androidx-junit\" }",
  "androidx-test-espresso = { module = \"androidx.test.espresso:espresso-core\", version.ref = \"espresso\" }",
  "ktor-client-core = { module = \"io.ktor:ktor-client-core\", version.ref = \"ktor\" }",
  "ktor-client-okhttp = { module = \"io.ktor:ktor-client-okhttp\", version.ref = \"ktor\" }",
  "supabase-bom = { module = \"io.github.jan-tennert.supabase:bom\", version.ref = \"supabase\" }",
  "supabase-auth = { module = \"io.github.jan-tennert.supabase:auth-kt\" }",
  "supabase-postgrest = { module = \"io.github.jan-tennert.supabase:postgrest-kt\" }",
  "camerax-camera2 = { module = \"androidx.camera:camera-camera2\", version.ref = \"camerax\" }",
  "camerax-lifecycle = { module = \"androidx.camera:camera-lifecycle\", version.ref = \"camerax\" }",
  "camerax-view = { module = \"androidx.camera:camera-view\", version.ref = \"camerax\" }",
  "mlkit-barcode = { module = \"com.google.android.gms:play-services-mlkit-barcode-scanning\", version.ref = \"mlkit-barcode\" }",
  "firebase-messaging = { module = \"com.google.firebase:firebase-messaging\", version.ref = \"firebase-messaging\" }",
  "",
  "[plugins]",
  "android-application = { id = \"com.android.application\", version.ref = \"agp\" }",
  "android-library = { id = \"com.android.library\", version.ref = \"agp\" }",
  "kotlin-android = { id = \"org.jetbrains.kotlin.android\", version.ref = \"kotlin\" }",
  "kotlin-compose = { id = \"org.jetbrains.kotlin.plugin.compose\", version.ref = \"kotlin\" }",
  "kotlin-kapt = { id = \"org.jetbrains.kotlin.kapt\", version.ref = \"kotlin\" }",
]));
put("gradle/wrapper/gradle-wrapper.properties", lines([
  "distributionBase=GRADLE_USER_HOME",
  "distributionPath=wrapper/dists",
  "distributionUrl=https\\://services.gradle.org/distributions/gradle-" + (previewSdk === 36 ? "8.11.1" : "9.5.0") + "-bin.zip",
  ...(previewSdk === 36 ? [] : ["distributionSha256Sum=553c78f50dafcd54d65b9a444649057857469edf836431389695608536d6b746"]),
  "networkTimeout=10000",
  "validateDistributionUrl=true",
  "zipStoreBase=GRADLE_USER_HOME",
  "zipStorePath=wrapper/dists",
]));
put("pnpm-workspace.yaml", "packages:\n" + workspace.map((p) => "  - " + p).join("\n") + "\n\nallowBuilds:\n  esbuild: true\n");
put(".npmrc", "engine-strict=true\nstrict-peer-dependencies=false\nauto-install-peers=true\n");
put(".gitignore", lines([
  "node_modules/", ".pnpm-store/", ".next/", "out/", "dist/", "coverage/",
  "playwright-report/", "test-results/", ".gradle/", "**/build/", "local.properties",
  "*.iml", ".idea/", ".DS_Store", ".env", ".env.*", "!.env.example", "public/sw.js",
  "*.tsbuildinfo",
]));
put("package.json", json({
  name: "famille-naxa", private: true, packageManager: "pnpm@12.21.0",
  engines: { node: ">=22.15.0" },
  scripts: {
    "build:web": "pnpm --workspace-concurrency=2 --filter './apps/web/*' -r build",
    "typecheck:web": "pnpm --workspace-concurrency=2 --filter './apps/web/*' -r typecheck",
    "test:contracts": "pnpm --filter @famille/contracts test",
    "test:assistant": "pnpm --filter @famille/assistant-rules test",
    "test:core-web": "pnpm --filter @naxa/core-web test",
    "test:billing": "pnpm --filter @famille/billing-core test",
    "test:design-system": "node --test packages/design-system/test/contrast.test.js",
    "test:e2e": "playwright test",
  },
  devDependencies: { "@axe-core/playwright": "4.14.0", "@playwright/test": "1.65.0" },
}));
put("playwright.config.ts", lines([
  'import { defineConfig, devices } from "@playwright/test";',
  "export default defineConfig({",
  '  testDir: "./tests/e2e", fullyParallel: true, forbidOnly: Boolean(process.env.CI),',
  "  retries: process.env.CI ? 1 : 0, reporter: process.env.CI ? \"github\" : \"list\",",
  '  use: { baseURL: "http://127.0.0.1:4173", trace: "retain-on-failure", ...devices["Desktop Chrome"] },',
  "  webServer: {",
  '    command: "pnpm --filter @famille/kiosko-web exec next start --hostname 127.0.0.1 --port 4173",',
  '    url: "http://127.0.0.1:4173", reuseExistingServer: !process.env.CI, timeout: 120_000, stdout: \"pipe\", stderr: \"pipe\",',
  "  },",
  "});",
]));
put("tests/e2e/app-shell.spec.ts", lines([
  'import { test, expect } from "@playwright/test";',
  'import AxeBuilder from "@axe-core/playwright";',
  'test("Kiosko publishes its shell and PWA manifest", async ({ page, request }) => {',
  '  await page.goto("/");',
  '  await expect(page.getByRole("main")).toBeVisible();',
  '  await expect(page.getByRole("heading", { level: 1, name: "Kiosko" })).toBeVisible();',
  '  const response = await request.get("/manifest.webmanifest");',
  "  expect(response.ok()).toBeTruthy();",
  "  const manifest = await response.json();",
  '  expect(manifest.name).toBe("Kiosko");',
  '  expect(manifest.display).toBe("standalone");',
  '  expect(manifest.icons.some((icon: { src: string }) => icon.src === "/icons/app.svg")).toBeTruthy();',
  "});",
  'test("Kiosko shell has no automated WCAG 2.1 A/AA violations", async ({ page }) => {',
  '  await page.goto("/");',
  '  const result = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"]).analyze();',
  "  expect(result.violations).toEqual([]);",
  "});",
]));

put("packages/core-android/build.gradle.kts", lines([
  "plugins { alias(libs.plugins.android.library); alias(libs.plugins.kotlin.android) }",
  "android {",
  '    namespace = "cm.naxa.core"',
  "    compileSdk = " + previewSdk,
  "    defaultConfig { minSdk = 26 }",
  "    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }",
  '    kotlinOptions { jvmTarget = "17" }',
  "}",
  "dependencies {",
  "    implementation(libs.androidx.core.ktx)",
  "    implementation(libs.androidx.work.runtime)",
  "    implementation(libs.androidx.biometric)",
  "    implementation(libs.androidx.fragment.ktx)",
  "    implementation(libs.androidx.security.crypto)",
  "    implementation(libs.androidx.datastore.preferences)",
  "}",
]));
put("packages/core-android/src/main/res/values/strings.xml", lines([
  '<?xml version="1.0" encoding="utf-8"?>', "<resources>",
  '<string name="notification_critical">Critical</string>',
  '<string name="notification_operations">Operations</string>',
  '<string name="notification_subscription">Subscription</string>',
  '<string name="notification_information">Information</string>',
  '<string name="notification_ai_coaching">AI coaching</string>',
  '<string name="biometric_title">Famille NAXA</string>',
  '<string name="biometric_subtitle">Unlock this device</string>',
  '<string name="biometric_use_pin">Use local PIN</string>',
  '<string name="biometric_failed">Biometric verification failed</string>',
  "</resources>",
]));
put("packages/core-android/src/main/res/values-fr/strings.xml", lines([
  '<?xml version="1.0" encoding="utf-8"?>', "<resources>",
  '<string name="notification_critical">Critique</string>',
  '<string name="notification_operations">Opérations</string>',
  '<string name="notification_subscription">Abonnement</string>',
  '<string name="notification_information">Information</string>',
  '<string name="notification_ai_coaching">Coaching IA</string>',
  '<string name="biometric_title">Famille NAXA</string>',
  '<string name="biometric_subtitle">Déverrouiller cet appareil</string>',
  '<string name="biometric_use_pin">Utiliser le code PIN local</string>',
  '<string name="biometric_failed">Échec de la vérification biométrique</string>',
  "</resources>",
]));
put("packages/core-android/src/main/java/cm/naxa/core/notifications/NotificationChannels.kt", lines([
  "package cm.naxa.core.notifications",
  "import android.Manifest",
  "import android.app.NotificationChannel",
  "import android.app.NotificationManager",
  "import android.app.PendingIntent",
  "import android.content.Context",
  "import android.content.pm.PackageManager",
  "import android.os.Build",
  "import androidx.core.app.NotificationCompat",
  "import androidx.core.app.NotificationManagerCompat",
  "import androidx.core.content.ContextCompat",
  "import cm.naxa.core.R",
  "object NotificationChannels {",
  '    const val CRITICAL = "critical"',
  '    const val OPERATIONS = "operations"',
  '    const val SUBSCRIPTION = "subscription"',
  '    const val INFORMATION = "information"',
  '    const val AI_COACHING = "ai_coaching"',
  "    fun create(context: Context) {",
  "        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {",
  "            val manager = context.getSystemService(NotificationManager::class.java)",
  "            manager.createNotificationChannels(listOf(",
  "                NotificationChannel(CRITICAL, context.getString(R.string.notification_critical), NotificationManager.IMPORTANCE_HIGH),",
  "                NotificationChannel(OPERATIONS, context.getString(R.string.notification_operations), NotificationManager.IMPORTANCE_DEFAULT),",
  "                NotificationChannel(SUBSCRIPTION, context.getString(R.string.notification_subscription), NotificationManager.IMPORTANCE_HIGH),",
  "                NotificationChannel(INFORMATION, context.getString(R.string.notification_information), NotificationManager.IMPORTANCE_LOW),",
  "                NotificationChannel(AI_COACHING, context.getString(R.string.notification_ai_coaching), NotificationManager.IMPORTANCE_DEFAULT),",
  "            ))",
  "        }",
  "    }",
  "    fun post(context: Context, channel: String, id: Int, title: String, body: String, smallIcon: Int, intent: PendingIntent? = null): Boolean {",
  "        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false",
  "        return try {",
  "            val builder = NotificationCompat.Builder(context, channel).setSmallIcon(smallIcon).setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)).setAutoCancel(true)",
  "            if (intent != null) builder.setContentIntent(intent)",
  "            NotificationManagerCompat.from(context).notify(id, builder.build())",
  "            true",
  "        } catch (_: SecurityException) { false }",
  "    }",
  "}",
]));
put("packages/core-android/src/main/java/cm/naxa/core/security/BiometricGate.kt", lines([
  "package cm.naxa.core.security",
  "import androidx.biometric.BiometricManager",
  "import androidx.biometric.BiometricPrompt",
  "import androidx.core.content.ContextCompat",
  "import androidx.fragment.app.FragmentActivity",
  "import cm.naxa.core.R",
  "object BiometricGate {",
  "    fun available(activity: FragmentActivity): Boolean = BiometricManager.from(activity).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS",
  "    fun prompt(activity: FragmentActivity, onSuccess: () -> Unit, onFailure: (String) -> Unit) {",
  "        val executor = ContextCompat.getMainExecutor(activity)",
  "        val prompt = BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {",
  "            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) { onSuccess() }",
  "            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) { onFailure(errString.toString()) }",
  "            override fun onAuthenticationFailed() { onFailure(activity.getString(R.string.biometric_failed)) }",
  "        })",
  "        prompt.authenticate(BiometricPrompt.PromptInfo.Builder()",
  "            .setTitle(activity.getString(R.string.biometric_title))",
  "            .setSubtitle(activity.getString(R.string.biometric_subtitle))",
  "            .setNegativeButtonText(activity.getString(R.string.biometric_use_pin))",
  "            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)",
  "            .build())",
  "    }",
  "}",
]));

for (const [id, label, acronym] of apps) {
  const ns = nsOf(id);
  const androidDir = "apps/android/" + id;
  const webDir = "apps/web/" + id;
  put(androidDir + "/build.gradle.kts", lines([
    "plugins {",
    "    alias(libs.plugins.android.application)",
    "    alias(libs.plugins.kotlin.android)",
    "    alias(libs.plugins.kotlin.compose)",
    "    alias(libs.plugins.kotlin.kapt)",
    "}",
    "android {",
    '    namespace = "' + ns + '"',
    "    compileSdk = " + previewSdk,
    "    defaultConfig {",
    '        applicationId = "' + ns + '"',
    "        minSdk = 26",
    "        targetSdk = " + previewSdk,
    "        versionCode = 1",
    '        versionName = "0.1.0"',
    ...(id === "naxa-security" ? ['        buildConfigField("String", "SECURITY_PUBLISHABLE_KEY", "\\"\\"")'] : []),
    '        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"',
    "    }",
    "    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }",
    '    kotlinOptions { jvmTarget = "17" }',
    id === "naxa-security" ? "    buildFeatures { compose = true; buildConfig = true }" : "    buildFeatures { compose = true }",
    '    buildTypes { getByName("release") { isMinifyEnabled = false } }',
    "}",
    "dependencies {",
    '    implementation(project(":core-android"))',
    "    implementation(platform(libs.androidx.compose.bom))",
    "    implementation(libs.androidx.activity.compose)",
    "    implementation(libs.androidx.compose.ui)",
    "    implementation(libs.androidx.compose.material3)",
    "    implementation(libs.androidx.room.runtime)",
    "    implementation(libs.androidx.room.ktx)",
    "    implementation(libs.androidx.datastore.preferences)",
    "    kapt(libs.androidx.room.compiler)",
    "    testImplementation(libs.junit)",
    "    androidTestImplementation(libs.androidx.test.junit)",
    "    androidTestImplementation(libs.androidx.test.espresso)",
    "    androidTestImplementation(platform(libs.androidx.compose.bom))",
    "    androidTestImplementation(libs.androidx.compose.ui.test.junit4)",
    "    debugImplementation(libs.androidx.compose.ui.test.manifest)",
    "}",
  ]));
  put(androidDir + "/src/main/AndroidManifest.xml", lines([
    '<?xml version="1.0" encoding="utf-8"?>',
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
    '    <uses-permission android:name="android.permission.INTERNET" />',
    "    <application android:allowBackup=\"false\" android:icon=\"@drawable/ic_launcher\" android:label=\"@string/app_name\" android:supportsRtl=\"true\" android:theme=\"@style/Theme.FamilleNAXA\">",
    '        <activity android:name=".MainActivity" android:exported="true">',
    "            <intent-filter>",
    '                <action android:name="android.intent.action.MAIN" />',
    '                <category android:name="android.intent.category.LAUNCHER" />',
    "            </intent-filter>",
    "        </activity>",
    "    </application>",
    "</manifest>",
  ]));
  put(androidDir + "/src/main/res/drawable/ic_launcher.xml", lines([
    '<?xml version="1.0" encoding="utf-8"?>',
    '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="48dp" android:height="48dp" android:viewportWidth="48" android:viewportHeight="48">',
    '    <path android:fillColor="#174C3C" android:pathData="M0,0h48v48h-48z" />',
    '    <path android:fillColor="#FFFFFF" android:pathData="M10,36V12h6l16,16V12h6v24h-6L16,20v16z" />',
    "</vector>",
  ]));
  put(androidDir + "/src/main/res/values/strings.xml", lines([
    '<?xml version="1.0" encoding="utf-8"?>', "<resources>",
    "    <string name=\"app_name\">" + label + "</string>",
    '    <string name="foundation_status">Socle technique initialisé.</string>',
    "</resources>",
  ]));
  put(androidDir + "/src/main/res/values-en/strings.xml", lines([
    '<?xml version="1.0" encoding="utf-8"?>', "<resources>",
    "    <string name=\"app_name\">" + label + "</string>",
    '    <string name="foundation_status">Technical foundation initialized.</string>',
    "</resources>",
  ]));
  put(androidDir + "/src/main/res/values/styles.xml", lines([
    '<?xml version="1.0" encoding="utf-8"?>', "<resources>",
    '    <style name="Theme.FamilleNAXA" parent="android:style/Theme.Material.Light.NoActionBar">',
    '        <item name="android:fontFamily">sans</item>',
    '        <item name="android:windowLightStatusBar">true</item>',
    "    </style>",
    "</resources>",
  ]));
  put(androidDir + "/src/main/java/" + javaPath(ns) + "/AppIdentity.kt", lines([
    "package " + ns, "",
    "object AppIdentity {",
    '    const val ID = "' + id + '"',
    "}",
  ]));
  put(androidDir + "/src/main/java/" + javaPath(ns) + "/MainActivity.kt", lines([
    "package " + ns, "",
    "import android.os.Bundle",
    "import androidx.activity.ComponentActivity",
    "import androidx.activity.compose.setContent",
    "import androidx.compose.foundation.layout.Arrangement",
    "import androidx.compose.foundation.layout.Column",
    "import androidx.compose.foundation.layout.Spacer",
    "import androidx.compose.foundation.layout.fillMaxSize",
    "import androidx.compose.foundation.layout.height",
    "import androidx.compose.foundation.layout.padding",
    "import androidx.compose.material3.MaterialTheme",
    "import androidx.compose.material3.Surface",
    "import androidx.compose.material3.Text",
    "import androidx.compose.ui.Modifier",
    "import androidx.compose.ui.res.stringResource",
    "import androidx.compose.ui.unit.dp",
    "import " + ns + ".R",
    "",
    "class MainActivity : ComponentActivity() {",
    "    override fun onCreate(savedInstanceState: Bundle?) {",
    "        super.onCreate(savedInstanceState)",
    "        setContent {",
    "            MaterialTheme {",
    "                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {",
    "                    Column(modifier = Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {",
    "                        Text(text = stringResource(R.string.app_name), style = MaterialTheme.typography.headlineLarge)",
    "                        Spacer(modifier = Modifier.height(12.dp))",
    "                        Text(text = stringResource(R.string.foundation_status), style = MaterialTheme.typography.bodyLarge)",
    "                    }",
    "                }",
    "            }",
    "        }",
    "    }",
    "}",
  ]));
  put(androidDir + "/src/main/java/" + javaPath(ns) + "/OfflineQueue.kt", lines([
    "package " + ns, "",
    "import androidx.room.Dao",
    "import androidx.room.Database",
    "import androidx.room.Entity",
    "import androidx.room.Insert",
    "import androidx.room.OnConflictStrategy",
    "import androidx.room.PrimaryKey",
    "import androidx.room.Query",
    "import androidx.room.RoomDatabase",
    "",
    '@Entity(tableName = "offline_events")',
    "data class OfflineEvent(",
    "    @PrimaryKey val eventId: String,",
    "    val appId: String,",
    "    val aggregateType: String,",
    "    val payloadJson: String,",
    "    val deviceSequence: Long,",
    "    val createdAtEpochMs: Long,",
    '    val state: String = "queued",',
    ")",
    "",
    "@Dao interface OfflineEventDao {",
    "    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun enqueue(event: OfflineEvent): Long",
    '    @Query("SELECT * FROM offline_events WHERE state = \'queued\' ORDER BY deviceSequence")',
    "    suspend fun queued(): List<OfflineEvent>",
    '    @Query("UPDATE offline_events SET state = :state WHERE eventId = :eventId")',
    "    suspend fun updateState(eventId: String, state: String): Int",
    "}",
    "",
    "@Database(entities = [OfflineEvent::class], version = 1, exportSchema = false)",
    "abstract class OfflineQueueDb : RoomDatabase() { abstract fun events(): OfflineEventDao }",
  ]));
  put(androidDir + "/src/test/java/" + javaPath(ns) + "/AppIdentityTest.kt", lines([
    "package " + ns, "",
    "import org.junit.Assert.assertEquals",
    "import org.junit.Test",
    "",
    "class AppIdentityTest {",
    '    @Test fun applicationIdIsStable() { assertEquals("' + id + '", AppIdentity.ID) }',
    "}",
  ]));
  put(androidDir + "/src/androidTest/java/" + javaPath(ns) + "/AppShellInstrumentedTest.kt", lines([
    "package " + ns, "",
    "import androidx.compose.ui.test.assertIsDisplayed",
    "import androidx.compose.ui.test.junit4.createAndroidComposeRule",
    "import androidx.compose.ui.test.onNodeWithText",
    "import androidx.test.ext.junit.runners.AndroidJUnit4",
    "import org.junit.Rule",
    "import org.junit.Test",
    "import org.junit.runner.RunWith",
    "",
    "@RunWith(AndroidJUnit4::class)",
    "class AppShellInstrumentedTest {",
    "    @get:Rule val composeRule = createAndroidComposeRule<MainActivity>()",
    "    @Test fun productNameIsVisible() {",
    "        val name = composeRule.activity.getString(R.string.app_name)",
    "        composeRule.onNodeWithText(name).assertIsDisplayed()",
    "    }",
    "}",
  ]));

  put(webDir + "/package.json", json({
    name: "@famille/" + id + "-web", version: "0.1.0", private: true, type: "module",
    scripts: { dev: "next dev", build: "next build && serwist build", start: "next start", typecheck: "tsc --noEmit" },
    dependencies: { "@famille/design-system": "workspace:*", next: "16.4.6", react: "19.3.0", "react-dom": "19.3.0" },
    devDependencies: {
      "@serwist/cli": "9.5.13", "@serwist/next": "9.5.13",
      "@types/node": "22.19.1", "@types/react": "19.2.7", "@types/react-dom": "19.2.3",
      concurrently: "9.2.1", esbuild: "0.27.2", serwist: "9.5.13", typescript: "5.9.3",
    },
  }));
  put(webDir + "/next.config.ts", lines([
    'import type { NextConfig } from "next";',
    "const nextConfig: NextConfig = { poweredByHeader: false, reactStrictMode: true, transpilePackages: [\"@famille/design-system\"] };",
    "export default nextConfig;",
  ]));
  put(webDir + "/tsconfig.json", json({
    compilerOptions: {
      target: "ES2022", lib: ["dom", "dom.iterable", "esnext"], allowJs: false,
      skipLibCheck: true, strict: true, noEmit: true, esModuleInterop: true,
      module: "esnext", moduleResolution: "bundler", resolveJsonModule: true,
      isolatedModules: true, jsx: "preserve", incremental: true,
      plugins: [{ name: "next" }], types: ["node", "@serwist/next/typings"],
    },
    include: ["next-env.d.ts", ".next/types/**/*.ts", "**/*.ts", "**/*.tsx"],
    exclude: ["node_modules"],
  }));
  put(webDir + "/next-env.d.ts", '/// <reference types="next" />\n/// <reference types="next/image-types/global" />\n');
  put(webDir + "/serwist.config.js", lines([
    'import { serwist } from "@serwist/next/config";',
    "export default serwist({ swSrc: \"app/sw.ts\", swDest: \"public/sw.js\", precachePrerendered: false });",
  ]));
  put(webDir + "/app/sw.ts", lines([
    '/// <reference lib="esnext" />',
    '/// <reference lib="webworker" />',
    'import type { PrecacheEntry, SerwistGlobalConfig } from "serwist";',
    'import { Serwist } from "serwist";',
    "declare global { interface WorkerGlobalScope extends SerwistGlobalConfig { __SW_MANIFEST: (PrecacheEntry | string)[] | undefined; } }",
    "declare const self: ServiceWorkerGlobalScope;",
    "const serwist = new Serwist({ precacheEntries: self.__SW_MANIFEST, skipWaiting: true, clientsClaim: true, navigationPreload: true, runtimeCaching: [] });",
    "serwist.addEventListeners();",
  ]));
  put(webDir + "/app/layout.tsx", lines([
    'import "@famille/design-system/tokens.css";',
    'import { SerwistProvider } from "@serwist/next/react";',
    'import type { Metadata, Viewport } from "next";',
    'import type { ReactNode } from "react";',
    'import "./globals.css";',
    "const appName = " + JSON.stringify(label) + ";",
    "export const metadata: Metadata = {",
    "  applicationName: appName, title: { default: appName, template: \"%s | \" + appName },",
    "  description: appName + \" — application Famille NAXA.\", manifest: \"/manifest.webmanifest\",",
    "  appleWebApp: { capable: true, statusBarStyle: \"default\", title: appName }, formatDetection: { telephone: false },",
    "};",
    "export const viewport: Viewport = { themeColor: \"#174c3c\", width: \"device-width\", initialScale: 1 };",
    "export default function RootLayout({ children }: { children: ReactNode }) {",
    "  return <html lang=\"fr\"><body><SerwistProvider swUrl=\"/sw.js\" disable={process.env.NODE_ENV === \"development\"}>{children}</SerwistProvider></body></html>;",
    "}",
  ]));
  put(webDir + "/app/manifest.ts", lines([
    'import type { MetadataRoute } from "next";',
    "export default function manifest(): MetadataRoute.Manifest { return {",
    "  name: " + JSON.stringify(label) + ", short_name: " + JSON.stringify(label) + ",",
    "  description: " + JSON.stringify(label + " — application Famille NAXA.") + ",",
    '  start_url: "/", scope: "/", display: "standalone", background_color: "#FFFFFF", theme_color: "#174c3c",',
    '  icons: [{ src: "/icons/app.svg", sizes: "any", type: "image/svg+xml", purpose: "any" }],',
    "}; }",
  ]));
  put(webDir + "/app/copy.ts", lines([
    "export const appCopy = {",
    "  fr: { title: " + JSON.stringify(label) + ', status: "Socle technique initialisé." },',
    "  en: { title: " + JSON.stringify(label) + ', status: "Technical foundation initialized." },',
    "} as const;",
  ]));
  put(webDir + "/app/page.tsx", lines([
    'import { appCopy } from "./copy";',
    "export default function HomePage() { const copy = appCopy.fr; return (",
    '<main className="app-shell" aria-labelledby="app-title">',
    '<p className="eyebrow">FAMILLE NAXA</p>',
    '<h1 id="app-title">{copy.title}</h1><p className="status">{copy.status}</p>',
    "</main>); }",
  ]));
  put(webDir + "/app/globals.css", lines([
    ":root { color-scheme: light; } html, body { min-height: 100%; }",
    "body { margin: 0; background: var(--naxa-surface, #fff); color: var(--naxa-text, #202522); }",
    ".app-shell { box-sizing: border-box; max-width: 64rem; min-height: 100svh; margin: 0 auto; padding: clamp(1.5rem, 5vw, 4rem); display: flex; flex-direction: column; justify-content: center; }",
    ".eyebrow { margin: 0 0 1rem; font-size: .75rem; font-weight: 700; letter-spacing: .12em; }",
    "h1 { margin: 0; font-size: clamp(2rem, 6vw, 4rem); line-height: 1.1; }",
    ".status { margin-top: 1rem; max-width: 42rem; line-height: 1.6; }",
    ":focus-visible { outline: 3px solid #174c3c; outline-offset: 3px; }",
    "@media (prefers-reduced-motion: reduce) { *, *::before, *::after { scroll-behavior: auto !important; animation-duration: .01ms !important; transition-duration: .01ms !important; } }",
  ]));
  put(webDir + "/public/icons/app.svg", lines([
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="' + label + '">',
    ' <rect width="512" height="512" rx="112" fill="#174c3c"/>',
    ' <circle cx="256" cy="256" r="172" fill="none" stroke="#fff" stroke-width="16" opacity=".22"/>',
    ' <text x="256" y="316" text-anchor="middle" font-family="Arial, sans-serif" font-size="' + (acronym.length > 1 ? "142" : "220") + '" font-weight="700" fill="#fff">' + acronym + "</text>",
    "</svg>",
  ]));

  await rm(join(webDir, "src/main.tsx"), { force: true });
  for (const oldFile of ["index.html", "vite.config.ts", "public/sw.js", "serwist.config.mjs"]) {
    await rm(join(webDir, oldFile), { force: true });
  }
}

// Retire generated Gradle binaries previously committed into the repository.
await rm("packages/core-android/build", { recursive: true, force: true });
for (const [path, content] of files) {
  const target = join(process.cwd(), path);
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, content, "utf8");
}
console.log("Generated " + files.size + " files for the approved Prompt 0.1 stack (10 native Android modules + 10 Next.js/PWA apps).");
