# BCWMS Android — Release Changelog

Sideload sürümleri burada toplanır. Her sürüm `bcwms-<version>-debug.apk`
olarak `releases/android/` altında saklanır.

Kurulum: [docs/android-install-guide.md](../../docs/android-install-guide.md)

---

## v1.14.28-bade — 2026-08-25

**APK:** `BCWMS-BADE-1.14.28-BAGLANTI-LP-SAYIM-DUZELTMELERI.apk`

**SHA-256:** `3c714c76e23715de5a4f0113c8688617e37d657d95cc9302beed6bc5fe58f4d5`

- Şirket bağlantısı artık tek bir LP veri sorgusunun sonucuna bağlı değil;
  giriş için gereken hafif WMS kullanıcı API'si esas alınıyor.
- Eski BC paketleri için LP bağlantı kontrolü yedek olarak korunuyor.
- Yetki, oturum, ağ ve eksik BC paketi hataları artık ayrı ve anlaşılır
  mesajlarla gösteriliyor.
- `testBadeReleaseUnitTest`: **91 test, 0 hata**; release derleme ve APK v2
  imza doğrulaması başarılı.

---

## v1.14.27-bade — 2026-08-25

**APK:** `BCWMS-BADE-1.14.27-LP-URUN-ADI-SAYIM-DUZELTMELERI.apk`

**SHA-256:** `feb78682c6a38d0239fc9ee742f49fa35c17aaefc39ecbc5c49137fee7460d2f`

**versionCode:** 1427 · **minSdk:** 26 · **targetSdk:** 35

### LP ürün seçimi ve sayım güvenliği

- LP satırına ürün numarası ve lot numarasının yanında ürün adıyla arayıp
  sonuç listesinden seçim yapma eklendi.
- Seri takipli ürünün LP satırına uygun olmayan doğrudan eklenmesi, işlem
  sonunda ham hata vermek yerine seçim aşamasında Türkçe uyarıyla durduruluyor.
- Boş `Open` ve `Unbuilt` LP'ler terminalden silinebiliyor; LP oluşturma bütün
  kanallarda şablon ölçülerini ve `Built` hareketini üreten tek iş kuralından geçiyor.
- Kaydedilmiş sayım belgesi ve satırları değiştirilemiyor; yalnız operatöre
  atanmış gerçek sayıcı slotları gösteriliyor ve kaydedilebiliyor.
- İki veya üç sayıcının miktar uyuşmazlığı satır bazında gösteriliyor, post
  durduruluyor; `Yeniden Say` bütün önceki miktarları ve bayrakları temizliyor.
- Fiziksel sayım günlük batch'i başka belge satırı içeriyorsa silme/post işlemi
  veri kaybını önlemek için durduruluyor.

Bu Android sürümü BADE BCWMS AL `1.14.0.42` ile birlikte yayımlanmalıdır.

### Doğrulama

- `testBadeReleaseUnitTest`: **88 test, 0 hata**
- `assembleBadeRelease`: başarılı
- APK Signature Scheme v2: doğrulandı; sertifika SHA-256:
  `ea7710af652faf6beff836d64327159b021c0561297cf9ae60987d26592b81eb`
- BC AL `1.14.0.42`: **323 dosya, derleme başarılı**

---

## v1.14.19-bade — 2026-08-24

**APK:** `bcwms-bade-1.14.19-production-release.apk`

**SHA-256:** `d5e955f52547834f94b7da8c20170b475800d080df186e9cd5b38b4c0321f40a`

**versionCode:** 1419 · **minSdk:** 26 · **targetSdk:** 35

### Güvenli üretim akışları ve sade operatör deneyimi

- Toplama, mal kabul, yerleştirme, sevkiyat, sayım, paketleme, montaj ve LP
  işlemleri; kullanıcı sahipliği ve belgenin bütün satırları doğrulanmadan
  değişiklik yapmayacak şekilde kapalı-güvenli hale getirildi.
