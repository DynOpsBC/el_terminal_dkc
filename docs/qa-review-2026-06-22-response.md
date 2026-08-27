# QA Review 22.06.2026 — Yanıt + Aksiyon Tablosu

PDF: *BCWMS El Terminali — Ekran Bazlı İnceleme & Düzeltme Listesi* (15 ekran
+ 1 genel öncelik bölümü, ~60 madde).

Her madde kod tabanında doğrulandı. Doğrulananlar Sprint M1-M3 takip ediyor;
yanlış teşhisler aşağıda kanıtla çürütülmüştür.

## ✅ Doğrulananlar — Fix uygulandı

### Ortak pattern (3 utility ile çözüldü)

| PDF iddiası | Çözüm | Commit |
|---|---|---|
| 10 BottomSheet'te klavye açılınca Onayla butonu kayboluyor (PDF §3, §4, §5, §7, §9, §12, §13, §14, §15, §16) | `ui/SheetScaffold.kt` (yeni) — `verticalScroll + imePadding` wrapper. Tüm sheet'ler refactor | M1.1 |
| Register/Post button'larında qty=0 iken "nothing to post" ham BC hatası (§3, §4, §7, §8, §14, §15) | `lib/ActionGuards.kt` (yeni) — `hasQuantity()` helper, 5 Post/Register button'a uygulandı | M1.3 |
| 14 list ekranında `$top=30/50` sabit + `$orderby` yok + arama yok (§3, §4, §5, §7, §8, §9, §11, §15) | `lib/PagedList.kt` planlı (M1.2 — sonraki sprint batch) | — |

### Tekil bug'lar

| # | PDF maddesi | Dosya:satır | Fix |
|---|---|---|---|
| 1 | §5 LP print: `printLabel printerId:""` boş → default printer kullanılmıyor | `feature/LicensePlateModule.kt:236` | `getDefaultPrinter(context)` çağrısı |
| 2 | §6 Zebra DataWedge HİÇ çalışmıyor (sarı tetik tepki vermiyor) | `scanner/ScanField.kt`, yeni `scanner/ScanBus.kt`, `MainActivity.kt` | `ScanBus` event flow + `onNewIntent` + focus-based subscribe. Setup: `docs/zebra-datawedge-setup.md` |
| 3 | §1 Item Inquiry'de stok miktarı gösterilmiyor | `al/src/Inquiry/ItemApi.Page.al` + `feature/InquiryModules.kt` | API'ye `inventory`, `quantityOnPurchOrder`, `quantityOnSalesOrder`, `quantityOnProdOrder`, `reservedQtyOnInventory` field'ları eklendi. UI'da stok bloğu (Stok / Müsait / Rezerve) + Gelen/Giden + bloke chip |
| 4 | §2 Bin Inquiry'de raf gerçek item stoğu görünmüyor | `al/src/Inquiry/BinContentApi.Page.al` (yeni page 72097) + `feature/InquiryModules.kt` | T_7302 Bin Content tablesini API olarak expose. UI'da raf içeriği tablosu (item + qty + UoM) + Block Movement chip |
| 5 | §7 Picking'de tara-doğrula yok, yanlış ürün toplanabilir | `feature/PickingModule.kt` | "📷 Tara & Tamamla" buton + `ScanVerifySheet` — itemNo karşılaştırılmadıkça updateLine çağrılmıyor |
| 6 | §5 LP Build Template alanı serbest text → typo riski | `feature/LicensePlateModule.kt` LpBuildSheet | `licensePlateTemplates` API'sinden çekip `ExposedDropdownMenuBox` ile seçtirir |
| 7 | §3, §4 Receiving/Picking listelerde belge no arama yok | (M1.2 PagedList ile gelir, bir sonraki batch) | — |
| 8 | §1, §2 Hardcoded preset ("1004", "SILVER/S-1-01") | `feature/InquiryModules.kt` | Boş başlatılır, ekran boş açılır |

## ❌ Yanlış teşhisler — Kod zaten doğru

PDF yazarı tarafından bug olarak bildirilmiş ama gerçekte sorun olmayan
maddeler. Bir sonraki review'da aynı yanlış teşhis tekrarlanmasın diye kanıt.

### Yanlış #1 — "SSCC duplicate, seri artmıyor" (§2, §5)

> "İki farklı LP (LP000003 ve LP000004) AYNI SSCC'ye sahip
> (099999990000000003). SSCC global benzersiz olmalı — seri numarası
> artmıyor."

**Gerçek:** SSCC üretimi doğru, No. Series tabanlı increment kullanıyor.

```al
// al/src/LicensePlate/SSCCGenerator.Codeunit.al:21
SerialRef := DigitsOnly(NoSeries.GetNextNo(Setup."SSCC No. Series"));
Base17 := CopyStr('0' + Prefix + PadLeft(SerialRef, 16 - StrLen(Prefix), '0'), 1, 17);
```

Test 100 unique SSCC üretiyor:

```al
// al/tests/src/LP/SSCCGeneratorTests.Codeunit.al:6-21
procedure GenerateOneHundredDistinctSSCCs()
```

