# ELOG Gereksinimleri — Geliştirme Notları (8 Temmuz 2026)

ELOG Lojistik saha ziyaretinden (7 Temmuz) çıkan 5 gereksinimin tamamı kodlandı.
Android derlemesi ve web typecheck macOS'ta doğrulandı; **AL uzantısı Windows'ta
derlenip sandbox'a publish edilmeli** (macOS'ta AL derlenemiyor).

## 1. Satır birleştirme (bin + ürün) — TAMAM (Android)
- `android/.../ui/GroupedLines.kt` (yeni): `LineGroupCards` ortak bileşeni + `pickLineCapacity`.
- `PickingModule.kt` ve `PutAwayShipModules.kt (WhsePickDocument)`: "🔗 Birleştir" çipi.
  Aynı bin+item satırları tek kartta, toplam "Kalan" ile; karta dokun → miktar gir →
  `distributeQty` alt satırlara dağıtır (PATCH `qtyToHandle`). Birleştirme açıkken
  ürün okutmak grubun miktar dialogunu açar (tek okutmada toplam giriş).

## 2. Sepet–sipariş eşleştirme — TAMAM (AL + Android)
- Tablo 72330 `DOPSWHS Pick Tote Assignment` (Pick No. + Source Order No. → LP No., Packed).
- `PickMgmt`: `AssignTote` (başka pick'in kapatılmamış tote'u reddedilir; Built LP pick'e
  Assigned olur), `GetToteForOrder`.
- `PickApi`: bound action `assignTote(sourceOrderNo, lpNo)` + `toteForOrder(sourceOrderNo)`.
- `PickLineApi`: `sourceNo` alanı eklendi.
- Terminal: Toplama ekranında "🧺" çipi (sepet modu). Ürün okutunca sistem satırın
  siparişine atanmış sepeti önerir ("→ Sepet T-06-K2"); sepet okutularak doğrulanır,
  yanlış sepette hata; sipariş sepetsizse okutulan sepet bağlanır, sonra satır tamamlanır.

## 3. Paketleme istasyonu — TAMAM (AL + Android)
- Enum 72331 `Pack Status`; tablolar 72332 `Pack Session`, 72333 `Pack Session Line`.
- Codeunit 72334 `DOPSWHS Pack Station Mgmt` — tek motor, **3 mod** (enum 72343
  `Pack Mode`: Solo/Bulk/Batch; oturumda saklanır). **Kutu SİPARİŞ başınadır**
  (Pack Session Line."Box LP No."); sipariş ancak hem tam paketlenmiş hem
  kutulanmışsa kapanır (`TryCompleteOrder`):
  - **Solo** (multi pick sepeti, 1 sepet = 1 sipariş): kutu → ürünler → fiş.
  - **Bulk** (2+2+2): sepet 1 kez; her pay için kutu → ürünler → payın fişi;
    sıradaki pay yeni kutu ister (`BoxNeededOrder` yönlendirir).
  - **Batch** (mono-SKU): ürün → kutu döngüsü — **kutu okuması siparişi kapatır
    ve fişini bastırır** (ELOG: "ürün okuttum, kutumu okuttum, fatura kesti").
  - `StartSession(toteLpNo, mode)`: beklenen satırlar (whse shipment
    `Qty. Picked − Qty. Shipped`; basit lokasyonda sales outstanding).
  - `SetBoxForOrder(sessionId, orderNo, boxLpNo, template)` (+ `SetBox` sarmalayıcı,
    boş barkodda CARTON-S üretir); `ScanItem`: **beklenmeyen ürün → hata (rollback)**.
  - Sepet bitince reusable tote Release edilir (yeniden kullanım).
- API: 72335 `packOps('')` (startSession(mode)/setBox/setBoxForOrder/scanItem/cancelSession),
  72336 `packSessions` (+mode), 72337 `packSessionLines` (+boxLpNo).
- Terminal: `PackingModule.kt` — girişte **3 mod sekmesi (🧍 Solo / 📚 Bulk / 1️⃣ Batch)**,
  mod açıklamalarıyla. Kutu bekleyen sipariş varsa ekran "Sipariş X için kutu okutun"
  kartına döner (bulk: her payda yeni kutu; batch: kutu okuması fişi bastırır);
  satır kartlarında sipariş + kutu + faturalandı bilgisi. Donanım tarayıcı adım
  bazlı yönlendirilir (sepet → kutu|ürün).

