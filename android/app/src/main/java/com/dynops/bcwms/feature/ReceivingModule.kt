package com.dynops.bcwms.feature

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.scanner.BarcodeIntentResolver
import com.dynops.bcwms.scanner.ScanField
import com.dynops.bcwms.ui.*
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Mal Kabul (Receiving).
 *
 * Tek bir ana ekran, 2 sekme:
 *  - "Whse Receipt": yönetilen lokasyon (BLUE/SILVER) için varolan Warehouse Receipt belgeleri
 *  - "Purchase Order": yönetilmeyen veya bypass senaryosunda Whse Receipt olmadan PO satırı doğrudan mal kabul
 *
 * Her ikisinde de qty/LP/bin set + post akışı tek dokunuşla biter.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReceivingModule() {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf(
        WmsGlyph.RECEIVING to "Ambar Mal Kabul",
        WmsGlyph.PICKING to "Satın Alma Siparişi",
    )

    Column(Modifier.fillMaxSize()) {
        TabRow(selectedTabIndex = tab) {
            tabs.forEachIndexed { i, item ->
                Tab(selected = tab == i, onClick = { tab = i }, text = { WmsTabLabel(item.first, item.second) })
            }
        }
        when (tab) {
            0 -> WhseReceiptTab()
            1 -> PurchaseOrderTab()
        }
    }
}

