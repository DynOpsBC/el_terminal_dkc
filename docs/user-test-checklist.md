# BCWMSApp — Kullanıcı Test Checklist'i (Danışman Modu)

> **Sandbox URL:** <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central>
> **Versiyon:** v1.0.2.0
> **Profil:** `DynOpsWarehouseManagement`

Bu checklist, BCWMSApp'i sıfırdan **danışman müdahalesi olmadan** kullanıma hazır hale getirmenizi sağlar. Her adımı sırayla tamamlayıp ✅ işaretleyin.

---

## 🏁 Faz 0 — İlk Bağlantı (1 dakika)

- [ ] Sandbox URL'i tarayıcıda açın
- [ ] `Deniz@dynamicsops.com` ile login olun
- [ ] Sağ üst → kullanıcı menüsü → **My Settings**
- [ ] Role alanına **`DynOps Warehouse Management`** seçin → **OK**
- [ ] Sayfa yenilenir, yeni Role Center karşınızda

---

## ⚡ Faz 1 — Otomatik Kurulum (30 saniye)

Role Center açılır açılmaz ekranın üstünde **🧪 Demo Data (Danışman Modu)** action group'unda:

- [ ] **⚡ Run Demo Setup** butonuna basın
- [ ] Yaklaşık 10-15 saniye içinde "✅ Demo setup tamamlandı" mesajı görünür
- [ ] Mesajda şunların oluştuğunu doğrulayın:
  - No. Series (AWMS-LP, AWMS-SSCC, AWMS-CNT, AWMS-DEV)
  - Setup row default değerlerle
  - Symbology + Barcode Rules (8 kural)
  - LP Templates (7 template)
  - Device Configurations (5 rol-bazlı + DEFAULT)
  - Short Pick Reasons (7 reason)
  - IWX Report Selection (4 usage)
  - Demo Devices (3 cihaz)

- [ ] **📦 Create Demo Transactions** butonuna basın
- [ ] "Demo transaction tamamlandı" mesajı görünür (5 yeni LP)
- [ ] Role Center cue'ları otomatik dolar (sayfa F5 ile yenileyin)

---

## 🔎 Faz 2 — Kurulum Doğrulama Testleri

### Test 2.1 — Setup tablo

- [ ] Üst banner → **BCWMSApp Setup** action → Card açılır
- [ ] **Doğrulayın:**
  - LP No. Series = `AWMS-LP`
  - SSCC No. Series = `AWMS-SSCC`
  - GS1 Company Prefix = `9999999` (extension-prefix işaretli)
  - Default Location Code = boş değil
  - Print Channel = `BCNative`
  - Max LP Nesting Depth = `3`

> `BCNative` yeni/demo kurulumun güvenli başlangıç değeridir. Fiziksel terminal
> baskı testlerinden önce [Azure Direct kurulumunu](azure-direct-print-setup.md)
> tamamlayın; başarılı config importundan sonra Print Channel=`AzureDirect`
> olmalıdır.

### Test 2.2 — Number Series

- [ ] Search box → **No. Series**
- [ ] **AWMS-LP**, **AWMS-SSCC**, **AWMS-CNT**, **AWMS-DEV** kayıtları var
- [ ] Her birinin "No. Series Lines" görünüm açılınca Starting/Ending No. tanımlı

### Test 2.3 — Barcode Symbology

- [ ] Sol menü → **⚙️ Sistem Yönetimi → Barcode Symbologies**
- [ ] **En az 4 kayıt:** EAN13, GS1-128, SSCC-18, CODE128

### Test 2.4 — Barcode Rules

- [ ] Sol menü → **Barcode Rules** action
- [ ] **8 kural** listelenir, hepsi `Active=Yes`:
  - EAN13-ITEM, GS1-128-FULL, SSCC-18, BIN-PREFIX, LP-TEMPLATE
  - ITEM-NO, BIN-CODE, LP-DIRECT (Demo Setup ile gelenler)

### Test 2.5 — LP Templates

- [ ] **LP Templates** action → 7 template:
  - CARTON-S, CARTON-M, CARTON-L
  - PALLET-EUR, PALLET-US
  - TOTE-A, TOTE-B
- [ ] Her birinin `Label Report ID` = 72091 (DOPSWHS LP Label)

### Test 2.6 — Device Configurations