## 4. Paket anında fiş/fatura basımı — TAMAM (AL)
- Sevkiyatlı sipariş: yalnız tamamlanan siparişin satırlarına `Qty. to Ship` yazılıp
  `Whse.-Post Shipment` **SetPostingSettings(true)** ile (fatura dahil) post edilir;
  diğer siparişlerin satırları sıfırlanır (kendi tamamlanmalarında post edilirler).
- Basit lokasyon: paketlenen miktarlar sales satırlarına yazılır → `PostSalesOrderShipAndInvoice`.
- Fiş: `IWX Report Usage` yeni değer **PackReceipt (10)** → `IWX Report Selection`'da
  seçili rapor; seçim yoksa **Standard Sales - Invoice (1306)**. Filtreli kayıt
  `PrintDispatcher.PrintReport` ile PDF üretilerek istasyonun belge yazıcısına kuyruklanır.

## 5. Multi-order pick — TAMAM (AL + Ops Console + terminal)
- Codeunit 72338 `DOPSWHS Multi Order Pick`: CSV sipariş listesi → hepsi tek
  Warehouse Shipment'a (report 5753 deseni: `FromSalesLine2ShptLine`), release,
  report 7318 ile **"Shelf or Bin" sıralı tek pick** + `Initialize(AssignedID …)`
  ile kullanıcıya atama (başlıkta ayrıca garanti edilir).
- Ops Console: yeni **"Siparişler" sekmesi** (checkbox seçim + kullanıcı + "Pick
  Oluştur & Ata"); `BoardData.BuildOrdersJson` (sevkiyata bağlanmamış, kalanı olan
  siparişler) + `CreateMultiPick`; controladdin'e `CreateMultiPick` event +
  `NotifyResult` prosedürü eklendi (React sonucu yeşil bildirimde gösterir).
- Terminal raf modu: pick ekranında **raf (bin) barkodu okutulunca liste o rafın
  satırlarına filtrelenir** ("📍 Raf X" çipi) — ELOG'daki raf-yönlendirmeli yürüyüş.

## 7. Uçtan uca ELOG akışı denetimi + eksik parçalar — TAMAM (9 Temmuz öğleden sonra)
Kullanıcının tarif ettiği akışın denetim sonucu:
- ✅ VAR: pick listesi (Bana atanan/Tümü), belge içi "Bana Ata", raf (bin)
  okutunca satır filtreleme, ürün okut → sepet önerisi (toteMode/toteForOrder),
  Register Pick, paketleme istasyonu (sepet→kırmızı satırlar→kutu→ürün→fatura),
  BC Local User altyapısı (tablo+verify+ekranlar).
- ➕ EKLENDİ (bu tur):
  1. **Zorunlu WMS operatör girişi** (paylaşımlı BC lisansı): LoginFlow'da
     ortam/şirket bağlantısı artık `onConnected` yerine **Step.LocalUser**'a
     geçer — oturum ancak WMS kullanıcı adı+şifre doğrulanınca açılır. Token
     varsa ekran doğrudan WMS girişinden başlar (vardiya değişimi = Bağlı
     rozetine dokun → kullanıcı gir). "Yönetici: WMS girişini atla" kaçış yolu
     kurulum içindir. BC tarafındaki ekran zaten vardı: **Local User List/Card
     (72285/72286)** = "WMS Users".
  2. **Pick modu**: enum 72349 `DOPSWHS Pick Mode` (boş/Multi/Bulk/Batch) +
     tableext 72429 `Warehouse Activity Header`."DOPSWHS Pick Mode" (field
     72400) + pickApi `pickMode` alanı + `MultiOrderPick.CreateGroupedPick`
     mode parametresi (overload; BoardData 'multi' damgalar; StampPickMode).
  3. **Terminal pick listesi**: 🧍Multi/📚Bulk/1️⃣Batch mod sekmeleri +
     ⏳ Bekleyen (assignedUserId boş) filtresi + atanmamış kartlarda
     **"✋ Üzerime Al"** — atama `reassign(userId=localUser)` ile OTURUMDAKİ
     WMS kullanıcısına yazılır (BC servis hesabına değil); belge içi "Bana
     Ata" da aynı mantığa geçirildi. Eski publish'e karşı **HTTP 400 →
     pickMode'suz sorguya düşen fallback** var (emülatörde doğrulandı:
     PASS HTTP 200).
