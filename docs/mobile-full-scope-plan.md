# BCWMSApp Mobile — Tam Warehouse Insight Parite Kapsamı

> **Referans:** DMSi Warehouse Insight 2.3 mobil handheld app + AdvWMS Technical Spec §7 (Android Handheld) + §10 (Module-by-Module)
> **Hedef:** BC SaaS ile full entegre, aksiyon-yetenekli (sadece read-only değil) handheld WMS app
> **Mevcut:** v1.2.0 — Home menü + 7 read-mostly ekran (LP list, Item/Bin inquiry, Receiving/Picking list, Test Center, Connection)
> **Bu plan:** Aksiyon-yetenekli iş akışları + barkod tarama + tüm WI modülleri

---

## Mevcut vs. Hedef Karşılaştırma

| Modül | Mevcut (v1.2.0) | Hedef (WI parite) |
|---|---|---|
| License Plate | List + Yeni LP | Build/Stop/AddLine/Transfer/Nest/Unbuild/Print + partial-use |
| Receiving | Belge listesi (read) | Doc detail → scan → qty dialog → LP-during-receive → **Post** |
| Picking | Belge listesi (read) | Doc detail → take/place → pick-to-LP → short pick → **Register** |
| Shipping | — | List → doc → **Post** + packing slip |
| Put-Away | — | List → doc → suggest bin → **Register** |
| Movement | — | Ad-hoc bin-to-bin + directed |
| Count | — | Basic + Advanced (blind) → **Post** |
| Production | — | Consumption + Output (→ new LP) |
| Assembly | — | Order → **Post** |
| Item Inquiry | Arama (raw) | Item card + stock-by-bin + LP |
| Bin Inquiry | Arama (raw) | Bin contents + LP listesi |
| Scanner | — | Kamera (ML Kit) + DataWedge + keyboard wedge |

---

## Modül Detayları (WI 2.3 § referanslı)

### 1. Receiving (WI §10.1 canonical)

**Ekranlar:** ReceiveLookupList → ReceiveDocument → QuantityDialogSheet

- **Lookup:** Açık Whse Receipt / PO / Transfer In listesi, filtre (doc no, vendor, due date), % complete bar
- **Document:** Header card + satır listesi (item, qty remaining, qty received input), bottom action bar
- **Aksiyonlar:** Scan item (mode: bin/item/LP) · Change qty · Start LP · Stop LP (label print) · **Post Receipt**
- **BC API:** `GET /receipts`, `PATCH /receipts({no})/lines`, `POST .../Microsoft.NAV.startLP`, `stopLP`, `post`
- **LP-during-receive:** Start LP → her scan LP'ye eklenir → Stop LP → SSCC + label

### 2. Put-Away (WI §10.2)

**Ekranlar:** PutAwayLookupList → PutAwayDocument

- Suggested bin (zone rank), LP scan → auto-fill, split, **Register**
- **BC API:** `GET /putaways`, `PATCH lines`, `POST .../suggestBin`, `register`

### 3. Picking (WI §10.3)

**Ekranlar:** PickLookupList → PickDocument → ShortPickDialog

- Assigned-to-me default + Show All · Take/Place switch · Start Shipping LP → take lines → Stop LP (SSCC) · Short pick (reason) · **Register**
- **BC API:** `GET /picks`, `POST .../assignToMe`, `startShippingLP`, `stopShippingLP`, `markShort`, `register`, `PATCH lines`

### 4. Shipping (WI §10.4)

**Ekranlar:** ShipLookupList → ShipDocument

- Released filtreli · Whse/Sales/Transfer varyant · **Post** (+packing slip) · Ship & Invoice (sales)
- **BC API:** `GET /shipments`, `POST .../post`

### 5. Movement (WI §10.5)

**Ekranlar:** AdHocMove (tek ekran) + DirectedMove (list+doc)

- Ad-hoc: scan from-bin → item/LP → to-bin → qty → confirm (Item Reclass Journal)
- Directed: Whse Movement doc → Register
- **BC API:** `POST /movements/Microsoft.NAV.adhoc`, `register`

### 6. Inventory Count (WI §10.6)

**Ekranlar:** CountSheetLookupList → CountSheetDocument → BlindCount

- Basic: Phys Inv batch → scan → post
- Advanced: count sheet → multi-counter → blind → recount → **Post**
- **BC API:** `GET /countSheets`, `POST`, `PATCH lines`, `startRecount`, `post`

### 7. License Plate Mgmt (WI §10.10 standalone)

**Ekranlar:** LpLookupList → LpDocument → LpUsePartialSheet → LpTransfer → LpProperties

- Build · Stop · AddLine/RemoveLine · Transfer · Nest/Unnest · Unbuild · Print · Partial-use (4 mod)
- **BC API:** `POST /licensePlates`, `.../stop`, `assign`, `transfer`, `usePartial`, `nest`, `unnest`, `unbuild`, `printLabel`, `PATCH/POST lines`