- Büyük belge ve kuyruklarda sunucunun tüm sayfaları okunuyor. Eksik/bozuk bir
  sayfa, boş veya tamamlanmış belge gibi değerlendirilmeden operatöre yeniden
  deneme mesajı gösteriliyor.
- Lot/seri ve ölçü birimi alanları BC takip kurallarına göre seçiliyor; zorunlu
  lot bilgisi alınamadığında lotsuz kayıt engelleniyor. Doğrudan siparişte
  saklanamayacak takip bilgisi ambar belgesi akışına yönlendiriliyor.
- Aynı ürünün birden fazla lot/seri toplama satırı varsa okutulan takip
  bilgisi tam satır grubuyla eşleşmeden miktar veya onay ekranı açılmıyor.
- Sayımda sonradan rafa bağlanan LP'nin tüm satırları alınamazsa eksik veriyle
  miktar kaydına geçilmiyor; belge yenilenip operatöre tekrar deneme bildiriliyor.
- Doğrudan satınalma mal kabulünün satır ön kontrolü kısmen başarısız olursa
  kayıt durduruluyor, belge sunucudan yeniden okunuyor ve kısmi işlem uyarısı
  yenileme sonrasında da korunuyor.
- LP'ye raftan ürün eklemeden önce kaynak rafın tüm OData sayfaları okunuyor;
  doğrulama tamamlanamazsa stok veya LP hareketi oluşturulmuyor.
- LP raf hareketi ve LP içeriği aktarımı sunucu tarafındaki atomik işlemleri
  kullanıyor; yarım stok/LP hareketi oluşturabilecek ardışık mobil yazımlar
  kaldırıldı.
- Paketleme çift okutma, zaman aşımı sonrası uzlaşma, başarısız oturumun tekrar
  başlatılması ve koli kapatılırken bekleyen yazım kontrolleri güçlendirildi.
- Operatör ekranlarında test/teknik alanlar, boş tıklanabilir kontroller ve ham
  API ayrıntıları gizlendi; teknik hata ayrıntıları yalnız destek referansı ile
  kayda alınıyor. Şirket değişimi ve oturum kimliği yeniden doğrulanmadan
  operasyon butonları ve yalnız kullanıcıya atanmış kuyruklar açılmıyor.

Bu Android sürümü BADE BCWMS AL `1.14.0.36` veya daha yeni paketle birlikte
yayımlanmalıdır.

### Doğrulama

- `testBadeDebugUnitTest`: **77 test, 0 hata, 0 atlanan**
- `lintBadeDebug`: **0 hata**; 72 uyarı yalnız bağımlılık/sürüm, Compose
  performans önerisi ve proje yapılandırma kontrolleridir.
- `assembleBadeDebug` ve `assembleBadeRelease`: başarılı
- APK Signature Scheme v2: doğrulandı; sertifika SHA-256:
  `ea7710af652faf6beff836d64327159b021c0561297cf9ae60987d26592b81eb`

---

## v1.14.18-bade — 2026-08-24

**APK:** `bcwms-bade-1.14.18-production-stabilization-release.apk`

**SHA-256:** build sonrası doldurulacak

**versionCode:** 1418 · **minSdk:** 26 · **targetSdk:** 35

### Production stabilizasyonu

- Toplama satırları ve belge kaydı, terminalde oturum açan depo
  kullanıcısıyla sunucu tarafında doğrulanan atomik aksiyonlara taşındı;
  paralel satır yazımları ve başkasının belgesini kaydetme yolu kapatıldı.
- Paketlemede hızlı çift okutma, aynı kolinin farklı siparişte kullanımı,
  zaman aşımından sonra sunucuda tamamlanmış oturum ve yarım kalan ilk
  oturumu yeniden başlatma akışları güvenli hale getirildi.
