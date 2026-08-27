# BCWMS Mobil App — Son Kullanıcı Quickstart

Bu rehber, BCWMS Android uygulamasını yeni yükleyen bir operatörün
ilk girişini ve günlük kullanıma hazır hale gelmesini kapsar.

> **Örnek kullanıcı:** `kaanodabas@dynamicsops.com`
> **Hedef BC ortamı:** SandboxUS / CRONUS USA, Inc.
> **Atanacak rol:** INV_ADMIN (veya PICKER, RECEIVER, COUNTER vb.)

---

## 1. Ön koşul — Admin'in yapması gerekenler

Aşağıdaki 3 adım **denizcelan@dynamicsops.com (BC admin)** tarafında
tamamlanmalı; bunlar yapılmadan operatör login olamaz.

### 1a. M365 lisans

1. <https://admin.microsoft.com> → **Users → Active users → Add a user**
2. Display name: `Kaan Odabas` · Username: `kaanodabas@dynamicsops.com`
3. **Licenses** → `Dynamics 365 Business Central Premium` (veya
   `Essentials`) seç → Save
4. Geçici parola → Kaan'a güvenli kanaldan paylaş (parola ilk girişte
   değiştirilir)

### 1b. BC user sync + permission

1. BC sandbox URL'e git:
   <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/SandboxUS>
2. **Tell me (?icon) → "Users"** sayfasını aç
3. **Get users from Microsoft 365** action → Kaan listede görünür
4. Kaan'ın satırında **Permission Sets** → `D365 BUS PREMIUM` ata

### 1c. WMS rolü ata

Yöntem 1 — BC UI (en hızlı):

1. Search → **"App User Roles"** sayfasını aç (page 72277)
2. **New** → User ID: `kaanodabas@dynamicsops.com` · Role Code: `INV_ADMIN`
3. Save

Yöntem 2 — Komut satırı (admin makinede):

```bash
export BC_TOKEN=$(az account get-access-token \
  --resource https://api.businesscentral.dynamics.com \
  --query accessToken -o tsv)
./tools/wms-add-user.sh kaanodabas@dynamicsops.com INV_ADMIN
```

> ⚠️ Bu adımdan önce DOPSWHS extension v1.10.0+ BC'ye publish edilmiş
> olmalı (page 72279 `appUserRoles` API'sini içerir). Eski paket
> v1.8.2.0 ise UI yolunu (Yöntem 1) kullanın.

---

## 2. Kaan'ın yapacağı — App'i bağlama

### 2a. Uygulamayı yükle

Daha önce yapılmadıysa: [docs/android-install-guide.md](android-install-guide.md)
adımlarını izle. Telefonda menüde "BCWMS" simgesi görünmeli.

### 2b. Bağlantı ekranını aç

1. App'i aç → Ana Menü görünür · sağ üstte 🔴 **Bağlı değil** badge'i
2. Sağ alt köşedeki ⚙️ **Bağlantı** tile'ına dokun (veya badge'e dokun)

### 2c. Email ile giriş (Device Code akışı — önerilen)

1. **Email** alanına `kaanodabas@dynamicsops.com` yaz → **Giriş**
2. Ekranda 8-karakterlik bir kod + URL belirir (örn:
   `Kod: XYZW-9876, URL: https://microsoft.com/devicelogin`)
3. Aynı telefonda (veya başka bir cihazda) tarayıcı aç →
   <https://microsoft.com/devicelogin>
4. Kodu yapıştır → **Next** → MS oturum açma → email + parola + MFA
5. "BCWMS WarehouseClient is trying to sign you in" → **Continue**
6. App ekranı **🟢 Bağlı** olur, otomatik **Environment + Company**
   seçim ekranına geçer

### 2d. Environment + Company seç

1. **Environment** dropdown: `SandboxUS` (veya admin sana hangisini
   söyledi)
2. **Company** dropdown: `CRONUS USA, Inc.`
3. **Devam** → Ana Menü'ye dön

### 2e. Local kullanıcı adı (opsiyonel)

Cihazda birden fazla kişi rotasyonla çalışıyorsa kim'in işlemi yaptığı
audit log'a düşsün diye **Local Kullanıcı** alanı doldurulur.
Tek-operatör cihazda boş bırakılabilir.

---

## 3. Bağlantı doğrulaması — 🩺 Sistem Sağlığı

Ana Menü → 🩺 **Sistem Sağlığı** → **▶ Tümünü Çalıştır**

Beklenen: **9 ✅ + 1 ⏭** (Default printer atanmadığı için skip).

| Eğer | O zaman |
|---|---|
| Hepsi PASS | ✓ Hazır, üretime başla |
| **Token süresi geçerli mi?** ❌ | Token expire olmuş — Bağlantı ekranından yeniden giriş |
| **warehouse/v2.0 ulaşılabilir mi?** ❌ + HTTP 401 | Token geçerli ama BC permission set eksik — admin'e haber ver |
| **BinContentApi page 72097** ❌ + HTTP 404 | DOPSWHS extension eski sürüm; admin v1.10.0'ı publish etmeli |
| **LP templates seed edilmiş mi?** ❌ | BC'de hiç LP Template yok — admin Setup ekranından demo template ekleyebilir |
| **ScanBus emit + collect** ❌ | App içi bus sorunlu — uygulamayı kapat-aç |

---

## 4. İlk operasyonel test

Bağlandıktan sonra şu sırayla 5 dakikalık smoke test yapın:

| # | Adım | Beklenen |
|---|------|----------|
| 1 | 🔎 **Item Inquiry** → `1000` ara | "1000" + stok bloğu (Stok / Müsait / Rezerve) görünür |
| 2 | 📍 **Bin Inquiry** → Lokasyon `SILVER` + Bin `S-1-01` | İçerik tablosu + LP listesi |
| 3 | 📦 **License Plate** → ➕ **Build LP** | Template dropdown'unda en az 1 şablon listelenmeli |
| 4 | 🚚 **Toplama** → mevcut bir pick belge | "Tara & Tamamla" + "Tamamla" + "Short" buton seti |
| 5 | 🏭 **Posting Test** → ▶ Tüm Postingleri Test Et | 4 kategorili sonuç (Passed / Real / Setup eksik / Atlandı) |

---

## 5. Günlük kullanım

- **🔴 Bağlı değil** badge'i tekrar gözükürse: Bağlantı ekranından
  email ile yeniden giriş yap (token süresi ~1 saat)
- Zebra TC22/TC52 cihazda kullanıyorsan sarı tetik aktif alana
  barkod yazar — kamerayı manuel açmaya gerek yok (DataWedge profile
  setup için [zebra-datawedge-setup.md](zebra-datawedge-setup.md))
- Sevkiyat / Mal Kabul ekranlarında **belge no arama** kutusu — uzun
  listede tek bir PO'yu hızlı bulmak için

## Sorun → Çözüm tablosu

| Sorun | Yapılacak |
|---|---|
| "Email tanınmıyor" | Admin M365 invite yaptı mı? (1a) |
| "AADSTS50105" | BC Premium lisans atanmamış (1a son adım) |
| "401 unauthorized" — her endpoint | BC Permission Set eksik (1b) |
| "WMS rolünüz yok" | AppUserRole satırı eklenmemiş (1c) |
| "Posting Test'te 4 Setup Eksik" | BC tarafında Inventory Posting Setup boş — admin doldurmalı (`docs/wms-token-generation.md` referansları) |
| Bütün 9 check FAIL | DOPSWHS extension publish edilmemiş veya yanlış environment |

İrtibat: BC admin **denizcelan@dynamicsops.com**.
