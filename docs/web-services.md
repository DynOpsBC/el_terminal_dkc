# BCWMS — Web Service / OData Yaklaşımı (extension API olmayan operasyonlar)

BC24'te bazı standart operasyonların **extension'dan erişilebilir AL API'si yok** (en belirgini:
directed **pick oluşturma** — `Whse.-Source - Create Document` / `WhseShptHeader.CreatePickDoc`
internal). Bunları, ilgili standart sayfaları **tenant web service** olarak yayınlayıp **OData (veri)**
ve **SOAP (sayfa aksiyonları, örn. CreatePick)** üzerinden çözüyoruz. Yayınlama kurulum/upgrade'de
**otomatik** yapılır.

## Otomatik yayınlama (kurulum prosedürü)

- **CU 72257 `DOPSWHS Web Svc Publisher`** → `PublishAll()` her install/upgrade'de çalışır (idempotent,
  `AllObjWithCaption` ile obje varlık kontrolü → hatalı ID upgrade'i bozmaz).
- **Warehouse Employee setup:** `DOPSWHS E2E Test Data.EnsureWarehouseEmployee()` — mevcut kullanıcıyı tüm
  bin-mandatory lokasyonlarda Warehouse Employee yapar. Bu olmadan warehouse sayfaları "You must first set
  up user X as a warehouse employee" hatası verir (OData/SOAP **ve** BC client). Bootstrap'a eklendi.

## Yayınlanan web servisler (v1.3.1.0)

| Servis adı | Sayfa | Kullanım |
|---|---|---|
| `DOPSWHSWarehouseShipment` | 7335 | **SOAP CreatePick** (directed pick) + OData veri |
| `DOPSWHSWarehousePick` | 5779 | Pick activity (OData read/update) |
| `DOPSWHSRegdWhseActivity` | 5797 | Registered pick/put-away (OData read) |
| `DOPSWHSWarehouseReceipt` | 5768 | SOAP CreatePutAway + OData |
| `DOPSWHSWarehousePutAway` | 5770 | Put-away activity |
| `DOPSWHSItemReclassJournal` | 393 | Ad-hoc/reclass move |
| `DOPSWHSWhseItemJournal` | 7324 | Directed lokasyon reclass |
| `DOPSWHSReleasedProdOrder` | 99000831 | Üretim emri |
| `DOPSWHSProductionJournal` | 5510 | Sarfiyat/output journal |
| `DOPSWHSPostingTests` | 72253 | Posting harness (OData V4) |
| `DOPSWHSQualityOrders` | 72256 | Kalite emirleri (OData V4) |

## Endpoint'ler

- **OData V4 (veri):** `https://api.businesscentral.dynamics.com/v2.0/{tenant}/{env}/ODataV4/Company('{company}')/{servis}`
- **SOAP (sayfa aksiyonları):** `https://api.businesscentral.dynamics.com/v2.0/{tenant}/{env}/WS/{company}/Page/{servis}`
- Servis listesi: `.../ODataV4/` (service document).

### Doğrulanan (SandboxUS / CRONUS USA, v1.3.1.0)

- `.../ODataV4/` → 16 DOPSWHS entity set listelendi (11 servis + parent/line alt sayfaları).
- `GET .../ODataV4/Company('CRONUS USA, Inc.')/DOPSWHSWarehouseShipment` → **HTTP 200** (SH000001/SH000002).
- `GET .../DOPSWHSItemReclassJournal` → **HTTP 200**.
- (Warehouse Employee setup'tan ÖNCE: HTTP 400 "set up user as warehouse employee" → setup'tan SONRA 200.)

## Directed pick'i web service ile oluşturma (örnek akış)

1. Whse shipment'ı OData ile bul: `GET .../DOPSWHSWarehouseShipment?$filter=Status eq 'Released'`.
2. Pick oluştur: **SOAP** `DOPSWHSWarehouseShipment` servisinde `CreatePick` aksiyonunu çağır (sayfanın
   "Create Pick" aksiyonu SOAP'ta method olarak görünür).
3. Pick'i OData ile işle: `DOPSWHSWarehousePick` üzerinde Qty to Handle güncelle → register
   (veya mobil Pick modülünden `picks/register`).
4. Shipment'ı post et: custom API `shipments/post` **veya** SOAP `Post`.

> Not: Harness (server-side AL) kendi BC'sine geri HTTP çağrısı yapmadığı için Shipment/Pick'i hâlâ
> "web service ile oluştur" mesajıyla raporluyor; ama **dış istemci (mobil/entegrasyon) artık bu servisleri
> kullanabilir** — directed-pick boşluğu kapandı.

## Sonraki adım (opsiyonel)

- Mobil Pick modülüne SOAP `CreatePick` çağrısı ekleyip uçtan uca Shipment→Pick→Post'u handheld'den tamamlamak.
- Üretim consume/output için Inventory Posting Setup (WIP) + iş merkezi/rota kurulumunu da bir setup
  prosedürüne eklemek (Quality/WebSvc publisher ile aynı desende).
