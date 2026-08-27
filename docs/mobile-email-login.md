# BCWMS Mobil — E-posta ile Giriş (Device-Code) + Ortam/Şirket Seçimi

> Token yapıştırma yerine **e-posta ile giriş**: OAuth 2.0 Device Authorization Grant (MSAL kütüphanesi
> gerekmez — düz HTTP). Giriş sonrası **ortamlar ve şirketler listelenir**, kullanıcı seçip bağlanır.
> Mobil **v1.8.0**.

## Akış

1. **E-posta** ekranı → kullanıcı e-postasını girer → **Giriş Yap**.
2. **Device-code** ekranı → app bir `user_code` gösterir (örn. `CCEBRFHZ8`) + `login.microsoft.com/device`
   + **🌐 Tarayıcıda Aç**. App arka planda token endpoint'ini poll eder.
3. Kullanıcı tarayıcıda e-posta + şifre/MFA ile giriş yapıp kodu onaylar.
4. App token'ı alır → **ortamları keşfeder** (her bilinen environment'ta `GET /api/v2.0/companies`):
   + **SandboxUS** → CRONUS USA, Inc. · My Company
   + **CustomerSandbox** → Demo Business Central · Developer Test · Medef Demo · …
5. **Ortam seç** + **Şirket seç** → kaydedilir, bağlanır (testConnection HTTP 200 → 🟢 Bağlı).

> **Gelişmiş: token ile giriş** — eski az-CLI token yapıştırma akışı fallback olarak kalır.

## Teknik

+ **`DeviceAuth.kt`** — `requestCode()` (POST `/oauth2/v2.0/devicecode`), `pollForToken()` (POST `/token`,
  `authorization_pending`/`slow_down` semantiği). Client: `BcApi.CLIENT_ID` (public client, device-code
  açık), tenant `BcApi.TENANT`, scope `…/.default offline_access`.
+ **`BcApi`** — environment/company artık **runtime** (SharedPreferences): `getEnvironment/getCompanyId/
  getCompanyName`, `setEnvironment/setCompany`. `discoverEnvironments(token)` → ortam→şirket listesi.
  `KNOWN_ENVIRONMENTS = [SandboxUS, CustomerSandbox]`.
+ **`LoginFlow.kt`** — 3 adımlı Compose akışı + token fallback. Bağlantı ekranı (⚙️) bunu kullanır.

## AAD önkoşulu (sağlandı)

+ App `BCWMSApp Mobile (sandbox)` (`8193e5c6-…`) **public client / device-code** açık
  (`isFallbackPublicClient = true`). Delegated `Dynamics 365 Business Central / user_impersonation`.

## Doğrulanan (emulator, v1.8.0)

+ E-posta ekranı render edildi; **Giriş Yap** → device-code endpoint `user_code: CCEBRFHZ8` döndü,
  tarayıcı device-login sayfasına açıldı.
+ Keşif (curl ile): her iki ortamın şirketleri listelendi.
+ Dinamik başlık: "BC: SandboxUS / CRONUS USA, Inc." (runtime seçim çalışıyor).
+ Tam tarayıcı girişi kullanıcı kimlik bilgisi gerektirir (otomatik tamamlanamaz) — kullanıcı tamamlar,
  sonra ortam/şirket seçici görünür.

## Not

APK: `~/Desktop/BCWMSApp-v1.8.0-EmailLogin.apk`. Kullanıcı: e-posta gir → Giriş Yap → Tarayıcıda Aç →
e-posta ile giriş → ortam + şirket seç → 🟢 Bağlı.
