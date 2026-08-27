package com.dynops.bcwms.feature

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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

internal fun directedMovementTakeMatches(lines: List<JSONObject>, itemNo: String): List<JSONObject> =
    lines.filter {
        it.optString("itemNo").equals(itemNo, ignoreCase = true) &&
            BcEnum.decodeOData(it.optString("actionType")).equals("Take", ignoreCase = true)
    }

internal fun directedMovementReadyToRegister(lines: List<JSONObject>): Boolean {
    val stagedTakeLines = lines.filter {
        BcEnum.decodeOData(it.optString("actionType")).equals("Take", ignoreCase = true) &&
            it.optDouble("qtyToHandle", 0.0) > 0.0
    }
    return stagedTakeLines.isNotEmpty() && stagedTakeLines.all {
        (!it.optBoolean("lotRequired", false) || rawValue(it, "lotNo").isNotBlank()) &&
            (!it.optBoolean("serialRequired", false) || rawValue(it, "serialNo").isNotBlank())
    }
}

private val directedMovementStockError = Regex(
    """must not be less than ([0-9.,]+).*Bin Code='([^']+)'.*Item No.='([^']+)'""",
    setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
)

internal fun directedMovementRegisterError(raw: String, httpCode: Int): String {
    val match = directedMovementStockError.find(raw)
    if (match != null) {
        val (quantity, binCode, itemNo) = match.destructured
        return "HATA: $binCode rafında $itemNo için $quantity miktar kullanılabilir stok yok. Hareket miktarını veya raf stoğunu kontrol edin."
    }
    return QcErrorParser.friendlyStatus(raw, httpCode)
}

/**
 * Ad-Hoc Move — WI §10.5.
 * Single screen: scan from-bin -> scan item/LP -> scan to-bin -> qty -> Confirm.
 * Posts to movements/Microsoft.NAV.adhoc (warehouse/v2.0, live since v1.0.8.0).
 */
