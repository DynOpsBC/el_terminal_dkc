# BCWMSApp Mobile — Erişim ve Çalıştırma Rehberi

> **Versiyon:** v1.0.0 (debug)
> **APK boyutu:** 8.4 MB
> **Min Android:** API 26 (Android 8)
> **Hedef Android:** API 35 (Android 15)

## 🎯 Kanıtlı Canlı Demo

Bu rehberin altında yer alan ekran görüntüleri **BC SaaS Demo Business Central** ortamına **gerçek REST API çağrısı** yapan canlı emulator'dan alınmıştır:

| Adım | Ekran Görüntüsü | Açıklama |
|---|---|---|
| 1️⃣ App açılış | `docs/mobile-demo/bcwms-emu-1-start.png` | "📱 BCWMS Mobile App v1.0.0 — BC Sandbox: CustomerSandbox / Demo Business Central" |
| 2️⃣ Token paste | `docs/mobile-demo/bcwms-emu-2-token.png` | Azure AD access token text field'a yapıştırılır |
| 3️⃣ LP API result | `docs/mobile-demo/bcwms-emu-4-final.png` | **HTTP 200** + LP000001-LP000005 (SILVER bin, CARTON/PALLET/TOTE) |
| 4️⃣ Test Run API | `docs/mobile-demo/bcwms-emu-5-testruns.png` | TR-000001-TR-000004 sonuçları (%98 / %100 pass rate) |

## 📦 APK Konumu

```
/Users/denizcelan/Documents/ClaudeCode/BCWMSApp/android/app/build/outputs/apk/debug/app-debug.apk
```

APK boyutu: 8.4 MB

## 🚀 4 Adımda Çalıştırma

### Adım 1: Toolchain hazırla (~10-15 dk, ilk kurulum)

```bash
# JDK 21 (Gradle 8.13 uyumlu)
mkdir -p /tmp/temurin-21
curl -L -o /tmp/jdk21.tar.gz \
  "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.5_11.tar.gz"
tar -xzf /tmp/jdk21.tar.gz -C /tmp/temurin-21
export JAVA_HOME=/tmp/temurin-21/jdk-21.0.5+11/Contents/Home

# Android SDK
mkdir -p ~/Library/Android/sdk/cmdline-tools
curl -L -o /tmp/cmdtools.zip \
  "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
unzip -q /tmp/cmdtools.zip -d ~/Library/Android/sdk/cmdline-tools/
mv ~/Library/Android/sdk/cmdline-tools/cmdline-tools ~/Library/Android/sdk/cmdline-tools/latest

export ANDROID_HOME=~/Library/Android/sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$JAVA_HOME/bin:$PATH

# SDK components
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" \
  "emulator" "system-images;android-35;google_apis;arm64-v8a"
```

### Adım 2: APK build (~2 dk)

```bash
cd /Users/denizcelan/Documents/ClaudeCode/BCWMSApp/android
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk (8.4 MB)
```

### Adım 3: Emulator oluştur + boot (~1-2 dk)

```bash
# Yeni AVD (Pixel 6, Android 15)
echo "no" | avdmanager create avd -n BCWMSEmu \
  -k "system-images;android-35;google_apis;arm64-v8a" -d "pixel_6" -f

# Boot (headless, no audio)
nohup emulator -avd BCWMSEmu -no-window -no-audio -no-snapshot > /tmp/emu.log 2>&1 &

# Boot bitmesini bekle (~10-30 sn)
adb wait-for-device
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')" != "1" ]; do sleep 3; done
echo "Emulator hazir"
```

### Adım 4: APK install + canlı demo (~1 dk)

```bash
# APK install
adb install -r app/build/outputs/apk/debug/app-debug.apk

# App launch
adb shell am start -n com.dynops.bcwms/.MainActivity

# Screenshot al
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png /tmp/bcwms.png
```

### Adım 5: Token paste + BC API call

```bash
# Az CLI'dan BC SaaS token
TOKEN=$(az account get-access-token \
  --resource "https://api.businesscentral.dynamics.com" \
  --query accessToken -o tsv)

# Text field'a tap (yaklaşık koordinat)
adb shell input tap 540 415

# Token paste (parça parça, 100 char chunks)
for i in $(seq 0 100 ${#TOKEN}); do
    adb shell input text "${TOKEN:$i:100}"
done

# Klavyeyi gizle
adb shell input keyevent KEYCODE_BACK

# "Fetch License Plates" butonuna bas
adb shell input tap 370 770

# Sonuç ekran görüntüsü
sleep 5
adb shell screencap -p /sdcard/result.png && adb pull /sdcard/result.png /tmp/result.png
```

## 🏗️ Mevcut Mobile App Mimari

### Aktif modüller (canlı emulator build'inde)

```
android/
├── app/              # MainActivity (Compose + Material3)
├── core-auth/        # AuthState, MsalAuthClient interface (production)
├── core-design/      # Compose UI components
├── core-domain/      # Entity tanımları
└── feature-auth/     # Token-paste login screen (LoginScreen.kt)
                      # + Ktor-free HttpURLConnection ile BC API call
```

### Demo build için settings.gradle.kts

```kotlin
include(":app", ":core-auth", ":core-design", ":core-domain", ":feature-auth")
```

