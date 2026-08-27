# BADE LP QR Etiketi — Azure Direct Yazıcı Kurulumu

Bu kurulumda el terminalinde **LP > LP QR Yazdır** işlemi şu yolu kullanır:

`BADE terminali → Business Central → Azure Blob/Service Bus → BCWMS Print Agent → Windows ZPL yazıcısı`

Etiketteki QR'ın içeriği oluşturulan LP'nin gerçek numarasıdır. LP henüz
`Stop` edilmemiş ve SSCC üretilmemiş olsa bile QR basılabilir. Doğrusal barkod
varsa SSCC'yi, SSCC yoksa LP numarasını taşır.

## En kısa cevap: müşteri bilgisayarında Azure'a giriş yapılacak mı?

**Hayır.** Azure kaynakları ve geçici secret dosyaları önceden yönetici
bilgisayarında hazırlanır. Yazıcının bağlı olduğu müşteri bilgisayarında Azure
CLI, Azure Portal veya `az login` gerekmez.

Müşteri bilgisayarına yalnız şunlar gider:

1. `bcwms-print-agent-1.0.0-win-x64.zip`
2. O bilgisayar/istasyon için üretilmiş `print-agent.runtime.secrets.json`
3. `lp-qr-smoke-test.zpl`
4. `bcwms-bade-1.14.15-release.apk`
5. Yazıcının üretici Windows sürücüsü

`business-central.runtime.secrets.json` müşteri yazıcı bilgisayarına
kopyalanmaz. Bu dosya yalnız Business Central yöneticisi tarafından BC'ye
içe aktarılır.

## 1. Ön koşullar

- ZPL destekli etiket yazıcısı gerekir. Zebra veya ZPL emülasyonlu bir model
  kullanılabilir. Yazıcı ZPL desteklemiyorsa bu etiketi göndermeden önce model
  ve komut dili doğrulanmalıdır.
- Yazıcının üretici Windows sürücüsü kurulu olmalıdır.
- Windows 11 x64 veya Windows Server 2022/2025 x64 kullanılmalıdır.
- Bilgisayar Azure'a dışarı doğru TCP 443 ile çıkabilmelidir. Modem/firewall'da
  dışarıdan bilgisayara port açılmaz.
- Ajanın çalışacağı Windows kullanıcısı sabit olmalıdır. Ayarlar Windows DPAPI
  ile o kullanıcıya bağlı şifrelenir.
- BCWMS lisansında `PrintBridge` özelliği etkin olmalıdır.

## 2. Yönetici tarafında Azure'ı bir kez hazırlama

Bu bölüm müşteri yazıcı bilgisayarında değil, Azure yetkisi olan yönetici
bilgisayarında çalıştırılır.

Gerekli yönetici paketi:

- `releases/azure/BCWMS-Azure-Setup-1.4-final-windows.zip`

Windows bilgisayarda Azure CLI ve PowerShell 7 kurulduktan sonra paketi açın.
PowerShell 7 ile:

```powershell
az login
az account set --subscription '<AZURE-SUBSCRIPTION-ID>'

Set-Location .\direct-print-azure

pwsh .\scripts\Deploy.ps1 `
  -SubscriptionId '<AZURE-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-bade-bcwms-print-sandbox' `
  -NamePrefix 'badewms' `
  -TenantId 'DYNOPS' `
  -CompanyId 'BADE' `
  -EnvironmentName 'sandbox' `
  -Location 'westeurope' `
  -WhatIfOnly
```

What-if sonucu kontrol edildikten sonra aynı komutu `-WhatIfOnly` olmadan
çalıştırın. Ardından istasyon secret'larını üretin:

```powershell
pwsh .\scripts\Initialize-Configuration.ps1 `
  -SubscriptionId '<AZURE-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-bade-bcwms-print-sandbox' `
  -EnvironmentName 'sandbox' `
  -StationId 'DYNOPS.BADE.MAIN.PRINT01' `
  -BlobSasValidityDays 90
