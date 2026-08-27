# V2 Outbound Mode

V2, klasik terminal akışını değiştirmeden toplama ve paketlemeyi üç ayrı
operasyon kuyruğuna böler. Android üst çubuğundaki `V2` anahtarı cihazda
kalıcıdır; kapatıldığında mevcut Toplama ve Paketleme ekranları aynen çalışır.

| Kullanıcı adı | BC enum değeri | Sipariş kuralı | Toplama | Paketleme |
|---|---|---|---|---|
| Multi | `Multi` | Birden fazla sipariş; birden fazla ürün olabilir | Raf rotası, ortak ürünlerde toplu miktar dağıtımı | Koli → siparişin farklı ürünleri → sevk/fatura |
| Mono | `Batch` | Her siparişte tek ürün; gruptaki ürünler birbirinden farklı | Her ürün tek siparişe gider | Ürün → koli → sevk/fatura |
| Tek SKU | `Bulk` | Birden fazla sipariş; tümünde aynı tek ürün | Ortak SKU toplu toplanır ve paylara dağıtılır | Koli → sipariş payı → sonraki koli |

`Bulk` ve `Batch` iç enum adları mevcut tenant verisi ve API uyumluluğu için
korunur. Arayüzlerde yalnızca `Tek SKU` ve `Mono` adları gösterilir.

## Business Central ekranları

- `Multi Siparişler`
- `Mono Siparişler`
- `Tek SKU Siparişler`

Üç ekran da aynı picking-order motorunu kullanır. Tip bilgisi picking order →
warehouse pick → packing order zincirinde taşınır. Mono ve Tek SKU kuralları,
sipariş gruba eklenirken sunucu tarafında doğrulanır.

Paketleme için aynı motoru kullanan üç sabit istasyon vardır: `V2 Multi
Paketleme`, `V2 Mono Paketleme`, `V2 Tek SKU Paketleme`.

## Yayın sırası

1. AL uzantısını şema senkronizasyonuyla yayınla.
2. Üç BC kuyruğundan test grupları oluşturup pick'leri kaydet.
3. Android build'ini dağıt.
4. Terminalde `V2`yi açıp her tip için toplama → paketleme → sevk/fatura
   zincirini doğrula.

Android, V2 API alanı/aksiyonu henüz yayınlanmadıysa açıklayıcı güncelleme
mesajı gösterir. Klasik moda dönmek için aynı `V2` düğmesine dokunmak yeterlidir.
