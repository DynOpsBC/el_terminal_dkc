# BCWMS Android — Sideload Kurulum Rehberi

**APK:** [`releases/android/bcwms-1.10.0-debug.apk`](../releases/android/bcwms-1.10.0-debug.apk) (32 MB)
**SHA-256:** `c19f10a73ca5edf41971898a74509e798ca0f463c57377211dbedbeb0f0e9020`
**Min Android:** 8.0 (API 26) — Pixel, Samsung, Zebra TC22/TC52 dahil
**Target SDK:** 35 (Android 15)
**Application ID:** `com.dynops.bcwms`

> Bu APK **debug build**. Production deploy için Play Store veya
> imzalı release APK önerilir. Debug APK self-test/QA için yeterlidir.

## Kurulum yöntemleri

### Yöntem 1 — USB + adb (geliştirici, en hızlı)

Cihaza Geliştirici Seçenekleri + USB Debugging açık olmalı:

1. **Ayarlar → Telefon Hakkında → Build Number** 7 kez dokun → "You are now
   a developer"
2. **Ayarlar → Sistem → Geliştirici Seçenekleri → USB Debugging** aç
3. Telefonu USB ile bilgisayara bağla, ekrandaki "Allow USB debugging"
   diyaloğunu onayla

Kurulum:

```bash
# Repo kök dizininde
adb install -r releases/android/bcwms-1.10.0-debug.apk
# veya cihaza zaten kurulu varsa update:
adb install -r -d releases/android/bcwms-1.10.0-debug.apk
```

`Success` çıktısı sonrası uygulama menüde "BCWMS" adıyla görünür.

### Yöntem 2 — Doğrudan APK indirme (sideload, USB yok)

Telefondan tarayıcıyı aç:

1. <https://github.com/DynOpsBC/WMS/raw/main/releases/android/bcwms-1.10.0-debug.apk>
   bağlantısını aç (private repo → GitHub login)
2. İndirme tamamlanınca dosya yöneticisinden APK'ya dokun
3. "Bilinmeyen kaynaklardan uygulama kurulumuna izin ver" çıkarsa
   **Ayarlar → Bu kaynak için izin ver → Geri** dön → Kur
4. Kurulum bittikten sonra "Aç"

### Yöntem 3 — Zebra TC22/TC52 EMM ile toplu dağıtım

DataWedge profili + MX bundle ile Zebra cihaz filosuna dağıtım için
[docs/zebra-datawedge-setup.md](zebra-datawedge-setup.md) runbook'unu
takip et.

## İlk açılış — bağlantı kurulumu

1. App açıldığında **🔴 Bağlı değil** badge'i + Ana Menü görünür
2. Sağ alttan **⚙️ Bağlantı** tile'ı veya badge'e dokun
3. **BC Token Yapıştır** kartına aşağıdaki bilgiler:
   - **Environment:** `SandboxUS` (CRONUS USA, Inc.) veya
     `CustomerSandbox` (Demo Business Central)
   - **Company:** Drop-down'dan seç (token gerekirse otomatik gelir)
   - **Access Token:** Bearer token (formatı uzun, `eyJ...` ile başlar)

Token nereden alınır:

```bash
# Lokal makinede (Azure CLI login'liyse)
az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv
```

Veya [docs/wms-token-generation.md](wms-token-generation.md) detaylı yol.

Token kaydedildikten sonra badge **🟢 Bağlı** olur.

## Smoke test — kurulumu doğrula

App içinde **🩺 Sistem Sağlığı** tile → **▶ Tümünü Çalıştır**.

Beklenen sonuç (BC ortamında DOPSWHS extension publish edilmişse):

```
✅ BC token saklanmış mı?
✅ warehouse/v2.0 API ulaşılabilir mi?
✅ Standart items fallback çalışıyor mu?
✅ ItemApi inventory FlowField calc çalışıyor mu?
✅ BinContentApi (page 72097) çalışıyor mu?
✅ LP templates seed edilmiş mi?
✅ qualityOrders API çalışıyor mu?
⏭ Default printer atanmış mı?   (Yazıcılar ekranından atayın)
✅ ScanBus emit + collect çalışıyor mu?
✅ Token süresi geçerli mi?
```

9 ✅ + 1 ⏭ → kurulum başarılı.

DOPSWHS extension publish edilmemişse: 6 ✅ + 3 ❌ (BinContent /
LPTemplate / ItemApi inventory FlowField). `releases/` altında en güncel
`.app` paketini BC Admin Center → Extension Management üzerinden yükleyin.

## Bilinen kısıtlar — debug APK

- **Imzasız** (`testKey`): Play Protect uyarı verebilir → "Yine de kur"
- **Debuggable**: prodüksiyon ortamına yüklemeyin (key extraction riski)
- **PWA pull-to-refresh yok**: app içi reload `🔄` butonları ile
- **Background sync yok**: foreground'da kullanılır (operatör elinde)

## APK güncellemeleri

`releases/android/` her yeni release'de güncellenir. Versiyon adı:
`bcwms-<X.Y.Z>-debug.apk`. Cihazda eski versiyon varsa `adb install -r`
otomatik replace yapar (data korunur).

`releases/android/CHANGELOG.md` her sürümün değişikliklerini özetler.

## Sorun giderme

| Belirti | Çözüm |
|---|---|
| "Parse error" kurulumda | İndirilen APK bozuk → yeniden indir, sha256 kontrol et |
| "App not installed" | Eski versiyon farklı signing key ile → önce kaldır, sonra kur |
| Açılışta crash | `adb logcat -d -t 100 \| grep AndroidRuntime` ile stack trace al |
| 🔴 Bağlı değil + token doğru | BC sandbox state Down olabilir; `az account` token expire kontrolü |
| Zebra sarı tetik çalışmıyor | [zebra-datawedge-setup.md](zebra-datawedge-setup.md) — DataWedge profile import |
