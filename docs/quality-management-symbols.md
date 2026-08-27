# Microsoft Quality Management — Symbol Notes (BCWMSApp Integration)

> Sprint Q0 çıktısı. BCWMSApp'in `DOPSWHS` AL paketinin Microsoft'un
> first-party Quality Management extension'ı üzerine yazacağı API page'ler için
> referans dokümandır.

## Extension Identity

| Field | Value |
|---|---|
| App ID | `bc7b3891-f61b-4883-bbb3-384cdef88bec` |
| Publisher | `microsoftdynsmb` |
| Name | Quality Management |
| Public preview | BC v27 (2025 release wave 2 — Kasım 16, 2025) |
| GA | BC v28 (2026 release wave 1 — Nisan 1, 2026) |
| AppSource | https://marketplace.microsoft.com/product/PUBID.microsoftdynsmb%7CAID.bc_qualitymanagement |
| Install | New environments auto, existing manuel (Extension Management / AppSource) |
| Licence | Premium (production-output testleri için) / Essential (receiving + assembly için yeterli) |

**SandboxUS durumu**: Kullanıcı doğruladı — extension yüklü. Hangi BC versiyonunda olduğunu Setup card → DOPSWHS → "BC Build" satırından veya BC client → Settings → About bölümünden alabiliriz. v27 ise public preview davranışları + bazı API breaking changes v28'de olabilir; v28 ise GA stabil.

## Tablo / Obje ID'ler

Microsoft Learn yalnızca **bir** object ID'yi explicit belgeliyor:

| Object | Type | ID |
|---|---|---|
| `Quality Test Lookup Value` | Table | **20408** |

20400-series Microsoft AppSource reserved range — diğer QM objelerinin ID'leri bu civarda (20400-20499 muhtemelen). Kesin object ID'leri için **AL symbol introspection** gerekiyor. Lokal `al/.alpackages/` cache'inde QM symbol yok; çıkarmanın yolları:

**Yol 1 — VS Code AL Extension üzerinden**:
```
1. VS Code'da al/ klasörünü aç
2. Ctrl/Cmd+Shift+P → "AL: Download symbols"
3. SandboxUS environment seç + tenant ID gir
4. al/.alpackages/Microsoft_Quality Management_<version>.app indirilir
5. Inspect: unzip + symbols/SymbolReference.json incele
```

**Yol 2 — BC OData $metadata**:
```bash
TOKEN=$(az account get-access-token --resource https://api.businesscentral.dynamics.com --query accessToken -o tsv)
curl -sH "Authorization: Bearer $TOKEN" \
  "https://api.businesscentral.dynamics.com/v2.0/SandboxUS/api/v2.0/\$metadata" | \
  grep -iE "quality|inspection|qms" | head -20
```
Bu sadece API-exposed page'leri gösterir; QM kendi public API'sini yayınlamadığı için tablo seviyesinde bilgi vermez.

**Yol 3 — BC Web Client Page Inspector**:
```
1. BC web client'ta QM page'lerini aç
2. Page header'ında "Help & Support" → "Inspect pages and data"
3. Açılan paneldeki "Table" sekmesinden Table ID + Field listesini gör
```

## Logical Entities (docs'tan çıkarılan)

Aşağıdakiler **kesin** olarak BC QM'de var (Microsoft Learn product docs'tan):

| Logical entity | Beklenen rol | DOPSWHS API'mizde wrap olacak mı? |
|---|---|---|
| Quality Inspection (header) | Inspection header — no, source doc, status, result code | ✅ `qualityInspections` (read + start/finish/cancel) |
| Quality Test (line) | Per-line measurement — type-specific value, pass/fail | ✅ `qualityTests` (read + recordResult) |
| Quality Inspection Template | Template definition + linked tests | ✅ `qualityTemplates` (read-only) |
| Quality Test Lookup Value (T20408) | Lookup values for Lookup-type tests | (gerekirse) `qualityLookupValues` (read-only) |
| Quality Inspection Result | Result code katalogu (PASS, FAIL, INPROGRESS, ...) | ✅ `qualityResults` (read-only) |
| Quality Inspection Generation Rule | Auto-trigger rule (PO receipt, prod output, vb.) | (faz 2) — read-only |
| Lot/Serial/Package No. Information ext. | Block flags lot/serial/package üzerine | Mevcut tabledata'ya read ekle |
| Quality Management Setup | Tenant-level config | (gerekmez — read-only) |

