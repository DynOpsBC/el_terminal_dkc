package com.dynops.bcwms.feature

import android.os.SystemClock
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.scanner.BarcodeIntentResolver
import com.dynops.bcwms.scanner.ScanField
import com.dynops.bcwms.ui.BottomActionBar
import com.dynops.bcwms.ui.EmptyState
import com.dynops.bcwms.ui.bcwmsStatus
import com.dynops.bcwms.ui.firstValue
import com.dynops.bcwms.ui.operatorFacingStatus
import com.dynops.bcwms.ui.rawValue
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject

/**
 * Operatör mesajının tonu. Metnin başına işaret koymak yerine rengi tondan
 * geliyor — böylece mesajlar kısa kalıyor ve tema (açık/koyu) ile uyumlu.
 */
private enum class PackTone { INFO, OK, WARN, ERR }

private data class PackMsg(val text: String = "", val tone: PackTone = PackTone.INFO)

internal fun packingStartFailureMessage(httpCode: Int): String =
    if (httpCode == 404 || httpCode == 405)
        "Paketleme servisi bu şirkette hazır değil. Sistem yöneticinize bildirin."
    else
        "Paketleme başlatılamadı. Bağlantıyı kontrol edip tekrar deneyin."

internal fun shouldAcceptPackingScan(
    currentBarcode: String,
    lastBarcode: String,
    lastScanAtMs: Long,
    nowMs: Long,
    duplicateWindowMs: Long = 250,
): Boolean = currentBarcode.isNotBlank() &&
    (!currentBarcode.equals(lastBarcode, ignoreCase = true) || nowMs - lastScanAtMs >= duplicateWindowMs)

/** Aynı fiziksel koli iki farklı siparişe bağlanamaz (sunucu da doğrular). */
internal fun packingBoxHasConflict(
    orderNo: String,
    boxBarcode: String,
    existingAssignments: Iterable<Pair<String, String>>,
): Boolean = boxBarcode.isNotBlank() && existingAssignments.any { (assignedOrder, assignedBox) ->
    !assignedOrder.equals(orderNo, ignoreCase = true) &&
        assignedBox.equals(boxBarcode, ignoreCase = true)
}

/** Koli kapama, son iyimser ürün yazımı sunucuda kesinleşmeden başlayamaz. */
internal fun packingCanCloseOrder(busy: Boolean, pendingItemWrites: Int): Boolean =
    !busy && pendingItemWrites == 0

