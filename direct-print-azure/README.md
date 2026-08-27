# BC WMS Direct Azure Print

Bu klasör, Business Central ile Windows print agent arasındaki doğrudan ve dağıtımı kolay Azure katmanını kurar. Azure Function veya ayrı veritabanı yoktur.

> **Routing sınırı:** Bir deployment/namespace yalnız **bir BC environment + bir company** içindir; aynı company altında birden fazla depo ve istasyon olabilir. `printer-status-queue` non-session olduğu için aynı kuyruğu birden fazla BC environment/company dinlerse competing consumer oluşur ve durum mesajı yanlış BC tarafından alınabilir. İkinci company için ayrı resource group/namespace deploy edin. Gelecekte ortak namespace gerekirse status tarafı session-enabled veya company başına queue olarak yeniden tasarlanmelidir.

> **Güvenlik sınırı:** Aynı deployment içindeki istasyonlar tek güvenlik bölgesidir.
> Service Bus SAS, `SessionId` bazında yetki sınırlandıramaz; bütün ajanlar aynı
> queue-level Listen/Send credential'ını ve aynı container-level read SAS'ını
> kullanır. Normal ajan yalnız yapılandırılmış exact session/body/blob yolunu
> kabul eder, fakat ele geçirilmiş bir ajan credential'ı aynı company stack'indeki
> diğer istasyonların mesaj ve payloadlarına erişebilir. Ayrı güvenlik sınırı
> gereken hassas istasyon/company için ayrı Azure stack kullanın. Station başına
> queue/container credential eşlemesi v1 kapsamı dışındadır.

```text
Business Central
  ├─ PDF/ZPL → private Blob container (create+write SAS)
  └─ job metadata → session-enabled Service Bus queue (send-only SAS)
                                      │ SessionId = StationId
                                      ▼
Windows print agent
  ├─ payload ← private Blob container (read-only SAS)
  └─ result → status queue (send-only SAS)
                                      │
                                      ▼
Business Central status worker (listen-only SAS)
```

## Kurulan kaynaklar

| Kaynak | Ayar |
|---|---|
| StorageV2 | LRS, private container, HTTPS-only, TLS 1.2 |
| `print-jobs` | PDF/ZPL payloadları; anonim erişim kapalı |
| Blob lifecycle | Varsayılan 14 gün sonra payload silme; 7 gün soft-delete koruması |
| Service Bus | Standard SKU, TLS 1.2 |
| `print-jobs-queue` | Session zorunlu, duplicate detection, 7 gün TTL, 10 denemeden sonra DLQ |
| `printer-status-queue` | Session yok, duplicate detection, 7 gün TTL, 10 denemeden sonra DLQ |
| Log Analytics | İsteğe bağlı; Service Bus operasyon/hata logları, Blob read/write/delete logları ve metrikler |

Service Bus yetkileri namespace seviyesinde değil, kuyruk seviyesindedir:

- BC: yalnız `print-jobs-queue` gönderme ve `printer-status-queue` dinleme.
- Agent: yalnız `print-jobs-queue` dinleme ve `printer-status-queue` gönderme.
- BC Blob SAS: yalnız create+write (`cw`).
- Agent Blob SAS: yalnız read (`r`).
- Uygulamalar `RootManageSharedAccessKey` kullanmaz.

## Ön koşullar

- Ayrı bir Azure sandbox aboneliği veya sandbox kaynak grubu.
- Azure CLI 2.60+ ve PowerShell 7+.
- Kaynak grubu oluşturma/dağıtım ve Storage/Service Bus anahtarlarını listeleme yetkisi (`Contributor` bunun için yeterlidir).
- BC sandbox extension ve Windows agent kurulumu için ayrı yetkiler.
- Agent bilgisayarından ve BC'den dışarı doğru TCP 443. Agent Service Bus için
  AMQP-over-WebSockets, BC ise Service Bus ve Blob HTTPS REST kullanır; doğrudan
  5671 açılması gerekmez.

Komutları Git kökü `WMS` altından bu klasöre geçerek çalıştırın:

```powershell
Set-Location ./direct-print-azure
az login
az account set --subscription '<SANDBOX-SUBSCRIPTION-ID>'
```