- Kalan ince nokta: BC "otomatik gruplama + onay" — şu an gruplamayı Ops
  Console'da kullanıcı yapıyor (CreateGroupedPick). Otomatik öneri + onay
  kuyruğu istenirse ayrı iş.

## 9. Yönlendirilmiş lokasyonda Ad-Hoc: Warehouse Reclass Journal (17 Temmuz)
Saha bulgusu: WHITE (Directed Put-away and Pick) lokasyonunda Ad-Hoc hareket
Item Reclass ile postalanınca warehouse entry'ler ADJUSTMENT zone / W-99-0001
üzerinden geçiyor ve **raf seviyesinde taşıma OLMUYOR** (BC tasarımı: item
journal directed lokasyonda bin taşıyamaz).
Düzeltme (MovementMgmt.AdHocMove): lokasyon `Directed Put-away and Pick` ise
otomatik dallanma → **Warehouse Reclass Journal (Entry Type=Movement)** satırı
(template RECLASS/Reclassification, batch DOPS-MOBIL — whse batch anahtarı
lokasyon içerir) + `Whse. Jnl.-Register Batch` ile confirm'siz register.
Bin'den bin'e gerçek taşıma, ILE'ye dokunmaz; lot satır alanlarında
("Lot No." + "New Lot No.") taşınır — tracking spec gerekmez. Basit
lokasyonlar eski Item Reclass yolunda kaldı. Terminal değişikliği yok.
**Windows publish doğrulama flag'leri:** `Whse. Jnl.-Register Batch` codeunit
adı/TableNo, Warehouse Journal Line'da "New Lot No." alanı, template
Type::Reclassification'da Movement entry type'ın kabulü.

