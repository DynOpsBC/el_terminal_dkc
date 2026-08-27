plugins {
  alias(libs.plugins.android.library)
  alias(libs.plugins.kotlin.android)
}

android {
  namespace = "com.dynops.bcwms.printer"
  compileSdk = 35
  defaultConfig { minSdk = 26 }
}
