plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("org.jetbrains.kotlin.plugin.compose"); id("org.jetbrains.kotlin.kapt") }
android { namespace="cm.naxa.zipple"; compileSdk=35; defaultConfig { applicationId="cm.naxa.zipple"; minSdk=26; testInstrumentationRunner="androidx.test.runner.AndroidJUnitRunner"; targetSdk=35; versionCode=1; versionName="0.1.0"; buildConfigField("String","ZIPPLE_API_URL","\""+(providers.gradleProperty("ZIPPLE_API_URL").orNull ?: "")+"\""); buildConfigField("String","ZIPPLE_BUSINESS_API_URL","\""+(providers.gradleProperty("ZIPPLE_BUSINESS_API_URL").orNull ?: "")+"\"") }; compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }; kotlinOptions { jvmTarget="17" }; buildFeatures { compose=true; buildConfig=true } }
dependencies { implementation(platform("androidx.compose:compose-bom:2024.10.01")); implementation("androidx.activity:activity-compose:1.9.3"); implementation("androidx.compose.ui:ui"); implementation("androidx.compose.material3:material3"); implementation(project(":core-android")); implementation("com.google.zxing:core:3.5.3"); implementation("androidx.room:room-runtime:2.6.1"); implementation("androidx.room:room-ktx:2.6.1"); kapt("androidx.room:room-compiler:2.6.1") }
dependencies { testImplementation("junit:junit:4.13.2"); implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1") }

dependencies { implementation("androidx.fragment:fragment-ktx:1.8.5") }

dependencies { implementation("androidx.work:work-runtime-ktx:2.9.1") }

dependencies { androidTestImplementation(platform("androidx.compose:compose-bom:2024.10.01")); androidTestImplementation("androidx.compose.ui:ui-test-junit4"); androidTestImplementation("androidx.test.ext:junit:1.2.1"); androidTestImplementation("androidx.test:runner:1.6.2"); debugImplementation("androidx.compose.ui:ui-test-manifest") }

dependencies { implementation("com.google.mlkit:text-recognition:16.0.1") }