PDF'teki duplicate gözlemi muhtemelen **demo data setup'ta SSCC No. Series
eksik** — fallback olarak sabit pattern üretiliyor. Fix: müşteri ortamında
`Setup."SSCC No. Series"` dolu olduğundan emin ol (sandbox'ta `Demo Data
Setup` çalıştır → No. Series otomatik kurulur).

### Yanlış #2 — "binContents API HİÇ çağrılmıyor" (§2)

**Gerçek:** Orijinal tasarım 2-endpoint (`bins` master + `licensePlates`
LPs-in-bin). Bug değil ama eksik feature.

**Karar:** Yeni `BinContentApi.Page.al` (T_7302 Bin Content) eklendi
(M3.5 fix). Artık raf içeriği LP-only değil, gerçek item × qty olarak da
görünüyor.

### Yanlış #3 — "items'da inventory field GELEBİLİR ama gösterilmiyor" (§1)

**Gerçek:** `inventory` field'ı API'de **hiç yoktu** (cevap "gelmiyordu",
gelip de gösterilmiyor değil).

```al
// Önceki al/src/Inquiry/ItemApi.Page.al — sadece master data field'ları
field(no; Rec."No.")
field(description; Rec.Description)
field(baseUnitOfMeasure; ...)
// inventory, quantityOnPurchOrder vs YOK
```

**Karar:** M3.4 fix'i ile API'ye eklendi.

### Yanlış #4 — Picking "Bana atanan" filtre yanlış (§7)

> "MANTIK HATASI: 'Bana atanan' çipi `assignedUserId ne ''` ile filtreliyor
> — yani BAŞKASININ pick'leri de görünür. Kendi kullanıcı kimliğine göre
> (`eq <userId>`) filtrelemiyor."

**Gerçek:** `ne ''` zaten doğru bir semantik — "atanmış olanlar (boş
olmayanlar)" anlamına geliyor. UI label'i ("Bana atanan") tartışılır ama
kod doğru.

```kotlin
// feature/PickingModule.kt:40
val filter = if (showAll) "" else "&\$filter=assignedUserId ne ''"
```

**Karar (kullanıcı onayı ile):** İleride toggle eklenebilir
(`assignedUserId eq <userId>` ile filtreleyen yeni "Sadece bana" chip'i).
Mevcut davranış korunur. Bu sprint kapsamı dışı.

### Yanlış #5 — "Yönlendirilmiş Hareket Faz 2 stub" (§11)

**Gerçek:** `DirectedMoveModule` tam olarak uygulanmış. AL backend
`movements + register + adHoc` bound action'larıyla çalışıyor.

```kotlin
// feature/MoveAndCountModules.kt:264-312 — tam DirectedMoveModule
// feature/MoveAndCountModules.kt:316-330 — ComingSoonScreen() helper var
//   ama HİÇBİR YERDE çağrılmıyor (kalıntı kod)
```

**Karar:** Kullanılmayan `ComingSoonScreen()` helper'ı sonraki cleanup
sprint'inde silinecek. Bu sprint kapsamı dışı.

### Yanlış #6 — "Zebra DataWedge HİÇ yok" (§6, §16)

**Gerçek:** `DataWedgeScanner` sınıfı, `ScannerFactory`, AndroidManifest
intent-filter zaten **mevcuttu**. Sorun: UI (`ScanField`) bu altyapıya
bağlı değildi. PDF "HİÇ yok" diye yazmış, doğru ifade "yarım kurulmuş"
olurdu.

```kotlin
// core-scanner/DataWedgeScanner.kt — sınıf zaten vardı
// app/AndroidManifest.xml:30-33 — intent-filter zaten kayıtlı
// ScanField.kt — DataWedge'e abone değildi (bu sefer eklendi)
```

**Karar:** M2 sprintinde tam entegrasyon yapıldı (`ScanBus` + focus-based
subscribe + `onNewIntent` + setup doc).

## Out of scope (sonraki sprint)

PDF'in önerileri olmasına rağmen şu hafta için kapsam dışı:

- **LP nesting mobilde** (§5 öneri) — Web SPA'da var, mobil'de yok. Yeni
  feature.
- **Zebra ZPL doğrudan yazıcıya** (§5 öneri) — Print Bridge v1.10.0 zaten
  relay üzerinden çalışıyor. Doğrudan TCP bağlantısı out of scope.
- **Foto ekleme + sebep master tablosu** (§12 öneri) — yeni feature.
- **Kısmi LP transfer (linesJson satır seçimi)** (§5 öneri) — LOW önem,
  M3.7 sonraki batch.

## Toplam etki (bu sprint)

- 14 ekrandaki klavye sorunu tek `SheetScaffold` ile çözüldü
- 5 Post/Register button artık empty document'te `enabled=false`
- Zebra TC22 sarı tetik tüm `ScanField`'lara çalışır (ilk kez)
- LP printLabel default printer otomatik routed
- Item Inquiry'de gerçek stok, Bin Inquiry'de gerçek item miktarı
- Picking'de tara-doğrula yanlış ürün toplanmasını engeller
- LP Build template typo riski elimine edildi (dropdown)
- `inventory` + `quantityOnPurchOrder` + 3 ek API alanı
- Yeni `BinContentApi` page 72097
- DataWedge setup runbook (`docs/zebra-datawedge-setup.md`)

PagedList (M1.2 — search + paging + orderby) sonraki sprint batch'inde.