## 8e. Lot reclass 3. saha hatası + NİHAİ düzeltme (17 Temmuz, AL-only)
Yeni publish sonrası hata tersine döndü: **"New Lot No. must be equal to '' ...
Current value is 'TEST#*'"** → codeunit 22, tracking specification (reservation
entry) VARKEN satırın kendi lot alanlarının BOŞ olmasını şart koşuyor — 8d'de
eklediğim satır-alanı doldurma çakışma yarattı. Nihai model:
- Journal satırının "Lot No."/"New Lot No." alanlarına DOKUNULMAZ.
- Lot yalnızca AddLotTracking'in reservation kaydında taşınır; kaydın boş kalan
  "New Lot No."su oluşturma sonrası doğrudan doldurulur (8d'nin 2. katmanı).
Yeniden publish gerekiyor. Test ederken GERÇEK lot kullanılmalı: 'TEST#*'
stokta yoksa sıradaki hata "lot yetersiz/yok" olur (kaynak binde o lottan
yeterli miktar olmalı).

## 8d. Lot reclass 2. saha hatası + düzeltme (16 Temmuz öğleden sonra, AL-only)
Publish sonrası adHocLot çalıştı ama post şu hatayla düştü: **"New Lot No.
must have a value in Item Journal Line ... Line No.=20000"** — codeunit 22,
reclass'ta hedef lotu hem satırda hem tracking'de arıyor; `Create Reserv.
Entry` ise ForReservEntry'deki "New Lot No."yu Prospect kaydına TAŞIMIYOR.
Düzeltme (MovementMgmt): (1) journal satırının kendi alanları dolduruluyor
(`ItemJournalLine."Lot No." / "New Lot No." := LotNo`), (2) AddLotTracking
sonunda oluşan Reservation Entry kayıtları bulunup boş "New Lot No." alanları
doğrudan LotNo ile güncelleniyor. **Yalnız AL değişti — APK aynı (1.10.15);
Windows'tan yeniden publish yeterli.**

## 8c. Saha testi geri bildirimleri (16 Temmuz öğlen) — APK v1.10.15
Gerçek cihaz testinden 3 düzeltme:
1. **Ad-Hoc LP modunda elle yazılan LP yüklenmiyordu** (loadLp yalnız
   tarama olayında tetikleniyordu) → LP alanının altına **"📥 LP İçeriğini
   Getir"** butonu; hedef doğrulama da belirgin butona çevrildi.
2. **Lot izlemeli üründe reclass hatası** ("You must assign a lot number"):
   - AL: `MovementMgmt.AdHocMove` LotNo overload'ı + `AddLotTracking`
     (Create Reserv. Entry ile Prospect kayıt: "Lot No." + "New Lot No.");
     `movementOps` API'sine **yeni `adHocLot` action** (eski `adHoc` imzası
     bozulmadı — eski APK'lar kırılmaz). ⚠️ Windows'ta doğrulanacak:
     `CreateReservEntryFor(..., ForReservEntry)` ve `CreateEntry(...,
     Enum::"Reservation Status"::Prospect)` imzaları (bellekten yazıldı).
   - Android: "Ürün ile" moduna **Lot No alanı**; LP modunda satırın kendi
     lotu otomatik kullanılır (lot doluysa adHocLot, boşsa adHoc).
3. **Mal Kabul araması satırlardaki ürüne de bakar:** WR + PO sekmelerinde
   aramaya "1002" yazınca o ürünü satırlarında içeren belgeler de listelenir
   (yeni `docsContainingItem` yardımcıyla receiptLines/purchaseSourceLines
   sorgusu, istemcide birleştirme; durum satırında "🔎 ... içerenler dahil").
- releases/android/bcwms-1.10.15-release.apk (+ Masaüstü kopyası güncellendi,
  1.10.14 Masaüstünden kaldırıldı). Lot düzeltmesinin ETKİN olması için BC
  publish şart; publish'e kadar lot'lu üründe anlaşılır hata mesajı verilir.

## 8b. Ad-Hoc "gerçekten taşıyor mu" denetimi + kritik düzeltmeler (16 Temmuz)
Soru üzerine yapılan denetimde bulunanlar ve düzeltmeler (APK v1.10.14):
- **KRİTİK BUG:** `LPApi.transfer`'de boş `linesJson` → `ParseLines` boş liste →
  Transfer döngüsü hiç dönmüyor → **hiçbir satır taşınmadan "başarılı"**
  dönüyordu. Hem yeni Ad-Hoc LP→LP yolu hem LP ekranındaki Transfer düğmesi
  boş gönderiyordu. Düzeltme iki katmanlı: (a) Android artık TÜM satırları
  açıkça gönderiyor (eski publish'te de çalışır), (b) AL transfer action'ı
  boş listeyi "tüm satırlar" olarak dolduruyor (publish sonrası güvence).
- **LP→LP aktarımda stok:** transfer yalnız LP içerik kaydını taşır; hedef LP
  FARKLI bindeyse Android artık ayrıca satır satır `adHoc` reclass postalıyor
  (stok fiziksel olarak da taşınır). Aynı bindeyse reclass atlanır.
- **Bin hedefi:** reclass zaten gerçek stok taşımaydı (Item Reclass Journal
  post); üstüne LP kartının `binCode`'u PATCH ile hedefe güncelleniyor
  (LP raf değiştirdi bilgisi kartta da doğru görünsün).
- releases/android: 1.10.13 geri çekildi (transfer bug'ı içeriyordu) →
  **bcwms-1.10.14-release.apk**.

## 8. LP kurma + Ad-Hoc hareket akışları (ELOG mantığı) — TAMAM (16 Temmuz)
Kullanıcının tarif ettiği sıraya göre iki ekran yeniden düzenlendi:
- **License Plate (kurma):** LP QR okut (belge açılır) → ➕ ürün okut → adet gir →
  **KAYNAK BİN okut** → satır kaydedilir. AL: `LP Line` tablosuna field 55
  **"Source Bin Code"** + `licensePlateLines` API'sine `sourceBinCode` eklendi;
  terminal eski publish'e karşı 400 alırsa alanı çıkarıp yeniden gönderir.
  Satır kartlarında 📍 kaynak bin görünür.
- **Ad-Hoc Hareket:** iki mod — varsayılan **"🧺 LP ile"** (yeni ELOG akışı):
  1) kaynak bin okut → 2) LP okut → 3) **sistem LP içeriğini otomatik listeler**
  → 4) hedef okut: okunan kod bir **LP ise** içerik `transfer` action ile o
  LP'ye aktarılır; **bin ise** satırlar tek tek `movementOps.adHoc` reclass ile
  o rafa taşınır (hedef türü `licensePlates('X')` GET ile otomatik çözülür).
  Eski ürün-bazlı akış "📦 Ürün ile" sekmesinde aynen duruyor.
