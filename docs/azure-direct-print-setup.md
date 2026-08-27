# Azure Direct Print — Sandbox Kurulum ve Test Kılavuzu

Bu, BCWMS için önerilen ana yazdırma yoludur. Azure Function, PrintNode aboneliği
ve ayrı bir veritabanı gerektirmez.

```text
El terminali / standart BC raporu
              |
              v
Business Central Print Job Queue
      | PDF/ZPL payload        | iş bilgisi + Station ID
      v                        v
private Azure Blob       Service Bus print-jobs-queue
                                  |
                                  v
                         Windows BCWMS Print Agent
                                  |
                                  v
                         Windows yazıcı sürücüsü
```

`Sent`, Windows spooler'ın işi kabul ettiği anlamına gelir.
Kağıdın fiziksel olarak çıktığını ancak gerçek yazıcı testi doğrular.

## Gerekenler

- Business Central sandbox'a extension yükleme yetkisi.
- Ayrı bir Azure sandbox aboneliği veya yalnız bu sisteme ayrılmış resource group.
- Azure CLI 2.60+ ve PowerShell 7+.
- Yazıcının bağlı olduğu, güncel destek alan Windows 11 x64 veya Windows Server
  2022/2025 x64 bilgisayar.
- Yazıcının üretici Windows sürücüsü.
- Bilgisayardan Azure'a outbound TCP 443 erişimi.

Bir Azure deployment yalnız bir BC environment + company içindir. Aynı company
altında birden fazla depo ve istasyon olabilir. İkinci company için ayrı resource
group/namespace kurun.

Aynı deployment içindeki istasyonlar tek güvenlik bölgesidir: Service Bus
`SessionId` routing sağlar fakat Azure yetkisi ayırmaz; ajanlar company stack'i
içinde aynı listen/send credential ve Blob read SAS'ını kullanır. Hassas
belgeleri birbirinden ayırmanız gerekiyorsa ayrı Azure stack kullanın. Mevcut v1
BC setup'ı tek AzureDirect stack/credential seti tuttuğu için station başına tam
credential izolasyonu ayrı bir v2 geliştirmesidir.

## 1. Paketleri hazırlayın

Windows CI/yayın makinesinde:

1. `al/` projesini BC 24/runtime 13 sembolleriyle derleyip `.app` üretin.
2. `windows-print-agent/scripts/publish-win-x64.ps1` ile self-contained
   `win-x64` ajan paketini üretin.
3. Üretilen dosyaların SHA-256 değerlerini yayın kaydına ekleyin.

macOS üzerinde oluşturulan bir AL paketi üretim yayın kanıtı sayılmaz. Son AL
derlemesini Windows AL araç zincirinde çalıştırın.

## 2. Azure kaynaklarını kurun

PowerShell 7 terminalinde Git kökü `WMS` altından:

```powershell
Set-Location ./direct-print-azure
az login
az account set --subscription '<SANDBOX-SUBSCRIPTION-ID>'

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

What-if çıktısını kontrol ettikten sonra aynı komutu `-WhatIfOnly` olmadan
çalıştırın. Ardından istasyon yapılandırmasını üretin:

```powershell
pwsh ./scripts/Initialize-Configuration.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -EnvironmentName 'sandbox' `
  -StationId 'DOPS.CONTOSO.MAIN.PACK01' `
  -BlobSasValidityDays 90
```

Station ID tam dört büyük-harfli segment olmalıdır:
`TENANT.COMPANY.WAREHOUSE.STATION`. İki bilgisayara aynı Station ID'yi vermeyin.

Komut iki ayrı, geçici secret dosyası üretir:

- `direct-print-azure/.local/business-central.runtime.secrets.json` yalnız
  BC'nin yükleme/gönderme yetkilerini içerir.
- `direct-print-azure/.local/print-agent.runtime.secrets.json` yalnız Windows
  ajanının okuma/dinleme yetkilerini içerir.

Dosyaları birbirinin hedefinde kullanmayın; içeriklerini terminale veya CI
loguna yazdırmayın.

Azure kaynak ve credential kontrollerini çalıştırın:

```powershell
pwsh ./scripts/Test-Infrastructure.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox' `
  -EnvironmentName 'sandbox'

pwsh ./scripts/Test-Credentials.ps1 `
  -SubscriptionId '<SANDBOX-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-dopwms-print-sandbox'
```

İki test de başarılı olmadan BC secret importuna geçmeyin.

## 3. AL extension'ı Sandbox'a yükleyin

