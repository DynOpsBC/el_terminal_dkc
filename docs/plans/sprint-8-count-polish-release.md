# Sprint 8 — Count + Polish + Release (2 hafta)

## Hedef

İnventory count (Basic + Advanced multi-counter), WI 2.x migration codeunit'ini tamamlama, çevirileri kapatma, Warehouse Manager Role Center KPI'larını ve LP Browser SPA'yı tamamlayarak v1.0 RC'ye hazır hale getir.

## Demo Kriterleri

1. Sandbox'ta cycle count batch oluştur → mobilde **Count** açılır → blind count modu seçilir → 3 counter atanır.
2. Her counter aynı bin'de sayım yapar → variance review web Role Center'da görünür → recount tetiklenir.
3. Posting → Phys. Inv. Journal'a variance entry → Item Ledger Entry oluşur.
4. Web **Warehouse Manager Role Center** → 6 KPI tile (Open Receipts/Picks/Shipments, Late Picks, Unbuilt LPs, Count Discrepancies, Devices Online) güncel verilerle doluyor.
5. Web **LP Browser SPA** → nested LP tree görünür → drag ile child LP'yi başka parent'a sürükle → BC'de nesting güncellenir → right-click "Print Label" çalışır.
6. **WI 2.x migration**: test sandbox'a WI 2.3 verisi yüklendi → "Migrate from WI" wizard → dry-run rapor → apply → DOPSWHS tablolarına geçiş başarılı.
7. en-US / tr-TR / de-DE çevirileri tüm UI'da doğru — Setup Wizard, Mobile, Role Center.

## AL İş Paketleri

### Count tabloları

- `al/src/Count/CountSheetHeader.Table.al` (T 72016) — `No.`, `Location Code`, `Mode` (Enum 72205: Blind/Visible/Recount), `Status`, `Created DateTime`, `Posted DateTime`, `Source Phys. Inv. Journal Batch`
- `al/src/Count/CountSheetLine.Table.al` (T 72017) — `Sheet No.`, `Line No.`, `Item No.`, `Bin Code`, `LP No.`, `System Qty`, `Counted Qty 1`, `Counted Qty 2`, `Counted Qty 3`, `Variance`, `Recount Required`
- `al/src/Count/CountCounter.Table.al` (T 72018) — `Sheet No.`, `Counter Slot`, `User ID`, `Assigned DateTime`
- `al/src/Enums/CountMode.Enum.al` (Enum 72205)

### Count API

- `al/src/Count/CountApi.Page.al` (P 72221) — `/countSheets`
  - GET — `$filter=status`
  - POST — `{locationCode, mode, counters: [userId]}`
  - GET `lines`
  - PATCH `lines({lineNo})` — `{countedQty, counterUserId}`
  - POST `Microsoft.NAV.startRecount` — `{lineNo}`
  - POST `Microsoft.NAV.post`

### Count Mgmt codeunit

- `al/src/Count/CountMgmt.Codeunit.al` (CU 72050)
  - `CreateSheet(Location; Mode; Counters)` — Phys. Inv. Journal Batch yarat
  - `RecordCount(Sheet; Line; CounterSlot; Qty)`
  - `EvaluateVariance(Sheet)` — counter slot'ları karşılaştır, `Recount Required` flag
  - `PostSheet(Sheet)` — variance'ı Phys. Inv. Journal'a post

### Phys. Inv. Journal extension

- `al/src/Count/PhysInvJournalExt.PageExt.al` (PageExt 72310) — Phys. Inv. Journal (191) üzerine "Count Sheet Source" reference

### Count pages

- `al/src/Count/CountSheetList.Page.al` (P 72074)
- `al/src/Count/CountSheetCard.Page.al` (P 72075)
- `al/src/Count/CountVarianceReview.Page.al` (P 72085) — supervisor variance approve UI; web Role Center'da yer alır
- `al/src/Count/CountVariance.Report.al` (R 72093)

### Warehouse Manager Role Center

- `al/src/RoleCenter/WarehouseManagerRC.Page.al` (P 72081) — RoleCenter pageType
  - Cue Group: Receipts (Open count), Picks (Open count), Shipments (Released count), Late Picks (SLA breach), Unbuilt LPs, Count Discrepancies, Devices Online
  - Each tile drillthrough to relevant queue page
- `al/src/RoleCenter/WarehouseManagerCue.Table.al` — cue values FlowField'lar

### WI Migration tamamlama

- `al/src/Upgrade/MigrateFromWI.Codeunit.al` (CU 72055) tam implementasyon:
  - `PreflightCheck()` — WI sürüm tespiti, conflict raporu
  - `DryRun()` — kaç satır, kaç çakışma, varolan target verisi
  - `Apply(LocationCode)` — transaction içinde tablo-tablo kopya, audit
  - `Cutover(LocationCode)` — WI location feature flag kapat
  - `Rollback(SnapshotNo)` — backup table'dan geri al
