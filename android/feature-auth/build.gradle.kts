plugins {
  alias(libs.plugins.android.library)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.kotlin.compose)
}

android {
  namespace = "com.dynops.bcwms.feature.auth"
  compileSdk = 35
  defaultConfig { minSdk = 26 }
  buildFeatures { compose = true }
}

dependencies {
  implementation(project(":core-auth"))
  implementation(project(":core-domain"))
  implementation(platform(libs.androidx.compose.bom))
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.material3)
  implementation(libs.androidx.lifecycle.viewmodel.compose)
  implementation("androidx.compose.foundation:foundation")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

