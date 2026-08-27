plugins {
  alias(libs.plugins.android.library)
  alias(libs.plugins.kotlin.android)
}

android {
  namespace = "com.dynops.bcwms.db"
  compileSdk = 35
  defaultConfig { minSdk = 26 }
}

dependencies {
  implementation(libs.room.runtime)
  implementation(libs.room.ktx)
  implementation(libs.sqlcipher)
  implementation(libs.work.runtime.ktx)
}
