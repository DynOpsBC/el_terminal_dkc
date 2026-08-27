# Sprint H — Hardening + AppSource RC (2 hafta)

## Hedef

v1.0-rc1 etiketi atıldıktan sonra production-shipping kalitesine getir: Microsoft AppSource technical validation, Play Store Internal track yükleme, performans sertleştirme, battery profiling, contract test'lerin CI'ya bağlanması, UI automation. Bu sprint sonunda **AppSource submission** yapılır ve **Play Store closed testing** açılır.

## Demo Kriterleri

1. `bcwmsapp.app` AppSource submission portal'ına yüklendi → otomatik validation rapor 0 critical.
2. Android APK Play Store internal track'e push edildi → 5 internal tester davet edildi → cihaz Zebra TC22'de 8 saat / 1500 scan battery testi ≤60% düşüş.
3. CI nightly contract test (Newman) sandbox'ta yeşil — tüm 50+ endpoint smoke geçti.
4. UI-Automator instrumented test sandbox'ta nightly yeşil.
5. Application Insights KQL dashboard 4 panel canlı veri çekiyor.
6. Crashlytics v1.0-rc1 build için 0 crash.
7. `v1.0` git tag atılır → GitHub Release otomatik oluşur (.app + .apk + web-bundle.zip + push-relay.zip).

## AL Hardening İş Paketleri

### AppSource validation checklist (60+ madde)

- [ ] **Permission sets** tüm yeni object'leri kapsıyor (otomatik audit script `tools/audit-permissions.sh`)
- [ ] **Permission entitlements** doğru (her PS için BC standart role mapping)
- [ ] **Translations** — tüm string'ler `.xlf`'te, kaynak dil en-US, hedefler tr-TR/de-DE
- [ ] **Logo** — 240x240 PNG `al/Logo.png`, app.json'da referans
- [ ] **Documentation URL** gerçek (`https://docs.dynops.com/bcwmsapp/`)
- [ ] **Support email** gerçek (`support@dynops.com`)
- [ ] **Privacy URL** gerçek
- [ ] **License URL** gerçek
- [ ] **Application Insights connection** production ID (Setup tablosunda)
- [ ] **`resourceExposurePolicy`** AppSource için kapalı (downloadSource=false)
- [ ] **`features`** array'inde `TranslationFile`, `NoImplicitWith` var
- [ ] **No per-tenant data** in published `.app` (binary scan)
- [ ] **Object naming** prefix tutarlı (`DOPSWHS-` her objede)
- [ ] **Obsolete tag'ler** breaking schema değişikliği yok
- [ ] **Upgrade codeunit** test sandbox'ta `v0.9 → v1.0` çalışıyor
- [ ] **AL Code Cop** warning sıfır (CI gate)
- [ ] **PerTenantExtensionCop** warning sıfır
- [ ] **AppSourceCop** warning sıfır
- [ ] **Dependency** versiyonu pinlendi (`Base Application 24.0.0.0`)
- [ ] **Test app** `.app` ayrı olarak da çalışıyor (verification)
- [ ] **Installation in fresh Cronus tenant** ≤30 dakika

### Audit scriptleri (CI'a entegre)

- `tools/audit-permissions.sh` — her object için 3 permission set'in birinde mention edildiğini doğrular
- `tools/audit-prefix.sh` — DOPSWHS prefix dışı obje var mı
- `tools/audit-translation-coverage.sh` — eksik çeviri anahtarları
- `tools/audit-obsolete.sh` — obsolete tag yanlış kullanımı

### Performans hardening

- 10K LP + 100K LP Line + 500K Movement Ledger entry seed verisi ile API stress test
- KQL dashboard `dashboards/api-latency.kql` ile p50/p95/p99 hedef gateleri
- Optimization: heavy FlowField'ları SIFT key'lerle hızlandır

## Android Hardening İş Paketleri

### Play Store gereksinimleri

- [ ] **Data safety form** — camera, foreground service, internet
- [ ] **Target API 35** ✓
- [ ] **Minimum supported API 26** ✓
- [ ] **Permissions justification** (CAMERA, INTERNET, FOREGROUND_SERVICE_DATA_SYNC)
- [ ] **Privacy policy URL** Play Store listingde
- [ ] **App icon** adaptive 432x432
- [ ] **Screenshots** Pixel + tablet + Zebra TC22 lt fotoğrafları
- [ ] **R8/ProGuard mapping** uploaded
- [ ] **Crashlytics** v1.0-rc1 build ID ile tagged
- [ ] **Closed testing track** → 5 internal user davet

### Build hardening

