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
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * License Plate management — WI §10.10 parity.
 * Lookup list -> document (header + lines) -> actions:
 *   Build new · Add line (scan + qty) · Stop (-> SSCC + print) · Transfer · Unbuild · Print · Partial-use.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LicensePlateModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var showBuild by remember { mutableStateOf(false) }
    var search by remember { mutableStateOf("") }

    fun loadList() {
        scope.launch {
            loading = true; status = "Yükleniyor..."
            val filter = com.dynops.bcwms.ui.buildODataFilter(com.dynops.bcwms.ui.searchClause("no", search))
            val page = BcApi.getAllPagesWithStandardFallback(context, "licensePlates?\$top=200&\$orderby=no desc&\$select=no,status,locationCode,binCode,templateCode,sscc$filter")
            loading = false
            rows = if (page.complete) page.rows else emptyList()
            status = if (!page.complete) "HATA: LP listesinin tamamı alınamadı. Yenileyin."
                else if (rows.isEmpty()) "BOŞ: LP kaydı yok"
                else "TAMAM: ${rows.size} LP"
        }
    }
    LaunchedEffect(Unit) { loadList() }

    val sel = selected
    if (sel != null) {
        LpDocument(lpNo = sel, onBack = { selected = null; loadList() })
        return
    }

    if (showBuild) {
        LpBuildSheet(
            onDismiss = { showBuild = false },
            onBuilt = { newNo -> showBuild = false; loadList(); selected = newNo }
        )
    }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { loadList() }, enabled = !loading) { WmsRefreshLabel(loading) }
            Spacer(Modifier.width(8.dp))
            Button(onClick = { showBuild = true }, enabled = !loading) {
                WmsActionLabel(WmsGlyph.LICENSE_PLATE, "LP Oluştur")
            }
        }
        Spacer(Modifier.height(8.dp))
        com.dynops.bcwms.ui.DocSearchBar(value = search, onValueChange = { search = it }, onSearch = { loadList() }, label = "LP no ile ara")
        Spacer(Modifier.height(4.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(rows) { lp ->
                Card(
                    onClick = { selected = lp.optString("no") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                ) {
                    Column(Modifier.padding(14.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(lp.optString("no"), fontWeight = FontWeight.Bold)
                            StatusBadge(lp.optString("status"))
                        }
                        Text("${lp.optString("templateCode")} · ${lp.optString("locationCode")}/${lp.optString("binCode")}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (lp.optString("sscc").isNotBlank())
                            Text("SSCC: ${lp.optString("sscc")}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("LP kaydı bulunamadı.") }
        }
    }
}

// BC LP durum değeri (wire) → operatöre gösterilen Türkçe etiket. Karşılaştırma/
// renk seçimi ham değerle yapılır; ekranda hep bu etiket görünür.
internal fun lpStatusLabel(status: String): String = when (status) {
    "Open" -> "Açık"
    "Built" -> "Oluşturuldu"
    "Assigned" -> "Atandı"
    "Used" -> "Kullanıldı"
    "Unbuilt" -> "Bozuldu"
    "" -> "Açık"
    else -> status
}

@Composable
private fun StatusBadge(status: String) {
    val (bg, fg) = when (status) {
        "Built" -> Color(0xFFEFF4FF) to Color(0xFF3448A5)
        "Assigned" -> Color(0xFFFFF4E5) to Color(0xFF9A5B00)
        "Used" -> Color(0xFFEAF7EF) to Color(0xFF216E43)
        "Unbuilt" -> Color(0xFFFFECEC) to Color(0xFFA82B2B)
        else -> Color(0xFFF0F2F5) to Color(0xFF536070)
    }
    Surface(color = bg, shape = RoundedCornerShape(50)) {
        Text(lpStatusLabel(status), Modifier.padding(horizontal = 10.dp, vertical = 5.dp), color = fg, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LpBuildSheet(onDismiss: () -> Unit, onBuilt: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // Müşteri/şirket özel varsayılanları kullanma. Yanlış lokasyonda sessiz LP
    // oluşmasını önlemek için üç değer de operatör seçimi/okutmasıyla gelir.
    var template by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var bin by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var err by remember { mutableStateOf("") }
    // PDF LP §5: Template alanı serbest text idi — operatör "CARTON-S"
    // yerine "CARTONS" yazıp sessizce yanlış kayıt yaratıyordu. Dropdown
    // ile mevcut template'lerden seçtirilir.
    var templates by remember { mutableStateOf<List<String>>(emptyList()) }
    LaunchedEffect(Unit) {
        val page = BcApi.getAllPages(context, "licensePlateTemplates?\$top=50&\$select=code,description")
        templates = if (page.complete) {
            page.rows.map { it.optString("code") }.filter { it.isNotBlank() }
        } else {
            err = "HATA: LP şablonlarının tamamı alınamadı. Yenileyip tekrar deneyin."
            emptyList()
        }
    }
    var templateExpanded by remember { mutableStateOf(false) }

    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Yeni LP Oluştur", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(12.dp))
        ExposedDropdownMenuBox(expanded = templateExpanded, onExpandedChange = { templateExpanded = !templateExpanded }) {
            OutlinedTextField(
                value = template,
                onValueChange = { template = it },
                readOnly = templates.isNotEmpty(),
                label = { Text("Şablon Kodu") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = templateExpanded) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().menuAnchor(),
            )
            if (templates.isNotEmpty()) {
                ExposedDropdownMenu(expanded = templateExpanded, onDismissRequest = { templateExpanded = false }) {
                    templates.forEach { code ->
                        DropdownMenuItem(text = { Text(code) }, onClick = { template = code; templateExpanded = false })
                    }
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        ScanField("Lokasyon", location, { location = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        ScanField("Bin", bin, { bin = it }, modifier = Modifier.fillMaxWidth())
        if (err.isNotBlank()) { Spacer(Modifier.height(8.dp)); StatusText(err) }
        Spacer(Modifier.height(16.dp))
        Button(
            enabled = !busy && template.isNotBlank() && location.isNotBlank() && bin.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(50.dp),
            onClick = {
                scope.launch {
                    busy = true; err = ""
                    val safeTemplate = template.trim().replace("'", "''")
                    val safeLocation = location.trim().replace("'", "''")
                    val safeBin = bin.trim().replace("'", "''")
                    val templateExists = BcApi.get(context, "licensePlateTemplates?\$filter=code eq '$safeTemplate'&\$top=1")
                    val binExists = BcApi.get(context, "bins?\$filter=locationCode eq '$safeLocation' and code eq '$safeBin'&\$top=1")
                    if (!templateExists.ok || BcApi.parseValueArray(templateExists.body).isEmpty()) {
                        busy = false; err = "HATA: Geçerli bir LP şablonu seçin."
                        return@launch
                    }
                    if (!binExists.ok || BcApi.parseValueArray(binExists.body).isEmpty()) {
                        busy = false; err = "HATA: Lokasyon ve raf eşleşmiyor. Değerleri kontrol edin."
                        return@launch
                    }
                    val body = JSONObject().apply {
                        put("locationCode", location.trim())
                        put("binCode", bin.trim())
                    }.toString()
                    val r = BcApi.boundAction(
                        context,
                        "licensePlateTemplates",
                        template.trim(),
                        "build",
                        body,
                    )
                    busy = false
                    if (r.ok) {
                        val no = BcApi.scalarValue(r.body).trim()
                        if (no.isNotBlank()) onBuilt(no)
                        else err = "HATA: Business Central LP numarası döndürmedi."
                    } else {
                        val serverError = BcApi.errorMessage(r.body)
                        err = if (serverError.contains("LP No. Series", ignoreCase = true))
                            "HATA: LP numara serisi tanımlı değil. Advanced WMS kurulumunu tamamlayın."
                        else if (r.httpCode == 404 || r.httpCode == 405)
                            "HATA: LP Build servisi henüz Business Central'a yayımlanmamış. Güncel AL uzantısını yayımlayın."
                        else QcErrorParser.friendlyStatus(serverError, r.httpCode)
                    }
                }
            }
        ) { Text(if (busy) "Oluşturuluyor..." else "Oluştur") }
        Spacer(Modifier.height(24.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LpDocument(lpNo: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var linesComplete by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }

    // dialogs — LP aç → kaynak bin + ürün/lot seç → adet → kaydet.
    var showAddLine by remember { mutableStateOf(false) }
    var showQty by remember { mutableStateOf(false) }
    var scannedItem by remember { mutableStateOf("") }
    var selectedLineItem by remember { mutableStateOf<LpItemSelection?>(null) }
    var showTransfer by remember { mutableStateOf(false) }
    var showPartial by remember { mutableStateOf(false) }
    var showUnbuildConfirm by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    fun reload() {
        scope.launch {
            busy = true
            header = null
            lines = emptyList()
            linesComplete = false
            val safeLpNo = lpNo.replace("'", "''")
            val h = BcApi.get(context, "licensePlates('$safeLpNo')")
            header = if (h.ok) runCatching { JSONObject(h.body) }.getOrNull() else null
            if (header == null) {
                status = "HATA: LP bilgisi alınamadı. Yenileyip tekrar deneyin."
                busy = false
                return@launch
            }
            val page = BcApi.getAllPages(
                context,
                "licensePlateLines?\$filter=lpNo eq '$safeLpNo'&\$orderby=lineNo",
            )
            lines = page.rows
            linesComplete = page.complete
            if (!page.complete) status = "HATA: LP satırlarının tamamı alınamadı. Yenileyip tekrar deneyin."
            else if (status.startsWith("HATA:")) status = ""
            busy = false
        }
    }
    LaunchedEffect(lpNo) { reload() }

    fun action(name: String, body: String = "{}", okMsg: String, requiresCompleteLines: Boolean = true) {
        if (header == null) {
            status = "HATA: LP bilgisi yüklenmeden işlem yapılamaz. Yenileyin."
            return
        }
        if (requiresCompleteLines && !linesComplete) {
            status = "HATA: LP satırlarının tamamı yüklenmeden işlem yapılamaz. Yenileyin."
            return
        }
        scope.launch {
            busy = true; status = "İşlem yapılıyor..."
            val r = BcApi.boundAction(context, "licensePlates", lpNo, name, body)
            busy = false
            status = if (r.ok) "TAMAM: $okMsg" else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
            if (r.ok) reload()
        }
    }

    val h = header
    val headerLoaded = h != null
    val st = h?.optString("status") ?: ""
    val canEdit = headerLoaded && linesComplete && canEditLicensePlate(st)
    val canTransfer = headerLoaded && linesComplete && canTransferLicensePlate(st, lines.size)
    val canPartiallyUse = headerLoaded && linesComplete && canPartiallyUseLicensePlate(st, lines.size)
    val canDelete = headerLoaded && linesComplete && canDeleteLicensePlate(st, lines.size)
    val canUnbuild = headerLoaded && linesComplete &&
        (st.equals("Open", ignoreCase = true) || st.equals("Built", ignoreCase = true)) && !canDelete

    fun addLineFromSourceBin(res: com.dynops.bcwms.ui.QuantityResult, scannedBin: String) {
        scope.launch {
            busy = true
            val userId = BcApi.currentUserId(context).trim()
            if (userId.isBlank()) {
                busy = false
                status = "HATA: Kullanıcı kimliği doğrulanamadı. Yeniden giriş yapın."
                return@launch
            }
            val targetLocation = h?.optString("locationCode").orEmpty()
            val sourceBin = scannedBin.trim()
            status = "$sourceBin kaynak rafı ve LP lokasyonu doğrulanıyor..."
            fun safe(value: String) = value.replace("'", "''")
            val binPage = BcApi.getAllPages(
                context,
                "bins?\$filter=code eq '${safe(sourceBin)}'&\$select=locationCode,code&\$top=50",
            )
            if (!binPage.complete) {
                busy = false
                status = "HATA ÖNLENDİ: Kaynak rafın tüm lokasyon bilgisi doğrulanamadı. LP satırı gönderilmedi; yenileyip tekrar deneyin."
                return@launch
            }
            val sourceLocations = binPage.rows
                .map { it.optString("locationCode") }
                .filter { it.isNotBlank() }
                .distinct()
            if (!sourceBinLookupAllowsMove(binPage.complete, targetLocation, sourceLocations)) {
                busy = false
                val actualLocations = sourceLocations.joinToString().ifBlank { "bulunamadı" }
                status = "HATA ÖNLENDİ: $sourceBin kaynak rafı $actualLocations lokasyonunda; " +
                    "LP $targetLocation lokasyonunda. Lokasyonlar arası LP satırı eklenemez ve stok taşınmadı."
                return@launch
            }
            status = "Satır ekleniyor..."
            val body = JSONObject().apply {
                put("itemNo", scannedItem)
                put("unitOfMeasure", res.uom)
                put("quantity", res.quantity)
                put("lotNo", res.lotNo)
                put("serialNo", res.serialNo)
                put("sourceBinCode", sourceBin)
                put("userId", userId)
            }.toString()
            val r = BcApi.boundAction(context, "licensePlates", lpNo, "addLineFromBin", body)
            busy = false
            val targetBin = h?.optString("binCode").orEmpty()
            status = if (r.ok)
                "TAMAM: ${scannedItem} × ${res.quantity} LP'ye eklendi; BC stoğu $targetLocation/$sourceBin → $targetLocation/$targetBin taşındı"
            else
                "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})" +
                    if (r.httpCode == 404 || r.httpCode == 405)
                        " — güncel BC uzantısını yayımlayın" else ""
            if (r.ok) reload()
        }
    }

    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(12.dp)) {
            TextButton(onClick = onBack) { Text("‹ LP Listesi") }
            val isTote = h?.optBoolean("reusable") == true
            DocHeaderCard(
                title = lpNo,
                subtitle = "${h?.optString("templateCode") ?: ""}${if (isTote) " · ♻ Tote" else ""} · ${h?.optString("locationCode") ?: ""}/${h?.optString("binCode") ?: ""}" +
                    (h?.optString("sscc")?.takeIf { it.isNotBlank() }?.let { "\nSSCC: $it" } ?: ""),
                badge = lpStatusLabel(st)
            )
            Spacer(Modifier.height(6.dp))
            StatusText(status)
            // Tote (yeniden kullanılabilir LP): iş bitince Release → tekrar Built.
            if (st.equals("Assigned", ignoreCase = true)) {
                Spacer(Modifier.height(6.dp))
                Button(
                    onClick = { action("release", "{}", "LP serbest bırakıldı — yeniden kullanılabilir") },
                    enabled = !busy, modifier = Modifier.fillMaxWidth().height(48.dp),
                ) { WmsActionLabel(WmsGlyph.LICENSE_PLATE, if (isTote) "Tote'u Serbest Bırak" else "Serbest Bırak") }
            }
            Spacer(Modifier.height(6.dp))
            Text("Satırlar (${lines.size})", fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Spacer(Modifier.height(8.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                lines.forEach { ln ->
                    Card(
                        Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Row(Modifier.padding(13.dp), verticalAlignment = Alignment.CenterVertically) {
                            WmsIconBadge(WmsGlyph.LICENSE_PLATE, MaterialTheme.colorScheme.primary, size = 40.dp, iconSize = 22.dp)
                            Spacer(Modifier.width(11.dp))
                            Column(Modifier.weight(1f)) {
                                Text(ln.optString("itemNo"), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                                Text(
                                    "${ln.optDouble("quantity")} ${ln.optString("unitOfMeasure")}".trim(),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Bold,
                                )
                            val extra = listOfNotNull(
                                ln.optString("sourceBinCode").takeIf { it.isNotBlank() && it != "null" }?.let { "Kaynak raf: $it" },
                                ln.optString("lotNo").takeIf { it.isNotBlank() }?.let { "Lot $it" },
                                ln.optString("serialNo").takeIf { it.isNotBlank() }?.let { "Seri $it" },
                            ).joinToString(" · ")
                                if (extra.isNotBlank()) Text(extra, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                if (lines.isEmpty() && !busy) EmptyState("Henüz satır yok. Satır Ekle düğmesiyle ürün ekleyin.")
            }
        }

        Surface(
            tonalElevation = 2.dp,
            shadowElevation = 10.dp,
            color = MaterialTheme.colorScheme.surface,
        ) {
            Column(
                Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Açık LP'de önce ürün eklenir, iş bitince tek ve belirgin ana
                // eylemle tamamlanır. Geçersiz eylemler dar gri düğme olarak
                // gösterilmez; yalnız kullanılabilen seçenekler görünür.
                if (canEdit) {
                    OutlinedButton(
                        onClick = { showAddLine = true },
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = RoundedCornerShape(14.dp),
                    ) { WmsActionLabel(WmsGlyph.LICENSE_PLATE, "Satır Ekle") }
                    Button(
                        onClick = {
                            val payload = JSONObject().apply {
                                put("printLabel", true)
                                put("printerId", getDefaultPrinter(context))
                            }.toString()
                            action("stopToPrinter", payload, "LP tamamlandı")
                        },
                        enabled = !busy && lines.isNotEmpty(),
                        modifier = Modifier.fillMaxWidth().height(56.dp),
                        shape = RoundedCornerShape(14.dp),
                    ) { WmsActionLabel(WmsGlyph.QUALITY, "LP'yi Tamamla") }
                }

                if (canTransfer || canPartiallyUse) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (canTransfer) {
                            OutlinedButton(
                                onClick = { showTransfer = true },
                                enabled = !busy,
                                modifier = Modifier.weight(1f).height(52.dp),
                                shape = RoundedCornerShape(14.dp),
                            ) { WmsActionLabel(WmsGlyph.AD_HOC, "Transfer") }
                        }
                        if (canPartiallyUse) {
                            OutlinedButton(
                                onClick = { showPartial = true },
                                enabled = !busy,
                                modifier = Modifier.weight(1f).height(52.dp),
                                shape = RoundedCornerShape(14.dp),
                            ) { WmsActionLabel(WmsGlyph.PACKING, "Kısmi İşlem") }
                        }
                    }
                }

                OutlinedButton(
                    onClick = {
                        val defaultPrinter = getDefaultPrinter(context, PRINTER_USAGE_DOCUMENT)
                        val payload = JSONObject().apply {
                            put("printerId", defaultPrinter)
                            put("copies", 1)
                        }.toString()
                        action(
                            "printDocument",
                            payload,
                            if (defaultPrinter.isBlank()) "LP QR belgesi varsayılan yazıcıya gönderildi" else "LP QR belgesi $defaultPrinter yazıcısına gönderildi",
                            requiresCompleteLines = false,
                        )
                    },
                    enabled = !busy && headerLoaded,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(14.dp),
                ) { WmsActionLabel(WmsGlyph.PRINTER, "QR Etiketini Yazdır") }

                when {
                    canDelete -> OutlinedButton(
                        onClick = { showDeleteConfirm = true },
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    ) { WmsActionLabel(WmsGlyph.WARNING, "Boş LP'yi Sil") }
                    canUnbuild -> OutlinedButton(
                        onClick = { showUnbuildConfirm = true },
                        enabled = !busy,
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                        shape = RoundedCornerShape(14.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    ) { WmsActionLabel(WmsGlyph.WARNING, "LP'yi Boz") }
                }
            }
        }
    }

    if (showUnbuildConfirm) {
        AlertDialog(
            onDismissRequest = { if (!busy) showUnbuildConfirm = false },
            title = { Text("LP bozulsun mu?") },
            text = {
                Text(
                    "$lpNo içindeki ${lines.size} LP satırı silinecek ve LP 'Bozuldu' durumuna alınacak. " +
                        "Fiziksel BC stoğu ${h?.optString("locationCode").orEmpty()}/${h?.optString("binCode").orEmpty()} " +
                        "depo gözünde serbest stok olarak kalır. Sonrasında boş LP'yi silebilirsiniz."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showUnbuildConfirm = false
                    action("unbuild", "{}", "LP bozuldu; içerik depo gözünde serbest stok olarak kaldı")
                }, enabled = !busy) { Text("Boz") }
            },
            dismissButton = {
                TextButton(onClick = { showUnbuildConfirm = false }, enabled = !busy) { Text("Vazgeç") }
            },
        )
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { if (!busy) showDeleteConfirm = false },
            title = { Text("Boş LP silinsin mi?") },
            text = { Text("$lpNo kalıcı olarak silinecek. Bu işlem yalnız Açık/Bozuldu durumda ve satırı olmayan LP için yapılabilir.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch {
                            busy = true
                            status = "$lpNo siliniyor..."
                            val safeLpNo = lpNo.replace("'", "''")
                            val result = BcApi.delete(context, "licensePlates('$safeLpNo')")
                            busy = false
                            if (result.ok) {
                                showDeleteConfirm = false
                                onBack()
                            } else {
                                status = "HATA: ${BcApi.errorMessage(result.body)} (HTTP ${result.httpCode})"
                            }
                        }
                    },
                    enabled = !busy,
                ) { Text("Kalıcı Sil", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }, enabled = !busy) { Text("Vazgeç") }
            },
        )
    }

    // Add line: scan item -> qty dialog
    if (showAddLine) {
        AddLineScanSheet(
            locationCode = h?.optString("locationCode").orEmpty(),
            onDismiss = { showAddLine = false },
            onItem = { selection ->
                selectedLineItem = selection
                scannedItem = selection.itemNo
                showAddLine = false
                showQty = true
            }
        )
    }
    if (showQty) {
        val selection = selectedLineItem
        QuantityDialogSheet(
            title = "Satır Ekle",
            itemNo = scannedItem,
            initialUom = selection?.initialUom.orEmpty(),
            initialLot = selection?.initialLotNo.orEmpty(),
            uomOptions = selection?.uomOptions.orEmpty(),
            uomRequired = true,
            uomSelectionOnly = true,
            showLotSerial = selection?.let { it.lotRequired || it.serialRequired } == true,
            showSerial = selection?.serialRequired == true,
            quantityExactlyOne = selection?.serialRequired == true,
            lotRequired = selection?.lotRequired == true,
            lotSelectionOnly = (selection?.availableLotCount ?: 0) > 0,
            showAvailableLotLookup = (selection?.availableLotCount ?: 0) > 0,
            autoDetectLotFromStock = true,
            locationCode = h?.optString("locationCode").orEmpty(),
            binCode = selection?.sourceBinCode.orEmpty(),
            onDismiss = { showQty = false },
            onConfirm = { res ->
                val sourceBin = selection?.sourceBinCode.orEmpty()
                if (sourceBin.isBlank()) {
                    showQty = false
                    status = "HATA: Kaynak bin kodu seçilmeden LP satırı eklenemez."
                } else if (!validLpTrackingQuantity(selection?.serialRequired == true, res.quantity)) {
                    status = "HATA: Seri takipli üründe her seri numarası için miktar 1 olmalıdır."
                } else {
                    showQty = false
                    addLineFromSourceBin(res, sourceBin)
                }
            }
        )
    }
    if (showTransfer) {
        TransferSheet(onDismiss = { showTransfer = false }, onConfirm = { target ->
            showTransfer = false
            // Tüm satırları açıkça gönder — eski publish'te boş linesJson hiçbir
            // satır taşımadan başarı dönüyordu (LPApi.ParseLines boş çıkışı).
            val linesJson = org.json.JSONArray().apply {
                lines.forEach { ln -> put(JSONObject().apply { put("lineNo", ln.optInt("lineNo")) }) }
            }.toString()
            action("transfer", JSONObject().apply { put("targetLpNo", target); put("linesJson", linesJson) }.toString(), "Transfer tamamlandı (${lines.size} satır)")
        })
    }
    if (showPartial) {
        PartialUseSheet(lines = lines, onDismiss = { showPartial = false }, onConfirm = { mode, qty, lineNo ->
            showPartial = false
            val label = lpPartialActions.firstOrNull { it.apiValue == mode }?.label ?: "Kısmi kullanım"
            action("usePartial", JSONObject().apply { put("action", mode); put("qty", qty); put("lineNo", lineNo) }.toString(), "$label tamamlandı")
        })
    }
}

private data class LpItemSelection(
    val itemNo: String,
    val description: String,
    val sourceBinCode: String,
    val initialUom: String,
    val uomOptions: List<String>,
    val initialLotNo: String,
    val lotRequired: Boolean,
    val serialRequired: Boolean,
    val availableLotCount: Int,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddLineScanSheet(
    locationCode: String,
    onDismiss: () -> Unit,
    onItem: (LpItemSelection) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var sourceBinCode by remember { mutableStateOf("") }
    var itemOrLot by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var candidates by remember { mutableStateOf<List<LpItemSelection>>(emptyList()) }

    fun select(candidate: LpItemSelection) = onItem(candidate)

    fun resolve() {
        if (itemOrLot.isBlank() || busy) return
        scope.launch {
            busy = true
            error = ""
            candidates = emptyList()
            resolveLpItemOrLot(context, itemOrLot.trim(), locationCode, sourceBinCode.trim())
                .onSuccess { matches ->
                    when (matches.size) {
                        0 -> error = "Ürün veya pozitif stoklu lot bulunamadı: ${itemOrLot.trim()}"
                        1 -> select(matches.first())
                        else -> candidates = matches
                    }
                }
                .onFailure { error = it.message.orEmpty() }
            busy = false
        }
    }

    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Ürün veya Lot Ara / Tara", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("Önce ürünün alınacağı kaynak bini, sonra ürün veya lotu girin.", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(12.dp))
        ScanField("Kaynak Bin Kodu", sourceBinCode, {
            sourceBinCode = it
            error = ""
            candidates = emptyList()
        }, modifier = Modifier.fillMaxWidth(), onScanned = { raw ->
            sourceBinCode = BarcodeIntentResolver.resolve(raw).value.trim()
        })
        Spacer(Modifier.height(10.dp))
        ScanField("Ürün No. / Ürün Adı / Lot No.", itemOrLot, {
            itemOrLot = it
            error = ""
            candidates = emptyList()
        }, modifier = Modifier.fillMaxWidth(), onScanned = { raw ->
            itemOrLot = raw.trim()
        })
        Spacer(Modifier.height(16.dp))
        Button(
            enabled = sourceBinCode.isNotBlank() && itemOrLot.isNotBlank() && !busy,
            modifier = Modifier.fillMaxWidth(),
            onClick = { resolve() },
        ) { Text(if (busy) "Aranıyor..." else "Bul → Miktar") }
        if (error.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            StatusText(error)
        }
        candidates.forEach { candidate ->
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = { select(candidate) }, modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.fillMaxWidth()) {
                    Text(candidate.itemNo, fontWeight = FontWeight.Bold)
                    if (candidate.description.isNotBlank()) Text(candidate.description, fontSize = 12.sp)
                    Text(
                        "Kaynak: ${candidate.sourceBinCode} · Lot: ${candidate.initialLotNo} · UOM: ${candidate.initialUom}",
                        fontSize = 11.sp,
                        color = Color.Gray,
                    )
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

private suspend fun resolveLpItemOrLot(
    context: android.content.Context,
    rawInput: String,
    locationCode: String,
    sourceBinCode: String,
): Result<List<LpItemSelection>> = runCatching {
    fun safe(value: String) = value.replace("'", "''")
    val resolvedBarcode = BarcodeIntentResolver.resolve(rawInput)
    val explicitItemNo = resolvedBarcode.itemNo?.trim().orEmpty()
    val explicitLotNo = resolvedBarcode.lotNo?.trim().orEmpty()
    val itemProbe = explicitItemNo.ifBlank { rawInput.trim() }
    val itemSelect = "no,description,baseUnitOfMeasure,lotTrackingRequired,serialTrackingRequired"

    if (sourceBinCode.isBlank())
        throw IllegalStateException("Kaynak bin kodunu girin veya okutun.")
    val sourceBinFilters = buildList {
        add("code eq '${safe(sourceBinCode)}'")
        if (locationCode.isNotBlank()) add("locationCode eq '${safe(locationCode)}'")
    }.joinToString(" and ")
    val sourceBinPage = BcApi.getAllPages(
        context,
        "bins?\$filter=$sourceBinFilters&\$select=locationCode,code&\$top=2",
    )
    if (!sourceBinPage.complete)
        throw IllegalStateException("Kaynak bin doğrulanamadı. Bağlantıyı kontrol edip yeniden deneyin.")
    if (sourceBinPage.rows.none { it.optString("code").equals(sourceBinCode, ignoreCase = true) })
        throw IllegalStateException("$sourceBinCode kaynak bini $locationCode lokasyonunda bulunamadı.")

    suspend fun itemRows(itemNo: String): List<JSONObject> {
        val result = BcApi.get(
            context,
            "items?\$filter=no eq '${safe(itemNo)}'&\$select=$itemSelect&\$top=2",
        )
        if (!result.ok) {
            if (result.httpCode == 400 || result.httpCode == 404)
                throw IllegalStateException("Ürün veya lot bilgisi alınamadı. Depo sorumlusuna bildirin.")
            throw IllegalStateException("Ürün doğrulanamadı. Bağlantıyı kontrol edip yeniden deneyin.")
        }
        return BcApi.parseValueArray(result.body)
    }

    suspend fun itemRowsByDescription(description: String): List<JSONObject> {
        val page = BcApi.getAllPages(
            context,
            "items?\$filter=contains(description,'${safe(description)}')&\$select=$itemSelect&\$orderby=no&\$top=10",
        )
        if (!page.complete)
            throw IllegalStateException("Ürün adıyla arama tamamlanamadı. Bağlantıyı kontrol edip yeniden deneyin.")
        return page.rows
    }

    suspend fun allLots(itemNo: String): List<JSONObject> =
        com.dynops.bcwms.ui.fetchAvailableLots(context, itemNo, locationCode, sourceBinCode, "")
            .getOrElse { throw it }

    suspend fun uoms(itemNo: String): List<String> {
        val page = BcApi.getAllPages(
            context,
            "itemUnitOfMeasures?\$filter=itemNo eq '${safe(itemNo)}'&\$select=code&\$orderby=code&\$top=100",
        )
        if (!page.complete) {
            throw IllegalStateException("Ölçü birimleri alınamadı. Bağlantıyı kontrol edip yeniden deneyin.")
        }
        return page.rows.map { it.optString("code") }
    }

    suspend fun selection(item: JSONObject, scannedLot: String, lotUom: String = ""): LpItemSelection {
        val itemNo = item.optString("no")
        val availableLots = allLots(itemNo)
        val baseUom = item.optString("baseUnitOfMeasure")
        val serialRequired = item.optBoolean("serialTrackingRequired")
        // A serial identifies exactly one base unit.  Do not offer a case/pallet
        // UOM here because the server correctly rejects a converted base qty > 1.
        val uomOptions = if (serialRequired) listOf(baseUom).filter(String::isNotBlank) else
            lpUomOptions(
                baseUom,
                uoms(itemNo),
                availableLots.map { it.optString("unitOfMeasureCode") },
            )
        val initialUom = lotUom.takeIf(String::isNotBlank)
            ?: uomOptions.firstOrNull().orEmpty()
        val lotRequired = lpLotIsRequired(
            item.optBoolean("lotTrackingRequired"),
            availableLots.size,
            scannedLot,
        )
        return LpItemSelection(
            itemNo = itemNo,
            description = item.optString("description"),
            sourceBinCode = sourceBinCode,
            initialUom = initialUom,
            uomOptions = uomOptions,
            initialLotNo = scannedLot,
            lotRequired = lotRequired,
            serialRequired = serialRequired,
            availableLotCount = availableLots.size,
        )
    }

    val exactItems = itemRows(itemProbe)
    if (exactItems.isNotEmpty()) {
        return@runCatching listOf(selection(exactItems.first(), explicitLotNo))
    }

    val lotProbe = explicitLotNo.ifBlank { rawInput.trim() }
    val lotFilters = buildList {
        add("lotNo eq '${safe(lotProbe)}'")
        if (locationCode.isNotBlank()) add("locationCode eq '${safe(locationCode)}'")
        if (sourceBinCode.isNotBlank()) add("binCode eq '${safe(sourceBinCode)}'")
    }.joinToString(" and ")
    val lotPage = BcApi.getAllPages(
        context,
        "availableLots?\$filter=$lotFilters&\$select=itemNo,lotNo,unitOfMeasureCode,quantityBase&\$top=200",
    )
    if (!lotPage.complete) throw IllegalStateException("Lot doğrulanamadı. Bağlantıyı kontrol edip yeniden deneyin.")
    val lotRows = lotPage.rows
        .filter { it.optString("lotNo").equals(lotProbe, ignoreCase = true) && it.optDouble("quantityBase", 0.0) > 0.0 }
        .distinctBy { it.optString("itemNo").uppercase() }

    val matchesByLot = buildList {
        for (lotRow in lotRows) {
            val rows = itemRows(lotRow.optString("itemNo"))
            if (rows.isNotEmpty()) add(selection(rows.first(), lotProbe, lotRow.optString("unitOfMeasureCode")))
        }
    }
    if (matchesByLot.isNotEmpty()) return@runCatching matchesByLot

    // Son seçenek serbest metin ürün adı aramasıdır. Her eşleşme, lot/UOM
    // kurallarıyla birlikte hazırlanır; operatör sonuç listesinden doğru ürünü seçer.
    buildList {
        for (item in itemRowsByDescription(rawInput.trim()))
            add(selection(item, ""))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TransferSheet(onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
    var target by remember { mutableStateOf("") }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("LP Transferi", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("İçeriği tamamlanmış bir hedef LP'ye taşıyın.", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(12.dp))
        ScanField("Hedef LP No", target, { target = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(16.dp))
        Button(
            enabled = target.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
            onClick = { onConfirm(target.trim()) },
        ) { Text("Transfer Et") }
        Spacer(Modifier.height(24.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PartialUseSheet(
    lines: List<JSONObject>,
    onDismiss: () -> Unit,
    onConfirm: (mode: String, qty: Double, lineNo: Int) -> Unit,
) {
    var selectedAction by remember { mutableStateOf(lpPartialActions.first()) }
    var qty by remember { mutableStateOf("1") }
    var selectedLineNo by remember(lines) { mutableStateOf(lines.firstOrNull()?.optInt("lineNo") ?: 0) }
    var actionExpanded by remember { mutableStateOf(false) }
    var lineExpanded by remember { mutableStateOf(false) }
    val selectedLine = lines.firstOrNull { it.optInt("lineNo") == selectedLineNo }
    val maximumQuantity = selectedLine?.optDouble("quantity") ?: 0.0
    val parsedQuantity = qty.toDoubleOrNull()
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Kısmi Kullanım", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(8.dp))
        ExposedDropdownMenuBox(expanded = actionExpanded, onExpandedChange = { actionExpanded = !actionExpanded }) {
            OutlinedTextField(
                value = selectedAction.label,
                onValueChange = {},
                readOnly = true,
                label = { Text("İşlem") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(actionExpanded) },
                modifier = Modifier.fillMaxWidth().menuAnchor(),
            )
            ExposedDropdownMenu(expanded = actionExpanded, onDismissRequest = { actionExpanded = false }) {
                lpPartialActions.forEach { action ->
                    DropdownMenuItem(
                        text = { Text(action.label) },
                        onClick = { selectedAction = action; actionExpanded = false },
                    )
                }
            }
        }
        Text(selectedAction.help, fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(8.dp))
        ExposedDropdownMenuBox(expanded = lineExpanded, onExpandedChange = { lineExpanded = !lineExpanded }) {
            OutlinedTextField(
                value = selectedLine?.let {
                    "${it.optString("itemNo")} · ${it.optString("lotNo").ifBlank { "Lotsuz" }} · ${it.optDouble("quantity")}"
                }.orEmpty(),
                onValueChange = {},
                readOnly = true,
                label = { Text("LP satırı") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(lineExpanded) },
                modifier = Modifier.fillMaxWidth().menuAnchor(),
            )
            ExposedDropdownMenu(expanded = lineExpanded, onDismissRequest = { lineExpanded = false }) {
                lines.forEach { line ->
                    DropdownMenuItem(
                        text = {
                            Text("${line.optString("itemNo")} · ${line.optString("lotNo").ifBlank { "Lotsuz" }} · ${line.optDouble("quantity")}")
                        },
                        onClick = {
                            selectedLineNo = line.optInt("lineNo")
                            qty = "1"
                            lineExpanded = false
                        },
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            qty,
            { qty = it.filter { c -> c.isDigit() || c == '.' || c == ',' }.replace(',', '.') },
            label = { Text("Miktar (en fazla $maximumQuantity)") },
            singleLine = true,
            isError = qty.isNotBlank() && !validPartialUseInput(parsedQuantity, selectedLineNo, maximumQuantity),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
        Button(
            enabled = validPartialUseInput(parsedQuantity, selectedLineNo, maximumQuantity),
            modifier = Modifier.fillMaxWidth(),
            onClick = { onConfirm(selectedAction.apiValue, parsedQuantity ?: return@Button, selectedLineNo) },
        ) { Text("Uygula") }
        Spacer(Modifier.height(24.dp))
    }
}
