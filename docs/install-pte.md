# Per-Tenant Extension (PTE) Install Guide

DynOps müşterilerinin BCWMSApp'i kendi BC SaaS ortamlarına yüklemeleri için
adım adım rehber. ~10 dakikalık bir işlem; üretim öncesi mutlaka bir
sandbox'ta deneyin.

## Ön koşullar

| Gereksinim | Açıklama |
|---|---|
| BC SaaS sürümü ≥ 24.0 | `Help → About Business Central` → version `24.x.x.x` veya üstü |
| AAD admin yetkisi | Tenant'ta Global Admin veya BC Admin Center'a erişim |
| Microsoft Quality Management (BC v28+ first-party uzantısı) | Dependency: app.json'da declared. Pre-installed gelir BC v28'de |
| `BCWMSApp-X.Y.Z.W.app` paketi | [GitHub Releases](https://github.com/DynOpsBC/WMS/releases/latest) → "Assets" → `bcwmsapp-X.Y.Z.W.app` |
| (opsiyonel) DynOps Customer Portal hesabı | https://portal.bcwms.dynops.com — lisans + sürüm yönetimi |

## Adımlar

### 1. Sandbox ortamına yükle

1. **BC Admin Center** (`https://businesscentral.dynamics.com/<aadtenant>/admin`) → açın
2. **Environments** → sandbox ortamınızı seçin (yoksa "Create new environment" → Sandbox tipi → ülke `US` veya `TR`)
3. **Apps** → "Manage Apps" → top bar'da **Upload Extension** butonuna tıklayın
4. **Browse** → indirdiğiniz `bcwmsapp-X.Y.Z.W.app` dosyasını seçin
5. Açılan dialogda:
   - Deploy to: **Production-like (with data loss if needed)** seçin (sandbox)
   - Accept EULA + privacy statement → "Deploy"
6. Sayfada deployment status'u "In progress" olur → ~3-5 dakika içinde "Success"

### 2. Lisans key'ini gir

1. BC Web Client'a giriş yap (`https://businesscentral.dynamics.com/<aadtenant>/<env>`)
2. Search (`Alt+Q`) → `Advanced WMS Setup` → enter
3. "License" group:
   - **License Service URL** = `https://bcwms-licensing-func.azurewebsites.net`
   - **License Key** = portal.bcwms.dynops.com'dan kopyaladığınız JWT (uzun string)
4. Sayfa otomatik verify yapar (1-2 saniye). "License Status" alanı:
   - **Active** → tüm fonksiyonlar açık
   - **Invalid / Expired** → DynOps'a başvurun
5. "Verify License Now" action'ı ile manuel re-verify yapılabilir

### 3. Demo data + first-run

1. Aynı Setup card'da:
   - **Run Demo Setup** → No. Series, LP templates, device configs (~10sn)
   - **Create Demo Transactions** → 5 LP + 1 count sheet
2. Search → `License Plate List` → demo LP'leri görün
3. Search → `DOPSWHS Role Center` → role center'ı kendi profil olarak set edin
   (User Personalization → "Choose role center")

### 4. Web + Mobile clients

#### Web
- `https://app.bcwms.dynops.com` adresini açın
- **Login** → AAD token'ı yapıştırın (terminal'de `az account get-access-token`)
- Çevrim "🟢 Bağlı" olduğunda hazır

#### Mobil (Android)
- Play Store (Closed Testing track'e davetli iseniz):
  - Tester davet linkini açın → "Become a tester" → Play Store'a yönlendirir
  - "Install" → BCWMS auto-update Play üzerinden gelir
- Sideload (Play Store'a erişim yoksa):
  - GitHub Releases → `bcwms-X.Y.Z.apk` indirin
  - Cihazda "Bilinmeyen kaynaklardan kuruluma izin ver" açın
  - APK'yı yükleyin → İlk açılışta uygulama yeni sürüm kontrolü için
    `app.bcwms.dynops.com/releases/android/latest.json` URL'ini sorgular

### 5. Üretime taşıma

1. Sandbox'ta tüm fonksiyonları test et (özellikle LP create / pick / ship,
   tier'a göre Print Bridge + MS QM + Production)
2. BC Admin Center → **Production** environment → Apps → Upload Extension
   → aynı .app dosyası
3. Lisans key'ini production Setup'a tekrar gir (sandbox key'i prod'da
   çalışmaz — `tid` claim'i farklı tenant ID'ye işaret edebilir)

## Otomatik update

PTE upload'da "Update behavior" ekranında **Automatic** seçildiğinde
Microsoft sonraki .app sürümlerini (aynı `id` + büyük `version`) background
deployment ile yükler — downtime yok.

Bizim portal manuel update'i şu şekilde tetikler:
1. https://portal.bcwms.dynops.com → Releases → yeni sürüm satırında
   "Şimdi yükselt" butonu
2. Portal → BC Admin Center upgrade API'sini çağırır
3. ~5 dakika içinde yeni sürüm aktif

### Portal "Şimdi yükselt" için tek seferlik AAD yapılandırması

Portal'ın `/api/bc/trigger-update` fonksiyonu BC Admin Center API'sini
müşterinin AAD tenant'ı altında çağırır. Bu çağrı için **müşteri tenant
admin'i**nin bir defaya mahsus aşağıdaki adımları yapması gerekir:

1. DynOps tarafı portal'ın managed identity service principal'ının
   `appId`'sini ve display name'ini (`bcwms-portal-api`) müşteriye iletir.
2. Müşteri admin BC Admin Center'da
   (`https://businesscentral.dynamics.com/<aadtenant>/admin`) →
   **Environments → <env> → App Registrations** sayfasını açar.
3. **+ New** ile `bcwms-portal-api` AppId'sini ekler ve `D365 Automation`
   permission set'ini seçer (veya en az `D365 BUS PREMIUM` + tenant-level
   `Admin Center API` izni).
4. Sayfa "Status = Active" gösterene kadar bekle (~2 dakika).
5. Portal'da "Şimdi yükselt" butonu ilk denemede `401` döner ise bu adımın
   tamamlandığını doğrula; izin propagation'ı ~15 dk sürebilir.

> Bu adım yapılmazsa "Şimdi yükselt" her zaman `502` döner; PTE upload'ı
> elle BC Admin Center'dan yapmaya devam edilebilir.

## Sorun giderme

| Belirti | Olası sebep | Çözüm |
|---|---|---|
| Upload sırasında "Dependency missing" | Quality Management eksik | BC v28 garantili, v27.x'te marketplace'ten yükleyin |
| Setup'ta `License Status = Offline` | Function URL ulaşılamıyor | İlk verify ile cache 7 gün grace; URL/firewall kontrol |
| `License Status = Invalid` | JWT geçersiz veya `tid` farklı | Portal'dan yeni JWT issue edin |
| LP card'da QC banner görünmüyor | MS QM bağımlılığı yüklenmemiş | Admin Center → Apps listesinde "Quality Management" var mı |
| Print job'lar `Queued`'da kalıyor | Print Channel SelfHosted ama agent yok | docs/print-bridge-setup.md |
| Mobile app `🔴 Bağlı değil` | Token expired veya yanlış tenant | Mobile Connection → Yeni token yapıştırın |

## Sürüm geriye alma

PTE'lerde rollback için Microsoft'un built-in "Restore environment" feature'ı
kullanılır (BC Admin Center → ⓘ Environment → Restore). Daha hızlı yöntem:
mevcut .app'i kaldırıp eski sürümü yükleyin (data shape backward-compatible
ise sorun yok; v1.10.0 öncesi rollback yapacaksanız önce sandbox'ta test edin).
