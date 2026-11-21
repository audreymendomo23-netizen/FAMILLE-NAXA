plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.kapt")
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
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    kapt("androidx.room:room-compiler:2.6.1")
    testImplementation("junit:junit:4.13.2")
}