## 1. Azure what-if ve dağıtım

Dağıtım için yalnız bu sisteme ait boş/dedicated bir kaynak grubu kullanın. Script, başka bir uygulamaya ait mevcut kaynak grubuna dağıtımı reddeder.

```powershell
pwsh ./scripts/Deploy.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -NamePrefix 'dopwms' `
  -TenantId 'DOPS' `
  -CompanyId 'CONTOSO' `
  -EnvironmentName 'sandbox' `
  -Location 'westeurope' `
  -WhatIfOnly
```

`WhatIfOnly`, subscription-scope wrapper üzerinden kaynak grubunun oluşturulmasını da önizler ve hiçbir Azure kaynağını değiştirmez. Çıktıyı kontrol ettikten sonra gerçek dağıtım:

```powershell
pwsh ./scripts/Deploy.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -NamePrefix 'dopwms' `
  -TenantId 'DOPS' `
  -CompanyId 'CONTOSO' `
  -EnvironmentName 'sandbox' `
  -Location 'westeurope'
```

Bicep hiçbir secret output üretmez. `TenantId.CompanyId` deployment tag/output değerine sabitlenir; bootstrap farklı company'ye ait Station ID'yi reddeder. Global isimler prefix, ortam ve deterministic unique suffix ile geçerli Azure isimlerine dönüştürülür.

Buradaki `TenantId` ve `CompanyId`, AAD/Entra GUID değerleri değil; WMS routing için seçilen 1-32 karakterlik canonical büyük harf kodlarıdır (örnek `DOPS` ve `CONTOSO`).

## 2. Station ID ve scoped credential üretimi

Station ID, Service Bus `SessionId` değeridir. Tek namespace içinde global olarak benzersiz olmalıdır. Önerilen format:

```text
TENANT.COMPANY.WAREHOUSE.STATION
DOPS.CONTOSO.MAIN.PACK01
```

Tam dört segment zorunludur: ilk segment `tenantId`, ikinci segment `companyId`, üçüncü segment `warehouseId`, dördüncü segment `stationCode` olur. Her segment 1-32 büyük harf, rakam, `_` veya `-` içerebilir; toplam uzunluk en fazla 128'dir. Nokta yalnız segment ayırıcıdır. İki agent aynı Station ID ile çalıştırılırsa competing consumer olurlar ve işler öngörülemeyen bilgisayara gider.

Aynı deployment içindeki bütün Station ID değerleri aynı `TENANT.COMPANY` ilk iki segmentini kullanmalıdır. Farklı company için aynı status queue paylaşılmaz.

```powershell
pwsh ./scripts/Initialize-Configuration.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -EnvironmentName 'sandbox' `
  -StationId 'DOPS.CONTOSO.MAIN.PACK01' `
  -BlobSasValidityDays 90
