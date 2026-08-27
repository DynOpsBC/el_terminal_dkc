pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
  }
}

rootProject.name = "BCWMSApp"

// Aktif derleme: yalnız :app ve onun tek bağımlılığı :core-design.
// :core-auth / :core-domain / :feature-auth yalnızca İNAKTİF scaffold
// modüllerince (feature-pick, feature-ship, …) kullanılıyor; bunlar zaten
// derlemeye dahil değil. Include listesinde tutulmaları her derlemede
// gereksiz yapılandırma + build çıktısı üretiyordu.
include(":app", ":core-design")
