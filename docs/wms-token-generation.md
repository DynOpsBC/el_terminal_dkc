# WMS Token Üretimi — Web ve Mobile Uygulama Bağlantısı

> **Hedef:** BCWMSApp web (tarayıcı) veya mobile (Android) operatör uygulamasını
> Business Central'a bağlayan AAD bearer token'ı kendi iş istasyonunuzdan
> üretin → uygulamaya yapıştırın → 🟢 Bağlı.
>
> **Mobil uygulama** çoğu zaman **Device Code Grant** (RFC 8628) ile otomatik
> bağlanır; manuel token sadece "Gelişmiş: token ile giriş" fallback'i içindir.
> **Web uygulaması** her seferinde manuel token gerektirir.

## Hızlı Başvuru

| | Web App | Mobile App |
|---|---|---|
| URL / APK | http://127.0.0.1:5173/ | [Releases sayfası](https://github.com/DynOpsBC/WMS/releases) |
| Login akışı | Token textarea | Device Code (default) **veya** "Gelişmiş: token ile giriş" |
| Token ömrü | ~1 saat | ~1 saat |
| Süre dolunca | Sağ üstte 🔴 Bağlı değil → Çıkış → yeni token | Aynı |
| Environment | `SandboxUS` | `SandboxUS` |
| Company | `CRONUS USA, Inc.` | `CRONUS USA, Inc.` |

## Yöntem 1 — Azure CLI (önerilen, her platform)

### Adım 1 — `az` kurulumu (bir kere)

```bash
# macOS
brew install azure-cli

# Windows (PowerShell admin)
winget install -e --id Microsoft.AzureCLI

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Detay: <https://learn.microsoft.com/cli/azure/install-azure-cli>

### Adım 2 — Tenant'a giriş (bir kere)

```bash
az login --tenant 7fa2357e-26f2-4174-8e16-a713981356b8
# Tarayıcı açılır → Deniz@dynamicsops.com ile giriş yap
```

### Adım 3 — Token üret + clipboard'a koy

**macOS:**

```bash
az account get-access-token \
  --resource "https://api.businesscentral.dynamics.com" \
  --query accessToken -o tsv | pbcopy
```

**Windows (PowerShell):**

```powershell
az account get-access-token `
  --resource "https://api.businesscentral.dynamics.com" `
  --query accessToken -o tsv | Set-Clipboard
```

**Linux (xclip):**

```bash
az account get-access-token \
  --resource "https://api.businesscentral.dynamics.com" \
  --query accessToken -o tsv | xclip -selection clipboard
```

Çıktıda hata yoksa **token clipboard'da** demektir (yaklaşık 2000+ karakter
uzunluğunda).

### Adım 4 — Uygulamaya yapıştır

**Web App:**
1. http://127.0.0.1:5173/ aç
2. Login ekranında "Token" textarea'sına ⌘V / Ctrl+V
3. "🔍 Discover Environments" (otomatik env+company seçer)
4. **🔓 Bağlan**

**Mobile App:**
1. APK'yı kur, uygulamayı aç
2. Login ekranında **"Gelişmiş: token ile giriş"** toggle'la aç
3. Textarea'ya token'ı yapıştır
4. Environment + Company gir → **Bağlan**

## Yöntem 2 — PowerShell + MSAL.PS (Windows odaklı)

```powershell
Install-Module MSAL.PS -Scope CurrentUser

$token = Get-MsalToken `
    -ClientId   "04b07795-8ddb-461a-bbee-02f9e1bf7b46" `
    -Authority  "https://login.microsoftonline.com/7fa2357e-26f2-4174-8e16-a713981356b8" `
    -Scopes     "https://api.businesscentral.dynamics.com/.default"

$token.AccessToken | Set-Clipboard
```

İlk çağrıda tarayıcı popup → SSO. Sonraki çağrılar cache'ten gelir.

## Yöntem 3 — Device Code (tarayıcısız sunucu)

Mobile uygulamanın yaptığı akışın CLI eşleniği:

```bash
# 1) Device code iste
curl -s -X POST \
  "https://login.microsoftonline.com/7fa2357e-26f2-4174-8e16-a713981356b8/oauth2/v2.0/devicecode" \
  -d "client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46" \
  -d "scope=https://api.businesscentral.dynamics.com/.default offline_access"
```

JSON çıktısındaki `user_code`'u not al + `verification_uri` (genelde
<https://microsoft.com/devicelogin>) tarayıcıda aç → user_code'u gir →
SSO ile giriş yap.

```bash
# 2) Tokeni topla
curl -s -X POST \
  "https://login.microsoftonline.com/7fa2357e-26f2-4174-8e16-a713981356b8/oauth2/v2.0/token" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
  -d "client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46" \
  -d "device_code=<bir önceki adımın device_code'u>" | jq -r .access_token
```

## BC Role Center'dan tek tıklama yardım

BC web client → Search (`Alt+Q`) → **"WMS Token Help"** ara →
sayfada komutlar kopyalanabilir form'da. Veya **DynOps WMS Role Center**'da
🔑 grubundan:

- **WMS Token Nasıl Alınır?** — bu sayfayı açar
- **Web App'i Aç** — http://127.0.0.1:5173/ yeni sekmede
- **Mobile APK İndir** — GitHub releases sayfası

## Güvenlik Notları

- Token **bearer secret**'tır. Slack/Teams/email/screen-share'de göstermeyin.
- 1 saatte yetkilendirme biter; tehdit modeli kabul edilebilir.
- Çıkış (Logout) butonu localStorage/SharedPreferences'tan token'ı siler.
- Üretim deployment için **mobile Device Code akışı** kullanın — manuel
  token kopyalama sadece geliştirici / kiosk senaryoları içindir.
- Token JWT decode edip kullanıcı bilgisini gösterir; dağıtmadan önce
  <https://jwt.ms> ile içerikten emin olun.

## Yaygın Sorunlar

| Belirti | Sebep | Çözüm |
|---|---|---|
| 🔴 Bağlı değil | Token süresi doldu | Çıkış → yeni token üret → yapıştır |
| `HTTP 401` her endpoint'te | Yanlış tenant/scope | `az account get-access-token` resource'unun `https://api.businesscentral.dynamics.com` olduğundan emin ol |
| `Discover Environments` boş | AAD kullanıcı BC'ye onboard değil | BC client'tan tenant admin ile kullanıcıyı ekle |
| Token 2000'den kısa | `-o tsv` yerine `-o json` kullanılmış (JSON wrapping eklemiş) | `-o tsv` flag'ini doğrula |
| Mobile "Code verifier missing" | Device Code session timeout | Login ekranını kapat, tekrar başlat |

## Otomatik Token Yenileyici (opsiyonel)

macOS launchctl/cron veya Windows Task Scheduler ile saatlik:

```bash
# crontab -e
0 * * * * az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv > ~/.bcwms-token
```

Web app'ı modify edip `~/.bcwms-token`'dan otomatik okuyacak hale getirmek
bir geliştirme görevidir — bu plan dışındadır.
