# Sprint 2 — License Plate Core (2 hafta)

## Hedef

License Plate (LP) modelini ve onun çevresindeki tüm yönetimi (build/stop/use/transfer/nest/unbuild + SSCC üretimi + ZPL label + nested LP rollup) hem AL'de hem Android'de uçtan uca çalışır hale getir. LP, sistemin atomik birimi olduğu için bundan sonraki tüm sprintler buna bağımlı.

## Demo Kriterleri

1. Mobilde **LP Mgmt** açılır → "Yeni LP Başlat" → 5 farklı ürün barkodu okut (qty + UoM dialog) → "LP'yi Kapat" → label printer'a ZPL gönderilir, SSCC üretilir.
2. Sandbox'ta `DOPSWHS LP Header` listesinde yeni LP `Built` durumunda; `LP Movement Ledger` 6 satır içerir (1 Built + 5 ItemAdded).
3. **Bin Content** üzerinde nested LP rollup görünür: pallet'in içindeki carton'un içindeki item'lar, bin'in toplam qty'sine doğru sayıdığında çift sayım yok.
4. Mobilde LP'yi başka LP'ye Transfer → kaynak LP'nin lines azalır, hedef LP'nin lines artar; Movement Ledger 2 satır (TransferOut + TransferIn).
5. Partial use senaryoları (Create New LP / Remove Excess / Remove Used Portion / Unbuild) bottom-sheet ile seçilebilir ve doğru sonuç üretir.

## AL İş Paketleri

### LP tabloları (4 tablo)

- `al/src/LicensePlate/LPHeader.Table.al` (T 72010) — alanlar: `No.` (No. Series), `Location Code`, `Bin Code`, `Status` (Enum 72097), `Parent LP No.`, `LP Template Code`, `SSCC` (Code[18]), `Assigned Document Type` (Enum 72098), `Assigned Document No.`, `Built By User`, `Built DateTime`, `Last Modified DateTime`, `Weight (kg)` (FlowField sum lines), `Length cm`, `Width cm`, `Height cm`, `Notes`
- `al/src/LicensePlate/LPLine.Table.al` (T 72011) — alanlar: `LP No.`, `Line No.`, `Item No.`, `Variant Code`, `Unit of Measure`, `Quantity`, `Lot No.`, `Serial No.`, `Package No.`, `Child LP No.` (mutex with Item No.), `Expiration Date`, `Source Document Type`, `Source Document No.`
- `al/src/LicensePlate/LPMovementLedger.Table.al` (T 72012) — immutable; `Entry No.` (AutoIncrement, PK), `LP No.`, `Action` (Enum 72201), `From Bin`, `To Bin`, `Quantity`, `Item No.`, `Lot/Serial`, `User ID`, `Device ID`, `DateTime`, `Related Document`
- `al/src/LicensePlate/LPTemplate.Table.al` (T 72013) — `Code`, `Description`, `Default Tare Weight`, `Default LxWxH`, `Max Weight`, `Label Report ID`, `No. Series`, `Allow Mixed Items`, `Allow Mixed Lots`

### LP Mgmt codeunits

