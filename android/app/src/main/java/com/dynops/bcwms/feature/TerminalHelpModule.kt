package com.dynops.bcwms.feature

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.Screen
import com.dynops.bcwms.ui.WmsGlyph
import com.dynops.bcwms.ui.WmsIcon
import com.dynops.bcwms.ui.WmsIconBadge
import com.dynops.bcwms.ui.glyphForScreen

internal enum class HelpCategory(val label: String) {
    START("Başlangıç"),
    INBOUND("Gelen"),
    OUTBOUND("Giden"),
    LP_MOVE("LP ve Hareket"),
    COUNT("Sayım"),
    OTHER("Diğer"),
}

internal data class HelpTopic(
    val id: String,
    val category: HelpCategory,
    val icon: String,
    val title: String,
    val summary: String,
    val steps: List<String>,
    val tip: String = "",
    val target: Screen? = null,
)

/** Operatörün ihtiyaç duyduğu akışlar; kart açılınca yalnız ilgili adımlar görünür. */
internal val TerminalHelpTopics = listOf(
    HelpTopic(
        "login", HelpCategory.START, "🔐", "İlk giriş",
        "Terminali bir kez bağlarsınız, sonra her vardiyada kendi kullanıcınızla girersiniz.",
        listOf(
            "Bağlantı ekranını açın. E-posta hazır gelir, doğru mu bakın.",
            "İlk kurulumda Microsoft şifrenizi yazın ve “Bağlan ve Bu Cihazı Hatırla”ya basın.",
            "Telefonunuza doğrulama kodu geliyorsa “Tarayıcıda Microsoft ile Giriş”i seçin.",
            "Ortamı ve çalışacağınız şirketi seçin.",
            "Listeden kendi depo kullanıcınızı seçip WMS şifrenizi girin.",
            "Ana menüde yeşil “Bağlı” yazısını görün. Görmeden işe başlamayın.",
        ),
        "Microsoft şifreniz cihazda tutulmaz. Bir kez girdikten sonra uygulama sonraki açılışlarda kendi bağlanır.",
        Screen.Connection,
    ),
    HelpTopic(
        "company", HelpCategory.START, "🏢", "Şirket değiştirme",
        "Yanlış şirkette çalışmak belgeleri karıştırır. Başlamadan önce üstteki şirket adına bakın.",
        listOf(
            "Ana menünün üstündeki şirket adını okuyun.",
            "Yanlışsa “Şirket Değiştir”e basın.",
            "Listede sadece yetkiniz olan şirketler çıkar.",
            "Doğru şirkete dokunun ve bağlantı yeşile dönene kadar bekleyin.",
            "Renkten de anlarsınız: Bade yeşil, BS mavi, PİM kırmızı.",
        ),
        "Şirketi değiştirdiyseniz açık kalan belgeye devam etmeyin. İşlemi yeni şirkette baştan açın.",
    ),
    HelpTopic(
        "scan", HelpCategory.START, "📷", "Barkod okutma — her ekranda aynı sıra",
        "Sıra hep aynıdır: önce nereden aldığınız, sonra ne aldığınız, en son nereye koyduğunuz.",
        listOf(
            "Ekranda renkli olan aktif alanı bulun. Okuttuğunuz oraya yazılır.",
            "Zebra'nın sarı tetiğine basın ya da ekrandaki “Tara” düğmesini kullanın.",
            "Okunan değer doğru alana geldi mi, gözünüzle kontrol edin.",
            "Lot veya seri listesi açılırsa etiketteki numarayla aynı olanı seçin.",
            "Miktara bakın. Ekranda hazır gelen sayı doğru olmayabilir; özellikle kısmi işlemde.",
            "Yeşil TAMAM yazısını görmeden sonraki ürüne geçmeyin.",
        ),
        "Aynı barkodu üst üste okutmayın. Önce ilkinin ekranda işlendiğini görün.",
    ),
    HelpTopic(
        "receiving", HelpCategory.INBOUND, "📥", "Mal kabul",
        "Gelen malı palete yerleştirip sisteme girersiniz.",
        listOf(
            "Mal Kabul ekranını açın, belgeyi listeden seçin ya da numarasını arayın.",
            "Belge sizde değilse “Bana Ata”ya basın.",
            "“LP Başlat”a basın. Sistem uygun palet şablonunu kendi seçer.",
            "Ekrandaki LP numarası ile paletteki etiket aynı mı, bakın.",
            "Ürünü okutun. Lot/seri, son kullanma tarihi ve miktarı girin.",
            "Aynı palete girecek diğer ürünleri de okutun.",
            "Palet dolunca “LP Kapat”a basın, etiketi yazdırın.",
            "Satırlar doğruysa “Mal Kabulü Kaydet”e basın.",
        ),
        "“LP Başlat” pasifse belge sizde değildir. Önce “Bana Ata”ya basın.",
        Screen.Receiving,
    ),
    HelpTopic(
        "putaway", HelpCategory.INBOUND, "📤", "Yerleştirme",
        "Mal kabulden çıkan ürünü veya paleti rafına kaldırırsınız.",
        listOf(
            "Belgeyi açın. Sizde değilse “Bana Ata”ya basın.",
            "“Al” satırında hangi raftan ne alacağınız yazar. Okuyun.",
            "Önce kaynak rafı, sonra ürün veya LP barkodunu okutun.",
            "“Yerleştir” satırındaki hedef rafı okutun.",
            "Sistemin önerdiği raf zorunlu değil. Aynı depodaki başka bir rafı da okutabilir, listeden seçebilirsiniz.",
            "Lot/seri ve miktarı kontrol edip satırı bitirin.",
            "Bütün satırlar bitince “Yerleştirmeyi Kaydet”e basın.",
        ),
        "Farklı rafa koyduysanız o rafın aynı depoda olduğundan emin olun.",
        Screen.PutAway,
    ),
    HelpTopic(
        "picking", HelpCategory.OUTBOUND, "🚚", "Toplama",
        "Sipariş için raflardan ürün toplarsınız.",
        listOf(
            "Toplama ekranında “Bana atanan” filtresini açın, belgenizi seçin.",
            "Belge boştaysa “Üzerime Al”a basın.",
            "Toplama kabı gerekiyorsa “LP Başlat” ile boş bir kap açın.",
            "Önce rafı, sonra ürünü okutun.",
            "Lot/seri listesinden etiketteki numarayı seçin.",
            "Kaç adet aldıysanız o kadar girin. Eksik aldıysanız gerçek miktarı yazın.",
            "Satırları kontrol edip “Toplamayı Kaydet”e basın.",
        ),
        "Belge başkasındaysa işlem yapamazsınız. Atamayı belge sahibi veya sorumlunuz değiştirir.",
        Screen.Picking,
    ),
    HelpTopic(
        "packing", HelpCategory.OUTBOUND, "📦", "Paketleme",
        "Toplanan ürünleri kolilere koyup siparişi kapatırsınız.",
        listOf(
            "Kuyruktan siparişi seçin.",
            "Toplama LP'sini okutun. Ekrandaki siparişle aynı mı, bakın.",
            "Yeni koli açıp koli barkodunu okutun.",
            "Ürünleri tek tek okutun. Karttaki “kalan adet” azalmalı.",
            "Koli dolunca “Kapat”a basın, gerekiyorsa yeni koli açın.",
            "Kalan sıfırlanınca “Paketlemeyi Tamamla”ya basın.",
        ),
        "Uyarı çıkarsa devam etmeyin. Yanlış LP ya da başka siparişin ürünü okunmuştur.",
        Screen.Packing,
    ),
    HelpTopic(
        "shipping", HelpCategory.OUTBOUND, "🚢", "Sevkiyat",
        "Sevkiyatı kendinize alır, eksik kalan ürün için toplama açar, sonra kaydedersiniz.",
        listOf(
            "Sevkiyat ekranında “Ambar Sevkiyatı” sekmesinden belgeyi seçin.",
            "“Bana Ata”ya basın. Bunu yapmadan diğer düğmeler açılmaz.",
            "Toplanmamış ya da eksik kalan ürün varsa “Pick Oluştur”a basın.",
            "Açık bir toplama varsa sistem onu getirir; yoksa sadece kalan miktar için yenisini açar.",
            "Toplama numarasına geçip toplamayı bitirin.",
            "Sevkiyata dönün, satırlar hazır mı bakın.",
            "İrsaliye/fatura seçimini yapıp “Sevkiyatı Kaydet”e basın.",
        ),
        "Belge üzerinize atanmadan hiçbir işlem açılmaz. İlk adım her zaman “Bana Ata”.",
        Screen.Shipping,
    ),
    HelpTopic(
        "lp", HelpCategory.LP_MOVE, "🧺", "LP (palet) oluşturma",
        "LP, içine ürün koyduğunuz paletin ya da kabın sistemdeki karşılığıdır.",
        listOf(
            "LP ekranında “LP Oluştur”a basın, şablonu seçin.",
            "Depo ve başlangıç rafını kontrol edin.",
            "Ürünü okutun; lot/seri, tarih ve miktarı girin.",
            "LP içindeki satırları listeden gözden geçirin.",
            "“Tamamla”ya basın. LP kapanır, etiket yazdırılır.",
            "Sonradan değişiklik gerekirse LP'yi yeniden açıp işiniz bitince tekrar tamamlayın.",
        ),
        "Paleti yerinden oynatmadan önce ekrandaki LP numarası ile üstündeki etiketin aynı olduğuna bakın.",
        Screen.LicensePlates,
    ),
    HelpTopic(
        "lp-partial-transfer", HelpCategory.LP_MOVE, "↗", "LP bölme ve aktarma",
        "Bir paletin tamamını ya da bir kısmını başka palete aktarırsınız.",
        listOf(
            "Tamamlanmış, içinde ürün olan LP'yi açın.",
            "Bir kısmını ayıracaksanız “Kısmi”ye basın; satırı ve miktarı seçin.",
            "Dört seçenek var: kalanı yeni LP'ye ayır, fazlayı rafta bırak, kullanılanı düş, LP'yi boz.",
            "Tamamını aktaracaksanız “Transfer”e basın.",
            "Hedef LP'yi okutun. İki LP aynı rafta olmalı.",
            "İşlem bitince iki LP'nin de miktarını yenileyip kontrol edin.",
        ),
        "Hedef LP başka raftaysa önce onu kaynak LP'nin yanına taşıyın.",
        Screen.LicensePlates,
    ),
    HelpTopic(
        "adhoc", HelpCategory.LP_MOVE, "↔", "Ad-Hoc hareket",
        "Belge olmadan, elinizle paleti veya ürünü başka yere taşırsınız.",
        listOf(
            "Ad-Hoc Hareket ekranında “LP ile” modunu seçin.",
            "Kaynak rafı okutun, sonra o raftaki LP'yi okutun veya listeden seçin.",
            "LP içeriğinin tam yüklendiğini ekranda görün.",
            "Rafa taşıyacaksanız hedef raf barkodunu okutun.",
            "Başka palete aktaracaksanız hedef LP'yi okutun — iki LP aynı rafta olmalı.",
            "Özeti kontrol edip “Hareketi Onayla”ya basın.",
            "TAMAM mesajındaki kaynak, hedef ve miktarı okuyun.",
        ),
        "Hedef LP başka raftaysa uygulama uyarır. Önce iki paleti aynı rafa getirin.",
        Screen.AdHocMove,
    ),
    HelpTopic(
        "directed", HelpCategory.LP_MOVE, "🧭", "Yönlendirilmiş hareket",
        "Ofiste hazırlanan taşıma belgesini terminalden uygularsınız.",
        listOf(
            "Ekranda “Tümü” sekmesinden belgeyi bulun.",
            "Belge boştaysa “Üzerime Al”a basın.",
            "Belgeyi açın, “Al” satırındaki rafı ve ürünü okutun.",
            "Lot/seri ve miktarı girin. Karşılığı olan “Yerleştir” satırı kendiliğinden hazırlanır.",
            "Hedef rafı okutun. İki satırın da aynı miktarı gösterdiğine bakın.",
            "Hepsi hazır olunca “Hareketi Kaydet”e bir kez basın.",
        ),
        "Kayıt sırasında bekleyin. Belge listeden kaybolduysa işlem tamamlanmıştır, tekrar basmayın.",
        Screen.DirectedMove,
    ),
    HelpTopic(
        "count", HelpCategory.COUNT, "🔢", "Sayım",
        "Raftaki gerçek miktarı sayıp sisteme yazarsınız.",
        listOf(
            "Sayım ekranından size verilen belgeyi seçin.",
            "Sayacağınız rafı okutun. O rafın satırları açılır.",
            "Ürün veya LP barkodunu okutun; lot/seri varsa doğrusunu seçin.",
            "Saydığınız miktarı girin.",
            "Hiç yoksa boş bırakmayın — “Sıfır Say” ile sıfır olduğunu bildirin.",
            "Listede olmayan ürün çıkarsa “Beklenmeyen” seçeneğiyle ekleyin.",
            "Raf bitince adresi kapatın. Bütün raflar bitince sayımı kaydedin.",
        ),
        "“Belge eksik yüklendi” uyarısı görürseniz kaydetmeyin. Önce Yenile ile bütün satırları tekrar alın.",
        Screen.Count,
    ),
    HelpTopic(
        "count-v2", HelpCategory.COUNT, "📲", "Sayım V2 (QR ile)",
        "Önceden liste hazırlanmaz. Etiketleri okutursunuz, satırlar kendiliğinden oluşur.",
        listOf(
            "Sayım V2 ekranında “Yeni V2 Sayımı” ile boş belge açın.",
            "Belgeyi seçip rafın barkodunu okutun.",
            "Ürün, lot veya LP QR etiketini okutun.",
            "Satır otomatik oluşur; miktar QR'ın içinden gelir.",
            "Etiketteki miktara bakın. Bu akışta elle miktar yazılmaz.",
            "Yanlış okuttuysanız son taramayı geri alın.",
            "Özet doğruysa “Sayım V2'yi Kaydet”e basın.",
        ),
        "Klasik sayım belgesi V2'ye çevrilmez. V2 için mutlaka “Yeni V2 Sayımı” ile boş belge açın.",
        Screen.CountV2,
    ),
    HelpTopic(
        "production", HelpCategory.OTHER, "🏭", "Üretim ve montaj",
        "Harcanan malzemeyi ve üretilen ürünü sisteme yazarsınız.",
        listOf(
            "Üretim ya da Montaj ekranında açık emri seçin.",
            "Harcanacak malzemeyi ve alındığı rafı okutun.",
            "Lot/seri ve gerçekten harcanan miktarı girin.",
            "Çıkan ürün için hedef rafı seçin; gerekiyorsa yeni LP başlatın.",
            "Üretilen miktarı girip özeti kontrol edin.",
            "Kayıt düğmesine bir kez basın ve TAMAM yazısını bekleyin.",
        ),
        target = Screen.Production,
    ),
    HelpTopic(
        "quality", HelpCategory.OTHER, "🔬", "Kalite kontrol",
        "Bloke lotları ve kalite denetimlerini sonuçlandırırsınız.",
        listOf(
            "Kalite Denetimi veya MS Kalite ekranından size düşen kaydı açın.",
            "Ürün, lot/seri ve numuneyi elinizdeki etiketle karşılaştırın.",
            "İstenen ölçümleri eksiksiz girin.",
            "Uygun / Uygun Değil kararını sadece ölçüm sonucuna göre verin.",
            "Kaydedin, sonra ilgili operasyon ekranını yenileyip blokajın kalktığını görün.",
        ),
        target = Screen.Quality,
    ),
    HelpTopic(
        "inquiry-printer", HelpCategory.OTHER, "🔎", "Sorgu, yazıcı ve hata çözme",
        "Stoğa dokunmadan bilgi bakar, yazıcı ayarlar, hataları çözersiniz.",
        listOf(
            "Ürün Sorgu: bir ürün hangi rafta, hangi lotta, kaç adet var.",
            "Bin Sorgu: bir rafta ne var.",
            "Ambar Hareketleri: son kayıtları görürsünüz, değiştiremezsiniz.",
            "Yazıcılar: etiket ve belge için ayrı ayrı varsayılan yazıcı seçin.",
            "HATA mesajı görürseniz önce Yenile deyip fiziksel durumu kontrol edin.",
            "Hata sürerse işlem adını, belge numarasını ve saati depo sorumlusuna bildirin.",
        ),
        "Ağ hatası aldığınızda Kaydet'e tekrar tekrar basmayın. Önce yenileyip işlemin geçip geçmediğine bakın.",
        Screen.ItemInquiry,
    ),
)

