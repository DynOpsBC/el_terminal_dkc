# Sprint 6 — Shipping + Sales/Transfer (2 hafta)

## Hedef

Warehouse Shipment'ı (ve doğrudan Sales Order ship / Transfer Order ship varyantlarını) mobilden post edilebilir hale getir. Sprint 5'te shipping LP olarak inşa edilen pallet'ler bu sprint'te postlandığında SSCC'leri posted shipment'a bağlanır ve packing slip otomatik yazıcıya basılır.

## Demo Kriterleri

1. Sprint 5'te register edilen pick → Whse Shipment "Released" durumda → mobilde **Ship** listesinde gözükür.
2. Doc aç → shipping LP'leri ile birlikte tüm satırlar listelenir → "Post" tetiklenir.
3. Posted Whse Shipment satırlarında `LP No.` ve `SSCC` görünür.
4. `IWX Report Selection` `Posted Shipment` usage → packing slip otomatik yazıcıya basılır (PrintNode).
5. Sales Order ship varyantı: Sales Order release → mobilde Ship listesinde + "Ship & Invoice" action seçilebilir.
6. Transfer Order ship varyantı: aynı UI, farklı doc tipi.
7. Eksik SSCC olan LP'ler için: Stop LP'de üretilmemişse Sprint 6 post sırasında otomatik üretilir + posted line'a yazılır.

## AL İş Paketleri

### Page extensions

- `al/src/Ship/WhseShipmentExt.PageExt.al` (PageExt 72307) — Whse Shipment Header (7320) üzerine "Post Mobile" + "Print Packing Slip" actions
- `al/src/Ship/SalesOrderExt.PageExt.al` (PageExt 72312) — Sales Order (42) "Ship Direct from Mobile" toggle

### Table extension

- `al/src/Ship/PostedWhseShipmentLineExt.TableExt.al` (TableExt 72405) — Posted Whse Shipment Line (7323) üzerine `LP No.`, `SSCC`

### Shipment API

- `al/src/Ship/ShipmentApi.Page.al` (P 72093) — `/shipments`, `/shipments({no})/lines`
  - PATCH `lines({lineNo})` — `{qtyToShip, licensePlateNo, sscc?}`
  - POST `Microsoft.NAV.post` — `{print, invoice}`

### Shipment Mgmt codeunit

- `al/src/Ship/ShipmentMgmt.Codeunit.al` (CU 72047)
  - `PostShipment(WhseShipment; PrintPackingSlip: Boolean; Invoice: Boolean)` — wraps standart `Whse.-Post Shipment`
  - Pre-post hook: SSCC eksik LP'ler için `SSCCGenerator.Generate()` çağrısı
  - Post hook: Posted Whse Shipment Line'a LP No + SSCC yaz
  - `IWX Report Selection` `Posted Shipment` usage'a göre report dispatch

### Ship-and-Invoice (Sales Order varyantı)

- `ShipmentMgmt.PostSalesOrderShipAndInvoice(SalesHeader)` — KB pattern wrap
- VAR'lar için event'li: `OnBeforeShipSales`, `OnAfterInvoiceSales`

### Shipment Queue Role Center

- `al/src/Ship/ShipmentQueue.Page.al` (P 72084) — ListPart; Whse Shipment + Sales (Ship Pending) + Transfer (Ship Pending) union view

### IWX Report Selection — Posted Shipment usage

- Sprint 2'de oluşturulan `IWX Report Selection` tablosuna seed: Usage = `Posted Shipment`, Report ID = standart 7321 veya custom 72092

### Test

- `tests/src/Ship/ShipmentPostingTests.Codeunit.al` — happy path
- `tests/src/Ship/SSCCOnPostTests.Codeunit.al` — eksik SSCC otomatik üretilir
- `tests/src/Ship/ShipAndInvoiceTests.Codeunit.al` — Sales Order varyantı
- `tests/src/Ship/TransferShipTests.Codeunit.al`
- `tests/src/Integration/EndToEndOutboundTests.Codeunit.al` — Pick → Ship → Posted

## Android İş Paketleri

### `:feature-ship`

- `feature/ship/ShipLookupListScreen.kt`
  - Default filter: Whse Shipment "Released"
  - Toggle: "Show Open" (released değilse de göster)
  - Source type chip: Whse / Sales / Transfer
- `feature/ship/ShipDocumentScreen.kt`
  - Source type'a göre küçük varyasyonlar, ortak UI
  - Bottom action: Post / Print / "Ship & Invoice" (sadece Sales için)
  - Confirm dialog: progress göstergesi, cancel disabled
- `feature/ship/ShipViewModel.kt`

### `:core-domain` ship usecase'leri

- `domain/usecase/GetShipments.kt`, `ConfirmShipLine.kt`, `PostShipment.kt`, `PostShipAndInvoice.kt`

### `:core-sync` ops

- `Op.kt`: `ConfirmShipLine` (queue-able), `PostShipment` (online-only)

### Test

- `feature/ship/test/ShipViewModelTest.kt` — 3 doc tipi
- `feature/ship/test/ShipDocumentScreenTest.kt` — Compose UI

## Web İş Paketleri

- `al/src/Ship/ShipmentQueue.Page.al` (yukarıda) — AL Role Center sayfası
- Sprint 8'de Warehouse Manager RC'ye tile olarak eklenecek

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET | `/shipments`, `/shipments({no})/lines` |
| PATCH | `/shipments({no})/lines({lineNo})` |
| POST | `/shipments({no})/Microsoft.NAV.post` |

## Bağımlılıklar (önceki sprintlerden)

- Pick + shipping LP (Sprint 5)
- SSCC Generator (Sprint 2)
- IWX Report Selection altyapısı (Sprint 2)
- Print Dispatcher (Sprint 2)

## Performans Hedefleri

| Metrik | Hedef |
|---|---|
| Shipment list | p95 ≤ 1200 ms |
| Post action (20 satır, 3 LP) | p95 ≤ 8000 ms |
| Packing slip print kuyruğa girme | ≤ 500 ms |

## Bitiş Kriterleri (DoD)

- [ ] Whse / Sales / Transfer ship varyantları mobilden post ediliyor
- [ ] Posted line'da LP No + SSCC görünüyor
- [ ] Eksik SSCC otomatik üretiliyor (post sırasında)
- [ ] Packing slip PrintNode'a gidiyor (sandbox test printer)
- [ ] Ship & Invoice Sales Order varyantı çalışıyor
- [ ] `ShipmentMgmt` coverage ≥ %75
- [ ] AppSourceCop warning=0
- [ ] `docs/release-notes/sprint-6.md` mevcut
