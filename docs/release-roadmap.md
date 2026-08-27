# BCWMSApp — Release & Licensing Roadmap

Hedef sürüm: **v1.10.0** — paketlemenin "müşteri ortamına ship edilebilir" olduğu
ilk kilometre taşı. Bu doc kararları, kapsam ve sırayı tek bir referans
noktasında toplar; ayrıntılı uygulama her bir GitHub issue'a bağlanır.

## Kararlar

| Konu | Karar | Not |
|---|---|---|
| BC dağıtım kanalı | **Per-Tenant Extension (PTE)** | Microsoft AppSource paralel olarak hazırlanır ama bloke değil. PTE: anında yayın, müşteri kendi BC Admin Center'ından yükler |
| Web dağıtım | Tek bundle SaaS — `app.bcwms.dynops.com` | Müşteri kendi BC tenant + token'ı ile bağlanır |
| Mobil dağıtım | **Play Closed Testing + APK in-app update fallback** | Play Store tester listesi ana yol; Play Store erişimi olmayan müşteriler için APK + `update.json` mekanizması |
| Lisans modeli | **Tier + seat** | `Setup."License Tier"` enum'unu (Essentials / Advanced / Enterprise) aktif enforcement'a bağla; seat = kayıtlı Device + aktif Web user |
| İlk iş | Roadmap doc + GitHub issues | Implementation v1.10.0 sprintinde başlar |

## Mimari

```
                              ┌──────────────────────────────────┐
                              │ DynOps Licensing Service         │
                              │ (Azure Function, RS256 JWT)      │
                              │                                  │
                              │ POST /license/issue              │
                              │ POST /license/verify             │
                              │ GET  /license/me                 │
                              └──┬───────────────┬───────────┬───┘
                                 │               │           │
            ┌────────────────────┴─┐  ┌──────────┴─────┐  ┌──┴──────────────────┐
            │ BC Extension (PTE)   │  │ Web SPA        │  │ Mobile (Compose)    │
            │ Setup.License Key →  │  │ Login → /verify│  │ Boot → /verify      │
            │ JWT Validator (1.8)  │  │ tier filters   │  │ tier + seat cache   │
            │ tier enforcement     │  │ tile gates     │  │ offline grace 7d    │
            └──────────────────────┘  └────────────────┘  └─────────────────────┘
                       ▲
                       │
            ┌──────────┴───────────────────────────────┐
            │ DynOps Customer Portal                   │
            │ (Vite + Azure Static Web App)            │
            │  • release notes + changelog feed        │
            │  • license issue / extend / revoke       │
            │  • "Şimdi yükselt" → BC Admin API        │
            └──────────────────────────────────────────┘
```

## Versiyonlama

- **Aynı major.minor tüm istemcilerde kilit**: web `1.10.x` ↔ BC `1.10.x.x` ↔
  Android `1.10.x(110x)`. Breaking schema değişiklikleri minor bump'la
  koordine edilir.
- Patch sürümler bağımsız ship olabilir (sadece kendi katmanını etkiliyorsa).
- SemVer: AL 4 segment, web/mobil 3 segment + Android `versionCode`.

## Release pipeline

```
git tag v1.10.0
   └─► GitHub Actions matrix:
        ├─ Windows runner  → ALTOOL package + AppSourceCop → .app
        ├─ Ubuntu runner   → pnpm build (web) → Azure Static Web App deploy
        └─ Ubuntu runner   → gradle assembleRelease (Android)
                              ├─ Play Store Closed Track upload (gplay-publisher)
                              └─ APK + update.json → GitHub Releases
   └─► Customer Portal manifest auto-refresh
   └─► Customer Portal sends update notification to opted-in tenants
```

## Sprint planı (v1.10.0)

### S1 — Licensing service (2 gün)
- `licensing-service/` (yeni Azure Function, push-relay yanına)
- Endpoints: `POST /license/issue`, `POST /license/verify`, `GET /license/me?tenant=`
- RS256 imzalı JWT, claims: `tenantId`, `product`, `tier`, `seats`, `validUntil`,
  `customerEmail`, `iat`, `exp`
