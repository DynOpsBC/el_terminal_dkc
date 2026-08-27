# BCWMS — Posting Test Harness & Results

> Her mobil WMS aksiyonunun BC'de bir post/register karşılığı varsa, o posting **app'den tetiklenebilir**
> ve **otomatik test edilebilir**. Bu doküman harness'i, canlı sonuçları ve bulunan/düzeltilen gerçek
> hataları özetler.

## App'den posting tetikleme

Her post-yetenekli modül zaten bir post/register aksiyonu içeriyor (bound action → Mgmt codeunit →
standart BC posting codeunit'i):

| Mobil modül | API entity / bound action | BC posting codeunit'i |
|---|---|---|
| Mal Kabul | `receipts/post(print,invoice)` | `Whse.-Post Receipt` |
| Toplama | `picks/register` | `Whse.-Activity-Register` |
| Sevkiyat | `shipments/post(print,invoice)` | `Whse.-Post Shipment` / `Sales-Post` |
| Put-Away | `putAways/register` | `Whse.-Activity-Register` |
| Ad-Hoc Hareket | `movements/adHoc` | `Item Jnl.-Post Batch` (reclass) |
| Yönlendirilmiş | `movements/register` | `Whse.-Activity-Register` |
| Sayım | `countSheets/postSheet` | `Item Jnl.-Post Batch` (phys. inv.) |
| Üretim | `productionConsumption/consume`, `productionOutput/report` | `Item Jnl.-Post` |
| Montaj | `assemblies/post` | `Assembly-Post` |
| License Plate | `licensePlates/stop` | SSCC finalize |

## Posting Smoke Test (otomatik harness)

- **CU 72252 `DOPSWHS Posting Smoke Test`** — her domain için minimum BC verisi oluşturup **aynı Mgmt
  codeunit'ini** (API bound action ile birebir) çağırır, post sonucunu doğrular, PASS/FAIL kaydeder.
- **Tablo 72251 `DOPSWHS Posting Test Result`** — kalıcı per-domain sonuç.
- **Page 72253 `DOPSWHS Posting Test API`** (`postingTests`) — `runAll()` bound action; app'teki
  **📮 Posting Test** ekranından tek tıkla tetiklenir.
- Her domain bir `[TryFunction]` içinde izole → bir domain'in hatası diğerlerini bloke etmez.

Çağrı (app'in yaptığıyla aynı yol):

```
POST .../api/dynops/warehouse/v2.0/companies({id})/postingTests('1-MOVE')/Microsoft.NAV.runAll
```

## Canlı Sonuçlar (CustomerSandbox, v1.0.9.0)

| Domain | Sonuç | Kanıt / Açıklama |
|---|---|---|
| **Inventory Count** | ✅ PASS | Phys. inv. post — `CNT-20260528072926` |
| **Warehouse Receipt** | ✅ PASS | PO → whse receipt → post — `107225` (WHITE) |
| **Put-Away register** | ✅ PASS | Receipt sonrası auto put-away register — `PU000009` (WHITE) |
| Ad-Hoc Move | ⚠️ Env | Default lokasyon SILVER **directed** → item-reclass bin içeriği oluşturmuyor. AdHocMove non-directed bin lokasyonu gerektirir; directed lokasyonda **Yönlendirilmiş Hareket** (whse movement) kullanılır. |
| Warehouse Shipment | ⚠️ Env | Whse shipment oluşturuluyor; **directed pick oluşturma için BC24'te extension API yok**. Pick mobil Pick modülünden register edilip sonra Post Shipment yapılır. |
| Pick register | ⚠️ Env | Mevcut pick gerektirir (yukarıdaki ile aynı kısıt). RegisterPick → `Whse.-Activity-Register` koşmaya hazır. |
| Production Consume/Output | ⚠️ Env | Bu sandbox'ta **BOM + routing olan üretim mastara verisi yok**. Consume/ReportOutput codeunit'leri gerçek (`Item Jnl.-Post`). |
| Assembly post | ⚠️ Env | Cronus assembly bileşeni (`1968-S`) availability kısıtı. PostAssembly → `Assembly-Post` gerçek. |

> **3/9 domain canlı doğrulandı.** Kalan 6 **sandbox ortam/veri kısıtı** (uygulama posting mantığı değil):
> directed default lokasyon, BC24 directed-pick API yokluğu, üretim master verisi yokluğu.

## Bu test sırasında bulunan + düzeltilen GERÇEK üretim hataları

1. **Ad-Hoc Move confirm dialog** — `MovementMgmt.AdHocMove` `Item Jnl.-Post` (CU 241) kullanıyordu; bu
   "Do you want to post?" Confirm'i API/handheld'de **client-callback hatası** veriyordu. → `Item
   Jnl.-Post Batch` (CU 23) ile değiştirildi (dialogsuz). *Bu, mobil Ad-Hoc Move'u da kırıyordu.*
2. **Sayım hiç post edilemiyordu** — `CountMgmt.PostSheet` phys. inv. journal satırına `Phys.
   Inventory = true` ve `Document No.` yazmıyordu → post hata veriyordu. Ayrıca **count satırı hiç
   oluşturulmuyordu** (line creation yoktu). → `Phys. Inventory`/`Qty.(Calculated)`/`Document No.`
   eklendi; `GenerateLines` + `AddLine` (bin content snapshot) eklendi; `System Qty` FlowField →
   **stored snapshot** (API listelemesini de düzeltti, bkz. count line API 404 değil artık).

## Mobil (v1.5.0)

- **Sayım** ekranına **➕ Satır Üret** (generateLines) eklendi → sheet artık sayılabilir + post edilebilir.
- **📮 Posting Test** ekranı eklendi → app'ten `runAll` tetikler, per-domain PASS/FAIL + posted belge no
  gösterir. Emulator'da 🟢 Bağlı ile canlı çalıştırıldı: **Geçen 3/9**, Count/Receipt/Put-Away ✅.

## Sonraki adımlar (kalan 6 domain için, istenirse)

- **Üretim**: minimal BOM + routing + work center master verisi seed et → Consume/Output testi.
- **Sevkiyat/Pick**: ya non-directed (require-shipment) test lokasyonu kur, ya da pick'i mobil Pick
  modülünden register edip Post Shipment'i doğrula.
- **Ad-Hoc Move**: default lokasyonu non-directed bir bin lokasyonu yap, ya da directed'da Yönlendirilmiş
  Hareket akışını test et.
- **Montaj**: bileşen stoğunu doğru tüketim lokasyonunda garanti et.
