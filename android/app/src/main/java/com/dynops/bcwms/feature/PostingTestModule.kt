package com.dynops.bcwms.feature

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
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
import com.dynops.bcwms.ui.*
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Posting Test — BC posting smoke harness'ı runAll bound action ile tetikler
 * ve sonuçları 4 kategoriye ayırır:
 *   - ✅ Passed: gerçekten doğru post edilenler
 *   - ❌ Real Failure: kod/logic bug ya da bilinmeyen hata (default açık)
 *   - ⚙️ Setup Missing: BC verisi eksik (Inv. Posting Setup, routing, vb.) →
 *        default kapalı expandable section; demo/customer ortamı için tipik
 *   - 🔗 Skipped (cascade): bağımlı test fail ettiği için anlamlı değil →
 *        default kapalı expandable section
 *
 * Kullanıcı isteği: "veri eksikse hidden tab'da topla". İki gizli kategori
 * (Setup Missing + Cascade Skip) header'a tıklanınca açılır.
 */
@Composable
fun PostingTestModule() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var running by remember { mutableStateOf(false) }
    var showSetup by remember { mutableStateOf(false) }
    var showSkipped by remember { mutableStateOf(false) }

    fun load() {
        scope.launch {
            val r = BcApi.get(context, "postingTests?\$orderby=sortOrder&\$select=domain,description,status,detail,postedDocNo")
            if (r.ok) rows = BcApi.parseValueArray(r.body)
        }
    }
    fun runAll() {
        scope.launch {
            running = true; status = "Tüm posting testleri çalışıyor (BC'de gerçek belge post ediliyor)..."
            val r = BcApi.boundAction(context, "postingTests", "1-MOVE", "runAll", "{}")
            running = false
            status = if (r.ok) "TAMAM: Posting testleri tamamlandı." else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
            load()
        }
    }
    LaunchedEffect(Unit) { load() }

    val grouped = remember(rows) { groupPostingResults(rows) }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Text("BC Kayıt Testi", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Text("Her WMS post/register aksiyonu için BC'de gerçek belge oluşturup post eder.", fontSize = 11.sp, color = Color.Gray)
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Button(onClick = { runAll() }, enabled = !running) { Text(if (running) "Çalışıyor..." else "▶ Tüm Postingleri Test Et") }
            Spacer(Modifier.width(8.dp))
            OutlinedButton(onClick = { load() }, enabled = !running) {
                WmsIcon(WmsGlyph.ENTRIES, MaterialTheme.colorScheme.primary, Modifier.size(20.dp))
            }
        }
        Spacer(Modifier.height(6.dp))
        StatusText(status)
        Spacer(Modifier.height(8.dp))
        if (rows.isNotEmpty()) PostingSummary(grouped)
        Spacer(Modifier.height(6.dp))

        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            // 1) Passed — yeşil özet kart (varsa, default açık)
            items(grouped.passed) { row -> PostingRowCard(row, kind = PostingKind.PASSED) }

            // 2) Real Failure — kırmızı, default açık (asıl ilgilenilmesi gereken)
            items(grouped.realFailure) { row -> PostingRowCard(row, kind = PostingKind.FAILED) }

            // 3) Setup Missing — collapsible header + cards
            if (grouped.setupMissing.isNotEmpty()) {
                item {
                    SectionHeader(
                        icon = "⚙️",
                        title = "Kurulum Eksiklikleri",
                        count = grouped.setupMissing.size,
                        subtitle = "BC'de Inventory Posting Setup / routing / hesap planı eksik",
                        expanded = showSetup,
                        bg = Color(0xFFFFF8E1),
                        fg = Color(0xFFEF6C00),
                    ) { showSetup = !showSetup }
                }
                if (showSetup) items(grouped.setupMissing) { row -> PostingRowCard(row, kind = PostingKind.SETUP_MISSING) }
            }

            // 4) Cascade Skip — collapsible
            if (grouped.cascadeSkip.isNotEmpty()) {
                item {
                    SectionHeader(
                        icon = "🔗",
                        title = "Bağımlılık Atlandı",
                        count = grouped.cascadeSkip.size,
                        subtitle = "Önce çalışması gereken test başarısız olduğu için anlamlı değil",
                        expanded = showSkipped,
                        bg = Color(0xFFE3F2FD),
                        fg = Color(0xFF1565C0),
                    ) { showSkipped = !showSkipped }
                }
                if (showSkipped) items(grouped.cascadeSkip) { row -> PostingRowCard(row, kind = PostingKind.CASCADE_SKIP) }
            }

            if (rows.isEmpty()) item { EmptyState("Henüz posting testi çalıştırılmadı. ▶ ile başlatın.") }
        }
    }
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

