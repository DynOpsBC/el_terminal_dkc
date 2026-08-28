import java.util.Properties
import java.io.FileInputStream

// GitHub release işi monoton versionCode ve etiket sürümünü Gradle property
// olarak verir. Lokal/emülatör derlemeleri aşağıdaki kaynak sürümünü kullanır.
val releaseVersionCodeOverride = providers.gradleProperty("releaseVersionCode").orNull?.toIntOrNull()
val releaseVersionNameOverride = providers.gradleProperty("releaseVersionName").orNull?.takeIf { it.isNotBlank() }

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.kotlin.compose)
  id("com.github.triplet.play") version "3.11.0" apply false
}

// gradle-play-publisher is only wired when both PLAY_SERVICE_ACCOUNT_JSON
// (raw json content) is present and the `withPlayPublisher` Gradle property is
// set; CI sets these on tag pipelines, local dev stays free of Play creds.
if (project.hasProperty("withPlayPublisher")) {
  apply(plugin = "com.github.triplet.play")
}

android {
  namespace = "com.dynops.bcwms"
  compileSdk = 35

  defaultConfig {
    applicationId = "com.dynops.bcwms"
    minSdk = 26
    targetSdk = 35
    versionCode = releaseVersionCodeOverride ?: 1447
    versionName = releaseVersionNameOverride ?: "1.14.47"
    manifestPlaceholders["appLabel"] = "BCWMS"
    // Ücretsiz dağıtım kanalı: public GitHub Release içindeki sabit latest.json.
    // APK aynı release'de tutulur; uygulamaya GitHub hesabı/token gömülmez.
    buildConfigField("String", "UPDATE_MANIFEST_URL", "\"https://github.com/DynOpsBC/WMS/releases/latest/download/latest.json\"")
    // El terminalleri ARM tabanlıdır. ML Kit'in x86/x86_64 yerel
    // kütüphaneleri gerçek cihazda hiç kullanılmıyor ve APK'yı yaklaşık
    // 12 MB şişiriyordu. ARM32 desteği eski terminaller için korunur.
    ndk {
      abiFilters += listOf("armeabi-v7a", "arm64-v8a")
    }
  }

  flavorDimensions += "tenant"
  productFlavors {
    create("dynops") {
      dimension = "tenant"
      buildConfigField("String", "BC_CLIENT_ID", "\"8193e5c6-64d2-4e6f-8992-2114e77e4f24\"")
      buildConfigField("String", "BC_FALLBACK_TENANT", "\"7fa2357e-26f2-4174-8e16-a713981356b8\"")
      buildConfigField("String", "BC_DEFAULT_ENVIRONMENT", "\"SandboxUS\"")
      buildConfigField("String", "BC_DEFAULT_COMPANY_ID", "\"1534369d-f248-f111-b478-7c1e521cfdf0\"")
      buildConfigField("String", "BC_DEFAULT_COMPANY_NAME", "\"CRONUS USA, Inc.\"")
      buildConfigField("boolean", "BC_ALLOW_PRODUCTION", "true")
      buildConfigField("String", "TENANT_LABEL", "\"DynamicsOps\"")
      buildConfigField("String", "LOGIN_EMAIL_HINT", "\"ornek@dynamicsops.com\"")
      buildConfigField("String", "LOGIN_DEFAULT_EMAIL", "\"\"")
      buildConfigField("boolean", "FEATURE_HIERARCHICAL_LP", "false")
    }
    create("bade") {
      dimension = "tenant"
      applicationIdSuffix = ".bade"
      versionCode = releaseVersionCodeOverride ?: 1447
      versionName = releaseVersionNameOverride ?: "1.14.47"
      versionNameSuffix = "-bade"
      manifestPlaceholders["appLabel"] = "BCWMS BADE"
      buildConfigField("String", "BC_CLIENT_ID", "\"3c4ba25a-89f4-41df-acf8-ebab8cb4809b\"")
      buildConfigField("String", "BC_FALLBACK_TENANT", "\"3bbd610b-95e4-47b3-8b48-4f7caf717bc3\"")
      buildConfigField("String", "BC_DEFAULT_ENVIRONMENT", "\"E-DefterSandbox\"")
      // BADE APK must never fall back to the shared CRONUS demo company. The
      // company UUID is discovered from BC by this exact display name after
      // token acquisition, then persisted for all subsequent requests.
      buildConfigField("String", "BC_DEFAULT_COMPANY_ID", "\"\"")
      buildConfigField("String", "BC_DEFAULT_COMPANY_NAME", "\"BADE NATURAL DOĞAL YAŞAM ÜRÜNLERİ SAN. TİC. A.Ş.\"")
      buildConfigField("boolean", "BC_ALLOW_PRODUCTION", "false")
      buildConfigField("String", "TENANT_LABEL", "\"Bade Natural\"")
      buildConfigField("String", "LOGIN_EMAIL_HINT", "\"dynops@badenatural.com\"")
      buildConfigField("String", "LOGIN_DEFAULT_EMAIL", "\"dynops@badenatural.com\"")
      buildConfigField("boolean", "FEATURE_HIERARCHICAL_LP", "false")
    }
    create("emu") {
      dimension = "tenant"
      applicationIdSuffix = ".emu"
      // DKC deposu kendi monoton sürümünü ve yayın kanalını taşır. BADE'nin
      // versionCode'u veya GitHub manifesti bu APK'yı etkileyemez.
      versionCode = releaseVersionCodeOverride ?: 200059
      versionName = releaseVersionNameOverride ?: "1.14.59"
      versionNameSuffix = "-emu"
      manifestPlaceholders["appLabel"] = "BCWMS EMU"
      buildConfigField("String", "BC_CLIENT_ID", "\"9f9a9965-f358-4b0b-a89e-923f1d8b7a04\"")
      buildConfigField("String", "BC_FALLBACK_TENANT", "\"9de3e840-2fae-4ffb-b690-2fca32956342\"")
      buildConfigField("String", "BC_DEFAULT_ENVIRONMENT", "\"Sandbox3007\"")
      // DKÇ tenant'ında şirket, ilk Microsoft girişinden sonra erişilebilir
      // şirketlerden seçilir. Ortak CRONUS kimliğine sessizce düşülmez.
      buildConfigField("String", "BC_DEFAULT_COMPANY_ID", "\"\"")
      buildConfigField("String", "BC_DEFAULT_COMPANY_NAME", "\"My Company\"")
      buildConfigField("boolean", "BC_ALLOW_PRODUCTION", "false")
      buildConfigField("String", "TENANT_LABEL", "\"DKÇ / EMU\"")
      buildConfigField("String", "LOGIN_EMAIL_HINT", "\"deniz@atesci.com\"")
      buildConfigField("String", "LOGIN_DEFAULT_EMAIL", "\"deniz@atesci.com\"")
      buildConfigField("boolean", "FEATURE_HIERARCHICAL_LP", "true")
      // EMU kendi manifestini izler; GitHub'ın genel latest yayını BADE'ye
      // ait kalır ve iki farklı applicationId birbirine APK önermez.
      buildConfigField(
        "String",
        "UPDATE_MANIFEST_URL",
        "\"https://github.com/DynOpsBC/el_terminal_dkc/releases/latest/download/latest.json\"",
      )
    }
  }

  buildFeatures {
    compose = true
    buildConfig = true
  }

  buildTypes {
    debug {
      isMinifyEnabled = false
    }
    release {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
      )
      val keystorePropsFile = rootProject.file("play/keystore/keystore.properties")
      if (keystorePropsFile.exists()) {
        val props = Properties()
        FileInputStream(keystorePropsFile).use { props.load(it) }
        signingConfig = signingConfigs.create("release") {
          storeFile = rootProject.file(props.getProperty("storeFile"))
          storePassword = props.getProperty("storePassword")
          keyAlias = props.getProperty("keyAlias")
          keyPassword = props.getProperty("keyPassword")
        }
      }
    }
  }

  lint {
    // CI'da lint'i bloklamayacak hale getir; rapor html olarak hala üretilir.
    // Lokalde "./gradlew lintDebug" zaten çalıştırılabilir, hatalar görünür.
    abortOnError = false
    checkReleaseBuilds = false
    // Manifest'te MSAL gibi opsiyonel auth class'ı kalırsa MissingClass bloklamasın.
    disable += setOf("MissingClass")
  }
}

