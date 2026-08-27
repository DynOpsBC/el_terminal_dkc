# Sprint 0 — Foundations (2 hafta)

## Hedef

Üç platformun (AL, Android, Web) iskeletini kur; sandbox'a placeholder `.app` deploy edip MSAL ile Android'den login round-trip'ini doğrula. Hiçbir iş mantığı bu sprint'te yazılmaz — sadece iskelet, toolchain ve CI.

## Demo Kriterleri

1. Sandbox `CustomerSandbox`'a placeholder `.app` yüklendi, `Demo Business Central` company'sinde Setup Wizard tile'ı görünüyor.
2. Android APK debug build başarılı, cihazda açılıyor, MSAL ile login oluyor, BC API'den `companies` listesini çekip ekranda gösteriyor.
3. Üç GitHub Actions workflow (`al-build`, `android-build`, `web-build`) main branch'te yeşil.

## AL İş Paketleri

### Proje kökü

- `al/app.json` — publisher=`DynOps`, name=`BCWMSApp`, idRanges=[{from:72000,to:72099}], platform=`24.0.0.0`, runtime=`13.0`, application=`24.0.0.0`, features=`["TranslationFile","NoImplicitWith"]`, supportedCountries=`["TR","US","DE"]`, resourceExposurePolicy={allowDebugging:true,allowDownloadingSource:false,includeSourceInSymbolFile:false}, dependencies=`[{Base Application Microsoft 24.0.0.0}]`
- `al/.vscode/launch.json` — type=`al`, environmentType=`Sandbox`, environmentName=`CustomerSandbox`, tenant=`7fa2357e-26f2-4174-8e16-a713981356b8`, schemaUpdateMode=`ForceSync`
- `al/.vscode/settings.json` — `al.enableCodeAnalysis=true`, codeAnalyzers=AppSourceCop+CodeCop+UICop+PerTenantExtensionCop
- `al/.gitignore` — `.alpackages/`, `.alcache/`, `.netpackages/`, `*.app`, `rad.json`, `*.g.xlf`
- `al/.alpackages/` — symbol cache, gitignored

### Setup (singleton)

- `al/src/Setup/Setup.Table.al` (T 72000) — `DOPSWHS Setup` singleton, OnInsert kontrolü, alanlar: `Primary Key`, `LP No. Series`, `SSCC No. Series`, `GS1 Company Prefix`, `Default Location`, `Print Channel` enum, `PrintNode API Key Set` boolean
- `al/src/Setup/Setup.Page.al` (P 72061) — Card
- `al/src/Setup/SetupWizard.Codeunit.al` (CU 72031) — `OnRegisterAssistedSetup` subscribe (codeunit 3725 `Assisted Setup`); page=`Setup`, group=`AdminGuidedSetup`

### Permission Sets

- `al/src/Permissions/AdminPermissionSet.al` (PS 72094) — `DOPSWHS-ADMIN` — tüm DOPSWHS objelerine RIMD + setup
- `al/src/Permissions/UserPermissionSet.al` (PS 72095) — `DOPSWHS-USER` — transactional only
- `al/src/Permissions/ViewPermissionSet.al` (PS 72096) — `DOPSWHS-VIEW` — read-only

### Telemetri + Install/Upgrade

- `al/src/Telemetry/Telemetry.Codeunit.al` (CU 72032) — `Log(category, message, verbosity, dims)` wrapper; tüm `Session.LogMessage` çağrıları buradan
- `al/src/Telemetry/TelemetryBuffer.Table.al` (T 72024) — async telemetry için ring buffer
- `al/src/Upgrade/Install.Codeunit.al` (CU 72033) — OnInstall trigger, ilk Setup row insert
- `al/src/Upgrade/Upgrade.Codeunit.al` (CU 72034) — OnUpgrade trigger placeholder
- `al/src/Permissions/PermissionHelper.Codeunit.al` (CU 72035) — runtime permission checks

### Test app

