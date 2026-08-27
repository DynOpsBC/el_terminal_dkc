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
import com.dynops.bcwms.ui.*
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Quality (Kalite) — manage quality inspection orders from the handheld.
 * Lists open quality orders; the inspector PASSES (release) or FAILS (→ quarantine bin) each.
 * BC: qualityOrders / pass / fail / createOrder (warehouse/v2.0).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QualityModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var showOnlyOpen by remember { mutableStateOf(true) }
    var inspectOrder by remember { mutableStateOf<JSONObject?>(null) }
    var search by remember { mutableStateOf("") }

    fun load() {
        scope.launch {
            loading = true; status = "Kalite emirleri yükleniyor..."
            val filter = com.dynops.bcwms.ui.buildODataFilter(com.dynops.bcwms.ui.searchClause("no", search))
            val page = BcApi.getAllPages(context, "qualityOrders?\$top=50&\$orderby=no&\$select=no,sourceType,sourceNo,itemNo,itemDescription,quantity,sampleSize,status,inspector,resultNotes,quarantineBin$filter")
            loading = false
            val all = if (page.complete) page.rows else emptyList()
            rows = if (showOnlyOpen) all.filter { it.optString("status") == "Open" } else all
            status = if (!page.complete) "HATA: Kalite emirlerinin tamamı alınamadı. Yenileyin."
                else if (rows.isEmpty()) "BOŞ: ${if (showOnlyOpen) "Açık kalite emri yok" else "Kalite emri yok"}"
                else "TAMAM: ${rows.size} kalite emri"
        }
    }
    LaunchedEffect(showOnlyOpen) { load() }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { load() }, enabled = !loading) { WmsRefreshLabel(loading) }
            Spacer(Modifier.width(12.dp))
            FilterChip(selected = showOnlyOpen, onClick = { showOnlyOpen = true }, label = { Text("Açık") })
            Spacer(Modifier.width(6.dp))
            FilterChip(selected = !showOnlyOpen, onClick = { showOnlyOpen = false }, label = { Text("Tümü") })
        }
        Spacer(Modifier.height(8.dp))
        com.dynops.bcwms.ui.DocSearchBar(value = search, onValueChange = { search = it }, onSearch = { load() }, label = "QO no ile ara")
        Spacer(Modifier.height(4.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(rows) { d ->
                val st = d.optString("status")
                // BC durum değeri (st) karşılaştırmalarda kullanılır; ekrana Türkçe etiket gösterilir.
                val stLabel = when (st) {
                    "Open" -> "Açık"
                    "Passed" -> "Geçti"
                    "Failed" -> "Başarısız"
                    "Skipped" -> "Atlandı"
                    "InProgress" -> "Devam ediyor"
                    else -> st
                }
                val (bg, fg) = when (st) {
                    "Passed" -> Color(0xFFE8F5E9) to Color(0xFF2E7D32)
                    "Failed" -> Color(0xFFFFEBEE) to Color(0xFFC62828)
                    else -> Color(0xFFFFF8E1) to Color(0xFFEF6C00)
                }
                Card(
                    onClick = { inspectOrder = d },
                    enabled = st == "Open",
                    modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(10.dp)
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(d.optString("no"), fontWeight = FontWeight.Bold)
                            Surface(color = bg, shape = RoundedCornerShape(6.dp)) {
                                Text(stLabel, Modifier.padding(horizontal = 8.dp, vertical = 2.dp), color = fg, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                        Text("${d.optString("itemNo")} — ${firstValue(d, "itemDescription")}", fontSize = 13.sp)
                        Text("Adet: ${d.optDouble("quantity")} · Numune: ${d.optDouble("sampleSize")} · Kaynak: ${firstValue(d, "sourceNo")}", fontSize = 12.sp, color = Color.Gray)
                        if (st != "Open") {
                            val notes = d.optString("resultNotes")
                            Text("Denetçi: ${firstValue(d, "inspector")}${if (notes.isNotBlank()) " · $notes" else ""}", fontSize = 11.sp, color = fg)
                        } else {
                            Text("Denetlemek için dokunun →", fontSize = 11.sp, color = Color(0xFFEF6C00))
                        }
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("Kalite emri yok.") }
        }
    }

    val io = inspectOrder
    if (io != null) {
        InspectSheet(order = io, onDismiss = { inspectOrder = null }, onResult = { passed, reason, notes, quarantine ->
            scope.launch {
                val inspector = BcApi.currentUserId(context).trim()
                if (inspector.isBlank()) {
                    status = "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
                    return@launch
                }
                inspectOrder = null
                loading = true; status = "Sonuç kaydediliyor..."
                val no = io.optString("no")
                val r = if (passed)
                    BcApi.boundAction(context, "qualityOrders", no, "pass",
                        JSONObject().apply { put("inspector", inspector); put("notes", notes) }.toString())
                else
                    BcApi.boundAction(context, "qualityOrders", no, "fail",
                        JSONObject().apply { put("inspector", inspector); put("reasonCode", reason); put("notes", notes); put("quarantineBin", quarantine) }.toString())
                loading = false
                status = if (r.ok) "TAMAM: $no → ${if (passed) "KABUL" else "RED"}"
                    else operatorFacingStatus("HATA: ${BcApi.errorMessage(r.body)}")
                load()
            }
        })
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun InspectSheet(order: JSONObject, onDismiss: () -> Unit, onResult: (passed: Boolean, reason: String, notes: String, quarantine: String) -> Unit) {
    var notes by remember { mutableStateOf("") }
    var sampleBarcode by remember { mutableStateOf("") }
    var quarantine by remember { mutableStateOf("QUARANTINE") }
    val reasons = listOf("DAMAGED", "WRONGITEM", "EXPIRED", "CONTAMINATED", "SPEC-FAIL")
    var reason by remember { mutableStateOf(reasons.first()) }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Kalite Denetimi — ${order.optString("no")}", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("${order.optString("itemNo")} · Numune: ${order.optDouble("sampleSize")} / ${order.optDouble("quantity")}", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(12.dp))
        ScanField(
            "Numune barkod (opsiyonel)",
            sampleBarcode,
            { sampleBarcode = it },
            modifier = Modifier.fillMaxWidth(),
            onScanned = {
                val value = BarcodeIntentResolver.resolve(it).value.trim()
                sampleBarcode = value
                if (value.isNotBlank()) notes = "Numune barkodu: $value"
            },
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(notes, { notes = it }, label = { Text("Notlar") }, modifier = Modifier.fillMaxWidth(), maxLines = 3)
        Spacer(Modifier.height(12.dp))
        Text("RED sebebi (başarısız için)", fontSize = 12.sp, color = Color.Gray)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            reasons.forEach { FilterChip(selected = it == reason, onClick = { reason = it }, label = { Text(it, fontSize = 11.sp) }) }
        }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(quarantine, { quarantine = it }, label = { Text("Karantina Bin (red için)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(16.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = { onResult(true, "", notes, "") },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32))
            ) { Text("✅ KABUL", fontWeight = FontWeight.Bold) }
            Button(
                onClick = { onResult(false, reason, notes, quarantine.trim()) },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62828))
            ) { Text("❌ RED", fontWeight = FontWeight.Bold) }
        }
        Spacer(Modifier.height(24.dp))
    }
}
