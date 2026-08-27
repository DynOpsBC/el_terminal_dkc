# SandboxUS Kurulumu + Posting Testleri + Kalite Denetimi (Quality Orders)

> Ortam: tenant `7fa2357e-26f2-4174-8e16-a713981356b8`, environment **SandboxUS**, company **CRONUS USA, Inc.**
> (`1534369d-f248-f111-b478-7c1e521cfdf0`). AL **v1.2.0.0** hem SandboxUS hem CustomerSandbox'a publish edildi.
> Mobil **v1.7.0** SandboxUS/CRONUS USA'ya yönlendirildi.

## 1. SandboxUS deployment

- AL extension SandboxUS'a publish edildi; `OnInstall`/`OnUpgrade` artık tam bootstrap yapıyor (demo data +
  test catalog + posting-test satırları + demo kalite emirleri) → yeni ortam **kendi kendine test-hazır**.
- 8/8 custom entity set HTTP 200 (warehouse/v2.0). Bootstrap CRONUS USA + My Company için çalıştı.

## 2. Posting harness — CRONUS USA canlı sonuç (4/9)

| Domain | Sonuç | Kanıt / Açıklama |
|---|---|---|
| Inventory Count | ✅ PASS | Phys. inv. post — `CNT-…` |
| Warehouse Receipt | ✅ PASS | PO → whse receipt → post — `107246` (WHITE) |
| Put-Away register | ✅ PASS | `PU000007` (WHITE) |
| **Assembly post** | ✅ PASS | `A00003` (item **1925-W**) — US Cronus assembly verisiyle artık geçiyor |
| Ad-Hoc Move | ⚠️ Config | Default lokasyon SILVER **directed** → item-reclass bin içeriği oluşturmuyor; directed lokasyonda **Yönlendirilmiş Hareket** (whse movement) kullanılır |
| Warehouse Shipment / Pick | ⚠️ Platform | BC24'te **directed pick oluşturma için extension API yok**; pick mobil Pick modülünden register edilir, sonra Post Shipment |
| Production Consume | ⚠️ Config | Logic düzeltildi (Order Type sırası + Post Batch); kalan: **Inventory Posting Setup'ta WIP Account** eksik (BC üretim muhasebe kurulumu) |
| Production Output | ⚠️ Config | Üretim rota/iş-merkezi kurulumu gerekir |

**Bu turda düzeltilen ek üretim hatası:** `ProdMgmt.Consume/ReportOutput` — item journal satırında **Order Type, Item No.'dan önce** set edilmeli (yoksa posting "Order Type must be Production" reddediyordu) + `Item Jnl.-Post Batch` (confirm dialog'suz). Bu mobil Üretim postinglerini de etkiliyordu.

**Özet:** 4/9 canlı doğrulandı. Kalan 5 → app posting *mantığı* değil, **BC platform/kurulum** sınırları
(directed lokasyon, directed-pick API yokluğu, üretim muhasebe kurulumu). App'in Mgmt codeunit'leri gerçek
BC posting codeunit'lerini çağırıyor ve mantık düzeltildi (Consume artık WIP-account sınırına kadar doğru).

## 3. Mobil app → SandboxUS

- `BcApi.kt`: `ENVIRONMENT="SandboxUS"`, `COMPANY_ID=CRONUS USA`. APK **v1.7.0** (`~/Desktop/BCWMSApp-v1.7.0-SandboxUS.apk`).
- Emulator'da 🟢 Bağlı (HTTP 200), **📮 Posting Test** ekranından `runAll` app'ten tetiklendi → 4/9 (canlı belge: Count/Receipt/Put-Away/Assembly).

## 4. Kalite Denetimi (Quality Orders) — YENİ modül, app'ten yönetiliyor

WMS'e kalite denetim emri yönetimi eklendi: mal kabul/üretim sonrası gelen malı denetçi **mobil app'ten**
KABUL eder (serbest bırak) veya RED eder (→ karantina bin'i).

**AL (warehouse/v2.0):**

- Tablo 72254 `DOPSWHS Quality Order` (No., Source Type, Item, Qty, Sample Size, Status, Inspector, Reject Reason, Quarantine Bin…)
- CU 72255 `DOPSWHS Quality Mgmt` — `CreateOrder`, `Pass`, `Fail`, `SeedDemoOrders`, ANSI-tarzı numune boyutu (%10, min 1, max 20)
- Page 72256 `DOPSWHS Quality Order API` (`qualityOrders`) — bound action'lar `pass`, `fail`, `createOrder`

**Mobil:** `🔬 Kalite Denetimi` ekranı (`QualityModule.kt`) — açık/tümü filtre, denetim sheet'i (numune scan + KABUL/RED + RED sebebi + karantina bin).

**Canlı doğrulama (SandboxUS / CRONUS USA):**

- 3 demo kalite emri seed edildi (1896-S, 1900-S, 1906-S) numune boyutlarıyla.
- API: `pass` → HTTP 204 (Passed, DENIZ) · `fail` → HTTP 204 (Failed, DAMAGED, QUARANTINE) · `createOrder` → HTTP 200 (yeni QO).
- **Mobil app'ten:** QO-…-2 kartına dokunup **KABUL** → BC'de `Passed`, **Inspector = MOBIL** ✅ doğrulandı.

### Sonraki adımlar (Quality v2, istenirse)

- Mal kabul/üretim post'unda **otomatik** kalite emri tetikleme (receipt → quality order).
- RED'de stoğu otomatik karantina bin'e taşıma (whse movement entegrasyonu).
- Ölçüm/karakteristik (test plan) alanları + foto ek.
- RED sebep kodları master tablosu + zorunlu alan kuralları.

## Kalan platform/kurulum işleri (6 posting'in tamamı yeşil için)

1. **Üretim (Consume/Output):** CRONUS USA'da Inventory Posting Setup WIP/Output hesapları + iş merkezi/rota kurulumu.
2. **Sevkiyat/Pick:** non-directed (require-shipment) test lokasyonu **veya** pick'i mobil Pick akışından register edip Post Shipment.
3. **Ad-Hoc Move:** default lokasyonu non-directed bin lokasyonu yap (directed'da Yönlendirilmiş Hareket kullanılır).