- Sayım sayfalaması eksik sonuçta başarılı sayılmıyor; kaydetme/kayıt
  butonları belge ve veri tamamlanmadan açılmıyor, kritik işlemler onay istiyor.
- LP oluşturma/atama, ürün veya lotla arama, UOM ve zorunlu lot seçimi
  fail-closed çalışıyor. Müşteriye özel sabit şablon/lokasyon/raf kodları
  kaldırıldı; uygun şablon BC verisinden belirleniyor.
- Mal kabul, yerleştirme ve sevkiyat yalnız operatörün dokunduğu satırları
  kaydediyor; lot/seri takipli doğrudan siparişler doğru ambar belgesine
  yönlendiriliyor.
- BADE operatör arayüzü tek üretim akışına indirildi. V2 anahtarı,
  token/Azure CLI alanları, test menüleri ve boş tıklanabilir rozetler gizlendi;
  teknik API/HTTP ayrıntıları yerine kısa Türkçe hata metinleri gösteriliyor.

Bu Android sürümü, aynı teslimde derlenen güncel BADE BCWMS AL paketiyle
birlikte yayımlanmalıdır.

---

## v1.14.17-bade — 2026-08-21

**APK:** `bcwms-bade-1.14.17-release.apk`

**SHA-256:** `38e1bbda69bbf2746f41b944f852ae73e1083fe7a0c885f528a85cdc760f5fbf`

**versionCode:** 1417 · **minSdk:** 26 · **targetSdk:** 35

### LP — ürün/lot çözümleme, UOM seçimi ve zorunlu lot

- LP satırı eklerken ilk okutulan değer önce ürün numarası, ürün bulunamazsa
  pozitif stoklu lot numarası olarak aranır; lot artık ürün numarası diye BC'ye
  gönderilmez.
- Ölçü birimi elle yazılmaz; ürün kartındaki geçerli UOM listesinden seçilir.
- Lot takipli veya lokasyonda lotlu stoğu bulunan üründe stok lotu seçilmeden
  satır onaylanamaz. Aynı lot birden fazla üründe bulunursa doğru ürün seçtirilir.
- Sunucu tarafı da lot takipli ürünü boş lotla LP'ye eklemeyi reddeder.

Bu sürüm için BCWMS AL `1.14.0.35` paketi de yayımlanmalıdır.

---

## v1.14.16-bade — 2026-08-21

**APK:** `bcwms-bade-1.14.16-release.apk`

**SHA-256:** `0a5f743264ed86e3278762cce263abdfee2a72c03357c8ce7b2bb91651456a5a`

**versionCode:** 1416 · **minSdk:** 26 · **targetSdk:** 35

### Sayım — düz lot kodunun yanlış ekrana yönlenmesi düzeltildi

- Aktif raftaki düz lot numarası artık ürün kodu sanılarak `Beklenmeyen
  fiziksel stok` ekranını açmıyor; ilgili lot satırı veya lot seçim ekranı
  doğrudan açılıyor.
- Rafta yerel eşleşme bulunmazsa kod BC ürün kartından doğrulanıyor: gerçek ürün
  kodunda mevcut beklenmeyen stok akışı korunuyor, ürün olmayan kod BC lot
  bakiyesinde aranıyor.
- Bir ürünün/lotun kayıtları sırayla açılmaya devam ediyor; önceki çoklu seçim
  denemesi bu sürüme dahil edilmedi.

---

## v1.14.15-bade — 2026-08-21

**APK:** `bcwms-bade-1.14.15-release.apk`

**SHA-256:** `5e2bad2bd657d3c06309b545f7b0f07b756e9a47d317ed158a93659952ed08f0`

**versionCode:** 1415 · **minSdk:** 26 · **targetSdk:** 35

### LP QR etiketi — Azure Direct müşteri sürümü

- LP içindeki `Yazdır` butonu, oluşturulan LP numarasını taşıyan QR etiketini
  güncel BCWMS AL paketi üzerinden Azure Direct yazıcı kuyruğuna gönderir.
