plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

android {
    namespace = "cm.naxa.naxaservices"
    compileSdk = 35

    defaultConfig {
        applicationId = "cm.naxa.naxaservices"
        minSdk = 26
        targetSdk = 35
        versionCode = 2
        versionName = "0.2.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        val authUrl = (project.findProperty("NS_AUTH_FUNCTION_URL") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val anonKey = (project.findProperty("NS_SUPABASE_ANON_KEY") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val referralsUrl = (project.findProperty("NS_REFERRALS_FUNCTION_URL") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val accountingUrl = (project.findProperty("NS_ACCOUNTING_FUNCTION_URL") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "AUTH_FUNCTION_URL", "\"" + authUrl + "\"")
        buildConfigField("String", "REFERRALS_FUNCTION_URL", "\"" + referralsUrl + "\"")
        buildConfigField("String", "ACCOUNTING_FUNCTION_URL", "\"" + accountingUrl + "\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"" + anonKey + "\"")
        val firebaseApiKey = (project.findProperty("NS_FIREBASE_API_KEY") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val firebaseAppId = (project.findProperty("NS_FIREBASE_APP_ID") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val firebaseProjectId = (project.findProperty("NS_FIREBASE_PROJECT_ID") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val firebaseSenderId = (project.findProperty("NS_FIREBASE_SENDER_ID") as? String ?: "")
            .replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "FIREBASE_API_KEY", "\"" + firebaseApiKey + "\"")
        buildConfigField("String", "FIREBASE_APP_ID", "\"" + firebaseAppId + "\"")
        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"" + firebaseProjectId + "\"")
        buildConfigField("String", "FIREBASE_SENDER_ID", "\"" + firebaseSenderId + "\"")
        val supplierSyncEnabled = (project.findProperty("NS_ENABLE_SUPPLIER_SYNC") as? String ?: "false")
            .equals("true", ignoreCase = true)
        buildConfigField("boolean", "SUPPLIER_SYNC_ENABLED", supplierSyncEnabled.toString())
        val configuredProjectRef = (project.findProperty("NS_SUPABASE_PROJECT_REF") as? String ?: "").trim()
            .replace("\\", "\\\\").replace("\"", "\\\"")
        val familyProjectRef = (project.findProperty("NS_FAMILY_SUPABASE_PROJECT_REF") as? String ?: "").trim()
            .replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "SUPABASE_PROJECT_REF", "\"" + configuredProjectRef + "\"")
        buildConfigField("String", "FAMILY_SUPABASE_PROJECT_REF", "\"" + familyProjectRef + "\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    signingConfigs {
        create("naxaRelease") {
            storeFile = file(System.getenv("NAXA_SERVICES_RELEASE_STORE_FILE") ?: "missing-release-key.jks")
            storePassword = System.getenv("NAXA_SERVICES_RELEASE_STORE_PASSWORD") ?: ""
            keyAlias = System.getenv("NAXA_SERVICES_RELEASE_KEY_ALIAS") ?: ""
            keyPassword = System.getenv("NAXA_SERVICES_RELEASE_KEY_PASSWORD") ?: ""
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("naxaRelease")
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    sourceSets["main"].assets.srcDir(file("../../../assets/naxa-services"))
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation(project(":core-android"))
    implementation(platform("com.google.firebase:firebase-bom:35.2.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.room:room-runtime:2.8.5")
    implementation("androidx.room:room-ktx:2.8.5")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    ksp("androidx.room:room-compiler:2.8.5")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core-ktx:1.6.1")
}