```

Script şunları yapar:

1. Dört queue-level Service Bus connection string'ini alır.
2. `bc-upload` ve `agent-read` adlı, süreli ve iptal edilebilir Blob stored access policy oluşturur/günceller.
3. Storage account anahtarını yalnız process belleğinde/environment'ında kullanır; dosyaya veya konsola yazmaz.
4. Yalnız BC yetkilerini içeren
   `.local/business-central.runtime.secrets.json` dosyasını oluşturur.
5. Yalnız Windows ajanı yetkilerini içeren
   `.local/print-agent.runtime.secrets.json` dosyasını oluşturur.
6. İki secret dosyasının erişimini mevcut kullanıcıyla sınırlar ve secret
   içermeyen `.local/client-config.template.json` üretir.

`.local/` gitignore kapsamındadır. Yine de bu JSON dosyaları kalıcı secret
deposu değildir. BC dosyasını yalnız BC'ye, agent dosyasını yalnız hedef Windows
bilgisayarına aktarın. Agent dosyasını agent importundan sonra silebilirsiniz;
BC dosyasını `Send-SmokeTest.ps1` varsayılan olarak kullandığı için Azure smoke
tamamlanana kadar güvenli yerde tutun ve ancak sonra silin. Kurumsal ortamda
PowerShell SecretStore veya Azure Key Vault gibi onaylı bir secret store
kullanın.

Credential eşlemesi:

| Hedef | Secret alanları |
|---|---|
| BC | `businessCentral.printJobsSendConnectionString`, `printerStatusListenConnectionString`, `blobContainerUrl`, `blobCreateWriteSasToken` |
| Windows agent | `agent.printJobsListenConnectionString`, `printerStatusSendConnectionString`, `blobAccountName`, `blobContainerName`, `blobReadSasToken` |

Script hiçbir connection string veya SAS token'ı konsola yazmaz. CI loglarına
iki secret dosyasından birinin içeriğini basmayın.

## 3. Azure doğrulaması

Kaynak ayarları ve dört least-privilege policy:

```powershell
pwsh ./scripts/Test-Infrastructure.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -EnvironmentName 'sandbox'
```

Blob SAS izinleri ve yüklenen/indirilen byte bütünlüğü:

```powershell
pwsh ./scripts/Test-Credentials.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox'
```

İkinci test geçici bir Blob yükler, BC token'ıyla read işleminin ve agent token'ıyla write işleminin reddedildiğini doğrular, SHA-256 karşılaştırır ve test Blob'unu siler. Temizlik başarısız olursa lifecycle kuralı Blob'u süresi sonunda kaldırır.

## 4. BC sandbox ve agent uçtan uca testi

BC ve agent aynı değerleri kullanmalıdır:

- Queue adları: `print-jobs-queue`, `printer-status-queue`.
- Container: `print-jobs`.
- Station ID: tam ve büyük/küçük harf dahil birebir aynı.
- Service Bus transport: Windows agent `AmqpWebSockets`; BC worker HTTPS REST.
- TLS: en az 1.2; sertifika doğrulamasını kapatmayın.

İş mesajında SAS veya kullanıcıdan gelen URL bulunmaz. Mesaj sözleşmesi:

```json
{
  "schemaVersion": 1,
  "jobId": "11111111-2222-3333-4444-555555555555",
  "tenantId": "DOPS",
  "companyId": "CONTOSO",
  "stationId": "DOPS.CONTOSO.MAIN.PACK01",
  "printerId": "P0123456789ABCDEF",
  "printerName": "HP LaserJet Warehouse A4",
  "format": "PDF",
  "copies": 1,
  "blobName": "jobs/DOPS.CONTOSO.MAIN.PACK01/11111111-2222-3333-4444-555555555555.pdf",
  "payloadSha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  "payloadSize": 12345,
  "createdAtUtc": "2026-08-11T10:00:00Z"
}
```

Service Bus özellikleri:

- `SessionId = stationId`, `MessageId = jobId`, `CorrelationId = jobId` ve `ContentType = application/json` zorunlu.
- Agent yalnız kendi exact session'ını kabul eder.
- Agent Blob URL'yi kendisi, provision edilen account/container allowlist ve read-only SAS ile oluşturur.
- `..`, slash ile başlayan path, foreign host/container ve geçersiz SHA-256 reddedilir.
- Başarılı iş `Complete`; geçici hata `Abandon`; kalıcı/geçersiz mesaj `DeadLetter` yapılır.
- `printerId`, agent UI'da yazıcının yanında görünen kalıcı logical ID'dir ve tam `P` + 16 büyük hexadecimal karakter olmalıdır. ID, aynı agent profilinde aynı Windows yazıcı kuyruğu adı için korunur; Windows kuyruğunun adı değişirse agent bunu yeni bir yazıcı olarak görür ve yeni ID üretir.

Status kuyruğundaki bütün v1 mesajların ortak alanları şunlardır:

```json
{
  "schemaVersion": 1,
  "messageType": "PrinterSnapshot | Heartbeat | JobResult",
  "messageId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "tenantId": "DOPS",
  "companyId": "CONTOSO",
  "stationId": "DOPS.CONTOSO.MAIN.PACK01",
  "agentId": "11111111-2222-3333-4444-555555555555",
  "sentAtUtc": "2026-08-11T10:00:00Z",
  "agentVersion": "1.0.0"
}
```

Mesaj tipine özel alanlar:

- `PrinterSnapshot`: `printers[]` içinde `printerId`, `printerName`, `format`, `status`, `isDefault`; `selection` içinde `labelPrinterId`, `documentPrinterId`, `labelTransport`.
- `Heartbeat`: `status` ve nullable `lastJobId`.
- `JobResult`: `jobId`, `printerId`, `printerName`, `format`, `success`, en fazla 500 karakter `message`, `completedAtUtc`, `attempt`.

Status mesajına secret, connection string, SAS veya dosya içeriği konulmaz. Service Bus message subject `messageType`; JobResult correlation ID `jobId`, diğerlerinde `agentId` olur. Application properties içinde `schemaVersion`, `messageType`, `tenantId`, `companyId`, `stationId` bulunur.

BC'yi devreye almadan önce JSON ve dosya kontrollerini dry-run ile doğrulayın:

```powershell
pwsh ./scripts/Send-SmokeTest.ps1 `
  -DryRun `
  -StationId 'DOPS.CONTOSO.MAIN.PACK01' `
  -PrinterId 'P0123456789ABCDEF' `
  -PrinterName 'Microsoft Print to PDF' `
  -Format PDF `
  -FilePath 'C:\Test\single-page.pdf'