- Doğrulama: assembleDebug OK; emülatörde Ad-Hoc ekranının adım adım açılan
  yapısı görüldü. **AL alanı (Source Bin Code) Windows publish bekliyor.**

## 6c. Packer rolü + worksheet adları/düzeni + terminal UI — TAMAM (9 Temmuz)
ELOG ekran fotoğraflarına göre hizalama:
- **Sayfa adları ELOG'la birebir:** 72344 → "Solo Package Worksheet",
  72345 → "Batch Package Worksheet" (motor modu Bulk — ELOG bu akışa "batch"
  diyor), 72346 → "Mono-SKU Package Worksheet".
- **Sayfa düzeni fotoğraftaki gibi:** DETAILS (Order/Location/Pick/Orders/
  Unpacked Quantity/Unpacked Lines/Status) + SCANNING (Scan Here → Next Step →
  Current Tote → Current Package → **Current Item** → Last Scan → Last Packed
  Order). Current Item, okuma kutu değilken son okutulan üründür (HandleScan
  `WasItemScan` tespiti).
- **Yeni rol: page 72347 "DOPSWHS Packer RC"** (Caption 'Packer') + **page
  72348 "Packer Activities"** (3 tıklanabilir sayaç kutusu: Batch / Mono-SKU /
  Solo Package Worksheet, açık oturum sayısıyla) + **profile "DOPSWHS PACKER"**
  → BC'de Ayarlar → Rolüm → "Packer" seçilebilir. Embedding'de 3 worksheet
  butonu üst navigasyonda görünür; Sections'ta ayrıca Pack Sessions (All) ve
  Pick Tote Assignments var. El terminali aynı Pack Session tablolarına
  yazdığından terminal oturumları rol ana ekranındaki sayaçlarda canlı görünür.
- Warehouse Manager RC kısayol caption'ları da yeni adlarla hizalandı.
- İzin setlerine 72347/72348 eklendi.
- **Terminal UI güzelleştirme (PackingModule.kt):** aktif oturumda yeni
  `PackWorksheetCard` — sepet + mod rozeti, ilerleme çubuğu, 3 sayaç kutusu
  (Kalan Miktar / Kalan Satır / Sipariş x/y) ve worksheet bilgi satırları
  (Güncel Ürün / Son Okutma / Kutu). Mod seçimi ana menü kart stiliyle
  (PackModeCard) kutu kutu. compileDebugKotlin + assembleDebug OK.

