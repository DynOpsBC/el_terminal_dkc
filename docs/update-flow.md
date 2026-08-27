# Update Flow — Her katman müşterilere nasıl güncelleme götürür?

`git tag v1.x.y && git push --tags` tek bir komut. Bu noktadan sonra
otomatik mekanizmalar devreye girer ve müşteri ortamları en geç ~30 dakika
içinde güncel sürüme geçer.

## Üst düzey akış

```
 dev local
    │ git tag v1.10.0 && git push --tags
    ▼
 ┌──────────────────────────┐
 │ GitHub Actions release.yml│  (6 paralel job)
 ├──────────────────────────┤
 │ resolve  →  al-package    │
 │          →  licensing     │
 │          →  web saas      │
 │          →  customer-portal│
 │          →  android       │
 └──────────────────────────┘
            │
            ├─► Azure Function publish (licensing-service)
            ├─► Azure Static Web App push (web/dist)
            ├─► Azure Static Web App push (customer-portal/dist + api)
            ├─► Play Console Closed Track AAB upload (gradle-play-publisher)
            ├─► GitHub Releases assets (.app, .apk, .aab, latest.json)
            └─► Customer Portal release feed refresh
                   │
                   ▼
              Müşteri tarafı
```

## Katman bazlı sözleşmeler

### 1. BC extension (.app)

| Mekanizma | Açıklama |
|---|---|
| **Microsoft auto-update** | PTE upload sırasında "Automatic" seçildiyse, aynı `id` + büyük `version` yüklendiğinde BC ortamı arka planda yükseltir. Downtime yok |
| **Portal manuel update** | Customer Portal "Releases" → "Şimdi yükselt" → BC Admin Center upgrade API çağrısı |
| **PTE upload (manual)** | Admin Center → Apps → Upload Extension → `.app` |

`release.yml` `al-package` job'u Windows runner'da `.app` artifact'i toplar
ve GitHub Releases'a yükler. Müşterinin PTE upload akışı bu dosyayı kullanır.

Verify: `https://github.com/DynOpsBC/WMS/releases/latest` →
`bcwmsapp-1.10.0.0.app` görünmeli.

### 2. Web SaaS (`app.bcwms.dynops.com`)

| Mekanizma | Süre |
|---|---|
| **Azure Static Web App deploy** | `release.yml` web-deploy job → SWA, ~30sn |
| **Service Worker prompt** | Açık sekmede `onNeedRefresh` toast → kullanıcı "Yenile" → `skipWaiting` + reload |
| **Cold open** | Yeni cihazda anında en güncel bundle |

PWA precache `globPatterns` ile tüm `js/css/html/svg/woff2` cache'lenir;
`cleanupOutdatedCaches: true` eski revisionleri otomatik temizler.

UI bileşeni: `web/src/ui/UpdateToast.tsx` — `subscribeUpdate(cb)` hook'u
toast'ı render eder.

### 3. Customer Portal (`portal.bcwms.dynops.com`)

Aynı SWA pattern. Portal kendi sürümünü `package.json` üzerinden taşır;
müşteri 0 trafikle güncellenir.

### 4. Mobile — Play Store (closed track)

| Mekanizma | Süre |
|---|---|
| **Play auto-update** | Tester cihazlarında Play Store arka planda yükler (cihaz idle iken). Wi-Fi only default |
| **In-app update banner** | Update priority 3 → cihaz açılışında Play "Update available" prompt |
| **Manual** | Play Store → BCWMS → Update |

Closed Track tester listesi ~6 saatte propagate olur. Acil hotfix için ya
yeni `versionCode` hızla yükle ya da fallback APK kullan.

### 5. Mobile — APK sideload fallback

| Mekanizma | Süre |
|---|---|
| **In-app dialog** | Boot'ta `GET <DEFAULT_UPDATE_BASE>/releases/android/latest.json`; yeni `versionCode` → AlertDialog |
| **Indirme + SHA-256** | DownloadManager + manifest SHA-256 doğrulaması (mandatory) + apkUrl HTTPS + host allowlist |
| **Install** | FileProvider + ACTION_VIEW → Android sistem yükleme UI (kullanıcı consent) |

`latest.json` `release.yml` `android-publish` job'u tarafından `jq` ile
oluşturulur (injection-safe). GitHub Releases asset'leri `app.bcwms.dynops.com`
domain'i CNAME ile arkasında değil; agent şu host'ları kabul eder:
`app.bcwms.dynops.com`, `github.com`, `objects.githubusercontent.com`,
`release-assets.githubusercontent.com`.

## Süreler

| Adım | Tahmin |
|---|---|
| `release.yml` matrix bitiş | ~8 dk |
| BC otomatik update propagation | ~5-10 dk |
| Azure SWA cache invalidation | ~30 sn |
| Play Closed Track propagation | ~30 dk – 6 saat |
| Mobile in-app update dialog görünüm | sonraki app boot |
| **End-to-end (en kötü senaryo)** | ~6 saat (Play) / ~10 dk (diğerleri) |

## Troubleshooting

| Belirti | Olası sebep | Çözüm |
|---|---|---|
| BC `License Status = Offline` | licensing-service ulaşılamıyor | 7 gün grace; Azure Function health kontrol |
| Web toast görünmüyor | SW build edilmemiş | `BCWMS_TARGET=saas pnpm build` |
| Play tester'da update gelmiyor | Tester listesi güncel değil | Play Console → Closed Track → tester listesi yenile, 6 saat bekle |
| APK indirme `Doğrulama başarısız` | SHA-256 mismatch | Manifest cache'inden yeni yayını al; `latest.json` yeniden üretilmiş mi kontrol |
| Portal "Şimdi yükselt" 401 | EasyAuth oturum yenilenmemiş | Çıkış + tekrar giriş; tenant_id eşleşmesi kontrol |
| Release workflow `Tag … is not in MAJOR.MINOR.PATCH` | Tag formatı bozuk | Regex ile reddediliyor — `v1.10.0` formatında re-tag |

## Manuel acil sürüm geri alma

```bash
# 1. Önceki kararlı tag'i yeniden çek
git tag v1.10.0-hotfix HEAD~1
git push origin v1.10.0-hotfix

# 2. Release workflow tekrar koşar; bundle'lar geri alınmış sürümle gider
# 3. Müşteri tarafında SW + Play + BC auto-update aynı pipeline'ı kullanır
```

BC tarafında manuel rollback: Admin Center → Apps → "Restore from previous
version" (Microsoft built-in).
