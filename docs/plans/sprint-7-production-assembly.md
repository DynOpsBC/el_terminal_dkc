# Sprint 7 — Production + Assembly (2 hafta)

## Hedef

Production Order Consumption + Output + Assembly Order akışlarını mobilden tamamla. LP entegrasyonu: scan LP → tüm içerik tek component için consume; output sırasında yeni LP otomatik oluşturulabilir (KB "Output to License Plate" pattern).

## Demo Kriterleri

1. Released Production Order seçilir → mobilde **Consume** açılır → BOM gösterilir.
2. Her component için: bin scan → LP scan → tüm LP içeriği tek seferde consume.
3. Posted Consumption → Item Journal'a Consumption entry yazılır → On-hand azalır.
4. **Output**: aynı prod order için → operation seçilir → output qty + scrap qty + runtime girilir → "New LP" toggle açık → output otomatik yeni LP'ye yerleşir (Built durumunda, output bin'inde).
5. Posted Output → Item Journal'a Output entry → On-hand artar.
6. **Assembly Order**: assemble-to-stock akışı → mobilde **Assembly** → components scan → assembly qty post → Item Journal entries doğru.

## AL İş Paketleri

### Page extensions

- `al/src/Production/ProdOrderExt.PageExt.al` (PageExt 72308) — Released Prod Order (5409 family) üzerine "Mobile Consume" + "Mobile Output" actions
- `al/src/Assembly/AssemblyHeaderExt.PageExt.al` (PageExt 72309) — Assembly Order (900) üzerine "Mobile Consume" action

### Production API'ler (2 API)

- `al/src/Production/ConsumptionApi.Page.al` (P 72222) — `/productionConsumption`
  - GET — `$filter=prodOrderNo,status`
  - POST `Microsoft.NAV.consume` — `{prodOrderNo, componentLineNo, itemNo, qty, lpNo?, lotNo?, serialNo?, binCode?}`
- `al/src/Production/OutputApi.Page.al` (P 72223) — `/productionOutput`
  - GET — `$filter=prodOrderNo`
  - POST `Microsoft.NAV.report` — `{prodOrderNo, routingLineNo, outputQty, scrapQty, runtime, newLpTemplate?, binCode?}`

### Prod Mgmt codeunit

- `al/src/Production/ProdMgmt.Codeunit.al` (CU 72048)
  - `Consume(ProdOrderComponent; ItemNo; Qty; LP?; Lot?; Serial?)` — Item Journal Type=Consumption line yarat + post
  - `ReportOutput(ProdOrderRoutingLine; OutputQty; ScrapQty; Runtime; NewLpTemplate?)` — Item Journal Type=Output line yarat + post; NewLpTemplate verilmişse `LPManagement.Build` çağır
  - LP auto-match by item: scan edilen LP'nin Item No'su component'le eşleşiyorsa tüm qty consume edilir

### Assembly API + Mgmt

- `al/src/Assembly/AssemblyApi.Page.al` (P 72224) — `/assemblies`
  - GET, POST `Microsoft.NAV.post`
- `al/src/Assembly/AssemblyMgmt.Codeunit.al` (CU 72049)
  - `PostAssembly(AssemblyHeader)` — wraps `Assembly-Post`
  - Assemble-to-Stock destekli (öncelik)
  - Assemble-to-Order için sadece consumption tracking (output BC source document üzerinden)

### Test

- `tests/src/Production/ConsumptionTests.Codeunit.al`
- `tests/src/Production/OutputTests.Codeunit.al`
- `tests/src/Production/OutputToLPTests.Codeunit.al` — KB pattern doğrulama
- `tests/src/Assembly/AssemblyToStockTests.Codeunit.al`
- `tests/src/Integration/ProdOrderFlowTests.Codeunit.al`

## Android İş Paketleri

### `:feature-consume`

- `feature/consume/ConsumptionLookupListScreen.kt` — released prod orders
- `feature/consume/ConsumptionBOMScreen.kt` — BOM lines + component-wise consume
- Menu (WI 15 parite): Close, Post, Enter Bin, Enter Item, Show Usage, Item Inquiry, Bin Inquiry
- `feature/consume/ConsumeViewModel.kt`

### `:feature-output`

- `feature/output/OutputLookupListScreen.kt`
- `feature/output/OutputScreen.kt` — operation selector, qty fields, "New LP" toggle, runtime
- `feature/output/OutputViewModel.kt`

### `:feature-assembly`

- `feature/assembly/AssemblyLookupListScreen.kt`
- `feature/assembly/AssemblyScreen.kt` — components + assembly qty
- `feature/assembly/AssemblyViewModel.kt`

### `:core-domain` usecase'leri

- `Consume.kt`, `ReportOutput.kt`, `PostAssembly.kt`
- `GetProdOrder.kt`, `GetAssembly.kt`

### `:core-sync` ops

- `Op.kt`: `Consume` (queue), `ReportOutput` (queue), `PostAssembly` (online-only)

### Test

- `feature/consume/test/ConsumeViewModelTest.kt` — LP auto-match
- `feature/output/test/OutputViewModelTest.kt` — new LP toggle

## Web İş Paketleri

(Bu sprint'te yeni web bileşeni yok; Production listeleri standart BC Role Center'da gözüküyor.)

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET | `/productionConsumption` |
| POST | `/productionConsumption/Microsoft.NAV.consume` |
| GET | `/productionOutput` |
| POST | `/productionOutput/Microsoft.NAV.report` |
| GET | `/assemblies` |
| POST | `/assemblies({no})/Microsoft.NAV.post` |

## Bağımlılıklar (önceki sprintlerden)

- LP Mgmt + LPManagement.Build (Sprint 2) — output→new LP için
- Item Journal altyapısı (standart BC)
- Prod Order standart BC (sandbox'ta released prod order seed)

## Bitiş Kriterleri (DoD)

- [ ] Consumption + Output mobilden post ediliyor
- [ ] Output→New LP pattern çalışıyor (KB doğrulaması)
- [ ] Assembly Order assemble-to-stock akışı çalışıyor
- [ ] LP auto-match by item (consumption) çalışıyor
- [ ] `ProdMgmt` + `AssemblyMgmt` coverage ≥ %75
- [ ] AppSourceCop warning=0
- [ ] `docs/release-notes/sprint-7.md` mevcut
