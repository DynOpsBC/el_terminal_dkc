# EMU / DKC bağımsız yayın akışı

Bu depo yalnız `com.dynops.bcwms.emu` paketini müşteriye yayınlar. Uygulama
güncellemeyi aşağıdaki sabit GitHub Release varlığından denetler:

`https://github.com/DynOpsBC/el_terminal_dkc/releases/latest/download/latest.json`

BADE paketi `com.dynops.bcwms.bade` farklı application ID ve farklı manifest
adresi kullandığı için EMU sürümünü yükleyemez. EMU da BADE APK'sını önermez.

## İlk GitHub kurulumu

Yeni GitHub reposunun Actions secrets bölümüne, sahadaki EMU APK'sını imzalayan
aynı anahtarın bilgileri eklenmelidir:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

İmza anahtarı değişirse Android mevcut uygulamanın üzerine güncelleme kurmaz.
Anahtar ve parolalar repoya commit edilmez.

## Yeni sürüm yayınlama

1. GitHub → Actions → **EMU Android Release** açılır.
2. **Run workflow** seçilir.
3. `1.14.48` biçiminde sürüm girilir.
4. İş akışı EMU testlerini ve lint'i çalıştırır.
5. İmzalı `BCWMS-EMU-<sürüm>-RELEASE.apk` ile SHA-256 içeren `latest.json`
   aynı GitHub Release içine yüklenir.
6. Terminalde **Güncellemeyi Kontrol Et** düğmesine basıldığında bu manifest
   okunur ve yalnız daha yüksek `versionCode` varsa kurulum önerilir.

## Yerel doğrulama

```bash
cd android
./gradlew :app:testEmuDebugUnitTest :app:lintEmuDebug :app:assembleEmuDebug
```

Release imzası yerelde mevcutsa:

```bash
./gradlew :app:assembleEmuRelease
```
