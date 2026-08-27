# Sprint 5 — Picking (2 hafta)

## Hedef

Warehouse Pick + Inventory Pick akışları, **pick-to-LP** varsayılan davranışıyla. Pick supervisor'un atama yapabileceği ilk SPA bileşeni (Pick Board, React) bu sprint'te canlanır. Webhook-driven realtime pick board için Azure Function push-relay aktive edilir.

## Demo Kriterleri

1. Released Whse Shipment'tan Whse Pick oluştur → mobilde **Pick** listesinde "Assigned to Me" filter + "Show All" toggle.
2. Pick aç → "Start LP" otomatik (default ON) → take satırları LP'ye eklenir → place satırında "Stop LP" → SSCC üretilir + label.
3. **Short pick**: bir satır için "Mark Short" → reason picker → Backorder mantığı standart BC tarafında yürür.
4. **Switch Take/Place**: WI 13.2 paritesinde aynı satır arasında geçiş.
5. Supervisor web Role Center → **Pick Board** SPA → 3 picker, 5 pick → drag-drop bir pick'i başka picker'a sürükle → 2 saniye içinde mobilde "Pick reassigned" notification.
6. Sandbox webhook → Azure Function → SignalR/FCM uçtan uca çalışıyor.

## AL İş Paketleri

### Pick tabloları + extension

- `al/src/Pick/ShortPickReason.Table.al` (T 72015) — `Code`, `Description`, `Default`, `Allows Backorder`
- `al/src/Pick/ReassignHistory.Table.al` (T 72021) — audit
- `al/src/Sync/SyncConflict.Table.al` (T 72019) — ETag 412 → conflict buffer (mobil için)
- `al/src/Events/WebhookAudit.Table.al` (T 72020) — webhook log
- `al/src/Pick/WhsePickHeaderExt.PageExt.al` (PageExt 72311) — Whse Pick Header (7340) "Assigned User" filter ve action ekler
- `al/src/Pick/ShortPickReasonList.Page.al` (P 72073)
- `al/src/Sync/SyncConflictList.Page.al` (P 72080)

### Pick API

- `al/src/Pick/PickApi.Page.al` (P 72092) — `/picks`, `/picks({no})/lines`
  - POST `Microsoft.NAV.assignToMe`
  - PATCH `lines({lineNo})` — `{qtyToHandle, binCode, licensePlateNo}`
  - POST `Microsoft.NAV.startShippingLP` — `{lpTemplateCode}` → `{lpNo}`
  - POST `Microsoft.NAV.stopShippingLP` — `{lpNo, sscc?}`
  - POST `Microsoft.NAV.markShort` — `{lineNo, qty, reasonCode}`
  - POST `Microsoft.NAV.register`
  - POST `Microsoft.NAV.reassign` — `{userId}` (supervisor permission gerekli)

### Pick Mgmt + Pick Strategy

- `al/src/Enums/IPickStrategy.Interface.al` (Interface 72207) — `procedure SuggestNextLine(var WhseActivityLine): Boolean`
- `al/src/Pick/PickMgmt.Codeunit.al` (CU 72046)
  - `StartShippingLP(Pick; Template)` — create LP in shipping zone
  - `RegisterShortPick(Line; Qty; Reason)` — backorder marker
  - `RegisterPick(Pick)` — wrap standart `Whse.-Activity-Register`
  - `ReassignPick(Pick; NewUser)` — audit + webhook publish

### Webhook altyapısı (BC subscriptions)

- `al/src/Events/WebhookMgmt.Codeunit.al` (CU 72053) — `picks`, `licensePlates`, `shipments` resource'ları için BC standart webhook subscription register
- `al/src/Events/WebhookEventPublisher.Codeunit.al` — entity change → BC webhook trigger

### Pick Queue Role Center

- `al/src/Pick/PickQueue.Page.al` (P 72083) — ListPart + ControlAddIn `DOPSWHS Pick Board`
- Action: "Manual Reassign" (table-driven, SPA olmadan da çalışır)

### ControlAddIn (Vite build output'unu host eden AL resource)

- `al/src/ControlAddIn/PickBoard.ControlAddIn.al` (ControlAddIn 72501) — `Scripts: ['Resources/pickBoard.js']`, `StyleSheets: ['Resources/pickBoard.css']`, BC bridge procedures
- AL'den SPA'ya `setData(json)`, `setLocale(code)`, `applyFilter(json)`
- SPA'dan AL'ye `reassign(pickNo, userId)`, `requestRefresh()`

### Test

- `tests/src/Pick/PickRegisterTests.Codeunit.al`
- `tests/src/Pick/PickToLPTests.Codeunit.al` — shipping LP build during pick
- `tests/src/Pick/ShortPickTests.Codeunit.al` — backorder allocation kontrolü
- `tests/src/Pick/ReassignmentTests.Codeunit.al` — permission, audit
- `tests/src/Events/WebhookSubscriptionTests.Codeunit.al`

## Android İş Paketleri

### `:feature-pick`