- `al/src/Upgrade/MigrationMapWI.Table.al` (T 72025) — field mapping seed
- `al/src/Upgrade/MigrateFromWI.Page.al` — Card UI (wizard tarzı)

### Upgrade codeunit + Entitlement

- `al/src/Upgrade/Upgrade.Codeunit.al` (CU 72034) — OnUpgradePerDatabase / OnUpgradePerCompany; obsolete tag handling
- `al/src/Setup/Entitlement.Codeunit.al` (CU 72056) — per-device licensing kontrolü (Sprint 0'da placeholder, burada tam)

### Translation

- `al/Translations/DOPSWHS.g.xlf` — AL compiler tarafından regenerate
- `al/Translations/DOPSWHS.tr-TR.xlf` — tüm string'ler çevrildi, `docs/i18n-glossary.md`'ye uyumlu
- `al/Translations/DOPSWHS.de-DE.xlf` — aynı

### ControlAddIn (LP Browser için ek)

- `al/src/ControlAddIn/LPBrowser.ControlAddIn.al` (ControlAddIn 72500) — `Scripts: ['Resources/lpBrowser.js']`, `StyleSheets: ['Resources/lpBrowser.css']`, bridge procedures (`setData`, `nestLp`, `unnestLp`, `printLabel`)

### Test

- `tests/src/Count/CountSheetCreateTests.Codeunit.al`
- `tests/src/Count/CountVarianceTests.Codeunit.al` — 3-counter senaryosu, recount
- `tests/src/Count/CountPostTests.Codeunit.al` — Phys. Inv. Journal'a doğru post
- `tests/src/Migration/WIMigrationTests.Codeunit.al` — preflight, dry-run, apply, rollback
- `tests/src/Integration/FullE2ETests.Codeunit.al` — Receive → Putaway → Pick → Ship + Count cycle

## Android İş Paketleri

### `:feature-count`

- `feature/count/CountSheetLookupListScreen.kt`
- `feature/count/CountSheetDocumentScreen.kt`
- `feature/count/BlindCountScreen.kt` — sistem qty'sini gizle
- `feature/count/CountViewModel.kt`

### `:core-domain` count usecase'leri

- `CreateCountSheet.kt`, `RecordCount.kt`, `StartRecount.kt`, `PostCountSheet.kt`

### `:core-sync` ops

- `Op.kt`: `RecordCount` (queue), `PostCountSheet` (online-only)

### Polish + i18n

- Tüm strings.xml → tr.xml, de.xml çeviri
- Accessibility audit — TalkBack tüm screen'lerde test
- Performance polish — Compose recomposition profili
- Crashlytics 0 crash hedef

### Test

- `feature/count/test/CountViewModelTest.kt`

## Web İş Paketleri

### LP Browser SPA

- `web/src/lpBrowser/LpBrowserApp.tsx` — top-level component
- `web/src/lpBrowser/LpTreeNode.tsx` — recursive tree node
- `web/src/lpBrowser/DragNestHandler.ts` — react-dnd ile drag-nest
- `web/src/lpBrowser/PrintMenu.tsx` — right-click context menu
- `web/src/lpBrowser/BinMoveModal.tsx`
- `web/vite.config.ts` — entry `lpBrowser` ekle, output `../al/src/ControlAddIn/Resources/lpBrowser.{js,css}`

### i18n

- `web/src/i18n/{en,tr,de}.json` — `react-i18next` ile

### Test

- `web/tests/lpBrowser.spec.ts` — Playwright E2E

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET / POST | `/countSheets`, `/countSheets({no})/lines` |
| PATCH | `/countSheets({no})/lines({lineNo})` |
| POST | `/countSheets({no})/Microsoft.NAV.{startRecount,post}` |

## Bağımlılıklar (önceki sprintlerden)

- Phys. Inv. Journal standart BC mevcut
- LP Mgmt (Sprint 2) — LP scan ile count
- Warehouse Manager RC için cue source'lar: Sprint 3-7 queue tabloları/sayfaları

## Bitiş Kriterleri (DoD)

- [ ] Basic + Advanced count akışları mobilden post ediliyor
- [ ] 3-counter blind count → variance → recount → post zinciri çalışıyor
- [ ] WI 2.x migration codeunit dry-run + apply + rollback yeşil testte
- [ ] Warehouse Manager Role Center 6 KPI tile gerçek veriyle doluyor
- [ ] LP Browser SPA Vite build → AL resource → BC'de render → drag-nest + print çalışıyor
- [ ] en-US / tr-TR / de-DE çevirileri %100 complete
- [ ] Upgrade codeunit eski versiyonu test ediyor (`v0.9 → v1.0` upgrade integrity test)
- [ ] AppSourceCop + CodeCop + UICop + PerTenantExtensionCop warning=0
- [ ] AL test runner ≥%80 coverage
- [ ] `docs/release-notes/sprint-8.md` mevcut
- [ ] **v1.0-rc1 tag** atıldı, hardening sprint başlıyor
