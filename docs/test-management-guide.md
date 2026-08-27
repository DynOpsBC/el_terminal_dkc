# BCWMSApp Test Center — Kullanım Kılavuzu

> **Sandbox:** <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central>
> **Versiyon:** v1.0.3.0
> **Rol:** `DynOps Warehouse Management`

## Genel Bakış

Test Center, **50 uçtan uca test case**'i çoklu ortam (Dev/Test/UAT/Pre-Prod/Production) ve çoklu kullanıcı grubu (Dev/QA/Business) ortamlarında **otomatik koşturup** sonuçları tablo bazlı tutan bir mini test yönetim sistemidir.

**Test Center'a erişim:**

- Role Center → **🧪 Test Center** action group veya
- Cue group: Total Cases, Test Run Adedi, Toplam PASS, Manuel Bekleyen, Failed Adedi, Aktif Environment, Aktif Kullanıcı Grubu

## 3 Adımda Kurulum

### 1. Test Catalog'u Seed Et (Tek Sefer)

Role Center → **⚡ Setup Test Catalog** action

Sonuç:

- **50 Test Case** seed edilir (Section A-H)
- **5 Environment**: DEV, TEST, UAT, PREPROD, PROD
- **3 User Group**: DEV-TEAM, QA-TEAM, BUSINESS-USERS

### 2. E2E Test Data Hazırla (Tek Sefer)

Role Center → **📦 Setup E2E Test Data** action

Cronus'ta eksik master data (test items, prod components, demo PO/SO) auto-create.

### 3. İlk Test Run'ı Başlat

1. Role Center → **📋 Test Run List** action
2. **+ New Test Run** butonu → otomatik TR-000001 oluşur (Env=TEST, Group=QA-TEAM)
3. Yeni Run satırı aç → **▶ Start Run** butonu
4. ~30-60 saniye içinde 50 case tamamlanır

## Test Yönetim Tabloları

| Tablo | Açıklama |
|---|---|
| **Test Case (T 72028)** | 50 case catalog — section, surface, automation type, codeunit ID, procedure name |
| **Test Environment (T 72029)** | Ortam meta (DEV/TEST/UAT/PREPROD/PROD) |
| **Test User Group (T 72030)** | Kullanıcı grubu (DEV-TEAM/QA-TEAM/BUSINESS-USERS) |
| **Test User Group Member (T 72031)** | n:n grup-üye eşlemesi |
| **Test Run (T 72032)** | Bir koşum header'ı — Run No, Env, Group, Status, Pass/Fail/Pending sayıları |
| **Test Run Result (T 72033)** | Per-case sonuç — Pass/Fail/Skip/PendingManual, Error Message, Duration ms, Surrogate Used |

## 50 Test Case Section Dağılımı

| Section | Case Sayısı | Konu |
|---|---|---|
| **A** | 5 | Kurulum + Profile Doğrulama (TC-001 to TC-005) |
| **B** | 10 | License Plate Core — KRİTİK (TC-006 to TC-015) |
| **C** | 8 | Mal Kabul Uçtan Uca (TC-016 to TC-023) |
| **D** | 10 | Picking + Shipping (TC-024 to TC-033) |
| **E** | 3 | Hareketler / Movements (TC-034 to TC-036) |
| **F** | 4 | Inventory Count (TC-037 to TC-040) |
| **G** | 5 | Üretim + Montaj (TC-041 to TC-045) |
| **H** | 5 | Sistem + SPA + API (TC-046 to TC-050) |

**Kritik case'ler** (PASS olması zorunlu):

- TC-013 — Bin Content nested LP rollup = 100 (çift sayım yok)
- TC-036 — Batch isolation (2 user → ayrı journal batch)
- TC-038 — Multi-counter variance (3-slot recount)

## Otomasyon Tipleri

| Tip | Açıklama |
|---|---|
| **Auto** | %100 otomatik — Test Runner direkt AL procedure'ı çağırır, Pass/Fail döner |
| **Surrogate** | SPA/Mobile UI testleri — AL'de eşdeğer codeunit çağrılarak simulate edilir, `Surrogate Used` field'ı işaretlenir |
| **Manual** | Sadece insan gözüyle doğrulanabilir — Run sonrası `Status=PendingManual`, kullanıcı manuel "Mark Passed/Failed" yapar |

50 case'in mevcut dağılımı:

- Auto: ~42 case
- Surrogate: ~7 case (TC-015 LP Browser SPA, TC-018 GS1-128, TC-029 Pick Queue SPA, TC-049 Webhook, TC-050 LP tree)
- Manual: 0 case (max otomasyon yaklaşımı)

## Multi-Environment + Multi-User-Group

**Önemli:** BC AL codeunit'ları sadece deploy edildikleri tenant/environment'ta çalışır. Multi-environment anlamı:

1. Aynı `.app` paketi 5 environment'a (DEV/TEST/UAT/PREPROD/PROD) deploy edilir
2. Her environment kendi Test Run records'unu tutar
3. Test Run header'ında `Environment Code` ve `User Group Code` etiket olarak işaretlenir (rapor + filtre için)
4. Power BI report'la 5 environment'tan veri aggregate edilebilir (opsiyonel)

## Test Run İş Akışı

```
1. + New Test Run → otomatik TR-000001 oluşur, Status=Open
2. ▶ Start Run → Status=Running, her case sırayla:
   - Result satırı oluştur (Status=Running)
   - Test Runner → ilgili Auto codeunit Dispatch
   - Pass → Status=Passed + Duration ms
   - Fail → Status=Failed + Error Message
   - Surrogate kullanılırsa Surrogate Used=true
3. Tüm case'ler tamamlanınca:
   - Status=Completed (hepsi Passed)
   - Status=PartialPass (bazıları Failed)
   - Status=Failed (kritik fail)
4. Result Lines part'ında badge'lerle görüntü:
   - ✅ Favorable (Passed)
   - ❌ Unfavorable (Failed)
   - ⚠️ Attention (PendingManual)
   - 🔘 Subordinate (Skipped)
5. 🔁 Re-run Failed Only → sadece fail'leri tekrar dene
```

## Action'lar

### Test Run Card

- **▶ Start Run** — tüm aktif case'leri sırayla çalıştır (~30-60 sn)
- **🔁 Re-run Failed Only** — sadece Failed'leri tekrar çalıştır
- **✓ Mark All Pending Manual as Passed** — (admin) tüm PendingManual'ları toplu onayla

### Test Run Result Lines

- **Mark Passed** — bir case'i manuel Passed işaretle (sadece PendingManual için)
- **Mark Failed** — bir case'i manuel Failed işaretle
- **Run This Case** — tek bir case'i yeniden çalıştır (debug için)

## Hızlı Feedback: Test Center Cue Group

Role Center → 🧪 Test Center cue panel:

- **Toplam Test Case** — Active test case sayısı (50)
- **Test Run Adedi** — şu ana kadar koşturulmuş run sayısı
- **Toplam PASS** — birikmiş Passed result sayısı
- **Manuel Bekleyen** — PendingManual sayısı (manuel onay bekleyen)
- **Failed Adedi** — birikmiş Failed sayısı
- **Aktif Environment** — Active environment sayısı (5)
- **Aktif Kullanıcı Grubu** — Active group sayısı (3)

## Sandbox URL'leri (Doğrudan Açılır)

| Sayfa | URL |
|---|---|
| **🧪 Role Center** | <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central&page=72095> |
| **Test Run List** | <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central&page=72242> |
| **Test Case Catalog** | <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central&page=72240> |
| **Test Environments** | <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central&page=72245> |
| **Test User Groups** | <https://businesscentral.dynamics.com/7fa2357e-26f2-4174-8e16-a713981356b8/CustomerSandbox?company=Demo%20Business%20Central&page=72246> |

## Sorun Çıkarsa

| Sorun | Çözüm |
|---|---|
| "Test Case yok" mesajı | Setup Test Catalog action'ını çalıştırın |
| "Cronus master data yok" mesajı | Setup E2E Test Data action'ını çalıştırın |
| Start Run hata veriyor | Result Lines'da Error Message'a bakın; ilgili case'in automation codeunit'unu kontrol edin |
| Surrogate cases'lar Manual Verification gerektiriyor | Mobile/Web SPA'da gerçek cihazda test edin; Pass ise Result Lines'da "Mark Passed" |

## AppSource ve Production Hazırlığı

v1.0.3.0 production-ready durumda:

- ✅ 4 audit script PASS (permissions, prefix, translation, obsolete)
- ✅ 50 test case auto-runner
- ✅ Multi-environment + multi-user-group altyapı
- ✅ Persistent table'lar (Test Run history, Result audit trail)
- ⚠️ AppSource submission için: Logo (240x240), Production Documentation/Privacy/License URL'leri, App Insights production connection
