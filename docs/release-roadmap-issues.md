# v1.10.0 — Release & Licensing — GitHub Issues

Bu dosya `docs/release-roadmap.md`'nin S1–S7 sprint'lerini birebir karşılayan
issue başlık + body'lerini içerir. Tek komutla açmak için:

```bash
gh auth login
gh issue create --title "S1 — licensing-service Azure Function (JWT issue/verify)" \
  --label "v1.10.0,backend,licensing" --milestone "v1.10.0" \
  --body-file <(awk '/^## S1/,/^---$/' docs/release-roadmap-issues.md | sed '$d')
```

(Veya GitHub web UI → New Issue → her bölümü kopyala.)

Önce milestone'u oluştur:
```bash
gh api -X POST repos/DynOpsBC/WMS/milestones -f title="v1.10.0" \
  -f description="Release & Licensing — ship-ready to customers"
```

---

## S1 — licensing-service Azure Function (JWT issue/verify)

**Etiketler:** v1.10.0, backend, licensing

### Görev
push-relay yanına yeni `licensing-service/` Azure Function ekle. RS256 JWT
issue + verify endpoint'leri.

### Endpoint'ler
- `POST /api/license/issue` — body `{ tenantId, product, tier, seats, validUntil, customerEmail }` → `{ key (JWT), id }`
- `POST /api/license/verify` — body `{ tenantId, key }` → `{ valid, tier, seats, expiresAt, signature }`
- `GET  /api/license/me?tenant=<id>` — cache-friendly (HTTP cache 1h), aynı `verify` payload

### Storage
- Azure Table Storage: `licenses` tablosu (PartitionKey=tenantId, RowKey=id, status, history JSON)
- Azure KeyVault: RSA 2048 private key (`license-signing-key`), soft-delete + 90gün purge protection AÇIK

### Acceptance
- `curl POST /license/issue` → JWT döner, jwt.io'da decode edilebilir
- `verify` valid key → 200 `valid:true`
- expired key → 200 `valid:false`, `reason:"expired"`
- bad signature → 401
- Unit test: `node --test` ile issue/verify round-trip

### Dosyalar
- `licensing-service/license-issue/{function.json,index.ts}`
- `licensing-service/license-verify/{function.json,index.ts}`
- `licensing-service/license-me/{function.json,index.ts}`
- `licensing-service/shared/JwtSigner.ts` (RS256 sign + verify)
- `licensing-service/shared/LicenseStore.ts` (Table Storage repo)
- `licensing-service/infra/main.bicep` (Function App + KeyVault + Storage)

---

## S2 — BC License Validator + tier enforcement

**Etiketler:** v1.10.0, al, licensing

### Görev
`DOPSWHS License Mgmt` codeunit ile S1 service'ini BC tarafında entegre et.
Tier-bazlı runtime guard'ları LP/Device/Print/QM/Production noktalarına bağla.

### AL değişiklikleri
- `Setup."License Key"` Text[2048] — yeni alan
- `DOPSWHS License Mgmt` codeunit:
  - Boot ve günde 1 kere `/verify` çağırır (mevcut `DOPSWHS JWT Validator`
    ile signature check ek olarak)
  - IsolatedStorage cache (TTL 1h, offline grace 7 gün, son geçerli kabul)
  - Setup Card'a "License" group: tier badge, seats used/available, expires,
    health status
- Lisans geçersiz/expired → RoleCenter'da kırmızı banner; bu sırada Print
  Job Queue + Print Bridge + Webhook publish bloklanır (read-only mode kalır)
- Tier guard'lar:
  - **Essentials**: max 5 device, 10 LP/saat throttle, Print Bridge KAPALI,
    MS QM KAPALI, Production KAPALI
  - **Advanced**: max 20 device, Print Bridge AÇIK, MS QM AÇIK, Production KAPALI
  - **Enterprise**: unlimited, hepsi AÇIK
- Yeni event'ler: `OnBeforeLicenseGate` (extensibility), `OnAfterLicenseValidated`

### Acceptance
- Setup'a invalid key gir → banner görünür, status `Invalid`
- Valid Essentials key → 6. Device Registration insert → `License limit reached` error
- Valid Advanced key → MS QM tile açılır, Production hâlâ kilitli
- Valid Enterprise → tüm gate'ler PASS