/** Ekranda en fazla TEK satır mesaj — boşsa hiç yer kaplamaz. */
@Composable
private fun PackStatusLine(msg: PackMsg) {
    val visibleText = operatorFacingStatus(msg.text)
    if (visibleText.isBlank()) return
    val palette = bcwmsStatus()
    val color = when (msg.tone) {
        PackTone.OK -> palette.success
        PackTone.WARN -> palette.warning
        PackTone.ERR -> palette.danger
        PackTone.INFO -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Text(
        visibleText,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.Medium,
        color = color,
    )
}

/** Listede gösterilen "şimdi okutulacak" ürün — aynı ürün tek satırda toplanır. */
private data class PendingItem(val itemNo: String, val description: String, val qty: Double)

/** Koli kayıtlı LP de olabilir, harici kargo/SSCC barkodu da olabilir. */
private fun JSONObject.hasShippingBox(): Boolean =
    optString("boxLpNo").isNotBlank() || optString("boxBarcode").isNotBlank()

/**
 * İyimser paketleme için: verilen sipariş+ürünün ilk eksik satırında
 * paketlenen miktarı [delta] kadar artırıp YENİ liste döndürür (Compose'un
 * değişimi görmesi için nesneler kopyalanır).
 */
private fun bumpPackedQty(
    lines: List<JSONObject>,
    orderNo: String,
    itemNo: String,
    delta: Double,
): List<JSONObject> {
    var applied = false
    return lines.map { l ->
        if (applied) return@map l
        val matches = l.optString("sourceOrderNo").equals(orderNo, ignoreCase = true) &&
            l.optString("itemNo").equals(itemNo, ignoreCase = true) &&
            l.optDouble("qtyPacked") < l.optDouble("qtyExpected")
        if (!matches) return@map l
        applied = true
        JSONObject(l.toString()).apply {
            put("qtyPacked", (l.optDouble("qtyPacked") + delta).coerceAtMost(l.optDouble("qtyExpected")))
        }
    }
}

/**
 * ELOG pick-bazlı paketleme listesi. Her kart bir sepet (pick) — kart başlığı
 * SEPET no'su, çünkü operatörün elindeki fiziksel nesne o. Sepet/pick/sipariş
 * okutunca doğrudan belgeye girilir; liste ekranı arama için değil, sadece
 * "elimde barkod yoksa" durumu için.
 */
@Composable
fun PackingModule(v2Enabled: Boolean = false) {
    if (v2Enabled) {
        V2PackingModule()
        return
    }
    PackingQueue(flowMode = null)
}

@Composable
private fun V2PackingModule() {
    var flow by remember { mutableStateOf(OutboundFlowMode.Multi) }
    Column(Modifier.fillMaxSize()) {
        V2FlowSelector(current = flow, onSelect = { flow = it }, sectionTitle = "Paketleme türü")
        Box(Modifier.weight(1f)) { key(flow) { PackingQueue(flowMode = flow) } }
    }
}

@Composable
private fun PackingQueue(flowMode: OutboundFlowMode?) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var orders by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var selectedPick by remember { mutableStateOf<String?>(null) }
    // Kuyrukta ana LP okutularak açılan pick doğrulanmış sayılır. Karttan elle
    // girilirse belge içinde LP tekrar okutulmadan ürün adımına geçilemez.
    var lpVerifiedPick by remember { mutableStateOf<String?>(null) }
    var msg by remember { mutableStateOf(PackMsg()) }
    var loading by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }

    fun load() {
        scope.launch {
            loading = true
            msg = PackMsg("Yükleniyor…")
            val modeFilter = flowMode?.let { "&\$filter=orderFlowMode eq '${it.apiValue}'" }.orEmpty()
            val page = BcApi.getAllPages(
                context,
                "packingOrders?\$top=500&\$orderby=readyDateTime asc$modeFilter",
            )
            orders = if (page.complete) page.rows.filter {
                !rawValue(it, "status").equals("Completed", ignoreCase = true)
            } else emptyList()
            // Başarı mesajı yazmıyoruz: sayı zaten başlıkta, boş liste kendi
            // kartında. Ekranda gereksiz satır kalmasın.
            msg = when {
                page.complete -> PackMsg()
                flowMode != null && page.error?.httpCode in listOf(400, 404) ->
                    PackMsg("Paketleme kuyruğu bu şirkette kullanılamıyor. Depo sorumlusuna bildirin.", PackTone.WARN)
                else -> PackMsg("Liste alınamadı, tekrar deneyin.", PackTone.ERR)
            }
            loading = false
        }
    }
    LaunchedEffect(Unit) { load() }

    val sel = selectedPick
    if (sel != null) {
        val pickOrderCount = orders.count { it.optString("pickNo") == sel }
        PickPackingDocument(
            pickNo = sel,
            orderCount = pickOrderCount,
            flowMode = flowMode,
            lpConfirmedOnEntry = lpVerifiedPick == sel,
            onBack = { selectedPick = null; lpVerifiedPick = null; load() },
        )
        return
    }

    // Pick bazında grupla — her kart bir sepet.
    val byPick = orders.groupBy { it.optString("pickNo").ifBlank { "—" } }
    val shownPicks = if (search.isBlank()) byPick else byPick.filter { (pick, ords) ->
        pick.contains(search, ignoreCase = true) ||
            ords.any {
                it.optString("salesOrderNo").contains(search, ignoreCase = true) ||
                    it.optString("customerName").contains(search, ignoreCase = true) ||
                    // Sepet (LP) ile de bulunabilsin.
                    it.optString("mainLpNo").contains(search, ignoreCase = true)
            }
    }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        // Ekran başlığı üst çubukta ("Paketleme") zaten var — burada sadece
        // sayaç + yenile duruyor.
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (orders.isEmpty()) "" else "${byPick.size} sepet · ${orders.size} sipariş",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = { load() }, enabled = !loading) { Text(if (loading) "…" else "Yenile") }
        }
        // Paketleme yalnız toplamada kullanılan ana LP okutularak başlatılır.
        // Pick/sipariş barkoduyla giriş, yanlış fiziksel sepeti alma riskini
        // doğrulamadığı için kabul edilmez.
        ScanField(
            label = "Önce toplama sepeti LP'sini okut",
            value = search,
            onValueChange = { search = it },
            modifier = Modifier.fillMaxWidth(),
            enabled = !loading,
            onScanned = { raw ->
                val v = BarcodeIntentResolver.resolve(raw).value.trim()
                search = v
                val hit = byPick.entries.firstOrNull { (_, ords) ->
                    ords.any { it.optString("mainLpNo").equals(v, ignoreCase = true) }
                }
                if (hit != null) {
                    search = ""
                    lpVerifiedPick = hit.key
                    selectedPick = hit.key
                } else msg = PackMsg("'$v' paketleme kuyruğundaki bir toplama LP'si değil", PackTone.WARN)
            },
        )
        Spacer(Modifier.height(6.dp))
        PackStatusLine(msg)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(shownPicks.entries.toList(), key = { it.key }) { (pickNo, ords) ->
                val started = ords.any { rawValue(it, "status").contains("Progress", ignoreCase = true) }
                // Ürünlerin toplandığı sepet (LP) — operatörün elindeki nesne bu,
                // o yüzden kart başlığı. Okutunca da bu belgeye giriliyor.
                val lp = ords.firstNotNullOfOrNull {
                    it.optString("mainLpNo").takeIf { s -> s.isNotBlank() }
                }
                val packer = ords.firstNotNullOfOrNull {
                    it.optString("startedByUser").takeIf { s -> s.isNotBlank() }
                }
                // Tek satırda özet: sipariş sayısı, pick ve (varsa) paketleyen.
                val meta = buildList {
                    add("${ords.size} sipariş")
                    if (lp != null) add("Pick $pickNo")
                    if (!packer.isNullOrBlank()) add(packer)
                }.joinToString(" · ")
                val warn = bcwmsStatus().warning
                Card(
                    onClick = { lpVerifiedPick = null; selectedPick = pickNo },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(1.dp, if (started) warn else MaterialTheme.colorScheme.outline),
                ) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                if (lp != null) "Sepet $lp" else "Pick $pickNo",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                            )
                            Text(
                                meta,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        if (started) {
                            Text("başlandı", style = MaterialTheme.typography.labelSmall, color = warn)
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(
                            "›",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
            if (shownPicks.isEmpty() && !loading) item { EmptyState("Paketlenecek sepet yok.") }
        }
    }
}