private enum class PostingKind { PASSED, FAILED, SETUP_MISSING, CASCADE_SKIP }

private data class GroupedPosting(
    val passed: List<JSONObject>,
    val realFailure: List<JSONObject>,
    val setupMissing: List<JSONObject>,
    val cascadeSkip: List<JSONObject>,
) {
    val totalFail get() = realFailure.size + setupMissing.size + cascadeSkip.size
}

private fun groupPostingResults(rows: List<JSONObject>): GroupedPosting {
    val passed = mutableListOf<JSONObject>()
    val real = mutableListOf<JSONObject>()
    val setup = mutableListOf<JSONObject>()
    val cascade = mutableListOf<JSONObject>()
    for (r in rows) {
        when (classify(r)) {
            PostingKind.PASSED -> passed += r
            PostingKind.SETUP_MISSING -> setup += r
            PostingKind.CASCADE_SKIP -> cascade += r
            PostingKind.FAILED -> real += r
        }
    }
    return GroupedPosting(passed, real, setup, cascade)
}

private fun classify(row: JSONObject): PostingKind {
    val status = row.optString("status")
    if (status.equals("Passed", ignoreCase = true)) return PostingKind.PASSED
    if (status.equals("Skipped", ignoreCase = true)) return PostingKind.CASCADE_SKIP
    val d = row.optString("detail").lowercase()

    // BC tarafında veri/setup eksikliği — "şu hesap tanımlanmamış", "satır yok"
    val setupPatterns = listOf(
        "is missing in inventory posting setup",
        "account is missing",
        "must be defined",
        "no routing lines",
        "no posting setup",
        "g/l account",
        "no setup",
        "must have",
        "no number series",
        "no permission",
    )
    if (setupPatterns.any { it in d }) return PostingKind.SETUP_MISSING

    // Cascade: önce başka adım koşmalı — bu testin "kendi" hatası değil
    val cascadePatterns = listOf(
        "must run first",
        "no open put-away",
        "no open pick",
        "no registered pick",
        "no registered put-away",
        "post a receipt first",
        "shipment flow must run",
        "no bin content for",          // pre-condition (Ad-Hoc Move)
        "no inventory for",
        "şu testi önce çalıştır",
        "önce post edilmeli",
    )
    if (cascadePatterns.any { it in d }) return PostingKind.CASCADE_SKIP

    return PostingKind.FAILED
}

// ---------------------------------------------------------------------------
// UI helpers
// ---------------------------------------------------------------------------

@Composable
private fun PostingSummary(g: GroupedPosting) {
    val total = g.passed.size + g.totalFail
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        SummaryChip("Geçen", g.passed.size, total, Color(0xFF2E7D32))
        if (g.realFailure.isNotEmpty()) SummaryChip("Gerçek hata", g.realFailure.size, total, Color(0xFFC62828))
        if (g.setupMissing.isNotEmpty()) SummaryChip("Kurulum eksik", g.setupMissing.size, total, Color(0xFFEF6C00))
        if (g.cascadeSkip.isNotEmpty()) SummaryChip("Atlandı", g.cascadeSkip.size, total, Color(0xFF1565C0))
    }
}

@Composable
private fun SummaryChip(label: String, count: Int, total: Int, color: Color) {
    Surface(color = color.copy(alpha = 0.12f), shape = RoundedCornerShape(8.dp)) {
        Column(Modifier.padding(horizontal = 8.dp, vertical = 4.dp)) {
            Text("$count / $total", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = color)
            Text(label, fontSize = 10.sp, color = color)
        }
    }
}