- `al/tests/app.json` — ayrı app, dependency=BCWMSApp ana app, idRanges=[{72090,72099}], `test`: `5.0.0.0`
- `al/tests/src/Setup/SetupTests.Codeunit.al` — `[Test] CannotInsertSecondSetupRow()`, `[Test] WizardCreatesNoSeries()`
- `al/tests/src/TestHelper.Codeunit.al` (CU 72057) — common test fixtures

## Android İş Paketleri

### Gradle yapısı

- `android/settings.gradle.kts` — 22 modül tanımı (`:app`, 7 `:core-*`, 14 `:feature-*`)
- `android/build.gradle.kts` — root, plugin DSL
- `android/gradle/libs.versions.toml` — kotlin=2.0.21, agp=8.6.1, compose-bom=2024.10.01, ktor=3.0.1, hilt=2.52, room=2.6.1, msal=5.0.0, mlkit-barcode=17.3.0, camerax=1.4.0, datawedge-intent=8.x, work=2.10
- `android/gradle.properties` — `org.gradle.jvmargs=-Xmx4g`, AndroidX, Kotlin compose
- `android/.gitignore` — `.gradle/`, `build/`, `local.properties`, `*.apk`, `*.keystore`

### `:app` ana modülü

- `android/app/build.gradle.kts` — applicationId=`com.dynops.bcwms`, minSdk=26, targetSdk=35, compileSdk=35, signing configs
- `android/app/src/main/AndroidManifest.xml` — permissions, DataWedge intent filter, MSAL redirect activity
- `android/app/src/main/java/com/dynops/bcwms/BcwmsApplication.kt` — Hilt entry, Firebase init, MSAL config init
- `android/app/src/main/java/com/dynops/bcwms/MainActivity.kt` — single-activity, Compose host, edge-to-edge

### `:core-network`

- `BcApiClient.kt` — Ktor `HttpClient` with `ContentNegotiation`, `Auth bearer`, base URL builder
- `interceptors/AuthInterceptor.kt` — MSAL'dan token alır, header ekler
- `interceptors/ETagInterceptor.kt` — 412 conflict surfacing
- `error/BcApiException.kt` + `ProblemDetails.kt`

### `:core-auth`

- `MsalAuthClient.kt` — PKCE acquire/refresh; sandbox tenant configurable
- `TokenStore.kt` — `EncryptedSharedPreferences` + Android Keystore
- `AuthState.kt` — sealed class
- `ProfileStore.kt` — connection profile (tenant/env/company/deviceConfig)

### `:core-db`

- `BcwmsDatabase.kt` — Room + SQLCipher (`net.zetetic:android-database-sqlcipher`)
- `KeyProvider.kt` — Keystore-backed passphrase
- `SyncQueueDao.kt` + `SyncOpEntity.kt`

### `:feature-auth`

- `LoginScreen.kt` — Compose; MSAL launch button; loading state
- `ConnectionProfileScreen.kt` — manuel input + QR import (CameraX + ML Kit)
- `AuthViewModel.kt` — MVI

## Web İş Paketleri (placeholder)