- `feature/pick/PickLookupListScreen.kt`
  - Default filter: "assigned to me"; toggle "Show All"
  - Status badge: Open / In Progress / Done
- `feature/pick/PickDocumentScreen.kt`
  - Take/Place satırları renkli ayrım
  - "Switch Take/Place" action (WI 13.2 parite)
  - Start LP otomatik (config flag ile kapatılabilir)
  - Bottom action: Register / Mark Short
- `feature/pick/ShortPickDialog.kt` — reason picker modal
- `feature/pick/PickViewModel.kt`

### `:core-domain` pick usecase'leri

- `GetPicks.kt`, `AssignPickToMe.kt`, `ConfirmPickLine.kt`, `StartShippingLp.kt`, `StopShippingLp.kt`, `MarkPickShort.kt`, `RegisterPick.kt`

### `:core-sync` ops

- `Op.kt`: `AssignPickToMe`, `ConfirmPickLine`, `StartShippingLp`, `StopShippingLp`, `MarkPickShort`
- Register asla queue'da değil — online only (Post gibi)

### Push notification

- FCM push handler: `PickReassignedNotification.kt` — Snackbar + auto-refresh
- `core/network/PushTokenRegistrar.kt` — FCM token'ı BC'ye device registration ile birlikte gönderir

### Test

- `feature/pick/test/PickViewModelTest.kt` — pick-to-LP flow
- `feature/pick/test/ShortPickDialogTest.kt`

## Web İş Paketleri (İLK SPA BİLEŞENİ)

### React + Vite SPA

- `web/src/pickBoard/PickBoardApp.tsx` — top-level component
- `web/src/pickBoard/PickerColumn.tsx` — picker bazlı kolon
- `web/src/pickBoard/PickCardDraggable.tsx` — react-dnd ile drag-drop kart
- `web/src/pickBoard/ReassignMutation.ts` — BC bridge ile reassign çağrısı
- `web/src/al-bridge/ControlAddInBridge.ts` — postMessage protokolü
- `web/vite.config.ts` — entry `pickBoard` için ayrı bundle, output `../al/src/ControlAddIn/Resources/pickBoard.{js,css}`
- `web/tests/pickBoard.spec.ts` — Playwright E2E (BC'siz, mock veri)

### SignalR realtime

- v1.0 default: 5-saniye polling (`useSWR`)
- v1.1 hedefi: SignalR `@microsoft/signalr` ile gerçek zamanlı; bu sprint'te scaffold edilir, polling fallback aktif

## Push Relay Azure Function (aktivasyon)

- `push-relay/webhook/index.ts` — BC HMAC verify + dispatch
- `push-relay/signalr/negotiate/index.ts` — SignalR connection negotiate
- `push-relay/shared/BcHmacVerifier.ts`
- `push-relay/shared/FcmClient.ts` — FCM HTTP v1 send
- `push-relay/infra/main.bicep` — deployment (manual trigger CI'dan)

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET | `/picks`, `/picks({no})/lines` |
| POST | `/picks({no})/Microsoft.NAV.{assignToMe,startShippingLP,stopShippingLP,markShort,register,reassign}` |
| PATCH | `/picks({no})/lines({lineNo})` |

## Webhook Subscriptions Setup (Sandbox seed)

Sprint 5 sonunda sandbox'a aşağıdaki webhook subscription'lar otomatik kaydedilir (Setup Wizard genişlemesi):

- Resource `picks` → endpoint `https://<azure-func>.azurewebsites.net/api/webhook`
- Resource `licensePlates` → aynı
- Resource `shipments` → aynı

## Bağımlılıklar (önceki sprintlerden)

- LP Mgmt (Sprint 2) — shipping LP build için
- Standard Whse Pick (BC) — sandbox'ta release edilmiş Whse Shipment'tan pick oluşturulabiliyor
- Push relay infra deploy (bu sprint'te aktif)
- React+Vite web/ skeleton (Sprint 0'da hazır)

## Performans Hedefleri

| Metrik | Hedef |
|---|---|
| Pick list ilk yükleme (assigned to me) | p95 ≤ 1200 ms |
| Pick line PATCH | p95 ≤ 800 ms |
| Register pick (10 satır) | p95 ≤ 4000 ms |
| Pick reassign latency (drag → mobilde notification) | ≤ 2 sn |

## Bitiş Kriterleri (DoD)

- [ ] Released Whse Shipment → mobil pick → register zinciri çalışıyor
- [ ] Pick-to-LP default ON; Stop LP'de SSCC üretilir + label yazıcıya gider
- [ ] Short pick reason picker çalışıyor, backorder allocation testi geçiyor
- [ ] Web Pick Board SPA Vite build edilip AL ControlAddIn resource olarak BC'de render oluyor
- [ ] Drag-drop reassign → BC'ye PATCH → mobil device notification (push veya 5-sn polling) çalışıyor
- [ ] Azure Function push-relay deploy edildi, HMAC verify yeşil
- [ ] `PickMgmt` coverage ≥ %75
- [ ] Playwright E2E pick board mock'lu yeşil
- [ ] `docs/release-notes/sprint-5.md` mevcut
