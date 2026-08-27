package com.dynops.bcwms.feature

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.BuildConfig
import com.dynops.bcwms.shouldForceProductionFlow
import com.dynops.bcwms.scanner.ScanField
import com.dynops.bcwms.ui.EmptyState
import com.dynops.bcwms.ui.InfoPill
import com.dynops.bcwms.ui.StatusText
import com.dynops.bcwms.ui.WmsGlyph
import com.dynops.bcwms.ui.WmsIcon
import com.dynops.bcwms.ui.WmsRefreshLabel
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Printers module — view agent-discovered printers and set the default printer
 * for this device (per-usage). The selection is stored in SharedPreferences
 * under `bcwms.printer.<usage>` and consumed by LP/Pick/Ship print buttons.
 */

private const val PREF_NAMESPACE = "bcwms.printer."
const val PRINTER_USAGE_LABEL = "LpLabel"
const val PRINTER_USAGE_DOCUMENT = "Document"

fun getDefaultPrinter(context: Context, usage: String = PRINTER_USAGE_LABEL): String {
    return context.getSharedPreferences("bcwms_prefs", Context.MODE_PRIVATE)
        .getString(PREF_NAMESPACE + usage, "") ?: ""
}

fun setDefaultPrinter(context: Context, code: String, usage: String = PRINTER_USAGE_LABEL) {
    context.getSharedPreferences("bcwms_prefs", Context.MODE_PRIVATE)
        .edit().putString(PREF_NAMESPACE + usage, code).apply()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrintersModule() {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var defaultLabelCode by remember { mutableStateOf(getDefaultPrinter(context, PRINTER_USAGE_LABEL)) }
    var defaultDocumentCode by remember { mutableStateOf(getDefaultPrinter(context, PRINTER_USAGE_DOCUMENT)) }
    var scannedBarcode by rememberSaveable { mutableStateOf("") }
    var barcodePrintBusy by remember { mutableStateOf(false) }
    val productionCustomer = shouldForceProductionFlow(BuildConfig.FLAVOR)

    fun load() {
        scope.launch {
            loading = true; status = "Yükleniyor..."
            val page = BcApi.getAllPages(context, "printers?\$top=100&\$orderby=code")
            loading = false
            rows = if (page.complete) page.rows else emptyList()
            status = if (!page.complete) "HATA: Yazıcı listesinin tamamı alınamadı. Windows yazıcı ajanının bağlantısını kontrol edin."
                else if (rows.isEmpty()) "Henüz eşitlenmiş yazıcı yok. Windows ajanında Yazıcıları Yenile ve Buluta Eşitle'yi çalıştırın."
                else "TAMAM: ${rows.size} yazıcı hazır"
        }
    }
    LaunchedEffect(Unit) { load() }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            WmsIcon(WmsGlyph.PRINTER, MaterialTheme.colorScheme.primary, Modifier.size(24.dp))
            Spacer(Modifier.width(8.dp))
            Text("Yazıcılar", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
        Text(
            "Windows ajanının buluta eşitlediği yazıcılardan bu cihaz için etiket ve belge varsayılanını seçin.",
            fontSize = 12.sp, color = Color.Gray
        )
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { load() }, enabled = !loading) { WmsRefreshLabel(loading) }
        }
        Spacer(Modifier.height(6.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (!productionCustomer) item {
                Card(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                ) {
                    Column(Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            WmsIcon(WmsGlyph.SCAN, MaterialTheme.colorScheme.primary, Modifier.size(22.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Barkod Baskı Testi", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        }
                        Text(
                            "Barkodu okutun; okunan numara aşağıda görünür ve seçili belge yazıcısına PDF olarak basılır.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f),
                        )
                        Spacer(Modifier.height(8.dp))
                        ScanField(
                            label = "Barkodu okut",
                            value = scannedBarcode,
                            onValueChange = { scannedBarcode = it },
                            modifier = Modifier.fillMaxWidth(),
                            onScanned = { raw ->
                                scannedBarcode = raw.trim()
                                status = "Okunan barkod: ${raw.trim()}"
                                keyboardController?.hide()
                            },
                        )
                        if (scannedBarcode.isNotBlank()) {
                            Spacer(Modifier.height(8.dp))
                            Surface(
                                color = MaterialTheme.colorScheme.surface,
                                shape = RoundedCornerShape(8.dp),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Column(Modifier.padding(10.dp)) {
                                    Text("OKUNAN NUMARA", fontSize = 11.sp, color = Color.Gray)
                                    Text(
                                        scannedBarcode,
                                        fontFamily = FontFamily.Monospace,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 20.sp,
                                    )
                                }
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = {
                                keyboardController?.hide()
                                focusManager.clearFocus(force = true)
                                scope.launch {
                                    barcodePrintBusy = true
                                    val payload = JSONObject().apply {
                                        put("barcodeValue", scannedBarcode.trim())
                                        put("copies", 1)
                                    }.toString()
                                    val result = BcApi.boundAction(
                                        context,
                                        "printers",
                                        defaultDocumentCode,
                                        "printBarcodeTest",
                                        payload,
                                    )
                                    barcodePrintBusy = false
                                    status = if (result.ok) {
                                        val jobId = runCatching { JSONObject(result.body).optInt("value") }.getOrDefault(0)
                                        if (jobId > 0) "Barkod $scannedBarcode, iş $jobId olarak Azure'a gönderildi."
                                        else "Barkod $scannedBarcode Azure'a gönderildi."
                                    } else {
                                        "HATA: ${result.body.take(180)}"
                                    }
                                }
                            },
                            enabled = !barcodePrintBusy && scannedBarcode.trim().length in 1..100 && defaultDocumentCode.isNotBlank(),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(if (barcodePrintBusy) "Gönderiliyor..." else "🖨 Belge Yazıcısına Yazdır")
                        }
                        if (defaultDocumentCode.isBlank()) {
                            Text("Önce aşağıdaki PDF yazıcısında Belge düğmesine basın.", fontSize = 12.sp, color = MaterialTheme.colorScheme.error)
                        } else {
                            Text("Belge yazıcısı: $defaultDocumentCode", fontSize = 11.sp, color = Color.Gray)
                        }
                    }
                }
            }
            if (rows.isEmpty() && !loading) item { EmptyState("Kayıtlı yazıcı yok. Windows Print Agent'ta yazıcıları yenileyip Buluta Eşitle'yi çalıştırın.") }
            items(rows) { row ->
                val code = row.optString("code")
                val desc = row.optString("description")
                val format = row.optString("format")
                val handle = row.optString("printerHandle").ifBlank { row.optString("hostname") }
                val active = row.optBoolean("active", true)
                val agentStatus = row.optString("agentStatus")
                val stationId = row.optString("stationId")
                val isLabelDefault = defaultLabelCode == code
                val isDocumentDefault = defaultDocumentCode == code
                Card(shape = RoundedCornerShape(12.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(code, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.width(8.dp))
                            if (isLabelDefault) InfoPill("Etiket")
                            if (isDocumentDefault) {
                                Spacer(Modifier.width(4.dp))
                                InfoPill("Belge")
                            }
                            if (!active) {
                                Spacer(Modifier.width(4.dp))
                                InfoPill(
                                    "Pasif",
                                    containerColor = MaterialTheme.colorScheme.errorContainer,
                                    contentColor = MaterialTheme.colorScheme.onErrorContainer,
                                )
                            }
                            if (agentStatus.isNotBlank() && !productionCustomer) {
                                Spacer(Modifier.width(4.dp))
                                InfoPill("Bağlantı $agentStatus")
                            }
                        }
                        Text(
                            if (productionCustomer) "$desc · ${if (format == "ZPL") "Etiket yazıcısı" else "Belge yazıcısı"}"
                            else "$desc · $format · ${handle.ifBlank { "-" }}",
                            fontSize = 12.sp,
                            color = Color.Gray,
                        )
                        if (!productionCustomer && stationId.isNotBlank()) Text(stationId, fontSize = 11.sp, color = Color.Gray)
                        Spacer(Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            OutlinedButton(
                                onClick = {
                                    setDefaultPrinter(context, code, PRINTER_USAGE_LABEL)
                                    defaultLabelCode = code
                                },
                                enabled = active && format == "ZPL",
                            ) { Text(if (isLabelDefault) "✓ Etiket" else "Etiket", fontSize = 12.sp) }
                            OutlinedButton(
                                onClick = {
                                    setDefaultPrinter(context, code, PRINTER_USAGE_DOCUMENT)
                                    defaultDocumentCode = code
                                },
                                enabled = active && format == "PDF",
                            ) { Text(if (isDocumentDefault) "✓ Belge" else "Belge", fontSize = 12.sp) }
                        }
                        if (!productionCustomer) {
                            Spacer(Modifier.height(6.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                OutlinedButton(onClick = {
                                    scope.launch {
                                        val r = BcApi.boundAction(context, "printers", code, "testPrint", "{}")
                                        status = if (r.ok) "Test yazdırma işi ${code} kuyruğa alındı." else "HATA: ${r.body.take(140)}"
                                    }
                                }, enabled = active && format == "ZPL") { Text("🧪 ZPL Test", fontSize = 12.sp) }
                            }
                        }
                    }
                }
            }
        }
    }
}