- `android/app/proguard-rules.pro` — Kotlin reflection, Ktor, Room, MSAL için keep rules
- R8 full mode aktif (`android.enableR8.fullMode=true`)
- Resource shrinking
- APK boyut hedefi: ≤35MB release

### Battery profiling

- Zebra TC22 sertifika protokolü:
  - 8 saat (480 dakika) sürekli kullanım
  - Her 30 sn'de 1 scan (toplam 960 scan)
  - WiFi-only mode
  - Brightness 50%
  - Hedef: battery ≤ 60% düşüş

### Performance profiling

- Firebase Performance: cold start ≤2.5s, API trace p95 ≤1200ms
- Compose recomposition: her ekranda max 3 recomposition / interaction
- Macrobenchmark profil — `android/macrobenchmark/` modülü ekle

### A11y audit

- TalkBack tüm 14 feature screen'de test
- Contrast WCAG AA — Compose Theme test
- Touch target ≥48dp

### Instrumented test matrix

- emulator (Pixel API 35) — CI default
- Zebra TC22 — nightly scheduled
- Honeywell CT45 — nightly (when available)
- Datalogic Memor 11 — manual on RC build

## Web SPA / Push Relay Hardening

- [ ] **Bundle size budget** ≤250KB gzip her addin
- [ ] **Azure Function cold start** ≤3s (premium plan değerlendirilir)
- [ ] **HMAC validation** unit test'li
- [ ] **Key Vault** secrets managed identity
- [ ] **App Insights** push-relay scope ayrı
- [ ] Playwright E2E suite sandbox'a karşı yeşil

## CI/CD Hardening

### Contract test suite (`.github/workflows/contract.yml`)

- Newman runner — `contract-tests/postman/BCWMSApp.postman_collection.json`
- 50+ endpoint smoke
- OAuth pre-request ile token al
- Nightly scheduled cron + manual trigger
- Failure → Slack notification

### Release workflow (`.github/workflows/release.yml`)

- Trigger: `v*` tag push
- Steps:
  1. Bump versions (app.json, build.gradle.kts, package.json)
  2. Build 3 artifact (.app, .apk release-signed, web bundle zip, push-relay zip)
  3. Create GitHub Release with assets
  4. Notify (email, Slack)

### Branch protection

- `main` direct push yok; PR + 1 review zorunlu
- CI all green zorunlu
- Branches: `main`, `release/v1.x`, `feature/*`, `bugfix/*`

## Monitoring + Telemetry Activation

### App Insights dashboards (`dashboards/`)

- `api-latency.kql` — endpoint × verb × percentile
- `lp-throughput.kql` — LP built/sec per location
- `error-funnel.kql` — scan → confirm → post drop-off
- `device-health.kql` — heartbeat-missing devices
- Power BI workspace bağlanır (opsiyonel)

### Alerting

- AL `AdvWMS.Api.*.Error` rate > 1% → email alert (Azure Monitor)
- Function App 5xx > 5/dakika → page on-call

## Dokümantasyon Hardening

- [ ] `docs/operations-runbook.md` tamamlandı (on-call senaryoları)
- [ ] `docs/api-openapi.yaml` tam (OpenAPI 3.1)
- [ ] `docs/troubleshooting.md` 20+ vaka
- [ ] `docs/release-notes/v1.0.md` final release notu
- [ ] AppSource listing copy (description, key benefits, screenshots)
- [ ] Play Store listing copy

## v1.0 Release Checklist

- [ ] AppSource submission portal'da .app yüklü
- [ ] AppSource validation 0 critical, 0 major
- [ ] Play Store internal testing track 5 tester
- [ ] Crashlytics 0 crash on RC build
- [ ] App Insights production telemetry akıyor
- [ ] Documentation portal canlı
- [ ] `v1.0` git tag + GitHub Release
- [ ] Sales / marketing demo videosu kaydedildi (`docs/release-notes/v1.0-demo.mp4`)
- [ ] Internal launch announcement
- [ ] **v1.0 GA hedef tarihi:** 18 hafta sonrası (Sprint 0 başlangıç + 18 hafta)

## Bitiş Kriterleri (DoD)

- [ ] AppSource submission portal'a .app yüklendi (henüz canlı yayınlanmadı, MS validation bekleniyor)
- [ ] Play Store closed testing track açıldı, 5 tester aktif
- [ ] 8 saat / 1500 scan battery testi geçti (≤60% düşüş)
- [ ] Contract test suite nightly yeşil
- [ ] UI automation suite nightly yeşil
- [ ] App Insights dashboard 4 panel canlı
- [ ] Crashlytics 0 crash RC build
- [ ] `v1.0` tag atıldı, GitHub Release otomatik oluştu
- [ ] `docs/release-notes/v1.0.md` final release notu yayında