```

Agent açıkken aynı testi gerçek Blob + Service Bus üzerinden gönderin:

```powershell
pwsh ./scripts/Send-SmokeTest.ps1 `
  -PrinterId 'P0123456789ABCDEF' `
  -PrinterName 'HP LaserJet Warehouse A4' `
  -Format PDF `
  -Copies 1 `
  -FilePath 'C:\Test\single-page.pdf'
```

Script BC'nin scoped credential'ını kullanır, payload SHA-256 ve boyutunu hesaplar, Blob'a yükler ve exact v1 job mesajını ilgili session'a gönderir. `-JobId '<GUID>'` verilirse aynı stable `MessageId` ile duplicate-detection testi yapılabilir. SAS veya connection string konsola yazılmaz. Agent çalışmıyorsa iş queue'da bekler; yüklenen Blob lifecycle ile temizlenir.

Bu raw Azure smoke işi BC tablosunda oluşturulmaz. Agent'ın `JobResult` mesajı,
BC status worker açıksa bütün v1/ownership alanları doğrulandıktan sonra “yerel
BC işi olmayan smoke sonucu” telemetrisiyle tamamlanır; BC'de `Sent` satırı
beklenmez. `Sent`, aşağıdaki gerçek BC/terminal işiyle ayrıca doğrulanır. Smoke
tamamlandıktan sonra `.local` altındaki geçici BC secret dosyasını silin veya
onaylı secret store'a taşıyın.

Fiziksel sandbox testi:

1. Windows'ta yazıcının üretici sürücüsünü kurun ve Windows test sayfası basın.
2. Agent ZIP'indeki `installer\install.ps1` dosyasını normal kullanıcıyla
   çalıştırın; açılan panelde **Print Agent Secrets İçe Aktar** ile üretilen
   `print-agent.runtime.secrets.json` dosyasını seçin.
3. Yazıcıları yenileyin, PDF belge yazıcısını ve yerleşik WMS etiketleri için
   ZPL etiket yazıcısını seçin; **Ayarları Kaydet ve Bağlan** ile secret'ları
   Windows DPAPI'ye taşıyın. İlk cloud işi öncesi **Listen doğrulaması için smoke
   job bekleniyor**, sonrasında **Azure kuyruğu dinleniyor** olmalıdır. Ardından
   kaynak agent secret dosyasını güvenli şekilde silin.
4. Önce yukarıdaki raw Azure smoke işini gönderin. Queue Active Message kısa
   süre artıp sıfıra dönmeli, fiziksel çıktı oluşmalı ve DLQ artmamalıdır; bu iş
   BC `Sent` satırı üretmez.
5. Sonra BC/terminalden tek sayfalık PDF test işi gönderip fiziksel çıktıyı ve BC
   `Queued → Dispatched → Sent` durumunu doğrulayın.
6. Aynı `jobId` ile tekrar gönderip duplicate detection nedeniyle ikinci fiziksel çıktının oluşmadığını doğrulayın.
7. Agent'ı kapatın, bir iş gönderin, yeniden açın; bekleyen iş çıkmalı.
8. Yanlış Station ID ile agent'ın işi almadığını doğrulayın.
9. Kontrollü bir test yazıcısını Windows'tan geçici kaldırarak `Failed`
    durumunu ve hata kodunu doğrulayın. Mesajdaki yazıcı adını elle değiştirerek
    test yapmak agent allowlist doğrulamasına takılır.