- SSCC henüz oluşmamış açık LP'ler de kendi LP numarasıyla QR basabilir.
- Sayım lot görünürlüğü, BC depo gözündeki LP bilgisi, güvenli LP silme ve
  lokasyon uyuşmazlığı kontrolleri bu müşteri APK'sında birlikte bulunur.
- Tam yazdırma akışı için BCWMS AL `1.14.0.31` derlenip BADE şirketine
  yayınlanmalı ve Windows Print Agent kurulmalıdır.

---

## v1.14.14-bade — 2026-08-21

**APK:** `bcwms-bade-1.14.14-release.apk`

**SHA-256:** `ee38194c3534f53d70a69fa6ca17fec9c704630f9cee9d2fd685ecdb5bce98d3`

**versionCode:** 1414 · **minSdk:** 26 · **targetSdk:** 35

### Sayım — lot miktarını açık gösterme ve yanlış lota girişi engelleme

- Sayım miktarı girişinde seçili lot/seri ve o lotun sistem miktarı belirgin
  olarak gösterilir; raftaki diğer lotların BC miktarları da ayrı listelenir.
- Rafın lotlu bakiyesi varken lotsuz sayım satırına miktar yazılması engellenir;
  operatörün lot satırını seçmesi veya lot barkodunu okutması istenir.
- 1., 2. ve 3. sayıcı tarafından daha önce girilen miktarlar aynı ekranda
  lot/seri bağlamıyla görünür.

### LP — depo gözü görünürlüğü, güvenli silme ve lokasyon kontrolü

- BC Bin Contents ve terminal depo gözü sorgusunda aktif LP numaraları ile
  ürünün aktif LP'lerdeki miktarı gösterilir. LP factbox'ı ürün, miktar ve lot
  özetini içerir.
- `Boz` işlemi LP satırlarını kaldırdıktan sonra Açık/Bozuldu ve boş LP için
  onaylı `Sil` işlemi açılır. Dolu veya işlem görmüş LP sunucuda da silinemez.
- Ürünün kaynak rafı ile LP lokasyonu farklıysa işlem mobilde gönderilmeden
  durdurulur; sunucu tarafındaki ikinci kontrol de stok hareketini reddeder.
- Aynı lokasyonda kaynak raf ile LP rafı farklıysa gerçek BC bin-to-bin
  hareketi yapılır; böylece LP ve ürün aynı depo gözünde kalır.
- LP içindeki `Yazdır` işlemi ZPL etikete LP numarasını taşıyan QR ekler ve
  Azure Direct işini aynı istekte kuyruğa gönderir; SSCC oluşmamış açık LP de
  QR etiketi basabilir.
- Bu sürümün tüm alanları ve işlemleri için BCWMS AL `1.14.0.31` paketi
  derlenip ilgili şirkete yayınlanmalıdır.

---

## v1.14.13-bade — 2026-08-21

**APK:** `bcwms-bade-1.14.13-release.apk`

**SHA-256:** `295ec8e099bbca938b3415285527974ea76389e39a498f31a512361f137fe163`

**versionCode:** 1413 · **minSdk:** 26 · **targetSdk:** 35

### Sayım — fiziksel raf farkı, lot seçimi ve güvenli sürüm kontrolü

- Sayım satırında bulunmayan fiziksel ürün/lot için ürün, varyant, birim,
  lot/seri ve miktar doğrulama ekranı eklendi.
- Sistemde başka rafta görünen LP fiziksel rafta doğrulanabilir; sayım başarıyla
  post edildikten sonra LP rafı fiziksel adresle eşitlenir.
- Terminalde görünen fakat fiziksel rafta bulunmayan satırlar, adres kapatılırken
  açık onayla kalıcı `0` sayım olarak kaydedilir.