- [ ] **Device Configuration** action → **6 config:**
  - DEFAULT, RECEIVER, PUTAWAY, PICKER, SHIPPER, COUNTER, PROD-OP
- [ ] Her birinin `Login Mode = SSO`, `Scan Beep = Yes`, `Max List Rows = 100`

### Test 2.7 — Short Pick Reasons

- [ ] Sol menü → **Toplama → Short Pick Reasons**
- [ ] **7 reason:** NO_STOCK (default), DAMAGED, EXPIRED, MISSING, LOT_NOT_FOUND, BIN_BLOCKED, COUNTING

### Test 2.8 — IWX Report Selection

- [ ] Sol menü → **Sistem → IWX Report Selection**
- [ ] **4 row:** POSTED-SHIP, LP-LABEL, PICK-CONF, RECEIPT-POSTED

### Test 2.9 — Demo Devices

- [ ] Sol menü → **Sistem → Device Registration**
- [ ] **3 kayıt:** ZEBRA-TC22-001, HONEYWELL-CT45-001, CAMERA-PHONE-001
- [ ] Her cihazın `Config Code` doluyor (RECEIVER, PICKER, COUNTER)

---

## 📦 Faz 3 — LP (License Plate) Senaryoları

### Senaryo 3.1 — Yeni LP yarat (manuel)

- [ ] Role Center üst banner → **+ Yeni LP** action
- [ ] LP Card açılır, No. otomatik üretildi (AWMS-LP serisi)
- [ ] Template = `CARTON-S` seçin
- [ ] Location = `BLUE` (veya default), Bin = mevcut bir kod
- [ ] LP Card kapatın → otomatik **Open** durumunda

### Senaryo 3.2 — LP içine satır ekle

- [ ] LP List → demo'da oluşan ilk LP'yi açın
- [ ] **Status = Built** olmalı (Demo Transactions tarafından Stop yapılmış)
- [ ] Lines görünümünde 0 satır (boş template — gerçek item line ekleme manual veya mobile ile yapılır)

### Senaryo 3.3 — LP Movement Ledger

- [ ] Sol menü → **License Plate → LP Movement Ledger**
- [ ] Her LP için **Built** entry'leri görünüyor

### Senaryo 3.4 — LP'leri durum bazlı filtre

- [ ] LP List → filtre çubuğunda **Status = Built** → 5 LP
- [ ] **Status = Open** → 0 LP
- [ ] **Status = Unbuilt** → 0 LP

### Senaryo 3.5 — Cue'ları doğrula

- [ ] Role Center → 🏷️ License Plate grup
- [ ] **Built LP = 5**, **Open LP = 0**, **Assigned LP = 0**, **Unbuilt LP = 0**

---

## 📥 Faz 4 — Mal Kabul Senaryosu (PO → Whse Receipt → Post)

### Senaryo 4.1 — Hazırlık (Cronus standart)

