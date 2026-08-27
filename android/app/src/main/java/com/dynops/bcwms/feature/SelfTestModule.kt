package com.dynops.bcwms.feature

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
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
import com.dynops.bcwms.scanner.ScanBus
import com.dynops.bcwms.scanner.ScanEvent
import com.dynops.bcwms.ui.bcwmsStatus
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Mobil app sağlık paneli. Müşteri ortamına kurulum / hand-off sonrası
 * operatörün veya yöneticinin "her şey çalışıyor mu?" diye tek dokunuşla
 * doğrulayabilmesi için her WMS modülünün API senaryosunu sırayla yürütür
 * ve PASS/FAIL/SKIP raporu üretir. Senaryolar üç gruba ayrılır: Bağlantı &
 * Kimlik, Veri & Modüller, Cihaz.
 *
 * Web tarafındaki [web/src/pages/SelfTest.tsx] ile aynı katalogu paylaşır.
 */

private const val G_CONN = "Bağlantı & Kimlik"
private const val G_MOD = "Veri & Modüller"
private const val G_DEVICE = "Cihaz"
private val GroupOrder = listOf(G_CONN, G_MOD, G_DEVICE)

private enum class CheckStatus { PENDING, RUNNING, PASS, FAIL, SKIP }

private data class CheckResult(
    val id: String,
    val title: String,
    val status: CheckStatus,
    val group: String = G_MOD,
    val message: String = "",
    val durationMs: Long = 0,
)

