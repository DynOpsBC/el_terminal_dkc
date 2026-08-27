# Sprint 3 — Receiving (2 hafta)

## Hedef

Warehouse Receipt, Purchase Order direct, Transfer Order receive akışlarını mobilde uçtan uca çalışır hale getir. LP build-during-receive akışı bu sprint'in temel kazanımı: alıcı, malzemeyi okuturken aynı anda pallet LP'sini inşa ediyor.

## Demo Kriterleri

1. Sandbox'ta Released PO oluştur (5 satır, 100 adet) → Whse Receipt yarat → mobilde **Receive** açılır → doc no okutunca satırlar gelir.
2. "Start LP" → 3 satırı LP'ye okut (LP build during receive) → "Stop LP" → label yazıcıya gider, SSCC üretilir.
3. GS1-128 barkodu okutulan bir satır lot/expiry'yi otomatik dolduruyor.
4. "Post" tetiklenir → BC'de Posted Whse Receipt oluşur, posted line'larda `LP No.` ve `SSCC` görünür.
5. Web Role Center'da **AWMS Receiving Queue** açılır → atanan kullanıcı + % complete bar görünür → "Assign User" action çalışır.
6. Offline test: havayolu modu aç → "Post" butonu disabled + tooltip "Çevrimdışıyken kayıt yapılamaz".

## AL İş Paketleri

### Page extensions (3 sayfa)

- `al/src/Receiving/WhseReceiptExt.PageExt.al` (PageExt 72303) — Whse Receipt (7316) üzerine "Assigned User", "Start LP", "Stop LP" action'ları
- `al/src/Receiving/PurchaseOrderExt.PageExt.al` (PageExt 72304) — Purchase Order (50) üzerine "Mobile Scan" action group
- `al/src/Receiving/TransferOrderExt.PageExt.al` (PageExt 72305) — Transfer Order (5740) receive side

### Table extension

- `al/src/Receiving/PostedWhseReceiptLineExt.TableExt.al` (TableExt 72404) — Posted Whse Receipt Line (7319) üzerine `LP No.` alanı

### Receipt API

- `al/src/Receiving/ReceiptApi.Page.al` (P 72090) — `/receipts`, `/receipts({no})`, `/receipts({no})/lines`
  - PATCH `lines({lineNo})` — `{qtyToReceive, lotNo, serialNo, expiryDate, licensePlateNo, binCode}`
  - POST `Microsoft.NAV.assignToUser` — `{userId}`
  - POST `Microsoft.NAV.startLP` — `{lpTemplateCode}` → `{lpNo}`
  - POST `Microsoft.NAV.stopLP` — `{lpNo, printLabel}`
  - POST `Microsoft.NAV.post` — `{print, invoice}`

### Receipt Mgmt codeunit

- `al/src/Receiving/ReceiptMgmt.Codeunit.al` (CU 72043) — `Whse.-Post Receipt`'i wrap eder; LP'yi posted line'a `LP No.` ve `Package No.` üzerinden bağlar; LP'yi `Assigned` durumuna alır

### Legacy WI event compatibility

- `al/src/Events/LegacyWIPublisher.Codeunit.al` (CU 72054) — re-publish (VAR compatibility):
  - `[IntegrationEvent] OnGetReceiptDocument(50001)` — yeni event'i wrap eder
  - `[IntegrationEvent] OnGetPurchaseOrder(50005)`
  - `[IntegrationEvent] OnGetTransferOrder(50013)`

### Receiving Queue Role Center

- `al/src/Receiving/ReceivingQueue.Page.al` (P 72082) — ListPart; columns: No, Source No, Source Type, Vendor/Source Name, Due Date, Assigned User, % Complete (FlowField)
- Action: "Assign to User" (modal user picker)

### Test

- `tests/src/Receipt/ReceiptPostingTests.Codeunit.al` — happy path, partial receipt, over-receive disabled
- `tests/src/Receipt/ReceiptWithLPTests.Codeunit.al` — LP'li receipt + posted line LP No. doğrulama
- `tests/src/Integration/EndToEndReceiveTests.Codeunit.al` — PO → Whse Receipt → mobil flow → Post → Posted Whse Receipt → Item Ledger Entry zinciri