@Composable
private fun SectionHeader(
    icon: String,
    title: String,
    count: Int,
    subtitle: String,
    expanded: Boolean,
    bg: Color,
    fg: Color,
    onToggle: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onToggle() },
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = bg),
    ) {
        Row(
            Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(icon, fontSize = 18.sp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("$title ($count)", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = fg)
                Text(subtitle, fontSize = 11.sp, color = fg.copy(alpha = 0.8f))
            }
            Text(if (expanded) "▾" else "▸", fontSize = 18.sp, color = fg)
        }
    }
}

@Composable
private fun PostingRowCard(d: JSONObject, kind: PostingKind) {
    val (mark, color, bg) = when (kind) {
        PostingKind.PASSED -> Triple("✅", Color(0xFF2E7D32), Color.Unspecified)
        PostingKind.FAILED -> Triple("❌", Color(0xFFC62828), Color.Unspecified)
        PostingKind.SETUP_MISSING -> Triple("⚙️", Color(0xFFEF6C00), Color(0xFFFFF8E1))
        PostingKind.CASCADE_SKIP -> Triple("🔗", Color(0xFF1565C0), Color(0xFFE3F2FD))
    }
    Card(
        Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(10.dp),
        colors = if (bg == Color.Unspecified) CardDefaults.cardColors()
            else CardDefaults.cardColors(containerColor = bg),
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("$mark ${d.optString("description")}", fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                val statusLabel = when (kind) {
                    PostingKind.PASSED -> "Geçti"
                    PostingKind.FAILED -> "Başarısız"
                    PostingKind.SETUP_MISSING -> "Kurulum eksik"
                    PostingKind.CASCADE_SKIP -> "Atlandı"
                }
                Text(statusLabel, color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
            val doc = firstValue(d, "postedDocNo")
            if (doc != "-") Text("Belge: $doc", fontSize = 12.sp, color = Color(0xFF2E7D32))
            val detail = d.optString("detail")
            if (detail.isNotBlank()) {
                Text(detail, fontSize = 11.sp, color = Color.Gray)
                // Setup eksikleri için kullanıcıya somut hint
                if (kind == PostingKind.SETUP_MISSING) {
                    Text(
                        text = setupHint(detail),
                        fontSize = 11.sp,
                        color = Color(0xFFEF6C00),
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}

/**
 * Setup eksikliği tipine göre BC'de hangi sayfaya gidileceğini önerir.
 * PostingTestCodeunit detail mesajını parse eder.
 */
private fun setupHint(detail: String): String {
    val d = detail.lowercase()
    // Spesifik pattern'ler önce: "wip account" hem "wip" hem "inventory posting setup"
    // içerir; generic "inventory posting setup" eşleşmesini ezmesini önlüyoruz.
    return when {
        "wip account" in d -> "→ BC: 'Inventory Posting Setup' (Location boş kombinasyonu) için WIP Account; G/L Setup → Accounts"
        "no routing lines" in d || "routing no" in d -> "→ BC: Production Order satırının 'Routing No.' alanı dolu olmalı; Released öncesi Routing → Stations atayın"
        "inventory posting setup" in d -> "→ BC: 'Inventory Posting Setup' sayfası; Location + Invt. Posting Group satırına Inventory Account doldurun"
        "account is missing" in d -> "→ BC: 'G/L Account Card' ile ilgili hesap oluşturun; sonra 'General Posting Setup' veya 'Inventory Posting Setup'a bağlayın"
        "no permission" in d -> "→ BC: User Setup / Permission Set kontrolü; DOPSWHS extension permission set'i atanmamış olabilir"
        "number series" in d -> "→ BC: 'No. Series' setup; ilgili dokuman tipi için aktif seri tanımlayın"
        else -> "→ BC Setup ekranında veri tamamlanmalı (yukarıdaki mesajdaki anahtar ifadeyi arayın)"
    }
}