- Storage: KeyVault'ta RSA private key, Table Storage'da issued licenses
  (tenantId → key, status, history)
- BC tarafındaki `DOPSWHS JWT Validator` (v1.8.2.0) imzayı bu key ile doğrular
- **Acceptance**: `curl POST /license/issue` → JWT döner; `verify` → valid:true;
  expired key → valid:false; bad signature → 401

### S2 — BC license validator + tier enforcement (1.5 gün)
- `Setup."License Key"` yeni alan (Text[2048] — JWT cargo)
- `DOPSWHS License Mgmt` codeunit: boot'ta + günde 1 kere `/verify`, sonucu
  IsolatedStorage cache (TTL 1h, offline grace 7 gün)
- Setup Card'da "License" group: tier, seats used / available, expires,
  status badge
- Lisans geçersiz/expired → RoleCenter'da kırmızı banner, Print Job Queue +
  Print Bridge + Webhook publish bloklanır (read-only mode kalır)
- Tier enforcement noktaları:
  - **Essentials**: max 5 device, 10 LP/saat throttle, Print Bridge KAPALI,
    MS QM KAPALI, Production KAPALI
  - **Advanced**: max 20 device, Print Bridge AÇIK, MS QM AÇIK, Production
    KAPALI
  - **Enterprise**: unlimited, hepsi AÇIK
- **Acceptance**: Setup'a invalid key gir → banner görünür; valid Essentials
  key → 6. device kayıt 'License limit' error; valid Enterprise → tüm
  feature flag'ler aktif

### S3 — Customer Portal (3 gün)
- `customer-portal/` (yeni Vite SPA, repo root altında)
- Auth: AAD MSAL.js (her müşteri admin kendi MS hesabıyla login)
- Sayfalar:
  - **Dashboard** — aktif lisans, tier, seats, sürüm, son güncelleme
  - **Releases** — versiyon notları + "Şimdi yükselt" butonu (BC Admin Center
    Update API çağrısı) + "Otomatik update'i aç/kapa" toggle
  - **License** — extend, additional seats, view history
  - **Downloads** — APK, agent binary, .app manifest
- Backend: licensing-service'in extension'ları (`GET /releases`, `POST /trigger-update`)
- Deploy: Azure Static Web App, custom domain `portal.bcwms.dynops.com`
- **Acceptance**: yeni müşteri MSAL ile login → dashboard'da kendi tenant
  bilgisi; "Yükselt" → BC tenant'ında app version değişir; "Extend license"
  → JWT yeniden imzalanır, BC verify döngüsünde tier güncellenir

### S4 — Web auto-update (0.5 gün)
- Vite plugin: `vite-plugin-pwa` ile Service Worker generate
- Background'da bundle değiştiğinde `skipWaiting` + kullanıcıya toast
  "Yeni sürüm yüklendi — yenileyin"
- GitHub Actions web-build job'una Azure Static Web Apps deploy step ekle
  (tag-tetikli)
- **Acceptance**: prod build deploy → ikinci sekmede toast görünür → refresh
  → yeni sürüm

### S5 — Android Play Closed Track + APK fallback (1.5 gün)
- Play Console Closed Testing track setup, internal alias listesi
- `fastlane`/`gplay-publisher` Gradle plugin → tag-tetikli upload
- In-app update channel:
  - `apps/mobile/feature/UpdateModule.kt` — boot'ta `GET /releases/android/latest.json`
  - Yeni versionCode varsa → AlertDialog "Yeni sürüm var (1.10.1) — indir"
  - İndir → `DownloadManager` → `PackageInstaller` (REQUEST_INSTALL_PACKAGES izni)
  - Play Store track'inden gelen update öncelikli, fallback sadece sideload
- **Acceptance**: Play Store closed track'e 1.10.0 push → tester cihazlarında
  otomatik update; APK installer cihazda → in-app dialog ile 1.10.1 yükler