```

Station ID tam dört büyük harfli bölümden oluşur:

`TENANT.COMPANY.WAREHOUSE.STATION`

Her yazıcı bilgisayarına farklı Station ID verin. Komut iki ayrı dosya üretir:

- `.local/business-central.runtime.secrets.json`: yalnız BC'ye aktarılır.
- `.local/print-agent.runtime.secrets.json`: yalnız ilgili yazıcı bilgisayarına
  güvenli kanalla gönderilir.

Bu dosyaları e-posta/WhatsApp grubuna veya kaynak kod deposuna koymayın.

Altyapı ve yetki testleri:

```powershell
pwsh .\scripts\Test-Infrastructure.ps1 `
  -SubscriptionId '<AZURE-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-bade-bcwms-print-sandbox' `
  -EnvironmentName 'sandbox'

pwsh .\scripts\Test-Credentials.ps1 `
  -SubscriptionId '<AZURE-SUBSCRIPTION-ID>' `
  -ResourceGroupName 'rg-bade-bcwms-print-sandbox'
```

İki test de başarılı olmadan müşteri kurulumuna geçmeyin.

## 3. Business Central kurulumu

1. QR'lı LP etiketi değişikliğini içeren BCWMS AL paketini Windows AL araç
   zincirinde derleyin.
2. BC **Extension Management** sayfasından güncel `.app` paketini yükleyin.
3. Extension için **Allow HttpClient Requests** seçeneğini açın.
4. Yönetici kullanıcıya `DOPSWHS-ADMIN`, terminal servis kullanıcısına
   `DOPSWHS-USER` izin setini atayın.
5. **Advanced WMS Setup** sayfasını açın.
6. **Import BC Azure Print Config** ile
   `business-central.runtime.secrets.json` dosyasını seçin.
7. `Print Channel` değerinin **Azure Direct (Blob + Service Bus)** olduğunu
   doğrulayın.
8. **Validate Azure Print** işlemini çalıştırın.
9. Secret importu ve smoke test tamamlandıktan sonra düz metin secret dosyasını
   güvenli kasaya taşıyın veya güvenli biçimde silin.

## 4. Müşteri yazıcı bilgisayarında kurulum

Müşteriye çıplak `.exe` göndermeyin. EXE diğer DLL ve installer dosyalarına
bağımlıdır; klasör yapısını koruyan ZIP gönderilmelidir.

Gönderilecek ajan paketi:

- `releases/windows/bcwms-print-agent-1.0.0-win-x64.zip`
- SHA-256:
  `af18719b05b651537d264f8d128fb89330df6475ebb6c0586b7a9871b030564c`

Kurulum sırası:

1. Etiket yazıcısının üretici sürücüsünü kurun.
2. Windows **Yazıcılar ve tarayıcılar** ekranından test sayfası alın.
3. Ajan ZIP'ini tamamen bir klasöre çıkarın.
4. Normal kullanıcı PowerShell'inde çıkarılan paketin üst klasöründe çalıştırın:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\BCWMS-Print-Agent-win-x64\installer\install.ps1
   ```

5. Ajan açılınca **Azure Ayarları** bölümüne girin.
6. **Print Agent Secrets İçe Aktar** ile yalnız
   `print-agent.runtime.secrets.json` dosyasını seçin.
7. **Yazıcılar > Yazıcıları Yenile** düğmesine basın.
8. **Etiket Yazıcısı** olarak gerçek etiket yazıcısını seçin.
9. Etiket formatını **ZPL**, taşıma yöntemini **WindowsRaw** seçin.
10. **Ayarları Kaydet ve Bağlan** düğmesine basın.
11. **Etiket Testi** ile yerel etiketi fiziksel olarak doğrulayın.
12. **Buluta Eşitle** düğmesine basın. Ajanın ürettiği
    `P` + 16 hex karakterli yazıcı kodunu not edin.