- `al/src/LicensePlate/LPManagement.Codeunit.al` (CU 72040) — public API:
  - `procedure Build(Template; Location; Bin; var LP)` + event `OnBeforeBuild`/`OnAfterBuild`
  - `procedure Stop(var LP; PrintLabel: Boolean)` (event'li)
  - `procedure Reopen(var LP)`
  - `procedure AddLine(var LP; Item; UoM; Qty; Lot; Serial; ExpiryDate)`
  - `procedure RemoveLine(var LPLine)`
  - `procedure Assign(var LP; DocType; DocNo)`
  - `procedure Release(var LP)`
  - `procedure Transfer(var SourceLP; var TargetLP; LineSelections)`
  - `procedure Unbuild(var LP)`
  - `procedure SplitForPartialUse(var LP; Action: Enum; Qty)`
- `al/src/LicensePlate/LPNestManager.Codeunit.al` (CU 72041) — `Nest(child, parent)`, `Unnest(child)`, depth check ≤3, same-location kuralı, status check
- `al/src/LicensePlate/SSCCGenerator.Codeunit.al` (CU 72042) — 18 haneli SSCC üretimi, GS1 Company Prefix Setup'tan, "extension-prefix" işaret bayrağı

### Bin content rollup (CRITICAL — double-count önleme)

- `al/src/LicensePlate/BinContentSubscriber.Codeunit.al` (CU 72039) — subscribe `OnAfterCalcBinContent` events; nested LP qty rollup; Sprint 2 sonu performance test ile doğrulanır
- `al/src/Inquiry/BinContentExt.TableExt.al` (TableExt 72401) — Bin Content (7302) üzerine `Root LP Count` FlowField
- `al/src/Inquiry/WhseEntryExt.TableExt.al` (TableExt 72402) — Warehouse Entry (7312) üzerine `LP No.` alanı

### LP API

- `al/src/LicensePlate/LPApi.Page.al` (P 72088) — `/licensePlates` + bound actions:
  - POST `Microsoft.NAV.assign` — `{docType, docNo}`
  - POST `Microsoft.NAV.unbuild`
  - POST `Microsoft.NAV.transfer` — `{targetLpNo, lines}`
  - POST `Microsoft.NAV.usePartial` — `{action, qty, lineNo?}`
  - POST `Microsoft.NAV.printLabel` — `{printerId, copies?}`
  - POST `Microsoft.NAV.nest` — `{parentLpNo}`
  - POST `Microsoft.NAV.unnest`
  - POST `Microsoft.NAV.start` (open new LP) + `Microsoft.NAV.stop`
- `al/src/LicensePlate/LPLineApi.Page.al` (P 72089) — `/licensePlateLines`

### LP pages

- `al/src/LicensePlate/LPCard.Page.al` (P 72069) — header + lines part + factbox actions
- `al/src/LicensePlate/LPList.Page.al` (P 72070) — filter location/bin/status/template
- `al/src/LicensePlate/LPTemplateList.Page.al` (P 72071)
- `al/src/LicensePlate/LPMovementLedger.Page.al` (P 72072) — read-only

### Print altyapısı

- `al/src/Print/IWXReportSelection.Table.al` (T 72007) — `Usage` (enum: LP Label, Receipt, Pick, Ship, Item, Bin, Posted Shipment, Custom 1-3), `Sequence`, `Report ID`, `Use For Email`, vs.
- `al/src/Print/PrintJobQueue.Table.al` (T 72022) — async print queue
- `al/src/Print/PrintJobLog.Table.al` (T 72023)
- `al/src/Print/PrintDispatcher.Codeunit.al` (CU 72051) — `PrintLabel(LP; PrinterId)` — channel'a göre dispatch
- `al/src/Print/PrintNodeClient.Codeunit.al` (CU 72052) — HTTP REST, API key Isolated Storage'dan
- `al/src/Print/IWXReportSelectionPage.Page.al` (P 72076)
- `al/src/Print/PrintJobLog.Page.al` (P 72079)
- `al/src/Print/LPLabel.Report.al` (R 72091) — ZPL section + RDLC fallback section; ZPL şablon: SSCC barcode + item summary + location + bin

### Enum'lar (eklenenler)

- `al/src/Enums/LPStatus.Enum.al` (Enum 72097) — Open, Built, Assigned, Used, Unbuilt
- `al/src/Enums/AssignedDocType.Enum.al` (Enum 72098)
- `al/src/Enums/LPAction.Enum.al` (Enum 72201)
- `al/src/Enums/PrintChannel.Enum.al` (Enum 72203) — PrintNode, BCNative
- `al/src/Enums/PartialUseAction.Enum.al` (Enum 72204)

### LP Migration placeholder

- `al/src/Upgrade/MigrateFromWI.Codeunit.al` (CU 72055) — boş iskelet; gerçek mantık Sprint 8
- `al/src/Upgrade/MigrationMapWI.Table.al` (T 72025) — boş

### Test

- `tests/src/LP/LPBuildTests.Codeunit.al` — build/stop/reopen
- `tests/src/LP/LPPartialUseTests.Codeunit.al` — 4 senaryo (CreateNewLP, RemoveExcess, RemoveUsedPortion, Unbuild)
- `tests/src/LP/LPNestingTests.Codeunit.al` — nest, unnest, depth limit, location mismatch, status mismatch
- `tests/src/LP/SSCCGeneratorTests.Codeunit.al` — uniqueness, check digit, extension-prefix flag
- `tests/src/LP/BinContentRollupTests.Codeunit.al` — **kritik** çift sayım kontrolü
- `tests/src/LP/LPTransferTests.Codeunit.al`

## Android İş Paketleri

### `:feature-lp`

- `feature/lp/LpLookupListScreen.kt` — filter chips (location/bin/status), TopAppBar
- `feature/lp/LpDocumentScreen.kt` — header + lines + bottom action bar (Build/Stop/Transfer/Print/Properties)
- `feature/lp/LpBuildModal.kt` — Compose ModalBottomSheet; template seç, location/bin pick
- `feature/lp/LpUsePartialBottomSheet.kt` — 4 action seçimi
- `feature/lp/LpTransferScreen.kt` — source LP + target LP scan + line selections
- `feature/lp/LpPropertiesScreen.kt` — Edit bin, template, weight, dimensions, notes
- `feature/lp/LpViewModel.kt`

### `:core-domain` LP usecase'leri

- `domain/usecase/BuildLp.kt`, `StopLp.kt`, `AssignLp.kt`, `UnbuildLp.kt`, `TransferLp.kt`, `AddLpLine.kt`, `RemoveLpLine.kt`, `PrintLpLabel.kt`, `NestLp.kt`, `UnnestLp.kt`, `UsePartialLp.kt`

### `:core-sync` LP ops

- `core/sync/Op.kt` sealed class genişletilir: `BuildLp`, `StopLp`, `AddLpLine`, `RemoveLpLine`, `AssignLp`, `UnbuildLp`, `TransferLp`, `PrintLpLabel`
- `core/sync/SyncWorker.kt` LP ops için handler

### `:core-printer`

- `core/printer/ZplBuilder.kt` — LP label ZPL üretimi (template-based)
- `core/printer/PrintNodeClient.kt` — Android'de de PrintNode REST'i çağırma (cihazın doğrudan yazıcıya erişimi olduğu senaryolar için; AL backend default)
- `core/printer/PrinterRegistry.kt`

### Test

- `feature/lp/test/LpUsePartialSheetTest.kt` — Compose UI
- `core/domain/test/BuildLpTest.kt`, `TransferLpTest.kt`

## Web İş Paketleri

(Bu sprint'te SPA yok; LP List Role Center sayfasında görünür.)

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET / POST / PATCH / DELETE | `/licensePlates`, `/licensePlates({no})` |
| GET / POST / PATCH / DELETE | `/licensePlates({no})/lines` |
| POST | `/licensePlates({no})/Microsoft.NAV.{assign,unbuild,transfer,usePartial,printLabel,nest,unnest,start,stop}` |

## Bağımlılıklar (Sprint 0-1'den)

- Setup table, No. Series altyapısı, Permission sets
- Barcode parser (LP barkod tipi tanır)
- Item Inquiry API (LP factbox için)
- Device Configuration (default LP template per device)

## Kritik Riskler

| Risk | Mitigation |
|---|---|
| `OnAfterCalcBinContent` subscriber performans regresyonu | Sprint 2 sonu performance test (10K LP, 50K line); KQL'de baseline ölç |
| Nested LP recursion infinite loop | `LPNestManager` depth check + cyclic reference check unit test'li |
| SSCC duplicate (race condition) | No. Series ile atomik üretim; uniqueness constraint DB seviyesinde |

## Bitiş Kriterleri (DoD)

- [ ] Mobilde build/stop akışı uçtan uca çalışıyor, label yazıcıya gidiyor
- [ ] 4 partial use senaryosu tam çalışıyor
- [ ] LP transfer 2 yönlü Movement Ledger entry üretiyor
- [ ] Nested LP rollup Bin Content'te çift sayım yapmıyor (kritik unit test geçti)
- [ ] LP API tüm bound action'lar Postman'de yeşil
- [ ] `LPManagement` codeunit coverage ≥ %85
- [ ] AppSourceCop warning=0
- [ ] `docs/lp-state-machine.md` LP state geçişleri diyagramı mevcut
- [ ] `docs/release-notes/sprint-2.md` mevcut