## 6b. Solo/Bulk/Mono-SKU AYRI sayfalar — TAMAM (AL, 8 Temmuz akşam)
Kullanıcı isteği: tek adaptif sayfa yerine ELOG'daki gibi 3 GERÇEKTEN ayrı BC
sayfası + ana dashboard'da 3 ayrı bölüm. Kod tekrarını önlemek için iş mantığı
codeunit 72334'e taşındı, sayfalar ince UI kabuğu:
- Codeunit 72334'e eklenen paylaşılan orkestrasyon: `ProcessScan(var SessionId,
  FixedMode, ScanValue): Text` (tek okuma alanının motoru — oturum yoksa açar,
  açıksa kutu/ürün adımına yönlendirir), `IsOrderCompleted`, `GetSessionDisplay`
  (Details/Next Step alanlarını doldurur). Üç yeni sayfa da bunları çağırır.
- **Page 72344 `Pack Station - Solo (WMS)`** — mod sabit Solo, sepet=sipariş.
- **Page 72345 `Pack Station - Bulk (WMS)`** — mod sabit Bulk, sepet 1 kez
  okutulur, her sipariş payı için ayrı kutu.
- **Page 72346 `Mono-SKU Batch Package Worksheet (WMS)`** — ELOG'un aynı adlı
  sayfasının birebir karşılığı; mod sabit Batch, ürün→kutu döngüsü.
- Her sayfanın `OnOpenPage`'i kullanıcının **o moddaki** son açık oturumuna
  döner (`Rec.SetRange(Mode, ...)`), böylece Solo sayfası yanlışlıkla bir Bulk
  oturumunu göstermez.
- Eski adaptif **Page 72339 `Pack Station (WMS)`** silinmedi — mod seçici
  olarak hâlâ duruyor, `Pack Session List`'in `CardPageId`'si (herhangi bir
  oturumu moddan bağımsız incelemek için) hâlâ ona işaret ediyor.
- **Dashboard (ana ekran):** `Warehouse Mgr Cue` tablosuna 3 FlowField (Open
  Solo/Bulk/Batch Pack Sessions); `Warehouse Manager Activities` part'ına yeni
  **"Pack Station" cuegroup** (3 tık edilebilir sayı, her biri ilgili sayfaya
  drill-down); `Warehouse Manager RC` Shortcuts'a 3 ayrı aksiyon eklendi
  (eski tekil "Pack Station" kısayolu 3'e bölündü).
- İzin setlerine (Admin+User) 3 yeni sayfa eklendi.

## 6. BC istemcisi ekranları — TAMAM (AL)
ELOG'daki "Batch Package Worksheet" gibi masaüstünde (USB/wedge okuyucu ile)
çalışan görünür BC sayfaları:
- **Page 72339 `Pack Station (WMS)`** (Tell Me → Tasks): tek "Scan Here" alanı
  adım bazlı yönlendirir (sepet → kutu → ürün); Details bölümünde Current
  Tote/Box, Pick No., Orders Completed, **Unpacked Quantity / Unpacked Lines**;
  satır alt sayfasında bekleyenler KIRMIZI, tamamlananlar YEŞİL (StyleExpr).
  Aksiyonlar: **Print Last Packed Order** (fiş yeniden bas), Cancel Session, Refresh.
  Mono-SKU/bulk/multi tek sayfada — WI'daki gibi iki ayrı sayfaya gerek yok.
- **Page 72341 `Pack Session Subform`** (ListPart, kırmızı/yeşil satırlar).
- **Page 72340 `Pack Sessions`** (liste; CardPageId → Pack Station).
- **Page 72342 `Pick Tote Assignments`** (sepet–sipariş eşleştirme listesi).
- Warehouse Manager Role Center'a kısayollar eklendi (Pack Station, Pack
  Sessions, Pick Tote Assignments). Ops Console'daki "Siparişler" sekmesi de
  BC içinde (page 72219) çalışır.

## Windows'ta ilk derleme hatası ve düzeltmesi (8 Temmuz 2026, akşam)
Windows publish denemesinde AL0132 hatası çıktı: `FromSalesLine2ShptLine` ve
`SetHideValidationDialog` **codeunit 5750 "Whse.-Create Source Document" üzerinde
mevcut değil** — o codeunit yalnızca düşük seviye satır oluşturma yardımcıları
barındırıyor (`CreateShipmentLine`, `SetQtysOnShptLine`). Gerçek sahibi
**codeunit 5991 "Sales Warehouse Mgt."** — imza:
`FromSalesLine2ShptLine(WarehouseShipmentHeader: Record "Warehouse Shipment Header"; SalesLine: Record "Sales Line") Result: Boolean`
(satırı kendi içinde `InitNewLine`+`Insert` ile oluşturur; ayrıca dialog
bastırma prosedürü yok/gerekmiyor). `MultiOrderPick.AddOrderToShipment` bu
codeunit'i kullanacak şekilde düzeltildi; izin setlerine `Sales Warehouse Mgt.`,
`Release Sales Document`, `Whse.-Shipment Release`, report `Whse.-Shipment -
Create Pick` eklendi. **Yeniden Windows'ta derlenip test edilmeli.**

Doğrulanan diğer imzalar (BC24 base app kaynağından teyit edildi):
- Report 7318 `Whse.-Shipment - Create Pick`: `SetHideValidationDialog(Boolean)`,
  `SetWhseShipmentLine(var WhseShptLine2, WhseShptHeader2)`,
  `Initialize(AssignedID2, SortActivity2, PrintDoc2, DoNotFillQtytoHandle2, BreakbulkFilter2)` — **doğru, değişiklik gerekmedi**.
- Codeunit 5763 `Whse.-Post Shipment`.`SetPostingSettings(PostInvoice: Boolean)` — **doğru**.
- Codeunit `Release Sales Document`.`PerformManualRelease(var SalesHeader)` — **doğru**.
- Codeunit `Whse.-Shipment Release`.`Release(var WhseShptHeader)` — **doğru**.

## Windows publish sonrası hâlâ doğrulanacaklar
1. Enum `Whse. Activity Sorting Method::"Shelf or Bin"` değer adı (kod bulunamadı, isim varsayıldı).
2. `report "Whse.-Shipment - Create Pick"` çağrısında `UseRequestPage(false)` + `RunModal()`
   kombinasyonunun ProcessingOnly=true rapor için beklendiği gibi çalışıp çalışmadığı.
3. XLF çevirileri (tr-TR/de-DE) yeni Label/Caption'lar için yeniden üretilmeli.

## Kurulum / demo hazırlığı
- LP Template: `CARTON-S` (geçici kutu) mevcut olmalı; kalıcı sepetler için
  Reusable (Tote) işaretli şablondan LP'ler üretilip barkod basılmalı.
- `IWX Report Selection`: Usage=**Pack Receipt** için fiş raporu seçin (yoksa 1306 basılır).
- Print kanalı (BCNative/PrintNode/Self-Hosted) paketleme istasyonu yazıcısına eşlenmeli.
- Uçtan uca senaryo: Ops Console → 2-3 sipariş seç → pick oluştur+ata → terminalde
  raf okut → ürün okut → 🧺 sepet öner/okut → Register → Paketleme ekranı → sepet okut
  (kırmızı satırlar) → kutu okut → ürünleri okut → sipariş fişleri otomatik.

## 10. Multi-tenant giriş (20 Temmuz) — APK 1.11.0
Sorun: AL paketi başka müşteriye (BADE) publish edilse de mobil APK tenant'a
SABİT kodluydu (BcApi.TENANT + DeviceAuth authority = DynamicsOps GUID). BADE
e-postasıyla giriş çalışmıyordu; terminalde e-posta yazmak tenant'ı değiştirmiyordu.
Çözüm (kod tarafı — her müşteri için ayrı APK gerekmez):
- DeviceAuth authority `/organizations` (multi-tenant); kullanıcı hangi tenant
  hesabıyla girerse token o tenant'a ait olur.
- BcApi: TENANT sabiti kaldırıldı → `getTenant/setTenant` (SharedPreferences) +
  `captureTenantFromToken` (JWT "tid" claim'i saveToken içinde otomatik yakalanır,
  device-code/ROPC/refresh/token-paste yollarının hepsini kapsar). Tüm BC API
  URL'leri getTenant(context) kullanır (Quality modülü dahil). FALLBACK_TENANT
  yalnız token okunamazsa.
- discoverEnvironments token'daki tenant'ı sorgular; KNOWN_ENVIRONMENTS'a
  "Production"/"Sandbox" eklendi; LoginFlow'a **elle ortam adı + "Bul"** alanı
  (probeEnvironment) — otomatik bulunamayan ortam adları için (BADE = Production).
- clearToken artık tenant/env/company'yi de siler — farklı müşteri hesabıyla
  yeniden girişte eski tenant'a takılmayı önler.

**Entra tarafı (müşteri başına bir kez, kod dışı):** BCWMSApp Mobile client
kaydı **AzureADMultipleOrgs** (multi-tenant) + "Allow public client flows" =
Yes olmalı; her müşteri yöneticisi kendi tenant'ında bu client'a
`Dynamics 365 Business Central / user_impersonation` (delegated) onayı verir.
Sonra BADE kullanıcısı aynı APK'yla girer; ortam adı "Production" yazılır.
Uzun vade: client'ı AppSource/publisher domain ile yayınlamak onayı basitleştirir.

## Toplanacak Siparişler — toplama durumu + akıllı filtre (21 Tem 2026)

"Satış siparişleri statüleriyle birlikte BC ekranına toplanacak siparişler olarak
çekilsin" isteği. Mevcut Picking Order (tablo 72352 "Toplanacak Siparişler",
sayfa 72356/72357) üzerine eklendi — yeni sayfa açılmadı.

- **Toplama Durumu kolonu** (sayfa 72355 Picking Order Lines): sipariş satırında
  Pick Yok / Pick Açık / Toplandı (renkli: Unfavorable/Ambiguous/Favorable).
  `PickingOrderMgmt.GetSalesOrderPickStatus(salesOrderNo)`:
  0=açık Warehouse Activity Line yok + Registered da yok; 1=açık pick satırı var;
  2=Registered Whse. Activity Line var (register edilince açık satır silindiği için
  tamamlanma yalnız Registered'dan anlaşılır). Source Type=Sales Line, Subtype=1.
- **"Satış Siparişlerini Seç" filtresi** (sayfa 72356 SelectSalesOrders): artık
  yalnız **Released + pick'i olmayan** siparişler. `FilterToPickable(SalesHeader)`
  açık/registered pick'i olan No.'ları `<>...&` filtresiyle eler (uzun filtre riski
  var ama AddOrder guard'ı slip-through'u yakalar). AddOrder'a da
  `SalesOrderHasOpenPick` guard eklendi (zaten pick'li sipariş gruba eklenemez).
- Yeni kod: PickingOrderMgmt cu 72354 (GetSalesOrderPickStatus / SalesOrderHasOpenPick
  / FilterToPickable). **AL derlenmedi — Windows publish gerekli.**

## Toplanacak Siparişler — OPS Status = Pending filtresi (21 Tem 2026)

Saha gözlemi: "Satış Siparişlerini Seç" listesinde Refunded/Canceled/Returned
siparişler de çıkıyordu. Kullanıcı: yalnız **OPS Status = Pending** toplanabilir.
"OPS Status" başka eklentinin alanı (field 60000, Option) — bizim koda derleme
bağımlılığı yaratmamak için RecordRef/FieldRef ile field-no üzerinden erişilir.

- `PickingOrderMgmt.ApplyOpsPendingFilter(SalesHeader)`: RecRef.FieldExist(60000)
  → yoksa atla (o eklenti kurulu değilse hata verme). FieldRef.OptionMembers()'tan
  'Pending' üyesinin ordinal'i `OptionOrdinal()` ile çözülür, FldRef.SetRange(ordinal).
- PickingOrderCard SelectSalesOrders: SetRange(Status,Released) + ApplyOpsPendingFilter
  + FilterToPickable (açık/registered pick eleme) sırasıyla uygulanır.
- 'Pending' üyesi bulunamazsa filtre atlanır (güvenli taraf — hepsi görünür).

## Toplanacak Siparişler — Released şartı kaldırıldı + ölçeklenebilir filtre (21 Tem 2026)

Saha: BADE'de 5.341 Pending sipariş var ama sadece 2'si Released → liste 2 gösteriyordu.
Kullanıcı: toplama için Released ŞART DEĞİL, OPS Status = Pending yeterli.
- PickingOrderCard SelectSalesOrders: `SetRange(Status, Released)` KALDIRILDI.
  Kalan: Document Type=Order + ApplyOpsPendingFilter (OPS=Pending) + FilterToPickable.
- FilterToPickable ÖLÇEKLENEBİLİR yeniden yazıldı: 5000+ siparişi tek tek dolaşmak
  yerine PICK SATIRLARINI (az) tarar, pick'i olan Source No.'ları Dictionary'de
  toplar, tek <>...& filtresi kurar (SetLoadFields ile hızlı). ~1900 char sınırı
  aşılırsa durur; AddOrder guard'ı kalanı yakalar.