### Dosyalar
- `al/src/Licensing/LicenseMgmt.Codeunit.al` (yeni)
- `al/src/Licensing/LicenseCue.Table.al` (yeni — seats used/avail)
- `al/src/Setup/Setup.Table.al` (License Key + Last Verified At)
- `al/src/Setup/Setup.Page.al` (License group)
- `al/src/RoleCenter/DynOpsWMSRC.Page.al` (banner)
- `al/src/Device/DeviceRegistration.Table.al` OnInsert → license check
- `al/src/Print/PrintDispatcher.Codeunit.al` SelfHosted branch → license check
- 3× PermissionSet update

---

## S3 — Customer Portal (Vite + Azure Static Web App)

**Etiketler:** v1.10.0, frontend, portal

### Görev
Müşteri admin'in kendi tenant'ı için lisans yönetimi + sürüm yükseltmesi
yapabileceği SaaS portal.

### Sayfalar
- **Dashboard** — aktif lisans, tier, seats used/avail, sürüm, son güncelleme
- **Releases** — versiyon notları feed + "Şimdi yükselt" + "Auto-update aç/kapa"
- **License** — extend, additional seats, history
- **Downloads** — APK, agent binary, .app + manifest

### Auth
- MSAL.js — müşteri admin AAD ile login
- Backend `tenantId` claim'i ile bağlanır
- `customer-portal/api/` (Azure Function) — licensing-service'i çağırır,
  BC Admin Center Update API'sini proxy'ler

### Deploy
- Azure Static Web App, custom domain `portal.bcwms.dynops.com`
- GitHub Actions: `customer-portal/` push → SWA deploy

### Acceptance
- Yeni müşteri MSAL login → dashboard'da kendi tenant bilgisi
- "Şimdi yükselt" → BC tenant'ında app version değişir (Microsoft.Dynamics
  Admin Center API çağrısı), sayfada toast "Update tetiklendi"
- "Extend license 12 ay" → yeni JWT issue → BC bir döngüde fark eder

### Dosyalar
- `customer-portal/` (yeni — Vite + React 19 + TypeScript)
- `customer-portal/api/` Azure Function endpoints (releases proxy, trigger-update)
- `customer-portal/src/modules/{Dashboard,Releases,License,Downloads}.tsx`
- `customer-portal/infra/main.bicep`

---

## S4 — Web auto-update (SW + version banner)

**Etiketler:** v1.10.0, web, ux

### Görev
`web/` üzerine Service Worker ekle; yeni bundle deploy olduğunda kullanıcıya
toast göster.

### Değişiklikler
- `pnpm add -D vite-plugin-pwa` + `vite.config.ts` integration
- `web/src/lib/updateNotifier.ts` — `registerSW({ onNeedRefresh })`
- `web/src/ui/UpdateToast.tsx` — Fraunces serif başlıklı toast: "Yeni sürüm
  hazır — yenile" + "Yenile" buton (iris primary)
- GitHub Actions `web-build.yml` → tag-tetikli Azure Static Web App deploy step

### Acceptance
- Prod build deploy edilir → eski sekmede 30sn içinde toast belirir → refresh
  → yeni sürüm
- Browser DevTools → Application → Service Workers'da `bcwms` SW kayıtlı
- Lighthouse PWA score ≥ 90

### Dosyalar
- `web/vite.config.ts` (PWA plugin)
- `web/src/lib/updateNotifier.ts`
- `web/src/ui/UpdateToast.tsx`
- `web/src/main.tsx` (register + render toast)
- `.github/workflows/web-build.yml` (deploy step)

---

## S5 — Android Play Closed Track + APK in-app update

**Etiketler:** v1.10.0, android, ux

### Görev
İki dağıtım kanalı paralel:
1. Google Play Closed Testing track (öncelikli)
2. Sideload müşterileri için in-app update channel

