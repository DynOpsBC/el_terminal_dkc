# Zebra DataWedge Setup — BCWMS El Terminali

BCWMS Android app'i Zebra TC22 / TC52 / TC58 cihazlarındaki **donanım barkod
tarayıcısını** (sarı tetik tuşu) destekler. Bu desteğin çalışması için
**her test/üretim cihazında bir defa** DataWedge profili oluşturulmalıdır.
Bu doc adım adım yapılandırmayı + simülasyon test akışını içerir.

## Önkoşullar

- Zebra Android cihaz (DataWedge önyüklü gelir, Settings → Apps listesinde
  "DataWedge" görünür)
- BCWMS uygulaması cihaza yüklü (`com.dynops.bcwms` paket adı)
- Cihaz Android 10+ (DataWedge ≥ 8.0)

## 1. DataWedge profili oluştur

1. Cihazda **DataWedge** uygulamasını aç (uygulama çekmecesinden).
2. Sağ üst menü → **New profile** → İsim: `BCWMS`.
3. Yeni profili tıklayıp aç.
4. **Profile enabled** ✓ (üst toggle).

## 2. Associated apps (sadece BCWMS tetiklesin)

5. **Associated apps** → **+** → seçin:
   - Package name: `com.dynops.bcwms`
   - Activity: `*` (tüm activity'ler — MainActivity zaten singleTop)
6. Geri.

## 3. Intent output (kritik adım)

7. **Intent output** → **Enabled** ✓ (toggle).
8. **Intent action**: `com.dynops.bcwms.SCAN`
9. **Intent category**: `android.intent.category.DEFAULT`
10. **Intent delivery**: **Send via startActivity** (en güvenilir;
    MainActivity intent-filter'a kayıtlı).

> ⚠ `Broadcast intent` veya `Send via startService` SEÇMEYİN. Bunlar bizim
> kod tarafımız tarafından dinlenmiyor; sadece startActivity destekli.

## 4. Keystroke output (KAPALI olmalı)

11. **Keystroke output** → **Disabled** ✗.

> Eğer hem Intent hem Keystroke açıksa barkod iki kez işlenir — alana iki
> kere yazılır. Sadece Intent açık olsun.

## 5. Barcode input (önerilen ayarlar)

12. **Barcode input** → **Enabled** ✓.
13. **Decoders** alt menüsünde aktif olması gerekenler:
    - **Code 128** (item barkodu)
    - **EAN-13 / UPC-A** (perakende item)
    - **GS1-128** (GS1 lot/serial)
    - **GS1 DataBar** (SSCC)
    - **Data Matrix** (lot, expiry)
    - **QR Code** (LP no, vs.)
14. **Scan params** → **Decode haptic feedback** ✓, **Decode audio
    feedback** ✓ (operatörün başarılı taramayı duyup hissetmesi).

## 6. Profili kaydet

15. DataWedge'i geri tuşuyla kapat (otomatik kaydeder).

## 7. Test

Uygulamayı aç → herhangi bir **Item No** veya **LP No** alanına dokun
(focus al). Sarı tetik tuşuna bas:
- Cihaz beep + titreme → barkod okundu.
- Aktif text field'a barkod yazılır.
- BarcodeIntentResolver çalışır (GS1 ise lot/serial parse edilir, SSCC ise
  LP olarak yönlendirilir).

## Emülatörde simülasyon (geliştiriciler için)

DataWedge sadece Zebra cihazlarda çalışır. Emülatörde test için:

```bash
adb shell am broadcast -a com.dynops.bcwms.SCAN \
  --es com.symbol.datawedge.data_string "1000" \
  --es com.symbol.datawedge.label_type "LABEL-TYPE-CODE128" \
  -n com.dynops.bcwms/.MainActivity
```

Veya intent'i activity'e direkt iletmek için:

```bash
adb shell am start -a com.dynops.bcwms.SCAN \
  --es com.symbol.datawedge.data_string "LP000001" \
  -n com.dynops.bcwms/.MainActivity
```

Beklenen: aktif ScanField'a `1000` veya `LP000001` yazılır.

## Çoklu cihaza dağıtım (auto-import)

Tek tek manuel ayarlamak yerine **DataWedge Profile Export** kullanın:

1. Bir cihazda yukarıdaki adımları tamamlayın.
2. DataWedge sağ üst menü → **Export profile** → cihazın storage'ına
   `BCWMS-DataWedge.db` dosyası iner.
3. Bu dosyayı `bcwms-print-agent` repo'sundaki release artifact'iyle
   birlikte müşteriye verin.
4. Müşteri her yeni cihaza `/sdcard/Android/data/com.symbol.datawedge/files/`
   dizinine kopyalar + DataWedge'i restart eder (Settings → Apps →
   DataWedge → Force stop → tekrar aç).

## Sorun giderme

| Belirti | Olası sebep | Çözüm |
|---|---|---|
| Sarı tetik basıyorum, bir şey olmuyor | Profili "Associated apps" listesinde com.dynops.bcwms yok | Adım 5'i kontrol |
| Barkod alana iki kere yazılıyor | Hem Intent hem Keystroke açık | Adım 11 — Keystroke'u kapat |
| Tarama başka activity'i açıyor | launchMode `standard` (default) | AndroidManifest.xml'de `android:launchMode="singleTop"` olmalı (zaten ayarlı) |
| Operatör beep/titreme almıyor | Adım 14 ayarları | DataWedge profil parametrelerine bak |
| ScanField'a yazıyor ama yanlış alana | Focus alanı yanlış | ScanField focused olduğunda dinler — operatör önce alana dokunmalı |

## Mimari notları

- `MainActivity.onNewIntent()` her DataWedge intent'ini alır.
- `ScanBus` (singleton, `MutableSharedFlow`) bu intent'i parse eder ve
  `events` flow'una emit eder.
- `ScanField` `interactionSource.collectIsFocusedAsState()` ile focus
  durumunu izler ve sadece focus'tayken `ScanBus.events` collect eder.
- Kamera fallback path'i (ML Kit) korunmuştur — Zebra olmayan cihazlarda
  `📷` butonu çalışır.