13. Kurulumdan sonra `print-agent.runtime.secrets.json` dosyasını müşteri
    bilgisayarından kaldırıp güvenli kasaya taşıyın.

Ajan penceresini kapatmak programı durdurmaz; sistem tepsisine küçültür. Program
aynı Windows kullanıcısı oturum açınca otomatik başlar.

### Windows güvenlik notu

Mevcut ajan paketi bütünlük manifestiyle korunuyor ancak Authenticode imzalı
değil. Kurumsal müşteriye kalıcı dağıtımdan önce EXE ve installer scriptlerini
kod imzalama sertifikasıyla imzalamak önerilir. İmzasız pakette Windows
SmartScreen uyarısı görülebilir; dosya hash'i yukarıdaki değerle eşleşmeden
çalıştırmayın.

## 5. İlk bulut baskı testi

Önce Azure smoke testi yapın. Ajan ekranında görünen gerçek yazıcı kodu ve
Windows yazıcı adını kullanın:

```powershell
Set-Location .\direct-print-azure

pwsh .\scripts\Send-SmokeTest.ps1 `
  -PrinterId 'P0123456789ABCDEF' `
  -PrinterName 'ZDesigner ZD220-203dpi ZPL' `
  -Format ZPL `
  -Copies 1 `
  -FilePath 'C:\Test\lp-qr-smoke-test.zpl'
```

Beklenenler:

- Ajan **Azure kuyruğu dinleniyor** durumuna geçer.
- Fiziksel yazıcı tam bir etiket çıkarır.
- Service Bus DLQ sayısı artmaz.
- Ajan logunda işin spooler tarafından kabul edildiği görülür.

## 6. BADE terminalinde yazıcı seçme

1. BADE el terminali uygulamasını açın.
2. **Yazıcılar** ekranına girin.
3. **Yenile** düğmesine basın.
4. ZPL yazıcının yanında **Etiket** düğmesine basın.
5. Yazıcının etiket rozetiyle seçili göründüğünü doğrulayın.

## 7. LP QR etiketini basma

1. Terminalde **LP** bölümünü açın.
2. Oluşturulan LP'nin içine girin.
3. **Yazdır** düğmesine basın.
4. Terminal isteği BC'ye gönderir; BC ZPL içinde LP numarasını taşıyan QR'ı
   oluşturup Azure'a hemen dispatch eder.
5. BC **Print Job Queue** üzerinde iş sırasıyla
   `Queued → Dispatched → Sent` olmalıdır.
6. Çıkan etiketteki QR'ı terminalle okutun. Okunan değer oluşturulan LP
   numarasıyla birebir aynı olmalıdır.

## 8. Hızlı arıza kontrolü

- **Terminalde yazıcı yok:** Ajan içinde **Buluta Eşitle**, BC status worker ve
  terminal **Yazıcılar > Yenile** işlemlerini kontrol edin.
- **No WMS bridge printer is mapped:** Terminalden ZPL yazıcıyı **Etiket**
  varsayılanı seçin veya BC **Device Printer Mapping** içinde `LP Label`
  eşlemesi yapın.
- **Queued durumunda kalıyor:** BC `Allow HttpClient Requests`, Azure secret
  süresi ve **Validate Azure Print** sonucunu kontrol edin.
- **Dispatched ama basılmıyor:** Ajanın aynı Station ID ile bağlı olduğunu,
  Windows yazıcı kuyruğunu ve ajan logunu kontrol edin.
- **QR basılmıyor ama yazı basılıyor:** Yazıcı/emülasyon dili ZPL değildir veya
  sürücü RAW veriyi dönüştürüyordur. Etiket yazıcısını ZPL/WindowsRaw olarak
  yeniden seçin.
- **QR okunmuyor:** 203 DPI yazıcıda baskı koyuluğu, etiket yüzeyi ve kafa
  temizliğini kontrol edin; QR'ın içeriğini telefonla okuyup LP numarasıyla
  karşılaştırın.