Full production build için (24 modül):

```kotlin
include(":app", ":macrobenchmark",
        ":core-network", ":core-auth", ":core-db", ":core-scanner",
        ":core-printer", ":core-design", ":core-domain", ":core-sync",
        ":feature-auth", ":feature-home", ":feature-config",
        ":feature-itemInquiry", ":feature-binInquiry", ":feature-lp",
        ":feature-receive", ":feature-putaway", ":feature-move",
        ":feature-pick", ":feature-ship", ":feature-consume",
        ":feature-output", ":feature-assembly", ":feature-count")
```

> Yedek: `android/settings.gradle.kts.full` dosyasında saklı.

## 🔌 BC Sandbox Bağlantı Bilgileri (Hardcoded)

`app-debug.apk` içinde:

- **Tenant:** `7fa2357e-26f2-4174-8e16-a713981356b8`
- **Environment:** `CustomerSandbox`
- **Company ID:** `e83a57e9-38c9-f011-8542-6045bd6aeb9e` (Demo Business Central)
- **API base:** `https://api.businesscentral.dynamics.com/v2.0/{tenant}/{env}/api/dynops/warehouse/v2.0/companies({companyId})/`

## 🔐 Azure AD App Registration (BCWMSApp Mobile)

az CLI ile yaratıldı:

- **App display name:** `BCWMSApp Mobile (sandbox)`
- **Application (client) ID:** `8193e5c6-64d2-4e6f-8992-2114e77e4f24`
- **Sign-in audience:** `AzureADMyOrg` (sadece bu tenant)
- **Public client:** Yes (PKCE flow)
- **Redirect URIs:**
  - `msauth://com.dynops.bcwms/`
  - `https://login.microsoftonline.com/common/oauth2/nativeclient`
- **API permission:** Dynamics 365 Business Central → `user_impersonation` (delegated)

## 🧪 Canlı Demo Sonuçları (Bu oturumda kanıtlandı)

### Fetch License Plates → HTTP 200

BC sandbox'tan **gerçek LP listesi** çekildi:

```
LP000001  CARTON-S    SILVER/S-1-01  Built
LP000002  CARTON-M    SILVER/S-1-01  Built
LP000003  PALLET-EUR  SILVER/S-1-01  Built
LP000004  TOTE-A      SILVER/S-1-01  Built
LP000005  PALLET-US   SILVER/S-1-01  Built
```

### Test Runs → HTTP 200

4 Test Run sonucu (Section A-H, 50 case):

- TR-000001: 49/50 Passed (%98, 3.584sn)
- TR-000002: 49/50 Passed (%98, 3.019sn)
- TR-000003: **50/50 Passed (%100, 0.812sn)** ✅
- TR-000004: **50/50 Passed (%100, 0.746sn)** ✅

## ⚠️ Bilinen Sınırlamalar (Bu demo versiyonu için)

1. **MSAL implementation yok** — Üretim'de Microsoft Authentication Library entegre edilecek; demo'da token-paste flow kullanıldı
2. **Sadece 5 modül aktif** — Tam feature set (14 ek modül) `settings.gradle.kts.full`'da, production build için tekrar etkinleştirilmeli
3. **Hilt DI kapatıldı** — Demo APK basitleştirildi; production'da Hilt + ViewModel injection geri açılacak
4. **Scanner integration scaffold** — `core-scanner` modülü hazır ama feature-auth'ta scan event handling yok (production'da OnScannerResult callback'leri çağrılacak)
5. **Offline queue scaffold** — `core-sync` Op.kt sealed class hazır, SyncWorker production'da WorkManager ile bağlanacak

## 🚀 Üretim Hazırlığı için Sonraki Adımlar

1. **MSAL implementation** — `MsalAuthClient.kt` concrete class yaz, AAD app reg client ID'sini `gradle.properties`'tan al
2. **Tam multi-module activation** — `settings.gradle.kts.full` → `settings.gradle.kts` overlap, Hilt geri ekle
3. **Feature implementations** — Şu an her feature module Compose ekranı + ViewModel scaffold içeriyor; gerçek BC API repository entegrasyonu (Ktor + AuthInterceptor) tamamlanacak
4. **Scanner integration** — Zebra/Honeywell/Datalogic SDK'larının real implementation'ı
5. **Print integration** — PrintNode REST API client production'da yazılacak
6. **Sign release APK** — Production keystore + Play Store internal track

## 📂 İlgili Dosyalar

```
android/
├── app/src/main/java/com/dynops/bcwms/MainActivity.kt     # Compose entry
├── feature-auth/src/main/java/com/dynops/bcwms/LoginScreen.kt  # Token-paste + BC API
├── app/build/outputs/apk/debug/app-debug.apk              # 8.4 MB
├── settings.gradle.kts                                     # Minimal (5 modül)
└── settings.gradle.kts.full                                # Full (24 modül)

docs/mobile-demo/
├── bcwms-emu-1-start.png   # Login screen
├── bcwms-emu-2-token.png   # Token paste
├── bcwms-emu-4-final.png   # ✅ LP API HTTP 200 result
└── bcwms-emu-5-testruns.png # ✅ Test Run API HTTP 200 result

docs/mobile-app-guide.md (bu dosya)
```