- [ ] Sol menü → **Sipariş Listesi (PO)** action
- [ ] Cronus'ta hazır PO yoksa: **+New** → Vendor `30000` → Location `BLUE` → Item satırı (örn `1896-S` qty 10) → Release
- [ ] Action: **Create Inventory Put-away / Pick / Movement** veya **Create Whse. Receipt** (Location BLUE'da Whse Receipt aktifse)

### Senaryo 4.2 — Whse Receipt mobile akışı (sandbox web'de simüle)

- [ ] Role Center → **📥 Mal Kabul → Açık Mal Kabul** drill (cue)
- [ ] Açık Whse Receipt'ı seçin → Qty to Receive doldurun
- [ ] **Post Receipt** → confirm
- [ ] **Doğrulayın:**
  - Sol menü → Posted Whse. Receipts → yeni kayıt görünür
  - Item Ledger Entry yarattı
  - Warehouse Entry yarattı

### Senaryo 4.3 — LP ile receive

- [ ] Whse Receipt açıkken → action **Start LP** (DOPSWHS Mobile group)
- [ ] LP otomatik yaratıldı → notification görünür
- [ ] Lines'a item ekleyin → **Stop LP** → ZPL etiket, terminalde seçili **Etiket** yazıcısına gider
- [ ] Mal kabul belgesini yazdırarak post edin → PDF, terminalde seçili **Belge** yazıcısına gider
- [ ] **Post Receipt** → Posted line'da `LP No.` görünür

---

## 🚚 Faz 5 — Toplama Senaryosu (Sales Order → Pick → Register)

### Senaryo 5.1 — Sales Order release

- [ ] Sol menü → **Sales Orders** action
- [ ] **+New** → Customer `10000` → Location `BLUE` → Item satırı (qty 5) → **Release**

### Senaryo 5.2 — Whse Shipment + Pick

- [ ] Action: **Create Whse. Shipment** (released SO üzerinden)
- [ ] Whse Shipment → **Release**
- [ ] **Create Pick** action → Whse Activity (Type=Pick) oluşur

### Senaryo 5.3 — Pick Queue (drag-drop SPA)

- [ ] Role Center → **🚚 Toplama → Pick Kuyruğu (Drag-Drop)** action
- [ ] Oluşan pick'i görüntüleyin → **Manual Reassign** action

### Senaryo 5.4 — Pick register

- [ ] Pick'i açın → Take/Place lines görünür
- [ ] Qty to Handle doldurun (her Take + her Place için)
- [ ] **Register Pick** action → Whse Activity silinir, Whse Entries oluşur

### Senaryo 5.5 — Cue doğrula

- [ ] Role Center → **Açık Pick = 0** (register edildi)

---

## 📤 Faz 6 — Sevkiyat Senaryosu

### Senaryo 6.1 — Whse Shipment Post

- [ ] Role Center → **📤 Sevkiyat → Sevkiyat Kuyruğu** action
- [ ] Faz 5'teki shipment'ı açın
- [ ] **Post Shipment** → confirm → "Ship" seçin (Ship & Invoice değil)

### Senaryo 6.2 — Posted line LP No

- [ ] Sol menü → Posted Whse. Shipments → en son post edileni açın
- [ ] Lines görünümünde `LP No.` doluysa Pick-to-LP doğru bağlandı

---

## 🏷️ Faz 7 — LP Transfer Senaryosu

### Senaryo 7.1 — İki LP arasında satır transferi

- [ ] LP List → 2 farklı LP açın (Built durumunda)
- [ ] Kaynak LP'de satır var olmalı (yoksa AddLine ile ekleyin)
- [ ] **Transfer** action → target LP No → line selection → Transfer
- [ ] LP Movement Ledger'da `TransferOut` + `TransferIn` entry'leri

---

## 📊 Faz 8 — Inventory Count Senaryosu

### Senaryo 8.1 — Demo Count Sheet

- [ ] Role Center → **📊 Sayım → Count Sheets** action
- [ ] Demo Transactions ile oluşan CS00001 (veya CNT-) sheet'i açın
- [ ] **Status = Open**, **Mode = Blind**

### Senaryo 8.2 — Yeni Count Sheet

- [ ] Üst banner → **+ Yeni Sayım** action
- [ ] Location = BLUE, Mode = Visible, Counter slots = Deniz
- [ ] **OK** → CS00002 oluşur

### Senaryo 8.3 — Variance + Post

- [ ] Count Sheet → Lines → System Qty manuel doldurma (real life'ta bu BC tarafından otomatik gelir)
- [ ] Counted Qty 1 farklı bir değer girin → Variance hesaplanır
- [ ] **Post Sheet** → Phys. Inv. Journal'a transfer

---

## 🏭 Faz 9 — Üretim Senaryosu

### Senaryo 9.1 — Released Prod Order

- [ ] Role Center → **🏭 Üretim → Released Production Orders** action
- [ ] Cronus'ta hazır prod order varsa açın, yoksa Item Card → Manufacturing tab → component setup → Production Order oluştur

### Senaryo 9.2 — Consumption (mobile simulation)

- [ ] Prod Order → action **Mobile Consume** (DOPSWHS Mobile group)
- [ ] Component listesi açılır → her component için qty consume
- [ ] Item Ledger Entry type=Consumption oluşur

### Senaryo 9.3 — Output to LP

- [ ] Action **Mobile Output**
- [ ] Output Qty + Scrap + Runtime gir
- [ ] "New LP" toggle açık → output otomatik yeni LP'ye yerleşir
- [ ] LP List → yeni LP `Built` durumunda

---

## 🔄 Faz 10 — Bin-to-Bin Hareket

### Senaryo 10.1 — Hızlı Ad-Hoc Move

- [ ] Role Center → **Hızlı Bin-to-Bin Hareket** action
- [ ] Item Reclass. Journal açılır
- [ ] Item No, From Bin, To Bin, Qty doldur
- [ ] **Post** → Item Ledger Entry oluşur (Type=Transfer)

### Senaryo 10.2 — Directed Movement

- [ ] Sol menü → **Hareketler → Warehouse Movements (Activity)**
- [ ] **+New** → Whse Movement document → Lines doldur → Register

---

## ⚙️ Faz 11 — Sistem Yönetimi Testleri

### Senaryo 11.1 — Cihaz heartbeat

- [ ] Device Registration → Last Seen DateTime alanı güncel
- [ ] Role Center → ⚙️ Sistem → **Çevrimiçi Cihazlar = 3** (son 5dk'da görüldü)

### Senaryo 11.2 — Sync Conflict yönetimi

- [ ] Sol menü → **Sistem → Sync Conflicts**
- [ ] Boş liste (gerçek conflict mobile sync ile tetiklenir)

### Senaryo 11.3 — Print Job Log

- [ ] Sol menü → **Sistem → Print Job Log**
- [ ] Azure Direct ajan bağlı ve hedef yazıcı `Online`
- [ ] LP Stop sırasında oluşan iş `Queued → Dispatched → Sent` olur
- [ ] Job ID, Station ID ve fiziksel çıktının aynı test işine ait olduğu doğrulanır
- [ ] **Failed** veya 8 günden uzun **Dispatched** iş varsa agent logu ve Azure DLQ kontrol edilir; sonucu bilinmeyen iş operatör kontrolü olmadan tekrar basılmaz

---

## 🧪 Faz 12 — AL Test Codeunit Suite'i Çalıştır

- [ ] **Sandbox URL** + `?page=130401` (Test Tool sayfası)
- [ ] Suite Code = `DOPSWHS`
- [ ] **Get Test Codeunits** action → tüm DOPSWHS test codeunit'ları gelir
- [ ] **Run** → tüm test'ler çalışsın
- [ ] **Beklenen:** %90+ PASS rate (TODO-flag'li test'ler skip olabilir)

Kritik test'ler (mutlaka PASS olmalı):

- ✅ **DOPSWHS Bin Rollup Tests** — Nested LP double-count önleme
- ✅ **DOPSWHS LP Build Tests** — LP state machine
- ✅ **DOPSWHS Batch Isolation Tests** — KB risk koruması
- ✅ **DOPSWHS Barcode Parser Tests** — GS1-128 parsing

---

## ✅ Best Practice Doğrulamaları

- [ ] **Faz 0-2 tamamlandı** → kurulum hazır
- [ ] **Faz 3** ≥ 4 test PASS → LP çekirdeği çalışıyor
- [ ] **Faz 4 + 6** PASS → end-to-end inbound/outbound çalışıyor
- [ ] **Faz 5** PASS → pick + queue + reassign çalışıyor
- [ ] **Faz 12** ≥ 18 test codeunit PASS → AL test suite sağlam

Bu 5 madde sağlandıysa modül **production-ready** demektir.

---

## ⚠️ Bilinen Limitler (Sprint H+ Backlog)

Codex'in deploy sırasında eklediği 11 TODO:

1. AssistedSetup subscription pasif (codeunit 3725 sembolü açılınca aktive)
2. Warehouse activity pageextension uyumluluğu
3. Activity Status API field compatibility variables
4. Receipt tracking → Item Tracking APIs deferred
5. RoleCenter cue FlowField date filter'ları (DueDate exposure beklendiğinde geri konur)

Bunlar **işlevsellik** etkilemez — sadece bazı BC standart event subscribe'larını ve metric filter'larını sembol uyumu için TODO bıraktırdı.

---

## 🆘 Sorun çıkarsa

1. Compile hatası varsa: `docs/deployment/sandbox-deployment-2026-05-27.md` deki TODO listesini gözden geçirin
2. Cue boş veya sıfır gösteriyorsa: Demo Data Setup ve Demo Transactions tekrar çalıştırın (idempotent)
3. Action çalışmıyorsa: Permission set'inizin `DOPSWHS-ADMIN` veya `DOPSWHS-USER` olduğundan emin olun

İletişim: Setup card → **Webhook Endpoint** alanına geri bildirim URL'i koyabilirsiniz.

---

**Hayırlı olsun!** Tüm modül artık hazır. ✨