// ============================================================
// Tab 1: Warehouse Receipt (orijinal akış)
// ============================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WhseReceiptTab() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }
    var showAll by remember { mutableStateOf(false) }

    fun load() {
        scope.launch {
            loading = true; status = "Yükleniyor..."
            val myUser = if (showAll) "" else BcApi.currentUserId(context)
            if (!canLoadAssignedOnlyList(showAll, myUser)) {
                rows = emptyList(); loading = false
                status = "HATA: Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
                return@launch
            }
            // Arama yalnız belge no'ya değil, SATIRLARDAKİ ürün no'ya da bakar:
            // "1002" yazınca 1002'yi içeren belgeler de listede kalır. Belgeler
            // aramasız çekilir, eşleşme istemcide birleştirilir.
            val filter = com.dynops.bcwms.ui.buildODataFilter(
                com.dynops.bcwms.ui.assignedToMeClause(myUser, enabled = !showAll),
            )
            val page = BcApi.getAllPagesWithStandardFallback(context, "receipts?\$top=100&\$orderby=no desc&\$select=no,locationCode,assignedUserId,sourceNo,vendorSourceName,dueDate,percentComplete$filter")
            val all = if (page.complete) page.rows else emptyList()
            val q = search.trim()
            var itemHit = 0
            rows = if (q.isBlank()) all else {
                val itemDocsSet = com.dynops.bcwms.ui.docsContainingItem(context, "receiptLines", q)
                if (itemDocsSet == null) {
                    rows = emptyList(); loading = false
                    status = "HATA: Ürün-belge eşleşmelerinin tamamı alınamadı. Yenileyin."
                    return@launch
                }
                all.filter {
                    it.optString("no").contains(q, ignoreCase = true) ||
                        firstValue(it, "sourceNo").contains(q, ignoreCase = true) ||
                        it.optString("no") in itemDocsSet
                }.also { filtered -> itemHit = filtered.count { it.optString("no") in itemDocsSet } }
            }
            loading = false
            status = if (!page.complete) "HATA: Mal kabul listesinin tamamı alınamadı. Yenileyin."
                else if (rows.isEmpty()) (if (q.isNotBlank()) "BOŞ: '$q' ile eşleşen belge/ürün yok" else if (showAll) "BOŞ: Açık ambar mal kabul belgesi yok" else "BOŞ: Size atanmış mal kabul yok")
                else "TAMAM: ${rows.size} belge" + (if (itemHit > 0) " · 🔎 '$q' ürününü içerenler dahil" else "")
        }
    }
    LaunchedEffect(showAll) { load() }

    var itemDocs by remember { mutableStateOf<Pair<String, Set<String>>?>(null) }
    val sel = selected
    if (sel != null) { ReceiveDocument(no = sel, onBack = { selected = null; load() }); return }

    // Belge listesinde ürün okut → o ürünü içeren belgeleri bul (girme-çıkma yok).
    DocListScanHandler(
        enabled = true,
        linesEndpoint = "receiptLines",
        documentsEndpoint = "receipts",
        acceptDocTypes = setOf("receipt"),
        onDocument = { selected = it },
        onError = { status = it },
    ) { item, docs ->
        when { docs.isEmpty() -> status = "⚠️ '$item' açık belgede yok"; docs.size == 1 -> selected = docs.first(); else -> { itemDocs = item to docs; status = "TAMAM: '$item' → ${docs.size} belge" } }
    }
    val shownRows = itemDocs?.let { f -> rows.filter { it.optString("no") in f.second } } ?: rows

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { load() }, enabled = !loading) { WmsRefreshLabel(loading) }
            Spacer(Modifier.width(12.dp))
            FilterChip(selected = !showAll, onClick = { showAll = false }, label = { Text("Bana atanan") })
            Spacer(Modifier.width(6.dp))
            FilterChip(selected = showAll, onClick = { showAll = true }, label = { Text("Tümü") })
        }
        Spacer(Modifier.height(8.dp))
        com.dynops.bcwms.ui.DocSearchBar(value = search, onValueChange = { search = it }, onSearch = { load() }, label = "Mal kabul no ile ara")
        Spacer(Modifier.height(4.dp))
        StatusText(status)
        if (itemDocs != null) { ScanFilterChip("${itemDocs!!.first} → ${itemDocs!!.second.size} belge") { itemDocs = null } }
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(shownRows) { d ->
                OperationDocumentCard(
                    title = d.optString("no"),
                    metadata = "Lokasyon: ${firstValue(d, "locationCode")}  ·  Kaynak: ${firstValue(d, "sourceNo")}\nAtanan: ${rawValue(d, "assignedUserId").ifBlank { "Atanmamış" }}",
                    progressPercent = d.optInt("percentComplete"),
                    onClick = { selected = d.optString("no") },
                )
            }
            if (rows.isEmpty() && !loading) item { EmptyState(if (showAll) "Açık ambar mal kabul belgesi yok. PO'dan direkt mal kabul için sağdaki sekmeyi kullanın." else "Size atanmış mal kabul yok. Tümünü görmek için \"Tümü\" seçin.") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReceiveDocument(no: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var headerLoaded by remember { mutableStateOf(false) }
    var linesComplete by remember { mutableStateOf(false) }
    var myUserId by remember { mutableStateOf("") }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var activeLp by remember { mutableStateOf<String?>(null) }
    var printReceipt by remember(no) { mutableStateOf(false) }
    // TOPLU POST: satır onayı (PATCH receiptLines) belgeyi ASLA postlamaz —
    // yalnız "Qty. to Receive"/lot/seri/LP yazar. Post tek bir yerden, alttaki
    // butondan ve özet onayından sonra çalışır.
    var showPostConfirm by remember(no) { mutableStateOf(false) }
    // Operatörün bu oturumda onayladığı satırların Line No. kümesi. BC, belge
    // oluşturulurken "Qty. to Receive" alanını kalan miktarla ÖNCEDEN doldurduğu
    // için tek başına miktar alanı "bu satır işlendi" demek değildir; renk kodu
    // ve post aktifliği bu kümeye bakar.
    var touched by remember(no) { mutableStateOf(setOf<Int>()) }

    var showScan by remember { mutableStateOf(false) }
    var showQty by remember { mutableStateOf(false) }
    var scannedItem by remember { mutableStateOf("") }
    var scannedLine by remember { mutableStateOf<JSONObject?>(null) }
    // "Paletten ekrana": donanım tarayıcı ile okutunca ilgili satırı bul/filtrele.
    var scanFilter by remember { mutableStateOf("") }
    var scanLot by remember { mutableStateOf("") }
    var scanSerial by remember { mutableStateOf("") }
    var scanSupplierLot by remember { mutableStateOf("") }
    var scanExpiryDate by remember { mutableStateOf("") }
    // İade birleştirme: aynı ürün+bin satırlarını tek grupta göster, tek okutmada dağıt.
    var merge by remember { mutableStateOf(false) }
    var groupTarget by remember { mutableStateOf<LineGroup?>(null) }
    // Konfigüre edilebilir kolonlar (WI "Choose Columns").
    var columns by remember { mutableStateOf(ColumnPrefs.get(context, "receipt", GridColumns.receipt)) }
    var showColumns by remember { mutableStateOf(false) }

    fun reload() {
        scope.launch {
            busy = true
            header = null; lines = emptyList(); headerLoaded = false; linesComplete = false
            myUserId = BcApi.currentUserId(context).trim()
            val h = BcApi.get(context, "receipts('$no')")
            header = if (h.ok) runCatching { JSONObject(h.body) }.getOrNull() else null
            headerLoaded = header != null
            val page = BcApi.getAllPages(context, "receiptLines?\$filter=no eq '$no'&\$top=100")
            lines = page.rows
            linesComplete = page.complete
            if (!headerLoaded || !linesComplete) {
                status = "HATA: Belgenin tüm satırları yüklenemedi. Yenileyip tekrar deneyin."
            }
            busy = false
        }
    }
    LaunchedEffect(no) { reload() }

    fun action(name: String, body: String, okMsg: String, onResult: (BcApi.ApiResult) -> Unit = {}) {
        if (!canMutateAssignedDocument(header?.optString("assignedUserId").orEmpty(), myUserId)) {
            status = documentOwnershipMessage(header?.optString("assignedUserId").orEmpty(), myUserId)
            return
        }
        scope.launch {
            busy = true; status = "$name..."
            val r = BcApi.boundAction(context, "receipts", no, name, body)
            busy = false
            status = if (r.ok) "TAMAM: $okMsg (HTTP ${r.httpCode})" else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
            onResult(r)
            if (r.ok) reload()
        }
    }

    suspend fun assignReceiptLot(lineNo: Int): Result<String> {
        if (lineNo <= 0)
            return Result.failure(IllegalStateException("Mal kabul satırı belirlenemedi."))
        val safeNo = no.replace("'", "''")
        val result = BcApi.boundAction(
            context = context,
            entitySet = "receiptLines",
            key = "no='$safeNo',lineNo=$lineNo",
            action = "assignLotNo",
        )
        if (!result.ok)
            return Result.failure(
                IllegalStateException(
                    "${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})"
                )
            )
        val assigned = BcApi.scalarValue(result.body).trim()
        return if (assigned.isNotBlank()) Result.success(assigned)
        else Result.failure(IllegalStateException("BC lot numarası üretmedi."))
    }

    val h = header
    val assignedUserId = h?.optString("assignedUserId")?.trim().orEmpty()
    val canMutate = headerLoaded && linesComplete &&
        canMutateAssignedDocument(assignedUserId, myUserId)
    // Donanım tarayıcı: satırı okut → 1 eşleşme miktar ekranını açar, çok eşleşme
    // listeyi o ürüne filtreler, eşleşme yoksa uyarı. Dialog/sheet açıkken kapalı.
    DocumentScanHandler(
        enabled = canMutate && !busy && !showQty && !showScan,
        lines = lines,
        onSingleMatch = { line, r ->
            scannedItem = line.optString("itemNo"); scannedLine = line
            // BC'de satıra zaten atanmış lot/seri varsa onu kullan; yoksa barkoddan (GS1 AI) gelen değere düş.
            scanLot = line.optString("lotNo").ifBlank { r.lotNo ?: "" }
            scanSerial = line.optString("serialNo").ifBlank { r.serialNo ?: "" }
            scanSupplierLot = line.optString("supplierLotNo")
            scanExpiryDate = line.optString("expiryDate")
            scanFilter = ""
            showQty = true
        },
        onMultiMatch = { itemNo, _ -> scanFilter = itemNo; status = "TAMAM: '$itemNo' için birden fazla satır — birini seçin" },
        onNoMatch = { r -> status = "⚠️ '${r.itemNo ?: r.value}' bu belgede yok" },
    )
    val displayLines = if (scanFilter.isBlank()) lines else lines.filter { matchLinesByBarcode(listOf(it), com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(scanFilter)).isNotEmpty() }

    // Satırın kalan (henüz alınmamış) miktarı. Renk kodu bunun ne kadarının
    // girildiğine bakar: tamamı → yeşil, bir kısmı → sarı.
    val outstandingOf: (JSONObject) -> Double = { l ->
        val q = l.optDouble("quantity", 0.0); val rec = l.optDouble("qtyReceived", 0.0)
        if (q > 0) (q - rec).coerceAtLeast(0.0) else 0.0
    }
    val rowDone: (JSONObject) -> Boolean = { l ->
        val out = outstandingOf(l); val t = l.optDouble("qtyToReceive", 0.0)
        l.optInt("lineNo") in touched && t > 0.0 && (out <= 0.0 || t >= out)
    }
    val rowPartial: (JSONObject) -> Boolean = { l ->
        val out = outstandingOf(l); val t = l.optDouble("qtyToReceive", 0.0)
        l.optInt("lineNo") in touched && t > 0.0 && out > 0.0 && t < out
    }
    // Özet/aktiflik sayıları: "hazır" = operatörün miktar girdiği satır.
    val readyCount = lines.count { rowDone(it) || rowPartial(it) }
    val postLines = lines.filter { it.optInt("lineNo") in touched && it.optDouble("qtyToReceive", 0.0) > 0.0 }
    val postQty = postLines.sumOf { it.optDouble("qtyToReceive", 0.0) }

    Column(Modifier.fillMaxSize()) {
        // Belge başlığı, LP bilgisi, özet ve satırlar tek kaydırma alanında.
        // Önceden yalnız LineGrid/LazyColumn kayıyor; küçük el terminalinde
        // başlıklar ekranı kapladığında alt satırlara ulaşmak zorlaşıyordu.
        Column(
            Modifier.weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(12.dp)
        ) {
            TextButton(onClick = onBack) { Text("‹ Belge Listesi") }
            DocHeaderCard(
                title = no,
                subtitle = "Lokasyon: ${h?.optString("locationCode") ?: ""} · Kaynak: ${h?.optString("sourceNo") ?: "-"}" +
                    (activeLp?.let { "\nAktif LP: $it" } ?: ""),
                badge = rawValue(h ?: JSONObject(), "assignedUserId").ifBlank { "Atanmadı" },
                percent = h?.optDouble("percentComplete")?.toInt() ?: 0
            )
            Spacer(Modifier.height(6.dp))
            LineReadySummary(ready = readyCount, total = lines.size, stagedQty = postQty)
            Spacer(Modifier.height(6.dp))
            StatusText(status)
            if (!canMutate && headerLoaded) {
                Text(
                    documentOwnershipMessage(assignedUserId, myUserId),
                    color = bcwmsStatus().danger,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(vertical = 4.dp),
                )
            }
            Spacer(Modifier.height(4.dp))
            val capReceipt: (JSONObject) -> Double = { l ->
                val q = l.optDouble("quantity"); val rec = l.optDouble("qtyReceived")
                if (q > 0) (q - rec).coerceAtLeast(0.0) else (l.optDouble("qtyToReceive").takeIf { it > 0 } ?: 1.0)
            }
            val groups = if (merge) groupLines(displayLines, capReceipt) else emptyList()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(if (merge) "Gruplar (${groups.size})" else "Satırlar (${displayLines.size}/${lines.size})", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.weight(1f))
                if (!merge) { TextButton(onClick = { showColumns = true }) { WmsActionLabel(WmsGlyph.FIELD_SETTINGS, "Kolonlar") } }
                FilterChip(selected = merge, onClick = { merge = !merge }, label = { Text("🔗 Birleştir", fontSize = 12.sp) })
            }
            if (scanFilter.isNotBlank()) { ScanFilterChip(scanFilter) { scanFilter = "" }; Spacer(Modifier.height(4.dp)) }
            if (merge) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    groups.forEach { g ->
                        val staged = g.lines.sumOf { it.optDouble("qtyToReceive") }
                        // Grup rengi de satır kuralıyla aynı: hepsi tamamsa yeşil,
                        // bir kısmı işlendiyse sarı, hiçbiri işlenmediyse nötr.
                        val done = g.lines.isNotEmpty() && g.lines.all { rowDone(it) }
                        val partial = !done && g.lines.any { rowDone(it) || rowPartial(it) }
                        val colors = when {
                            done -> doneCardColors(true)
                            partial -> CardDefaults.cardColors(containerColor = bcwmsStatus().warning.copy(alpha = 0.18f))
                            else -> CardDefaults.cardColors()
                        }
                        Card(
                            onClick = { groupTarget = g },
                            enabled = canMutate && !busy,
                            modifier = Modifier.fillMaxWidth(),
                            colors = colors,
                        ) {
                            Column(Modifier.padding(14.dp)) {
                                Text("${donePrefix(done)}${g.itemNo} — ${g.description}", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                                Text("${g.count} satır · Toplam kalan: ${fmtNum(g.totalOutstanding)}" + if (staged > 0) " · Girilen: ${fmtNum(staged)}" else "", fontSize = 12.sp, color = Color.Gray)
                            }
                        }
                    }
                    if (groups.isEmpty() && !busy) EmptyState("Grup yok.")
                }
            } else {
                // WI-benzeri konfigüre edilebilir kolonlu grid.
                LineGrid(
                    defs = GridColumns.receipt,
                    columns = columns,
                    rows = displayLines,
                    modifier = Modifier.fillMaxWidth(),
                    isDone = rowDone,
                    isPartial = rowPartial,
                    showProgress = true,
                    expandRows = true,
                    onRowClick = { ln -> if (canMutate && !busy) {
                        scannedItem = ln.optString("itemNo"); scannedLine = ln
                        scanLot = ln.optString("lotNo"); scanSerial = ln.optString("serialNo")
                        scanSupplierLot = ln.optString("supplierLotNo")
                        scanExpiryDate = ln.optString("expiryDate")
                        showQty = true
                    } },
                )
            }
        }

        BottomActionBar {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = printReceipt, onCheckedChange = { printReceipt = it })
                Text("Mal kabul belgesi yazdır", fontSize = 13.sp)
            }
        }
        BottomActionBar {
            OutlinedButton(onClick = {
                scope.launch {
                    busy = true; status = "Atanıyor..."
                    val me = BcApi.currentUserId(context)
                    val r = if (me.isBlank()) BcApi.ApiResult(false, 0, "Kullanıcı çözülemedi")
                        else BcApi.boundAction(context, "receipts", no, "assignToUser", JSONObject().apply { put("userId", me) }.toString())
                    busy = false
                    status = if (r.ok) "TAMAM: Bana atandı (HTTP ${r.httpCode})" else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
                    if (r.ok) reload()
                }
            }, enabled = !busy && headerLoaded && linesComplete && myUserId.isNotBlank() && !canMutate, modifier = Modifier.weight(1f)) { Text("Bana Ata") }
            Button(onClick = { showScan = true }, enabled = !busy && canMutate, modifier = Modifier.weight(1f)) {
                WmsActionLabel(WmsGlyph.SCAN, "Tara")
            }
            if (activeLp == null) {
                OutlinedButton(onClick = {
                    scope.launch {
                        busy = true
                        status = "Uygun palet şablonu belirleniyor..."
                        val template = resolveLpTemplate(context, LpPurpose.PALLET)
                        if (template == null) {
                            status = "HATA: Uygun palet şablonu belirlenemedi. BC'de PALLET-EUR şablonunu kontrol edin."
                            busy = false
                            return@launch
                        }
                        val r = BcApi.boundAction(
                            context, "receipts", no, "startLP",
                            JSONObject().apply { put("lpTemplateCode", template) }.toString(),
                        )
                        val createdLp = if (r.ok) BcApi.scalarValue(r.body).trim() else ""
                        status = when {
                            !r.ok -> QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                            createdLp.isBlank() -> "HATA: LP oluşturuldu ancak numarası alınamadı. Belgeyi yenileyip kontrol edin."
                            else -> "TAMAM: $createdLp başlatıldı"
                        }
                        if (createdLp.isNotBlank()) activeLp = createdLp
                        busy = false
                        if (createdLp.isNotBlank()) reload()
                    }
                }, enabled = !busy && canMutate, modifier = Modifier.weight(1f)) { Text("LP Başlat") }
            } else {
                OutlinedButton(onClick = {
                    val lp = activeLp!!
                    action("stopLPToPrinter", JSONObject().apply {
                        put("lpNo", lp)
                        put("printLabel", true)
                        put("printerId", getDefaultPrinter(context))
                    }.toString(), "LP kapatıldı") { r ->
                        if (r.ok) activeLp = null
                    }
                }, enabled = !busy && canMutate, modifier = Modifier.weight(1f)) { Text("LP Kapat") }
            }
        }
        BottomActionBar {
            // TOPLU POST: operatör istediği kadar satırı okutur/girer, belge
            // ancak burada ve özet onayından sonra postalanır. En az bir satır
            // işlenmeden buton açılmaz (yanlışlıkla boş belge postlanmasın).
            val canPost = canMutate && readyCount > 0 && postQty > 0.0
            Button(
                onClick = { showPostConfirm = true },
                enabled = !busy && canPost,
                modifier = Modifier.fillMaxWidth().height(54.dp),
            ) {
                Text(
                    if (canPost) "Kaydet (post) — $readyCount satır" else "Önce satırlara miktar girin",
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }

    if (showPostConfirm) {
        PostConfirmDialog(
            title = "Mal kabulü kaydet",
            readyCount = readyCount,
            postLineCount = postLines.size,
            totalLineCount = lines.size,
            totalQty = postQty,
            confirmLabel = "Kaydet",
            onDismiss = { showPostConfirm = false },
            onConfirm = {
                showPostConfirm = false
                scope.launch {
                    if (!canMutateAssignedDocument(header?.optString("assignedUserId").orEmpty(), myUserId)) {
                        status = documentOwnershipMessage(header?.optString("assignedUserId").orEmpty(), myUserId)
                        return@launch
                    }
                    busy = true; status = "Mal kabul hazırlanıyor..."
                    // BC yeni belgelerde tüm satırları önceden doldurabilir. Bu
                    // oturumda okutulmayan satırları sıfırlamadan post etmek tüm
                    // belgeyi yanlışlıkla kaydeder; seri ve fail-closed ilerle.
                    var preflightOk = true
                    var resetCount = 0
                    for (line in lines.filter {
                        it.optInt("lineNo") !in touched && it.optDouble("qtyToReceive", 0.0) > 0.0
                    }) {
                        val reset = BcApi.patch(
                            context,
                            "receiptLines(no='${no.replace("'", "''")}',lineNo=${line.optInt("lineNo")})",
                            JSONObject().apply { put("qtyToReceive", 0) }.toString(),
                        )
                        if (!reset.ok) { preflightOk = false; break }
                        resetCount++
                    }
                    if (!preflightOk) {
                        busy = false
                        status = receivingPreflightFailureStatus(resetCount)
                        reload()
                        return@launch
                    }
                    val r = BcApi.boundAction(
                        context, "receipts", no, "postToPrinter",
                        JSONObject().apply {
                            put("print", printReceipt)
                            put("invoice", false)
                            put("printerId", getDefaultPrinter(context, PRINTER_USAGE_DOCUMENT))
                        }.toString(),
                    )
                    busy = false
                    status = if (r.ok) "TAMAM: Mal kabul kaydedildi."
                        else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                    if (r.ok) { touched = emptySet(); reload() }
                }
            },
        )
    }

    if (showScan) {
        ScanItemSheet(title = "Ürün Tara", onDismiss = { showScan = false }, onItem = { item, line ->
            scannedItem = item; scannedLine = line
            scanLot = line?.optString("lotNo") ?: ""; scanSerial = line?.optString("serialNo") ?: ""
            scanSupplierLot = line?.optString("supplierLotNo") ?: ""
            scanExpiryDate = line?.optString("expiryDate") ?: ""
            showScan = false; showQty = true
        }, lines = lines, matchKey = "itemNo")
    }
    if (showQty) {
        val line = scannedLine
        QuantityDialogSheet(
            title = "Alınan Miktar",
            itemNo = scannedItem,
            initialQty = line?.optDouble("qtyToReceive")?.takeIf { it > 0 } ?: 1.0,
            initialUom = line?.optString("unitOfMeasureCode") ?: "",
            initialLot = scanLot,
            initialSerial = scanSerial,
            initialSupplierLot = scanSupplierLot,
            initialExpiryDate = scanExpiryDate,
            showSupplierLot = line?.optBoolean("lotRequired") == true,
            supplierLotRequired = false,
            lotRequired = line?.optBoolean("lotRequired") == true,
            serialRequired = line?.optBoolean("serialRequired") == true,
            showExpiryDate = line?.optBoolean("expirationDateEnabled") == true,
            expiryDateRequired = line?.optBoolean("expirationDateRequired") == true,
            onAssignLotNo = if (line?.optBoolean("lotRequired") == true) {
                { assignReceiptLot(line.optInt("lineNo")) }
            } else null,
            onDismiss = {
                showQty = false
                scanLot = ""; scanSerial = ""; scanSupplierLot = ""; scanExpiryDate = ""
            },
            onConfirm = { res ->
                showQty = false
                scanLot = ""; scanSerial = ""; scanSupplierLot = ""; scanExpiryDate = ""
                val ln = scannedLine
                if (ln == null) { status = "HATA: Satır eşleşmedi — listeden seçin"; return@QuantityDialogSheet }
                if (!canMutate) { status = documentOwnershipMessage(assignedUserId, myUserId); return@QuantityDialogSheet }
                scope.launch {
                    busy = true; status = "Satır güncelleniyor..."
                    val body = JSONObject().apply {
                        put("qtyToReceive", res.quantity)
                        if (res.lotNo.isNotBlank()) put("lotNo", res.lotNo)
                        if (res.serialNo.isNotBlank()) put("serialNo", res.serialNo)
                        if (res.supplierLotNo.isNotBlank()) put("supplierLotNo", res.supplierLotNo)
                        if (res.expiryDate.isNotBlank()) put("expiryDate", res.expiryDate)
                        activeLp?.let { put("licensePlateNo", it) }
                    }.toString()
                    val lineNo = ln.optInt("lineNo")
                    val r = BcApi.patch(context, "receiptLines(no='$no',lineNo=$lineNo)", body)
                    busy = false
                    status = if (r.ok) "TAMAM: Satır güncellendi (HTTP ${r.httpCode})" else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
                    // Satır işlendi olarak işaretlenir (post YOK) — grid'de yeşil/sarı
                    // olması ve toplu post'un açılması bu kayda bağlı.
                    if (r.ok) { touched = touched + lineNo; reload() }
                }
            }
        )
    }
    val gt = groupTarget
    if (gt != null) {
        val groupRequiresLot = gt.lines.any { it.optBoolean("lotRequired") }
        val groupRequiresSerial = gt.lines.any { it.optBoolean("serialRequired") }
        val groupUsesExpiryDate = gt.lines.any { it.optBoolean("expirationDateEnabled") }
        val groupRequiresExpiryDate = gt.lines.any { it.optBoolean("expirationDateRequired") }
        val firstGroupLine = gt.lines.first()
        val capReceipt: (JSONObject) -> Double = { l ->
            val q = l.optDouble("quantity"); val rec = l.optDouble("qtyReceived")
            if (q > 0) (q - rec).coerceAtLeast(0.0) else (l.optDouble("qtyToReceive").takeIf { it > 0 } ?: 1.0)
        }
        QuantityDialogSheet(
            title = "İade Miktarı (${gt.count} satıra dağıtılır)",
            itemNo = gt.itemNo,
            initialQty = gt.totalOutstanding.takeIf { it > 0 } ?: 1.0,
            initialUom = gt.lines.first().optString("unitOfMeasureCode"),
            initialLot = gt.lines.first().optString("lotNo"),
            initialSerial = gt.lines.first().optString("serialNo"),
            initialSupplierLot = gt.lines.firstNotNullOfOrNull {
                it.optString("supplierLotNo").takeIf(String::isNotBlank)
            }.orEmpty(),
            initialExpiryDate = gt.lines.firstNotNullOfOrNull {
                it.optString("expiryDate").takeIf(String::isNotBlank)
            }.orEmpty(),
            showSupplierLot = groupRequiresLot,
            supplierLotRequired = false,
            lotRequired = groupRequiresLot,
            serialRequired = groupRequiresSerial,
            showExpiryDate = groupUsesExpiryDate,
            expiryDateRequired = groupRequiresExpiryDate,
            onAssignLotNo = if (groupRequiresLot) {
                { assignReceiptLot(firstGroupLine.optInt("lineNo")) }
            } else null,
            onDismiss = { groupTarget = null },
            onConfirm = { res ->
                groupTarget = null
                if (!canMutate) { status = documentOwnershipMessage(assignedUserId, myUserId); return@QuantityDialogSheet }
                scope.launch {
                    busy = true; status = "Grup dağıtılıyor..."
                    val plan = distributeQty(gt, res.quantity, capReceipt)
                    var okCount = 0
                    val okLines = mutableSetOf<Int>()
                    var firstError = ""
                    for ((ln, q) in plan) {
                        val body = JSONObject().apply {
                            put("qtyToReceive", q)
                            if (res.lotNo.isNotBlank()) put("lotNo", res.lotNo)
                            if (res.serialNo.isNotBlank()) put("serialNo", res.serialNo)
                            if (res.supplierLotNo.isNotBlank()) put("supplierLotNo", res.supplierLotNo)
                            if (res.expiryDate.isNotBlank()) put("expiryDate", res.expiryDate)
                            activeLp?.let { put("licensePlateNo", it) }
                        }.toString()
                        val r = BcApi.patch(context, "receiptLines(no='$no',lineNo=${ln.optInt("lineNo")})", body)
                        if (r.ok) {
                            okCount++
                            okLines.add(ln.optInt("lineNo"))
                        } else {
                            firstError = QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                            break
                        }
                    }
                    touched = touched + okLines
                    busy = false
                    status = if (okCount == plan.size)
                        "TAMAM: $okCount/${plan.size} satıra dağıtıldı (toplam ${fmtNum(res.quantity)})"
                    else if (okCount > 0)
                        "UYARI: $okCount/${plan.size} satır yazıldı; kalan satırlar başarısız. $firstError"
                    else firstError.ifBlank { "HATA: Grup satırları güncellenemedi." }
                    reload()
                }
            }
        )
    }
    if (showColumns) {
        ChooseColumnsSheet(
            defs = GridColumns.receipt,
            initial = columns,
            onDismiss = { showColumns = false },
            onSave = { newCols -> columns = newCols; ColumnPrefs.save(context, "receipt", newCols); showColumns = false },
        )
    }
}

