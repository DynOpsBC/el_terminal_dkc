# Sprint 4 — Put-Away + Movements (2 hafta)

## Hedef

Posted Whse Receipt'ten kaynaklanan Put-Away aktivitesini ve hem Ad-Hoc (Item Reclass Journal) hem Directed (Whse Movement document) bin-to-bin hareketleri mobilde tamamlanır hale getir. Directed PutAway'in suggested-bin algoritmasını pluggable strategy olarak inşa et — bu Sprint 5 Pick stratejisi için de pattern oluşturur.

## Demo Kriterleri

1. Sprint 3'teki posted Whse Receipt'ten Put-Away oluşturulur → mobilde **Put-Away** listesinde gözükür.
2. Doc açılır → her satır için suggested bin görünür (zone rank + bin rank + capacity); kullanıcı onaylar → register.
3. LP'den auto-fill: kaynak bin'den LP barkodu okutunca tüm LP içeriği satır olarak gelir.
4. Bin Content güncel: receipt + putaway sonrası item qty doğru bin'de.
5. **Ad-Hoc Move**: mobilde "Quick Move" → source bin scan → item/LP scan → target bin scan → confirm → Item Reclass Journal'a post, ledger entry'ler doğru.
6. **Directed Move**: Whse Movement document oluştur → mobil register flow → bin contents güncel.

## AL İş Paketleri

### Whse Activity page extension

- `al/src/PutAway/WhseActivityExt.PageExt.al` (PageExt 72306) — Whse. Activity Header (7330) page extension; Put-away, Pick, Movement aynı sayfayı kullanır; bu ext üçünde de geçerli olacak ek action'lar (LP scan, mobile sync)

### Table extension

- `al/src/PutAway/WhseActivityLineExt.TableExt.al` (TableExt 72403) — Warehouse Activity Line (5767) üzerine `LP No.` (kaynak LP), `Target LP No.` (hedef LP)

### PutAway API

- `al/src/PutAway/PutAwayApi.Page.al` (P 72091) — `/putaways`, `/putaways({no})/lines`
  - PATCH `lines({lineNo})` — `{qtyToHandle, binCode, licensePlateNo}`
  - POST `Microsoft.NAV.suggestBin` — `{itemNo, qty}` → `{binCode, zone}`
  - POST `Microsoft.NAV.register`

### Directed PutAway codeunit + interface

- `al/src/Enums/IPutAwayStrategy.Interface.al` (Interface 72206) — `procedure SuggestBin(Item; Qty; Location; var BinCode; var Reason)`
- `al/src/PutAway/DirectedPutAway.Codeunit.al` (CU 72044) — varsayılan strategy: zone rank → bin rank → capacity → mixing rules
- VAR'lar kendi strategy implementasyonlarını `IPutAwayStrategy` üzerinden ekleyebilir; setup'tan strategy seçimi (`Setup.PutAway Strategy Code`)

### Movement API

- `al/src/Movement/MovementApi.Page.al` (P 72220) — `/movements`
  - POST `Microsoft.NAV.adhoc` — `{fromBin, toBin, itemNo?, lpNo?, qty}` (Item Reclass Journal'a post)
  - GET `/movements` — `$filter=type` (AdHoc/Directed)
  - POST `Microsoft.NAV.register` — Directed Whse Movement register

### Movement Mgmt codeunit

- `al/src/Movement/MovementMgmt.Codeunit.al` (CU 72045)
  - `AdHocMove(fromBin, toBin, item|lp, qty)` — Item Reclass Journal Line yarat + post
  - `RegisterDirected(WhseActivityHeader)` — standart `Whse.-Activity-Register` wrap
  - Critical: KB pattern "reclass batches must NOT be hardcoded across multiple scanners" → cihaz başına unique journal template/batch

### Test

- `tests/src/PutAway/PutAwayRegisterTests.Codeunit.al` — happy path, suggested bin
- `tests/src/PutAway/PutAwayLPAutoFillTests.Codeunit.al`
- `tests/src/Movement/AdHocMoveTests.Codeunit.al` — bin-to-bin, LP move
- `tests/src/Movement/DirectedMoveTests.Codeunit.al`
- `tests/src/Movement/JournalBatchIsolationTests.Codeunit.al` — KB risk koruması

## Android İş Paketleri

### `:feature-putaway`

- `feature/putaway/PutAwayLookupListScreen.kt` — assigned-to-me filter default
- `feature/putaway/PutAwayDocumentScreen.kt`
  - Suggested bin gösterimi
  - LP scan → auto-fill flow
  - Split menu (Whse Pick parite)
  - Bottom action: Register
- `feature/putaway/PutAwayViewModel.kt`

### `:feature-move`

- `feature/move/AdHocMoveScreen.kt` — single-screen flow: source bin → item/LP → target bin → confirm
- `feature/move/DirectedMoveScreen.kt` — list + doc
- `feature/move/MoveViewModel.kt`

### `:core-domain` putaway/move usecase'leri

- `domain/usecase/GetPutAway.kt`, `SuggestBin.kt`, `ConfirmPutAwayLine.kt`, `RegisterPutAway.kt`
- `domain/usecase/AdHocMove.kt`, `RegisterDirectedMove.kt`

### `:core-sync` ops

- `Op.kt` genişletme: `ConfirmPutAwayLine`, `RegisterPutAway`, `AdHocMove`, `RegisterDirectedMove`

### Test

- `feature/putaway/test/PutAwayViewModelTest.kt` — LP auto-fill
- `feature/move/test/AdHocMoveViewModelTest.kt`

## Web İş Paketleri

(Bu sprint'te yeni Role Center sayfası yok; Receiving Queue pattern'i Movement için tekrar kullanılır — bu küçük iş Sprint 8'de toplanır.)

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET | `/putaways`, `/putaways({no})/lines` |
| PATCH | `/putaways({no})/lines({lineNo})` |
| POST | `/putaways({no})/Microsoft.NAV.suggestBin` |
| POST | `/putaways({no})/Microsoft.NAV.register` |
| GET | `/movements` |
| POST | `/movements/Microsoft.NAV.adhoc` |
| POST | `/movements({no})/Microsoft.NAV.register` |

## Bağımlılıklar (önceki sprintlerden)

- LP API + LP'den item listesi okuma (Sprint 2)
- Posted Whse Receipt mevcut (Sprint 3) — putaway oluşturmak için
- Standart BC Whse Activity sayfası 7330 (kullanılıyor, modifiye edilmiyor)

## Pluggable Strategy Pattern Notu

- `IPutAwayStrategy` interface'i Sprint 5'teki `IPickStrategy` için template olacak
- Setup tablosuna `PutAway Strategy Code` ve `Pick Strategy Code` alanları eklenir (Sprint 4 sonu)
- Default strategy DOPSWHS içinde yaşar; custom strategy'ler 3rd-party app'lerden gelir

## Bitiş Kriterleri (DoD)

- [ ] Posted Whse Receipt'ten oluşan Put-Away mobilde register edilebiliyor
- [ ] Suggested bin doğru kuralla geliyor (zone rank+bin rank+capacity)
- [ ] LP'den auto-fill çalışıyor (5 satırlı LP tek scan'de doluyor)
- [ ] Ad-Hoc move + Directed move mobilde uçtan uca
- [ ] Reclass batch isolation testi geçti (KB risk korunmuş)
- [ ] `DirectedPutAway` ve `MovementMgmt` coverage ≥ %75
- [ ] AppSourceCop warning=0
- [ ] `docs/release-notes/sprint-4.md` mevcut