1. BC Sandbox'ta **Extension Management** sayfasını açın.
2. **Upload Extension** ile yeni `.app` paketini yükleyin.
3. Şema eşitleme ve kurulum tamamlanana kadar bekleyin.
4. Yüklenen extension için **Configure** sayfasında **Allow HttpClient
   Requests** seçeneğini etkinleştirin. Bu izin olmadan BC, Blob Storage ve
   Service Bus'a çıkamaz.
5. İlgili yöneticiye `DOPSWHS-ADMIN`, terminal servis kullanıcısına
   `DOPSWHS-USER` izin setini atayın.
6. **Advanced WMS Setup** sayfasını açın.
7. **Import BC Azure Print Config** aksiyonunda
   `business-central.runtime.secrets.json` dosyasını seçin.
8. Görünen secret olmayan değerleri doğrulayın:
   - Print Channel: `Azure Direct (Blob + Service Bus)`
   - Tenant Route ID: `DOPS`
   - Company Route ID: `CONTOSO`
   - Print Jobs Queue: `print-jobs-queue`
   - Printer Status Queue: `printer-status-queue`
   - Blob Container: `print-jobs`
9. **Validate Azure Print** aksiyonunu çalıştırın.

BC, Service Bus ve Blob secret'larını company kapsamlı Isolated Storage'da
tutar. Setup tablosunda veya AL kaynak kodunda düz metin secret tutulmaz.

## 4. Windows ajanını kurun

1. Ajan ZIP'ini, klasör yapısını değiştirmeden yazıcının bağlı olduğu Windows
   x64 bilgisayara açın.
2. Üretici yazıcı sürücüsünü kurun ve önce Windows **Test Page** yazdırın.
3. Normal kullanıcı PowerShell'inde çıkarılan paketin üst klasöründen doğrulamalı
   ve atomik installer'ı çalıştırın:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\BCWMS-Print-Agent-win-x64\installer\install.ps1
   ```

4. Otomatik açılan panelde **Print Agent Secrets İçe Aktar** ile yalnız
   `print-agent.runtime.secrets.json` dosyasını seçin.
5. **Yazıcıları Yenile** düğmesine basın.
6. Ayrı seçimlerden:
   - yerleşik LP/ürün/raf etiketleri için **Etiket Yazıcısı** ve format `ZPL`,
   - PDF için **Belge Yazıcısı** seçin.
7. **Ayarları Kaydet ve Bağlan** düğmesine basın. Etiket yolu Windows RAW
   spooler kullanır; USB veya ağ yazıcısı önce üretici sürücüsüyle Windows'a
   yazıcı kuyruğu olarak kurulmuş olmalıdır.
8. Station ID beklenen değer olmalıdır. İlk cloud işi öncesi
   **Listen doğrulaması için smoke job bekleniyor**, başarılı smoke sonrasında
   **Azure kuyruğu dinleniyor** durumu beklenir.
9. **Etiket Testi** ve **Belge Testi** düğmeleriyle yerel baskıyı ayrı ayrı
    doğrulayın.

Ajan secret'ları Windows DPAPI `CurrentUser` kapsamında şifreler. Ajanı her
zaman aynı Windows kullanıcısıyla çalıştırın. Uygulamayı kapatma düğmesi tray'e
küçültür; gerçek çıkış için tray menüsündeki **Çıkış** komutunu kullanın.

Agent importu ve kaydı tamamlandıktan sonra agent secret dosyası silinebilir.
`business-central.runtime.secrets.json`, bir sonraki Azure smoke komutunun
varsayılan credential girdisidir; smoke tamamlanana kadar güvenli yerde tutun.

## 5. Önce Azure smoke testini çalıştırın

Tek sayfalık güvenli bir test PDF'i hazırlayın. Ajan ekranındaki `P` + 16 hex
karakterli printer ID'yi kullanın:

```powershell
Set-Location ./direct-print-azure
pwsh ./scripts/Send-SmokeTest.ps1 `
  -PrinterId 'P0123456789ABCDEF' `
  -PrinterName 'HP LaserJet Warehouse A4' `
  -Format PDF `
  -Copies 1 `
  -FilePath 'C:\Test\single-page.pdf'
```

Beklenen sonuç:

- Service Bus jobs queue `Active Messages` kısa süre artıp sıfıra döner.
- DLQ artmaz.
- Ajan logunda job ID ve “spool kabul edildi” görünür.
- Seçilen fiziksel yazıcıdan çıktı oluşur. İlk cloud smoke testinde dosya seçme
  penceresi açabilen `Microsoft Print to PDF` sürücüsünü kullanmayın.