- Ürün+lot etiketi tam eşleşmeyle seçilir; aynı ürünün başka lotuna düşme
  engellendi. Aynı lot için birden fazla kayıt varsa madde/LP/miktar seçim
  ekranı açılır.
- BADE sürümü varsayılan şirketi artık şirket listesinden tam adıyla çözer;
  eski `CRONUS USA, Inc.` varsayılanı otomatik temizlenir.
- Yeni fark işlemleri BCWMS AL `1.14.0.30` gerektirir. Sunucuda eski paket varsa
  normal sayım çalışmaya devam eder; desteklenmeyen işlemler HTTP hatasına
  gönderilmeden kapatılır ve ekranda paket gereksinimi gösterilir.

---

## v1.14.12-bade — 2026-08-20

**APK:** `bcwms-bade-1.14.12-release.apk`

**SHA-256:** `f18ce367fa11dec85cda1e55df8560bb1070991ee2c45d01a513657b2bc5b5e6`

**versionCode:** 1412 · **minSdk:** 26 · **targetSdk:** 35

### Sayım — lot/seri bazlı miktar görünürlüğü

- LP dışındaki raf stoku artık ürün toplamı yerine Warehouse Entry bakiyesine
  göre lot/seri kırılımında ayrı sayım satırlarına dönüştürülür.
- Terminalde ürün ve LP satırlarında lot/seri, sistem miktarı ve seçili
  sayıcının girdiği miktar birlikte gösterilir.
- Satır düzeltme ekranı daha önce girilmiş 1./2./3. sayım miktarlarını gösterir;
  slot değiştirilince ilgili slotun değeri düzenlemeye açılır.
- Sayım içindeki LP kartına doğrudan **LP etiketini yazdır** düğmesi eklendi.
- Bu sürüm, BCWMS AL `1.14.0.29` paketiyle birlikte kullanılmalıdır.

---

## v1.14.11-bade — 2026-08-20

**APK:** `bcwms-bade-1.14.11-release.apk`

**SHA-256:** `233c080867c92ad24064eff82fe382a474821d82d7197b296f75eea7159780c5`

**versionCode:** 1411 · **minSdk:** 26 · **targetSdk:** 35

### LP — gerçek raf stok hareketi

- LP'ye satır eklenirken kaynak raf ile LP rafı farklıysa BC bin-to-bin
  hareketi aynı işlem içinde kaydedilir.
- Hareket veya LP satırı hata verirse ikisi de geri alınır; yalnızca LP
  satırı oluşturan eski geri dönüş yolu kaldırıldı.
- Yetersiz veya başka aktif LP'lere ayrılmış stok açık hata ile reddedilir.
- Satırdaki adres artık `Kaynak raf` etiketiyle gösterilir.
- Bu sürüm, BCWMS AL `1.14.0.28` paketiyle birlikte kullanılmalıdır.

---

## v1.14.10-bade — 2026-08-20

**APK:** `bcwms-bade-1.14.10-release.apk`

**SHA-256:** `76ac84f7ea494d71ab2224629c35f533d8b1b5e55bee730867fe7eedd005775b`

**versionCode:** 1410 · **minSdk:** 26 · **targetSdk:** 35

### Sayım — rafsız LP ilk yerleştirme

- Rafı boş LP artık `Satır Üret` işlemini durdurmaz.
- Operatör önce rafı, sonra LP'yi okuttuğunda LP okutulan rafa bağlanır ve
  LP satırları açık sayım belgesine eklenir.
- LP miktarı, aynı raftaki paletsiz sistem stokundan düşülür; çift sayım
  önlenir. BC raf stoku yoksa/yetersizse işlem açık hata verir.
- LP başka bir rafa önceden atanmışsa otomatik taşınmaz; fiziksel doğrulama
  istenir.

### BC — sayıcı kullanıcı seçimi

- Count Counters / User ID seçimi, terminal operatörlerinin bulunduğu etkin
  `Local WMS Users` listesine bağlandı.