private fun fmtNum(v: Double): String = if (v == v.toLong().toDouble()) v.toLong().toString() else v.toString()

/**
 * Belge üstü toplu-post özeti: kaç satır hazır ve kaydedilecek toplam miktar.
 * Operatör satırları tek tek girerken belgenin bütününde nerede olduğunu
 * görsün diye başlığın hemen altında durur.
 */
@Composable
private fun LineReadySummary(ready: Int, total: Int, stagedQty: Double) {
    val palette = bcwmsStatus()
    Surface(
        color = if (ready > 0) palette.success.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                "$ready/$total satır hazır",
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
                color = if (ready > 0) palette.success else MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.weight(1f))
            Text("Kaydedilecek miktar: ${fmtNum(stagedQty)}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/**
 * Post öncesi özet onayı. Post geri alınamadığı için operatör ne kadarını
 * kaydettiğini rakamla görmeden ilerleyemesin. [postLineCount] BC'nin gerçekten
 * kaydedeceği satır sayısıdır — miktar alanı BC tarafından önceden doldurulmuş
 * (operatörün dokunmadığı) satırlar da buna dahildir, o fark ayrıca uyarılır.
 */
@Composable
private fun PostConfirmDialog(
    title: String,
    readyCount: Int,
    postLineCount: Int,
    totalLineCount: Int,
    totalQty: Double,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val palette = bcwmsStatus()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title, fontWeight = FontWeight.Bold) },
        text = {
            Column {
                Text("İşlediğiniz satır: $readyCount/$totalLineCount", fontSize = 14.sp)
                Text("Kaydedilecek satır: $postLineCount", fontSize = 14.sp)
                Text("Toplam miktar: ${fmtNum(totalQty)}", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                val extra = postLineCount - readyCount
                if (extra > 0) {
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Dikkat: $extra satırda miktar sizin girişiniz olmadan dolu (BC varsayılanı) ve bunlar da kaydedilecek.",
                        fontSize = 12.sp,
                        color = palette.warning,
                    )
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    "Kayıt, belgeyi Business Central'da postalar ve geri alınamaz.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
        confirmButton = { Button(onClick = onConfirm) { Text(confirmLabel, fontWeight = FontWeight.Bold) } },
        dismissButton = { OutlinedButton(onClick = onDismiss) { Text("Vazgeç") } },
    )
}

// ============================================================
// Tab 2: Purchase Order direct receive
// ============================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PurchaseOrderTab() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var releasedOnly by remember { mutableStateOf(true) }
    var search by remember { mutableStateOf("") }

    fun load() {
        scope.launch {
            loading = true; status = "Yükleniyor..."
            // PDF §3: belge no arama yoktu. Arama artık belge no + satıcı adı +
            // SATIRLARDAKİ ürün no'ya bakar ("1002" → 1002 içeren PO'lar).
            val filter = if (releasedOnly) "&\$filter=status eq 'Released'" else ""
            val page = BcApi.getAllPages(
                context,
                "purchaseSources?\$top=100&\$orderby=no desc$filter&\$select=no,vendorNo,vendorName,locationCode,expectedReceiptDate,status,lineCount,outstandingQty,percentComplete,requiresWhseReceipt,directReceiveAllowed"
            )
            val all = if (page.complete) page.rows else emptyList()
            val q = search.trim()
            var itemHit = 0
            rows = if (q.isBlank()) all else {
                val itemDocsSet = com.dynops.bcwms.ui.docsContainingItem(context, "purchaseSourceLines", q)
                if (itemDocsSet == null) {
                    rows = emptyList(); loading = false
                    status = "HATA: Ürün-sipariş eşleşmelerinin tamamı alınamadı. Yenileyin."
                    return@launch
                }
                all.filter {
                    it.optString("no").contains(q, ignoreCase = true) ||
                        firstValue(it, "vendorName").contains(q, ignoreCase = true) ||
                        firstValue(it, "vendorNo").contains(q, ignoreCase = true) ||
                        it.optString("no") in itemDocsSet
                }.also { filtered -> itemHit = filtered.count { it.optString("no") in itemDocsSet } }
            }
            loading = false
            status = if (!page.complete) "HATA: Satınalma siparişi listesinin tamamı alınamadı. Yenileyin."
                else if (rows.isEmpty()) (if (q.isNotBlank()) "BOŞ: '$q' ile eşleşen sipariş/ürün yok" else "BOŞ: ${if (releasedOnly) "serbest bırakılmış" else "açık"} satınalma siparişi yok")
                else "TAMAM: ${rows.size} satınalma siparişi" + (if (itemHit > 0) " · 🔎 '$q' ürününü içerenler dahil" else "")
        }
    }
    LaunchedEffect(releasedOnly) { load() }

    var itemDocs by remember { mutableStateOf<Pair<String, Set<String>>?>(null) }
    val sel = selected
    if (sel != null) { ReceivePurchaseOrder(no = sel, onBack = { selected = null; load() }); return }

    DocListScanHandler(
        enabled = true,
        linesEndpoint = "purchaseSourceLines",
        documentsEndpoint = "purchaseSources",
        acceptDocTypes = setOf("purchaseOrder"),
        onDocument = { selected = it },
        onError = { status = it },
    ) { item, docs ->
        when { docs.isEmpty() -> status = "⚠️ '$item' açık PO'da yok"; docs.size == 1 -> selected = docs.first(); else -> { itemDocs = item to docs; status = "TAMAM: '$item' → ${docs.size} PO" } }
    }
    val shownRows = itemDocs?.let { f -> rows.filter { it.optString("no") in f.second } } ?: rows

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { load() }, enabled = !loading) { WmsRefreshLabel(loading) }
            Spacer(Modifier.width(12.dp))
            FilterChip(
                selected = releasedOnly,
                onClick = { releasedOnly = !releasedOnly },
                label = { Text(if (releasedOnly) "Sadece Serbest" else "Tüm Durumlar", fontSize = 12.sp) }
            )
        }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            singleLine = true,
            label = { Text("PO no ile ara (örn: 106040)") },
            trailingIcon = {
                TextButton(onClick = { load() }) {
                    WmsIcon(WmsGlyph.ITEM_SEARCH, MaterialTheme.colorScheme.primary, Modifier.size(21.dp))
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(4.dp))
        StatusText(status)
        if (itemDocs != null) { ScanFilterChip("${itemDocs!!.first} → ${itemDocs!!.second.size} PO") { itemDocs = null } }
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(shownRows) { d ->
                val requiresWhse = d.optBoolean("requiresWhseReceipt", false)
                Card(onClick = { selected = d.optString("no") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(10.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(d.optString("no"), fontWeight = FontWeight.Bold)
                            Row {
                                if (requiresWhse) Text("⚠ Ambar Girişi", fontSize = 11.sp, color = Color(0xFFD97706), modifier = Modifier.padding(end = 6.dp))
                                Text(firstValue(d, "status"), fontSize = 12.sp, color = Color.Gray)
                            }
                        }
                        Text("Tedarikçi: ${firstValue(d, "vendorName")} (${firstValue(d, "vendorNo")})", fontSize = 12.sp, color = Color.Gray)
                        Text("Lokasyon: ${firstValue(d, "locationCode")} · Satır: ${d.optInt("lineCount")} · Kalan: ${d.optDouble("outstandingQty")}", fontSize = 12.sp, color = Color.Gray)
                        val pct = d.optInt("percentComplete")
                        if (pct > 0) LinearProgressIndicator(progress = { pct / 100f }, modifier = Modifier.fillMaxWidth().padding(top = 4.dp))
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("Uygun satınalma siparişi yok.") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReceivePurchaseOrder(no: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var headerLoaded by remember { mutableStateOf(false) }
    var linesComplete by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var invoiceToo by remember { mutableStateOf(false) }
    var qtyLine by remember { mutableStateOf<JSONObject?>(null) }
    var showScan by remember { mutableStateOf(false) }
    var scanFilter by remember { mutableStateOf("") }
    // TOPLU POST (bkz. Ambar Mal Kabul): satır PATCH'i belgeyi postlamaz, kayıt
    // yalnız alttaki butondan + özet onayından sonra çalışır.
    var showPostConfirm by remember(no) { mutableStateOf(false) }
    // Operatörün bu oturumda miktar girdiği PO satırları (Line No.).
    var touched by remember(no) { mutableStateOf(setOf<Int>()) }
    // Ambar Mal Kabul'deki gibi konfigüre edilebilir kolonlar (kendi tercihi:
    // PO satırlarının alan adları farklı olduğu için ayrı kolon seti + ayrı anahtar).
    var columns by remember { mutableStateOf(ColumnPrefs.get(context, "purchaseOrder", GridColumns.purchaseOrder)) }
    var showColumns by remember { mutableStateOf(false) }

    fun reload(statusAfterReload: String? = null) {
        scope.launch {
            busy = true
            header = null; lines = emptyList(); headerLoaded = false; linesComplete = false
            // Başlık ve satırlar bağımsız — paralel çek.
            coroutineScope {
                val hJob = async { BcApi.get(context, "purchaseSources('$no')") }
                val lJob = async { BcApi.getAllPages(context, "purchaseSourceLines?\$filter=no eq '$no' and type eq 'Item'&\$top=200&\$orderby=lineNo") }
                val h = hJob.await()
                header = if (h.ok) runCatching { JSONObject(h.body) }.getOrNull() else null
                headerLoaded = header != null
                val l = lJob.await()
                lines = l.rows
                linesComplete = l.complete
            }
            status = when {
                statusAfterReload != null && (!headerLoaded || !linesComplete) ->
                    "$statusAfterReload Ayrıca güncel siparişin tüm satırları yüklenemedi; tekrar yenileyin."
                statusAfterReload != null -> statusAfterReload
                !headerLoaded || !linesComplete ->
                    "HATA: Siparişin tüm satırları yüklenemedi. Yenileyip tekrar deneyin."
                else -> status
            }
            busy = false
        }
    }
    LaunchedEffect(no) { reload() }

    val h = header
    val trackingRequiresWarehouse = lines.any {
        it.optBoolean("lotRequired", false) || it.optBoolean("serialRequired", false)
    }
    val directAllowed = headerLoaded && linesComplete &&
        (h?.optBoolean("directReceiveAllowed", false) == true) &&
        !trackingRequiresWarehouse
    DocumentScanHandler(
        enabled = qtyLine == null && !showScan,
        lines = lines,
        onSingleMatch = { line, _ -> if (directAllowed) { scanFilter = ""; qtyLine = line } },
        onMultiMatch = { itemNo, _ -> scanFilter = itemNo; status = "TAMAM: '$itemNo' için birden fazla satır — birini seçin" },
        onNoMatch = { r -> status = "⚠️ '${r.itemNo ?: r.value}' bu PO'da yok" },
    )
    val displayLines = if (scanFilter.isBlank()) lines else lines.filter { matchLinesByBarcode(listOf(it), com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(scanFilter)).isNotEmpty() }

    // Satır durumu: PO satırında kalan miktar "outstandingQuantity" alanından
    // gelir; girilen miktar kalanın tamamını kapatıyorsa yeşil, bir kısmını
    // kapatıyorsa sarı, operatör dokunmadıysa nötr.
    val rowDone: (JSONObject) -> Boolean = { l ->
        val out = l.optDouble("outstandingQuantity", 0.0); val t = l.optDouble("qtyToReceive", 0.0)
        l.optInt("lineNo") in touched && t > 0.0 && (out <= 0.0 || t >= out)
    }
    val rowPartial: (JSONObject) -> Boolean = { l ->
        val out = l.optDouble("outstandingQuantity", 0.0); val t = l.optDouble("qtyToReceive", 0.0)
        l.optInt("lineNo") in touched && t > 0.0 && out > 0.0 && t < out
    }
    val readyCount = lines.count { rowDone(it) || rowPartial(it) }
    val postLines = lines.filter { it.optInt("lineNo") in touched && it.optDouble("qtyToReceive", 0.0) > 0.0 }
    val postQty = postLines.sumOf { it.optDouble("qtyToReceive", 0.0) }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(12.dp)
        ) {
            TextButton(onClick = onBack) { Text("‹ PO Listesi") }
            DocHeaderCard(
                title = no,
                subtitle = "Tedarikçi: ${firstValue(h ?: JSONObject(), "vendorName")} (${firstValue(h ?: JSONObject(), "vendorNo")})\n" +
                    "Lokasyon: ${firstValue(h ?: JSONObject(), "locationCode")} · Durum: ${firstValue(h ?: JSONObject(), "status")}",
                percent = h?.optDouble("percentComplete")?.toInt() ?: 0
            )
            if (h != null && !directAllowed) {
                Spacer(Modifier.height(8.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)),
                ) {
                    Text(
                        if (trackingRequiresWarehouse)
                            "Bu siparişte lot/seri izlemeli ürün var. Lot ve seri kaydını korumak için Ambar Mal Kabul ekranındaki belgeyi kullanın."
                        else "Bu lokasyon (${firstValue(h, "locationCode")}) için Ambar Mal Kabul belgesi zorunlu. İlgili belgeyi Ambar Mal Kabul ekranından tamamlayın.",
                        modifier = Modifier.padding(10.dp),
                        fontSize = 12.sp,
                        color = Color(0xFF92400E),
                    )
                }
            }
            Spacer(Modifier.height(6.dp))
            LineReadySummary(ready = readyCount, total = lines.size, stagedQty = postQty)
            Spacer(Modifier.height(6.dp))
            StatusText(status)
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Satırlar (${displayLines.size}/${lines.size}) — qty/bin için dokunun", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                if (scanFilter.isNotBlank()) { Spacer(Modifier.width(8.dp)); ScanFilterChip(scanFilter) { scanFilter = "" } }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { showColumns = true }) { Text("Kolonlar", fontSize = 12.sp) }
            }
            if (displayLines.isEmpty() && !busy) {
                EmptyState(if (scanFilter.isNotBlank()) "Filtreyle eşleşen satır yok." else "Bu PO'da satır yok (veya tümü tamamlandı).")
            } else {
                // Ambar Mal Kabul ile aynı konfigüre edilebilir kolonlu grid.
                LineGrid(
                    defs = GridColumns.purchaseOrder,
                    columns = columns,
                    rows = displayLines,
                    modifier = Modifier.fillMaxWidth(),
                    isDone = rowDone,
                    isPartial = rowPartial,
                    showProgress = true,
                    expandRows = true,
                    onRowClick = { ln -> if (directAllowed) qtyLine = ln },
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = invoiceToo, onCheckedChange = { invoiceToo = it })
                Text("Aynı zamanda faturalandır", fontSize = 13.sp)
            }
        }

        BottomActionBar {
            OutlinedButton(onClick = { showScan = true }, enabled = !busy && directAllowed, modifier = Modifier.weight(1f)) {
                WmsActionLabel(WmsGlyph.SCAN, "Ürün Tara")
            }
        }
        BottomActionBar {
            // TOPLU POST: en az bir satır işlenmeden kayıt açılmaz.
            val canPost = headerLoaded && linesComplete && directAllowed && readyCount > 0 && postQty > 0.0
            Button(
                onClick = { showPostConfirm = true },
                enabled = !busy && canPost,
                modifier = Modifier.fillMaxWidth().height(54.dp),
            ) {
                Text(
                    when {
                        !directAllowed -> "Doğrudan mal kabul kapalı"
                        readyCount == 0 -> "Önce satırlara miktar girin"
                        invoiceToo -> "Kaydet ve Faturala — $readyCount satır"
                        else -> "Kaydet (post) — $readyCount satır"
                    },
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }

    if (showPostConfirm) {
        PostConfirmDialog(
            title = if (invoiceToo) "Mal kabul + fatura kaydı" else "PO mal kabulünü kaydet",
            readyCount = readyCount,
            postLineCount = postLines.size,
            totalLineCount = lines.size,
            totalQty = postQty,
            confirmLabel = if (invoiceToo) "Kaydet ve Faturala" else "Kaydet",
            onDismiss = { showPostConfirm = false },
            onConfirm = {
                showPostConfirm = false
                scope.launch {
                    busy = true; status = "Mal kabul hazırlanıyor..."
                    var preflightOk = true
                    var resetCount = 0
                    for (line in lines.filter {
                        it.optInt("lineNo") !in touched && it.optDouble("qtyToReceive", 0.0) > 0.0
                    }) {
                        val reset = BcApi.patch(
                            context,
                            "purchaseSourceLines(documentType='Order',no='${no.replace("'", "''")}',lineNo=${line.optInt("lineNo")})",
                            JSONObject().apply { put("qtyToReceive", 0) }.toString(),
                        )
                        if (!reset.ok) { preflightOk = false; break }
                        resetCount++
                    }
                    if (!preflightOk) {
                        val failureStatus = receivingPreflightFailureStatus(resetCount)
                        status = failureStatus
                        reload(statusAfterReload = failureStatus)
                        return@launch
                    }
                    status = "Mal kabul kaydı..."
                    val body = JSONObject().apply { put("invoice", invoiceToo) }.toString()
                    val r = BcApi.boundAction(context, "purchaseSources", no, "receive", body)
                    busy = false
                    status = if (r.ok) "TAMAM: Satınalma mal kabulü kaydedildi."
                        else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                    if (r.ok) { touched = emptySet(); reload() }
                }
            },
        )
    }

    val ql = qtyLine
    if (ql != null) {
        QuantityDialogSheet(
            title = "Alınacak Miktar",
            itemNo = ql.optString("itemNo"),
            initialQty = ql.optDouble("qtyToReceive").takeIf { it > 0 }
                ?: ql.optDouble("outstandingQuantity").takeIf { it > 0 } ?: 1.0,
            initialUom = ql.optString("unitOfMeasureCode"),
            // Doğrudan satınalma satırı Reservation Entry lot/seri takibini
            // taşımaz. Takipli satırlar yukarıdaki directAllowed kapısıyla
            // Ambar Mal Kabul akışına yönlendirilir; burada kaybolacak alanı gösterme.
            showLotSerial = false,
            onDismiss = { qtyLine = null },
            onConfirm = { res ->
                qtyLine = null
                scope.launch {
                    busy = true; status = "Satır güncelleniyor..."
                    val lineNo = ql.optInt("lineNo")
                    val body = JSONObject().apply {
                        put("qtyToReceive", res.quantity)
                    }.toString()
                    val r = BcApi.patch(
                        context,
                        "purchaseSourceLines(documentType='Order',no='$no',lineNo=$lineNo)",
                        body
                    )
                    busy = false
                    status = if (r.ok) "TAMAM: Satır miktarı güncellendi."
                        else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                    // Satır işlendi (post YOK) — renk kodu ve toplu post aktifliği buna bağlı.
                    if (r.ok) { touched = touched + lineNo; reload() }
                }
            }
        )
    }

    if (showScan) {
        ScanItemSheet(title = "Ürün Tara (PO)", onDismiss = { showScan = false }, onItem = { _, line ->
            showScan = false
            qtyLine = line
        }, lines = lines, matchKey = "itemNo")
    }
    if (showColumns) {
        ChooseColumnsSheet(
            defs = GridColumns.purchaseOrder,
            initial = columns,
            onDismiss = { showColumns = false },
            onSave = { newCols -> columns = newCols; ColumnPrefs.save(context, "purchaseOrder", newCols); showColumns = false },
        )
    }
}

/** Generic scan sheet that tries to match the scanned item against existing lines. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanItemSheet(
    title: String,
    onDismiss: () -> Unit,
    onItem: (item: String, line: JSONObject?) -> Unit,
    lines: List<JSONObject> = emptyList(),
    matchKey: String = "itemNo",
) {
    var item by remember { mutableStateOf("") }
    var hint by remember { mutableStateOf("") }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(12.dp))
        ScanField("Ürün No.", item, { item = it }, modifier = Modifier.fillMaxWidth(), onScanned = { raw ->
            val resolved = BarcodeIntentResolver.resolve(raw)
            item = resolved.itemNo ?: raw
            hint = "Okutuldu: ${resolved.value}"
        })
        if (hint.isNotBlank()) { Spacer(Modifier.height(6.dp)); Text(hint, fontSize = 12.sp, color = Color.Gray) }
        Spacer(Modifier.height(16.dp))
        Button(enabled = item.isNotBlank(), modifier = Modifier.fillMaxWidth(), onClick = {
            val match = lines.firstOrNull { it.optString(matchKey).equals(item.trim(), ignoreCase = true) }
            onItem(item.trim(), match)
        }) { Text("Devam") }
        Spacer(Modifier.height(24.dp))
    }
}