internal fun glyphForHelpTopic(topic: HelpTopic): WmsGlyph = when (topic.id) {
    "login" -> WmsGlyph.CONNECTION
    "company" -> WmsGlyph.LAYOUT
    "scan" -> WmsGlyph.SCAN
    "lp-partial-transfer" -> WmsGlyph.LICENSE_PLATE
    "production" -> WmsGlyph.PRODUCTION
    "quality" -> WmsGlyph.QUALITY
    "inquiry-printer" -> WmsGlyph.ITEM_SEARCH
    else -> topic.target?.let(::glyphForScreen) ?: WmsGlyph.HELP
}

@Composable
fun TerminalHelpModule(connected: Boolean, onNavigate: (Screen) -> Unit) {
    var query by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf<HelpCategory?>(null) }
    var expandedId by remember { mutableStateOf<String?>("login") }

    val visibleTopics = remember(query, selectedCategory) {
        val q = query.trim().lowercase()
        TerminalHelpTopics.filter { topic ->
            (selectedCategory == null || topic.category == selectedCategory) &&
                (q.isBlank() || listOf(topic.title, topic.summary, topic.steps.joinToString(" "), topic.tip)
                    .any { q in it.lowercase() })
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(18.dp)) {
                    Text("Nasıl Kullanılır?", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Aşağıdan yapacağınız işi seçin. Karta dokununca adımlar tek tek açılır. " +
                            "Sırayla uygulayın, atlamayın.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(15.dp))
                    Text(
                        "Hangi ekranda olursanız olun 3 kural aynı",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    Spacer(Modifier.height(9.dp))
                    GuideRule("1", "Okut", "Barkodu ekrandaki renkli alana okutun.")
                    GuideRule("2", "Kontrol et", "Gelen değer ve miktar doğru mu, gözünüzle bakın.")
                    GuideRule("3", "Onayla", "Yeşil TAMAM yazısını görmeden sonraki adıma geçmeyin.")
                }
            }
        }
        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("Ne yapacaksınız?") },
                placeholder = { Text("örn. mal kabul, sayım, LP transfer") },
                leadingIcon = {
                    WmsIcon(
                        WmsGlyph.ITEM_SEARCH,
                        MaterialTheme.colorScheme.primary,
                        Modifier.size(21.dp),
                    )
                },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                item {
                    FilterChip(
                        selected = selectedCategory == null,
                        onClick = { selectedCategory = null },
                        label = { Text("Tümü") },
                    )
                }
                items(HelpCategory.entries) { category ->
                    FilterChip(
                        selected = selectedCategory == category,
                        onClick = { selectedCategory = category },
                        label = { Text(category.label) },
                    )
                }
            }
        }
        if (visibleTopics.isEmpty()) {
            item {
                Card(Modifier.fillMaxWidth()) {
                    Text("Böyle bir konu yok. Daha kısa bir kelime yazmayı deneyin.", Modifier.padding(18.dp))
                }
            }
        }
        items(visibleTopics, key = { it.id }) { topic ->
            HelpTopicCard(
                topic = topic,
                expanded = expandedId == topic.id,
                connected = connected,
                onToggle = { expandedId = if (expandedId == topic.id) null else topic.id },
                onNavigate = onNavigate,
            )
        }
    }
}