## Bound Action (DOPSWHS-side, wrap edilecek)

DOPSWHS Quality Mgmt Bridge codeunit (CU 72079 önerisi) şu işlemleri sarar:

```al
procedure CreateInspection(
    SourceDocType: Enum;       // 0=PurchReceiptLine, 1=ProdOutputJournal, 2=AsmHeader, ...
    SourceDocNo: Code[20];
    LotNo: Code[50];
    SerialNo: Code[50];
    TemplateCode: Code[20]
): Code[20]                   // returns new inspection no
procedure RecordTestResult(
    InspectionNo: Code[20];
    TestLineNo: Integer;
    DecimalValue: Decimal;
    OptionValue: Integer;
    BooleanValue: Boolean;
    TextValue: Text;
    DateValue: Date;
    LookupValue: Code[20]
): Boolean
procedure FinishInspection(InspectionNo: Code[20]; ResultCode: Code[20]): Boolean
procedure CancelInspection(InspectionNo: Code[20]; Reason: Text): Boolean
```

Underlying olarak MS QM'in kendi `Codeunit "Quality Mgmt"` (object ID belirsiz, sembol açılınca netleşir) içindeki public procedure'ları çağırır. Eğer public method yoksa, gerekli tablodata'lara doğrudan Insert/Modify yaparız (table'lar Public ise).

## Workflow Events (subscribe edilebilir)

DOPSWHS Quality Mgmt Bridge'in subscribe edeceği MS QM events (workflow engine üzerinden):

- `A Quality Inspection is Created` — DOPSWHS Pick/Put-Away activity'ler etkilenebilir
- `A Quality Inspection is Finished` — sonuç result code'a göre lot/serial blocked olabilir

Yan tarafta:
- BCWMSApp `PickMgmt.RegisterPick` çağrısı block flag bulunan lot için "Lot blocked by QC inspection #INS-001" error fırlatır.
- Mobile/web error response parsing bu mesajı yakalar ve deep-link Quality Management modülüne yönlendirir (Sprint Q2/Q3).

## Premium License Guard

```al
local procedure IsPremiumExperience(): Boolean
var
    ApplicationAreaSetup: Record "Application Area Setup";
    ApplicationAreaMgmt: Codeunit "Application Area Mgmt.";
begin
    exit(ApplicationAreaMgmt.IsPremiumExperienceEnabled());
end;
```

Production-output trigger'lar bu guard arkasında olacak. Receiving + Assembly Essential'da bile çalışır.

## Verification Adımları (Q1 öncesi)

1. SandboxUS BC web client'ı aç → Tell Me → "Quality Management Setup" arat → page açılıyorsa QM yüklü ✓
2. AL VS Code'da `AL: Download symbols` ile QM symbol'unu çek
3. Çekilen `Microsoft_Quality Management_*.app` içinde `Quality Inspection` table'ının ID'sini ve `Extensible` bayrağını doğrula
4. Eğer table Extensible değilse — workflow-only entegrasyona pivot et (Sprint Q1 scope'u küçülür: sadece event subscriber)
5. Premium licence durumunu test et: production output bound action çağrıldığında 403/forbidden geldiyse Essential

## Sonraki Adım

Sprint Q1 — `al/src/QualityMgmt/` altında 4 API page + 1 bridge codeunit yazılır:
- `QualityInspectionApi.Page.al` (72076)
- `QualityTestApi.Page.al` (72077)
- `QualityTemplateApi.Page.al` (72078)
- `QualityResultApi.Page.al` (72079) — *not: bridge codeunit için ID çakışıyorsa 72080 kullanılır*
- `QualityMgmtBridge.Codeunit.al` (72080)

App version: v1.7.7.0 → v1.8.0.0.

## Kaynaklar

- https://learn.microsoft.com/dynamics365/business-central/qms-overview
- https://learn.microsoft.com/dynamics365/business-central/qms-setup
- https://learn.microsoft.com/dynamics365/business-central/qms-quality-workflows
- https://learn.microsoft.com/dynamics365/business-central/qms-lot-blocking-unblocking
- https://learn.microsoft.com/dynamics365/release-plan/2025wave2/smb/dynamics365-business-central/evaluate-quality-incoming-goods-materials
- https://learn.microsoft.com/dynamics365/release-plan/2026wave1/smb/dynamics365-business-central/evaluate-quality-incoming-goods-materials
