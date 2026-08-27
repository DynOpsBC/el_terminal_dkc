package com.dynops.bcwms.feature

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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

/** Item Inquiry — item card + LP lines that contain the item (on-hand by LP). */
@Composable
fun ItemInquiryModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // PDF Item Inquiry §1: hardcoded "1004" preset removed — start empty so
    // the screen does not falsely claim an item exists before the operator
    // scans/types one.
    var query by remember { mutableStateOf("") }
    var item by remember { mutableStateOf<JSONObject?>(null) }
    var lpLines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var ledger by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("Ürün No. tarayın/girin.") }
    var loading by remember { mutableStateOf(false) }

    fun load() {
        if (query.trim().isBlank()) return
        scope.launch {
            loading = true; status = "Sorgulanıyor..."
            item = null; lpLines = emptyList(); ledger = emptyList()
            val q = query.trim()
            val r = BcApi.getWithStandardFallback(context, "items?\$filter=no eq '$q'&\$top=1", "items?\$filter=number eq '$q'&\$top=1")
            if (r.ok) {
                val list = BcApi.parseValueArray(r.body)
                item = list.firstOrNull()
            }
            // on-hand by LP: lines for this item across license plates
            val lpPage = BcApi.getAllPages(context, "licensePlateLines?\$filter=itemNo eq '$q'&\$top=50")
            if (lpPage.complete) lpLines = lpPage.rows
            // Son Hareketler (Item Ledger) — WI "Recent Transactions" pariteti.
            val le = BcApi.get(context, "itemLedgerEntries?\$filter=itemNo eq '$q'&\$orderby=postingDate desc,entryNo desc&\$top=20")
            if (le.ok) ledger = BcApi.parseValueArray(le.body)
            loading = false
            status = when {
                !lpPage.complete -> "HATA: Ürünün LP kayıtlarının tamamı alınamadı. Yenileyin."
                item == null -> "BOŞ: '$q' için ürün bulunamadı."
                else -> "TAMAM: ürün bulundu · ${lpLines.size} LP · ${ledger.size} hareket."
            }
        }
    }

    fun printItemLabel() {
        val no = item?.let { rawValue(it, "no", "number") }?.takeIf { it.isNotBlank() } ?: return
        scope.launch {
            status = "🖨 Etiket yazdırılıyor..."
            val payload = JSONObject().apply {
                put("printerId", getDefaultPrinter(context))
                put("copies", 1)
            }.toString()
            val r = BcApi.boundAction(context, "items", no, "printLabel", payload)
            status = if (r.ok) "🟢 Ürün etiketi kuyruğa alındı ($no)." else "🔴 Yazdırma: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
        }
    }

    val palette = bcwmsStatus()
    Column(Modifier.fillMaxSize().padding(12.dp)) {
        ScanField("Ürün No", query, { query = it }, modifier = Modifier.fillMaxWidth(), onScanned = {
            query = BarcodeIntentResolver.resolve(it).itemNo ?: it
        })
        Spacer(Modifier.height(8.dp))
        Button(onClick = { load() }, enabled = !loading, modifier = Modifier.fillMaxWidth()) {
            Text(if (loading) "..." else "🔎 Sorgula", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        item?.let { it ->
            val blocked = it.optBoolean("blocked", false)
            val inventory = it.optDouble("inventory", Double.NaN)
            val qtyOnPo = it.optDouble("quantityOnPurchOrder", 0.0)
            val qtyOnSo = it.optDouble("quantityOnSalesOrder", 0.0)
            val qtyOnProd = it.optDouble("quantityOnProdOrder", 0.0)
            val reserved = it.optDouble("reservedQtyOnInventory", 0.0)
            val uom = firstValue(it, "baseUnitOfMeasure", "baseUoM")
            val available = (if (inventory.isNaN()) 0.0 else inventory) - reserved
            val totalOnLp = lpLines.sumOf { l -> l.optDouble("quantity") }
            Card(
                Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (blocked) palette.danger.copy(alpha = 0.10f)
                    else MaterialTheme.colorScheme.primary.copy(alpha = 0.07f),
                ),
            ) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(firstValue(it, "no", "number"), fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.onSurface)
                        if (blocked) {
                            Spacer(Modifier.width(8.dp))
                            InfoPill("🚫 Bloke", containerColor = palette.danger, contentColor = Color.White)
                        }
                    }
                    Text(firstValue(it, "description", "displayName"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
                    Spacer(Modifier.height(10.dp))
                    // Stock block — PDF Item Inquiry §1 critical fix.
                    if (!inventory.isNaN()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            StockTile("Stok", inventory, uom, palette.success, Modifier.weight(1f))
                            StockTile("Müsait", available, uom, MaterialTheme.colorScheme.primary, Modifier.weight(1f))
                            StockTile("Rezerve", reserved, uom, palette.warning, Modifier.weight(1f))
                        }
                        Spacer(Modifier.height(8.dp))
                        Text("Gelen ${fmtItemQty(qtyOnPo)} · Giden ${fmtItemQty(qtyOnSo)} · Üretim ${fmtItemQty(qtyOnProd)}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Spacer(Modifier.height(8.dp))
                    Text("Temel UOM: $uom", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Kategori: ${firstValue(it, "itemCategoryCode")} · LP Şablonu: ${firstValue(it, "defaultLpTemplateCode")}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("LP'lerdeki toplam: ${fmtItemQty(totalOnLp)} $uom", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = { printItemLabel() }, modifier = Modifier.fillMaxWidth().height(48.dp)) {
                WmsActionLabel(WmsGlyph.PRINTER, "Ürün Etiketi Bas")
            }
            Spacer(Modifier.height(12.dp))
            Text("LP'lerde (${lpLines.size})", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(6.dp))
        }
        // weight(1f): üstteki sabit ürün kartı listeyi sıfır yüksekliğe
        // sıkıştırıp LP/hareket satırlarını kesiyordu (yatay mod / küçük ekran).
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(lpLines) { ln ->
                Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Text("${ln.optString("lpNo")} × ${fmtItemQty(ln.optDouble("quantity"))}", fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                        val extra = listOfNotNull(
                            ln.optString("lotNo").takeIf { it.isNotBlank() }?.let { "Lot $it" },
                            ln.optString("serialNo").takeIf { it.isNotBlank() }?.let { "Seri $it" }
                        ).joinToString(" · ")
                        if (extra.isNotBlank()) Text(extra, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            if (item != null && lpLines.isEmpty() && !loading) item { EmptyState("Bu ürün hiçbir LP'de bulunmuyor.") }
            if (ledger.isNotEmpty()) {
                item {
                    Text("Son Hareketler (${ledger.size})", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(top = 10.dp, bottom = 4.dp))
                }
                items(ledger) { e ->
                    val qty = e.optDouble("quantity")
                    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("${bcEntryTypeLabelTr(e.optString("entryType"))} · ${e.optString("documentNo")}", fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                                Text("${e.optString("postingDate").take(10)} · ${firstValue(e, "locationCode")}" + e.optString("lotNo").takeIf { it.isNotBlank() }?.let { " · Lot $it" }.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(fmtItemQty(qty), fontWeight = FontWeight.Bold, color = if (qty < 0) bcwmsStatus().danger else bcwmsStatus().success)
                        }
                    }
                }
            }
        }
    }
}

/** Bin Inquiry — bin card + real bin contents (item × qty) + LPs in the bin. */
@Composable
fun BinInquiryModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // PDF Bin Inquiry §2: hardcoded SILVER/S-1-01 preset removed.
    var location by remember { mutableStateOf("") }
    var binCode by remember { mutableStateOf("") }
    var bin by remember { mutableStateOf<JSONObject?>(null) }
    var contents by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var lps by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var whseEntries by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("Lokasyon + Bin girin.") }
    var loading by remember { mutableStateOf(false) }

    fun load() {
        if (location.trim().isBlank() || binCode.trim().isBlank()) return
        scope.launch {
            loading = true; status = "Yükleniyor..."
            bin = null; contents = emptyList(); lps = emptyList(); whseEntries = emptyList()
            val loc = location.trim(); val code = binCode.trim()
            val b = BcApi.get(context, "bins?\$filter=locationCode eq '$loc' and code eq '$code'&\$top=1")
            if (b.ok) bin = BcApi.parseValueArray(b.body).firstOrNull()
            // PDF Bin Inquiry §2 critical fix: now also fetch the real item
            // quantities from the new BinContent API page (T7302 Bin Content).
            val contentsPage = BcApi.getAllPages(context, "binContents?\$filter=locationCode eq '$loc' and binCode eq '$code'&\$top=100")
            if (contentsPage.complete) contents = contentsPage.rows.filter { it.optDouble("quantity", 0.0) != 0.0 }
            val lpPage = BcApi.getAllPages(context, "licensePlates?\$filter=locationCode eq '$loc' and binCode eq '$code'&\$top=50")
            if (lpPage.complete) lps = lpPage.rows.filter { activeLicensePlateStatus(it.optString("status")) }
            // Whse Entries (raf hareket geçmişi) — WI pariteti.
            val we = BcApi.get(context, "warehouseEntries?\$filter=locationCode eq '$loc' and binCode eq '$code'&\$orderby=registeringDate desc,entryNo desc&\$top=20")
            if (we.ok) whseEntries = BcApi.parseValueArray(we.body)
            loading = false
            status = if (!contentsPage.complete || !lpPage.complete) "HATA: Raf içeriğinin tamamı alınamadı. Yenileyin."
                else if (bin == null && contents.isEmpty() && lps.isEmpty()) "BOŞ: '$loc/$code' için içerik yok."
                else "TAMAM: ${contents.size} ürün · ${lps.size} LP · ${whseEntries.size} hareket."
        }
    }

    fun printBinLabel() {
        val b = bin ?: return
        val loc = rawValue(b, "locationCode"); val code = rawValue(b, "code")
        if (loc.isBlank() || code.isBlank()) return
        scope.launch {
            status = "🖨 Bin etiketi yazdırılıyor..."
            val key = "locationCode='${loc.replace("'", "''")}',code='${code.replace("'", "''")}'"
            val payload = JSONObject().apply {
                put("printerId", getDefaultPrinter(context))
                put("copies", 1)
            }.toString()
            val r = BcApi.boundAction(context, "bins", key, "printLabel", payload)
            status = if (r.ok) "🟢 Bin etiketi kuyruğa alındı ($loc/$code)." else "🔴 Yazdırma: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
        }
    }

    val palette = bcwmsStatus()
    Column(Modifier.fillMaxSize().padding(12.dp)) {
        ScanField("Lokasyon", location, { location = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        ScanField("Bin", binCode, { binCode = it }, modifier = Modifier.fillMaxWidth(), onScanned = {
            binCode = BarcodeIntentResolver.resolve(it).value
        })
        Spacer(Modifier.height(8.dp))
        Button(onClick = { load() }, enabled = !loading, modifier = Modifier.fillMaxWidth()) {
            Text(if (loading) "..." else "🔎 Sorgula", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        bin?.let { b ->
            val blocked = b.optBoolean("blockMovement", false)
            Card(
                Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (blocked) palette.danger.copy(alpha = 0.10f) else palette.success.copy(alpha = 0.10f),
                ),
            ) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${firstValue(b, "locationCode")} / ${firstValue(b, "code")}", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.onSurface)
                        if (blocked) {
                            Spacer(Modifier.width(8.dp))
                            InfoPill("🚫 Hareket Engelli", containerColor = palette.danger, contentColor = Color.White)
                        }
                    }
                    Text(rawValue(b, "description").ifBlank { "—" }, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
                    Text("Bölge: ${rawValue(b, "zoneCode").ifBlank { "—" }} · Tip: ${rawValue(b, "binTypeCode").ifBlank { "—" }}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = { printBinLabel() }, modifier = Modifier.fillMaxWidth().height(48.dp)) {
                WmsActionLabel(WmsGlyph.PRINTER, "Bin Etiketi Bas")
            }
            Spacer(Modifier.height(8.dp))
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f)) {
            if (contents.isNotEmpty()) {
                item {
                    Text("Bin İçeriği (${contents.size})", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(vertical = 4.dp))
                }
                items(contents) { c ->
                    Card(
                        Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = palette.warning.copy(alpha = 0.10f)),
                    ) {
                        Row(
                            Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(c.optString("itemNo"), fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface)
                                val desc = c.optString("itemDescription")
                                if (desc.isNotBlank()) Text(desc, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                val activeLpNos = c.optString("activeLpNos")
                                if (activeLpNos.isNotBlank()) {
                                    Text(
                                        "LP: $activeLpNos · LP içindeki miktar: ${fmtItemQty(c.optDouble("activeLpQuantity"))}",
                                        style = MaterialTheme.typography.bodySmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                }
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(fmtItemQty(c.optDouble("quantity")), fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MaterialTheme.colorScheme.primary)
                                Text(c.optString("unitOfMeasureCode").ifBlank { "—" }, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                item { Spacer(Modifier.height(8.dp)) }
            }
            item {
                Text("LP'ler (${lps.size})", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(vertical = 4.dp))
            }
            items(lps) { lp ->
                Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Text("${lp.optString("no")} · ${lpStatusLabel(lp.optString("status"))}", fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                        Text("${lp.optString("templateCode")}${lp.optString("sscc").takeIf { it.isNotBlank() }?.let { " · SSCC $it" } ?: ""}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (lp.has("lineCount") || lp.has("totalQuantity")) {
                            Text(
                                "LP içeriği: ${fmtItemQty(lp.optDouble("totalQuantity"))} adet · ${lp.optInt("lineCount")} satır",
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
            }
            if (lps.isEmpty() && !loading) item { EmptyState("Bu bin'de LP yok.") }
            if (whseEntries.isNotEmpty()) {
                item {
                    Text("Ambar Kayıtları (${whseEntries.size})", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.padding(top = 10.dp, bottom = 4.dp))
                }
                items(whseEntries) { e ->
                    val qty = e.optDouble("quantity")
                    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("${e.optString("itemNo")} · ${bcEntryTypeLabelTr(e.optString("entryType"))}", fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                                Text("${e.optString("registeringDate").take(10)}" + e.optString("lotNo").takeIf { it.isNotBlank() }?.let { " · Lot $it" }.orEmpty() + e.optString("lpNo").takeIf { it.isNotBlank() }?.let { " · LP $it" }.orEmpty(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(fmtItemQty(qty), fontWeight = FontWeight.Bold, color = if (qty < 0) bcwmsStatus().danger else bcwmsStatus().success)
                        }
                    }
                }
            }
        }
    }
}

/** Format an item quantity with up to 2 decimals, stripping trailing zeros. */
internal fun fmtItemQty(q: Double): String {
    if (q.isNaN()) return "0"
    return if (q == q.toLong().toDouble()) q.toLong().toString() else "%.2f".format(q).trimEnd('0').trimEnd('.')
}

/** Compact stock tile used by ItemInquiry — label on top, qty bold, uom small. */
@Composable
private fun StockTile(label: String, qty: Double, uom: String, accent: Color, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(horizontal = 10.dp, vertical = 8.dp)) {
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(fmtItemQty(qty), fontWeight = FontWeight.Bold, fontSize = 16.sp, color = accent)
            Text(uom.ifBlank { "—" }, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/**
 * Ambar Hareketleri (Warehouse Entries) — terminalden doğrulama ekranı.
 * Ad-Hoc / register sonrası "taşındı mı?" sorusunun cevabı: bin/ürün/lot
 * filtresiyle son kayıtlar, +/- renkli miktarlarla listelenir.
 */
@Composable
fun WhseEntriesModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var binFilter by remember { mutableStateOf("") }
    var itemFilter by remember { mutableStateOf("") }
    var lotFilter by remember { mutableStateOf("") }
    // Filtre bölümü varsayılan KAPALI: ekran açılır açılmaz liste görünsün.
    var filtersOpen by remember { mutableStateOf(false) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }

    fun load() {
        scope.launch {
            loading = true; status = "Hareketler yükleniyor..."
            fun eq(field: String, v: String): String? =
                v.trim().takeIf { it.isNotBlank() }?.let { "$field eq '${it.replace("'", "''")}'" }
            val filter = buildODataFilter(eq("binCode", binFilter), eq("itemNo", itemFilter), eq("lotNo", lotFilter))
            val r = BcApi.get(context, "warehouseEntries?\$top=50&\$orderby=entryNo desc$filter")
            loading = false
            rows = if (r.ok) BcApi.parseValueArray(r.body) else emptyList()
            status = if (!r.ok) "HATA: Hareketler alınamadı (HTTP ${r.httpCode})" +
                    (if (r.httpCode == 400 || r.httpCode == 404) " — warehouseEntries için BC publish gerekli olabilir" else "")
                else if (rows.isEmpty()) "BOŞ: Filtreye uyan hareket yok"
                else "TAMAM: ${rows.size} kayıt (en yeni üstte)"
        }
    }
    LaunchedEffect(Unit) { load() }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Ambar Hareketleri", fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Spacer(Modifier.weight(1f))
            OutlinedButton(
                onClick = { load() },
                enabled = !loading,
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 14.dp),
            ) { WmsRefreshLabel(loading, compact = true) }
        }
        Spacer(Modifier.height(8.dp))
        // Filtreler: ScanField'ler kendi OK + kamera butonlarını taşıdığı için
        // yan yana iki tanesi ekrana sığmıyordu (etiketler dikey harflere
        // bölünüyordu). Her biri TAM GENİŞLİK, alt alta; hepsi katlanabilir
        // bölümde — filtre kullanılmadığında liste tüm ekranı kullanır.
        val hasFilter = binFilter.isNotBlank() || itemFilter.isNotBlank() || lotFilter.isNotBlank()
        Row(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .clickable { filtersOpen = !filtersOpen }
                .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                if (hasFilter) "Filtreler · açık" else "Filtrele",
                fontSize = 13.sp,
                fontWeight = if (hasFilter) FontWeight.SemiBold else FontWeight.Normal,
                color = if (hasFilter) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (hasFilter) {
                Spacer(Modifier.width(8.dp))
                // Aktif filtreleri özetle — bölüm kapalıyken de görünsün.
                Text(
                    listOfNotNull(
                        binFilter.takeIf { it.isNotBlank() }?.let { "Bin: $it" },
                        itemFilter.takeIf { it.isNotBlank() }?.let { "Ürün: $it" },
                        lotFilter.takeIf { it.isNotBlank() }?.let { "Lot: $it" },
                    ).joinToString(" · "),
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
            } else Spacer(Modifier.weight(1f))
            if (hasFilter) {
                TextButton(onClick = { binFilter = ""; itemFilter = ""; lotFilter = ""; load() }) {
                    Text("Temizle", fontSize = 12.sp)
                }
            }
            Text(if (filtersOpen) "▲" else "▼", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (filtersOpen) {
            Spacer(Modifier.height(6.dp))
            ScanField("Bin", binFilter, { binFilter = it }, modifier = Modifier.fillMaxWidth(),
                onScanned = { binFilter = BarcodeIntentResolver.resolve(it).value; load() })
            Spacer(Modifier.height(6.dp))
            ScanField("Ürün", itemFilter, { itemFilter = it }, modifier = Modifier.fillMaxWidth(),
                onScanned = {
                    val res = BarcodeIntentResolver.resolve(it)
                    itemFilter = (res.itemNo ?: res.value); load()
                })
            Spacer(Modifier.height(6.dp))
            ScanField("Lot", lotFilter, { lotFilter = it }, modifier = Modifier.fillMaxWidth(),
                onScanned = { lotFilter = BarcodeIntentResolver.resolve(it).value; load() })
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = { load(); filtersOpen = false },
                enabled = !loading,
                modifier = Modifier.fillMaxWidth().height(46.dp),
            ) { Text("Ara") }
        }
        Spacer(Modifier.height(6.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(rows) { e ->
                val qty = e.optDouble("quantity", 0.0)
                val positive = qty >= 0
                Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(10.dp)) {
                    Column(Modifier.padding(10.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                "${e.optString("itemNo")} · ${firstValue(e, "entryType")}",
                                fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                            )
                            Text(
                                (if (positive) "+" else "") + fmtItemQty(qty),
                                fontWeight = FontWeight.Bold, fontSize = 15.sp,
                                color = if (positive) Color(0xFF2E7D32) else Color(0xFFB71C1C),
                            )
                        }
                        Text(
                            buildList {
                                add("📍 ${rawValue(e, "binCode").ifBlank { "—" }}")
                                rawValue(e, "zoneCode").takeIf { it.isNotBlank() }?.let { add(it) }
                                rawValue(e, "lotNo").takeIf { it.isNotBlank() }?.let { add("Lot $it") }
                                rawValue(e, "lpNo").takeIf { it.isNotBlank() }?.let { add("🧺 $it") }
                                add("#${e.optInt("entryNo")}")
                                rawValue(e, "registeringDate").takeIf { it.isNotBlank() }?.let { add(it) }
                            }.joinToString(" · "),
                            fontSize = 11.sp, color = Color.Gray,
                        )
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("Kayıt yok. Filtreyi değiştirin ya da 🔄 ile yenileyin.") }
        }
    }
}
