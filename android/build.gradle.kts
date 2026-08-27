plugins {
  alias(libs.plugins.android.application) apply false
  alias(libs.plugins.android.library) apply false
  alias(libs.plugins.kotlin.android) apply false
  alias(libs.plugins.kotlin.compose) apply false
}

// Tum modullerde JVM target = 17 (Java/Kotlin uyumlulugu icin)
subprojects {
  plugins.withId("com.android.application") {
    extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
      compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
      }
    }
  }
  plugins.withId("com.android.library") {
    extensions.configure<com.android.build.api.dsl.LibraryExtension> {
      compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
      }
    }
  }
  tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions {
      jvmTarget = "17"
    }
  }
}