### S6 — Release pipeline (1 gün)
- `.github/workflows/release.yml` — `v*` tag triggered, matrix:
  - `windows-latest`: AL build (zaten var, sadece release artifact ekle)
  - `ubuntu-latest`: web build + Static Web App deploy
  - `ubuntu-latest`: Android assembleRelease + Play upload + GitHub Release APK
- GitHub Release auto-generated changelog (`gh release create`)
- Customer Portal manifest webhook tetiklenir
- **Acceptance**: `git tag v1.10.0 && git push --tags` → 8 dakika içinde
  Static Web App + Play Closed Track + GitHub Releases güncel

### S7 — Docs (0.5 gün)
- `docs/license-protocol.md` — JWT şeması, endpoints, hata kodları, BC entegrasyon
- `docs/install-pte.md` — müşteri admin için adım adım PTE install rehberi
  (screenshot'larla)
- `docs/update-flow.md` — her katmanın update mekanizması (BC auto-update,
  web SW, Play Store, APK fallback)
- `README.md` üst kısma "Latest version", "How to install", "Customer portal"
  linkleri

**Toplam tahmin:** ~10 gün efor (paralel sprint'ler, 1 dev için ~2 hafta).

## Out of scope (v1.11.0+)

- **AppSource sertifikası** — Microsoft Partner Center kaydı + AppSourceCop
  full pass + technical validation gerekli. Paralel çalışılır ama v1.10.0
  ship gating değil.
- **iOS mobil app** — şu an roadmap dışı, talep ölçeğine göre değerlendirilir.
- **Multi-tenant Customer Portal RBAC** — şu an 1 admin = 1 tenant; ileride
  reseller / partner user'lar için role-based access.
- **Usage-based pricing** — şu an flat tier; ileride job count / API call /
  print volume metriklerinden faturalama.

## Riskler

- **JWT imza key kaybı** → tüm müşteri lisansları geçersiz. Mitigation:
  KeyVault soft-delete + 90 gün purge protection + offline backup (encrypted).
- **Müşteri offline → license verify fail** → 7 gün grace + son geçerli
  cache'i kabul et. 7+ gün kapalı kalan tenant manuel reactivation.
- **BC PTE upload customer-side adım** → bizim portal yapamıyor, sadece
  customer admin yapabilir. Mitigation: portal'da "Bana e-posta gönder"
  butonu + step-by-step PDF + video.
- **Play Closed Track latency** — tester listesi propagation ~6 saat. Acil
  hotfix için APK fallback çözüm.
- **Tier enforcement bypass** → kötü niyetli müşteri AL kod'unu inceleyemez
  (extension binary), ama lisans verify endpoint'ini mock'layabilir.
  Mitigation: JWT imza zorunlu + boot'ta replay-resistant nonce + telemetry
  ile tenant başına usage anomalisi alarm.

## Kabul kriteri (v1.10.0 ship)

1. `licensing-service` Azure'da deploy, `curl /license/verify` valid JWT döner.
2. BC PTE upload: yeni müşterinin sandbox'ına .app yüklenir, Setup'a key
   yapıştırılır, banner "Lisans aktif (Advanced — 12 seat / 20)" gösterir.
3. Customer Portal'dan tier upgrade: portal'da Essentials → Advanced butonu →
   yeni JWT → BC bir döngüde fark eder → tile'lar açılır.
4. Web sürüm bump: tag push → Static Web App deploy → tüm açık sekmelerde
   "Yeni sürüm" toast.
5. Mobil sürüm bump: tag push → Play Closed Track'e otomatik upload → tester
   cihazlarında Play Store update → APK-only test cihazında in-app dialog.
6. End-to-end zaman: `git tag` → tüm istemciler güncel sürümde ≤ 30 dk.

## Referanslar

- BC PTE upload: <https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/tenant-admin-center-extensions>
- Play Closed Testing: <https://support.google.com/googleplay/android-developer/answer/9845334>
- Azure Static Web Apps custom domains: <https://learn.microsoft.com/en-us/azure/static-web-apps/custom-domain>
- RS256 JWT in BC: mevcut `DOPSWHS JWT Validator` (v1.8.2.0) referansı