10. Etiket yazıcısında ZPL, belge yazıcısında PDF testini ayrı ayrı tamamlayın.

Standart BC raporunda özel kâğıt kullanılacaksa PDF yazıcısının BC **Printer
Card** sayfasında **Paper Width (mm)** ve **Paper Height (mm)** değerlerinin
ikisini de ayarlayın; ikisi `0` olduğunda A4 kullanılır. Aynı ölçü Windows
sürücüsünde custom media olarak tanımlanmalıdır.

Azure kaynak testi fiziksel yazıcının sürücüsünü veya kâğıt ayarını doğrulayamaz. Canlıya geçiş koşulu, bu on maddenin hedef Windows bilgisayarı ve gerçek yazıcılarla geçmesidir.

## İzleme

Azure Portal'da şu metrikleri alarm için kullanın:

- Service Bus `Active Messages`, `Dead-lettered Messages`, `Incoming Messages`, `Server Errors`, `User Errors`.
- Storage `Transactions`, `Availability`, `Success E2E Latency`.
- Agent yerel loglarında `jobId`/`stationId`; PDF/ZPL içeriği ve SAS asla loglanmamalıdır.

DLQ sıfır değilse mesajı otomatik silmeyin; hata kodu ve delivery count incelendikten sonra kontrollü replay yapın.

## Credential yenileme

Blob SAS süresi dolmadan `Initialize-Configuration.ps1` yeniden çalıştırılabilir. Yeni dosyayı önce BC/agent'a dağıtıp bağlantıyı doğrulayın. Service Bus policy key rotasyonunda primary/secondary anahtarı sırayla yenileyerek kesintisiz geçiş yapın; iki anahtarı aynı anda yenilemeyin.

Bir secret açığa çıktıysa yalnız dosyayı silmek yeterli değildir: ilgili queue authorization-rule key'ini yenileyin veya Blob stored access policy'yi iptal edip yeniden oluşturun.

## Sandbox kaldırma

Script yalnız `managedBy=direct-print-azure` ve `application=bc-wms-direct-print` tag'leri bulunan dedicated kaynak grubunu siler. Resource group adını ikinci kez, birebir yazarak onaylamak zorunludur:

```powershell
pwsh ./scripts/Remove-Environment.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -ConfirmResourceGroupName 'rg-dopwms-print-sandbox' `
  -Wait
```

Bu işlem Blob payloadları, kuyruklar, DLQ mesajları ve log workspace dahil kaynak grubundaki her şeyi kalıcı olarak siler. Önce gerekli teşhis kayıtlarını dışarı aktarın.

## Maliyet notu

Service Bus **Standard** namespace sabit taban ücret ve mesajlaşma operasyonları doğurur. Storage kapasite/transaction/egress, Log Analytics ise ingest ve retention üzerinden ayrıca ücretlenir. Düşük hacimde bile Standard namespace taban ücreti vardır; en değişken kalem çoğunlukla diagnostik log ingestidir. Kısa süreli sandbox'ta `-EnableDiagnostics $false` seçilebilir, ancak hata analizi zayıflar. Fiyatlar bölgeye ve tarihe göre değiştiği için canlıya geçmeden Azure Pricing Calculator ile güncel abonelik fiyatını hesaplayın.

## Yerel doğrulama

Bicep şablonunu Azure'a bağlanmadan derlemek için:

```powershell
az bicep build --file ./infra/main.bicep --outfile ./build/main.json
```

ARM deployment validation için Azure login gerekir; `Deploy.ps1 -WhatIfOnly` bunu gerçek subscription ve region üzerinde yapar.

Kaynaklar: [Service Bus queues](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-queues-topics-subscriptions), [message sessions](https://learn.microsoft.com/azure/service-bus-messaging/message-sessions), [Service Bus SAS](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-sas), [Blob SAS](https://learn.microsoft.com/azure/storage/common/storage-sas-overview), [diagnostic settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings), [lifecycle management](https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview).