## Android İş Paketleri

### `:feature-receive` (spec §10.1 canonical template — diğer feature'lar bu pattern'i takip eder)

- `feature/receive/ReceiveLookupListScreen.kt` — Compose
  - TopAppBar: title "Receive", refresh, filter
  - Search field: doc no, source no, external doc no
  - LazyColumn: No, Source No, Vendor Name, Due Date, Assigned User chip, % complete bar
- `feature/receive/ReceiveDocumentScreen.kt`
  - Header card: doc no, source, vendor, due date, assigned user
  - LazyColumn lines (sticky line-of-focus)
  - Bottom action bar: Post / Print / Start-Stop LP toggle / overflow
  - Overflow: Close, Change Qty, Enter Bin, Enter Item, Enter LP, Hide/Show Completed, Item Inquiry, Bin Inquiry
- `feature/receive/QuantityDialogSheet.kt` — ModalBottomSheet
  - Qty stepper, UoM dropdown, Lot/Serial fields (if tracked), Expiry
  - "+1" big primary button
  - Cancel / Confirm
- `feature/receive/ReceiveViewModel.kt` — MVI
  - State: header, lines, selectedLp, mode (scan-bin/item/lp), offline status
  - Intent: ScanBarcode, ChangeQty, StartLp, StopLp, PostDocument

### `:core-domain` receipt usecase'leri

- `domain/usecase/GetReceipt.kt`, `ConfirmReceiptLine.kt`, `PostReceipt.kt`, `StartReceiptLp.kt`, `StopReceiptLp.kt`, `AssignReceiptToUser.kt`

### `:core-sync` receipt ops

- `Op.kt` genişletme: `ConfirmReceiptLine`, `AssignReceipt`, `StartReceiptLp`, `StopReceiptLp` (Post asla queue'da değil — online-only)

### Offline davranışı

- `feature/receive/ReceiveDocumentScreen.kt`'te Post butonu `connectivityObserver.isOnline` Flow'una bağlı
- Offline'da tooltip: "Çevrimdışıyken kayıt yapılamaz"
- Diğer mutations (qty, LP) queue'ya yazılır, replay olunca confirmation

### Test

- `feature/receive/test/ReceiveViewModelTest.kt` — happy path, GS1-128 parse, mode switch
- `feature/receive/test/ReceiveDocumentScreenTest.kt` — Compose UI + Roborazzi

## Web İş Paketleri

- `al/src/Receiving/ReceivingQueue.Page.al` (yukarıda) — AL Role Center sayfası; SPA değil
- "Receiving Queue" Role Center'a tile + listpart olarak eklenir (Sprint 8 Warehouse Manager RC'ye entegrasyon)

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET | `/receipts`, `/receipts({no})`, `/receipts({no})/lines` |
| PATCH | `/receipts({no})/lines({lineNo})` |
| POST | `/receipts({no})/Microsoft.NAV.{assignToUser,startLP,stopLP,post}` |

## Bağımlılıklar (Sprint 0-2'den)

- LP Mgmt + LP API + SSCC + Print Dispatcher (Sprint 2)
- Barcode Parser GS1-128 AI desteği (Sprint 1)
- Whse Receipt standart BC mevcut (sandbox seed verisinde)

## Performans Hedefleri

| Metrik | Hedef |
|---|---|
| Receipt doc list ilk yükleme | p95 ≤ 1500 ms (50 satır) |
| Receipt line PATCH | p95 ≤ 1200 ms |
| Post action | p95 ≤ 5000 ms (10 satır) |
| Cold start → ilk satır görünür | ≤ 5 sn (online) |

## Bitiş Kriterleri (DoD)

- [ ] PO → Whse Receipt → mobilde 5 satır + LP build → Post → Posted Whse Receipt zinciri çalışıyor
- [ ] LP No. posted line'da görünüyor
- [ ] Offline'da Post disabled, queue'daki mutations replay oluyor
- [ ] Receiving Queue Role Center sayfası AL'de açılıyor, drag-drop assign çalışıyor
- [ ] `ReceiptMgmt` codeunit coverage ≥ %75
- [ ] AL test runner yeşil
- [ ] `docs/release-notes/sprint-3.md` mevcut