/**
 * Üç temel kural. Eskiden yalnız "1 Okut / 2 Kontrol et / 3 Onayla" yazan küçük
 * rozetlerdi; ne demek istediği anlaşılmıyordu. Artık her kuralın yanında tek
 * cümlelik karşılığı var.
 */
@Composable
private fun GuideRule(number: String, label: String, description: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(26.dp).background(MaterialTheme.colorScheme.primary, CircleShape),
            contentAlignment = Alignment.Center,
        ) { Text(number, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold) }
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold)
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun HelpTopicCard(
    topic: HelpTopic,
    expanded: Boolean,
    connected: Boolean,
    onToggle: () -> Unit,
    onNavigate: (Screen) -> Unit,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(
            if (expanded) 1.5.dp else 1.dp,
            if (expanded) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
        ),
        modifier = Modifier.fillMaxWidth().clickable { onToggle() },
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                WmsIconBadge(
                    glyph = glyphForHelpTopic(topic),
                    color = MaterialTheme.colorScheme.primary,
                    size = 44.dp,
                    iconSize = 24.dp,
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(topic.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Text(topic.summary, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                WmsIcon(
                    WmsGlyph.CHEVRON,
                    MaterialTheme.colorScheme.primary,
                    Modifier.size(18.dp).rotate(if (expanded) -90f else 90f),
                )
            }
            if (expanded) {
                Spacer(Modifier.height(14.dp))
                topic.steps.forEachIndexed { index, step ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalAlignment = Alignment.Top) {
                        Box(
                            Modifier.size(27.dp).background(MaterialTheme.colorScheme.primary, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("${index + 1}", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(step, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    }
                }
                if (topic.tip.isNotBlank()) {
                    Spacer(Modifier.height(8.dp))
                    Surface(
                        color = Color(0xFFFFA500).copy(alpha = 0.12f),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Row(Modifier.fillMaxWidth().padding(11.dp), verticalAlignment = Alignment.Top) {
                            WmsIcon(WmsGlyph.HELP, Color(0xFFE08A00), Modifier.size(19.dp))
                            Spacer(Modifier.width(7.dp))
                            Text(topic.tip, style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f))
                        }
                    }
                }
                val target = topic.target
                if (target != null) {
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = { onNavigate(target) },
                        enabled = connected || target == Screen.Connection,
                        modifier = Modifier.fillMaxWidth().height(48.dp),
                    ) {
                        Text(if (connected || target == Screen.Connection) "${target.title} Ekranını Aç" else "Önce Bağlantı Kurun")
                    }
                }
            }
        }
    }
}