@Composable
fun SelfTestModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var running by remember { mutableStateOf(false) }
    var results by remember { mutableStateOf<List<CheckResult>>(initialChecks()) }

    fun update(id: String, status: CheckStatus, message: String = "", durationMs: Long = 0) {
        results = results.map { if (it.id == id) it.copy(status = status, message = message, durationMs = durationMs) else it }
    }

    suspend fun timed(id: String, block: suspend () -> Pair<CheckStatus, String>) {
        update(id, CheckStatus.RUNNING)
        val start = System.currentTimeMillis()
        val (status, msg) = try { block() } catch (e: Exception) { CheckStatus.FAIL to "istisna: ${e.message ?: e.javaClass.simpleName}" }
        update(id, status, msg, System.currentTimeMillis() - start)
    }

    fun runAll() {
        if (running) return
        running = true
        results = initialChecks()
        scope.launch {
            val hasToken = BcApi.hasToken(context)

            // --- Bağlantı & Kimlik ---
            timed("token") {
                if (hasToken) CheckStatus.PASS to "Bağlantı tokenı kayıtlı"
                else CheckStatus.FAIL to "Token yok — Bağlantı Ayarları'ndan giriş yapın"
            }
            timed("bc_warehouse") {
                if (!hasToken) return@timed CheckStatus.SKIP to "Token gerek"
                val r = BcApi.testConnection(context)
                if (r.ok) CheckStatus.PASS to "warehouse/v2.0 ulaşılabilir (HTTP ${r.httpCode})"
                else CheckStatus.FAIL to "HTTP ${r.httpCode} · ${BcApi.errorMessage(r.body).take(120)}"
            }
            timed("bc_standard") {
                if (!hasToken) return@timed CheckStatus.SKIP to "Token gerek"
                val r = BcApi.getWithStandardFallback(context, "items?\$top=1")
                if (r.ok) CheckStatus.PASS to "items servisi çalışıyor (HTTP ${r.httpCode})"
                else CheckStatus.FAIL to "HTTP ${r.httpCode}"
            }
            timed("token_age") {
                if (!hasToken) return@timed CheckStatus.SKIP to "Token gerek"
                val r = BcApi.get(context, "licensePlates?\$top=1")
                if (r.httpCode == 401) CheckStatus.FAIL to "Token süresi dolmuş — yeniden giriş yapın"
                else if (r.ok) CheckStatus.PASS to "Token geçerli (HTTP ${r.httpCode})"
                else CheckStatus.SKIP to "Belirsiz (HTTP ${r.httpCode})"
            }

            // --- Veri & Modüller ---
            timed("item_inventory") {
                if (!hasToken) return@timed CheckStatus.SKIP to "Token gerek"
                val r = BcApi.get(context, "items?\$top=1&\$select=no,inventory,quantityOnPurchOrder,quantityOnSalesOrder")
                if (!r.ok) return@timed CheckStatus.FAIL to "items sorgusu HTTP ${r.httpCode}"
                val first = BcApi.parseValueArray(r.body).firstOrNull()
                    ?: return@timed CheckStatus.SKIP to "Hiç ürün yok"
                if (!first.has("inventory")) return@timed CheckStatus.FAIL to "inventory alanı yok — ItemApi.Page.al güncel mi?"
                CheckStatus.PASS to "inventory alanı dönüyor (${first.optString("no")}=${first.optDouble("inventory")})"
            }
            timed("bin_contents") {
                if (!hasToken) return@timed CheckStatus.SKIP to "Token gerek"
                val r = BcApi.get(context, "binContents?\$top=1")
                if (r.ok) CheckStatus.PASS to "binContents servisi çalışıyor"
                else CheckStatus.FAIL to "HTTP ${r.httpCode} — DOPSWHS BinContent API publish edildi mi?"
            }
            timed("bins") { probe(context, hasToken, "bins?\$top=1", "Bin kartları") }
            timed("lp_templates") {
                if (!hasToken) return@timed CheckStatus.SKIP to "Token gerek"
                val r = BcApi.get(context, "licensePlateTemplates?\$top=10&\$select=code")
                val codes = if (r.ok) BcApi.parseValueArray(r.body) else emptyList()
                when {
                    !r.ok -> CheckStatus.FAIL to "HTTP ${r.httpCode}"
                    codes.isEmpty() -> CheckStatus.FAIL to "Hiç LP şablonu yok — kurulum gerekli"
                    else -> CheckStatus.PASS to "${codes.size} şablon (${codes.first().optString("code")}...)"
                }
            }
            timed("receiving") { probe(context, hasToken, "receipts?\$top=1", "Mal Kabul (receipts)") }
            timed("putaway") { probe(context, hasToken, "putAways?\$top=1", "Yerleştirme") }
            timed("picking") { probe(context, hasToken, "picks?\$top=1", "Toplama (picks)") }
            timed("shipping") { probe(context, hasToken, "shipments?\$top=1", "Sevkiyat (shipments)") }
            timed("count") { probe(context, hasToken, "countSheets?\$top=1", "Sayım (countSheets)") }
            timed("movements") { probe(context, hasToken, "movements?\$top=1", "Hareket (movements)") }
            timed("production") { probe(context, hasToken, "productionOutput?\$top=1", "Üretim (productionOutput)") }
            timed("assembly") { probe(context, hasToken, "assemblies?\$top=1", "Montaj (assemblies)") }
            timed("quality_orders") { probe(context, hasToken, "qualityOrders?\$top=1", "Kalite (qualityOrders)") }
            timed("printers") { probe(context, hasToken, "printers?\$top=1", "Yazıcılar (printers)") }

            // --- Cihaz ---
            timed("default_printer") {
                val printer = com.dynops.bcwms.feature.getDefaultPrinter(context)
                if (printer.isBlank()) CheckStatus.SKIP to "Varsayılan yazıcı atanmadı (Yazıcılar ekranından seçin)"
                else CheckStatus.PASS to "Varsayılan: $printer"
            }
            timed("scan_bus") {
                val received = withTimeoutOrNull(500) {
                    coroutineScope {
                        val deferred = async(start = CoroutineStart.UNDISPATCHED) {
                            ScanBus.events.first()
                        }
                        delay(20)
                        ScanBus.emit(ScanEvent(raw = "SELF_TEST_PROBE", symbology = "TEST"))
                        deferred.await()
                    }
                }
                if (received?.raw == "SELF_TEST_PROBE") CheckStatus.PASS to "ScanBus emit + collect başarılı"
                else CheckStatus.FAIL to "Bus olayı alınmadı (DataWedge bağlantısını kontrol edin)"
            }

            running = false
        }
    }

    val summary = results.fold(Triple(0, 0, 0)) { acc, r ->
        when (r.status) {
            CheckStatus.PASS -> acc.copy(first = acc.first + 1)
            CheckStatus.FAIL -> acc.copy(second = acc.second + 1)
            CheckStatus.SKIP -> acc.copy(third = acc.third + 1)
            else -> acc
        }
    }
    val total = results.size
    val pending = total - summary.first - summary.second - summary.third
    val grouped = results.groupBy { it.group }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        SummaryCard(running, summary.first, summary.second, summary.third, pending)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { runAll() }, enabled = !running, modifier = Modifier.weight(1f)) {
                Text(if (running) "Çalışıyor…" else "▶︎ Tümünü Çalıştır", fontWeight = FontWeight.Bold)
            }
            OutlinedButton(
                onClick = { results = initialChecks() },
                enabled = !running,
                modifier = Modifier.weight(1f),
            ) { Text("Sıfırla") }
        }
        Spacer(Modifier.height(10.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            GroupOrder.forEach { group ->
                val rows = grouped[group].orEmpty()
                if (rows.isNotEmpty()) {
                    item(key = "hdr_$group") { SectionHeader(group) }
                    items(rows, key = { it.id }) { r -> CheckRow(r) }
                }
            }
        }
    }
}

