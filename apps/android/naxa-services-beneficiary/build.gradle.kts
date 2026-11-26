plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "cm.naxa.services.beneficiary"
    compileSdk = 35
    defaultConfig {
        applicationId = "cm.naxa.services.beneficiary"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        fun setting(name: String): String = (project.findProperty(name) as? String ?: "").replace("\\", "\\\\").replace("\"", "\\\"")
        buildConfigField("String", "AUTH_ENDPOINT", "\"" + setting("NS_AUTH_FUNCTION_URL") + "\"")
        buildConfigField("String", "ANON_KEY", "\"" + setting("NS_SUPABASE_ANON_KEY") + "\"")
        buildConfigField("String", "PROJECT_REF", "\"" + setting("NS_SUPABASE_PROJECT_REF") + "\"")
        buildConfigField("String", "FAMILY_PROJECT_REF", "\"" + setting("NS_FAMILY_SUPABASE_PROJECT_REF") + "\"")
    }
    buildFeatures { buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    testImplementation("junit:junit:4.13.2")
}