### 8. Production (WI §10.7-10.8)

**Ekranlar:** ConsumptionLookupList → ConsumptionBOM, OutputLookupList → Output

- Consume (component scan, LP auto-match), Output (qty/scrap/runtime, → new LP)
- **BC API:** `POST /productionConsumption/Microsoft.NAV.consume`, `/productionOutput/Microsoft.NAV.report`

### 9. Assembly (WI §10.9)

**Ekranlar:** AssemblyLookupList → Assembly

- Components + assembly qty → **Post**
- **BC API:** `GET /assemblies`, `POST .../post`

### 10. Item & Bin Inquiry (WI §10.11)

- Item Inquiry: card + on-hand by bin + recent transactions + LP listesi
- Bin Inquiry: contents (items + LPs) + recent whse entries

### 11. Scanner (spec §7.3)

- Kamera barkod (CameraX + ML Kit) — her doc ekranında scan input
- DataWedge intent receiver (Zebra), keyboard wedge fallback
- BarcodeIntentResolver: scan → {Item, Bin, LP, LpTemplate, Lot, Serial} sınıflandırma → aktif ekran intent'i kabul/red

---

## Teknik Yaklaşım

### Mimari (mevcut app modülü genişletilir)

- `BcApi.kt` — bound action POST helper'ları eklenir (Microsoft.NAV.* çağrıları)
- `AppRoot.kt` — navigation genişler (her modül için lookup→doc→dialog)
- `scanner/` — CameraScanner (ML Kit) + DataWedge + intent resolver
- Quantity dialog (ModalBottomSheet) — qty stepper + UoM + lot/serial + "+1"
- Document screen pattern — header + lines + bottom action bar

### BC bound action çağrısı (BcApi)

```kotlin
suspend fun boundAction(context, entitySet, key, action, body): ApiResult
// POST .../{entitySet}({key})/Microsoft.NAV.{action}
```

### Barkod tarama

- CameraX preview + ML Kit BarcodeScanning
- Scan sonucu → BarcodeIntentResolver → ekran intent kabul ederse field doldur
- DataWedge: BroadcastReceiver `com.dynops.bcwms.SCAN`

### Offline (faz 2 — opsiyonel)

- Room queue + WorkManager replay (spec §7.4) — Post hariç tüm mutations

---

## Deploy Stratejisi (3 faz)

### ✅ Faz 1 — Aksiyon-yetenekli çekirdek (v1.3.0, TAMAMLANDI)

Receiving (post), Picking (register + pick-to-LP), LP (build/stop/transfer/unbuild), Count (post), Ad-hoc Move, Item/Bin inquiry detail kartları. Kamera barkod tarama entegre.

### ✅ Faz 2 — Tam modül seti (v1.4.0, TAMAMLANDI)

Put-Away (suggest bin → Register), Shipping (qty/LP → Post + packing slip), Production (Sarfiyat + Output → yeni LP, sekmeli), Assembly (bileşenler → Post), Directed Move (movements → Register), Advanced/blind Count (sayıcı slot 1-3 + recount + post).

**Önkoşul kök-neden düzeltmesi (v1.0.8.0):** `movements`/`countSheets`/`putAways`/`shipments` entity set'leri yanlış `APIGroup`/`APIVersion` (wms/v1.0, advWms, warehouseOps) ile yayınlanmıştı → mobil app'in sorguladığı `dynops/warehouse/v2.0` route'unda 404 dönüyordu. 7 API sayfası `warehouse`/`v2.0`'a normalize edildi, republish edildi, 8/8 entity set HTTP 200 doğrulandı.

**Canlı doğrulama (emulator BCWMSEmu, BC SaaS CustomerSandbox):**

- 🟢 Bağlı, tüm tile'lar görünür (Put-Away, Sevkiyat, Üretim, Montaj, Yönlendirilmiş dahil)
- Put-Away → live `putAways` HTTP 200; Üretim → sekmeli, live `productionConsumption` HTTP 200
- Sayım → 7 canlı count sheet (HTTP 200), drill → BLIND badge + lines fetch + Recount/Post action bar

### Faz 3 — Hardening (sonraki)

Offline queue, DataWedge/Honeywell SDK, MSAL OAuth (token-paste yerine), Play Store signing.

---

## Doğrulama (her modül için)

1. APK build (JDK 21 + Gradle 8.13)
2. Emulator install + token inject (run-as SharedPreferences)
3. Modül ekranına git → BC bound action tetikle → HTTP 200/201 + BC'de sonuç doğrula
4. Screenshot kanıt

### Önkoşul demo verisi (sandbox'ta hazır)

- 50 LP, 50 test case, Demo Data Setup + E2E Test Data çalıştırılmış
- Cronus released PO/SO (receiving/picking için)
- BLUE/SILVER bins