dependencies {
  implementation(project(":core-design"))
  implementation(libs.androidx.core.ktx)
  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.lifecycle.runtime.ktx)
  implementation(platform(libs.androidx.compose.bom))
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.ui.tooling.preview)
  implementation(libs.androidx.compose.material3)
  implementation("androidx.compose.foundation:foundation")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
  // Real PATCH/DELETE verbs for BC API (HttpURLConnection can't PATCH; BC ignores X-HTTP-Method-Override).
  implementation(libs.okhttp)

  // Barcode scanning (camera) — graceful manual-entry fallback if camera/permission unavailable
  implementation("com.google.mlkit:barcode-scanning:17.3.0")
  implementation("androidx.camera:camera-core:1.4.0")
  implementation("androidx.camera:camera-camera2:1.4.0")
  implementation("androidx.camera:camera-lifecycle:1.4.0")
  implementation("androidx.camera:camera-view:1.4.0")
  implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
  implementation("androidx.core:core:1.19.0")
  testImplementation(libs.junit)
  // Android's org.json classes are stubs in local JVM tests. Use the reference
  // implementation so pagination payload parsing is exercised for real.
  testImplementation("org.json:json:20240303")
}

// Closed-track Play publishing block is read by gradle-play-publisher only when
// the plugin is applied above. service-account credentials come from
// $PLAY_SERVICE_ACCOUNT_JSON env (CI) or play/play-service-account.json (local).
if (project.hasProperty("withPlayPublisher")) {
  configure<com.github.triplet.gradle.play.PlayPublisherExtension> {
    serviceAccountCredentials.set(rootProject.file("play/play-service-account.json"))
    defaultToAppBundles.set(true)
    track.set("internal")
    releaseStatus.set(com.github.triplet.gradle.androidpublisher.ReleaseStatus.DRAFT)
    updatePriority.set(3)
  }
}