### Play Console
- App listing (Closed Testing), tester gmail listesi (ilk müşteri admin'leri)
- Play App Signing AÇIK; upload key bizim CI secret
- `gradle-play-publisher` plugin: tag-tetikli `publishReleaseBundle`

### In-app update channel
- `apps/mobile/feature/UpdateModule.kt` — boot'ta `GET /releases/android/latest.json`
- JSON: `{ versionCode, versionName, apkUrl, sha256, releaseNotes }`
- Yeni versionCode varsa → `AlertDialog` (Fraunces başlık, iris CTA)
  → "İndir" → `DownloadManager` → SHA-256 verify → `PackageInstaller`
- `REQUEST_INSTALL_PACKAGES` permission AndroidManifest'e eklenir
- Settings → "Güncelleme kontrolü kapalı/açık" toggle

### Acceptance
- Tag `v1.10.0` push → 10 dk içinde Play Closed Track'te builds görünür →
  tester cihazlarında auto-update
- APK-only sideload cihaz → in-app dialog → indir → kur → uygulama yeni
  versionCode'da yeniden açılır
- SHA-256 mismatch → "Doğrulama başarısız" hata, install yok

### Dosyalar
- `android/app/src/main/java/com/dynops/bcwms/feature/UpdateModule.kt`
- `android/app/src/main/AndroidManifest.xml` (REQUEST_INSTALL_PACKAGES)
- `android/app/build.gradle.kts` (gradle-play-publisher config)
- `android/play/keystore/keystore.properties` (CI secret reference)

---

## S6 — Release pipeline (matrix CI on tag)

**Etiketler:** v1.10.0, ci, infra

### Görev
`v*` tag push → parallel jobs → tüm istemcileri tek komutla deploy.

### Workflow
- `.github/workflows/release.yml` (yeni)
- Trigger: `push: tags: ['v*']`
- Jobs:
  - `al-package`: windows-latest, ALTOOL package + AppSourceCop, artifact `.app`
  - `web-deploy`: ubuntu-latest, pnpm build + Azure Static Web App deploy
  - `mobile-publish`: ubuntu-latest, gradle assembleRelease + Play upload +
    GitHub Releases APK + `update.json`
  - `customer-portal-deploy`: ubuntu-latest, customer-portal SWA deploy
  - `licensing-service-deploy`: ubuntu-latest, Azure Function deploy
  - `release-notes`: GitHub Release auto-changelog ve customer-portal manifest
    webhook tetikle

### Secrets
- `AZURE_CREDENTIALS`, `AZURE_STATIC_WEB_APPS_API_TOKEN` (web + portal)
- `AZURE_FUNCTIONAPP_PUBLISH_PROFILE_LICENSING`
- `PLAY_SERVICE_ACCOUNT_JSON`, `ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASS`
- `BCWMS_LICENSE_SIGNING_KID` (test mode için)
- `JDK21_PATH` runner env (ubuntu setup-java action)

### Acceptance
- `git tag v1.10.0 && git push --tags` → 8 dakika içinde Static Web App
  yenilenir, Play Closed Track'e push, GitHub Releases sayfasında .app +
  APK + changelog
- Failed job tek track'i blokler, diğerleri devam eder

### Dosyalar
- `.github/workflows/release.yml` (yeni)
- `.github/workflows/web-build.yml` (deploy step)
- `.github/workflows/android-build.yml` (Play upload step)
- `.github/workflows/al-build.yml` (release artifact step)

---

## S7 — Docs

**Etiketler:** v1.10.0, docs

### Görev
v1.10.0 için müşteri-yönlü + dev-yönlü 3 doc.

### Dosyalar
- `docs/license-protocol.md` — JWT şeması (claims tablosu), endpoint
  contracts, hata kodları, BC entegrasyon adımları, key rotation
- `docs/install-pte.md` — müşteri admin için adım adım PTE install rehberi
  (Admin Center → Manage extensions → Upload), screenshot
- `docs/update-flow.md` — her katmanın update mekanizması (BC auto-update,
  web SW, Play Store, APK fallback), troubleshooting tablosu
- `README.md` üst kısma "Latest version", "Customer Portal", "Status page"
  rozetleri

### Acceptance
- Yeni müşteri docs'u takip ederek 30 dk içinde lisans aktif, sürüm yüklü
- DevTeam'in license rotation runbook'u var

---

## Issue'lar açıldıktan sonra

Milestone progress bar tüm sprint'leri grupbağlar. PR'lar `Closes #<issue>`
ile bağlanır. Sprint sırası: S1 → S2 (paralel S4) → S3 (S1 hazır olunca) →
S5 (paralel S6) → S7 (cleanup).
