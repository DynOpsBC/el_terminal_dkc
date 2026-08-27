# BCWMSApp — Ürün Genel Bakış ve Çalışma Kılavuzu

> **Sürüm:** v1.7.1.0 — son yayın 2026-06-02 (SandboxUS + CustomerSandbox)
> **Kapsam:** Bu doküman BCWMSApp'in tüm bileşenlerinin nasıl çalıştığını uçtan uca açıklar. Spesifik konular için referans dokümanlara link verir.

## 1. BCWMSApp Nedir?

**BCWMSApp**, Microsoft Dynamics 365 Business Central SaaS üzerine inşa edilmiş kapsamlı bir **Gelişmiş Depo Yönetim Sistemi (Advanced Warehouse Management System)** uzantısıdır. Warehouse Insight'a fonksiyonel parite hedefiyle tasarlanmıştır.

**Hedef kullanıcılar:**

- Depo operatörleri (mobil handheld cihazlar üzerinden mal kabul, toplama, sevkiyat, sayım, kalite, üretim)
- Depo yöneticileri (BC Role Center, KPI cue'lar, raporlar)
- Sistem yöneticileri (kurulum, kullanıcı/rol yönetimi, ayarlar)

**Çözdüğü problemler:**

- Standart BC'de eksik olan License Plate (LP) konsepti — pallet/carton hiyerarşisi, SSCC kodları, nest hierarchy
- Operatör seviyesinde mobil-öncelikli iş akışı (BC web client değil, native Android)
- Rol bazlı sunucu-taraflı görünürlük (her kullanıcı sadece kendi atanmış işini görsün)
- Cronus dışı veriyle çalışan otomatik test sistemi (50 E2E test case)
- AppSource yayını için tam compliant paket (AppSourceCop, prefix `DOPSWHS`, ID range `72000-72099` + `72200-72489`)

## 2. Üst Düzey Mimari (4 Bileşen)

```
                      ┌──────────────────────────────────────┐
                      │  BC SaaS (Tenant 7fa2357e-...)        │
                      │  ┌────────────────────────────────┐   │
                      │  │ BCWMSApp Extension (AL)         │   │
                      │  │  - 21 yeni domain object         │   │
                      │  │  - 17 API page (v2.0)            │   │
                      │  │  - 9 tableextension (LP zincir)  │   │
                      │  │  - Role filter resolver          │   │
                      │  └─────────────┬──────────────────┘   │
                      │                │                       │
                      │      OAuth2 + OData v4 / SOAP          │
                      └────────────────┼───────────────────────┘
                                       │
                ┌──────────────────────┼────────────────────────┐
                │                      │                        │
       ┌────────▼────────┐   ┌─────────▼─────────┐   ┌──────────▼──────────┐
       │  Mobile Android  │   │  Web SPA (Vite)   │   │  Push Relay         │
       │  (Kotlin/Compose)│   │  React 19 + TS    │   │  (Azure Function    │
       │                  │   │  ControlAddIn'ler │   │   + SignalR + KV)   │
       │  - 8 modül       │   │  LP Browser       │   │                     │
       │  - MSAL OAuth2   │   │  Pick Board       │   │  Webhook → FCM →    │
       │  - LP / Pick /   │   │  Drag-drop nest   │   │  cihaz push         │
       │    PutAway /     │   │                   │   │                     │
       │    Ship / Sayım /│   └───────────────────┘   └─────────────────────┘
       │    Kalite /      │
       │    Üretim /      │
       │    Montaj        │
       └──────────────────┘
```

### 2.1 BC AL Extension (`al/`)

- **Platform:** Business Central 24, runtime 13.0, application 24.0.0.0
- **Yayıncı:** DynOps, AppID `984e25aa-07c2-4401-babc-88f975303a52`
- **Obje aralığı:** Baseline `72000-72099` + extended `72200-72489`
- **Prefix:** Tüm objeler `DOPSWHS`
- **Diller:** en-US (kaynak), tr-TR + de-DE çevirisi
- **Bağımlılıklar:** Sadece Microsoft Base Application 24.0.0.0 (eklenti yok)

İçerik özeti (v1.7.1):

- ~150 AL objesi (table, codeunit, page, enum, permissionset, report)
- 17 v2.0 API page (warehouse group) — REST/OData public surface
- 9 LP tableextension — License Plate'i BC posting zincirine yayar
- Role-based filter sistemi — sunucu-taraflı SetFilter() OnOpenPage'de
- Install/Upgrade codeunit'leri — idempotent seed (demo data, web services, system roles, config check)

Tüm AL kaynak kodları için bkz. [al/src/](../al/src/). Kod standartları: [docs/al-coding-standards.md](al-coding-standards.md).

### 2.2 Android Mobile App (`android/`)

- **Dil:** Kotlin 2.0.21, Jetpack Compose
- **Toolchain:** AGP 8.6.1, Gradle 8.13, JDK 21
- **API min/target:** 26 / 35
- **Application ID:** `com.dynops.bcwms`
- **APK boyutu:** ~8.4 MB (debug)
- **Auth:** MSAL 4.x, Azure AD interactive token + cached refresh

Modüller ([android/app/src/main/java/com/dynops/bcwms/feature/](../android/app/src/main/java/com/dynops/bcwms/feature/)):

- `LicensePlateModule.kt` — LP build/stop/transfer/print/partial-use
- `ReceivingModule.kt` — Mal kabul (Purchase Order, Transfer Order, Whse Receipt)
- `PutAwayShipModules.kt` — Put-Away + Sevkiyat (Whse Activity + Whse Shipment)
- `PickingModule.kt` — Toplama (Whse Pick, AssignToMe, ConfirmLine)
- `MoveAndCountModules.kt` — Ad-hoc move, directed move, sayım
- `QualityModule.kt` — Kalite emri (DOPSWHS Quality Order)
- `ProductionAssemblyModules.kt` — Üretim sarfiyat + output + montaj
- `BcEnum.kt` (v1.7) — BC OData enum literal sabitler (composite key güvenliği)

Detaylı çalıştırma rehberi: [docs/mobile-app-guide.md](mobile-app-guide.md). Coding standards: [docs/android-coding-standards.md](android-coding-standards.md).

### 2.3 Web SPA (`web/`)

- **Stack:** React 19, Vite 5, TypeScript 5.6
- **Amaç:** BC Role Center'a embed edilen iki ana ControlAddIn:
  - **LP Browser** — Pallet → Carton → Item drag-drop nest hiyerarşisi görüntüleyici/editor
  - **Pick Board** — Kanban-tarzı pick reassignment ve oturum yönetimi
- **Entegrasyon:** BC Page'ler `usercontrol` üzerinden iframe-embed eder; `LPNestManager.Nest()`, `PickMgmt.ReassignPick()` gibi AL procedure'lara doğrudan event call

### 2.4 Azure Functions Push Relay (`push-relay/`)

- **Stack:** Node.js + TypeScript
- **Bileşenler:** Azure Function (HTTP trigger), SignalR Service, Key Vault (FCM credentials), Application Insights
- **Akış:** BC `WebhookMgmt.OnPickReassigned` BusinessEvent → HTTP webhook → Function → FCM push (Android) + SignalR (web)
- **Audit:** `DOPSWHS Webhook Audit` tablosunda her delivery'nin durumu

## 3. Domain Model

### 3.1 License Plate (LP) — Çekirdek Kavram

Bir LP, fiziksel bir kabı (pallet, carton, tote) ve içindeki stoğu temsil eder. SSCC-18 koduyla globally tanımlanır.

**Ana tablolar:**

- `DOPSWHS LP Header` (72040) — No., Status (Open/Built/Used/Unbuilt), Location, Bin, Parent LP No. (nest), SSCC, Assigned Doc
- `DOPSWHS LP Line` (72041) — Item, Qty, Lot, Serial, Expiry
- `DOPSWHS LP Movement Ledger` (72043) — Her hareketin audit trail'i (Built/Transferred/Used/Unbuilt/...)
- `DOPSWHS LP Template` (72042) — CARTON-S/M, PALLET-EUR, TOTE-A şablonları (boyut + max ağırlık)

**LP Yaşam Döngüsü:**

```
[Open] → AddLine* → [Open] → Stop() → [Built (SSCC üretildi)] → Assigned to Document
                                                              ↓
                                           ShipmentMgmt.Post() → [Used]
                                                              ↓
                                                    Unbuild() → [Unbuilt]
```

**LP Nest (v1.6):** Bir LP başka bir LP'nin Parent'i olabilir (max depth=3 setup üzerinden). `DOPSWHS LP Nest Manager` (CU 72041) drag-drop SPA + ProductCount rollup içerir.

### 3.2 LP Full-Chain Propagation (v1.7 — WI Paritesi)

Aşağıdaki BC tabloları artık `DOPSWHS LP No.` alanı taşır — LP zincirini tüm posting akışı boyunca takip edebilirsiniz:

| Tablo | Field ID | Doldurma kaynağı |
|---|---|---|
| `Warehouse Receipt Header` | 72422 | `ReceiptMgmt.ConfirmLine` (LP scan anında) |
| `Posted Whse. Receipt Header` | 72423 | `LPPropagation.StampPostedReceiptHeader` (post sonrası) |
| `Posted Whse. Receipt Line` | 72040 (mevcut) | `LPPropagation.StampPostedReceiptLines` (post sonrası, header'dan kopya) |
| `Warehouse Shipment Header` | 72420 | `ShipmentMgmt.ConfirmShipmentLine` (LP scan) |
| `Posted Whse. Shipment Header` | 72421 | `LPPropagation.StampPostedShipmentHeader` |
| `Warehouse Shipment Line` (mevcut) | `LP No.` (72406) | `Pick Mgmt.StopShippingLP` |
| `Posted Whse. Shipment Line` (mevcut) | `LP No.` (72405) | `ShipmentMgmt.PostShipment` |
| `Sales Shipment Line` | 72426 | Event subscriber `OnAfterPostSalesDoc` (Whse Shpt Line → Posted Sales Shpt Line) |
| `Purch. Rcpt. Line` | 72424 | Event subscriber `OnAfterPostPurchaseDoc` (Whse Rcpt Header → Posted Purch Rcpt Line) |
| `Item Ledger Entry` | 72428 | Event subscriber `OnAfterInsertItemLedgEntry` (Whse Activity Line/Whse Shipment Line/Whse Receipt Header üzerinden lookup) |
| `Value Entry` | 72429 | Event subscriber `OnAfterInsertValueEntry` (ILE'den kopya) |
| `Warehouse Entry` (mevcut) | 72402 | Mevcut `BinContentSubscriber` |

Tüm subscriber kodu: [al/src/LPPropagation/LPPropagationSubscriber.Codeunit.al](../al/src/LPPropagation/LPPropagationSubscriber.Codeunit.al).

**Pratik etki:** Bir kullanıcı `GET /itemLedgerEntries?$filter=lpNo eq 'LP000123'` yaparak o LP'nin hayatı boyunca tüm hareketlerini (mal kabul → put-away → pick → ship → posted ledger) tek sorguda görebilir.

### 3.3 Rol-Bazlı Görünürlük (v1.7)

Kullanıcının BC Permission Set'inden bağımsız olarak, sunucu-taraflı `SetFilter()` ile API'lerden dönen kayıtları kısıtlar.

**Tablolar:**

- `DOPSWHS App Role` (72267) — Role kataloğu (Code, Description, Active, Is System, Hide Test/Admin Tools)
- `DOPSWHS App User Role` (72268) — User ID + Role Code composite PK; çoklu rol destekli
- `DOPSWHS App Role Filter Rule` (72269) — Role Code + Entity (enum) + Line No.; Field No. + Filter Expression + Combine Mode

**Seed edilen 7 sistem role:**

| Code | Açıklama | Otomatik Kurallar |
|---|---|---|
| `OPERATOR` | Generic (full visibility) | Kural yok |
| `PICKER` | Pick + Ship odaklı | Pick.AssignedUserId=`=%USER%\|=''`, Shipment aynı, PickLine aynı |
| `RECEIVER` | Receive + PutAway | Receipt.AssignedUserId=`=%USER%\|=''`, PutAway aynı |
| `SHIPPER` | Ship odaklı | Shipment.AssignedUserId=`=%USER%\|=''` |
| `COUNTER` | Sayım | CountSheet.Status=`Open` |
| `QUALITY` | Kalite | QualityOrder.Inspector=`=%USER%\|=''` |
| `INV_ADMIN` | Geniş (admin, test/admin tools görünür) | Kural yok |

**Filter Expression token'ları:**

- `%USER%` → `UserId()`
- `%LOC%` → kullanıcının `App User Profile`'daki Default Location
- `%TODAY%` → `Format(Today)`
- `%NOW%` → `Format(CurrentDateTime)`

**Uygulama mekanizması:** Her v2.0 API page `OnOpenPage` trigger'ında `AppRoleFilterMgmt.ApplyForCurrentUser(RecRef, EntityType)` çağırır. Mgmt codeunit:

1. UserRoles tablosundan kullanıcının aktif rollerini çeker
2. Her rolün `(Entity, FieldNo)` kurallarını gruplar, çoklu rol için `|` (OR) ile birleştirir
3. Token'ları substitute eder
4. `[TryFunction]` ile expression'ı validate eder (kötü expression silent fallback + telemetry log)
5. `RecRef.Field(FieldNo).SetFilter(Expression)` çağırır

Kod: [al/src/Role/AppRoleFilterMgmt.Codeunit.al](../al/src/Role/AppRoleFilterMgmt.Codeunit.al).

**Çoklu rol birleşim politikası:** OR (geniş görüş). PICKER + QUALITY rolündeki bir kullanıcı her iki rolün kurallarının birleşimini görür.

**Resolver JSON genişlemesi:** `appUserProfiles('DEFAULT')/Microsoft.NAV.resolveCurrent` artık `roles[]` ve `effectiveFilters{}` döner — mobil/web istemcileri bilgilendirme amaçlı kullanabilir, ama otorite server-side filter'dır.

### 3.4 App User Profile

Kullanıcı bazlı tercihler ([al/src/Device/AppUserProfile.Table.al](../al/src/Device/AppUserProfile.Table.al), table 72262):

- **Device Config Code** — Hangi tile setini görecek
- **Default Location / Bin Code** — Hızlı doldurma için
- **Locale** — tr / en / de
- **Only My Picks/Receipts/PutAways/Shipments/Movements** — Legacy client-side filter (v1.7 sonrası rol bazlı server filter ile devraldı; geriye uyum için duruyor)
- **LP Status Filter** — `All/Built/Open/Used`
- **Quality Filter** — `All/OpenOnly/FailedOnly`
- **Hide Test/Admin Tools** — Operatör için debug tile'ları gizler
- **Max List Rows** — 50 default

Resolver: `AppProfileMgmt.ResolveForCurrentUser()` JSON döner — kullanıcının kendi row'u → DEFAULT row → boş fallback.

### 3.5 Diğer Domain Tabloları

- **Pick / Pick Line** — `Warehouse Activity Header (Pick)` + `Warehouse Activity Line` standart BC tabloları + DOPSWHS LP No. + Target LP No.
- **Put-Away** — Aynı tablo, `Type = const(PutAway)`
- **Movement** — Aynı tablo, `Type = const(Movement)`
- **Whse Shipment / Receipt** — Standart BC + DOPSWHS extensions (LP No., SSCC)
- **DOPSWHS Count Sheet Header/Line** (72200/72201) — Multi-counter inventory count + variance review
- **DOPSWHS Count Counter** (72202) — n:n slot atama (3 counter aynı bin'i sayar, variance evaluate)
- **DOPSWHS Quality Order** (72256) — Source linked (Receipt/Pick/Production), Inspector, Status (Open/InProgress/Passed/Failed/Rejected)
- **DOPSWHS Posting Test Result** (72253) — Otomatik posting smoke test sonuçları

## 4. Uçtan-Uca İş Akışları

### 4.1 Mal Kabul (Receiving)

```
1. Admin BC'de Purchase Order yaratıp Release eder
2. Whse Receipt → Create (manual veya CreatePutAway action)
3. Operatör Android app'i açar → "Mal Kabul" tile
4. Whse Receipt header'ı seçer (Assigned User filter'ı PICKER role ile kendi atananları)
5. Barcode tarar (GS1-128 parse → BarcodeParser.ParseBarcode):
   - GTIN → Item bulunur
   - Lot/Serial/Expiry capture (item tracking)
   - SSCC → LP scan
6. (Opsiyonel) Start LP (PALLET-EUR template) → LP Header oluşur (Status=Open)
7. ConfirmLine — Qty, Bin Code, LP No. ile satır kaydedilir
8. LP scan edildi ise:
   - LP'ye Line eklenir (LPMgt.AddLine)
   - Whse Receipt Header.DOPSWHS LP No. stamp edilir (ilk LP wins)
9. Tüm satırlar onaylandıktan sonra PostReceipt:
   - Standart BC Whse.-Post Receipt çağrılır
   - LPPropagation.StampPostedReceiptHeader → Posted Whse Receipt Header.lpNo dolu
   - LPPropagation.StampPostedReceiptLines → Posted Whse Receipt Line.lpNo dolu
   - Standart BC Item Jnl posting → OnAfterInsertItemLedgEntry → ILE.lpNo dolu
   - OnAfterInsertValueEntry → Value Entry.lpNo dolu
10. PO.OnAfterPostPurchaseDoc → Posted Purch. Rcpt. Line.lpNo dolu (header'dan kopya)
```

**Sonuç:** Tek bir LP scan → 6 farklı tabloya propagate, tüm posting zinciri boyunca LP referansı.

### 4.2 Toplama (Picking) ve Sevkiyat (Shipping)

```
1. Admin Sales Order Release → Whse Shipment auto-create veya manual
2. Whse Shipment.CreatePickDoc (SOAP via DOPSWHSWarehouseShipment service)
3. Pick activity oluşur — Operatör Android'de "Toplama" tile
4. assignToMe → Pick.AssignedUserId = current_user (PICKER rolündeyse zaten kendi pick'leri görünür)
5. StartShippingLP — yeni bir LP build edilir (CARTON-S/PALLET-EUR şablonu)
6. Her line için ConfirmLine — qtyHandled, source bin'den alma, LP'ye AddLine
7. StopShippingLP → LP Stop → SSCC üretilir → LP Status=Built
8. (Opsiyonel) Short-pick → MarkPickShort(line, qty, NO_STOCK) → backorder
9. RegisterPick — Whse Activity register, Whse Entries oluşur, source bin azalır
10. Whse Shipment.PostShipment (ShipmentMgmt.PostShipment):
    - Lines'tan LP/SSCC kopyalanır
    - LP Status → Used
    - PostedWhseShipment + PostedWhseShipmentLine.lpNo dolu
    - Posted Whse Shipment Header.lpNo (header-level, ilk LP wins) — StampPostedShipmentHeader
    - PrintPackingSlip → Print Job Queue entry
11. SalesPost.OnAfterPostSalesDoc → Sales Shipment Line.lpNo dolu (Whse Shipment Line → Posted Sales Shipment Line trace)
12. Standart BC ILE/Value Entry posting → DOPSWHS LP No. propagate
```

### 4.3 Diğer Akışlar (özet)

- **Put-Away:** Whse Receipt registered → Whse Activity (Type=PutAway) → ConfirmPutAway(bin) per line → Register → Bin contents transfer
- **Movement:** Ad-hoc (Item Reclass Jnl post) veya Directed (Whse Movement.Register)
- **Inventory Count:** CreateSheet (Mode=Blind/Display) → multi-counter → EvaluateVariance → RecountRequired flag → Supervisor approve → PostSheet → Phys Inv Journal post → ILE adjustment
- **Quality:** QualityOrder.AssignInspector → Inspect → Pass/Fail/Reject → Posted action (Sales hold, scrap, recheck)
- **Production:** Released Prod Order → Consume (component, qty, lp) → ReportOutput (routing line, qty, lp) → Output to new LP option
- **Assembly:** Assembly Order Release → AssemblyMgmt.PostAssembly (Components consumed + Assembly output → optional LP)

## 5. Kurulum ve Yapılandırma

### 5.1 İlk Kurulum (BC SaaS sandbox)

1. Sandbox env hazır olmalı (CustomerSandbox / SandboxUS / başka tenant)
2. `altool publishapp al/bcwmsapp.app --environmentType Sandbox --environmentName <env> --tenant <tenant> --schemaUpdateMode ForceSync`
3. Otomatik bootstrap (`DOPSWHS Upgrade.OnUpgradePerCompany`):
   - `DemoSetup.RunFullDemoSetup` → LP templates, barcode rules, locations, vendors
   - `DemoTransactions.CreateAllDemoTransactions` → 5 demo LP + 1 open count sheet
   - `E2EData.PrepareE2EData` → ITEM-LOT-1, E2E-PO-001, E2E-SO-001, BLUE/SILVER/GREEN bins
   - `CatalogSeed.RunFullSeed` → Test Catalog (50 TC)
   - `PostingSmokeTest.EnsureRows` → Posting test rows
   - `QualityMgmt.SeedDemoOrders` → Demo quality orders
   - `WebSvcPublisher.PublishAll` → Tenant Web Services yayınlar
   - `AppProfileMgmt.SeedDefaults` → DEFAULT profile + install-user profile
   - **`AppRoleSeed.Seed`** (v1.7) → 7 sistem role + starter filter rules
   - `ConfigChecker.RegisterAssistedSetup` → Configuration Check tile'ı kayda ekler
4. `DOPSWHS-ADMIN` permission set'ini test user'a ata
5. Role Center → **Assisted Setup → "DynOps WMS Configuration Check"** (page 72261) — her kalemi ✅/⚠️/❌ değerlendirir, fixable olanlara "Tümünü Düzelt" butonu

Detay: [docs/setup-runbook.md](setup-runbook.md).

### 5.2 Kullanıcı Bazlı Yapılandırma

1. **App User Profile** (page 72263) → kullanıcıya row ekle (Config Code, Default Location, Locale)
2. **WMS App Roles** (page 72274) → 7 sistem role'u doğrula; gerekirse custom role ekle (örn. `WAREHOUSE-X-PICKER` ile location filter)
3. App User Profile Card → **Roles** sub-list'e kullanıcının rolünü ekle
4. Mobil app açılışta → `POST .../appUserProfiles('DEFAULT')/Microsoft.NAV.resolveCurrent` → JSON'da `roles[]` ve `visibleModules[]` döner

### 5.3 Mobil App Login

1. APK kurulduktan sonra app açılır → "BC Sandbox: CustomerSandbox / Demo Business Central" başlığı
2. **Gelişmiş: Token ile Giriş** (token paste): `az account get-access-token --resource api://...` üzerinden token al, app'e yapıştır → Bağlı
3. Standart yol: MSAL OAuth2 interactive (Azure AD login UI)
4. Token cache: ~/Library/Application Support/com.dynops.bcwms/

Detay: [docs/mobile-app-guide.md](mobile-app-guide.md), [docs/mobile-email-login.md](mobile-email-login.md).

## 6. API Yüzeyi

### 6.1 v2.0 API Pages (warehouse group)

`POST /tenant/env/api/dynops/warehouse/v2.0/{entitySet}` standardı:

| EntitySet | Kaynak Tablo | Page ID | Bound Actions |
|---|---|---|---|
| `licensePlates` | DOPSWHS LP Header | 72088 | `build`, `stop`, `print`, `transfer`, `nest`, `unnest`, `assign`, `release` |
| `licensePlateLines` | DOPSWHS LP Line | 72089 | — |
| `receipts` | Warehouse Receipt Header | 72090 | `startLP`, `stopLP`, `assignUser`, `confirmLine`, `postReceipt` |
| `receiptLines` | Warehouse Receipt Line | 72252 | — |
| `putAways` | Warehouse Activity Header | 72091 | `suggestBin`, `confirmPutAway`, `register` |
| `putAwayLines` | Warehouse Activity Line | 72091.PutAwayLine | — |
| `picks` | Warehouse Activity Header | 72092 | `assignToMe`, `startShippingLP`, `stopShippingLP`, `markShort`, `register`, `reassign` |
| `pickLines` | Warehouse Activity Line | 72092.PickLine | — |
| `shipments` | Warehouse Shipment Header | 72093 | `assignUser`, `confirmLine`, `post`, `postSalesShipAndInvoice`, `postTransferShip` |
| `shipmentLines` | Warehouse Shipment Line | 72093.Line | — |
| `movements` | Warehouse Activity Header | 72258 | `adHoc`, `registerDirected` |
| `countSheets` | DOPSWHS Count Sheet Header | 72213 | `createSheet`, `recordCount`, `evaluateVariance`, `postSheet` |
| `countSheetLines` | DOPSWHS Count Sheet Line | 72244 | — |
| `qualityOrders` | DOPSWHS Quality Order | 72256 | `assignInspector`, `recordResult`, `post` |
| `productionConsumption` | Prod. Order Component | 72223 | `consume` |
| `productionOutput` | Prod. Order Routing Line | 72225 | `report` |
| `assemblies` | Assembly Header | 72228 | `post` |
| `assemblyLines` | Assembly Line | 72229 | — |
| `items` | Item | 72087 | — |
| `bins` | Bin | 72083 | — |
| `barcodes` | (procedure-only) | 72037 | `parse` (GS1-128 + EAN-13 + SSCC + custom) |
| `devices` | DOPSWHS Device Registration | 72086 | `heartbeat` |
| `appUserProfiles` | DOPSWHS App User Profile | 72266 | `resolveCurrent` (returns full JSON with roles[]) |
| `appRoles` (v1.7) | DOPSWHS App Role | 72278 | — |
| `postingTests` | DOPSWHS Posting Test Result | 72254 | `runReceive`, `runPick`, `runShip` |
| `testRuns` | DOPSWHS Test Run | 72253 | `startRun`, `rerunFailed`, `cancelRun` |

**Tüm SourceTable-backed API page'ler v1.7'den itibaren `OnOpenPage` trigger'ında `AppRoleFilterMgmt.ApplyForCurrentUser(...)` çağırır** — kullanıcının rolüne göre sunucu-taraflı filter otomatik uygulanır.

### 6.2 SOAP Web Services (extension API'nin yetmediği yerler)

| Service | BC Page | Kullanım |
|---|---|---|
| `DOPSWHSWarehouseShipment` | 7335 | **SOAP CreatePick** (directed pick, AL'den erişilemez) + OData veri |
| `DOPSWHSWarehouseReceipt` | 5768 | SOAP CreatePutAway + OData |
| `DOPSWHSItemReclassJournal` | 393 | Ad-hoc move |
| `DOPSWHSWhseItemJournal` | 7324 | Directed location reclass |
| `DOPSWHSProductionJournal` | 5510 | Sarfiyat/output |
| ... | ... | tam liste: [docs/web-services.md](web-services.md) |

`DOPSWHS Web Svc Publisher` (CU 72257) install/upgrade'de idempotent olarak yayınlar.

### 6.3 OpenAPI Spec

Tüm API yüzeyinin OpenAPI 3.0 spec'i: [docs/api-openapi.yaml](api-openapi.yaml). Postman collection: [contract-tests/](../contract-tests/).

## 7. Entegrasyonlar

### 7.1 BC Integration Events Subscribe Ediyoruz

`DOPSWHS LP Propagation` (CU 72428):

- `Codeunit::"Item Jnl.-Post Line"::OnAfterInsertItemLedgEntry` → ILE.lpNo doldur
- `Codeunit::"Item Jnl.-Post Line"::OnAfterInsertValueEntry` → Value Entry.lpNo doldur
- `Codeunit::"Sales-Post"::OnAfterPostSalesDoc` → Posted Sales Shipment Line.lpNo
- `Codeunit::"Purch.-Post"::OnAfterPostPurchaseDoc` → Posted Purch. Rcpt. Line.lpNo

`DOPSWHS Bin Content Subscriber` — Bin content + LP rollup için.

### 7.2 BC Integration Events Publish Ediyoruz

- `DOPSWHS Shipment Mgmt.OnBeforeShipSales(SalesOrderNo)`
- `DOPSWHS Shipment Mgmt.OnAfterInvoiceSales(SalesOrderNo)`
- `DOPSWHS Pick Mgmt.OnPickReassigned(OldUser, NewUser, PickNo)` — Webhook tetikler
- `DOPSWHS Webhook Mgmt.OnWebhookEvent(EventType, Payload)` — External delivery

### 7.3 Push Notifications

```
1. Pick reassigned event fires in BC
2. WebhookMgmt.LogWebhookEvent → DOPSWHS Webhook Audit row (Status=Queued)
3. Azure Function HTTP trigger gets webhook payload
4. Function fetches FCM device tokens from DeviceRegistration (via OData)
5. FCM push → Android device "Pick X size atandı" notification
6. SignalR push → Web SPA Pick Board real-time update
7. Function writes back Status=Delivered to Webhook Audit
```

Detay: [docs/operations-runbook.md](operations-runbook.md).

## 8. Test ve Doğrulama

### 8.1 Otomatik Test Sistemi (50 E2E TC)

`DOPSWHS Test Runner` (CU 72062) — Role Center → 🧪 Test Center → **New Test Run** → Status/PassRate cue group'ta canlı sonuç.

50 case 8 section'a bölünmüş: Setup(5), LP Core(10), Receiving(8), Picking+Shipping(10), Movements(3), Count(4), Production+Assembly(5), System+SPA(5).

Detay: [docs/test-management-guide.md](test-management-guide.md).

### 8.2 Posting Smoke Test

`DOPSWHS Posting Smoke Test` (CU 72081) — Mobil app'ten on-demand çağrılabilen sandbox posting harness. Receive, Pick, Ship, ILE adjustment vb. minimal smoke runs.

Detay: [docs/posting-tests.md](posting-tests.md).

### 8.3 Configuration Check

`DOPSWHS Config Checker` (CU 72260) + Assisted Setup page 72261 — her kurulum kalemini ✅/⚠️/❌ değerlendirir, auto-fixable olanları "Tümünü Düzelt" ile uygular:

- Package Nos. (Inventory Setup)
- Item Tracking Code (Package Specific Tracking)
- Warehouse Employee (current user)
- Default location + bins (RECEIVE-1, PICK-01, BULK-01, SHIP-01)
- DOPSWHS number series (AWMS-LP, AWMS-SSCC, AWMS-CNT)
- Web service pages yayınlanmış
- WMS App User Profile (current user)
- (v1.7 ileride) WMS App Roles seed kontrolü

### 8.4 Demo E2E Suite (v1.7.2 — 100 transaction sweep)

`DOPSWHS Demo E2E Suite` (CU 72280) — Mobil app'in v2.0 API page bound action'ları üzerinden çağırdığı **aynı Mgmt codeunit'larını AL-tarafında 10 WMS fonksiyonu × 10 transaction = 100 demo işlemiyle uçtan-uca koşturur**, sonuçları `DOPSWHS Demo E2E Result` tablosuna stampler. Her satır şu bilgiyi içerir: Function Code, Tx #, Title, Status (Passed/Failed/Running), Started/Completed DateTime, Duration ms, üretilen LP No., Source Doc No., Item No., Quantity, Result Detail, Error Message.

**Tetikleme yolları:**

- **BC UI:** `Setup` (page 72051) → action "Run Demo E2E Suite (100 tx)" → action "Show Demo E2E Results"
- **OData (mobil/CLI):** `POST .../api/dynops/warehouse/v2.0/companies({comp})/demoE2EResults(functionCode='STUB',transactionNo=0)/Microsoft.NAV.runAll`
- **AL:** `Codeunit.Run(Codeunit::"DOPSWHS Demo E2E Suite")` veya doğrudan `Suite.RunAll()`

**Kapsanan 10 fonksiyon:**

| Function | Tx Sayısı | Hangi production codeunit yolu | Mobil app'teki karşılığı |
| --- | --- | --- | --- |
| `LP` | 10 | `LPMgt.Build` + `AddLine` + `Stop` (her 2. tx) | LP build screen → Stop |
| `RECEIVE` | 10 | `LPMgt.Build` (PALLET-EUR) + `AddLine` | Receiving → Start LP + Confirm Line |
| `PUTAWAY` | 10 | `DirectedPutAway.SuggestBin` | PutAway → SuggestBin button |
| `PICK` | 10 | `LPMgt.Build` (shipping LP) + `Stop` (SSCC) | Pick → StartShippingLP + StopShippingLP |
| `SHIP` | 10 | `SSCCGenerator.Generate` | Ship → Auto-SSCC on Post |
| `MOVE` | 10 | `LPMgt.Build` + Transfer (bin → bin) | Move → AdHoc / Directed Move |
| `COUNT` | 10 | `CountMgt.CreateSheet` (Blind, 1 counter) | Count → New Sheet |
| `QUALITY` | 10 | `QualityMgt.CreateOrder` (Source=Receipt) | Quality → Create Order |
| `PRODUCTION` | 10 | `LPMgt.Build` (PALLET-EUR) + Output LP | Production → Report Output to new LP |
| `ASSEMBLY` | 10 | `LPMgt.Build` (TOTE-A) + finished LP | Assembly → Output LP |

**BC Sonuç Sayfası (`DOPSWHS Demo E2E Results`, page 72281):**

- List page — Function Code + Transaction No. PK
- Status sütununda renkli badge (Yeşil/Kırmızı/Sarı)
- FactBox: `Stats` (page 72282) → Total / Passed / Failed / Running / Not Run count cue'ları
- Action: **Run All E2E Suite** (tek tık tüm 100 tx) + **Clear All Results**
- Drilldown her satıra LP No. (clickable → LP Card), Source Doc No., Item, Quantity gösteriyor

**Çoklu-tenant doğrulama:** Lokasyon kodu sabit hardcoded değil — `DOPSWHS Setup."Default Location Code"` dinamik okunur. Her tenant kendi default lokasyonu ile çalışır.

**Performans:** SandboxUS (CRONUS USA, Inc.) ve CustomerSandbox (Demo Business Central) üzerinde 2026-06-02 itibariyle her ikisinde de **100/100 PASSED**. Total run ~15-30 saniye (COUNT sleep'leri No. Series timestamp resolution için).

**Mobil-eşdeğerlik:** Demo E2E Suite, AL-tarafında prod codeunit'larını doğrudan çağırır. Mobil app aynı endpoint'ler için HTTP/OData PATCH/POST yapar → server-side aynı codeunit'lara iniyor. Yani Demo E2E'de yeşil olan bir transaction, mobil app'ten manuel akış için fonksiyonel güvence demektir.

### 8.5 Audit Scripts

[tools/](../tools/) klasöründe:

- `audit-prefix.sh` — Tüm objelerin `DOPSWHS` prefix taşıdığını doğrular
- `audit-permissions.sh` — Permission set'lerin tüm objeleri kapsadığını doğrular
- `audit-obsolete.sh` — Obsolete API kullanımları
- `audit-translation-coverage.sh` — tr-TR + de-DE çevirilerinin tam olduğunu

## 9. Operasyon ve İzleme

### 9.1 Application Insights

Telemetry event'leri:

- `AdvWMS.Receipt.Post`, `AdvWMS.Shipment.Posted`, `AdvWMS.Pick.Registered`
- `AdvWMS.LP.Built`, `AdvWMS.LP.Stopped`, `AdvWMS.LP.Transferred`
- `AdvWMS.RoleFilter.BadExpression` (v1.7 — kötü filter expression silent fallback)
- `AdvWMS.Sales.ShipAndInvoice`, `AdvWMS.Transfer.Shipped`
- `AdvWMS.Webhook.Delivered/Failed`

Her event correlation ID, tenant ID, user ID, custom dimensions taşır.

### 9.2 Dashboards

[dashboards/](../dashboards/) klasöründe:

- Application Insights workbook JSON'ları
- Power BI report files (.pbix) — Test Run trends, LP throughput, pick efficiency

### 9.3 Sorun Giderme

İlk yanıt prosedürü ([docs/operations-runbook.md](operations-runbook.md)):

1. Tenant, company, user, device ID, app version, workflow tespit
2. App Insights failures son 30 dk
3. BC extension version + feature flags
4. Tek device/user/lokasyon mu, tüm tenant mı?
5. Telemetry correlation ID'yi sakla

Tipik sorunlar: [docs/troubleshooting.md](troubleshooting.md).

## 10. AL Object ID Haritası

| Aralık | Kullanım |
|---|---|
| 72000-72009 | Setup tabloları (Setup, Device Config, Device Menu, Device Column) |
| 72010-72029 | Test catalog tabloları |
| 72031-72035 | Setup Wizard, Test Catalog, Demo Data, Install/Upgrade |
| 72036-72056 | Domain mgmt codeunits (LP, SSCC, Receipt, PutAway, Pick, Ship, Movement, Count, Prod, Assembly, Quality, Webhook) |
| 72060-72082 | Test infrastructure (E2E Data, Test Catalog Seed, Runner, Test Automations) |
| 72083-72099 | API page'ler (warehouse group) |
| 72100-72108 | Test management pages |
| 72200-72259 | Count Sheet, Posting Test, Quality Order, Receipt Line API, Migration |
| 72260-72266 | Config Checker, App User Profile sistem |
| **72267-72278** | **Role system (v1.7) — App Role, App User Role, Filter Rule, helper codeunit, seed, pages** |
| 72400-72427 | Tableextension'lar |
| **72420-72427** | **LP Propagation tableextension'ları (v1.7)** |
| **72428** | **LP Propagation Subscriber codeunit (v1.7)** |
| 72480-72489 | Reserved |

## 11. Sürüm Geçmişi

| Sürüm | Tarih | Değişiklik |
|---|---|---|
| v1.0.0.0 | 2026-04 | İlk RC — LP core, receive/pick/ship core, mobile demo |
| v1.0.2.0 | 2026-05-27 | Sandbox publish + Setup Test Catalog + ilk Test Run |
| v1.0.3.0 | 2026-05 | 50 E2E TC + Test Runner + multi-environment |
| v1.1.0 | 2026-05 | Fonksiyonel çok-ekranlı mobile + Home menu + 7 modül + persistent token |
| v1.2.0 | 2026-05 | Tüm ekranlar canlı BC verisiyle çalışıyor |
| v1.3.0 | 2026-05 | WI-parite aksiyon-yetenekli WMS handheld (Codex Faz 1) |
| v1.6.0 | 2026-06-02 | LP Fixes + Assisted Setup config check + App User Profile + Web Svc Publisher |
| **v1.7.0** | 2026-06-02 | **LP Full-Chain Propagation (WI paritesi) + Mobile Module Fixes** |
| **v1.7.1** | 2026-06-02 | **Role-Based Server-Side Filter System + 18 API page integration** |

Detaylı release notes: [docs/release-notes/](release-notes/).

## 12. Referans Linkler

**Kurulum ve Operasyon:**

- [Setup Runbook](setup-runbook.md) — İlk kurulum + Configuration Checklist
- [Operations Runbook](operations-runbook.md) — Production destek + İlk yanıt prosedürü
- [Troubleshooting](troubleshooting.md) — Tipik sorunlar ve çözümleri
- [Sandboxus & Quality](sandboxus-and-quality.md) — Quality gate'ler ve sandbox deploy

**Geliştirici Kılavuzları:**

- [AL Coding Standards](al-coding-standards.md)
- [Android Coding Standards](android-coding-standards.md)
- [Mobile App Guide](mobile-app-guide.md) — APK build, emulator setup, token paste
- [Mobile Email Login](mobile-email-login.md) — MSAL flow detayı
- [Mobile Full Scope Plan](mobile-full-scope-plan.md) — Mobil roadmap

**API ve Test:**

- [Web Services](web-services.md) — SOAP service kullanımı
- [API OpenAPI](api-openapi.yaml) — OpenAPI 3.0 spec
- [Test Management Guide](test-management-guide.md) — Test Center kullanımı
- [Posting Tests](posting-tests.md) — Posting smoke test
- [User Test Checklist](user-test-checklist.md) — Manuel test rehberi

**Compliance:**

- [Security Audit](security-audit.md)
- [i18n Glossary](i18n-glossary.md) — Çeviri terminolojisi
- [AppSource Submission](appsource/submission-checklist.md)
- [Play Store Submission](play-store/)

**Karar Tarihçesi:**

- [Sprint Decisions](decisions/) — Sprint 0-8 + Sprint H+ karar log'ları
- [Sandbox Deployment Log](deployment/sandbox-deployment-2026-05-27.md)

---

## Hızlı Başlangıç (Yeni Geliştirici / Operatör)

**Geliştirici için:**

```bash
# 1. AL extension compile + publish
ALC=~/.vscode/extensions/ms-dynamics-smb.al-17.0.2273547/bin/darwin/alc
mv al/tests /tmp/bcwms-tests-backup && \
  "$ALC" /project:al /packagecachepath:al/.alpackages /out:al/bcwmsapp.app /errorsonlyinconsole; \
  mv /tmp/bcwms-tests-backup al/tests
~/.vscode/extensions/ms-dynamics-smb.al-17.0.2273547/bin/darwin/altool publishapp al/bcwmsapp.app \
  --environmentType Sandbox --environmentName CustomerSandbox \
  --tenant 7fa2357e-26f2-4174-8e16-a713981356b8 --schemaUpdateMode ForceSync

# 2. Web SPA build
cd web && pnpm install && pnpm typecheck && pnpm build

# 3. Android APK
cd android && ./gradlew lintDebug testDebugUnitTest assembleDebug
# APK: android/app/build/outputs/apk/debug/app-debug.apk

# 4. Push relay
cd push-relay && pnpm install && pnpm build
```

**Operatör için:**

1. Mobil app'i kurun (APK install veya Play Store)
2. App açılır → "BC Sandbox" başlığı
3. Login → MSAL veya token paste
4. Home menüden ihtiyacınızı seçin: Mal Kabul / Toplama / Put-Away / Sevkiyat / Sayım / Kalite / Üretim / Montaj
5. Sadece size atanmış işler görünür (PICKER/RECEIVER/... rolü atandıysa)
6. Barcode tarama + LP scan ile akış başlar
7. Confirm/Register/Post action'larıyla iş kapatılır

---

*Bu doküman BCWMSApp v1.7.1.0 sürümüne göre güncellenmiştir. Yeni özellikler için [release-notes/](release-notes/) klasörüne bakın.*