- Bu komut BC dışında doğrudan Azure işi oluşturduğu için BC **Print Job Queue**
  satırı ve `Sent` durumu üretmez. BC status worker çalışıyorsa doğrulanmış test
  sonucunu “yerel BC işi olmayan smoke sonucu” telemetrisiyle tamamlar; status
  DLQ artmaz. BC `Sent` geçişi 6. bölümdeki terminal/standart rapor testinde
  doğrulanır.

Smoke tamamlandıktan sonra iki geçici secret dosyasını güvenli biçimde silin
veya kurumsal secret store'a taşıyın. Scripti başka konumdaki güvenli bir BC
secret kopyasıyla çalıştıracaksanız `-SecretsPath` parametresini açıkça verin.

## 6. Terminal ve standart BC testleri

1. BC **Printers** sayfasında ajan tarafından keşfedilen PDF ve etiket
   yazıcılarını kontrol edin; Station ID doğru olmalıdır.
2. Gerekirse **Device Printer Mapping** ile usage/istasyon eşlemesini yapın.
3. El terminalinde **Yazıcılar** ekranını açın:
   - etiket varsayılanı olarak ZPL yazıcıyı,
   - belge varsayılanı olarak PDF yazıcıyı seçin.
4. Sırasıyla LP, ürün ve raf etiketi basın.
5. Mal kabul/sevkiyat post işlemini “yazdır” seçeneğiyle çalıştırın.
6. Paket fişi testini çalıştırın.
7. Standart BC raporlarında özel medya gerekiyorsa PDF yazıcısının **Printer
   Card** sayfasında **Paper Width (mm)** ve **Paper Height (mm)** alanlarının
   ikisini de gerçek ölçüyle doldurun; ikisi de `0` ise A4 üretilir. Aynı özel
   medya ölçüsünü Windows üretici sürücüsünde de tanımlayın.
8. BC **Printer Selections** sayfasında bir standart raporu
   `DOPSWHS::<printer-code>` sanal yazıcısına bağlayıp raporu basın.
9. **Print Job Queue** üzerinde her işin `Queued → Dispatched → Sent` geçişini,
   payload boyutunu, Station ID'yi ve correlation ID'yi doğrulayın.

## 7. Zorunlu arıza testleri

- Ajan kapalıyken iş gönderin; ajan açılınca yalnız bir kez basılmalı.
- Ajanı hafta sonunu temsil edecek şekilde birkaç gün kapalı bırakma testinde iş
  7 günlük queue TTL içinde korunmalı; 7 günü aşan iş DLQ'ya düşer ve otomatik
  yeniden baskı yapılmaz.
- Aynı job ID'yi tekrar gönderin; duplicate detection/journal ikinci baskıyı
  önlemeli.
- Yanlış Station ID ile ajan işi almamalı.
- Kontrollü test yazıcısı kuyruğunu Windows'tan kaldırın; iş `Failed`/DLQ olmalı
  ve hata metni secret içermemeli. Yalnız cihazı offline yapmak yeterli bir hata
  testi değildir; Windows spooler offline kuyruğa işi kabul edebilir.
- Status queue geçici kapalıyken fiziksel baskı sonrası JobResult disk outbox'ta
  kalmalı ve bağlantı gelince BC'ye ulaşmalı.
- Geçersiz SHA-256 veya farklı blob path mesajı fiziksel baskıdan önce
  reddedilmeli.

## 8. Canlıya geçiş kriteri

Aşağıdakilerin tamamı kanıtlanmadan “canlıya hazır” demeyin:

- Azure altyapı ve credential testleri başarılı.
- Windows ajan build/test/publish başarılı.
- Hedef Windows makinede yerel PDF ve ZPL testi başarılı.
- Terminalde LP/ürün/raf + en az bir belge baskısı başarılı.
- Standart BC raporu sanal yazıcıdan başarılı.
- Ajan kapalı/açık, duplicate ve offline printer testleri başarılı.
- Queue/DLQ/Blob retention alarm ve sorumluları tanımlı.

Azure ayrıntıları, credential rotasyonu ve teardown komutları için
[`direct-print-azure/README.md`](../direct-print-azure/README.md) belgesine bakın.
Eski Function/Go ajan yolu gerekiyorsa
[`print-bridge-setup.md`](print-bridge-setup.md) belgesinde `SelfHosted` kanal adıyla
ayrı bir uyumluluk seçeneği olarak tutulur.