- `web/package.json` — vite=5.x, react=19.x, typescript=5.6, vitest
- `web/vite.config.ts` — `build.outDir` `../al/src/ControlAddIn/Resources/` (ileride 2 addin için ayrı entry'ler)
- `web/tsconfig.json`
- `web/index.html` — AL host stub
- `web/src/main.tsx` — boş bootstrap

## Push Relay (skeleton)

- `push-relay/host.json` — extension bundle `[4.*, 5.0.0)`
- `push-relay/package.json` — `@azure/functions`, `@azure/signalr`, `firebase-admin`, `axios`
- `push-relay/tsconfig.json`
- `push-relay/webhook/function.json` + `index.ts` (HTTP trigger placeholder, sadece 200 döner)
- `push-relay/infra/main.bicep` — Function App + SignalR Service + Key Vault + App Insights iskeleti

## CI/CD İş Paketleri

- `.github/workflows/al-build.yml` — Windows runner, AL compile (.app artifact)
- `.github/workflows/android-build.yml` — Ubuntu, `./gradlew lintDebug testDebugUnitTest assembleDebug`
- `.github/workflows/web-build.yml` — Ubuntu, `pnpm typecheck && pnpm build`
- `.github/workflows/dependabot.yml`
- GitHub secrets oluştur: `BC_SANDBOX_TENANT_ID`, `BC_SANDBOX_USER`, `BC_SANDBOX_PASSWORD`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`

## Dokümantasyon İş Paketleri

- `README.md` — proje girişi, hızlı başlangıç (clone → al compile → android build)
- `CLAUDE.md` — AI ajan davranış kuralları: prefix=DOPSWHS, sandbox URL, hangi testlerin çalıştırılacağı, hangi konvansiyonların izleneceği
- `docs/AdvWMS-Technical-Spec.md` — ekteki spec
- `docs/AdvWMS-Architecture.svg` — mimari diyagram
- `docs/setup-runbook.md` — sandbox'a ilk install adımları
- `docs/al-coding-standards.md`
- `docs/android-coding-standards.md`
- `docs/i18n-glossary.md` — terim sözlüğü Sprint 1 için hazır
- `docs/release-notes/sprint-0.md` — bitişte yazılacak

## Paralel Dış Bağımlılıklar

| İş | Sahip | Bitiş hedefi |
|---|---|---|
| Microsoft PartnerSource: ID range `72000-72499` talebi | denizcelan | Sprint 1 başı |
| Azure AD app registration (mobile public + web confidential) | denizcelan | Sprint 0 sonu |
| Sandbox kullanıcısına `DOPSWHS-ADMIN` permission | denizcelan | Sprint 0 sonu |

## Gün-Gün İş Dağılımı (10 iş günü)

| Gün | İş |
|---|---|
| 1 | Repo init, `.gitignore`, `README.md`, `CLAUDE.md`, dizin iskeleti |
| 1 | Azure AD app registration (paralel) |
| 2 | `al/app.json`, `launch.json`, sandbox bağlantı testi |
| 2 | Setup table + page + wizard + 3 PermissionSet + Telemetry CU |
| 3 | Install/Upgrade CU + Test app skeleton + ilk AL test |
| 3 | AL compile + sandbox publish smoke testi |
| 4 | `android/settings.gradle.kts`, `libs.versions.toml`, 22 modül skeleton |
| 4 | `:core-network`, `:core-auth`, `:core-db` temel sınıflar |
| 5 | `:feature-auth` Login + ConnectionProfile (QR import) |
| 5 | MSAL ile sandbox login round-trip → `companies` endpoint çek |
| 6 | `web/` Vite skeleton + AL ControlAddIn resource hedef path |
| 6 | 3 GitHub Actions workflow + secrets |
| 7 | `push-relay/` skeleton + `infra/main.bicep` |
| 7 | Secrets registry GH Actions'a |
| 8 | `docs/` zorunlu dosyalar |
| 8 | Spec ve mimari diyagram repo'ya kopyalanır |
| 9 | Sprint 0 demo prep: placeholder `.app` install + Android login |
| 9 | İlk `git commit` + uzak repo push |
| 10 | Sprint 0 retro + Sprint 1 backlog grooming |

## Bitiş Kriterleri (DoD)

- [ ] Üç GitHub Actions workflow main'de yeşil
- [ ] `.app` sandbox'a yüklendi, Assisted Setup tile görünüyor, "Run Setup Wizard" basit bir sayfa açıyor
- [ ] Android APK debug build cihazda açılıyor, MSAL ile login, `companies` listesi görünüyor
- [ ] AL test (`SetupTests`) çalışıyor, AppSourceCop warning=0
- [ ] Repo GitHub'a push edildi
- [ ] `docs/release-notes/sprint-0.md` demo notu mevcut
