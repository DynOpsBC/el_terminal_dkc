plugins {
  alias(libs.plugins.android.library)
  alias(libs.plugins.kotlin.android)
}

android {
  namespace = "com.dynops.bcwms.core.auth"
  compileSdk = 35
  defaultConfig { minSdk = 26 }
}

dependencies {
  // MSAL ve EncryptedSharedPreferences gerçek production'da; demo için gerek yok
}