/**
 * ELOG "ürün-önce" paketleme: pick'in TÜM siparişleri tek session'da toplanır.
 * Operatör sepetten eline gelen ürünü okutur; BC (ScanItem) o ürünü doğru
 * siparişe yazar. Bir siparişin payı bitince o sipariş için koli istenir;
 * kolilenince sevk+fatura kesilir.
 *
 * SADELEŞTİRME: ekranda aynı anda tek iş var — ya "ürün okut" ya "koli okut".
 * Ürün listesi sipariş sipariş değil, ÜRÜN bazında ve sadece kalanlar
 * gösterilir (biten satır listeden düşer). Sipariş dökümü en altta kapalı
 * durur, isteyen açar; böylece tamamlananlar listeyi şişirmez.
 */
@Composable
private fun PickPackingDocument(
    pickNo: String,
    orderCount: Int,
    flowMode: OutboundFlowMode? = null,
    lpConfirmedOnEntry: Boolean = false,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var sessionId by remember(pickNo) { mutableStateOf(0) }
    var lines by remember(pickNo) { mutableStateOf<List<JSONObject>>(emptyList()) }
    var linesComplete by remember(pickNo) { mutableStateOf(false) }
    // Sipariş no -> müşteri adı (packingOrders'tan; koli adımında göstermek için).
    var customerByOrder by remember(pickNo) { mutableStateOf<Map<String, String>>(emptyMap()) }
    var msg by remember(pickNo) { mutableStateOf(PackMsg()) }
    var busy by remember(pickNo) { mutableStateOf(false) }
    var itemInput by remember(pickNo) { mutableStateOf("") }
    var boxInput by remember(pickNo) { mutableStateOf("") }
    // Toplamada kullanılan ana sepet — paketleyici ürünleri nereden alacağını görsün.
    var mainLp by remember(pickNo) { mutableStateOf("") }
    var lpConfirmed by remember(pickNo) { mutableStateOf(lpConfirmedOnEntry) }
    var lpConfirmInput by remember(pickNo) { mutableStateOf("") }
    var pickDone by remember(pickNo) { mutableStateOf(false) }
    // Sipariş dökümü varsayılan KAPALI — operatörün işi ürün okutmak, sipariş
    // kırılımı sadece merak edilince açılan bir detay.
    var showOrders by remember(pickNo) { mutableStateOf(false) }
    val itemScanMutex = remember(pickNo) { Mutex() }
    var pendingItemWrites by remember(pickNo) { mutableIntStateOf(0) }
    var lastItemBarcode by remember(pickNo) { mutableStateOf("") }
    var lastItemScanAtMs by remember(pickNo) { mutableLongStateOf(0L) }

    suspend fun reloadLines(): Boolean {
        linesComplete = false
        if (sessionId <= 0) {
            lines = emptyList()
            return false
        }
        val page = BcApi.getAllPages(
            context,
            "packSessionLines?\$filter=sessionEntryNo eq $sessionId&\$top=500",
        )
        lines = page.rows
        linesComplete = page.complete
        if (!page.complete) {
            msg = PackMsg("Paketleme satırlarının tamamı alınamadı. Yenileyip tekrar deneyin.", PackTone.ERR)
        }
        return page.complete
    }

    // Müşteri adlarını packingOrders'tan (pick filtresiyle) bir kez çek.
    suspend fun loadCustomers(): Boolean {
        val safePickNo = pickNo.replace("'", "''")
        val page = BcApi.getAllPages(
            context,
            "packingOrders?\$filter=pickNo eq '$safePickNo'&\$top=500",
        )
        if (page.complete) {
            val rows = page.rows
            customerByOrder = rows.associate {
                it.optString("salesOrderNo") to it.optString("customerName")
            }
            // Ana sepet pick bazında aynı — ilk dolu değeri al.
            mainLp = rows.firstNotNullOfOrNull {
                it.optString("mainLpNo").takeIf { s -> s.isNotBlank() }
            }.orEmpty()
        }
        return page.complete
    }

    suspend fun startIfNeeded() {
        msg = PackMsg("Hazırlanıyor…")
        val me = BcApi.currentUserId(context).trim()
        if (me.isBlank()) {
            msg = PackMsg("Kullanıcı kimliği doğrulanamadı. Yeniden giriş yapın.", PackTone.ERR)
            return
        }
        val body = JSONObject().apply {
            put("pickNo", pickNo)
            put("userId", me)
            put("printerId", getDefaultPrinter(context, PRINTER_USAGE_DOCUMENT))
        }.toString()
        // V2 sekmelerinde de AYNI action kullanılır: oturum açma davranışı
        // moda göre değişmiyor (pick'in tüm siparişleri tek session'a girer),
        // fark yalnızca ekranda koli adımının sırasında. Ayrı bir
        // "startPickPackingV2" action'ı AL'de hiç yazılmamıştı; çağrı 404
        // dönüyor ve V2 sekmeleri "Hazırlanıyor…" ekranında takılı kalıyordu.
        val r = BcApi.boundAction(context, "packOps", "", "startPickPackingWithPrinter", body)
        if (r.ok) {
            sessionId = BcApi.scalarValue(r.body).toIntOrNull() ?: 0
            if (sessionId <= 0) {
                msg = PackMsg("Paketleme oturumu doğrulanamadı. Yenileyip tekrar deneyin.", PackTone.ERR)
                return
            }
            // Müşteri adları ve satırlar birbirinden bağımsız — PARALEL çek
            // (sırayla ~2 istek beklemesi oluyordu, belge açılışı yavaşlıyordu).
            val (customersOk, linesOk) = coroutineScope {
                val customers = async { loadCustomers() }
                val sessionLines = async { reloadLines() }
                customers.await() to sessionLines.await()
            }
            msg = when {
                !linesOk -> PackMsg("Paketleme satırları alınamadı. Yenileyip tekrar deneyin.", PackTone.ERR)
                !customersOk -> PackMsg("Sipariş bilgileri eksik geldi. Yenileyip tekrar deneyin.", PackTone.WARN)
                mainLp.isBlank() -> PackMsg("Toplama LP'si bulunamadı. Depo sorumlusuna bildirin.", PackTone.ERR)
                else -> PackMsg()
            }
        } else msg = PackMsg(packingStartFailureMessage(r.httpCode), PackTone.ERR)
    }

    // ELOG katı kilit: bir siparişe başlandıysa (kısmen paketli ama bitmemiş),
    // o siparişin TÜM ürünleri bitmeden başka siparişin ürünü okutulamaz.
    // activeOrder = ilk kısmen-paketli sipariş; yoksa null (serbest okutma).
    fun activeLockedOrder(): String? =
        lines.groupBy { it.optString("sourceOrderNo") }
            .entries
            .firstOrNull { (_, ords) ->
                val packed = ords.sumOf { it.optDouble("qtyPacked") }
                val expected = ords.sumOf { it.optDouble("qtyExpected") }
                packed > 0 && packed < expected
            }?.key

    // Bir siparişte kalan (bekleyen) toplam ürün adedi.
    fun orderRemaining(orderNo: String): Double =
        lines.filter { it.optString("sourceOrderNo") == orderNo }
            .sumOf { (it.optDouble("qtyExpected") - it.optDouble("qtyPacked")).coerceAtLeast(0.0) }

    // Okutulan ürünün YAZILACAĞI siparişi seç:
    // 1) Aktif (yarım) sipariş varsa → o siparişin bekleyen satırı ise oraya.
    // 2) Yoksa → ürünün bekleyen satırı olan siparişlerden TOPLAM KALANI EN AZ
    //    olan (o sipariş daha çabuk kapanır). Eşitlikte sipariş no'ya göre.
    fun targetOrderFor(itemNo: String): String? {
        val candidates = lines.filter {
            it.optString("itemNo").equals(itemNo, ignoreCase = true) &&
                it.optDouble("qtyPacked") < it.optDouble("qtyExpected")
        }.map { it.optString("sourceOrderNo") }.distinct()
        if (candidates.isEmpty()) return null
        val locked = activeLockedOrder()
        if (locked != null) return if (locked in candidates) locked else null
        // En az kalan; eşitlikte sipariş no'ya göre deterministik.
        return candidates.sortedBy { it }.minByOrNull { orderRemaining(it) }
    }

    /**
     * Ürün okut. İYİMSER: satırın kalan miktarı anında yerelde düşer (biten
     * satır listeden kalkar); BC yazımı arka planda gider. Operatör ard arda
     * okutmaya devam edebilir — hata olursa gerçek durum geri yüklenir.
     */
    fun scanItem(raw: String) {
        if (raw.isBlank() || sessionId == 0 || !lpConfirmed) return
        if (!linesComplete) {
            msg = PackMsg("Paketleme satırları eksik. Yenileyip tekrar deneyin.", PackTone.ERR)
            return
        }
        val resolved = BarcodeIntentResolver.resolve(raw)
        val itemNo = (resolved.itemNo ?: resolved.value).trim()
        val now = SystemClock.elapsedRealtime()
        if (!shouldAcceptPackingScan(itemNo, lastItemBarcode, lastItemScanAtMs, now)) return
        lastItemBarcode = itemNo
        lastItemScanAtMs = now
        val locked = activeLockedOrder()
        val target = targetOrderFor(itemNo)
        // Aktif sipariş varsa ve bu ürün ona ait değilse → kilit reddi.
        if (locked != null && target == null) {
            msg = PackMsg("Önce $locked siparişini bitir", PackTone.WARN)
            itemInput = ""
            return
        }
        if (target == null) {
            msg = PackMsg("$itemNo bu sepette kalmadı", PackTone.ERR)
            itemInput = ""
            return
        }
        // 1) Yerel düşüş — ekran anında tepki verir.
        itemInput = ""
        lines = bumpPackedQty(lines, target, itemNo, 1.0)
        msg = PackMsg("$itemNo okundu", PackTone.OK)
        pendingItemWrites += 1
        // 2) BC'ye arka planda yaz.
        scope.launch {
            // Aynı paketleme oturumundaki yazımlar BC'ye seri gider. Çok hızlı
            // taramada iki action'ın aynı satırı eşzamanlı güncellemesi önlenir.
            try {
                itemScanMutex.withLock {
                    val body = JSONObject().apply {
                        put("sessionId", sessionId)
                        put("orderNo", target)
                        put("itemNo", itemNo)
                        put("qty", 1)
                    }.toString()
                    val r = BcApi.boundAction(context, "packOps", "", "scanItemForOrder", body)
                    if (r.ok) {
                        // scanItemForOrder dönüşü: tamamlandıysa o sipariş no'su, yoksa boş.
                        val done = BcApi.scalarValue(r.body).trim()
                        if (done.isNotBlank()) {
                            // Sipariş bitti — koli kartı zaten ekranı devraldığı için
                            // ayrıca mesaj yazmıyoruz.
                            msg = PackMsg()
                            reloadLines()   // sipariş kapandı → gerçek durumu al
                        }
                    } else {
                        msg = PackMsg("Okutma kaydedilemedi. Yenileyip tekrar deneyin.", PackTone.ERR)
                        reloadLines()       // iyimser artışı geri al
                    }
                }
            } finally {
                pendingItemWrites = (pendingItemWrites - 1).coerceAtLeast(0)
            }
        }
    }

    // Siparişe KARGO KOLİSİ bağla → sevk+fatura+fiş.
    // Okutulan barkod müşteriye giden kolinin barkodudur (kargo etiketi / SSCC /
    // matbu koli barkodu); sistemde kayıtlı bir LP olmak ZORUNDA DEĞİLDİR —
    // depoda kalan sepetle (tote) karıştırılmamalı. Boş gönderilirse BC karton üretir.
    fun scanBox(orderNo: String, raw: String) {
        if (sessionId == 0 || !lpConfirmed) return
        if (!linesComplete) {
            msg = PackMsg("Paketleme satırları eksik. Yenileyip tekrar deneyin.", PackTone.ERR)
            return
        }
        if (!packingCanCloseOrder(busy, pendingItemWrites)) {
            msg = PackMsg("Son ürün kaydı tamamlanıyor. Lütfen bekleyin.", PackTone.WARN)
            return
        }
        val boxLp = BarcodeIntentResolver.resolve(raw).value.trim()
        val assignments = lines.mapNotNull { line ->
            val assigned = line.optString("boxLpNo").ifBlank { line.optString("boxBarcode") }
            assigned.takeIf { it.isNotBlank() }?.let { line.optString("sourceOrderNo") to it }
        }
        if (packingBoxHasConflict(orderNo, boxLp, assignments)) {
            boxInput = ""
            msg = PackMsg("Bu koli başka bir siparişe bağlı. Farklı koli okutun.", PackTone.ERR)
            return
        }
        // Aynı barkod timeout/çift tetik yüzünden yeniden gönderilmesin.
        // Sonucu sunucudan uzlaştıracağımız için alan isteğin başında temizlenir.
        boxInput = ""
        // Busy değerini coroutine başlamadan yükselt: iki donanım tetikleyicisi
        // aynı frame içinde gelirse aynı sipariş iki kez kapatılmasın.
        busy = true
        scope.launch {
            msg = PackMsg("$orderNo kapatılıyor…")
            val body = JSONObject().apply {
                put("sessionId", sessionId)
                put("orderNo", orderNo)
                put("boxLpNo", boxLp)
                put("lpTemplateCode", "")
            }.toString()
            val r = BcApi.boundActionLongRunning(context, "packOps", "", "setBoxForOrder", body)
            if (r.ok) {
                if (!reloadLines()) {
                    msg = PackMsg("Koli kaydı tamamlandı; güncel satırlar alınamadı. Yenileyin.", PackTone.WARN)
                    busy = false
                    return@launch
                }
                val stillOpen = lines.any {
                    it.optString("sourceOrderNo") == orderNo &&
                        it.optDouble("qtyPacked") < it.optDouble("qtyExpected")
                }
                msg = if (stillOpen)
                    PackMsg("$orderNo kolisi bağlandı — ürünleri okutun", PackTone.OK)
                else
                    PackMsg("$orderNo kapandı, faturası kesildi", PackTone.OK)
            } else {
                val err = BcApi.errorMessage(r.body)
                // İstemci timeout olmuş olsa bile BC sevk/fatura işlemini tamamlamış
                // olabilir. Tekrar post etmek yerine gerçek session satırlarını oku.
                if (!reloadLines()) {
                    msg = PackMsg("İşlemin sonucu doğrulanamadı. Yenileyip tekrar deneyin.", PackTone.WARN)
                    busy = false
                    return@launch
                }
                val orderLines = lines.filter { it.optString("sourceOrderNo") == orderNo }
                val completedOnServer = orderLines.isNotEmpty() && orderLines.all {
                    it.optBoolean("orderCompleted") ||
                        (it.optDouble("qtyPacked") >= it.optDouble("qtyExpected") && it.hasShippingBox())
                }
                if (completedOnServer) {
                    msg = PackMsg("$orderNo sunucuda kapandı, koli $boxLp doğrulandı", PackTone.OK)
                    busy = false
                    return@launch
                }
                // Satış siparişi yoksa/kapalıysa bu paketleme sunucuda
                // tamamlanamaz. Siparişi sessizce atlamak ileride tüm pick'i
                // tamamlandı gösterirdi; bu yüzden açık destek gerektiren
                // fail-closed durumda bırakılır.
                val gone = r.httpCode == 404 ||
                    err.contains("Sales Header does not exist", ignoreCase = true) ||
                    err.contains("artık açık değil", ignoreCase = true)
                if (gone) {
                    msg = PackMsg("$orderNo artık açık değil. Bu paketleme tamamlanamaz; depo sorumlusuna bildirin.", PackTone.ERR)
                } else {
                    val friendly = QcErrorParser.friendlyStatus(err, r.httpCode).removePrefix("HATA: ")
                    msg = PackMsg(friendly, PackTone.ERR)
                }
            }
            busy = false
        }
    }

    fun confirmMainLp(raw: String) {
        val scanned = BarcodeIntentResolver.resolve(raw).value.trim()
        lpConfirmInput = ""
        when {
            mainLp.isBlank() ->
                msg = PackMsg("Bu pick'te toplama LP'si bulunamadı; depo sorumlusuna bildirin.", PackTone.ERR)
            scanned.equals(mainLp, ignoreCase = true) -> {
                lpConfirmed = true
                msg = PackMsg("LP $mainLp doğrulandı — ürünleri okutun", PackTone.OK)
            }
            else ->
                msg = PackMsg("Yanlış LP: $scanned · Beklenen: $mainLp", PackTone.ERR)
        }
    }

    LaunchedEffect(pickNo) { busy = true; startIfNeeded(); busy = false }

    if (pickDone) {
        PickCompleteSummary(pickNo = pickNo, orderCount = orderCount, onBack = onBack)
        return
    }

    val byOrder = lines.groupBy { it.optString("sourceOrderNo") }
    // Koli bekleyen siparişler: tüm satırları paketlenmiş ama henüz kolisiz.
    val completedButUnboxed = if (linesComplete) byOrder.filter { (orderNo, ords) ->
        ords.isNotEmpty() &&
            ords.all { it.optDouble("qtyPacked") >= it.optDouble("qtyExpected") } &&
            ords.any { !it.hasShippingBox() }
    }.keys.toList() else emptyList()
    // Tüm akışlarda ürün önce, koli sonra: bir siparişin bütün ürünleri
    // doğrulanmadan koli okutma/oluşturma adımı gösterilmez.
    val boxNeeded = completedButUnboxed
    // Tüm satırlar paketlendi + hepsi kolilendi → pick biter.
    val allBoxed = linesComplete && lines.isNotEmpty() &&
        lines.all { it.optDouble("qtyPacked") >= it.optDouble("qtyExpected") && it.hasShippingBox() }
    LaunchedEffect(allBoxed) { if (allBoxed) { kotlinx.coroutines.delay(900); pickDone = true } }

    val totalExpected = lines.sumOf { it.optDouble("qtyExpected") }
    val totalPacked = lines.sumOf { it.optDouble("qtyPacked") }
    val activeOrder = activeLockedOrder()
    // Ekranda tek iş olsun: koli bekleyen sipariş varsa o, yoksa ürün okutma.
    val boxOrderNo = boxNeeded.firstOrNull()

    // Şimdi okutulabilecek ürünler. Kilit varsa sadece aktif siparişin kalanı
    // (diğerleri nasılsa reddedilir, listede durup kafa karıştırmasın). Aynı
    // ürünün farklı siparişlerdeki satırları tek satırda toplanır.
    val pending = lines
        .filter {
            it.optDouble("qtyPacked") < it.optDouble("qtyExpected") &&
                (activeOrder == null || it.optString("sourceOrderNo") == activeOrder)
        }
        .groupBy { it.optString("itemNo") }
        .map { (itemNo, group) ->
            PendingItem(
                itemNo = itemNo,
                description = group.first().optString("description"),
                qty = group.sumOf { (it.optDouble("qtyExpected") - it.optDouble("qtyPacked")).coerceAtLeast(0.0) },
            )
        }
        .sortedBy { it.itemNo }

    // Sipariş dökümü sırası: AKTİF önce, kapananlar en sona.
    val orderedKeys = byOrder.keys.sortedWith(
        compareByDescending<String> { it == activeOrder }
            .thenBy { k -> byOrder[k]?.all { it.hasShippingBox() } == true }
            .thenBy { k -> orderRemaining(k) }
            .thenBy { it }
    )
    val closedCount = byOrder.count { (_, ords) ->
        ords.all { it.optDouble("qtyPacked") >= it.optDouble("qtyExpected") } &&
            ords.any { it.hasShippingBox() }
    }

    Column(Modifier.fillMaxSize()) {
        // Başlıktan sipariş dökümünün sonuna kadar TEK dikey liste. Önceki
        // yapıda yalnız alt ürün listesi kayıyor ve sabit LP/başlık kartları
        // küçük ekranlarda alt içeriği görünmez bırakıyordu.
        LazyColumn(
            Modifier.weight(1f).padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item(key = "page-header") {
                Column {
            TextButton(onClick = onBack) { Text("‹ Liste") }
            if (flowMode != null) {
                V2PackFlowBanner(flowMode)
                Spacer(Modifier.height(8.dp))
            }
            // Session açılınca gerçek sipariş sayısı satırlardan; açılmadan
            // liste kartından gelen orderCount kullanılır.
            val orderCountShown = if (byOrder.isNotEmpty()) byOrder.size else orderCount
            // Tek şerit başlık: SEPET (operatörün elindeki nesne) + ilerleme.
            Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.padding(14.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                if (mainLp.isNotBlank()) "Sepet $mainLp" else "Pick $pickNo",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Text(
                                if (mainLp.isNotBlank()) "$orderCountShown sipariş · Pick $pickNo"
                                else "$orderCountShown sipariş",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Text(
                            "${packQty(totalPacked)} / ${packQty(totalExpected)}",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    LinearProgressIndicator(
                        progress = { if (totalExpected > 0) (totalPacked / totalExpected).toFloat().coerceIn(0f, 1f) else 0f },
                        modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(50)),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            PackStatusLine(msg)
            Spacer(Modifier.height(8.dp))

            if (!lpConfirmed) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    border = BorderStroke(2.dp, MaterialTheme.colorScheme.primary),
                ) {
                    Column(Modifier.fillMaxWidth().padding(16.dp)) {
                        Text(
                            "1. Toplama LP'sini doğrula",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Text(
                            "Ürünleri doğru sepetten aldığınızı doğrulamak için fiziksel sepetin LP barkodunu okutun.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(12.dp))
                        ScanField(
                            label = if (mainLp.isBlank()) "LP bilgisi yükleniyor…" else "Toplama sepeti LP'sini okut",
                            value = lpConfirmInput,
                            onValueChange = { lpConfirmInput = it },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !busy && linesComplete && mainLp.isNotBlank(),
                            onScanned = { confirmMainLp(it) },
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
            } else {
                Surface(
                    color = bcwmsStatus().success.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        "✓ LP $mainLp doğrulandı · Şimdi ürünleri okutun",
                        Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Bold,
                        color = bcwmsStatus().success,
                    )
                }
                Spacer(Modifier.height(8.dp))
            }

            // Koli adımı yokken ürün okutma alanı SABİT durur (klavye/tetik odağı
            // kaymasın). Koli adımı gelince kart listenin içine alınır — yatay
            // ekranda sabit dursaydı listeyi sıkıştırıp satırları kırpardı.
            if (lpConfirmed && linesComplete && boxOrderNo == null) {
                if (activeOrder != null) {
                    Text(
                        "Önce $activeOrder: ${packQty(orderRemaining(activeOrder))} ürün kaldı",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(Modifier.height(6.dp))
                }
                ScanField(
                    label = "Ürün okut",
                    value = itemInput,
                    onValueChange = { itemInput = it },
                    modifier = Modifier.fillMaxWidth(),
                    // İyimser okutma: arka planda BC yazımı sürerken bile
                    // operatör sonraki ürünü okutabilsin.
                    enabled = sessionId > 0 && linesComplete,
                    onScanned = { scanItem(it) },
                )
                Spacer(Modifier.height(10.dp))
            }
                }
            }
                if (!linesComplete) {
                    item(key = "incomplete-lines") {
                        EmptyState("Paketleme satırlarının tamamı alınamadı. Yenileyip tekrar deneyin.")
                    }
                } else if (!lpConfirmed) {
                    item(key = "lp-wait") { EmptyState("Önce toplama sepetinin LP'sini doğrulayın.") }
                } else if (boxOrderNo != null) {
                    item(key = "box-step") {
                        BoxForOrderCard(
                            orderNo = boxOrderNo,
                            customer = customerByOrder[boxOrderNo].orEmpty(),
                            remaining = boxNeeded.size,
                            closesOrder = orderRemaining(boxOrderNo) <= 0.0,
                            busy = !packingCanCloseOrder(busy, pendingItemWrites),
                            boxInput = boxInput,
                            onBoxInput = { boxInput = it },
                            onUseCarton = { scanBox(boxOrderNo, "") },
                            onScanBox = { scanBox(boxOrderNo, it) },
                        )
                    }
                } else {
                    items(pending, key = { it.itemNo }) { row -> PendingItemRow(row) }
                    if (pending.isEmpty() && lines.isNotEmpty()) {
                        item(key = "no-pending") { EmptyState("Okutulacak ürün kalmadı.") }
                    }
                }
                // Sipariş dökümü en altta ve kapalı: tamamlananlar dahil hepsi
                // tek satıra iner, liste şişmez.
                if (byOrder.isNotEmpty()) {
                    item(key = "orders-toggle") {
                        Surface(
                            onClick = { showOrders = !showOrders },
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Row(
                                Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    "Siparişler · $closedCount/${byOrder.size} kapandı",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.weight(1f),
                                )
                                Text(
                                    if (showOrders) "gizle" else "göster",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                    if (showOrders) {
                        items(orderedKeys, key = { "ord-$it" }) { orderNo ->
                            val ords = byOrder[orderNo].orEmpty()
                            val boxed = ords.all { it.optDouble("qtyPacked") >= it.optDouble("qtyExpected") } &&
                                ords.any { it.hasShippingBox() }
                            val remaining = orderRemaining(orderNo)
                            val state = when {
                                boxed -> "kapandı"
                                remaining <= 0.0 -> "koli bekliyor"
                                else -> "${packQty(remaining)} ürün"
                            }
                            val tone = when {
                                boxed -> PackTone.OK
                                remaining <= 0.0 -> PackTone.WARN
                                else -> PackTone.INFO
                            }
                            OrderStatusRow(
                                orderNo = orderNo,
                                customer = customerByOrder[orderNo].orEmpty(),
                                state = state,
                                tone = tone,
                                active = orderNo == activeOrder,
                            )
                        }
                    }
                }
                if (lines.isEmpty() && !busy) item(key = "empty") { EmptyState("Paketlenecek satır yok.") }
        }
        BottomActionBar {
            OutlinedButton(
                onClick = {
                    scope.launch {
                        busy = true
                        if (sessionId <= 0) {
                            startIfNeeded()
                        } else {
                            msg = if (reloadLines()) PackMsg()
                            else PackMsg("Liste yenilenemedi. Bağlantıyı kontrol edip tekrar deneyin.", PackTone.ERR)
                        }
                        busy = false
                    }
                },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Yenile") }
        }
    }
}

@Composable
private fun V2PackFlowBanner(flow: OutboundFlowMode) {
    val instruction = when (flow) {
        OutboundFlowMode.Multi -> "LP'yi doğrula → siparişin ürünlerini okut → ürünler bitince koliyi okut."
        OutboundFlowMode.Mono -> "LP'yi doğrula → ürünü okut → koliyi okut → siparişi kapat."
        OutboundFlowMode.SingleSku -> "LP'yi doğrula → ortak SKU payını okut → ürünler bitince koliyi okut."
    }
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = flow.accent.copy(alpha = 0.11f),
        border = BorderStroke(1.dp, flow.accent.copy(alpha = 0.45f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(flow.icon, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = flow.accent)
            Spacer(Modifier.width(10.dp))
            Column {
                Text("${flow.title} paketleme", fontWeight = FontWeight.Bold, color = flow.accent)
                Text(instruction, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Kalan ürün satırı — sadece "ne okutulacak" ve "kaç tane". */
@Composable
private fun PendingItemRow(row: PendingItem) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(row.itemNo, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                if (row.description.isNotBlank()) {
                    Text(
                        row.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
            }
            Spacer(Modifier.width(8.dp))
            Text(
                packQty(row.qty),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Black,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

/** Sipariş dökümündeki tek satır — no, müşteri ve durumu. */
@Composable
private fun OrderStatusRow(
    orderNo: String,
    customer: String,
    state: String,
    tone: PackTone,
    active: Boolean,
) {
    val palette = bcwmsStatus()
    val stateColor = when (tone) {
        PackTone.OK -> palette.success
        PackTone.WARN -> palette.warning
        PackTone.ERR -> palette.danger
        PackTone.INFO -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                orderNo,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (active) FontWeight.Bold else FontWeight.Normal,
                color = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            )
            if (customer.isNotBlank()) {
                Text(
                    customer,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
        }
        Text(state, style = MaterialTheme.typography.labelSmall, color = stateColor)
    }
}

/**
 * Koli adımı: sipariş paketlendi, geriye TEK iş kaldı — koliyi okut ya da
 * karton üret. Okutma alanı doğrudan görünür (eskiden "elimdeki koliyi okut"
 * için fazladan bir dokunuş gerekiyordu).
 */
@Composable
private fun BoxForOrderCard(
    orderNo: String,
    customer: String,
    remaining: Int,
    closesOrder: Boolean,
    busy: Boolean,
    boxInput: String,
    onBoxInput: (String) -> Unit,
    onUseCarton: () -> Unit,
    onScanBox: (String) -> Unit,
) {
    val palette = bcwmsStatus()
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, palette.success),
    ) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (closesOrder) "$orderNo hazır — koliyi okut" else "$orderNo için koliyi okut",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = palette.success,
                    )
                    if (customer.isNotBlank()) {
                        Text(
                            customer,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (remaining > 1) {
                    Text(
                        "+${remaining - 1} sipariş",
                        style = MaterialTheme.typography.labelSmall,
                        color = palette.warning,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            ScanField(
                label = "Koli barkodu",
                value = boxInput,
                onValueChange = onBoxInput,
                modifier = Modifier.fillMaxWidth(),
                enabled = !busy,
                onScanned = onScanBox,
            )
            // Sık yapılan hata: depoda kalan sepeti okutmak.
            Text(
                "Kargoya çıkan koli — sepet değil.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = onUseCarton,
                enabled = !busy,
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) {
                Text(
                    if (closesOrder) "Barkodsuz kapat (karton üret)" else "Barkodsuz koli oluştur",
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun PickCompleteSummary(pickNo: String, orderCount: Int, onBack: () -> Unit) {
    val palette = bcwmsStatus()
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Surface(shape = RoundedCornerShape(50), color = palette.success.copy(alpha = 0.15f)) {
            Text(
                "TAMAM",
                Modifier.padding(horizontal = 22.dp, vertical = 10.dp),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Black,
                color = palette.success,
            )
        }
        Spacer(Modifier.height(16.dp))
        Text("Paketleme bitti", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(6.dp))
        Text(
            "Pick $pickNo · $orderCount sipariş sevk edildi ve faturalandı.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(24.dp))
        Button(onClick = onBack, modifier = Modifier.fillMaxWidth().height(52.dp)) {
            Text("Listeye dön", fontWeight = FontWeight.Bold)
        }
    }
}

private fun packQty(value: Double): String =
    if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()