@Composable
fun AdHocMoveModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // ELOG akışı (varsayılan "🧺 LP ile" modu):
    //   1) kaynak bin okut → 2) LP okut → 3) sistem LP içeriğini gösterir →
    //   4) hedef okut: aynı raftaki LP ise içerik atomik transfer edilir;
    //      bin ise LP ve stok içeriği tek moveToBin transaction'ıyla taşınır.
    var lpFlow by remember { mutableStateOf(true) }
    var fromBin by remember { mutableStateOf("") }
    var lpNo by remember { mutableStateOf("") }
    var binLps by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var lpLines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var lpLinesComplete by remember { mutableStateOf(false) }
    var target by remember { mutableStateOf("") }
    var targetIsLp by remember { mutableStateOf<Boolean?>(null) }
    var targetLpBin by remember { mutableStateOf("") }
    var sourceLpLocation by remember { mutableStateOf("") }
    var sourceLpBin by remember { mutableStateOf("") }
    // Eski ürün-bazlı mod
    var itemOrLp by remember { mutableStateOf("") }
    var toBin by remember { mutableStateOf("") }
    var qty by remember { mutableStateOf("1") }
    var lotNoInput by remember { mutableStateOf("") }
    var lotPickerOpen by remember { mutableStateOf(false) }
    var availableLots by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var availableLotsLoading by remember { mutableStateOf(false) }
    var availableLotsError by remember { mutableStateOf("") }
    var lotLookupItem by remember { mutableStateOf("") }
    var lotLookupBin by remember { mutableStateOf("") }
    var lotLookupRequestId by remember { mutableIntStateOf(0) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    // Son başarılı hareketin kalıcı özeti — PASS sonrası ekranda kart olarak durur.
    var lastMove by remember { mutableStateOf<List<String>?>(null) }

    fun resetLpFlow() { fromBin = ""; lpNo = ""; binLps = emptyList(); lpLines = emptyList(); lpLinesComplete = false; target = ""; targetIsLp = null; targetLpBin = ""; sourceLpLocation = ""; sourceLpBin = "" }

    fun invalidateAvailableLots() {
        lotLookupRequestId += 1
        lotNoInput = ""
        availableLots = emptyList()
        availableLotsLoading = false
        availableLotsError = ""
        lotPickerOpen = false
    }

    fun openAvailableLots() {
        val bin = fromBin.trim()
        val resolved = BarcodeIntentResolver.resolve(itemOrLp)
        val item = resolved.itemNo?.trim().takeUnless { it.isNullOrBlank() }
            ?: resolved.value.trim()
        if (bin.isBlank() || item.isBlank()) {
            status = "HATA: Lotları listelemek için önce Kaynak Bin ve Ürün alanlarını doldurun."
            return
        }
        if (resolved.kind == com.dynops.bcwms.scanner.BarcodeKind.Lp) {
            status = "HATA: LP hareketinde lot seçimi gerekmez. Ürün ile hareket için ürün barkodunu okutun."
            return
        }

        val requestId = lotLookupRequestId + 1
        lotLookupRequestId = requestId
        lotLookupItem = item
        lotLookupBin = bin
        availableLots = emptyList()
        availableLotsError = ""
        availableLotsLoading = true
        lotPickerOpen = true
        scope.launch {
            val result = fetchAvailableLots(
                context = context,
                itemNo = item,
                locationCode = "",
                binCode = bin,
                variantCode = "",
            )
            if (lotLookupRequestId != requestId) return@launch
            result
                .onSuccess { availableLots = it }
                .onFailure {
                    availableLotsError = it.message.orEmpty().ifBlank {
                        "Lot listesi alınamadı. Bağlantıyı kontrol edip yeniden deneyin."
                    }
                }
            availableLotsLoading = false
        }
    }

    // Kaynak bin'deki LP'leri getir — operatör yazmak yerine dokunup seçer.
    fun loadBinLps(bin: String) {
        val b = bin.trim()
        if (b.isBlank()) return
        scope.launch {
            busy = true; status = "Bindeki LP'ler aranıyor..."
            val safe = b.replace("'", "''")
            val page = BcApi.getAllPages(context, "licensePlates?\$filter=binCode eq '$safe'&\$top=50&\$select=no,templateCode,status,binCode")
            binLps = if (page.complete) page.rows else emptyList()
            busy = false
            status = if (!page.complete) "HATA: LP listesinin tamamı alınamadı. Yenileyip tekrar deneyin."
                else if (binLps.isEmpty()) "⚠️ $b bininde kayıtlı LP yok — LP barkodunu okutabilirsiniz"
                else "TAMAM: $b bininde ${binLps.size} LP — dokunarak seçin"
        }
    }

    fun loadLp(no: String) {
        val t = no.trim()
        if (t.isBlank()) return
        scope.launch {
            busy = true; status = "LP içeriği alınıyor..."; lpLinesComplete = false
            lpNo = ""; lpLines = emptyList(); target = ""; targetIsLp = null; targetLpBin = ""
            val safeNo = t.replace("'", "''")
            val h = BcApi.get(context, "licensePlates('$safeNo')")
            if (!h.ok) { busy = false; status = "HATA: LP bulunamadı: $t"; return@launch }
            val header = JSONObject(h.body)
            sourceLpLocation = header.optString("locationCode").trim().takeUnless { it == "null" }.orEmpty()
            sourceLpBin = header.optString("binCode").trim().takeUnless { it == "null" }.orEmpty()
            if (sourceLpBin.isNotBlank() && fromBin.isNotBlank() && !sourceLpBin.equals(fromBin.trim(), ignoreCase = true)) {
                busy = false
                lpNo = ""; lpLines = emptyList(); lpLinesComplete = false
                status = "HATA: $t, ${sourceLpBin} rafında kayıtlı. Kaynak rafı kontrol edin."
                return@launch
            }
            val l = BcApi.getAllPages(context, "licensePlateLines?\$filter=lpNo eq '$safeNo'&\$orderby=lineNo")
            if (!l.complete) {
                busy = false; lpNo = ""; lpLines = emptyList(); lpLinesComplete = false
                val http = l.error?.httpCode?.takeIf { it > 0 }?.let { " (HTTP $it)" }.orEmpty()
                status = "HATA: LP satırlarının tamamı alınamadı$http. Yenileyip tekrar deneyin."
                return@launch
            }
            lpLines = l.rows
            lpLinesComplete = true
            lpNo = t
            busy = false
            status = if (lpLines.isEmpty()) "⚠️ LP boş görünüyor — yine de taşınabilir"
                else "TAMAM: $t içinde ${lpLines.size} satır"
        }
    }

    fun openLpWorkflowFromProductMode(no: String) {
        val routedLpNo = no.trim()
        if (routedLpNo.isBlank()) {
            status = "HATA: LP barkodu boş. LP'yi yeniden okutun."
            return
        }
        // Product form state must not leak into the LP operation. In particular,
        // its target/quantity/lot must never trigger an additional adHoc request.
        invalidateAvailableLots()
        itemOrLp = ""
        toBin = ""
        qty = "1"
        lpNo = routedLpNo
        lpLines = emptyList()
        lpLinesComplete = false
        target = ""
        targetIsLp = null
        targetLpBin = ""
        lpFlow = true
        if (fromBin.isBlank()) {
            status = "LP barkodu algılandı. Önce kaynak rafı okutun, ardından LP içeriğini getirin."
            return
        }
        status = "LP barkodu algılandı — güvenli LP taşıma akışı açılıyor..."
        // loadLp validates the scanned LP's current bin against fromBin and loads
        // every LP line before transfer/moveToBin can be enabled.
        loadLp(routedLpNo)
    }

    // Hedef LP mi bin mi? LP bulunamadığında otomatik olarak "bin" kabul
    // edilmez; bin kaydı da sunucudan doğrulanır. Ağ/API hatası fail-closed'dur.
    fun resolveTarget(scanned: String) {
        val t = scanned.trim()
        if (t.isBlank()) return
        if (!lpLinesComplete) {
            status = "HATA: LP satırları eksik yüklendi. Hedef seçmeden önce LP içeriğini yenileyin."
            return
        }
        scope.launch {
            busy = true; targetIsLp = null; targetLpBin = ""
            if (t.equals(lpNo, ignoreCase = true)) {
                busy = false; status = "HATA: Kaynak ve hedef LP aynı olamaz."
                return@launch
            }
            val safe = t.replace("'", "''")
            val r = BcApi.get(context, "licensePlates('$safe')")
            if (r.ok) {
                val targetHeader = JSONObject(r.body)
                val targetStatus = targetHeader.optString("status")
                if (!targetStatus.equals("Open", true) && !targetStatus.equals("Built", true)) {
                    busy = false; status = "HATA: Hedef LP açık veya tamamlanmış durumda değil. Başka bir LP seçin."
                    return@launch
                }
                targetLpBin = targetHeader.optString("binCode").takeIf { it != "null" } ?: ""
                if (targetLpBin.isBlank() || !targetLpBin.equals(fromBin.trim(), ignoreCase = true)) {
                    busy = false
                    targetIsLp = null
                    status = "HATA: Hedef LP kaynak LP ile aynı rafta değil. Önce hedef LP’yi aynı rafa taşıyın."
                    return@launch
                }
                targetIsLp = true
            } else if (r.httpCode == 404) {
                val locationFilter = if (sourceLpLocation.isBlank()) "" else
                    " and locationCode eq '${sourceLpLocation.replace("'", "''")}'"
                val bins = BcApi.get(context, "bins?\$filter=code eq '$safe'$locationFilter&\$top=2&\$select=code,locationCode")
                val matches = if (bins.ok) BcApi.parseValueArray(bins.body) else emptyList()
                if (!bins.ok || matches.size != 1) {
                    busy = false
                    status = if (!bins.ok) "HATA: Hedef doğrulanamadı. Bağlantıyı kontrol edip yeniden deneyin."
                        else "HATA: '$t' geçerli bir LP veya raf değil."
                    return@launch
                }
                targetIsLp = false
            } else {
                busy = false; status = "HATA: Hedef doğrulanamadı. Bağlantıyı kontrol edip yeniden deneyin."
                return@launch
            }
            target = t
            busy = false
            status = if (targetIsLp == true) "🧺 Hedef LP: $t${if (targetLpBin.isNotBlank()) " (bin: $targetLpBin)" else ""} — içerik bu LP'ye aktarılacak"
                else "📍 Hedef bin: $t — LP içeriği bu rafa taşınacak"
        }
    }

    fun confirmLpMove() {
        if (!lpLinesComplete) {
            status = "HATA: LP satırları eksik yüklendi. Hareket yapılmadı; LP içeriğini yenileyin."
            return
        }
        if (targetIsLp == null || target.isBlank()) {
            status = "HATA: Hareket yapılmadı. Önce hedef LP veya rafı doğrulayın."
            return
        }
        scope.launch {
            busy = true; status = "Hareket gönderiliyor..."
            if (targetIsLp == true) {
                if (targetLpBin.isBlank() || !targetLpBin.equals(fromBin.trim(), ignoreCase = true)) {
                    busy = false
                    status = "HATA: Hedef LP kaynak LP ile aynı rafta değil. Önce hedef LP’yi aynı rafa taşıyın."
                    return@launch
                }
                // Tüm satırları AÇIKÇA gönder: eski publish'te boş linesJson
                // hiçbir satır taşımadan başarı dönüyordu (ParseLines boş çıkışı).
                val linesJson = org.json.JSONArray().apply {
                    lpLines.forEach { ln -> put(JSONObject().apply { put("lineNo", ln.optInt("lineNo")) }) }
                }.toString()
                val r = BcApi.boundAction(context, "licensePlates", lpNo, "transfer",
                    JSONObject().apply { put("targetLpNo", target); put("linesJson", linesJson) }.toString())
                if (!r.ok) {
                    busy = false
                    status = "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
                    return@launch
                }
                busy = false
                status = "TAMAM: $lpNo içeriği aynı raftaki $target LP'sine aktarıldı (${lpLines.size} satır)"
                lastMove = buildList {
                    add("🧺 $lpNo → 🧺 $target (📍 $targetLpBin)")
                    lpLines.forEach { ln ->
                        add("• ${ln.optString("itemNo")} × ${fmtq(ln.optDouble("quantity"))}" +
                            (ln.optString("lotNo").takeIf { it.isNotBlank() && it != "null" }?.let { " · Lot $it" } ?: ""))
                    }
                }
                resetLpFlow()
            } else {
                // currentUserId: WMS yerel kullanıcısı yoksa AAD token'ının BC User
                // ID'sine düşer. getLocalUser tek başına, servis/admin test oturumunda
                // ve yalnız AAD ile girişte boş döndüğü için hareketi haksız yere
                // engelliyordu ("Bağlı" görünürken bile).
                val userId = BcApi.currentUserId(context).trim()
                if (userId.isBlank()) {
                    busy = false
                    status = "HATA: Kullanıcı kimliği çözülemedi (BC'ye ulaşılamıyor). " +
                        "Bağlantıyı kontrol edip tekrar deneyin."
                    return@launch
                }
                // LP→bin tek sunucu transaction'ıdır. Satır bazlı adHoc + sonradan
                // header PATCH zinciri kısmi stok/LP konumu üretebildiği için kullanılmaz.
                val r = BcApi.boundAction(
                    context,
                    "licensePlates",
                    lpNo,
                    "moveToBin",
                    JSONObject().apply {
                        put("targetBinCode", target)
                        put("userId", userId)
                    }.toString(),
                )
                busy = false
                if (!r.ok) {
                    status = "HATA: LP taşınamadı: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode}). " +
                        "LP konumunu yenileyip doğrulayın."
                    return@launch
                }
                status = "TAMAM: LP $lpNo ve stok içeriği atomik olarak $target rafına taşındı"
                lastMove = buildList {
                    add("🧺 $lpNo · 📍 ${fromBin.trim()} → 📍 $target")
                    lpLines.forEach { ln ->
                        add("• ${ln.optString("itemNo")} × ${fmtq(ln.optDouble("quantity"))}" +
                            (ln.optString("lotNo").takeIf { it.isNotBlank() && it != "null" }?.let { " · Lot $it" } ?: ""))
                    }
                }
                resetLpFlow()
            }
        }
    }

    if (lotPickerOpen) {
        AlertDialog(
            onDismissRequest = {
                lotLookupRequestId += 1
                lotPickerOpen = false
                availableLotsLoading = false
            },
            title = { Text("Kaynak Bindeki Lotlar", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text(
                        "Ürün: $lotLookupItem · Kaynak Bin: $lotLookupBin",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(12.dp))
                    when {
                        availableLotsLoading -> Row(
                            Modifier.fillMaxWidth().padding(vertical = 24.dp),
                            horizontalArrangement = Arrangement.Center,
                        ) { CircularProgressIndicator() }
                        availableLotsError.isNotBlank() -> Column {
                            Text(availableLotsError, color = MaterialTheme.colorScheme.error)
                            Spacer(Modifier.height(8.dp))
                            OutlinedButton(
                                onClick = { openAvailableLots() },
                                modifier = Modifier.fillMaxWidth(),
                            ) { Text("Yeniden Dene") }
                        }
                        availableLots.isEmpty() -> Text(
                            "Bu ürünün $lotLookupBin kaynak bininde pozitif stoklu lotu bulunamadı. Lot numarasını QR ile okutabilir veya elle girebilirsiniz.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        else -> LazyColumn(
                            modifier = Modifier.fillMaxWidth().heightIn(max = 420.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            items(availableLots) { row ->
                                val lotNo = row.optString("lotNo")
                                OutlinedButton(
                                    onClick = {
                                        lotNoInput = lotNo
                                        lotPickerOpen = false
                                        status = "TAMAM: $lotNo lotu seçildi ($lotLookupBin / $lotLookupItem)"
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    Column(Modifier.fillMaxWidth()) {
                                        Text(lotNo, fontWeight = FontWeight.Bold)
                                        Text(
                                            buildString {
                                                append("Stok: ${fmtq(row.optDouble("quantityBase", 0.0))}")
                                                row.optString("unitOfMeasureCode")
                                                    .takeIf { it.isNotBlank() && it != "null" }
                                                    ?.let { append(" $it") }
                                                row.optString("locationCode")
                                                    .takeIf { it.isNotBlank() && it != "null" }
                                                    ?.let { append(" · Lokasyon: $it") }
                                            },
                                            fontSize = 12.sp,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    lotLookupRequestId += 1
                    lotPickerOpen = false
                    availableLotsLoading = false
                }) { Text("Kapat") }
            },
        )
    }

    Column(Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState())) {
        Text("Ad-Hoc Hareket", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            FilterChip(selected = lpFlow, onClick = { lpFlow = true }, label = { Text("🧺 LP ile") })
            FilterChip(selected = !lpFlow, onClick = { lpFlow = false }, label = { Text("📦 Ürün ile") })
        }
        Spacer(Modifier.height(12.dp))

        if (lpFlow) {
            // 1) Kaynak bin — okutulunca o bindeki LP'ler otomatik listelenir.
            ScanField("1) Kaynak Bin okut", fromBin, { fromBin = it }, modifier = Modifier.fillMaxWidth(), onScanned = {
                val b = BarcodeIntentResolver.resolve(it).value
                fromBin = b
                loadBinLps(b)
            })
            Spacer(Modifier.height(8.dp))
            // 2) LP: bindeki LP'lerden DOKUNARAK seç ya da barkod okut.
            if (fromBin.isNotBlank()) {
                if (binLps.isEmpty() && lpLines.isEmpty()) {
                    Button(
                        enabled = !busy,
                        onClick = { loadBinLps(fromBin) },
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                    ) { Text("📋 2) Bu Bindeki LP'leri Listele", fontWeight = FontWeight.SemiBold) }
                    Spacer(Modifier.height(8.dp))
                }
                if (binLps.isNotEmpty() && lpLines.isEmpty()) {
                    Text("2) LP seçin (${binLps.size})", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    Spacer(Modifier.height(4.dp))
                    binLps.forEach { lp ->
                        val no = lp.optString("no")
                        Card(
                            onClick = { loadLp(no) },
                            enabled = !busy,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                            shape = RoundedCornerShape(12.dp),
                        ) {
                            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text("🧺", fontSize = 18.sp)
                                Spacer(Modifier.width(10.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(no, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Text(
                                        "${firstValue(lp, "templateCode")} · ${firstValue(lp, "status")}",
                                        fontSize = 11.sp, color = Color.Gray,
                                    )
                                }
                                Text("Seç ›", fontSize = 12.sp, color = Color(0xFF6C5CE7), fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                }
                ScanField(if (lpLines.isEmpty()) "…ya da LP barkodu okut" else "2) LP", lpNo, { lpNo = it }, modifier = Modifier.fillMaxWidth(), onScanned = {
                    loadLp(BarcodeIntentResolver.resolve(it).value)
                })
                // Elle yazılan LP için: okuma tetiklenmediğinde içerik bu butonla gelir.
                if (lpNo.isNotBlank() && lpLines.isEmpty()) {
                    Spacer(Modifier.height(6.dp))
                    OutlinedButton(
                        enabled = !busy,
                        onClick = { loadLp(lpNo) },
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                    ) { Text("📥 LP İçeriğini Getir", fontWeight = FontWeight.SemiBold) }
                }
                Spacer(Modifier.height(8.dp))
            }
            // 3) İçerik (sistem gösterir)
            if (lpLines.isNotEmpty()) {
                Text("3) LP içeriği (${lpLines.size})", fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                Spacer(Modifier.height(4.dp))
                lpLines.forEach { ln ->
                    Card(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
                        Column(Modifier.padding(10.dp)) {
                            Text("${ln.optString("itemNo")} × ${ln.optDouble("quantity")}", fontWeight = FontWeight.Medium, fontSize = 13.sp)
                            val extra = listOfNotNull(
                                ln.optString("sourceBinCode").takeIf { it.isNotBlank() && it != "null" }?.let { "📍 $it" },
                                ln.optString("lotNo").takeIf { it.isNotBlank() }?.let { "Lot $it" },
                            ).joinToString(" · ")
                            if (extra.isNotBlank()) Text(extra, fontSize = 11.sp, color = Color.Gray)
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                // 4) Hedef: LP ya da bin
                ScanField("4) Hedef okut (LP veya Bin)", target, {
                    target = it; targetIsLp = null; targetLpBin = ""
                }, modifier = Modifier.fillMaxWidth(), onScanned = {
                    resolveTarget(BarcodeIntentResolver.resolve(it).value)
                })
                if (target.isNotBlank() && targetIsLp == null) {
                    Spacer(Modifier.height(6.dp))
                    Button(
                        enabled = !busy,
                        onClick = { resolveTarget(target) },
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                    ) { Text("🔎 Hedefi Doğrula (LP mi bin mi?)", fontWeight = FontWeight.SemiBold) }
                }
                Spacer(Modifier.height(12.dp))
                Button(
                    enabled = !busy && lpLinesComplete && lpNo.isNotBlank() && target.isNotBlank() && targetIsLp != null,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    onClick = { confirmLpMove() },
                ) {
                    Text(
                        when {
                            busy -> "Gönderiliyor..."
                            targetIsLp == true -> "✅ İçeriği $target LP'sine Aktar"
                            targetIsLp == false -> "✅ LP'yi $target Rafına Taşı"
                            else -> "✅ Hareketi Onayla"
                        },
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        } else {
            ScanField("Kaynak Bin", fromBin, {
                if (it != fromBin) invalidateAvailableLots()
                fromBin = it
            }, modifier = Modifier.fillMaxWidth(), onScanned = {
                val scanned = BarcodeIntentResolver.resolve(it).value
                if (scanned != fromBin) invalidateAvailableLots()
                fromBin = scanned
            })
            Spacer(Modifier.height(8.dp))
            ScanField("Ürün / LP", itemOrLp, {
                if (it != itemOrLp) invalidateAvailableLots()
                itemOrLp = it
            }, modifier = Modifier.fillMaxWidth(), onScanned = {
                val decision = decideAdHocProductInput(it)
                when (decision.route) {
                    AdHocProductInputRoute.LicensePlateWorkflow ->
                        openLpWorkflowFromProductMode(decision.value)

                    AdHocProductInputRoute.ProductMutation -> {
                        if (decision.value != itemOrLp) invalidateAvailableLots()
                        itemOrLp = decision.value
                    }

                    AdHocProductInputRoute.Invalid -> {
                        if (decision.value != itemOrLp) invalidateAvailableLots()
                        itemOrLp = decision.value
                        status = "HATA: Bu alanda ürün veya LP barkodu okutun."
                    }
                }
            })
            Spacer(Modifier.height(8.dp))
            ScanField("Hedef Bin", toBin, { toBin = it }, modifier = Modifier.fillMaxWidth(), onScanned = {
                toBin = BarcodeIntentResolver.resolve(it).value
            })
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(qty, { qty = it.filter { c -> c.isDigit() || c == '.' } }, label = { Text("Miktar") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            // Lot izlemeli ürünler için ("You must assign a lot number" hatası).
            ScanField("Lot No (lot izlemeli üründe)", lotNoInput, { lotNoInput = it }, modifier = Modifier.fillMaxWidth(), onScanned = {
                lotNoInput = BarcodeIntentResolver.resolve(it).value
            })
            Spacer(Modifier.height(6.dp))
            OutlinedButton(
                enabled = !busy && fromBin.isNotBlank() && itemOrLp.isNotBlank(),
                onClick = { openAvailableLots() },
                modifier = Modifier.fillMaxWidth().height(44.dp),
            ) {
                Text(
                    if (lotNoInput.isBlank()) "📋 Kaynak Bindeki Lotları Göster"
                    else "📋 Seçili Lotu Değiştir",
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Spacer(Modifier.height(16.dp))
            Button(
                enabled = !busy && fromBin.isNotBlank() && toBin.isNotBlank() && itemOrLp.isNotBlank(),
                modifier = Modifier.fillMaxWidth().height(52.dp),
                onClick = {
                    val decision = decideAdHocProductInput(itemOrLp)
                    when (decision.route) {
                        AdHocProductInputRoute.LicensePlateWorkflow ->
                            openLpWorkflowFromProductMode(decision.value)

                        AdHocProductInputRoute.Invalid ->
                            status = "HATA: Hareket yapılmadı. Geçerli bir ürün barkodu okutun."

                        AdHocProductInputRoute.ProductMutation -> scope.launch {
                            busy = true; status = "Hareket gönderiliyor..."
                            // currentUserId: WMS yerel kullanıcısı yoksa AAD token'ının BC User
                            // ID'sine düşer. getLocalUser tek başına, servis/admin test oturumunda
                            // ve yalnız AAD ile girişte boş döndüğü için hareketi haksız yere
                            // engelliyordu ("Bağlı" görünürken bile).
                            val userId = BcApi.currentUserId(context).trim()
                            if (userId.isBlank()) {
                                busy = false
                                status = "HATA: Kullanıcı kimliği çözülemedi (BC'ye ulaşılamıyor). " +
                                    "Bağlantıyı kontrol edip tekrar deneyin."
                                return@launch
                            }
                            val itemNo = decision.value
                            val lot = lotNoInput.trim()
                            val body = JSONObject().apply {
                                put("fromBin", fromBin.trim()); put("toBin", toBin.trim())
                                // AL action param is "qty" (not "quantity"); send every param so OData binds them all.
                                put("qty", qty.toDoubleOrNull() ?: 0.0)
                                put("itemNo", itemNo)
                                // movementOps.adHoc still requires the legacy lpNo argument,
                                // but Product mode never sends an LP through this contract.
                                put("lpNo", "")
                                put("userId", userId)
                                if (lot.isNotBlank()) put("lotNo", lot)
                            }.toString()
                            // adHoc is bound to the singleton Setup record (key '') via the movementOps API,
                            // because a fresh bin-to-bin move has no existing movement document to bind to.
                            // Lot girildiyse lot-tracking bağlayan adHocLot action'ı kullanılır.
                            val r = BcApi.boundAction(context, "movementOps", "", if (lot.isBlank()) "adHoc" else "adHocLot", body)
                            busy = false
                            status = if (r.ok) "TAMAM: Hareket kaydedildi (HTTP ${r.httpCode})"
                                else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})" +
                                    if (lot.isNotBlank() && (r.httpCode == 404 || r.httpCode == 400))
                                        " — lot desteği için BC publish gerekli olabilir" else ""
                            if (r.ok) {
                                lastMove = buildList {
                                    add("📍 ${fromBin.trim()} → 📍 ${toBin.trim()}")
                                    add("• $itemNo × ${qty.toDoubleOrNull()?.let { fmtq(it) } ?: qty}" +
                                        if (lot.isNotBlank()) " · Lot $lot" else "")
                                }
                                itemOrLp = ""; qty = "1"; lotNoInput = ""
                            }
                        }
                    }
                }
            ) { Text(if (busy) "Gönderiliyor..." else "✅ Hareketi Onayla", fontWeight = FontWeight.Bold) }
        }
        Spacer(Modifier.height(12.dp))
        StatusText(status)
        val lm = lastMove
        if (lm != null) {
            Spacer(Modifier.height(8.dp))
            Card(
                Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F5E9)),
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text("✅ Hareket kaydedildi", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Color(0xFF2E7D32))
                    Spacer(Modifier.height(6.dp))
                    lm.forEach { line -> Text(line, fontSize = 13.sp, color = Color(0xFF1B5E20)) }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "BC'de iz: Warehouse Entries (bin çifti + lot) · Bin Contents (güncel raf stoğu)",
                        fontSize = 11.sp, color = Color(0xFF558B2F),
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(
                        onClick = { lastMove = null; status = "" },
                        modifier = Modifier.fillMaxWidth().height(42.dp),
                        shape = RoundedCornerShape(50),
                    ) { Text("Tamam — Yeni Hareket") }
                }
            }
        }
    }
}

/**
 * Inventory Count — adres (bin) bazlı sayım.
 * Sayfa listesi -> Sayım Belgesi -> raf okut -> etiket okut -> adresi kapat.
 * Miktar her zaman gösterilir: sayım palet/etiket doğrulamasıyla yürüdüğü için
 * BC'deki Blind modu terminalde uygulanmaz.
 * -> Start Recount / Post. BC: countSheets / countSheetLines (warehouse/v2.0, live since v1.0.8.0).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }

    fun load() {
        scope.launch {
            loading = true; status = "Sayım sayfaları yükleniyor..."
            val filter = com.dynops.bcwms.ui.buildODataFilter(com.dynops.bcwms.ui.searchClause("no", search))
            val page = BcApi.getAllPages(context, "countSheets?\$top=100&\$orderby=createdDateTime desc&\$select=no,locationCode,mode,status,createdDateTime$filter")
            loading = false
            rows = if (page.complete) page.rows else emptyList()
            status = if (!page.complete) "HATA: Sayım listesinin tamamı alınamadı. Yenileyin."
                else if (rows.isEmpty()) "BOŞ: Sayım sayfası yok"
                else "TAMAM: ${rows.size} sayfa"
        }
    }
    LaunchedEffect(Unit) { load() }

    var itemDocs by remember { mutableStateOf<Pair<String, Set<String>>?>(null) }
    val sel = selected
    if (sel != null) { CountDocument(no = sel, onBack = { selected = null; load() }); return }

    DocListScanHandler(
        enabled = true,
        linesEndpoint = "countSheetLines",
        docKey = "sheetNo",
        onError = { status = it },
    ) { item, docs ->
        when { docs.isEmpty() -> status = "⚠️ '$item' sayım sayfasında yok"; docs.size == 1 -> selected = docs.first(); else -> { itemDocs = item to docs; status = "TAMAM: '$item' → ${docs.size} sayfa" } }
    }
    val shownRows = itemDocs?.let { f -> rows.filter { firstValue(it, "no", "batchName") in f.second } } ?: rows

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Button(onClick = { load() }, enabled = !loading) { WmsRefreshLabel(loading) }
        Spacer(Modifier.height(8.dp))
        com.dynops.bcwms.ui.DocSearchBar(value = search, onValueChange = { search = it }, onSearch = { load() }, label = "Sayım no ile ara")
        Spacer(Modifier.height(6.dp))
        StatusText(status)
        if (itemDocs != null) { ScanFilterChip("${itemDocs!!.first} → ${itemDocs!!.second.size} sayfa") { itemDocs = null } }
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(shownRows) { d ->
                Card(onClick = { selected = d.optString("no") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(10.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(firstValue(d, "no", "batchName"), fontWeight = FontWeight.Bold)
                            Text(firstValue(d, "mode") + " · " + firstValue(d, "status"), fontSize = 12.sp, color = Color.Gray)
                        }
                        Text("Lokasyon: ${firstValue(d, "locationCode")}", fontSize = 12.sp, color = Color.Gray)
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("Sayım sayfası yok.") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CountDocument(no: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var countLine by remember { mutableStateOf<JSONObject?>(null) }
    var countCapabilities by remember(no) { mutableStateOf<BcApi.CountCapabilities?>(null) }
    // Sayıcı slotu belge seviyesinde tutulur: pane'deki okutmalar ve satır
    // düzeltme ekranı (CountEntrySheet) AYNI slota yazsın diye. paneReset,
    // 'Yeniden Say' sonrası pane'in yerel ilerleme durumunu sıfırlar.
    var slot by remember(no) { mutableStateOf(1) }
    var paneReset by remember(no) { mutableStateOf(0) }
    var linesComplete by remember(no) { mutableStateOf(false) }
    var showPostConfirm by remember(no) { mutableStateOf(false) }
    var showRecountConfirm by remember(no) { mutableStateOf(false) }
    var myUserId by remember(no) { mutableStateOf("") }
    var adminTestSession by remember(no) { mutableStateOf(false) }

    fun counterAssignments(h: JSONObject?): List<CountSlotAssignment> = listOf(
        CountSlotAssignment(1, h?.optString("counter1UserId").orEmpty()),
        CountSlotAssignment(2, h?.optString("counter2UserId").orEmpty()),
        CountSlotAssignment(3, h?.optString("counter3UserId").orEmpty()),
    )

    fun configuredSlots(h: JSONObject?): List<Int> = counterAssignments(h)
        .filter { it.userId.isNotBlank() }
        .map { it.slot }
        .ifEmpty { listOf(1) }

    fun operatorSlots(h: JSONObject?): List<Int> = assignedCountSlotsForOperator(
        assignments = counterAssignments(h),
        currentUserId = myUserId,
        adminTestSession = adminTestSession,
    )

    fun reload() {
        scope.launch {
            busy = true
            // Her yenilemede eski veriyi önce kapat. Ağ/sunucu hatasında önceki
            // satırlar güncelmiş gibi düzenlenip kaydedilemesin.
            header = null
            lines = emptyList()
            linesComplete = false
            countLine = null
            showPostConfirm = false
            showRecountConfirm = false
            myUserId = BcApi.currentUserId(context).trim()
            adminTestSession = BcApi.isAdminTestSession(context)
            val safeNo = no.replace("'", "''")
            val h = BcApi.get(context, "countSheets('$safeNo')")
            val loadedHeader = if (h.ok) runCatching { JSONObject(h.body) }.getOrNull() else null
            val page = BcApi.getAllPages(
                context,
                "countSheetLines?\$filter=sheetNo eq '$safeNo'&\$top=200",
            )
            header = loadedHeader
            val allowedSlots = operatorSlots(loadedHeader)
            if (allowedSlots.isNotEmpty() && slot !in allowedSlots)
                slot = allowedSlots.first()
            linesComplete = loadedHeader != null && page.complete
            if (linesComplete) {
                lines = page.rows
                if (status.startsWith("HATA:")) status = ""
            } else {
                status = "HATA: Sayım belgesi ve tüm satırları alınamadı. İşlem yapmadan önce yenileyin."
            }
            busy = false
        }
    }
    LaunchedEffect(no) {
        countCapabilities = BcApi.getCountCapabilities(context)
        reload()
    }

    fun action(name: String, okMsg: String) {
        if (header == null || !linesComplete) {
            status = "HATA: Sayım belgesi tamamen yüklenmeden bu işlem yapılamaz. Yenileyin."
            return
        }
        scope.launch {
            busy = true; status = "$name..."
            val r = BcApi.boundAction(context, "countSheets", no, name, "{}")
            busy = false
            status = if (r.ok) "TAMAM: $okMsg (HTTP ${r.httpCode})" else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
            if (r.ok) reload()
        }
    }

    fun postSheetAndPrintLpLabels() {
        val requiredSlots = configuredSlots(header)
        val allAssignedSlotsComplete = requiredSlots.all { requiredSlot ->
            allRequiredCountLinesExplicitlyCompleted(lines.map { line ->
                CountSlotLineState(
                    hasExplicitFlag = line.has("counted$requiredSlot"),
                    explicitlyCounted = line.optBoolean("counted$requiredSlot"),
                    quantity = line.optDouble("countedQty$requiredSlot", Double.NaN),
                )
            })
        }
        val postAllowed = countDocumentActions(
            lineCount = lines.size,
            busy = busy,
            linesComplete = linesComplete,
            headerLoaded = header != null,
            activeSlotComplete = allAssignedSlotsComplete,
            status = header?.optString("status").orEmpty(),
            activeSlotAssigned = slot in operatorSlots(header),
            hasRecountRequired = lines.any { it.optBoolean("recountRequired") },
        ).canPost
        if (!postAllowed) {
            status = if (lines.any { it.optBoolean("recountRequired") })
                "Uyuşmayan sayım satırları var. Yeniden Say ile yeni tur başlatın."
            else
                "Atanmış tüm sayıcılar bütün satırları, sıfır olanlar dahil, tamamlamadan kayıt yapılamaz."
            return
        }
        val countedLpNos = lines.map { it.optString("lpNo") }.filter { it.isNotBlank() }.distinct()
        scope.launch {
            busy = true; status = "Sayım BC'ye kaydediliyor..."
            val r = BcApi.boundActionLongRunning(context, "countSheets", no, "postSheet", "{}")
            if (!r.ok) {
                busy = false
                status = "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
                reload()
                return@launch
            }

            val printerId = getDefaultPrinter(context)
            var printFailures = 0
            countedLpNos.forEach { lpNo ->
                val body = JSONObject().apply { put("printerId", printerId); put("copies", 1) }.toString()
                val pr = BcApi.boundAction(context, "licensePlates", lpNo, "printLabel", body)
                if (!pr.ok) printFailures += 1
            }
            reload()
            busy = false
            status = if (printFailures == 0)
                "TAMAM: Sayım kaydedildi; ${countedLpNos.size} LP etiketi güncel miktarla yazdırıldı"
            else
                "UYARI: Sayım kaydedildi; $printFailures LP etiketi yazdırılamadı"
        }
    }

    val h = header
    val requiredSlots = configuredSlots(h)
    val allowedSlots = operatorSlots(h)
    val allAssignedSlotsComplete = requiredSlots.all { requiredSlot ->
        allRequiredCountLinesExplicitlyCompleted(lines.map { line ->
            CountSlotLineState(
                hasExplicitFlag = line.has("counted$requiredSlot"),
                explicitlyCounted = line.optBoolean("counted$requiredSlot"),
                quantity = line.optDouble("countedQty$requiredSlot", Double.NaN),
            )
        })
    }
    val documentStatus = h?.optString("status").orEmpty()
    val isV2Document = h?.optBoolean("v2ScanMode", false) == true
    val recountLines = lines.filter { it.optBoolean("recountRequired") }
    val availableActions = countDocumentActions(
        lineCount = lines.size,
        busy = busy,
        linesComplete = linesComplete,
        headerLoaded = header != null,
        activeSlotComplete = allAssignedSlotsComplete,
        status = documentStatus,
        activeSlotAssigned = slot in allowedSlots,
        hasRecountRequired = recountLines.isNotEmpty(),
    )
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(12.dp)) {
            TextButton(onClick = onBack) { Text("‹ Sayfa Listesi") }
            DocHeaderCard(
                title = no,
                subtitle = "Lokasyon: ${h?.optString("locationCode") ?: ""} · ${firstValue(h ?: JSONObject(), "status")}",
            )
            Spacer(Modifier.height(8.dp))
            StatusText(status)
            if (h != null) {
                val assignmentText = counterAssignments(h)
                    .filter { it.userId.isNotBlank() }
                    .joinToString(" · ") { "${it.slot}: ${it.userId}" }
                    .ifBlank { "1: Eski belge varsayılanı" }
                Text("Atanmış sayıcılar: $assignmentText", fontSize = 12.sp, color = Color.Gray)
            }
            if (documentStatus.equals("Posted", ignoreCase = true)) {
                Spacer(Modifier.height(8.dp))
                StatusText("Bu sayım kaydedilmiş ve kapatılmıştır; terminalden değiştirilemez.")
            } else if (h != null && allowedSlots.isEmpty()) {
                Spacer(Modifier.height(8.dp))
                StatusText("Bu sayımda $myUserId kullanıcısına atanmış sayıcı slotu yok. BC'deki Count Counters bölümünü kontrol edin.")
            }
            if (isV2Document) {
                Spacer(Modifier.height(8.dp))
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.10f))) {
                    Text(
                        "Bu belge Sayım V2 ile başlatılmıştır. Otomatik QR satırlarına devam etmek için ana menüde Sayım V2'yi açın.",
                        Modifier.fillMaxWidth().padding(12.dp),
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            if (recountLines.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFFE4E6))) {
                    Column(Modifier.fillMaxWidth().padding(12.dp)) {
                        Text("Yeniden sayılması gereken ${recountLines.size} satır", fontWeight = FontWeight.Bold, color = Color(0xFF9F1239))
                        recountLines.take(8).forEach { line ->
                            Text(
                                "${line.optString("itemNo")} · ${line.optString("binCode")} · fark ${fmtq(line.optDouble("variance"))}",
                                fontSize = 12.sp,
                                color = Color(0xFF9F1239),
                            )
                        }
                    }
                }
            }
            val capabilities = countCapabilities
            if (capabilities != null && !capabilities.varianceReady) {
                Spacer(Modifier.height(8.dp))
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFFE4E6)),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        if (!capabilities.metadataLoaded)
                            "Gelişmiş sayım işlemleri doğrulanamadı. Bağlantıyı kontrol edip tekrar deneyin."
                        else
                            "Beklenmeyen stok ve sıfır sayım özellikleri bu şirkette henüz etkin değil. " +
                                "Sistem yöneticinize bildirin.",
                        modifier = Modifier.padding(12.dp),
                        color = Color(0xFF9F1239),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            if (!isV2Document && h != null && linesComplete && countDocumentIsMutable(documentStatus) && allowedSlots.isNotEmpty()) {
                CountByBinPane(
                    sheetNo = no,
                    locationCode = h.optString("locationCode"),
                    lines = lines,
                    slot = slot,
                    allowedSlots = allowedSlots,
                    onSlotChange = { slot = it },
                    resetTick = paneReset,
                    busy = busy,
                    onBusy = { busy = it },
                    onStatus = { status = it },
                    onReload = { reload() },
                    onEditLine = { countLine = it },
                    serverCapabilities = countCapabilities,
                )
            } else if (h == null || !linesComplete) {
                EmptyState("Sayım belgesi tam olarak yüklenemedi. Yenileyip tekrar deneyin.")
            }
        }
        BottomActionBar {
            // Generate lines from bin content when the sheet is empty (the count flow needs lines).
            OutlinedButton(onClick = { action("generateLines", "Satırlar üretildi") }, enabled = !isV2Document && availableActions.canGenerateLines, modifier = Modifier.weight(1f).height(52.dp)) { Text("➕ Satır Üret") }
            OutlinedButton(onClick = { showRecountConfirm = true }, enabled = !isV2Document && availableActions.canStartRecount, modifier = Modifier.weight(1f).height(52.dp)) { Text("⟳ Yeniden Say") }
            Button(onClick = { showPostConfirm = true }, enabled = !isV2Document && availableActions.canPost, modifier = Modifier.weight(1f).height(52.dp)) { Text("✅ Kaydet", fontWeight = FontWeight.Bold) }
        }
    }

    val cl = countLine.takeIf { !isV2Document && h != null && linesComplete && !busy }
    if (cl != null) {
        CountEntrySheet(
            line = cl,
            locationCode = h?.optString("locationCode").orEmpty(),
            initialSlot = slot,
            allowedSlots = allowedSlots,
            onDismiss = { countLine = null },
            onConfirm = { slot, qty ->
            countLine = null
            scope.launch {
                busy = true; status = "Sayım kaydediliyor..."
                val body = JSONObject().apply { put("counterSlot", slot); put("qty", qty) }.toString()
                val sheetNo = cl.optString("sheetNo").ifBlank { no }.replace("'", "''")
                val lineNo = cl.optInt("lineNo")
                val r = BcApi.post(context, "countSheetLines(sheetNo='$sheetNo',lineNo=$lineNo)/Microsoft.NAV.recordCount", body)
                busy = false
                status = if (r.ok) "TAMAM: Sayım kaydedildi (slot $slot) (HTTP ${r.httpCode})" else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
                if (r.ok) reload()
            }
        })
    }
    if (showPostConfirm) {
        AlertDialog(
            onDismissRequest = { if (!busy) showPostConfirm = false },
            title = { Text("Sayımı kaydet") },
            text = { Text("${lines.size} sayım satırının sayım turu $slot sonuçları Business Central'a kaydedilecek. Bu işlemden sonra belge kapanabilir. Devam edilsin mi?") },
            confirmButton = {
                TextButton(
                    enabled = availableActions.canPost,
                    onClick = { showPostConfirm = false; postSheetAndPrintLpLabels() },
                ) { Text("Kaydet") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { showPostConfirm = false }) { Text("Vazgeç") }
            },
        )
    }
    if (showRecountConfirm) {
        AlertDialog(
            onDismissRequest = { if (!busy) showRecountConfirm = false },
            title = { Text("Yeniden sayım başlatılsın mı?") },
            text = { Text("Mevcut 1/2/3 sayıcı miktarları temizlenecek ve bütün satırlar yeniden sayılacak.") },
            confirmButton = {
                TextButton(
                    enabled = availableActions.canStartRecount,
                    onClick = {
                        showRecountConfirm = false
                        paneReset += 1
                        action("startRecount", "Eski sayımlar temizlendi; yeniden sayım başlatıldı")
                    },
                ) { Text("Yeniden Say") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { showRecountConfirm = false }) { Text("Vazgeç") }
            },
        )
    }
}

/** Okutulan etiketin (palet ya da madde) sayım sayfasındaki karşılığı. */
private data class CountScanTarget(
    /** Gruplama anahtarı: palet no ya da paletsiz satır için "#<lineNo>". */
    val key: String,
    /** Ekranda gösterilen ad: palet no ya da madde no. */
    val label: String,
    val lines: List<JSONObject>,
    val misplacedFrom: String = "",
    /** Etiketten okunan miktar (varsa). Yoksa sistem miktarı esas alınır. */
    val labelQty: Double? = null,
    /** Lot-only QR sonrasında BC lot bakiyesinden önerilen, düzenlenebilir miktar. */
    val suggestedQty: Double? = null,
    val suggestedQtySource: String = "",
    val lotNo: String = "",
)

private data class UnexpectedItemDraft(
    val itemNo: String = "",
    val variantCode: String = "",
    val unitOfMeasureCode: String = "",
    val lotNo: String = "",
    val serialNo: String = "",
    val suggestedQty: Double? = null,
    val systemBins: Set<String> = emptySet(),
)

private data class UnexpectedLpDraft(
    val lpNo: String,
    val registeredBin: String,
)

/**
 * Adres (bin) bazlı sayım — depocunun sahadaki gerçek yürüyüşünü izler:
 * rafı okut → o rafta beklenen paletler listelenir → paletleri tek tek okut →
 * "Adresi Kapat" → sonraki rafa geç.
 *
 * LP okutmak o paleti TAM kabul eder: paletin tüm satırlarına sistem miktarı
 * sayılan miktar olarak yazılır. Palet fiilen eksikse okutulmaz; adres
 * kapatılırken okutulmayanlar onay alınarak 0 sayılır (eksik). Bir paletin
 * içeriği farklıysa satırına dokunup miktar elle girilebilir.
 *
 * BC tarafında yeni bir nesne gerekmez — mevcut countSheetLines + recordCount
 * kullanılır; satırlar zaten LP No. ve Bin Code taşıyor.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CountByBinPane(
    sheetNo: String,
    locationCode: String,
    lines: List<JSONObject>,
    slot: Int,
    allowedSlots: List<Int>,
    onSlotChange: (Int) -> Unit,
    resetTick: Int,
    busy: Boolean,
    onBusy: (Boolean) -> Unit,
    onStatus: (String) -> Unit,
    onReload: () -> Unit,
    onEditLine: (JSONObject) -> Unit,
    serverCapabilities: BcApi.CountCapabilities?,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var activeBin by remember(sheetNo, resetTick) { mutableStateOf("") }
    var binScan by remember { mutableStateOf("") }
    var lpScan by remember { mutableStateOf("") }
    // Slot'a da keyed: done-durumu seçili sayıcı slotuna göre hesaplandığından
    // slot değişince yerel ilerleme de o slotun gerçeğine göre yeniden kurulur.
    var handledLps by remember(sheetNo, resetTick, slot) { mutableStateOf<Set<String>>(emptySet()) }
    var closedBins by remember(sheetNo, resetTick, slot) { mutableStateOf<Set<String>>(emptySet()) }
    var expandedLp by remember { mutableStateOf("") }
    var confirmClose by remember { mutableStateOf(false) }
    var misplaced by remember { mutableStateOf<Pair<String, String>?>(null) }
    var scanned by remember { mutableStateOf<CountScanTarget?>(null) }
    var lotSelection by remember { mutableStateOf<Pair<String, List<CountScanTarget>>?>(null) }
    var unexpectedItem by remember { mutableStateOf<UnexpectedItemDraft?>(null) }
    var unexpectedLp by remember { mutableStateOf<UnexpectedLpDraft?>(null) }
    var discoveredBins by remember(sheetNo, resetTick) { mutableStateOf<Set<String>>(emptySet()) }
    var itemNames by remember(sheetNo) { mutableStateOf<Map<String, String>>(emptyMap()) }

    // Paletli depoda kalem = palet; paletsiz depoda kalem = tek sayım satırı.
    // Hepsini tek "(paletsiz)" kartına yığmak 68 kalemlik rafı sayılamaz hale
    // getiriyordu — ürün etiketiyle sayabilmek için her satır ayrı kalem olmalı.
    fun lpKey(ln: JSONObject) = ln.optString("lpNo").ifBlank { "#" + ln.optInt("lineNo") }
    fun isLoose(key: String) = key.startsWith("#")
    fun binOf(ln: JSONObject) = ln.optString("binCode").ifBlank { "(rafsız)" }

    val binOrder = remember(lines, discoveredBins) {
        (lines.map { binOf(it) } + discoveredBins).distinct().sorted()
    }
    val binLines = lines.filter { binOf(it) == activeBin }
    val lpGroups = binLines.groupBy { lpKey(it) }

    // Done-durumu SEÇİLİ slota göredir: sayıcı 2, sayıcı 1'in bitirdiği rafı
    // kendi slotuyla yeniden sayabilmeli (recount). Counted bayrakları sayesinde
    // kaydedilmiş 0, artık "hiç sayılmadı" durumundan ayrı tutulur.
    fun alreadyCounted(ln: JSONObject): Boolean =
        isCountRecorded(
            hasExplicitFlag = ln.has("counted$slot"),
            explicitFlag = ln.optBoolean("counted$slot"),
            quantity = ln.optDouble("countedQty$slot", 0.0),
        )
    // Görsel geri bildirim: seçili slotun girdiği sayım.
    fun countedQtyOf(ln: JSONObject): Double? =
        ln.optDouble("countedQty$slot", 0.0).takeIf { alreadyCounted(ln) }
    fun trackingText(ln: JSONObject): String = listOfNotNull(
        ln.optString("lotNo").takeIf { it.isNotBlank() }?.let { "Lot: $it" },
        ln.optString("serialNo").takeIf { it.isNotBlank() }?.let { "Seri: $it" },
    ).joinToString(" · ")
    fun lpDone(lpNo: String): Boolean =
        lpNo in handledLps || (lpGroups[lpNo]?.all { alreadyCounted(it) } == true)

    suspend fun writeQty(ln: JSONObject, qty: Double): Boolean {
        val body = JSONObject().apply { put("counterSlot", slot); put("qty", qty) }.toString()
        val lineNo = ln.optInt("lineNo")
        val safeSheet = sheetNo.replace("'", "''")
        val r = BcApi.post(context, "countSheetLines(sheetNo='$safeSheet',lineNo=$lineNo)/Microsoft.NAV.recordCount", body)
        if (!r.ok) onStatus("HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})")
        return r.ok
    }

    fun printLpLabel(lpNo: String) {
        scope.launch {
            onBusy(true)
            val printerId = getDefaultPrinter(context)
            onStatus(
                if (printerId.isBlank()) "$lpNo etiketi varsayılan sunucu yazıcısına gönderiliyor..."
                else "$lpNo etiketi $printerId yazıcısına gönderiliyor..."
            )
            val body = JSONObject().apply {
                put("printerId", printerId)
                put("copies", 1)
            }.toString()
            val result = BcApi.boundAction(context, "licensePlates", lpNo, "printLabel", body)
            onBusy(false)
            onStatus(
                if (result.ok) "TAMAM: $lpNo LP etiketi yazdırma kuyruğuna alındı"
                else "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})"
            )
        }
    }

    fun handleBinScan(raw: String) {
        val value = BarcodeIntentResolver.resolve(raw).value.trim().ifBlank { raw.trim() }
        binScan = ""
        val match = binOrder.firstOrNull { it.equals(value, ignoreCase = true) }
        if (match == null) {
            // Fiziksel rafta stok bulunabilir fakat üretilen sayım sayfasında o
            // rafa ait hiç satır olmayabilir. Rafı BC'den doğrula; geçerliyse boş
            // adres olarak aç ve operatörün beklenmeyen stoku okutmasına izin ver.
            scope.launch {
                onBusy(true)
                onStatus("$value rafı BC'de doğrulanıyor...")
                fun safe(text: String) = text.replace("'", "''")
                val filters = buildList {
                    if (locationCode.isNotBlank()) add("locationCode eq '${safe(locationCode)}'")
                    add("code eq '${safe(value)}'")
                }.joinToString(" and ")
                val result = BcApi.get(context, "bins?\$filter=$filters&\$select=code,locationCode&\$top=1")
                val verified = if (result.ok) BcApi.parseValueArray(result.body).firstOrNull() else null
                onBusy(false)
                if (verified == null) {
                    onStatus("⚠️ '$value' bu lokasyonda geçerli bir raf değil")
                } else {
                    val verifiedCode = verified.optString("code").ifBlank { value }
                    discoveredBins = discoveredBins + verifiedCode
                    activeBin = verifiedCode
                    expandedLp = ""
                    lotSelection = null
                    onStatus("TAMAM: $verifiedCode boş sayım rafı olarak açıldı — fiziksel ürünü/LP'yi okutun")
                }
            }
            return
        }
        activeBin = match
        expandedLp = ""
        lotSelection = null
        onStatus("TAMAM: $match açıldı — ${lines.count { binOf(it) == match }} satır")
    }

    // Ürün adı sayım satırında boş gelirse (eski AL sürümü) Item kartından tamamlanır:
    // depocunun ekranda ürün adını görmesi bu akışın şartı.
    fun ensureItemNames(target: List<JSONObject>) {
        val missing = target
            .filter { it.optString("description").isBlank() }
            .map { it.optString("itemNo") }
            .filter { it.isNotBlank() && itemNames[it] == null }
            .distinct()
        if (missing.isEmpty()) return
        scope.launch {
            val found = itemNames.toMutableMap()
            for (code in missing) {
                val safe = code.replace("'", "''")
                val r = BcApi.get(context, "items?\$filter=no eq '$safe'&\$select=no,description&\$top=1")
                if (r.ok) BcApi.parseValueArray(r.body).firstOrNull()?.let { found[code] = it.optString("description") }
            }
            itemNames = found
        }
    }

    fun openTarget(
        key: String,
        label: String,
        group: List<JSONObject>,
        misplacedFrom: String = "",
        labelQty: Double? = null,
        suggestedQty: Double? = null,
        suggestedQtySource: String = "",
        lotNo: String = "",
    ) {
        ensureItemNames(group)
        scanned = CountScanTarget(
            key = key,
            label = label,
            lines = group,
            misplacedFrom = misplacedFrom,
            labelQty = labelQty,
            suggestedQty = suggestedQty,
            suggestedQtySource = suggestedQtySource,
            lotNo = lotNo,
        )
    }

    fun lotTargets(
        lotNo: String,
        matchingLines: List<JSONObject>,
        balanceRows: List<JSONObject> = emptyList(),
    ): List<CountScanTarget> = matchingLines
        .groupBy { lpKey(it) }
        .map { (key, matches) ->
            // LP bulunduysa yalnız lot satırını değil LP'nin tamamını aç; aksi halde
            // LP'nin diğer ürünleri fark edilmeden sayılmamış kalır.
            val targetLines = if (isLoose(key)) matches else lpGroups[key].orEmpty()
            val head = matches.first()
            val balance = balanceRows.firstOrNull { row ->
                row.optString("itemNo").equals(head.optString("itemNo"), ignoreCase = true) &&
                    row.optString("variantCode").equals(head.optString("variantCode"), ignoreCase = true) &&
                    (row.optString("unitOfMeasureCode").isBlank() ||
                    row.optString("unitOfMeasureCode").equals(rawValue(head, "unitOfMeasureCode"), ignoreCase = true))
            }
            val suggested = if (targetLines.size == 1) {
                balance?.let { row ->
                    if (row.has("quantity")) row.optDouble("quantity") else row.optDouble("quantityBase")
                } ?: head.optDouble("systemQty", 0.0)
            } else null
            CountScanTarget(
                key = key,
                label = head.optString("lpNo").ifBlank { head.optString("itemNo") },
                lines = targetLines,
                suggestedQty = suggested,
                suggestedQtySource = "BC lot kaydı",
                lotNo = lotNo,
            )
        }
        .distinctBy { it.key }

    fun presentLotTargets(lotNo: String, targets: List<CountScanTarget>) {
        when (targets.size) {
            0 -> onStatus("⚠️ Lot $lotNo için $activeBin adresinde sayılabilir kayıt bulunamadı")
            1 -> {
                ensureItemNames(targets.first().lines)
                scanned = targets.first()
                onStatus("TAMAM: Lot $lotNo bulundu — miktarı kontrol edip kaydedin")
            }
            else -> {
                targets.forEach { ensureItemNames(it.lines) }
                lotSelection = lotNo to targets
                onStatus("ℹ️ Lot $lotNo için ${targets.size} kayıt var — ilgili kaydı seçin")
            }
        }
    }

    fun loadLotFromBc(lotNo: String, itemNo: String = "") {
        scope.launch {
            onBusy(true)
            onStatus("Lot $lotNo BC stok kayıtlarında aranıyor...")
            fun safe(value: String) = value.replace("'", "''")
            val filters = buildList {
                if (locationCode.isNotBlank()) add("locationCode eq '${safe(locationCode)}'")
                add("binCode eq '${safe(activeBin)}'")
                add("lotNo eq '${safe(lotNo)}'")
                if (itemNo.isNotBlank()) add("itemNo eq '${safe(itemNo)}'")
            }.joinToString(" and ")
            val page = BcApi.getAllPages(context, "availableLots?\$filter=$filters&\$top=200")
            if (!page.complete) {
                onBusy(false)
                onStatus("HATA: Lot stoklarının tamamı alınamadı. Yenileyip tekrar deneyin.")
                return@launch
            }
            val balances = page.rows
                .filter {
                    it.optString("lotNo").equals(lotNo, ignoreCase = true) &&
                        (if (it.has("quantity")) it.optDouble("quantity") else it.optDouble("quantityBase")) > 0.0
                }
            val allMatches = balances.flatMap { balance ->
                binLines.filter { line ->
                    line.optString("itemNo").equals(balance.optString("itemNo"), ignoreCase = true) &&
                        line.optString("variantCode").equals(balance.optString("variantCode"), ignoreCase = true) &&
                        (line.optString("lotNo").isBlank() ||
                            line.optString("lotNo").equals(lotNo, ignoreCase = true))
                }
            }.distinctBy { it.optInt("lineNo") }
            val matches = allMatches.filter {
                !alreadyCounted(it) && lpKey(it) !in handledLps
            }
            onBusy(false)
            if (balances.isEmpty()) {
                unexpectedItem = UnexpectedItemDraft(itemNo = itemNo, lotNo = lotNo)
                onStatus("⚠️ Lot $lotNo bu rafta beklenmiyor — fiziksel fazla stok olarak eklemek için ürünü doğrulayın")
            } else if (matches.isEmpty() && allMatches.isNotEmpty() &&
                allMatches.all { alreadyCounted(it) || lpKey(it) in handledLps }
            ) {
                onStatus("ℹ️ Lot $lotNo bu adreste zaten sayıldı")
            } else if (matches.isEmpty()) {
                val first = balances.first()
                unexpectedItem = UnexpectedItemDraft(
                    itemNo = first.optString("itemNo"),
                    variantCode = first.optString("variantCode"),
                    unitOfMeasureCode = first.optString("unitOfMeasureCode"),
                    lotNo = lotNo,
                    suggestedQty = (if (first.has("quantity")) first.optDouble("quantity") else first.optDouble("quantityBase"))
                        .takeIf { it > 0.0 },
                    systemBins = balances.map { it.optString("binCode") }.filter { it.isNotBlank() }.toSet(),
                )
                onStatus("⚠️ Lot $lotNo BC'de bulundu fakat sayım satırında yok — beklenmeyen stok olarak doğrulayın")
            } else {
                presentLotTargets(lotNo, lotTargets(lotNo, matches, balances))
            }
        }
    }

    fun handleLpScan(raw: String) {
        val resolved = BarcodeIntentResolver.resolve(raw)
        val value = (resolved.value).trim().ifBlank { raw.trim() }
        lpScan = ""
        if (activeBin.isBlank()) { onStatus("⚠️ Önce raf adresini okutun"); return }

        // 1) Bu raftaki bir palet mi?
        val here = lpGroups.keys.firstOrNull { it.equals(value, ignoreCase = true) }
        if (here != null) {
            if (lpDone(here)) onStatus("ℹ️ $here zaten sayıldı")
            else openTarget(here, here, lpGroups[here].orEmpty(), labelQty = resolved.quantity)
            return
        }
        // 2) Palet değil de madde etiketi olabilir: bu raftaki ürün satırlarını ara.
        val directItemHits = matchLinesByBarcode(binLines, resolved, listOf("itemNo", "itemReference", "gtin"))
            .filter { !alreadyCounted(it) && lpKey(it) !in handledLps }
        val resolvedLot = resolved.lotNo?.trim().orEmpty()
        val itemLotHits = if (resolvedLot.isNotBlank())
            directItemHits.filter { it.optString("lotNo").equals(resolvedLot, ignoreCase = true) }
        else emptyList()
        if (resolvedLot.isNotBlank()) {
            if (itemLotHits.isNotEmpty()) {
                val targets = lotTargets(resolvedLot, itemLotHits).map { target ->
                    target.copy(labelQty = resolved.quantity ?: target.labelQty)
                }
                if (targets.isNotEmpty()) {
                    presentLotTargets(resolvedLot, targets)
                    return
                }
            }
            // Ürün + lot taşıyan etikette aynı ürünün başka lotuna kesinlikle
            // düşme. İstenen lot sayım satırında yoksa BC lot bakiyesinden tam
            // ürün/lot eşleşmesini doğrula; aksi davranış yanlış lotu sayardı.
            val scannedItemNo = resolved.itemNo?.trim().orEmpty().ifBlank {
                if (resolved.kind == com.dynops.bcwms.scanner.BarcodeKind.Item) value else ""
            }
            loadLotFromBc(resolvedLot, scannedItemNo)
            return
        }
        if (directItemHits.isNotEmpty()) {
            val hit = directItemHits.first()
            val hitLp = hit.optString("lpNo")
            if (hitLp.isNotBlank()) {
                // Ürün etiketi paletli satıra denk geldi: sayım kalemi PALETTİR.
                // Tek satırı sayıp paleti 'bitti' işaretlemek diğer ürünleri
                // sayımsız bırakır — o yüzden paletin TÜM satırları açılır.
                if (lpDone(hitLp)) onStatus("ℹ️ $hitLp zaten sayıldı")
                else openTarget(hitLp, hitLp, lpGroups[hitLp].orEmpty(), labelQty = resolved.quantity)
            } else {
                openTarget(lpKey(hit), hit.optString("itemNo"), listOf(hit), labelQty = resolved.quantity)
            }
            return
        }

        // Düz lot numarası resolver tarafından ürün kodu gibi sınıflandırılabilir.
        // Aktif rafta bu lot zaten varsa ürün-dışı akışa düşmeden lot satır(lar)ını aç.
        val plainLotValue = value
        val plainAllLotHits = binLines.filter {
            it.optString("lotNo").equals(plainLotValue, ignoreCase = true)
        }
        if (plainAllLotHits.isNotEmpty()) {
            val plainLotHits = plainAllLotHits.filter {
                !alreadyCounted(it) && lpKey(it) !in handledLps
            }
            if (plainLotHits.isNotEmpty()) {
                presentLotTargets(plainLotValue, lotTargets(plainLotValue, plainLotHits))
            } else {
                onStatus("ℹ️ Lot $plainLotValue bu adreste zaten sayıldı")
            }
            return
        }

        // Ürün ile lot aynı düz barkod biçiminde gelebilir. BC ürün kartında bu
        // değer gerçekten ürün numarasıysa beklenmeyen stok akışını koru; değilse
        // lot servisine yönlendir. Böylece lot girişi yanlış fiziksel stok sayfasını açmaz.
        if (resolved.kind == com.dynops.bcwms.scanner.BarcodeKind.Item) {
            val itemNo = resolved.itemNo?.trim().orEmpty().ifBlank { value }
            scope.launch {
                onBusy(true)
                onStatus("$itemNo ürün/lot kaydı doğrulanıyor...")
                val safeItemNo = itemNo.replace("'", "''")
                val itemResult = BcApi.get(
                    context,
                    "items?\$filter=no eq '$safeItemNo'&\$select=no&\$top=1",
                )
                val itemExists = itemResult.ok && BcApi.parseValueArray(itemResult.body).isNotEmpty()
                onBusy(false)

                if (shouldResolvePlainCountBarcodeAsLot(
                        hasLocalLotMatch = false,
                        itemExistsInBc = itemExists,
                    )
                ) {
                    loadLotFromBc(itemNo)
                    return@launch
                }

                val expectedBins = lines
                    .filter { it.optString("itemNo").equals(itemNo, ignoreCase = true) }
                    .map { binOf(it) }
                    .filter { it != activeBin }
                    .toSet()
                unexpectedItem = UnexpectedItemDraft(
                    itemNo = itemNo,
                    lotNo = resolved.lotNo.orEmpty(),
                    serialNo = resolved.serialNo.orEmpty(),
                    suggestedQty = resolved.quantity,
                    systemBins = expectedBins,
                )
                onStatus("⚠️ $itemNo $activeBin rafında beklenmiyor — fiziksel stok olarak doğrulayın")
            }
            return
        }

        // 3) Sayım satırlarında henüz bulunmayan gerçek bir LP olabilir. Özellikle
        // yeni oluşturulan LP'nin Bin Code'u boşsa GenerateLines onu güvenle
        // atlar; operatör önce rafı, sonra LP'yi okuttuğunda BC tarafındaki
        // attachLpToBin işlemi LP'yi bu rafa bağlar ve satırlarını sayıma ekler.
        if (resolved.kind == com.dynops.bcwms.scanner.BarcodeKind.Lp) {
            scope.launch {
                onBusy(true)
                onStatus("$value LP kaydı kontrol ediliyor...")
                fun safe(text: String) = text.replace("'", "''")

                var lpHeaderResult = BcApi.get(context, "licensePlates('${safe(value)}')")
                var lpHeader = if (lpHeaderResult.ok) JSONObject(lpHeaderResult.body) else null
                // GS1/SSCC okutulduğunda resolver SSCC değerini döndürür; API'nin
                // anahtarı LP No. olduğundan ikinci arama SSCC alanından yapılır.
                if (lpHeader == null) {
                    lpHeaderResult = BcApi.get(
                        context,
                        "licensePlates?\$filter=sscc eq '${safe(value)}'&\$top=1&\$select=no,locationCode,binCode,status,sscc",
                    )
                    if (lpHeaderResult.ok) lpHeader = BcApi.parseValueArray(lpHeaderResult.body).firstOrNull()
                }
                if (lpHeader == null) {
                    onBusy(false)
                    onStatus("HATA: $value LP kaydı bulunamadı")
                    return@launch
                }

                val actualLpNo = lpHeader.optString("no").ifBlank { value }
                val lpLocation = lpHeader.optString("locationCode")
                val currentBin = lpHeader.optString("binCode").takeUnless { it == "null" }.orEmpty()
                if (locationCode.isNotBlank() && !lpLocation.equals(locationCode, ignoreCase = true)) {
                    onBusy(false)
                    onStatus("HATA: $actualLpNo LP'si $lpLocation lokasyonunda; bu sayım $locationCode lokasyonunda")
                    return@launch
                }
                if (currentBin.isNotBlank() && !currentBin.equals(activeBin, ignoreCase = true)) {
                    onBusy(false)
                    unexpectedLp = UnexpectedLpDraft(actualLpNo, currentBin)
                    onStatus("⚠️ $actualLpNo sistemde $currentBin rafında, fiziksel olarak $activeBin rafında bulundu — farkı doğrulayın")
                    return@launch
                }

                val body = JSONObject().apply {
                    put("lpNo", actualLpNo)
                    put("binCode", activeBin)
                }.toString()
                val attach = BcApi.boundAction(context, "countSheets", sheetNo, "attachLpToBin", body)
                if (!attach.ok) {
                    onBusy(false)
                    onStatus("HATA: ${BcApi.errorMessage(attach.body)} (HTTP ${attach.httpCode})")
                    return@launch
                }

                val linePage = BcApi.getAllPages(
                    context,
                    "countSheetLines?\$filter=sheetNo eq '${safe(sheetNo)}' and lpNo eq '${safe(actualLpNo)}'&\$top=100",
                )
                onBusy(false)
                onReload()
                if (!linePage.complete) {
                    onStatus("UYARI: $actualLpNo rafa bağlandı ancak sayım satırlarının tamamı alınamadı. Belge yenilendi; tekrar deneyin.")
                    return@launch
                }
                val attachedLines = linePage.rows
                if (attachedLines.isEmpty()) {
                    onStatus("TAMAM: $actualLpNo → $activeBin bağlandı; LP içinde sayılacak ürün satırı yok")
                } else {
                    openTarget(actualLpNo, actualLpNo, attachedLines, labelQty = resolved.quantity)
                    onStatus("TAMAM: $actualLpNo → $activeBin bağlandı — miktarı kontrol edip kaydedin")
                }
            }
            return
        }

        // 4) QR yalnız lot no taşıyabilir. Önce aktif bin'deki sayım satırında
        // ara; bulunmazsa availableLots üzerinden BC lot bakiyesine git.
        val lotValue = resolved.lotNo?.trim().takeUnless { it.isNullOrBlank() } ?: value
        val allLotHits = binLines.filter { it.optString("lotNo").equals(lotValue, ignoreCase = true) }
        val lotHits = allLotHits.filter { !alreadyCounted(it) && lpKey(it) !in handledLps }
        if (lotHits.isNotEmpty()) {
            presentLotTargets(lotValue, lotTargets(lotValue, lotHits))
            return
        }
        if (allLotHits.isNotEmpty()) {
            onStatus("ℹ️ Lot $lotValue bu adreste zaten sayıldı")
            return
        }
        // 5) Sayfada var ama başka adreste: yanlış yere konmuş palet.
        val elsewhere = lines.filter { it.optString("lpNo").equals(value, ignoreCase = true) }
        if (elsewhere.isNotEmpty()) {
            if (elsewhere.all { alreadyCounted(it) })
                onStatus("ℹ️ $value zaten sayıldı (adres: ${binOf(elsewhere.first())})")
            else
                misplaced = value to binOf(elsewhere.first())
            return
        }

        // Düz lot numarası ürün kodundan ayırt edilemediği için yerel satırda
        // eşleşme yoksa BC'nin lot bakiyesiyle güvenli biçimde çözülür.
        loadLotFromBc(lotValue)
    }

    // Okutulan hedefi (palet ya da madde satırları) okutulan adrese sayılmış olarak yazar.
    fun commitTarget(target: CountScanTarget, manualQty: Double? = null) {
        scope.launch {
            onBusy(true); onStatus("${target.label} kaydediliyor...")
            var savedCount = 0
            for (ln in target.lines) {
                // Öncelik: elle girilen sayım > etiketten okunan miktar (GS1) >
                // LP/etiket kaydı (systemQty). LP'li palette etiket = LP kaydı
                // olduğundan systemQty etiketteki miktarla aynıdır.
                val qty = manualQty
                    ?: (if (target.lines.size == 1) target.labelQty else null)
                    ?: ln.optDouble("systemQty", 0.0)
                if (!writeQty(ln, qty)) break
                savedCount += 1
            }
            onBusy(false)
            val progress = sequentialWriteProgress(target.lines.size, savedCount)
            when {
                progress.complete -> {
                    handledLps = handledLps + target.key
                    onStatus(
                        "TAMAM: ${target.label} → $activeBin sayıldı (${target.lines.size} satır)" +
                            if (target.misplacedFrom.isNotBlank()) " — sistemde ${target.misplacedFrom}" else ""
                    )
                    // Satır verisi tazelenmeli: aynı ürünün İKİNCİ satırı (başka lot)
                    // okutulduğunda bayat alreadyCounted ilk satırı yeniden seçmesin.
                    onReload()
                }
                progress.partial -> {
                    onStatus(
                        "UYARI: ${target.label} için ${progress.succeeded}/${progress.total} satır kaydedildi; " +
                            "işlem kısmi kaldı. Veriler yeniden yükleniyor. Satırları kontrol edip yeniden sayın."
                    )
                    onReload()
                }
            }
        }
    }

    fun recordUnexpectedItem(itemNo: String, variantCode: String, uom: String, lotNo: String, serialNo: String, qty: Double) {
        if (serverCapabilities?.unexpectedItemAction != true) {
            onStatus("HATA: Beklenmeyen stok şu anda kaydedilemiyor. Uygulamayı yenileyin; sorun sürerse yöneticinize bildirin.")
            return
        }
        scope.launch {
            onBusy(true)
            onStatus("$itemNo beklenmeyen stok olarak kaydediliyor...")
            val body = JSONObject().apply {
                put("itemNo", itemNo.trim())
                put("variantCode", variantCode.trim())
                put("binCode", activeBin)
                put("unitOfMeasureCode", uom.trim())
                put("lotNo", lotNo.trim())
                put("serialNo", serialNo.trim())
                put("qty", qty)
                put("counterSlot", slot)
            }.toString()
            val result = BcApi.boundAction(context, "countSheets", sheetNo, "addUnexpectedItem", body)
            onBusy(false)
            if (result.ok) {
                unexpectedItem = null
                handledLps = handledLps + "unexpected:$itemNo:${lotNo.trim()}:${serialNo.trim()}"
                onStatus("TAMAM: $itemNo → $activeBin beklenmeyen fiziksel stok olarak sayıldı")
                onReload()
            } else {
                onStatus(
                    "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})" +
                        if (result.httpCode == 404 || result.httpCode == 405)
                            " — güncel BADE BCWMS AL paketini yayınlayın" else ""
                )
            }
        }
    }

    fun recordUnexpectedLp(draft: UnexpectedLpDraft) {
        if (serverCapabilities?.unexpectedLpAction != true) {
            onStatus("HATA: Farklı raftaki LP şu anda kaydedilemiyor. Uygulamayı yenileyin; sorun sürerse yöneticinize bildirin.")
            return
        }
        scope.launch {
            onBusy(true)
            onStatus("${draft.lpNo} fiziksel raf farkı kaydediliyor...")
            val body = JSONObject().apply {
                put("lpNo", draft.lpNo)
                put("binCode", activeBin)
                put("counterSlot", slot)
            }.toString()
            val result = BcApi.boundAction(context, "countSheets", sheetNo, "addUnexpectedLp", body)
            onBusy(false)
            if (result.ok) {
                unexpectedLp = null
                handledLps = handledLps + draft.lpNo
                onStatus("TAMAM: ${draft.lpNo} sistemde ${draft.registeredBin}, fizikselde $activeBin olarak sayıldı")
                onReload()
            } else {
                onStatus(
                    "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})" +
                        if (result.httpCode == 404 || result.httpCode == 405)
                            " — güncel BADE BCWMS AL paketini yayınlayın" else ""
                )
            }
        }
    }

    // ---- görünüm ----
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Sayım turu", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.width(8.dp))
        allowedSlots.forEach { sIdx ->
            FilterChip(selected = slot == sIdx, onClick = { onSlotChange(sIdx) }, enabled = !busy, label = { Text("$sIdx") })
            Spacer(Modifier.width(4.dp))
        }
    }
    Spacer(Modifier.height(8.dp))
    StatusText("")

    if (activeBin.isBlank()) {
        ScanField(
            label = "Raf adresi okut",
            value = binScan,
            onValueChange = { binScan = it },
            onScanned = { handleBinScan(it) },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        val doneBins = closedBins.size
        Text("Adresler ($doneBins/${binOrder.size} kapatıldı)", fontWeight = FontWeight.Bold, fontSize = 14.sp)
        Spacer(Modifier.height(6.dp))
        if (binOrder.isEmpty()) EmptyState("Sayım satırı yok — önce 'Satır Üret'.")
        binOrder.forEach { b ->
            val inBin = lines.filter { binOf(it) == b }
            val total = inBin.size
            val counted = inBin.count { alreadyCounted(it) }
            val closed = b in closedBins || (total > 0 && counted == total)
            Card(
                onClick = { activeBin = b; expandedLp = "" },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                shape = RoundedCornerShape(10.dp),
            ) {
                Column(Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(if (closed) "✅ $b" else "📍 $b", fontWeight = FontWeight.Bold)
                        Spacer(Modifier.weight(1f))
                        Text(
                            "$counted/$total sayıldı",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = when {
                                counted == total && total > 0 -> Color(0xFF15803D)
                                counted > 0 -> Color(0xFFC2410C)
                                else -> Color.Gray
                            },
                        )
                    }
                    if (total > 0) {
                        Spacer(Modifier.height(6.dp))
                        LinearProgressIndicator(
                            progress = { counted.toFloat() / total },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
    } else {
        val lpKeys = lpGroups.keys.sortedBy { key ->
            lpGroups[key]?.firstOrNull()?.let { if (isLoose(key)) it.optString("itemNo") else key } ?: key
        }
        val doneCount = lpKeys.count { lpDone(it) }
        val hasPallets = lpKeys.any { !isLoose(it) }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("📍 $activeBin", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { activeBin = ""; expandedLp = "" }) { Text("‹ Adresler", fontSize = 12.sp) }
        }
        Text(
            "$doneCount/${lpKeys.size} " + (if (hasPallets) "kalem" else "ürün") + " sayıldı",
            fontSize = 12.sp, color = Color.Gray,
        )
        Spacer(Modifier.height(8.dp))
        ScanField(
            label = "LP, ürün veya lot barkodu okut",
            value = lpScan,
            onValueChange = { lpScan = it },
            onScanned = { handleLpScan(it) },
            // Bilgi kartı açıkken ikinci okutma hedefi sessizce değiştirmesin.
            enabled = !busy && scanned == null && unexpectedItem == null && unexpectedLp == null && lotSelection == null,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        lpKeys.forEach { lp ->
            val group = lpGroups[lp].orEmpty()
            val done = lpDone(lp)
            val loose = isLoose(lp)
            val head = group.firstOrNull() ?: JSONObject()
            val title = if (loose) head.optString("itemNo") else lp
            Card(
                onClick = { if (loose) openTarget(lp, title, group) else expandedLp = if (expandedLp == lp) "" else lp },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                shape = RoundedCornerShape(10.dp),
            ) {
                Column(Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text((if (done) "✅ " else "⏳ ") + title, fontWeight = FontWeight.Bold)
                        Spacer(Modifier.weight(1f))
                        val countedShown = if (loose) countedQtyOf(head) else null
                        Text(
                            when {
                                countedShown != null -> "Sayılan: ${fmtq(countedShown)} ${firstValue(head, "unitOfMeasureCode")}".trim()
                                loose -> "Sistem: ${fmtq(head.optDouble("systemQty"))} ${firstValue(head, "unitOfMeasureCode")}".trim()
                                else -> "${group.size} satır"
                            },
                            fontSize = 12.sp,
                            fontWeight = if (countedShown != null) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (countedShown != null) Color(0xFF15803D) else Color.Gray,
                        )
                    }
                    if (loose) {
                        val nm = head.optString("description").ifBlank { itemNames[title].orEmpty() }
                        if (nm.isNotBlank()) Text(nm, fontSize = 12.sp, color = Color.Gray)
                        val tracking = trackingText(head)
                        if (tracking.isNotBlank()) {
                            Text(
                                tracking,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        } else {
                            Text("Lot/seri takibi yok", fontSize = 11.sp, color = Color.Gray)
                        }
                    }
                    if (head.optBoolean("unexpectedStock")) {
                        Text(
                            "⚠️ Bu rafta beklenmeyen fiziksel stok",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color(0xFFC2410C),
                        )
                    }
                    if (expandedLp == lp) {
                        Spacer(Modifier.height(8.dp))
                        group.forEach { ln ->
                            TextButton(onClick = { onEditLine(ln) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                                Column(Modifier.fillMaxWidth()) {
                                    Text(ln.optString("itemNo"), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    val tracking = trackingText(ln)
                                    if (tracking.isNotBlank()) Text(tracking, fontSize = 12.sp)
                                    val counted = countedQtyOf(ln)
                                    Text(
                                        "Sistem: ${fmtq(ln.optDouble("systemQty"))} ${firstValue(ln, "unitOfMeasureCode")}" +
                                            if (counted != null) " · Sayılan: ${fmtq(counted)}" else " · Henüz sayılmadı",
                                        fontSize = 12.sp,
                                        color = if (counted != null) Color(0xFF15803D) else Color.Gray,
                                    )
                                }
                            }
                        }
                        if (!loose) {
                            OutlinedButton(
                                onClick = { printLpLabel(lp) },
                                enabled = !busy,
                                modifier = Modifier.fillMaxWidth(),
                            ) { WmsActionLabel(WmsGlyph.PRINTER, "LP etiketini yazdır") }
                        }
                        if (!loose && !done) {
                            OutlinedButton(onClick = { openTarget(lp, lp, group) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                                Text("✅ Paleti say")
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { confirmClose = true },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("🔒 Adresi Kapat", fontWeight = FontWeight.Bold) }
    }

    val sc = scanned
    if (sc != null) {
        val total = sc.lines.sumOf { it.optDouble("systemQty", 0.0) }
        // LP'siz (dökme) kalemde QR miktarı varsa alan onunla başlar; operatör
        // fiziksel sonuca göre değiştirebilir. QR miktarı yoksa manuel giriş
        // zorunludur. Sistemin sayısını otomatik onaylatmak sayım değildir.
        val loose = sc.lines.all { it.optString("lpNo").isBlank() }
        val singleLineLabelQty = sc.labelQty.takeIf { sc.lines.size == 1 }
        val singleLineSuggestedQty = sc.suggestedQty.takeIf { sc.lines.size == 1 }
        val singleLinePrefillQty = singleLineLabelQty
            ?: singleLineSuggestedQty
            ?: sc.lines.singleOrNull()?.takeUnless { loose }?.optDouble("systemQty", 0.0)
        val prefillSource = when {
            singleLineLabelQty != null -> "Etiket QR'ı"
            singleLineSuggestedQty != null -> sc.suggestedQtySource.ifBlank { "BC lot kaydı" }
            singleLinePrefillQty != null -> "LP kaydı"
            else -> ""
        }
        var manualQty by remember(sc) { mutableStateOf(singleLinePrefillQty?.let(::fmtq).orEmpty()) }
        com.dynops.bcwms.ui.SheetScaffold(
            onDismiss = { scanned = null },
            contentPadding = PaddingValues(20.dp),
        ) {
            Text("Okutulan: ${sc.label}", fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Text("Adres: $activeBin", fontSize = 12.sp, color = Color.Gray)
            if (sc.misplacedFrom.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Surface(shape = RoundedCornerShape(10.dp), color = Color(0xFFEA580C).copy(alpha = 0.14f)) {
                    Text(
                        "⚠️ Bu palet sistemde ${sc.misplacedFrom} adresinde kayıtlı, siz $activeBin adresinde okuttunuz.",
                        Modifier.fillMaxWidth().padding(12.dp),
                        fontSize = 12.sp,
                        color = Color(0xFFC2410C),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            Spacer(Modifier.height(14.dp))
            sc.lines.forEach { ln ->
                val itemNo = ln.optString("itemNo")
                val name = ln.optString("description").ifBlank { itemNames[itemNo].orEmpty() }
                val uom = firstValue(ln, "unitOfMeasureCode")
                val shownLot = ln.optString("lotNo").ifBlank { sc.lotNo }
                val tracking = listOfNotNull(
                    shownLot.takeIf { it.isNotBlank() }?.let { "Lot: $it" },
                    ln.optString("serialNo").takeIf { it.isNotBlank() }?.let { "Seri: $it" },
                ).joinToString(" · ")
                Card(
                    onClick = { val line = ln; scanned = null; onEditLine(line) },
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Text("Madde No: $itemNo", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Text(
                            "Ürün Adı: " + name.ifBlank { "—" },
                            fontSize = 14.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        val labelQty = singleLineLabelQty
                        if (loose) {
                            // Dökme mal: sistem miktarı yalnız karşılaştırma bilgisidir.
                            Text(
                                "Sistem kaydı: ${fmtq(ln.optDouble("systemQty"))} $uom".trim(),
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            val automaticQty = labelQty ?: singleLineSuggestedQty
                            if (automaticQty != null) {
                                val sysQty = ln.optDouble("systemQty", 0.0)
                                val diff = automaticQty - sysQty
                                Text(
                                    "Önerilen miktar: ${fmtq(automaticQty)} $uom · $prefillSource kaynağından geldi" +
                                        if (diff != 0.0) " · Sistem farkı: ${if (diff > 0) "+" else ""}${fmtq(diff)}" else " · Fark yok",
                                    fontSize = 12.sp,
                                    color = if (diff != 0.0) Color(0xFFC2410C) else Color(0xFF15803D),
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        } else {
                            Text(
                                "Miktar: ${fmtq(labelQty ?: singleLineSuggestedQty ?: ln.optDouble("systemQty"))} $uom".trim(),
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp,
                            )
                            if (labelQty != null) {
                                val sysQty = ln.optDouble("systemQty", 0.0)
                                val diff = labelQty - sysQty
                                Text(
                                    "Etiket QR'ından okundu · Sistem: ${fmtq(sysQty)}" +
                                        if (diff != 0.0) " · Fark: ${if (diff > 0) "+" else ""}${fmtq(diff)}" else " · Fark yok",
                                    fontSize = 12.sp,
                                    color = if (diff != 0.0) Color(0xFFC2410C) else Color(0xFF15803D),
                                    fontWeight = FontWeight.SemiBold,
                                )
                            } else if (singleLineSuggestedQty != null) {
                                Text(
                                    "BC lot kaydından otomatik getirildi · Fiziksel sayıma göre düzenlenebilir",
                                    fontSize = 11.sp,
                                    color = Color.Gray,
                                )
                            } else {
                                Text("Kaynak: LP kaydı (etiket basımındaki içerik)", fontSize = 11.sp, color = Color.Gray)
                            }
                        }
                        if (tracking.isNotBlank()) Text(tracking, fontSize = 12.sp, color = Color.Gray)
                        if (!loose) Text("Dokunarak miktarı düzeltebilirsiniz", fontSize = 11.sp, color = Color.Gray)
                    }
                }
            }
            if (sc.lines.size > 1) {
                Spacer(Modifier.height(4.dp))
                Text("Toplam: ${fmtq(total)}", fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(16.dp))
            if (sc.lines.size == 1) {
                OutlinedTextField(
                    value = manualQty,
                    onValueChange = { manualQty = it.replace(',', '.').filter { c -> c.isDigit() || c == '.' } },
                    label = {
                        Text(
                            if (singleLinePrefillQty != null) "Sayılan Miktar ($prefillSource)"
                            else "Sayılan Miktar (zorunlu)"
                        )
                    },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    if (singleLinePrefillQty != null)
                        "Miktar $prefillSource kaynağından otomatik dolduruldu. Fiziksel sayım farklıysa değeri değiştirebilirsiniz."
                    else
                        "Etiket ve BC lot kaydında miktar bulunamadı — fiziksel miktarı elle girin.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(10.dp))
                Button(
                    onClick = {
                        val t = sc
                        val q = manualQty.toDoubleOrNull()
                        if (q != null) { scanned = null; commitTarget(t, manualQty = q) }
                    },
                    enabled = !busy && manualQty.toDoubleOrNull() != null,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                ) { Text("✅ Sayılan miktarla $activeBin adresine kaydet", fontWeight = FontWeight.Bold) }
            } else {
                Button(
                    onClick = { val t = sc; scanned = null; commitTarget(t) },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                ) { Text("✅ $activeBin adresine sayıldı olarak kaydet", fontWeight = FontWeight.Bold) }
            }
            TextButton(onClick = { scanned = null }, modifier = Modifier.fillMaxWidth()) { Text("Vazgeç") }
            Spacer(Modifier.height(24.dp))
        }
    }

    val unexpectedItemDraft = unexpectedItem
    if (unexpectedItemDraft != null) {
        UnexpectedStockSheet(
            activeBin = activeBin,
            draft = unexpectedItemDraft,
            busy = busy,
            serverReady = serverCapabilities?.unexpectedItemAction == true,
            onDismiss = { unexpectedItem = null },
            onConfirm = { itemNo, variantCode, uom, lotNo, serialNo, qty ->
                recordUnexpectedItem(itemNo, variantCode, uom, lotNo, serialNo, qty)
            },
        )
    }

    val unexpectedLpDraft = unexpectedLp
    if (unexpectedLpDraft != null) {
        AlertDialog(
            onDismissRequest = { if (!busy) unexpectedLp = null },
            title = { Text("LP farklı rafta bulundu") },
            text = {
                Text(
                    "${unexpectedLpDraft.lpNo} sistemde ${unexpectedLpDraft.registeredBin} rafında görünüyor. " +
                        "Fiziksel olarak $activeBin rafında buldunuz. Bu LP'yi $activeBin rafında sayarsanız " +
                        "eski rafta eksik, bu rafta fazla farkı oluşur; post başarılı olunca LP rafı güncellenir."
                )
            },
            confirmButton = {
                TextButton(
                    onClick = { recordUnexpectedLp(unexpectedLpDraft) },
                    enabled = !busy && serverCapabilities?.unexpectedLpAction == true,
                ) {
                    Text("Fiziksel rafta say")
                }
            },
            dismissButton = {
                TextButton(onClick = { unexpectedLp = null }, enabled = !busy) { Text("Vazgeç") }
            },
        )
    }

    val lotPick = lotSelection
    if (lotPick != null) {
        AlertDialog(
            onDismissRequest = { lotSelection = null },
            title = { Text("Lot ${lotPick.first} — ilgili kaydı seçin") },
            text = {
                Column(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 460.dp).verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        "Aynı lot için birden fazla sayım kaydı bulundu. Madde, LP ve miktarı kontrol ederek doğru kaydı seçin.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    lotPick.second.forEach { target ->
                        val head = target.lines.first()
                        val itemNo = head.optString("itemNo")
                        val name = head.optString("description").ifBlank { itemNames[itemNo].orEmpty() }
                        val lpNo = head.optString("lpNo")
                        val uom = firstValue(head, "unitOfMeasureCode")
                        val qty = target.suggestedQty ?: target.lines.sumOf { it.optDouble("systemQty", 0.0) }
                        OutlinedButton(
                            onClick = {
                                lotSelection = null
                                scanned = target
                                onStatus("TAMAM: Lot ${lotPick.first} için ${target.label} seçildi")
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Column(Modifier.fillMaxWidth()) {
                                Text("$itemNo — ${name.ifBlank { "Ürün adı yok" }}", fontWeight = FontWeight.Bold)
                                Text(
                                    (if (lpNo.isNotBlank()) "LP: $lpNo · " else "") +
                                        "Miktar: ${fmtq(qty)} $uom",
                                    fontSize = 12.sp,
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { lotSelection = null }) { Text("Vazgeç") }
            },
        )
    }


    val mp = misplaced
    if (mp != null) {
        AlertDialog(
            onDismissRequest = { misplaced = null },
            title = { Text("Palet başka adreste görünüyor") },
            text = {
                Text(
                    "${mp.first} sistemde ${mp.second} adresinde kayıtlı, siz $activeBin adresinde okuttunuz. " +
                        "Paleti bulunduğu yerde tam sayalım mı? (Adres farkı sayım sonrası düzeltilmeli.)"
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    val lp = mp.first
                    val from = mp.second
                    misplaced = null
                    openTarget(lp, lp, lines.filter { it.optString("lpNo").equals(lp, ignoreCase = true) }, misplacedFrom = from)
                }) { Text("Evet, göster") }
            },
            dismissButton = { TextButton(onClick = { misplaced = null }) { Text("Vazgeç") } },
        )
    }

    if (confirmClose) {
        val pending = lpGroups.keys.filter { !lpDone(it) }
        val canRecordZero = serverCapabilities?.explicitZeroCount == true
        AlertDialog(
            onDismissRequest = { confirmClose = false },
            title = { Text("$activeBin kapatılsın mı?") },
            text = {
                val names = pending.map { key ->
                    if (isLoose(key)) lpGroups[key]?.firstOrNull()?.optString("itemNo").orEmpty().ifBlank { key } else key
                }
                Text(
                    if (pending.isEmpty()) "Bu adresteki tüm kalemler sayıldı."
                    else if (canRecordZero)
                        "Sayılmayan ${pending.size} kalem var: ${names.joinToString(", ")}. " +
                            "Kapatırsanız bunlar EKSİK sayılır (miktar 0) ve sayım farkı oluşur."
                    else
                        "Sayılmayan ${pending.size} kalem var: ${names.joinToString(", ")}. " +
                            "Sıfır sayımı şu anda kaydedilemiyor. Yenileyip tekrar deneyin; sorun sürerse yöneticinize bildirin."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmClose = false
                    val toZero = pending.flatMap { lpGroups[it].orEmpty() }.filter { !alreadyCounted(it) }
                    scope.launch {
                        onBusy(true); onStatus("$activeBin kapatılıyor...")
                        var savedCount = 0
                        for (ln in toZero) {
                            if (!writeQty(ln, 0.0)) break
                            savedCount += 1
                        }
                        onBusy(false)
                        val progress = sequentialWriteProgress(toZero.size, savedCount)
                        if (toZero.isEmpty() || progress.complete) {
                            closedBins = closedBins + activeBin
                            handledLps = handledLps + pending
                            onStatus("TAMAM: $activeBin kapatıldı" + if (pending.isEmpty()) "" else " — ${pending.size} palet eksik")
                            activeBin = ""
                            expandedLp = ""
                            onReload()
                        } else if (progress.partial) {
                            onStatus(
                                "UYARI: $activeBin için ${progress.succeeded}/${progress.total} sıfır sayım kaydı yazıldı; " +
                                    "adres kapatılmadı. Veriler yeniden yükleniyor; kalemleri kontrol edin."
                            )
                            onReload()
                        }
                    }
                }, enabled = pending.isEmpty() || canRecordZero) { Text("Kapat") }
            },
            dismissButton = { TextButton(onClick = { confirmClose = false }) { Text("Vazgeç") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun UnexpectedStockSheet(
    activeBin: String,
    draft: UnexpectedItemDraft,
    busy: Boolean,
    serverReady: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (itemNo: String, variantCode: String, uom: String, lotNo: String, serialNo: String, qty: Double) -> Unit,
) {
    var itemNo by remember(draft) { mutableStateOf(draft.itemNo) }
    var variantCode by remember(draft) { mutableStateOf(draft.variantCode) }
    var uom by remember(draft) { mutableStateOf(draft.unitOfMeasureCode) }
    var lotNo by remember(draft) { mutableStateOf(draft.lotNo) }
    var serialNo by remember(draft) { mutableStateOf(draft.serialNo) }
    var qty by remember(draft) { mutableStateOf(draft.suggestedQty?.let(::fmtq).orEmpty()) }
    val parsedQty = qty.toDoubleOrNull()

    com.dynops.bcwms.ui.SheetScaffold(
        onDismiss = { if (!busy) onDismiss() },
        contentPadding = PaddingValues(20.dp),
    ) {
        Text("Beklenmeyen fiziksel stok", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(6.dp))
        Text(
            "$activeBin rafında, üretilen sayım satırlarında bulunmayan stok tespit edildi. " +
                "Doğrulanan miktar sistem 0'a karşı pozitif fark olarak kaydedilecek.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (!serverReady) {
            Spacer(Modifier.height(8.dp))
            Text(
                "Kayıt şu anda kullanılamıyor. Yenileyip tekrar deneyin; sorun sürerse yöneticinize bildirin.",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFFBE123C),
            )
        }
        if (draft.systemBins.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text(
                "Sistemde beklenen raf: ${draft.systemBins.joinToString(", ")}",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFFC2410C),
            )
        }
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = itemNo,
            onValueChange = { itemNo = it },
            label = { Text("Ürün No. *") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = qty,
            onValueChange = { qty = it.replace(',', '.').filter { c -> c.isDigit() || c == '.' } },
            label = { Text("Fiziksel Miktar *") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = variantCode,
            onValueChange = { variantCode = it },
            label = { Text("Varyant (varsa)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = uom,
            onValueChange = { uom = it },
            label = { Text("Birim (boşsa ürün temel birimi)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = lotNo,
            onValueChange = { lotNo = it },
            label = { Text("Lot No.") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = serialNo,
            onValueChange = { serialNo = it },
            label = { Text("Seri No.") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = {
                parsedQty?.let {
                    onConfirm(itemNo.trim(), variantCode.trim(), uom.trim(), lotNo.trim(), serialNo.trim(), it)
                }
            },
            enabled = serverReady && !busy && itemNo.isNotBlank() && parsedQty != null && parsedQty > 0.0,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("Bu rafta say", fontWeight = FontWeight.Bold) }
        TextButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.fillMaxWidth()) { Text("Vazgeç") }
        Spacer(Modifier.height(24.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CountEntrySheet(
    line: JSONObject,
    locationCode: String,
    initialSlot: Int = 1,
    allowedSlots: List<Int> = listOf(initialSlot),
    onDismiss: () -> Unit,
    onConfirm: (slot: Int, qty: Double) -> Unit,
) {
    val context = LocalContext.current
    // Panelde seçilen sayıcı slotu devralınır: elle düzeltme başka slota
    // (varsayılan 1'e) kayıp 1. sayıcının değerini ezmesin.
    var slot by remember { mutableStateOf(initialSlot) }
    fun slotWasCounted(selectedSlot: Int): Boolean =
        isCountRecorded(
            hasExplicitFlag = line.has("counted$selectedSlot"),
            explicitFlag = line.optBoolean("counted$selectedSlot"),
            quantity = line.optDouble("countedQty$selectedSlot", 0.0),
        )
    fun qtyForSlot(selectedSlot: Int): String = line.optDouble("countedQty$selectedSlot", 0.0)
        .takeIf { slotWasCounted(selectedSlot) }
        ?.let(::fmtq)
        .orEmpty()
    var qty by remember(line, initialSlot) { mutableStateOf(qtyForSlot(initialSlot)) }
    var lotBalances by remember(line, locationCode) { mutableStateOf<List<JSONObject>>(emptyList()) }
    var lotProbeFinished by remember(line, locationCode) { mutableStateOf(false) }
    var lotProbeSucceeded by remember(line, locationCode) { mutableStateOf(false) }
    LaunchedEffect(line.optInt("lineNo"), locationCode) {
        val itemNo = line.optString("itemNo")
        val binCode = rawValue(line, "binCode")
        val variantCode = line.optString("variantCode")
        if (locationCode.isBlank() || itemNo.isBlank() || binCode.isBlank()) {
            lotProbeFinished = true
            lotProbeSucceeded = true
            return@LaunchedEffect
        }
        fun safe(value: String) = value.replace("'", "''")
        val filter = buildList {
            add("locationCode eq '${safe(locationCode)}'")
            add("binCode eq '${safe(binCode)}'")
            add("itemNo eq '${safe(itemNo)}'")
            if (variantCode.isNotBlank()) add("variantCode eq '${safe(variantCode)}'")
        }.joinToString(" and ")
        val page = BcApi.getAllPages(context, "availableLots?\$filter=$filter&\$top=100")
        lotBalances = if (page.complete) {
            page.rows.filter { row ->
                row.optString("lotNo").isNotBlank() &&
                    (if (row.has("quantity")) row.optDouble("quantity") else row.optDouble("quantityBase")) > 0.0
            }
        } else emptyList()
        lotProbeSucceeded = page.complete
        lotProbeFinished = true
    }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Sayım Gir — ${line.optString("itemNo")}", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        val lpInfo = line.optString("lpNo").takeIf { it.isNotBlank() }?.let { "LP: $it · " }.orEmpty()
        val lineLotNo = line.optString("lotNo")
        val lineSerialNo = line.optString("serialNo")
        val tracking = listOfNotNull(
            lineLotNo.takeIf { it.isNotBlank() }?.let { "Lot: $it" },
            lineSerialNo.takeIf { it.isNotBlank() }?.let { "Seri: $it" },
        ).joinToString(" · ")
        Text(lpInfo + "Bin: ${firstValue(line, "binCode")}", fontSize = 12.sp, color = Color.Gray)
        if (tracking.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.10f),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(12.dp)) {
                    Text(
                        if (lineLotNo.isNotBlank()) "Bu giriş yalnız Lot $lineLotNo içindir"
                        else "Bu giriş yalnız Seri $lineSerialNo içindir",
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        "Bu lot/serinin sistem miktarı: ${fmtq(line.optDouble("systemQty"))} ${firstValue(line, "unitOfMeasureCode")}".trim(),
                        fontSize = 13.sp,
                    )
                }
            }
        } else {
            Text(
                "Bu satırın sistem miktarı: ${fmtq(line.optDouble("systemQty"))} ${firstValue(line, "unitOfMeasureCode")}".trim(),
                fontSize = 12.sp,
                color = Color.Gray,
            )
        }
        if (lotBalances.isNotEmpty()) {
            Spacer(Modifier.height(10.dp))
            Text("Bu raftaki lot bazlı BC miktarı", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            lotBalances.forEach { balance ->
                val balanceQty = if (balance.has("quantity")) balance.optDouble("quantity") else balance.optDouble("quantityBase")
                val selected = balance.optString("lotNo").equals(lineLotNo, ignoreCase = true)
                Text(
                    (if (selected) "▶ " else "• ") +
                        "Lot ${balance.optString("lotNo")}: ${fmtq(balanceQty)} ${balance.optString("unitOfMeasureCode")}".trim(),
                    fontSize = 12.sp,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                    color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        val needsLotSelection = countLineNeedsLotSelection(
            lineLotNo,
            lotBalances.map { it.optString("lotNo") },
        )
        if (lotProbeFinished && !lotProbeSucceeded) {
            Spacer(Modifier.height(8.dp))
            StatusText("HATA: Raftaki lotların tamamı doğrulanamadı. Sayımı kaydetmeden önce bağlantıyı kontrol edip yeniden açın.")
        }
        if (lotProbeFinished && needsLotSelection) {
            Spacer(Modifier.height(8.dp))
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = Color(0xFFFFE4E6),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    "Bu ürünün rafta lotlu stoğu var ancak seçilen sayım satırında lot yok. " +
                        "Yanlış lota miktar yazılmaması için kayıt kapatıldı; geri dönüp lot satırını seçin veya lot barkodunu okutun.",
                    Modifier.padding(12.dp),
                    color = Color(0xFF9F1239),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
        val existingCounts = (1..3).mapNotNull { countSlot ->
            line.optDouble("countedQty$countSlot", 0.0)
                .takeIf { slotWasCounted(countSlot) }
                ?.let { "$countSlot. sayım: ${fmtq(it)}" }
        }
        if (existingCounts.isNotEmpty()) {
            Text(
                "Girilen miktarlar · ${existingCounts.joinToString(" · ")}",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFF15803D),
            )
        }
        Spacer(Modifier.height(12.dp))
        Text("Sayım turu", fontSize = 12.sp, color = Color.Gray)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            allowedSlots.forEach { s ->
                FilterChip(
                    selected = slot == s,
                    onClick = { slot = s; qty = qtyForSlot(s) },
                    label = { Text("Sayıcı $s") },
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        // Virgül noktaya çevrilir (TR klavye '12,5' → '125' olmasın); geçersiz
        // girdide buton kilitli kalır — 0.0'a sessiz düşüş yok.
        OutlinedTextField(
            qty,
            { qty = it.replace(',', '.').filter { c -> c.isDigit() || c == '.' } },
            label = {
                Text(
                    when {
                        lineLotNo.isNotBlank() -> "Sayılan Miktar — Lot $lineLotNo"
                        lineSerialNo.isNotBlank() -> "Sayılan Miktar — Seri $lineSerialNo"
                        else -> "Sayılan Miktar"
                    }
                )
            },
            enabled = lotProbeFinished && lotProbeSucceeded && !needsLotSelection,
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
        val parsedQty = qty.toDoubleOrNull()
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = parsedQty != null && lotProbeFinished && lotProbeSucceeded && !needsLotSelection,
            onClick = {
            parsedQty?.let { onConfirm(slot, it) }
        }) { Text("Sayımı Kaydet") }
        Spacer(Modifier.height(24.dp))
    }
}

/**
 * Directed Movement — WI §10.5 (directed variant).
 * Lists warehouse movement documents -> Register. BC: movements / register (warehouse/v2.0).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DirectedMoveModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }
    var showAll by remember { mutableStateOf(true) }

    fun load() {
        scope.launch {
            loading = true; status = "Hareket belgeleri yükleniyor..."
            val myUser = if (showAll) "" else BcApi.currentUserId(context)
            if (!showAll && myUser.isBlank()) {
                rows = emptyList()
                loading = false
                status = "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
                return@launch
            }
            val filter = buildODataFilter(
                assignedToMeClause(myUser, enabled = !showAll),
                searchClause("no", search),
            )
            val page = BcApi.getAllPages(context, "movements?\$top=100&\$orderby=no desc&\$select=no,locationCode,assignedUserId,status$filter")
            loading = false
            rows = if (page.complete) page.rows else emptyList()
            status = if (!page.complete) "HATA: Hareket listesinin tamamı alınamadı. Yenileyin."
                else if (rows.isEmpty()) "BOŞ: Açık yönlendirilmiş hareket belgesi yok"
                else "TAMAM: ${rows.size} belge"
        }
    }
    LaunchedEffect(showAll) { load() }

    // Paylaşımlı lisans: belge oturumdaki WMS kullanıcısına atanır.
    fun takeOver(no: String) {
        scope.launch {
            loading = true; status = "Üzerine alınıyor..."
            val me = BcApi.currentUserId(context)
            val r = if (me.isNotBlank())
                BcApi.boundAction(context, "movements", no, "assignTo", JSONObject().apply { put("userId", me) }.toString())
            else BcApi.ApiResult(false, 0, "Oturum kullanıcısı çözülemedi")
            status = if (r.ok) "TAMAM: $no üzerinize alındı ($me)"
                else operatorFacingStatus("HATA: ${BcApi.errorMessage(r.body)}")
            load()
        }
    }

    val sel = selected
    if (sel != null) { MovementDocument(no = sel, onBack = { selected = null; load() }); return }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            FilterChip(selected = !showAll, onClick = { showAll = false }, label = { Text("👤 Bana atanan") })
            Spacer(Modifier.width(6.dp))
            FilterChip(selected = showAll, onClick = { showAll = true }, label = { Text("Tümü") })
            Spacer(Modifier.weight(1f))
            OutlinedButton(
                onClick = { load() },
                enabled = !loading,
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 14.dp),
            ) { WmsRefreshLabel(loading, compact = true) }
        }
        Spacer(Modifier.height(8.dp))
        DocSearchBar(value = search, onValueChange = { search = it }, onSearch = { load() }, label = "Hareket no ile ara")
        Spacer(Modifier.height(4.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(rows) { d ->
                val no = d.optString("no")
                val assigned = d.optString("assignedUserId").trim()
                Card(onClick = { selected = no }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("🧭 $no", fontWeight = FontWeight.Bold)
                            Text(firstValue(d, "status"), fontSize = 12.sp, color = Color.Gray)
                        }
                        Text(
                            "Lokasyon: ${firstValue(d, "locationCode")} · " +
                                (if (assigned.isBlank()) "⏳ Atanmayı bekliyor" else "👤 Atanan Kullanıcı: $assigned"),
                            fontSize = 12.sp, color = Color.Gray,
                        )
                        if (assigned.isBlank()) {
                            Spacer(Modifier.height(6.dp))
                            Button(
                                onClick = { takeOver(no) },
                                enabled = !loading,
                                modifier = Modifier.fillMaxWidth().height(40.dp),
                            ) { Text("✋ Üzerime Al", fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                        }
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("Açık yönlendirilmiş hareket belgesi yok. Ofis, Movement Worksheet'ten \"Create Movement\" ile belge oluşturur.") }
        }
    }
}

/**
 * Movement belgesi: Take/Place satırlarını göster, ürün okutunca (veya satıra
 * dokunup miktar girince) qtyToHandle set edilir; "Register Movement" belgedeki
 * işlenmiş miktarları BC'de kaydeder (Whse.-Activity-Register).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MovementDocument(no: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var qtyLine by remember { mutableStateOf<JSONObject?>(null) }
    var headerLoaded by remember(no) { mutableStateOf(false) }
    var linesComplete by remember(no) { mutableStateOf(false) }
    var myUserId by remember(no) { mutableStateOf("") }

    fun canMutate(): Boolean = headerLoaded && linesComplete &&
        canMutateAssignedDocument(header?.optString("assignedUserId").orEmpty(), myUserId)

    fun requireMutationAccess(): Boolean {
        if (canMutate()) return true
        status = when {
            !headerLoaded || !linesComplete -> "HATA: Hareket belgesi tamamen yüklenmedi. Yenileyin."
            myUserId.isBlank() -> "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
            header?.optString("assignedUserId").isNullOrBlank() -> "Bu belge henüz size atanmadı. Listeden Üzerime Al işlemini kullanın."
            else -> "Bu belge başka bir kullanıcıya atanmış. İşlem yapılamaz."
        }
        return false
    }

    fun reload(afterRegisterAttempt: Boolean = false) {
        scope.launch {
            val previousStatus = status
            busy = true
            header = null
            lines = emptyList()
            headerLoaded = false
            linesComplete = false
            qtyLine = null
            val safeNo = no.replace("'", "''")
            val (h, l, me) = coroutineScope {
                val headerRequest = async { BcApi.get(context, "movements('$safeNo')") }
                val linesRequest = async {
                    BcApi.getAllPages(context, "movementLines?\$filter=no eq '$safeNo'&\$top=200")
                }
                val userRequest = async { BcApi.currentUserId(context) }
                Triple(headerRequest.await(), linesRequest.await(), userRequest.await())
            }
            // Register tamamlandığında açık belge API'sinden kaybolması
            // beklenen durumdur. Timeout sonrası 404 de sunucu başarısını
            // doğrular; operatörü yeniden kayda yönlendirmeyiz.
            if (afterRegisterAttempt && h.httpCode == 404) {
                busy = false
                status = "TAMAM: $no sunucuda kaydedildi."
                onBack()
                return@launch
            }
            header = if (h.ok) runCatching { JSONObject(h.body) }.getOrNull() else null
            headerLoaded = header != null
            linesComplete = l.complete
            lines = if (l.complete) l.rows else emptyList()
            myUserId = me.trim()
            busy = false
            status = when {
                !headerLoaded || !linesComplete -> "HATA: Hareket belgesi ve tüm satırları alınamadı. Yenileyin."
                myUserId.isBlank() -> "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
                !canMutate() -> "Bu belge size atanmadığı için salt okunur açıldı."
                afterRegisterAttempt -> previousStatus
                previousStatus.startsWith("HATA:") -> ""
                else -> previousStatus
            }
        }
    }
    LaunchedEffect(no) { reload() }

    suspend fun patchLine(ln: JSONObject, qty: Double, lotNo: String, serialNo: String): Boolean {
        if (!requireMutationAccess()) return false
        val body = directedMovementConfirmBody(ln.optInt("lineNo"), qty, lotNo, serialNo, myUserId)
        // Sunucu Take + Place eşini birlikte günceller; tek satır PATCH'i
        // companion satırı sıfırda bırakıp register butonunu kilitliyordu.
        val r = BcApi.boundAction(context, "movements", no, "confirmLine", body)
        if (!r.ok) status = "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
        return r.ok
    }

    // Barkod yalnızca tek bir Take satırını belirliyorsa miktar/lot
    // ekranını aç. Lot takipli stokta doğrudan miktar yazmak, hatayı ancak
    // register sırasında gösteriyordu.
    // Aynı ürün farklı lot/raf satırlarında yer alıyorsa topluca yazmak
    // yanlış stok hareketi yaratır; operatör kesin satırı seçmelidir.
    fun confirmItem(itemNo: String) {
        if (!requireMutationAccess()) return
        val targets = directedMovementTakeMatches(lines, itemNo)
        when {
            targets.isEmpty() -> status = "HATA: $itemNo için bekleyen Al satırı bulunamadı."
            targets.size > 1 ->
                status = "HATA: $itemNo için birden fazla Al satırı var. Lot/rafı doğrulamak için ilgili Al satırına dokunun."
            else -> {
                status = ""
                qtyLine = targets.single()
            }
        }
    }

    DocumentScanHandler(
        enabled = qtyLine == null && !busy && canMutate(),
        lines = lines.filter { it.optString("actionType").equals("Take", ignoreCase = true) },
        onSingleMatch = { line, _ -> confirmItem(line.optString("itemNo")) },
        onMultiMatch = { itemNo, _ -> confirmItem(itemNo) },
        onNoMatch = { r -> status = "⚠️ '${r.itemNo ?: r.value}' bu belgede yok" },
    )

    val totalQty = lines.sumOf { it.optDouble("quantity", 0.0) }
    val handledOrStaged = lines.sumOf { maxOf(it.optDouble("qtyHandled", 0.0), it.optDouble("qtyToHandle", 0.0)) }
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(12.dp)) {
            TextButton(onClick = onBack) { Text("‹ Hareket Listesi") }
            DocHeaderCard(
                title = "🧭 $no",
                subtitle = "Lokasyon: ${header?.optString("locationCode") ?: ""} · 👤 Atanan Kullanıcı: ${rawValue(header ?: JSONObject(), "assignedUserId").ifBlank { "—" }}",
                percent = if (totalQty > 0) ((handledOrStaged / totalQty) * 100).toInt().coerceIn(0, 100) else 0,
            )
            Spacer(Modifier.height(6.dp))
            StatusText(status)
            Spacer(Modifier.height(6.dp))
            Text(
                if (canMutate()) "Satırlar (${lines.size}) — ürünü okutun ya da satıra dokunup miktar girin"
                else "Satırlar (${lines.size}) — işlem için belgeyi üzerinize alın",
                fontSize = 12.sp,
                color = Color.Gray,
            )
            Spacer(Modifier.height(6.dp))
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                lines.forEach { ln ->
                    val take = ln.optString("actionType").equals("Take", ignoreCase = true)
                    val toHandle = ln.optDouble("qtyToHandle", 0.0)
                    val qty = ln.optDouble("quantity", 0.0)
                    val done = ln.optDouble("qtyHandled", 0.0) >= qty && qty > 0
                    Card(
                        onClick = { qtyLine = ln },
                        enabled = !busy && canMutate() && take,
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = when {
                                done -> Color(0xFFE8F5E9)
                                toHandle >= qty && qty > 0 -> Color(0xFFF3F1FD)
                                else -> MaterialTheme.colorScheme.surface
                            },
                        ),
                    ) {
                        Column(Modifier.padding(10.dp)) {
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(
                                    "${if (take) "📤 Al" else "📥 Bırak"} · ${ln.optString("itemNo")}",
                                    fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                                )
                                Text("${fmtq(toHandle)}/${fmtq(qty)}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            }
                            Text(
                                "📍 ${ln.optString("binCode")} · ${firstValue(ln, "description")}" +
                                    (rawValue(ln, "lotNo").takeIf { it.isNotBlank() }?.let { " · Lot $it" } ?: ""),
                                fontSize = 11.sp, color = Color.Gray,
                            )
                        }
                    }
                }
                if (lines.isEmpty() && !busy) EmptyState("Satır yok.")
            }
        }
        BottomActionBar {
            val canRegister = canMutate() && directedMovementReadyToRegister(lines)
            Button(
                onClick = {
                    if (requireMutationAccess()) {
                        scope.launch {
                            busy = true; status = "$no kaydediliyor..."
                            val r = BcApi.boundActionLongRunning(
                                context,
                                "movements",
                                no,
                                "registerFor",
                                JSONObject().apply { put("userId", myUserId) }.toString(),
                            )
                            busy = false
                            status = when {
                                r.ok -> "TAMAM: $no kaydedildi — stok taşındı"
                                BcApi.isAmbiguousMutationFailure(r) ->
                                    "UYARI: Kayıt sonucunun sunucudaki durumu doğrulanamadı. Tekrar kaydetmeyin; güncel durum okunuyor."
                                else -> directedMovementRegisterError(BcApi.errorMessage(r.body), r.httpCode)
                            }
                            // Timeout/5xx sonrasında BC işlemi tamamlamış olabilir. Her iki
                            // durumda da gerçek sunucu durumunu yeniden okuyarak tekrar kayıt
                            // riskini önleriz.
                            reload(afterRegisterAttempt = true)
                        }
                    }
                },
                enabled = !busy && canRegister,
                modifier = Modifier.fillMaxWidth().height(54.dp),
            ) { Text(if (canRegister) "✅ Hareketi Kaydet" else "Önce miktar ve takip bilgisi girin", fontWeight = FontWeight.Bold) }
        }
    }

    val ql = qtyLine.takeIf { canMutate() && !busy }
    if (ql != null) {
        QuantityDialogSheet(
            title = "Miktar (${if (ql.optString("actionType").equals("Take", true)) "Al" else "Bırak"} · 📍 ${ql.optString("binCode")})",
            itemNo = ql.optString("itemNo"),
            initialQty = ql.optDouble("qtyOutstanding", ql.optDouble("quantity")),
            initialUom = ql.optString("unitOfMeasureCode"),
            initialLot = ql.optString("lotNo"),
            initialSerial = ql.optString("serialNo"),
            showLotSerial = true,
            showSerial = ql.optBoolean("serialRequired", false),
            lotRequired = ql.optBoolean("lotRequired", false),
            serialRequired = ql.optBoolean("serialRequired", false),
            showAvailableLotLookup = true,
            autoDetectLotFromStock = true,
            locationCode = rawValue(ql, "locationCode").ifBlank { header?.optString("locationCode").orEmpty() },
            binCode = rawValue(ql, "binCode"),
            variantCode = ql.optString("variantCode"),
            onDismiss = { qtyLine = null },
            onConfirm = { res ->
                qtyLine = null
                scope.launch {
                    busy = true
                    if (patchLine(ql, res.quantity, res.lotNo, res.serialNo)) { status = "TAMAM: Satır güncellendi"; reload() }
                    busy = false
                }
            },
        )
    }
}

internal fun directedMovementConfirmBody(
    lineNo: Int,
    qty: Double,
    lotNo: String,
    serialNo: String,
    userId: String,
): String =
    JSONObject().apply {
        put("lineNo", lineNo)
        put("qtyToHandle", qty)
        put("lotNo", lotNo)
        put("serialNo", serialNo)
        put("userId", userId)
    }.toString()

private fun fmtq(v: Double): String = if (v == v.toLong().toDouble()) v.toLong().toString() else v.toString()

/** A simple "coming soon" placeholder for Phase 2 modules. */
@Composable
fun ComingSoonScreen(title: String, note: String) {
    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(12.dp))
        Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0))) {
            Column(Modifier.padding(16.dp)) {
                Text("Yakında (Faz 2)", fontWeight = FontWeight.Bold, color = Color(0xFFEF6C00))
                Spacer(Modifier.height(6.dp))
                Text(note, fontSize = 13.sp)
            }
        }
    }
}