- Seçimden sonra Assigned DateTime otomatik dolar; serbest metin ve standart
  BC User tablosu kaynaklı seçim hataları kaldırıldı.

---

## v1.14.9-bade — 2026-08-19

**APK:** `bcwms-bade-1.14.9-release.apk`

**SHA-256:** `66c758ada6daaa7429c05830f88ea6fc028c6e7024abe38c40347a93f00c2136`

**versionCode:** 1409 · **minSdk:** 26 · **targetSdk:** 35

### Sayım — nihai adres bazlı akış

- **Etiket okutunca bilgi kartı:** madde no + ürün adı + miktar. LP'li kalemde
  miktar etiketten gelir (GS1 AI 30/37 varsa QR'dan, yoksa LP kaydından) ve tek
  tuşla onaylanır. **LP'siz (dökme) kalemde otomatik miktar yok** — depocu
  saydığını elle girmeden kaydedemez.
- Ürün barkodu paletli satıra denk gelirse kalem PALET olarak açılır (tek
  satırı sayıp paleti bitti işaretleme hatası kapatıldı).
- Sayım yazıldıktan sonra satırlar hemen tazelenir: aynı ürünün ikinci lotu
  okutulunca ilk satırın üstüne yazma hatası kapatıldı.
- **Sayıcı slotları artık gerçekten bağımsız:** sayıldı-durumu seçili slota
  göre hesaplanır; 2./3. sayıcı okutarak yeniden sayım yapabilir. Satır
  düzeltme ekranı paneldeki slotu devralır (yanlışlıkla slot 1'i ezme bitti).
- 'Yeniden Say' pane ilerlemesini sıfırlar; sayılmış palet ikinci adresten tek
  tuşla ezilemez; bilgi kartı açıkken ikinci okutma işlenmez.
- Miktar girişinde virgül noktaya çevrilir (12,5 → 125 hatası kapandı);
  geçersiz girdide buton kilitli (sessiz 0 kaydı bitti).
- 200+ satırlı sayfalarda sayfalama: tüm satırlar yüklenir (5000 tavan).
- **Ekran netliği:** adres kartlarında X/Y sayıldı + ilerleme çubuğu; sayılan
  kalemde yeşil 'Sayılan: N', sayılmayanda gri 'Sistem: N'.
- GS1 çözümleme sağlamlaştırıldı: AI 02/30/37, FNC1 sonrası sabit AI, 00
  önekli 20 haneli SSCC.

### BC (AL — Windows'ta publish bekliyor)

- Count Sheet Card'a 'Sayım Durumu' paneli: Toplam/Sayılan/Kalan/Farklı Satır.
- Count Sheet Lines: 'Sayıldı' kolonu + satır renkleri (yeşil=fark yok,
  turuncu=fark var), Description kolonu.

### Bilinen sınırlamalar

- 0 girilen sayım sunucuda 'hiç sayılmadı'dan ayırt edilemiyor (şemada bayrak
  yok); adres kapatma/tekrar giriş 0'lı satırları bekliyor gösterebilir. Kalıcı
  çözüm AL şema değişikliği (Counted bayrağı) gerektirir.
- Etiket QR'ında miktar yoksa LP kaydı esas alınır — müşterinin QR formatı
  netleşince ayrıştırıcı uyarlanmalı.

---

## v1.14.8-bade — 2026-08-19

**APK:** `bcwms-bade-1.14.8-release.apk`

**SHA-256:** `68c3189ae998913a69bacf310111e6064fc619d560e2e8b215e425db6fd8383e`

**versionCode:** 1408 · **minSdk:** 26 · **targetSdk:** 35

### Değişiklikler

- **Etiket okutunca bilgi kartı açılıyor:** madde no, ürün adı, miktar (+ birim,
  lot/seri) gösterilir; onaylayınca okutulan adrese sayıldı olarak yazılır.
  Kart hem LP etiketini hem ürünün kendi barkodunu (madde no / ürün referansı /
  GTIN) tanır. Ürün adı sayım satırında boşsa ürün kartından tamamlanır.
  Miktar farklıysa karta dokunup elle girilebilir.
- Yanlış adreste okutulan palet uyarısı bilgi kartının içine taşındı.
- **Kör (Blind) mod terminalden kaldırıldı.** Sayım palet/etiket doğrulamasıyla
  yürüdüğü için miktar her zaman gösterilir; BC'deki Mode alanı ne olursa olsun
  terminal miktarı gizlemez, KÖR rozeti kalktı.

---

## v1.14.7-bade — 2026-08-19

**APK:** `bcwms-bade-1.14.7-release.apk`

**SHA-256:** `367766dab25b07d886c1db043819c4a25c261cc7741c3aaba94fd1937d1cef79`

**versionCode:** 1407 · **minSdk:** 26 · **targetSdk:** 35

### Değişiklikler

- **Sayım artık adres bazlı yürüyor — tek akış.** Sayım belgesi açılınca doğrudan
  adres listesi gelir: rafı okut (veya listeden seç) → o rafta beklenen paletler
  listelenir → LP'leri tek tek okut → "Adresi Kapat" → sonraki rafa geç. LP
  okutmak paleti tam kabul eder, miktar girmeye gerek yoktur. Adres
  kapatılırken okutulmayan paletler onay alınarak eksik (0) sayılır.
  Yanlış adreste okutulan palet uyarı verir; paletsiz stok ve içeriği hatalı
  palet için satıra dokunup miktar elle girilebilir.
- Eski satır listesi (grid + kolon seçici) sayım ekranından kaldırıldı; süreç
  tek ve yönlendirilmiş hale getirildi.

---

## v1.14.6-bade — 2026-08-19

**APK:** `bcwms-bade-1.14.6-release.apk`

**SHA-256:** `7ad6144520cfd8e706f413cad9540ff594ce8530a0785dcf46aee33d88795f42`

**versionCode:** 1406 · **minSdk:** 26 · **targetSdk:** 35

### Yenilikler

- **Yerleştirmede adım adım doğrulama.** Bir yerleştirmeye dokunulduğunda
  kaynak raf → ürün → hedef raf → miktar sırasıyla ilerlenir. Her adımda
  okutulan barkod belgedeki beklenen değerle karşılaştırılır; uyuşmazsa
  "Yanlış raf/ürün — Beklenen: X" uyarısı çıkar ve adım ilerlemez. Kaynak raf
  bilgisi belgede yoksa o adım atlanır.
- **Sevkiyat ve toplamada lot seçimi.** "Stoktaki Lotlardan Seç" listesi artık
  her zaman görünür; elde pozitif stoklu lotları miktar ve rafıyla listeler.
  Ürünün stoğunda lot varsa lot alanı otomatik olarak zorunlu olur ve boş
  bırakılırsa satır onaylanamaz — BC'deki `lotRequired` alanı gelmese bile.
  Toplama ekranında lot alanı önceden ne zorunluydu ne de seçim listesi vardı.

---

## v1.14.2-bade — 2026-08-12

**APK:** `bcwms-bade-1.14.2-barcode-auto-print-release.apk`

**SHA-256:** `752ba4c9ab7b741e329653becddad646f748c71fa50f352d4adb936d097fbe41`

**versionCode:** 1402 · **minSdk:** 26 · **targetSdk:** 35

### Düzeltmeler

- Barkod okutulduğunda/yazdırıldığında terminal klavyesi kapanır.
- Barkod test işi BC'de bekleyen `Queued` satır olarak bırakılmaz; aynı API
  isteğinde Azure'a gönderilir. Bir dakikalık worker çevrimini veya elle
  `Validate Azure Print` çalıştırmayı beklemez.

---

## v1.14.1-bade — 2026-08-12

**APK:** `bcwms-bade-1.14.1-barcode-print-test-release.apk`

**SHA-256:** `9cee4b0061cde859eccdd6d9ee5cd9b6b92f000061dfeab58d6a833b9e98e682`

**versionCode:** 1401 · **minSdk:** 26 · **targetSdk:** 35

### Bu sürümde

- **Yazıcılar → Barkod Baskı Testi** eklendi.
- Donanım okuyucu, kamera veya elle girişle alınan ham barkod numarası terminalde
  büyük olarak gösterilir.
- Okunan numara seçili PDF belge yazıcısına tek sayfalık test çıktısı olarak
  gönderilir.
- Bu özellik, gerçek Code 128 barkod çıktısı ve Azure üzerinden otomatik baskı için BCWMS AL extension `1.14.0.7` veya üstü gerekir.

---

## v1.10.0 — 2026-06-24

**APK:** `bcwms-1.10.0-debug.apk` (32 MB)
**SHA-256:** `c19f10a73ca5edf41971898a74509e798ca0f463c57377211dbedbeb0f0e9020`
**versionCode:** 110 · **minSdk:** 26 · **targetSdk:** 35

### Bu sürümde

- 🩺 **Sistem Sağlığı** paneli (yeni): 10 check probe BC API + ScanBus +
  PWA service worker + localStorage — kurulum sonrası tek-dokunuş smoke test
- 📷 **Picking Tara & Doğrula** (yeni): barkod ↔ itemNo eşleşmedikçe
  updateLine çağrılmaz; yanlış ürün toplanma riski elimine edildi
- 📋 **Posting Test grouping** (yeni): 4 kategori — Passed / Real Failure
  / Setup Eksik (gizli tab) / Cascade Atlandı (gizli tab); her Setup
  satırında BC sayfa hint'i
- ⚙️ **DocSearchBar** (yeni): 11 list ekranında ortak belge no arama
  (Picking, Receiving Tab1/Tab2, PutAway, Shipping Tab1/Tab2, Count,
  Movement, LP, Production×2, Assembly, Quality)
- 🔧 **SheetScaffold** (yeni): 10 BottomSheet refactor — klavye açılınca
  Onayla button artık görünür (verticalScroll + imePadding wrapper)
- 🛡 **ActionGuards** (yeni): qty=0 iken Post/Register button disabled
- 🔵 **Zebra DataWedge** entegrasyonu (yeni): ScanBus event bus +
  focus-based subscribe; cold-start intent drop fix (Codex Finding 7)
- 📊 **Item Inquiry stok bloğu** (yeni): inventory + 4 FlowField
  (qty on PO/SO/Prod + reserved); blocked chip
- 📍 **Bin Inquiry içerik tablosu** (yeni): T7302 Bin Content gerçek item
  miktarları (LP listesinin üstünde)
- 🏷 **LP Build template dropdown**: licensePlateTemplates'tan seçim
- 🖨 **LP printLabel default printer**: getDefaultPrinter() ile otomatik
- 🐛 Codex review wave 1+2 fix'leri:
  - ItemApi `OnAfterGetRecord` trigger + 5 FlowField CalcFields
  - PickingModule ScanVerifySheet race fix (busy atomic)
  - MainActivity DataWedge cold-start LaunchedEffect dispatch
  - PickingModule OData filter merge → `buildList` pattern

### BC tarafı gereksinimleri

DOPSWHS extension v1.10.0 publish edilmiş olmalı. Aksi halde Sistem
Sağlığı'nda 3 API check FAIL döner (BinContentApi 72097, ItemApi
inventory, LPTemplateApi 72280).

### Önceki sürümler

v1.8.2.0 ve öncesi BC AL paketleri `releases/bcwmsapp-*.app` altında.
Android APK arşivi v1.10.0'dan itibaren `releases/android/` altında.
