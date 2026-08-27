# Sprint 1 — Inquiry + Config (2 hafta)

## Hedef

Cihaz konfigürasyon altyapısı + barkod kuralları + sunucu-istemci paritesindeki barkod ayrıştırıcı + Item/Bin sorgulama akışları. Bu sprint sonunda mobil cihaz, sandbox'tan cihaz konfigürasyonunu çekebiliyor ve item/bin barkodlarını okuyup BC kartlarını gösterebiliyor.

## Demo Kriterleri

1. Sandbox'ta `DOPSWHS Device Configuration` listesinde "DEFAULT" record var; cihaz bu profile bağlanıyor.
2. Mobilde **Item Inquiry** → kamera ile EAN-13 barkod okut → Item Card açılıyor (factbox'ta LP listesi de).
3. Mobilde **Bin Inquiry** → bin barkodu (`B-A01-01`) okut → bin content + LP listesi.
4. GS1-128 barkod okutulunca lot/expiry/serial otomatik dolar (test verisinde `(01)08401234567890(10)LOT123(17)260101(21)SN42`).

## AL İş Paketleri

### Device tabloları (4 tablo, 5 sayfa)

- `al/src/Device/DeviceConfig.Table.al` (T 72001) — alanlar: `Code`, `Description`, `Location Code`, `Login Mode` (enum 72202), `Assign Document On Open`, `Ignore Bins`, `LP Usage Default Action` (enum 72204), `Max List Rows`, `Scan Beep`, `Auto Post`, `Print Channel` (enum 72203)
- `al/src/Device/DeviceMenu.Table.al` (T 72002) — `Code`, `Application Module` enum, `Menu Item`, `Sort Order`, `Visible`
- `al/src/Device/DeviceColumn.Table.al` (T 72003) — `Config Code`, `List Name`, `Column Name`, `Width`, `Sort Order`
- `al/src/Device/DeviceRegistration.Table.al` (T 72004) — `Device ID`, `Fingerprint`, `App Version`, `Last Seen DateTime`, `Active`, `Assigned User`, `Config Code`
- `al/src/Device/DeviceConfigList.Page.al` (P 72063) + `DeviceConfigCard.Page.al` (P 72062)
- `al/src/Device/DeviceMenuList.Page.al` (P 72064) + `DeviceColumnList.Page.al` (P 72065) + `DeviceRegistrationList.Page.al` (P 72066)
- `al/src/Device/DeviceAuth.Codeunit.al` (CU 72038) — cihaz handshake; ilk bağlantıda registration kaydı oluşturur veya günceller

### Barkod altyapısı (2 tablo, 2 codeunit, 2 sayfa)

- `al/src/Barcode/Symbology.Table.al` (T 72006) — `Code`, `Description`, `Format` (Enum 72200), `Min Length`, `Max Length`
- `al/src/Barcode/BarcodeRule.Table.al` (T 72005) — `Code`, `Description`, `Symbology`, `Regex`, `Capture Map JSON`, `Maps To` (Item/Bin/LP/LpTemplate/Lot/Serial), `Order`, `Active`
- `al/src/Barcode/BarcodeParser.Codeunit.al` (CU 72036) — entry: `[TryFunction] ParseBarcode(raw: Text; var Result: Record "DOPSWHS Parsed Barcode Buffer"): Boolean`
- `al/src/Barcode/GS1AIParser.Codeunit.al` (CU 72037) — AI-aware parser: 01/10/17/21/00 → field map
- `al/src/Barcode/SymbologyList.Page.al` (P 72068) + `BarcodeRuleList.Page.al` (P 72067)

### Inquiry API + page extensions

- `al/src/Inquiry/ItemApi.Page.al` (P 72086) — `entitySetName=items`, GET tek item; $expand=`binAvailability,lpAvailability`
- `al/src/Inquiry/BinApi.Page.al` (P 72087) — `entitySetName=bins`, GET; $expand=`contents,licensePlates`
- `al/src/Inquiry/ItemCardExt.PageExt.al` (PageExt 72300) — Item Card (30) üzerine LP factbox
- `al/src/Inquiry/BinCardExt.PageExt.al` (PageExt 72301) — Bin Card (7303) üzerine LP factbox
- `al/src/Inquiry/LPFactboxItem.Page.al` (P 72077) — ListPart, factbox olarak embed edilir
- `al/src/Inquiry/LPFactboxBin.Page.al` (P 72078)

### Device + Barcode API

- `al/src/Device/DeviceApi.Page.al` (P 72225) — `/devices({id})/config`; bound action `register`
- `al/src/Barcode/BarcodeParseApi.Page.al` (P 72226) — `/barcodes/Microsoft.NAV.parse`; body `{raw}` → `{kind,fields}`

### Enum'lar

- `al/src/Enums/ScanSource.Enum.al` (Enum 72099) — Camera, DataWedge, Honeywell, Datalogic, KeyboardWedge
- `al/src/Enums/Symbology.Enum.al` (Enum 72200)
- `al/src/Enums/LoginMode.Enum.al` (Enum 72202)

### Item tablo extension

- `al/src/Inquiry/ItemExt.TableExt.al` (TableExt 72400) — `Default LP Template`, `Default Print Rule Code`

### Setup wizard seed

- `SetupWizard.Codeunit.al` güncellemesi: barcode rules seed (EAN13-ITEM, GS1-128-FULL, SSCC-18, BIN-PREFIX, LP-TEMPLATE)

### Test

- `tests/src/Barcode/BarcodeParserTests.Codeunit.al` — 15+ test (EAN-13, GS1-128 7 AI kombinasyonu, SSCC-18, BIN-PREFIX, geçersiz girdi)
- `tests/src/Device/DeviceAuthTests.Codeunit.al` — ilk bağlantı registration, mevcut device update

## Android İş Paketleri

### `:core-scanner`

- `core/scanner/Scanner.kt` — interface
- `core/scanner/CameraScanner.kt` — CameraX + ML Kit; multi-format
- `core/scanner/DataWedgeScanner.kt` — broadcast receiver, intent action `com.dynops.bcwms.SCAN`
- `core/scanner/HoneywellScanner.kt` — Honeywell AIDC SDK (stub if SDK not yet integrated; FakeScanner fallback)
- `core/scanner/DatalogicScanner.kt` — Datalogic intent stub
- `core/scanner/KeyboardWedgeScanner.kt` — keystroke aggregator
- `core/scanner/FakeScanner.kt` — test/preview
- `core/scanner/ScannerFactory.kt` — device fingerprint lookup (Build.MANUFACTURER, MODEL)
- `core/scanner/BarcodeIntentResolver.kt` — server-parity sınıflandırma; AL `BarcodeParser` ile aynı output
- `core/scanner/BeepProvider.kt`

### `:feature-itemInquiry`

- `feature/itemInquiry/ItemInquiryScreen.kt` — Compose; ScanInputField + ItemCard
- `feature/itemInquiry/ItemInquiryViewModel.kt` — MVI
- `feature/itemInquiry/ItemRepository.kt` — implements `:core-domain` interface
- on-hand by bin, recent transactions, lot/serial picker, item images

### `:feature-binInquiry`

- `feature/binInquiry/BinInquiryScreen.kt`
- `feature/binInquiry/BinLpTree.kt` — bin içindeki LP'leri ağaç olarak gösterir

### `:feature-config`

- `feature/config/DeviceConfigScreen.kt` — sunucudan çekilen config'i göster

### `:feature-auth` güncellemeleri

- `ConnectionProfileScreen.kt` QR import — QR içeriği JSON `{tenant,env,company,deviceConfig}`
- `QrProfileImporter.kt`

### `:feature-home`

- `feature/home/HomeScreen.kt` — landing; menü öğeleri device config'ten gelir
- `feature/home/MenuRouter.kt`

### `:core-domain` (Sprint 1 ek usecase'ler)

- `usecase/ParseBarcode.kt`, `usecase/GetItem.kt`, `usecase/GetBin.kt`, `usecase/RegisterDevice.kt`

### Test

- `core/scanner/test/BarcodeIntentResolverTest.kt` — server testlerinin aynısı, parite kontrolü
- `feature/itemInquiry/test/ItemInquiryViewModelTest.kt`

## Web İş Paketleri

(Bu sprint'te SPA yok; AL Role Center sayfalarında setup ekranları görünür hale geliyor.)

## Eklenen API Endpoint'leri

| Verb | Path |
|---|---|
| GET | `/items({no})` |
| GET | `/bins({code})` |
| GET | `/devices({id})/config` |
| POST | `/devices/Microsoft.NAV.register` |
| POST | `/barcodes/Microsoft.NAV.parse` |

## Bağımlılıklar (Sprint 0'dan)

- `DOPSWHS Setup` tablo + sayfa mevcut
- Telemetry codeunit mevcut
- MSAL auth flow çalışıyor
- AL compile + sandbox publish pipeline çalışıyor

## Bitiş Kriterleri (DoD)

- [ ] Item barkodu okutunca `ItemInquiryScreen` Item Card datasını gösteriyor
- [ ] Bin barkodu okutunca `BinInquiryScreen` bin contents + LP listesini gösteriyor
- [ ] GS1-128 barkod testinde lot/expiry/serial otomatik dolar
- [ ] `BarcodeParser` test coverage ≥ %90
- [ ] `BarcodeIntentResolver` mobil testi sunucu testiyle paritede (aynı 15+ vaka)
- [ ] Setup Wizard 5 barcode rule seed eder
- [ ] AL Test Runner yeşil, AppSourceCop warning=0
- [ ] `docs/release-notes/sprint-1.md` mevcut
