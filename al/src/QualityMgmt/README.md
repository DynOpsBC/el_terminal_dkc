# DOPSWHS Quality Management Bridge (Sprint Q1)

> Microsoft Quality Management (BC v27 preview / v28 GA, AppID
> `bc7b3891-f61b-4883-bbb3-384cdef88bec`) entegrasyonu için planlama klasörü.
> Sprint Q1'in AL kodu MS QM symbol fetch'i tamamlandığında bu klasörde
> oluşturulacak. Mevcut commit reserve object ID'leri ve roadmap'i belgeler.

## Durum

| Durum | Açıklama |
|---|---|
| ⏸ Beklemede | MS QM symbol fetch (kullanıcı tarafında) — `al/.alpackages/Microsoft_Quality Management_*.app` |
| ✅ Hazır | Plan + obje ID rezervasyonu (bu doküman) |
| ✅ Hazır | Mobile + Web Picking/PutAway QC-block error parsing (Sprint Q2/Q3b) |

## Obje ID Rezervasyonu (72075-72080)

| ID | Tip | Ad | Sorumluluk |
|---|---|---|---|
| 72075 | page | `DOPSWHS Quality Inspection API` | Quality Inspection header read + start/finish/cancel bound actions |
| 72076 | page | `DOPSWHS Quality Test API` | Quality Test line read + recordResult bound action (typed value PATCH) |
| 72077 | page | `DOPSWHS Quality Template API` | Quality Inspection Template read-only catalog |
| 72078 | page | `DOPSWHS Quality Result API` | Quality Inspection Result codes read-only catalog |
| 72079 | codeunit | `DOPSWHS Quality Mgmt Bridge` | MS QM `Codeunit "Quality Mgmt"` wrapper + event subscribers |
| 72080 | codeunit | `DOPSWHS Quality Workflow Sub` | MS QM workflow event subscribers (Inspection Created / Finished) |

Bu ID'ler `al/app.json idRanges 72000-72099` içinde. Diğer DOPSWHS objeleri
72072 (Scenario Generator) ile bitiyor — bu blok yedek.

## Kullanıcının Yapması Gereken Adımlar

### Adım 1 — MS QM Symbol fetch

VS Code'da:
```
1. al/ klasörünü VS Code workspace olarak aç
2. Ctrl/Cmd+Shift+P → "AL: Download symbols"
3. Hedef ortam seç:
   - Tenant: 7fa2357e-26f2-4174-8e16-a713981356b8
   - Environment: SandboxUS
   - Authentication: AAD
4. al/.alpackages/ klasörüne şu paketin indiğini doğrula:
   Microsoft_Quality Management_<version>.app
```

### Adım 2 — Object ID Introspection

Symbol dosyasını incele:
```bash
cd al/.alpackages
unzip -d /tmp/qm-symbols "Microsoft_Quality Management_*.app"
cat /tmp/qm-symbols/SymbolReference.json | jq '.Tables[].Id, .Tables[].Name' | head -40
cat /tmp/qm-symbols/SymbolReference.json | jq '.Codeunits[] | select(.Name | contains("Quality")) | {Id, Name, Methods: .Methods | map(select(.IsPublic))}' | head -80
```

Sonuçları bu README'nin sonundaki "Object Reference" bölümüne yapıştır.

### Adım 3 — Bu Doc'taki "Object Reference" Bölümünü Doldur

Aşağıdaki tablo doldurulacak. **Bu doldurulmadan AL kodu yazılamaz**.

### Adım 4 — AL Kodu

Symbol fetch tamamlandığında bu klasöre eklenecek dosyalar:
- `QualityInspectionApi.Page.al` (72075)
- `QualityTestApi.Page.al` (72076)
- `QualityTemplateApi.Page.al` (72077)
- `QualityResultApi.Page.al` (72078)
- `QualityMgmtBridge.Codeunit.al` (72079)
- `QualityWorkflowSub.Codeunit.al` (72080)

`app.json` v1.7.7.0 → v1.8.0.0 bump + `Permissions/Admin+UserPermissionSet.al`
güncellemesi.

## Object Reference (kullanıcı symbol fetch sonrası doldurur)

> Aşağıdaki tablo placeholder. Symbol introspection sonrası gerçek değerlerle
> doldurun ve AL kodu o zaman yazılacak.

| MS QM Object | Type | ID | Extensible? | Notlar |
|---|---|---|---|---|
| Quality Inspection (header) | Table | TBD | TBD | Source ref'ler: Purch Rcpt Line / Prod Order Line / Asm Header |
| Quality Test (line) | Table | TBD | TBD | Type-specific value alanları (Decimal/Bool/Date/Lookup) |
| Quality Inspection Template | Table | TBD | TBD | Tests altında |
| Quality Test Lookup Value | Table | **20408** ✓ | TBD | Tek belgelenen ID |
| Quality Inspection Result | Table | TBD | TBD | Result codes (PASS/FAIL/INPROGRESS) |
| Quality Inspection Generation Rule | Table | TBD | TBD | Auto-trigger rules |
| Quality Management Setup | Table | TBD | n/a | Tenant config |
| Quality Mgmt | Codeunit | TBD | TBD | Ana API codeunit — public method'lar burada |

## Workflow Event'ler

MS QM dokümanında yer alan workflow events (Sprint Q1'de subscribe edilecek):

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"<MS QM Workflow Codeunit>", 'OnAfterQualityInspectionCreated', '', false, false)]
local procedure OnQualityInspectionCreated(QualityInspectionRecRef: RecordRef)
begin
    // DOPSWHS Picks/Put-Aways için lot block kontrolü
    // Buradan DOPSWHS event raise et: OnQualityInspectionOpenedForLot
end;

[EventSubscriber(ObjectType::Codeunit, Codeunit::"<MS QM Workflow Codeunit>", 'OnAfterQualityInspectionFinished', '', false, false)]
local procedure OnQualityInspectionFinished(QualityInspectionRecRef: RecordRef; ResultCode: Code[20])
begin
    // Result'a göre lot unblock veya quarantine routing
end;
```

Event imzaları kesin değil; symbol introspection ile netleşir.

## Mevcut Mobile/Web Hazırlığı

MS QM AL bridge bekleyene kadar **mobile + web Picking/PutAway** tarafı
QC-block error parsing yaparak hazır:

- Mobile: `PickingModule.kt` + `PutAwayShipModules.kt` API error response'unda
  "blocked by quality" / "inspection" keyword'leri yakalanır, kullanıcıya
  "Lot QC inspection nedeniyle bloklu — INS-001 numaralı denetimi tamamlayın"
  banner'ı gösterilir + deep-link Quality modülüne.
- Web: `web/src/modules/Picking.tsx` + `PutAway.tsx` aynı pattern.

Bu Sprint Q2 ve Q3b'de implement edildi (commit history). MS QM bridge devreye girdiğinde error mesajları zaten beklenen formatta gelir; UI değişikliği gerekmez.

## Versiyon Hedefi

`al/app.json` `v1.7.7.0 → v1.8.0.0` (Q1 tamamlandığında minor bump). Bu commit
versiyonu değiştirmez — sadece placeholder.

## Risk Notu

MS QM tabloları **Extensible = false** olarak yayınlandıysa DOPSWHS API page
yazma yöntemi çalışmaz. O senaryoda alternatif:
- Workflow event subscriber (yine de mümkün)
- Bizim DOPSWHS Quality Order tablomuza MS QM verisini **mirror** etme
  (HttpClient ile BC'nin kendi Connect API'sini çağırarak)

Sembol introspection bu kararı netleştirir.
