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
import com.dynops.bcwms.scanner.ScanField
import com.dynops.bcwms.ui.DocHeaderCard
import com.dynops.bcwms.ui.DocSearchBar
import com.dynops.bcwms.ui.EmptyState
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
                status = "Sayım V2 oluşturulamadı: ${BcApi.errorMessage(result.body)}"
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
                Text("Sayım V2 — QR ile otomatik satır", fontWeight = FontWeight.Bold)
                Text(
                    "Yeni V2 Sayımı Oluştur'a basın. Sistem boş belgeyi hazırlar; rafı ve miktarlı ürün QR'larını okuttukça satırlar otomatik oluşur.",
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
            items(rows) { sheet ->
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
            if (rows.isEmpty() && !loading) item { EmptyState("Sayım sayfası yok.") }
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
        status = if (prepared) "TAMAM: V2 hazır — önce rafı, sonra miktarlı ürün QR'larını okutun" else status
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
                status = "TAMAM: 📍 $activeBin — şimdi miktarlı ürün QR'ını okutun"
            }
        }
    }

    fun sendScan(pending: PendingCountV2Scan) {
        scope.launch {
            busy = true
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
            busy = false
            if (result.ok) {
                lastCompleted = CompletedCountV2Scan(pending.scanId, pending.binCode, pending.label)
                labelScan = ""
                reload(
                    "TAMAM: ${pending.label.itemNo}" +
                        pending.label.lotNo.takeIf { it.isNotBlank() }?.let { " · Lot $it" }.orEmpty() +
                        " · ${formatCountV2Qty(pending.label.quantity)} ${pending.label.unitOfMeasureCode} → ${pending.binCode} eklendi"
                )
            } else if (BcApi.isAmbiguousMutationFailure(result)) {
                pendingRetry = pending
                status = "UYARI: Sunucu cevabı alınamadı; kayıt ulaşmış olabilir. Aynı işlem kimliğiyle güvenli tekrar deneyin — QR'ı yeniden okutmayın."
            } else {
                status = "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})" +
                    if (result.httpCode == 404 || result.httpCode == 405) " — güncel BCWMS AL paketini yayınlayın" else ""
            }
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
        when (val validation = validateCountV2Label(BarcodeIntentResolver.resolve(raw))) {
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
        val completed = lastCompleted ?: return
        scope.launch {
            busy = true
            status = "Son okutma geri alınıyor..."
            val body = JSONObject().apply { put("scanId", completed.scanId) }.toString()
            val result = BcApi.boundAction(context, "countSheets", no, "undoV2Scan", body)
            busy = false
            if (result.ok) {
                lastCompleted = null
                reload("TAMAM: Son okutma geri alındı; miktar ikinci kez düşülmez")
            } else {
                status = if (BcApi.isAmbiguousMutationFailure(result))
                    "UYARI: Geri alma cevabı belirsiz. Aynı 'Son okutmayı geri al' düğmesine tekrar basmak güvenlidir."
                else
                    "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})"
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
                        onClick = { activeBin = ""; lastCompleted = null; pendingRetry = null },
                        enabled = !busy,
                    ) { Text("Rafı değiştir") }
                }
                ScanField(
                    label = "2. Ürün + lot/seri + miktar QR'ını okut",
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
        lastCompleted?.let {
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
                Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(10.dp)) {
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
                EmptyState("Ekran boş. Rafı ve ilk miktarlı ürün QR'ını okutun.")
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
