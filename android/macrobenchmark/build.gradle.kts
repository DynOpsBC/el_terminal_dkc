plugins {
  id("com.android.test") version "8.6.1"
  id("org.jetbrains.kotlin.android") version "2.0.21"
}

android {
  namespace = "com.dynops.bcwms.macrobenchmark"
  compileSdk = 35

  defaultConfig {
    minSdk = 26
    targetSdk = 35
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
  }

  targetProjectPath = ":app"
}

dependencies {
  implementation("androidx.benchmark:benchmark-macro-junit4:1.3.3")
  implementation("androidx.test.ext:junit:1.2.1")
  implementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