/** Shared reachability probe: GET endpoint, PASS on 2xx else FAIL with code. */
private suspend fun probe(
    context: android.content.Context,
    hasToken: Boolean,
    path: String,
    label: String,
): Pair<CheckStatus, String> {
    if (!hasToken) return CheckStatus.SKIP to "Token gerek"
    val r = BcApi.get(context, path)
    return if (r.ok) CheckStatus.PASS to "$label servisi çalışıyor"
    else CheckStatus.FAIL to "HTTP ${r.httpCode}"
}

@Composable
private fun SummaryCard(running: Boolean, pass: Int, fail: Int, skip: Int, pending: Int) {
    val palette = bcwmsStatus()
    val total = pass + fail + skip + pending
    val container = when {
        running -> MaterialTheme.colorScheme.primary.copy(alpha = 0.10f)
        fail > 0 -> palette.danger.copy(alpha = 0.10f)
        pass > 0 && pass == total - skip -> palette.success.copy(alpha = 0.12f)
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    Card(
        Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = container),
    ) {
        Column(Modifier.padding(16.dp)) {
            Text("🩺 Sistem Sağlığı", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
            Text(
                "Bağlantı · BC modülleri · cihaz entegrasyon senaryoları",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CountPill("✅ $pass", palette.success)
                CountPill("❌ $fail", palette.danger)
                CountPill("⏭ $skip", MaterialTheme.colorScheme.onSurfaceVariant)
                CountPill("⏳ $pending", MaterialTheme.colorScheme.primary)
            }
        }
    }
}

@Composable
private fun CountPill(text: String, color: Color) {
    Surface(shape = RoundedCornerShape(50), color = color.copy(alpha = 0.16f)) {
        Text(
            text,
            Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = color,
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title.uppercase(),
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 2.dp),
    )
}

@Composable
private fun CheckRow(r: CheckResult) {
    val palette = bcwmsStatus()
    val (icon, color) = when (r.status) {
        CheckStatus.PASS -> "✓" to palette.success
        CheckStatus.FAIL -> "✕" to palette.danger
        CheckStatus.SKIP -> "–" to MaterialTheme.colorScheme.onSurfaceVariant
        CheckStatus.RUNNING -> "…" to MaterialTheme.colorScheme.primary
        CheckStatus.PENDING -> "•" to MaterialTheme.colorScheme.outline
    }
    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp)) {
        Row(
            Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier.size(26.dp).clip(CircleShape).background(color.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) { Text(icon, color = color, fontWeight = FontWeight.Bold, fontSize = 14.sp) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(r.title, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
                if (r.message.isNotBlank()) {
                    Text(r.message, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (r.durationMs > 0) {
                Spacer(Modifier.width(8.dp))
                Text("${r.durationMs}ms", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

private fun initialChecks(): List<CheckResult> = listOf(
    // Bağlantı & Kimlik
    CheckResult("token", "BC token saklanmış mı?", CheckStatus.PENDING, G_CONN),
    CheckResult("bc_warehouse", "warehouse/v2.0 API ulaşılabilir mi?", CheckStatus.PENDING, G_CONN),
    CheckResult("bc_standard", "Standart items fallback çalışıyor mu?", CheckStatus.PENDING, G_CONN),
    CheckResult("token_age", "Token süresi geçerli mi?", CheckStatus.PENDING, G_CONN),
    // Veri & Modüller
    CheckResult("item_inventory", "Ürün Sorgu · inventory FlowField", CheckStatus.PENDING, G_MOD),
    CheckResult("bin_contents", "Bin Sorgu · binContents (72097)", CheckStatus.PENDING, G_MOD),
    CheckResult("bins", "Bin kartları (bins) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("lp_templates", "LP şablonları yüklenmiş mi?", CheckStatus.PENDING, G_MOD),
    CheckResult("receiving", "Mal Kabul (receipts) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("putaway", "Yerleştirme (putAways) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("picking", "Toplama (picks) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("shipping", "Sevkiyat (shipments) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("count", "Sayım (countSheets) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("movements", "Hareket (movements) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("production", "Üretim (productionOutput) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("assembly", "Montaj (assemblies) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("quality_orders", "Kalite (qualityOrders) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    CheckResult("printers", "Yazıcılar (printers) çalışıyor mu?", CheckStatus.PENDING, G_MOD),
    // Cihaz
    CheckResult("default_printer", "Varsayılan yazıcı atanmış mı?", CheckStatus.PENDING, G_DEVICE),
    CheckResult("scan_bus", "ScanBus emit + collect çalışıyor mu?", CheckStatus.PENDING, G_DEVICE),
)
