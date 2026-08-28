package com.dynops.bcwms.feature

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import com.dynops.bcwms.scanner.BarcodeKind
import androidx.compose.foundation.clickable
import com.dynops.bcwms.scanner.ScanField
import com.dynops.bcwms.ui.DocHeaderCard
import com.dynops.bcwms.ui.DocSearchBar
import com.dynops.bcwms.ui.EmptyState
import com.dynops.bcwms.ui.QuantityDialogSheet
import com.dynops.bcwms.ui.StatusText
import com.dynops.bcwms.ui.WmsRefreshLabel
import com.dynops.bcwms.ui.buildODataFilter
import com.dynops.bcwms.ui.firstValue
import com.dynops.bcwms.ui.searchClause
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

private data class PendingCountV2Scan(
    val scanId: String,
    val binCode: String,
    val label: CountV2Label,
)

private data class CompletedCountV2Scan(
    val scanId: String,
    val binCode: String,
    val label: CountV2Label,
)

/** LP okutması: LP içeriği sunucuda satırlara açıldı; geri alma LP bazında yapılır. */
private data class CompletedCountV2Lp(val lpNo: String, val binCode: String)

@Composable
fun CountV2Module() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }
    var backendReady by remember { mutableStateOf(false) }
    var showCreate by remember { mutableStateOf(false) }
    var newLocation by remember { mutableStateOf("") }
    var creating by remember { mutableStateOf(false) }
    val visibleRows = remember(rows, search) {
        val query = search.trim()
        if (query.isBlank()) rows
        else rows.filter { sheet ->
            sheet.optString("no").contains(query, ignoreCase = true) ||
                sheet.optString("locationCode").contains(query, ignoreCase = true) ||
                sheet.optString("status").contains(query, ignoreCase = true)
        }
    }

    fun load() {
        scope.launch {
            loading = true
            status = "Sayım sayfaları yükleniyor..."
            val filter = buildODataFilter(searchClause("no", search))
            // Select kullanmamak eski/yeni AL paketleriyle listeyi uyumlu tutar;
            // V2 alanı yayınlandıysa aynı response içinde ayrıca gelir.
            val page = BcApi.getAllPages(
                context,
                "countSheets?\$top=100&\$orderby=createdDateTime desc$filter",
            )
            val capabilities = BcApi.getCountCapabilities(context)
            backendReady = capabilities.v2Ready
            rows = if (page.complete) page.rows else emptyList()
            if (newLocation.isBlank())
                newLocation = rows.firstNotNullOfOrNull {
                    it.optString("locationCode").trim().takeIf(String::isNotBlank)
                }.orEmpty()
            loading = false
            status = when {
                !page.complete -> "HATA: Sayım listesinin tamamı alınamadı. Yenileyin."
                !capabilities.metadataLoaded -> "HATA: BC sayım özellikleri doğrulanamadı; bağlantıyı kontrol edin."
                !capabilities.v2Ready -> "HATA: Sayım V2 sunucu aksiyonları hazır değil — BCWMS AL 1.14.0.52 paketini yayınlayın."
                rows.isEmpty() -> "BOŞ: Sayım sayfası yok"
                else -> "TAMAM: ${rows.size} sayfa — yeni sayım için Yeni V2 Sayımı'na basın"
            }
        }
    }

    fun createV2() {
        val location = newLocation.trim()
        if (location.isBlank() || creating) return
        scope.launch {
            creating = true
            status = "$location lokasyonunda boş Sayım V2 oluşturuluyor..."
            val userId = BcApi.currentUserId(context).trim()
            if (userId.isBlank()) {
                creating = false
                status = "HATA: Terminal kullanıcı kimliği alınamadı. Yeniden giriş yapın."
                return@launch
            }

            val actionBody = JSONObject().apply {
                put("locationCode", location)
                put("userId", userId)
            }.toString()
            var result = BcApi.boundAction(context, "countOps", "", "createV2", actionBody)

            // AL 1.14.0.52 ile geriye uyumluluk: yeni atomik createV2 aksiyonu
            // henüz yayınlanmamışsa boş başlığı mevcut Count API üzerinden
            // oluştur. Belge ekranı idempotent prepareV2 çağrısıyla V2'ye geçirir.
            if (result.httpCode == 404 || result.httpCode == 405) {
                val legacyBody = JSONObject().apply {
                    put("locationCode", location)
                    put("mode", "Visible")
                }.toString()
                result = BcApi.post(context, "countSheets", legacyBody)
            }

            creating = false
            if (result.ok) {
                val createdNo = runCatching { JSONObject(result.body).optString("no") }
                    .getOrDefault("")
                    .ifBlank { BcApi.scalarValue(result.body).trim() }
                showCreate = false
                if (createdNo.isNotBlank()) selected = createdNo
                else {
                    status = "TAMAM: Boş Sayım V2 oluşturuldu. Listeden en yeni sayfayı açın."
                    load()
                }
            } else if (BcApi.isAmbiguousMutationFailure(result)) {
                showCreate = false
                status = "UYARI: Sunucu cevabı alınamadı. Mükerrer belge oluşturmamak için tekrar basmadan listeyi yenileyin."
                load()
            } else {
                // Diyalog açık kalırsa hata arkada kalır ve "hiçbir şey olmadı"
                // gibi görünür; kapat ki mesaj listede görünsün.
                showCreate = false
                status = "HATA: Sayım V2 oluşturulamadı — ${BcApi.errorMessage(result.body)}"
            }
        }
    }

    LaunchedEffect(Unit) { load() }
    selected?.let { no ->
        CountV2Document(no = no, onBack = { selected = null; load() })
        return
    }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.10f)),
            shape = RoundedCornerShape(12.dp),
        ) {
            Column(Modifier.fillMaxWidth().padding(12.dp)) {
                Text("Sayım V2 — sadece okut", fontWeight = FontWeight.Bold)
                Text(
                    "Yeni V2 Sayımı Oluştur'a basın. Rafı okutun; sonra LP (MTE etiketi) okutunca LP içeriği, ürün/lot barkodu okutunca o rafın BC stoku olduğu gibi sayılır. Fark varsa satıra dokunup düzeltin.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { load() }, enabled = !loading) { WmsRefreshLabel(loading) }
            Button(
                onClick = { showCreate = true },
                enabled = backendReady && !loading && !creating,
            ) { Text(if (creating) "Oluşturuluyor..." else "➕ Yeni V2 Sayımı") }
        }
        Spacer(Modifier.height(8.dp))
        DocSearchBar(value = search, onValueChange = { search = it }, onSearch = { load() }, label = "Sayım no ile ara")
        Spacer(Modifier.height(6.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(visibleRows) { sheet ->
                val posted = sheet.optString("status").equals("Posted", ignoreCase = true)
                val v2 = sheet.optBoolean("v2ScanMode", false)
                Card(
                    onClick = { selected = sheet.optString("no") },
                    enabled = !posted && backendReady,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(sheet.optString("no"), fontWeight = FontWeight.Bold)
                            Text(
                                when {
                                    posted -> "Kapalı"
                                    v2 -> "V2 devam ediyor"
                                    else -> "Klasik veya boş belge"
                                },
                                fontSize = 12.sp,
                                color = if (v2) Color(0xFF15803D) else Color.Gray,
                            )
                        }
                        Text(
                            "Lokasyon: ${sheet.optString("locationCode")} · ${sheet.optString("status")}",
                            fontSize = 12.sp,
                            color = Color.Gray,
                        )
                    }
                }
            }
            if (visibleRows.isEmpty() && !loading) {
                item {
                    EmptyState(
                        if (search.isBlank()) "Sayım sayfası yok."
                        else "Aramayla eşleşen sayım sayfası yok.",
                    )
                }
            }
        }
    }

    if (showCreate) {
        AlertDialog(
            onDismissRequest = { if (!creating) showCreate = false },
            title = { Text("Yeni V2 Sayımı Oluştur") },
            text = {
                Column {
                    Text("Sayım yapılacak Business Central lokasyon kodunu girin.")
                    Spacer(Modifier.height(10.dp))
                    OutlinedTextField(
                        value = newLocation,
                        onValueChange = { newLocation = it.uppercase() },
                        label = { Text("Lokasyon Kodu") },
                        singleLine = true,
                        enabled = !creating,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text(
                        "Boş V2 belgesi otomatik oluşturulur; klasik satır üretmeniz gerekmez.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { createV2() },
                    enabled = newLocation.isNotBlank() && !creating,
                ) { Text(if (creating) "Oluşturuluyor..." else "Oluştur ve Aç") }
            },
            dismissButton = {
                TextButton(onClick = { showCreate = false }, enabled = !creating) { Text("Vazgeç") }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CountV2Document(no: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember(no) { mutableStateOf<JSONObject?>(null) }
    var lines by remember(no) { mutableStateOf<List<JSONObject>>(emptyList()) }
    var linesComplete by remember(no) { mutableStateOf(false) }
    var busy by remember(no) { mutableStateOf(false) }
    var status by remember(no) { mutableStateOf("Sayım V2 hazırlanıyor...") }
    var prepared by remember(no) { mutableStateOf(false) }
    var myUserId by remember(no) { mutableStateOf("") }
    var adminTestSession by remember(no) { mutableStateOf(false) }
    var slot by remember(no) { mutableIntStateOf(1) }
    var activeBin by remember(no) { mutableStateOf("") }
    var binScan by remember(no) { mutableStateOf("") }
    var labelScan by remember(no) { mutableStateOf("") }
    var previousRaw by remember(no) { mutableStateOf("") }
    var previousAt by remember(no) { mutableLongStateOf(0L) }
    var pendingRetry by remember(no) { mutableStateOf<PendingCountV2Scan?>(null) }
    var lastCompleted by remember(no) { mutableStateOf<CompletedCountV2Scan?>(null) }
    // Ürün/lot okutması raf stokundaki her lot için ayrı okutma üretir; geri alma hepsini kapsar.
    var lastBatch by remember(no) { mutableStateOf<List<CompletedCountV2Scan>>(emptyList()) }
    var lastCompletedLp by remember(no) { mutableStateOf<CompletedCountV2Lp?>(null) }
    // Satıra dokunarak sayılan miktarı düzeltme (fark varsa).
    var adjustLine by remember(no) { mutableStateOf<JSONObject?>(null) }
    var showPostConfirm by remember(no) { mutableStateOf(false) }

    fun assignments(h: JSONObject?): List<CountSlotAssignment> = listOf(
        CountSlotAssignment(1, h?.optString("counter1UserId").orEmpty()),
        CountSlotAssignment(2, h?.optString("counter2UserId").orEmpty()),
        CountSlotAssignment(3, h?.optString("counter3UserId").orEmpty()),
    )

    fun configuredSlots(h: JSONObject?): List<Int> = assignments(h)
        .filter { it.userId.isNotBlank() }
        .map { it.slot }
        .ifEmpty { listOf(1) }

    fun operatorSlots(h: JSONObject?): List<Int> = assignedCountSlotsForOperator(
        assignments = assignments(h),
        currentUserId = myUserId,
        adminTestSession = adminTestSession,
    )

    suspend fun loadDocument(): Boolean {
        val safeNo = no.replace("'", "''")
        val headerResult = BcApi.get(context, "countSheets('$safeNo')")
        val loadedHeader = if (headerResult.ok) runCatching { JSONObject(headerResult.body) }.getOrNull() else null
        val page = BcApi.getAllPages(
            context,
            "countSheetLines?\$filter=sheetNo eq '$safeNo'&\$top=200",
        )
        header = loadedHeader
        lines = if (page.complete) page.rows else emptyList()
        linesComplete = loadedHeader != null && page.complete
        prepared = loadedHeader?.optBoolean("v2ScanMode", false) == true
        val allowed = operatorSlots(loadedHeader)
        if (allowed.isNotEmpty() && slot !in allowed) slot = allowed.first()
        if (!linesComplete) {
            status = "HATA: Belge ve tüm satırlar alınamadı; okutma kapatıldı."
            return false
        }
        return true
    }

    fun reload(successMessage: String = "") {
        scope.launch {
            busy = true
            val loaded = loadDocument()
            busy = false
            if (loaded && successMessage.isNotBlank()) status = successMessage
        }
    }

    LaunchedEffect(no) {
        busy = true
        myUserId = BcApi.currentUserId(context).trim()
        adminTestSession = BcApi.isAdminTestSession(context)
        val capabilities = BcApi.getCountCapabilities(context)
        if (!capabilities.v2Ready) {
            status = if (!capabilities.metadataLoaded)
                "HATA: BC sayım özellikleri doğrulanamadı; bağlantıyı kontrol edin."
            else
                "HATA: Sayım V2 sunucu aksiyonları hazır değil — BCWMS AL 1.14.0.52 paketini yayınlayın."
            busy = false
            return@LaunchedEffect
        }
        if (!loadDocument()) {
            busy = false
            return@LaunchedEffect
        }
        val h = header
        if (h?.optString("status").equals("Posted", ignoreCase = true)) {
            status = "Bu sayım kaydedilmiş ve kapatılmıştır."
            busy = false
            return@LaunchedEffect
        }
        if (!prepared && lines.isNotEmpty()) {
            // The guidance card below is the single source of truth.  Keeping
            // status empty avoids showing the same long explanation twice.
            status = ""
            busy = false
            return@LaunchedEffect
        }
        if (!prepared) {
            val result = BcApi.boundAction(context, "countSheets", no, "prepareV2", "{}")
            if (!result.ok) {
                status = "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})" +
                    if (result.httpCode == 404 || result.httpCode == 405) " — güncel BCWMS AL paketini yayınlayın" else ""
                busy = false
                return@LaunchedEffect
            }
            loadDocument()
        }
        status = if (prepared) "TAMAM: V2 hazır — önce rafı, sonra LP / ürün / lot barkodunu okutun" else status
        busy = false
    }

    fun selectBin(raw: String) {
        val value = BarcodeIntentResolver.resolve(raw).value.trim().ifBlank { raw.trim() }
        binScan = ""
        if (value.isBlank() || !prepared || busy) return
        scope.launch {
            busy = true
            status = "$value rafı doğrulanıyor..."
            val safeBin = value.replace("'", "''")
            val safeLocation = header?.optString("locationCode").orEmpty().replace("'", "''")
            val filters = buildList {
                add("code eq '$safeBin'")
                if (safeLocation.isNotBlank()) add("locationCode eq '$safeLocation'")
            }.joinToString(" and ")
            val result = BcApi.get(context, "bins?\$filter=$filters&\$select=code,locationCode&\$top=1")
            val row = if (result.ok) BcApi.parseValueArray(result.body).firstOrNull() else null
            busy = false
            if (row == null) {
                status = "HATA: $value rafı bu sayımın lokasyonunda bulunamadı"
            } else {
                activeBin = row.optString("code").ifBlank { value }
                labelScan = ""
                previousRaw = ""
                previousAt = 0L
                pendingRetry = null
                lastCompleted = null
                lastBatch = emptyList()
                lastCompletedLp = null
                status = "TAMAM: 📍 $activeBin — şimdi LP / ürün / lot barkodunu okutun"
            }
        }
    }

    suspend fun postScan(pending: PendingCountV2Scan, reloadAfter: Boolean = true): Boolean {
        pendingRetry = null
        status = "${pending.label.itemNo} · ${formatCountV2Qty(pending.label.quantity)} kaydediliyor..."
        val body = JSONObject().apply {
            put("scanId", pending.scanId)
            put("itemNo", pending.label.itemNo)
            put("variantCode", pending.label.variantCode)
            put("binCode", pending.binCode)
            put("unitOfMeasureCode", pending.label.unitOfMeasureCode)
            put("lotNo", pending.label.lotNo)
            put("serialNo", pending.label.serialNo)
            put("qty", pending.label.quantity)
            put("counterSlot", slot)
        }.toString()
        val result = BcApi.boundAction(context, "countSheets", no, "scanV2Label", body)
        if (result.ok) {
            lastCompleted = CompletedCountV2Scan(pending.scanId, pending.binCode, pending.label)
            lastBatch = emptyList()
            lastCompletedLp = null
            labelScan = ""
            if (reloadAfter) reload(
                "TAMAM: ${pending.label.itemNo}" +
                    pending.label.lotNo.takeIf { it.isNotBlank() }?.let { " · Lot $it" }.orEmpty() +
                    " · ${formatCountV2Qty(pending.label.quantity)} ${pending.label.unitOfMeasureCode} → ${pending.binCode} eklendi"
            )
            return true
        }
        if (BcApi.isAmbiguousMutationFailure(result)) {
            pendingRetry = pending
            status = "UYARI: Sunucu cevabı alınamadı; kayıt ulaşmış olabilir. Aynı işlem kimliğiyle güvenli tekrar deneyin — QR'ı yeniden okutmayın."
        } else {
            status = "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})" +
                if (result.httpCode == 404 || result.httpCode == 405) " — güncel BCWMS AL paketini yayınlayın" else ""
        }
        return false
    }

    fun sendScan(pending: PendingCountV2Scan) {
        scope.launch {
            busy = true
            postScan(pending)
            busy = false
        }
    }

    /**
     * MTE/LP etiketi: LP içeriği sunucuda olduğu gibi sayılır (ürün, lot, seri,
     * birim, miktar). Operatör hiçbir şey girmez; tekrar okutma miktarı toplamaz.
     */
    fun scanLp(lpNo: String) {
        scope.launch {
            busy = true
            status = "$lpNo LP içeriği $activeBin rafında sayılıyor..."
            val body = JSONObject().apply {
                put("scanId", UUID.randomUUID().toString())
                put("lpNo", lpNo)
                put("binCode", activeBin)
                put("counterSlot", slot)
            }.toString()
            val result = BcApi.boundAction(context, "countSheets", no, "scanV2Lp", body)
            busy = false
            when {
                result.ok -> {
                    val n = BcApi.scalarValue(result.body).toIntOrNull() ?: 0
                    lastCompleted = null
                    lastBatch = emptyList()
                    lastCompletedLp = CompletedCountV2Lp(lpNo, activeBin)
                    labelScan = ""
                    reload("TAMAM: LP $lpNo → $n satır $activeBin rafında sayıldı")
                }
                result.httpCode == 404 || result.httpCode == 405 ||
                    BcApi.errorMessage(result.body).contains("scanV2Lp", ignoreCase = true) ->
                    status = "HATA: LP okutma için güncel BCWMS AL paketi (scanV2Lp) yayınlanmalı."
                else -> status = "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})"
            }
        }
    }

    /**
     * Miktarsız ürün/lot barkodu: okutulan rafın BC stoku (lot ve birim bazında)
     * "burada" diye teyit edilir; her lot ayrı satır olur. Operatör yalnız fark
     * varsa satıra dokunup düzeltir. Rafta stok yoksa lotun/ürünün lokasyondaki
     * BC miktarı bu rafa yazılır; hiç yoksa yalnız uyarı (pencere açılmaz).
     */
    fun autoCountFromStock(candidate: CountV2ManualCandidate) {
        scope.launch {
            busy = true
            val loc = header?.optString("locationCode").orEmpty()
            fun safe(v: String) = v.replace("'", "''")
            val what = candidate.itemNo.ifBlank { "Lot ${candidate.lotNo}" }
            status = "$what için $activeBin raf stoku okunuyor..."
            val lotFilters = buildList {
                add("locationCode eq '${safe(loc)}'")
                add("binCode eq '${safe(activeBin)}'")
                if (candidate.itemNo.isNotBlank()) add("itemNo eq '${safe(candidate.itemNo)}'")
                if (candidate.lotNo.isNotBlank()) add("lotNo eq '${safe(candidate.lotNo)}'")
            }.joinToString(" and ")
            val lotPage = BcApi.getAllPages(context, "availableLots?\$filter=$lotFilters&\$top=200")
            var complete = lotPage.complete
            var rows = if (lotPage.complete) lotPage.rows.filter { it.optDouble("quantityBase", 0.0) > 0.0 } else emptyList()
            if (rows.isEmpty() && candidate.itemNo.isNotBlank() && candidate.lotNo.isBlank()) {
                val page = BcApi.getAllPages(
                    context,
                    "binContents?\$filter=locationCode eq '${safe(loc)}' and binCode eq '${safe(activeBin)}' and itemNo eq '${safe(candidate.itemNo)}'&\$top=50",
                )
                if (page.complete) rows = page.rows.filter { it.optDouble("quantity", 0.0) > 0.0 } else complete = false

                // Düz metin barkodu madde numarası da yalnız lot numarası da
                // olabilir. Önce gerçek maddeyi tercih et; BC'de bu madde hiç
                // yoksa aynı değeri lot olarak ara. Lot etiketi böylece manuel
                // miktar/UOM ekranına düşmeden ürününü ve raf bakiyesini çözer.
                if (rows.isEmpty() && complete) {
                    val itemPage = BcApi.getAllPages(
                        context,
                        "items?\$filter=no eq '${safe(candidate.itemNo)}'&\$select=no&\$top=1",
                    )
                    if (!itemPage.complete) {
                        complete = false
                    } else if (itemPage.rows.none { it.optString("no").equals(candidate.itemNo, ignoreCase = true) }) {
                        val byLotPage = BcApi.getAllPages(
                            context,
                            "availableLots?\$filter=locationCode eq '${safe(loc)}' and binCode eq '${safe(activeBin)}' and lotNo eq '${safe(candidate.itemNo)}'&\$top=200",
                        )
                        if (byLotPage.complete)
                            rows = byLotPage.rows.filter { it.optDouble("quantityBase", 0.0) > 0.0 }
                        else
                            complete = false
                    }
                }
            }
            // Rafta yoksa lotun/ürünün LOKASYONDAKİ BC miktarı alınır: "QR'da
            // tanımlı miktar neyse o" — operatör asla miktar girmez, pencere açılmaz.
            // Satır bu rafta açılır; BC başka rafta biliyorsa fark kayıtta çıkar.
            var fromOtherBin = false
            if (rows.isEmpty() && complete) {
                // Query API "or" kabul etmez: önce madde, sonra lot olarak ayrı ayrı ara.
                val key = candidate.itemNo.ifBlank { candidate.lotNo }
                val lotClause = if (candidate.lotNo.isNotBlank() && candidate.itemNo.isNotBlank())
                    " and lotNo eq '${safe(candidate.lotNo)}'" else ""
                val found = mutableListOf<JSONObject>()
                for (field in listOf("itemNo", "lotNo")) {
                    if (found.isNotEmpty()) break
                    val locPage = BcApi.getAllPages(
                        context,
                        "availableLots?\$filter=locationCode eq '${safe(loc)}' and $field eq '${safe(key)}'$lotClause&\$top=200",
                    )
                    if (!locPage.complete) { complete = false; break }
                    found += locPage.rows.filter { it.optDouble("quantityBase", 0.0) > 0.0 }
                }
                rows = found
                    .groupBy { Triple(it.optString("itemNo"), it.optString("lotNo"), it.optString("unitOfMeasureCode")) }
                    .map { (_, group) ->
                        JSONObject(group.first().toString()).apply {
                            put("quantity", group.sumOf { it.optDouble("quantity", 0.0) })
                            put("quantityBase", group.sumOf { it.optDouble("quantityBase", 0.0) })
                        }
                    }
                fromOtherBin = rows.isNotEmpty()
            }
            if (rows.isEmpty()) {
                busy = false
                status = when {
                    !complete -> "HATA: Stok okunamadı. Yenileyip tekrar okutun."
                    else -> "HATA: $what $loc lokasyonunda BC stokunda yok (madde/lot bulunamadı). LP okutun veya BC'de kontrol edin."
                }
                return@launch
            }
            val batch = mutableListOf<CompletedCountV2Scan>()
            var skipped = 0
            var total = 0.0
            for (row in rows) {
                val itemNo = row.optString("itemNo").ifBlank { candidate.itemNo }
                val lotNo = row.optString("lotNo")
                val uom = row.optString("unitOfMeasureCode")
                val qty = row.optDouble("quantity", 0.0).takeIf { it > 0.0 } ?: row.optDouble("quantityBase", 0.0)
                // Aynı raf/ürün/lot bu sayıcı için zaten sayıldıysa ikinci okutma
                // miktarı toplamasın; düzeltme satıra dokunarak yapılır.
                val already = lines.any { l ->
                    l.optString("binCode") == activeBin && l.optString("itemNo") == itemNo &&
                        l.optString("lotNo") == lotNo && l.optString("unitOfMeasureCode") == uom &&
                        l.optString("lpNo").isBlank() &&
                        isCountRecorded(l.has("counted$slot"), l.optBoolean("counted$slot"), l.optDouble("countedQty$slot", 0.0))
                }
                if (already) { skipped++; continue }
                val pending = PendingCountV2Scan(
                    scanId = UUID.randomUUID().toString(),
                    binCode = activeBin,
                    label = CountV2Label(
                        itemNo = itemNo,
                        variantCode = row.optString("variantCode"),
                        unitOfMeasureCode = uom,
                        lotNo = lotNo,
                        serialNo = "",
                        quantity = qty,
                        raw = candidate.raw,
                    ),
                )
                if (!postScan(pending, reloadAfter = false)) {
                    busy = false
                    if (batch.isNotEmpty()) { lastBatch = batch.toList(); lastCompletedLp = null; reload() }
                    return@launch
                }
                batch += CompletedCountV2Scan(pending.scanId, activeBin, pending.label)
                total += qty
            }
            busy = false
            if (batch.isEmpty()) {
                status = "ℹ️ $what bu rafta zaten sayıldı. Farklıysa satıra dokunup düzeltin."
                return@launch
            }
            lastCompleted = null
            lastBatch = batch.toList()
            lastCompletedLp = null
            labelScan = ""
            val first = batch.first().label
            reload(
                "TAMAM: ${first.itemNo} · ${batch.size} satır · toplam ${formatCountV2Qty(total)} ${first.unitOfMeasureCode} " +
                    (if (fromOtherBin) "$activeBin rafına yazıldı (BC başka rafta biliyordu)" else "$activeBin rafında teyit edildi") +
                    (if (skipped > 0) " ($skipped satır zaten sayılıydı)" else "") +
                    " — farklıysa satıra dokunup düzeltin"
            )
        }
    }

    fun recordLineCount(line: JSONObject, qty: Double) {
        if (qty < 0.0) { status = "HATA: Sayım miktarı negatif olamaz."; return }
        scope.launch {
            busy = true
            status = "${line.optString("itemNo")} → ${formatCountV2Qty(qty)} kaydediliyor..."
            val key = "sheetNo='${no.replace("'", "''")}',lineNo=${line.optInt("lineNo")}"
            val body = JSONObject().apply { put("counterSlot", slot); put("qty", qty) }.toString()
            val r = BcApi.boundAction(context, "countSheetLines", key, "recordCount", body)
            busy = false
            if (r.ok) {
                lastCompleted = null; lastBatch = emptyList(); lastCompletedLp = null
                reload("TAMAM: ${line.optString("itemNo")} → ${formatCountV2Qty(qty)} ${line.optString("unitOfMeasureCode")} olarak düzeltildi")
            } else status = "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
        }
    }

    fun scanLabel(raw: String) {
        labelScan = ""
        if (activeBin.isBlank()) {
            status = "HATA: Önce raf barkodunu okutun."
            return
        }
        if (!prepared || busy || pendingRetry != null) return
        val now = System.currentTimeMillis()
        if (isRapidCountV2Duplicate(previousRaw, previousAt, raw, now)) {
            status = "ℹ️ Aynı tarayıcı olayı ikinci kez geldi; mükerrer miktar eklenmedi."
            return
        }
        val resolved = BarcodeIntentResolver.resolve(raw)
        if (resolved.kind == BarcodeKind.Lp) {
            previousRaw = raw
            previousAt = now
            scanLp(resolved.value.trim())
            return
        }
        countV2ManualCandidate(resolved)?.let { candidate ->
            previousRaw = raw
            previousAt = now
            autoCountFromStock(candidate)
            return
        }
        when (val validation = validateCountV2Label(resolved)) {
            is CountV2LabelResult.Invalid -> status = "HATA: ${validation.message}"
            is CountV2LabelResult.Valid -> {
                previousRaw = raw
                previousAt = now
                sendScan(
                    PendingCountV2Scan(
                        scanId = UUID.randomUUID().toString(),
                        binCode = activeBin,
                        label = validation.label,
                    )
                )
            }
        }
    }

    fun undoLastScan() {
        lastCompletedLp?.let { lp ->
            scope.launch {
                busy = true
                status = "${lp.lpNo} LP okutması geri alınıyor..."
                val body = JSONObject().apply {
                    put("lpNo", lp.lpNo); put("binCode", lp.binCode); put("counterSlot", slot)
                }.toString()
                val r = BcApi.boundAction(context, "countSheets", no, "undoV2Lp", body)
                busy = false
                if (r.ok) { lastCompletedLp = null; reload("TAMAM: ${lp.lpNo} LP okutması geri alındı") }
                else status = "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
            }
            return
        }
        val batch = lastBatch.ifEmpty { listOfNotNull(lastCompleted) }
        if (batch.isEmpty()) return
        scope.launch {
            busy = true
            status = "Son okutma geri alınıyor..."
            var failed: BcApi.ApiResult? = null
            for (completed in batch.asReversed()) {
                val body = JSONObject().apply { put("scanId", completed.scanId) }.toString()
                val result = BcApi.boundAction(context, "countSheets", no, "undoV2Scan", body)
                if (!result.ok) { failed = result; break }
            }
            busy = false
            val f = failed
            if (f == null) {
                lastCompleted = null
                lastBatch = emptyList()
                reload("TAMAM: Son okutma geri alındı; miktar ikinci kez düşülmez")
            } else {
                status = if (BcApi.isAmbiguousMutationFailure(f))
                    "UYARI: Geri alma cevabı belirsiz. Aynı 'Son okutmayı geri al' düğmesine tekrar basmak güvenlidir."
                else
                    "HATA: ${BcApi.errorMessage(f.body)} (HTTP ${f.httpCode})"
            }
        }
    }

    fun postSheet() {
        scope.launch {
            busy = true
            status = "Sayım V2 BC'ye kaydediliyor..."
            val result = BcApi.boundActionLongRunning(context, "countSheets", no, "postSheet", "{}")
            busy = false
            showPostConfirm = false
            if (result.ok) reload("TAMAM: Sayım V2 kaydedildi ve kapatıldı")
            else {
                status = "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})"
                reload()
            }
        }
    }

    val h = header
    val allowedSlots = operatorSlots(h)
    val requiredSlots = configuredSlots(h)
    val allRequiredComplete = requiredSlots.all { requiredSlot ->
        allRequiredCountLinesExplicitlyCompleted(lines.map { line ->
            CountSlotLineState(
                hasExplicitFlag = line.has("counted$requiredSlot"),
                explicitlyCounted = line.optBoolean("counted$requiredSlot"),
                quantity = line.optDouble("countedQty$requiredSlot", Double.NaN),
            )
        })
    }
    val canPost = prepared && linesComplete && lines.isNotEmpty() && !busy &&
        slot in allowedSlots && allRequiredComplete &&
        lines.none { it.optBoolean("recountRequired") } &&
        countDocumentIsMutable(h?.optString("status").orEmpty())

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        TextButton(onClick = onBack, enabled = !busy) { Text("‹ Sayfa Listesi") }
        DocHeaderCard(
            title = "$no · Sayım V2",
            subtitle = "Lokasyon: ${h?.optString("locationCode").orEmpty()} · ${h?.optString("status").orEmpty()}",
        )
        Spacer(Modifier.height(8.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))

        if (h != null && allowedSlots.isEmpty()) {
            StatusText("Bu belge için $myUserId kullanıcısına sayıcı slotu atanmamış.")
        } else if (allowedSlots.size > 1) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Sayım turu", fontSize = 12.sp, color = Color.Gray)
                Spacer(Modifier.width(8.dp))
                allowedSlots.forEach { candidate ->
                    FilterChip(
                        selected = slot == candidate,
                        onClick = { slot = candidate },
                        enabled = !busy,
                        label = { Text("$candidate") },
                    )
                    Spacer(Modifier.width(4.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        if (!prepared) {
            if (busy) {
                LinearProgressIndicator(Modifier.fillMaxWidth())
            } else {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFFE4E6))) {
                    Text(
                        if (lines.isNotEmpty()) classicCountSheetV2Message(lines.size)
                        else "Bu belge henüz V2 için hazırlanmadı. Sayfa Listesi'ne dönüp Yeni V2 Sayımı Oluştur'u kullanın.",
                        Modifier.fillMaxWidth().padding(12.dp),
                        color = Color(0xFF9F1239),
                    )
                }
            }
        } else {
            ScanField(
                label = "1. Raf adresini okut",
                value = binScan,
                onValueChange = { binScan = it },
                onScanned = { selectBin(it) },
                enabled = !busy && pendingRetry == null,
                modifier = Modifier.fillMaxWidth(),
            )
            if (activeBin.isNotBlank()) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("📍 $activeBin", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    TextButton(
                        onClick = { activeBin = ""; lastCompleted = null; lastBatch = emptyList(); lastCompletedLp = null; pendingRetry = null },
                        enabled = !busy,
                    ) { Text("Rafı değiştir") }
                }
                ScanField(
                    label = "2. LP / ürün / lot barkodunu okut",
                    value = labelScan,
                    onValueChange = { labelScan = it },
                    onScanned = { scanLabel(it) },
                    enabled = !busy && pendingRetry == null && slot in allowedSlots,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }

        pendingRetry?.let { pending ->
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = { sendScan(pending) },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("🔁 Aynı işlemi güvenle tekrar dene", fontWeight = FontWeight.Bold) }
        }
        if (lastCompleted != null || lastBatch.isNotEmpty() || lastCompletedLp != null) {
            Spacer(Modifier.height(6.dp))
            OutlinedButton(
                onClick = { undoLastScan() },
                enabled = !busy && pendingRetry == null,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("↩ Son okutmayı geri al") }
        }

        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (prepared) "Otomatik oluşan satırlar (${lines.size})" else "Belgedeki klasik satırlar (${lines.size})",
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = { reload("TAMAM: Satırlar yenilendi") }, enabled = !busy) { Text("Yenile") }
        }
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(lines.sortedByDescending { it.optInt("lineNo") }) { line ->
                val counted = isCountRecorded(
                    hasExplicitFlag = line.has("counted$slot"),
                    explicitFlag = line.optBoolean("counted$slot"),
                    quantity = line.optDouble("countedQty$slot", 0.0),
                )
                Card(
                    Modifier.fillMaxWidth().clickable(enabled = prepared && !busy) { adjustLine = line },
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(line.optString("itemNo"), fontWeight = FontWeight.Bold)
                            Text(
                                if (counted) "${formatCountV2Qty(line.optDouble("countedQty$slot"))} ${firstValue(line, "unitOfMeasureCode")}" else "Henüz sayılmadı",
                                fontWeight = FontWeight.SemiBold,
                                color = if (counted) Color(0xFF15803D) else Color.Gray,
                            )
                        }
                        Text("📍 ${line.optString("binCode")}", fontSize = 12.sp, color = Color.Gray)
                        val tracking = listOfNotNull(
                            line.optString("lotNo").takeIf { it.isNotBlank() }?.let { "Lot: $it" },
                            line.optString("serialNo").takeIf { it.isNotBlank() }?.let { "Seri: $it" },
                        ).joinToString(" · ")
                        if (tracking.isNotBlank()) Text(tracking, fontSize = 12.sp)
                        Text(
                            "Sistem: ${formatCountV2Qty(line.optDouble("systemQty"))} · Fark: ${formatCountV2Qty(line.optDouble("variance"))}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            if (lines.isEmpty() && prepared && !busy) item {
                EmptyState("Ekran boş. Rafı okutun, sonra LP / ürün / lot barkodunu okutun.")
            }
        }
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = { showPostConfirm = true },
            enabled = canPost,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("✅ Sayım V2'yi Kaydet", fontWeight = FontWeight.Bold) }
        if (lines.isNotEmpty() && !allRequiredComplete) {
            Text(
                "Atanmış tüm sayıcıların bütün V2 satırlarını tamamlaması gerekir.",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }

    adjustLine?.let { line ->
        QuantityDialogSheet(
            title = "Miktarı düzelt — ${line.optString("binCode")}",
            itemNo = line.optString("itemNo") +
                line.optString("lotNo").takeIf { it.isNotBlank() }?.let { " · Lot $it" }.orEmpty(),
            initialQty = line.optDouble("countedQty$slot", 0.0).takeIf { it > 0.0 }
                ?: line.optDouble("systemQty", 0.0).coerceAtLeast(0.0),
            initialUom = line.optString("unitOfMeasureCode"),
            showLotSerial = false,
            onDismiss = { adjustLine = null },
            onConfirm = { res ->
                adjustLine = null
                recordLineCount(line, res.quantity)
            },
        )
    }

    if (showPostConfirm) {
        AlertDialog(
            onDismissRequest = { if (!busy) showPostConfirm = false },
            title = { Text("Sayım V2 kaydedilsin mi?") },
            text = { Text("${lines.size} QR satırı Business Central fiziksel sayımına kaydedilecek. İşlemden sonra belge kapanabilir.") },
            confirmButton = {
                TextButton(onClick = { postSheet() }, enabled = canPost) { Text("Kaydet") }
            },
            dismissButton = {
                TextButton(onClick = { showPostConfirm = false }, enabled = !busy) { Text("Vazgeç") }
            },
        )
    }
}

private fun formatCountV2Qty(value: Double): String =
    if (value.isFinite() && value == value.toLong().toDouble()) value.toLong().toString() else value.toString()
