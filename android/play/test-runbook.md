# Android Release-Sign Test Runbook

**Bu doc'taki adımlar v1.10.0 paketini herhangi bir müşteriye duyurmadan
ÖNCE bir kez bitirilmelidir.** Release signing CI'da otomatik gibi görünse
de ilk kez gerçek bir cihazda test edilmeden production'a gönderilmesi
ship-blocker bir risk.

## 1. Keystore üret (ilk kez, bir defaya mahsus)

```bash
keytool -genkey -v \
  -keystore android/play/keystore/upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 4096 -validity 9125 \
  -storepass "<strong-password>" -keypass "<strong-password>" \
  -dname "CN=BCWMS Upload, OU=DynOps, O=DynOps, L=Istanbul, C=TR"
```

`android/play/keystore/keystore.properties`:

```properties
storeFile=play/keystore/upload-keystore.jks
storePassword=<strong-password>
keyAlias=upload
keyPassword=<strong-password>
```

Bu dosyalar **repo'ya commit edilmez** (`android/play/.gitignore`).

CI secret'ları (one-time):

- `ANDROID_KEYSTORE_BASE64` = `base64 -i android/play/keystore/upload-keystore.jks`
- `ANDROID_KEYSTORE_PASSWORD` = strong password
- `ANDROID_KEY_ALIAS` = `upload`
- `ANDROID_KEY_PASSWORD` = strong password

## 2. Local release build (manual sanity)

```bash
cd android
JAVA_HOME=~/.local/jdk/jdk-21.0.11+10/Contents/Home \
ANDROID_HOME=~/Library/Android/sdk \
./gradlew :app:assembleRelease
```

Çıktı: `android/app/build/outputs/apk/release/app-release.apk`

```bash
ls -lh android/app/build/outputs/apk/release/*.apk
# bcwms-1.10.0(versionCode 110)-release.apk ≈ 8-12 MB
```

Doğrulama:

```bash
# 1. APK release signed mi?
~/Library/Android/sdk/build-tools/35.0.0/apksigner verify --verbose \
  android/app/build/outputs/apk/release/app-release.apk

# 2. v2 + v3 signature schemes aktif mi?
~/Library/Android/sdk/build-tools/35.0.0/apksigner verify --print-certs \
  android/app/build/outputs/apk/release/app-release.apk
```

Beklenen: "Verified using v2 scheme: true, v3 scheme: true", upload key
fingerprint görünmeli.

## 3. Cihaza yükle + smoke test

Test cihazı: BCWMSEmu (en az), tercih: gerçek bir Pixel/Samsung Android 12+.

```bash
# Önceki debug build'i kaldır (release ve debug imzalar farklı)
~/Library/Android/sdk/platform-tools/adb uninstall com.dynops.bcwms

# Release APK'yı yükle
~/Library/Android/sdk/platform-tools/adb install \
  android/app/build/outputs/apk/release/app-release.apk
```

Cihazda manuel test edilecek senaryolar (her biri yeşil olmalı):

- [ ] Splash → ana menü açılır, donmaz
- [ ] Top-bar'da `🔴 Bağlı değil` chip görünür (token yok henüz)
- [ ] **Bağlantı** ekranında `az` CLI ile token al + yapıştır + Test Connection
      → `200 OK` (sandbox URL'den)
- [ ] Çevrim `🟢 Bağlı` olur
- [ ] **License Plate** → liste yüklenir (HTTP 200)
- [ ] **Yazıcılar** → printer list 401 ise BC tarafında License Key girilmesi
      gerek; License Status `Active` iken liste yüklenir
- [ ] **Update channel**: cihazın `BuildConfig.VERSION_CODE` 110, manifest'in
      versionCode'u 110'dan büyük yapılırsa AlertDialog açılır → SHA-256
      mismatch testi: yanlış SHA → `Doğrulama başarısız`
- [ ] Cihaz uyutulup açıldığında oturum kalır

## 4. Play Closed Track'e yükle

```bash
# Yerel: gradle-play-publisher (CI ile aynı task)
JAVA_HOME=~/.local/jdk/jdk-21.0.11+10/Contents/Home \
ANDROID_HOME=~/Library/Android/sdk \
./gradlew :app:publishReleaseBundle -PwithPlayPublisher
```

Beklenen: Play Console'da Closed Testing track'te yeni release DRAFT olarak
görünür → "Roll out to internal testing" tıkla → tester listesindekiler
auto-update alır.

## 5. Üretim öncesi son checklist

- [ ] Adım 2'de `apksigner verify` PASS
- [ ] Adım 3'teki 8 manuel kontrol PASS
- [ ] Adım 4'te Play Console'da DRAFT görünüyor
- [ ] release.yml `android-publish` job geçen taglerde GREEN
- [ ] `latest.json` dosyası `https://app.bcwms.dynops.com/releases/android/latest.json`'da erişilebilir
- [ ] DynOps tarafından bir tester'ın gerçek cihazında Play Store update
      göründü ve install başarılı oldu

Bu checklist tamamlanmadan müşteri Play Store invitation linki almamalı.

## Sıkça karşılaşılan hatalar

| Hata | Olası sebep | Çözüm |
|---|---|---|
| `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | APK signing yok | `assembleRelease` çıktısı yerine `assembleDebug` yüklenmiş; doğru klasörü kontrol et |
| `apksigner: ... no APK Signature Scheme v2/v3` | minSdk yanlış | minSdk ≥ 24 zorunlu; build.gradle.kts kontrol |
| `Play Console: signature mismatch` | Upload keystore Play App Signing kaydından farklı | Play Console → Setup → App Signing'de upload key sertifikasını yeniden kaydet |
| `latest.json 404` | web-deploy job android-publish'in artifact'ini kopyalayamamış | release.yml log'unda `android-manifest/latest.json missing` warning aranır |
