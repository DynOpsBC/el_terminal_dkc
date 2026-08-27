package com.dynops.bcwms.feature

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.BuildConfig
import com.dynops.bcwms.shouldForceProductionFlow
import com.dynops.bcwms.ui.*
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Picking — WI §10.3 parity.
 * Lookup (assigned-to-me + show all) -> Pick Document -> Take/Place -> Start/Stop shipping LP ->
 * Short pick (reason) -> Register.
 */
// ELOG toplama dashboard sekmeleri. ("Bekleyen" kullanıcı isteğiyle kaldırıldı —
// Pick Created durumu terminaldeki toplayıcıyı yanıltıyordu.)
/** Kapalı/bozulmuş bir LP toplama kabı olarak kullanılamaz. */
internal fun isPickContainerStatusUsable(status: String): Boolean =
    status.equals("Open", true) || status.equals("Built", true) ||
        status.equals("Assigned", true)

/** Assigned picks are mutable only after the local warehouse identity is resolved
 * and verified as the current owner. Unknown identity is deliberately fail-closed. */
internal fun canMutateAssignedPick(assignedUserId: String, localUserId: String): Boolean =
    canMutateAssignedDocument(assignedUserId, localUserId)

internal fun canRegisterAssignedPick(
    assignedUserId: String,
    localUserId: String,
    readyToRegister: Boolean,
    inFlightLineCount: Int,
): Boolean = canMutateAssignedPick(assignedUserId, localUserId) &&
    readyToRegister && inFlightLineCount == 0

internal fun pickReadyToRegister(
    pickMode: String,
    qtyToHandle: List<Double>,
    allCollected: Boolean,
): Boolean = if (pickMode.equals("Multi", ignoreCase = true)) {
    allCollected
} else {
    qtyToHandle.any { it > 0.0 }
}

/**
 * İyimser UI için satırın kopyasını "toplandı" durumuyla döndürür.
 * JSONObject mutable olduğundan kopya alınır — Compose'un eski/yeni listeyi
 * ayırt edebilmesi için yeni nesne şart.
 */
private fun cloneWithQtyHandled(line: JSONObject, qty: Double): JSONObject =
    JSONObject(line.toString()).apply { put("qtyToHandle", qty) }

private enum class PickTab(val label: String) {
    Active("⏳ Toplanmakta"),
    Mine("👤 Benim Topladıklarım"),
    AllDone("📦 Genel Toplananlar"),
}

/**
 * Açık toplama listesinin görünürlük kuralı. Üç kapsam BİRBİRİNDEN AYRIDIR:
 * eskiden "Bana atanan" seçiliyken atanmamış pick'ler de listeye karışıyordu
 * ("bana atanan VEYA atanmamış") ve toplayıcı ekrandaki işin gerçekten kendisine
 * mi ait olduğunu ayırt edemiyordu. Artık her kapsam tek bir şeyi gösterir ve
 * ne gösterdiği ekranda yazar.
 */
private enum class PickScope(val label: String, val hint: String) {
    Mine(
        "Bana atanan",
        "Sadece size atanmış açık toplamalar. Doğrudan açıp toplamaya başlayabilirsiniz.",
    ),
    Unassigned(
        "Atanmamış",
        "Kimseye atanmamış (boştaki) toplamalar. Üzerime Al ile üstlenebilirsiniz.",
    ),
    All(
        "Tümü",
        "Depodaki tüm açık toplamalar. Başkasına atanmış olanlar rozetle işaretlidir; açılmadan önce uyarı verilir.",
    ),
}

/** Bir pick satırının okuyan kullanıcıya göre sahiplik durumu. */
private enum class PickOwner { Mine, Unassigned, Other, Unknown }

/**
 * Sahiplik kararı. Kullanıcı kimliği çözülemediyse (me boş) kimseyi "başkası"
 * diye kilitlemeyiz — yanlış kilitlemektense nötr göstermek daha güvenli.
 */
private fun pickOwnerOf(assignedUserId: String, me: String): PickOwner = when {
    assignedUserId.isBlank() -> PickOwner.Unassigned
    me.isBlank() -> PickOwner.Unknown
    assignedUserId.trim().equals(me.trim(), ignoreCase = true) -> PickOwner.Mine
    else -> PickOwner.Other
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PickingModule(v2Enabled: Boolean = false) {
    // Müşteri sürümleri doğrulanmış V2 akışını kullanır. Klasik ekran yalnız
    // geliştirme/demonstrasyon flavor'larında geriye uyumluluk için kalır.
    if (shouldForceProductionFlow(BuildConfig.FLAVOR) || v2Enabled) {
        V2PickingModule()
        return
    }
    ClassicPickingModule()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClassicPickingModule() {
    // ELOG: Toplama artık sekmeli — açık pick listesi (Toplanmakta) + geçmiş/durum
    // (Bekleyen / Benim Topladıklarım / Genel Toplananlar). Diğer sekmeler
    // pickingOrders API'sini kullanır (Picking Order Header).
    var tab by remember { mutableStateOf(PickTab.Active) }
    Column(Modifier.fillMaxSize()) {
        ScrollableTabRow(
            selectedTabIndex = tab.ordinal,
            edgePadding = 8.dp,
            modifier = Modifier.fillMaxWidth(),
        ) {
            PickTab.entries.forEach { t ->
                Tab(
                    selected = tab == t,
                    onClick = { tab = t },
                    text = { Text(t.label, fontSize = 12.sp, maxLines = 1) },
                )
            }
        }
        when (tab) {
            PickTab.Active -> ActivePicksTab()
            PickTab.Mine -> PickHistoryTab(PickTab.Mine)
            PickTab.AllDone -> PickHistoryTab(PickTab.AllDone)
        }
    }
}

/** V2: üç operasyon kuyruğu birbirine karışmadan ayrı ekranlarda çalışır. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun V2PickingModule() {
    var flow by rememberSaveable { mutableStateOf(OutboundFlowMode.Multi) }
    Column(Modifier.fillMaxSize()) {
        V2FlowSelector(current = flow, onSelect = { flow = it })
        Box(Modifier.weight(1f)) { key(flow) { V2PicksForFlow(flow) } }
    }
}

@Composable
internal fun V2FlowSelector(
    current: OutboundFlowMode,
    onSelect: (OutboundFlowMode) -> Unit,
    sectionTitle: String = "Toplama türü",
) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(sectionTitle, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)) {
                Text("SEÇİLİ", Modifier.padding(horizontal = 9.dp, vertical = 4.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
            }
        }
        Spacer(Modifier.height(9.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            OutboundFlowMode.entries.forEach { item ->
                val selected = current == item
                Surface(
                    onClick = { onSelect(item) },
                    shape = RoundedCornerShape(13.dp),
                    color = if (selected) item.accent.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surface,
                    border = BorderStroke(if (selected) 2.dp else 1.dp, if (selected) item.accent else MaterialTheme.colorScheme.outline),
                    modifier = Modifier.weight(1f),
                ) {
                    Column(Modifier.padding(horizontal = 8.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(item.icon, fontSize = 18.sp, fontWeight = FontWeight.Black, color = item.accent)
                        Text(item.title, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                    }
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(current.subtitle, style = MaterialTheme.typography.bodySmall, color = current.accent, fontWeight = FontWeight.SemiBold)
    }
    HorizontalDivider()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun V2PicksForFlow(flow: OutboundFlowMode) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var selected by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var pickScope by remember { mutableStateOf(PickScope.Mine) }
    var search by remember { mutableStateOf("") }
    var myUserId by remember { mutableStateOf("") }
    var blockedPick by remember { mutableStateOf<Pair<String, String>?>(null) }

    fun load() {
        scope.launch {
            loading = true
            status = "${flow.title} işleri yükleniyor…"
            val me = BcApi.currentUserId(context)
            myUserId = me
            val ownerClause = when (pickScope) {
                PickScope.Mine -> assignedToMeClause(me)
                PickScope.Unassigned -> "assignedUserId eq ''"
                PickScope.All -> null
            }
            if (pickScope == PickScope.Mine && me.isBlank()) {
                rows = emptyList()
                loading = false
                status = "HATA: Kullanıcı kimliği çözülemedi."
                return@launch
            }
            val filter = buildODataFilter(
                "pickMode eq '${flow.apiValue}'",
                ownerClause,
                searchClause("no", search),
            )
            val page = BcApi.getAllPagesWithStandardFallback(
                context,
                "picks?\$top=100&\$orderby=no desc&\$select=no,locationCode,assignedUserId,sourceNo,status,percentComplete,pickMode,mainLpNo$filter",
            )
            rows = if (page.complete) page.rows else emptyList()
            loading = false
            status = when {
                !page.complete -> "HATA: Toplama kuyruğunun tamamı alınamadı. Yenileyin."
                rows.isEmpty() -> "${pickScope.label} kapsamında ${flow.title} işi yok."
                else -> "${rows.size} ${flow.title} toplaması"
            }
        }
    }

    fun takeOver(no: String) {
        scope.launch {
            loading = true
            val me = BcApi.currentUserId(context)
            if (me.isBlank()) {
                loading = false
                status = "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
                return@launch
            }
            val r = BcApi.boundAction(context, "picks", no, "reassign", JSONObject().apply {
                put("userId", me); put("reason", "V2 ${flow.title} terminalinden üstlenildi")
            }.toString())
            status = if (r.ok) "$no üzerinize alındı." else "HATA: ${BcApi.errorMessage(r.body)}"
            load()
        }
    }

    LaunchedEffect(flow, pickScope) { load() }
    val selectedNo = selected
    if (selectedNo != null) {
        GuidedPickDocument(no = selectedNo, flowMode = flow, onBack = { selected = null; load() })
        return
    }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PickScope.entries.forEach { item ->
                FilterChip(
                    selected = pickScope == item,
                    onClick = { pickScope = item },
                    label = { Text(item.label, fontSize = 11.sp, maxLines = 1) },
                )
                Spacer(Modifier.width(5.dp))
            }
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { load() }, enabled = !loading) { Text(if (loading) "…" else "Yenile") }
        }
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            label = { Text("Toplama no ile ara") },
            singleLine = true,
            trailingIcon = { TextButton(onClick = { load() }) { Text("Ara") } },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(4.dp))
        StatusText(status)
        Spacer(Modifier.height(6.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(rows, key = { it.optString("no") }) { row ->
                val no = row.optString("no")
                val assigned = row.optString("assignedUserId").trim()
                val owner = pickOwnerOf(assigned, myUserId)
                PickListCard(
                    d = row,
                    busy = loading,
                    owner = owner,
                    onOpen = { if (owner == PickOwner.Other) blockedPick = no to assigned else selected = no },
                    onTake = { takeOver(no) },
                )
            }
            if (rows.isEmpty() && !loading) item { EmptyState("${flow.title} kuyruğunda açık toplama yok.") }
        }
    }

    blockedPick?.let { blocked ->
        AlertDialog(
            onDismissRequest = { blockedPick = null },
            title = { Text("Toplama ${blocked.second} kullanıcısında") },
            text = { Text("Belgeyi görüntüleyebilirsiniz; işlem yapmak için önce sorumlu kullanıcıdan devralın.") },
            confirmButton = { TextButton(onClick = { blockedPick = null; selected = blocked.first }) { Text("Görüntüle") } },
            dismissButton = { TextButton(onClick = { blockedPick = null }) { Text("Vazgeç") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ActivePicksTab() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<String?>(null) }
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    // Varsayılan "Bana atanan": toplayıcı ekranı açar açmaz SADECE kendi işini görsün.
    var pickScope by remember { mutableStateOf(PickScope.Mine) }
    var search by remember { mutableStateOf("") }
    // Rozetleri ("… kullanıcısında") çizebilmek için oturumdaki kullanıcı kimliği.
    // Liste yüklenirken tek sefer çözülür, sonra cache'ten gelir.
    var myUserId by remember { mutableStateOf("") }
    // "Tümü"de başkasına atanmış bir pick'e dokunulunca çıkan uyarı: belge no + sahibi.
    var blockedPick by remember { mutableStateOf<Pair<String, String>?>(null) }

    fun load() {
        scope.launch {
            loading = true; status = "Yükleniyor..."
            val myUser = BcApi.currentUserId(context)
            myUserId = myUser
            // Kapsam filtresi — her kapsam TEK bir kümeyi getirir, karışım yok:
            //  Mine       -> assignedUserId = ben
            //  Unassigned -> assignedUserId boş
            //  All        -> filtre yok
            val scopeClause = when (pickScope) {
                PickScope.Mine -> assignedToMeClause(myUser)
                PickScope.Unassigned -> "assignedUserId eq ''"
                PickScope.All -> null
            }
            // "Bana atanan" isteniyor ama kimlik çözülemedi: filtresiz listeye DÜŞME —
            // aksi halde kullanıcı başkasının işlerini kendi işi sanır.
            if (pickScope == PickScope.Mine && myUser.isBlank()) {
                rows = emptyList(); loading = false
                status = "HATA: Kullanıcı kimliğiniz çözülemedi; kime atandığı bilinemiyor. Yeniden giriş yapın veya Tümü ile bakın."
                return@launch
            }
            val combined = buildODataFilter(scopeClause, searchClause("no", search))
            val page = BcApi.getAllPagesWithStandardFallback(context, "picks?\$top=100&\$orderby=no desc&\$select=no,locationCode,assignedUserId,vehicleNo,sourceNo,status,percentComplete$combined")
            loading = false
            rows = if (page.complete) page.rows else emptyList()
            status = when {
                !page.complete -> "HATA: Toplama listesinin tamamı alınamadı. Yenileyin."
                rows.isEmpty() -> "BOŞ: ${pickScope.label} filtresinde kayıt yok"
                else -> "TAMAM: ${rows.size} belge · ${pickScope.label}"
            }
        }
    }
    LaunchedEffect(pickScope) { load() }

    // Listeden "Üzerime Al": paylaşımlı BC lisansında atama BC hesabına değil
    // oturumdaki WMS kullanıcısına yazılır (reassign); WMS girişi yoksa
    // assignToMe'ye düşer.
    fun takeOver(no: String) {
        scope.launch {
            loading = true; status = "Üzerine alınıyor..."
            val me = BcApi.currentUserId(context)
            if (me.isBlank()) {
                loading = false
                status = "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
                return@launch
            }
            val r = BcApi.boundAction(context, "picks", no, "reassign",
                JSONObject().apply { put("userId", me); put("reason", "terminalden üstlenildi") }.toString())
            // "Atanmamış" kapsamındayken üstlenilen iş listeden düşer; nereye
            // gittiğini söylemezsek operatör işi kaybettiğini sanıyor.
            status = if (r.ok)
                "TAMAM: $no üzerinize alındı${if (me.isNotBlank()) " ($me)" else ""}" +
                    if (pickScope != PickScope.Mine) " — artık 'Bana atanan' filtresinde" else ""
            else "HATA: ${BcApi.errorMessage(r.body)} (HTTP ${r.httpCode})"
            load()
        }
    }

    var itemDocs by remember { mutableStateOf<Pair<String, Set<String>>?>(null) }
    val sel = selected
    if (sel != null) { GuidedPickDocument(no = sel, onBack = { selected = null; load() }); return }

    DocListScanHandler(
        enabled = true,
        linesEndpoint = "pickLines",
        documentsEndpoint = "picks",
        acceptDocTypes = setOf("pick"),
        onDocument = { selected = it },
        onError = { status = it },
    ) { item, docs ->
        when { docs.isEmpty() -> status = "⚠️ '$item' açık toplamada yok"; docs.size == 1 -> selected = docs.first(); else -> { itemDocs = item to docs; status = "TAMAM: '$item' → ${docs.size} belge" } }
    }
    val shownRows = itemDocs?.let { f -> rows.filter { it.optString("no") in f.second } } ?: rows

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            // Üç kapsam yan yana ve tek seçimli — hangisinin açık olduğu net görünsün.
            PickScope.entries.forEach { s ->
                FilterChip(
                    selected = pickScope == s,
                    onClick = { pickScope = s },
                    label = { Text(s.label, fontSize = 12.sp, maxLines = 1) },
                )
                Spacer(Modifier.width(6.dp))
            }
            Spacer(Modifier.weight(1f))
            OutlinedButton(
                onClick = { load() },
                enabled = !loading,
                shape = RoundedCornerShape(50),
                contentPadding = PaddingValues(horizontal = 14.dp),
            ) { WmsRefreshLabel(loading, compact = true) }
        }
        Spacer(Modifier.height(6.dp))
        // Seçili filtrenin NE gösterdiği tek satırda yazılı olsun — "atanmamışlar
        // da geliyor mu?" belirsizliği ekranda çözülsün.
        Text(
            pickScope.hint,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(10.dp))
        // PDF Picking §7 / §16: belge no arama eksikti
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            singleLine = true,
            label = { Text("Belge no ile ara") },
            shape = RoundedCornerShape(14.dp),
            trailingIcon = {
                TextButton(onClick = { load() }) {
                    WmsIcon(WmsGlyph.ITEM_SEARCH, MaterialTheme.colorScheme.primary, Modifier.size(21.dp))
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(6.dp))
        StatusText(status)
        if (itemDocs != null) { ScanFilterChip("${itemDocs!!.first} → ${itemDocs!!.second.size} belge") { itemDocs = null } }
        Spacer(Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(shownRows) { d ->
                val no = d.optString("no")
                val assigned = d.optString("assignedUserId").trim()
                val owner = pickOwnerOf(assigned, myUserId)
                PickListCard(
                    d = d,
                    busy = loading,
                    owner = owner,
                    // Başkasının işi açılmaya çalışılınca önce uyarı çıkar; belge
                    // ancak operatör bilerek onaylarsa açılır.
                    onOpen = {
                        if (owner == PickOwner.Other) blockedPick = no to assigned else selected = no
                    },
                    onTake = { takeOver(no) },
                )
            }
            // Boş liste mesajı filtreye özel ve yol gösterici — "hiç iş yok" ile
            // "senin işin yok" birbirinden ayrılsın.
            if (shownRows.isEmpty() && !loading) item {
                EmptyState(
                    when {
                        itemDocs != null -> "Bu ürün seçili filtredeki hiçbir belgede yok. Filtreyi Tümü yapıp tekrar deneyin."
                        search.isNotBlank() -> "'$search' ile başlayan belge bu filtrede yok. Aramayı temizleyin ya da filtreyi değiştirin."
                        pickScope == PickScope.Mine ->
                            "Size atanmış açık toplama yok. Atanmamış filtresine geçip boştaki bir işi üzerinize alabilirsiniz."
                        pickScope == PickScope.Unassigned ->
                            "Boşta bekleyen toplama yok. Açık işlerin hepsi birine atanmış — Tümü ile kimde olduğunu görebilirsiniz."
                        else -> "Depoda açık toplama belgesi yok."
                    },
                )
            }
        }
    }

    // "Tümü"de başkasına atanmış belge uyarısı: aynı pick'i iki kişi toplarsa
    // miktarlar çakışır. Yine de açılabilir (denetim/devralma için) ama bilerek.
    val bp = blockedPick
    if (bp != null) {
        AlertDialog(
            onDismissRequest = { blockedPick = null },
            title = { Text("Bu toplama başkasında") },
            text = {
                Text(
                    "${bp.first} belgesi ${bp.second} kullanıcısına atanmış. " +
                        "Aynı toplamayı iki kişi yaparsa miktarlar çakışır. " +
                        "Devam ederseniz belge salt görüntüleme olarak açılır; toplamak için önce devralmanız gerekir.",
                    fontSize = 13.sp,
                )
            },
            confirmButton = {
                TextButton(onClick = { blockedPick = null; selected = bp.first }) { Text("Yine de aç") }
            },
            dismissButton = { TextButton(onClick = { blockedPick = null }) { Text("Vazgeç") } },
        )
    }
}

// ELOG dashboard zaman filtresi seçenekleri.
private enum class DateRange(val label: String) {
    Last24h("Son 24 saat"),
    Today("Bugün"),
    Yesterday("Dün"),
    Last7d("Son 7 gün"),
    Custom("Tarih aralığı"),
    All("Tümü"),
}

/**
 * ELOG toplama geçmiş/durum sekmesi. Picking Order Header'ı (pickingOrders API)
 * okur; sekmeye göre filtreler:
 *  - Pending: status=Open (henüz pick oluşmamış, toplanmayı bekleyen)
 *  - Mine: status=Completed + assignedUserId=ben (benim topladıklarım)
 *  - AllDone: status=Completed (genel toplananlar)
 * Zaman filtresi: Completed sekmelerinde completedDateTime, Pending'de createdDateTime.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PickHistoryTab(tab: PickTab) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var range by remember { mutableStateOf(DateRange.Last24h) }
    var customFrom by remember { mutableStateOf("") } // yyyy-MM-dd
    var customTo by remember { mutableStateOf("") }

    // Her iki sekme de tamamlanmış toplamaları gösterir → completedDateTime.
    val dateField = "completedDateTime"

    fun isoStart(daysAgo: Long): String {
        val cal = java.util.Calendar.getInstance()
        cal.add(java.util.Calendar.DAY_OF_YEAR, -daysAgo.toInt())
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0); cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0); cal.set(java.util.Calendar.MILLISECOND, 0)
        return isoUtc(cal.time)
    }

    fun buildRangeFilter(): String? {
        val now = System.currentTimeMillis()
        return when (range) {
            DateRange.All -> null
            DateRange.Last24h -> "$dateField ge ${isoUtc(java.util.Date(now - 24L * 3600 * 1000))}"
            DateRange.Today -> "$dateField ge ${isoStart(0)}"
            DateRange.Yesterday -> "$dateField ge ${isoStart(1)} and $dateField lt ${isoStart(0)}"
            DateRange.Last7d -> "$dateField ge ${isoStart(7)}"
            DateRange.Custom -> {
                val parts = mutableListOf<String>()
                if (customFrom.isNotBlank()) parts.add("$dateField ge ${customFrom}T00:00:00Z")
                if (customTo.isNotBlank()) parts.add("$dateField le ${customTo}T23:59:59Z")
                parts.joinToString(" and ").ifBlank { null }
            }
        }
    }

    fun load() {
        scope.launch {
            loading = true; status = "Yükleniyor..."
            val statusClause = "status eq 'Completed'"
            val me = BcApi.currentUserId(context)
            if (!canLoadAssignedOnlyList(showAll = tab != PickTab.Mine, localUserId = me)) {
                rows = emptyList()
                loading = false
                status = "HATA: Depo kullanıcınız doğrulanamadı. Yeniden giriş yapın."
                return@launch
            }
            val mineClause = if (tab == PickTab.Mine) {
                "assignedUserId eq '${me.trim().uppercase().replace("'", "''")}'"
            } else null
            val combined = buildODataFilter(statusClause, mineClause, buildRangeFilter())
            val orderBy = "$dateField desc"
            val page = BcApi.getAllPagesWithStandardFallback(
                context,
                "pickingOrders?\$top=100&\$orderby=$orderBy&\$select=entryNo,description,status,locationCode,assignedUserId,createdByUser,warehousePickNo,warehouseShipmentNo,createdDateTime,completedDateTime,orderCount$combined",
            )
            loading = false
            rows = if (page.complete) page.rows else emptyList()
            status = when {
                !page.complete -> "HATA: Toplama geçmişinin tamamı alınamadı. Yenileyin."
                rows.isEmpty() -> "BOŞ: Kayıt yok"
                else -> "TAMAM: ${rows.size} kayıt"
            }
        }
    }
    LaunchedEffect(tab, range, customFrom, customTo) { load() }

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        // Zaman filtresi çipleri.
        ScrollableTabRowChips(range, customLabel = customRangeLabel(customFrom, customTo)) { range = it }
        if (range == DateRange.Custom) {
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = customFrom, onValueChange = { customFrom = it },
                    label = { Text("Başlangıç (yyyy-aa-gg)") }, singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                OutlinedTextField(
                    value = customTo, onValueChange = { customTo = it },
                    label = { Text("Bitiş (yyyy-aa-gg)") }, singleLine = true,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            StatusText(status)
            Spacer(Modifier.weight(1f))
            OutlinedButton(
                onClick = { load() }, enabled = !loading,
                shape = RoundedCornerShape(50), contentPadding = PaddingValues(horizontal = 14.dp),
            ) { WmsRefreshLabel(loading, compact = true) }
        }
        Spacer(Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(rows) { d -> PickHistoryCard(d, tab) }
            if (rows.isEmpty() && !loading) item {
                EmptyState(
                    if (tab == PickTab.Mine) "Bu aralıkta sizin topladığınız yok."
                    else "Bu aralıkta toplanan yok.",
                )
            }
        }
    }
}

/** ELOG dashboard kartı: pick no + zaman + toplayan (+ sipariş sayısı). */
@Composable
private fun PickHistoryCard(d: JSONObject, tab: PickTab) {
    val whenField = "completedDateTime"
    val whenText = friendlyDateTime(d.optString(whenField))
    val user = rawValue(d, "assignedUserId", "createdByUser").ifBlank { "—" }
    val pickNo = d.optString("warehousePickNo").ifBlank { "Grup #${d.optInt("entryNo")}" }
    val orders = d.optInt("orderCount")
    val statusVal = d.optString("status")
    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clip(RoundedCornerShape(13.dp)).background(PickAccent.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) { Text("✅", fontSize = 20.sp) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(pickNo, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text(d.optString("description").ifBlank { d.optString("locationCode") }, fontSize = 12.sp, color = Color.Gray)
                Text(
                    "🕒 $whenText   👤 $user" + if (orders > 0) "   🧾 $orders sipariş" else "",
                    fontSize = 11.sp, color = Color.Gray,
                )
            }
        }
    }
}

// --- ELOG dashboard yardımcıları ---

/** Zaman filtresi çip satırı. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScrollableTabRowChips(current: DateRange, customLabel: String, onSelect: (DateRange) -> Unit) {
    androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        items(DateRange.entries) { r ->
            val label = if (r == DateRange.Custom && customLabel.isNotBlank()) customLabel else r.label
            FilterChip(selected = current == r, onClick = { onSelect(r) }, label = { Text(label, fontSize = 12.sp) })
        }
    }
}

private fun customRangeLabel(from: String, to: String): String =
    when {
        from.isNotBlank() && to.isNotBlank() -> "$from → $to"
        from.isNotBlank() -> "$from →"
        to.isNotBlank() -> "→ $to"
        else -> ""
    }

/** UTC ISO-8601 (OData datetime filtresi için). */
private fun isoUtc(date: java.util.Date): String {
    val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US)
    fmt.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return fmt.format(date)
}

/** BC datetime metnini kısa yerel gösterime çevirir (gün.ay saat:dk). */
private fun friendlyDateTime(iso: String): String {
    if (iso.isBlank()) return "—"
    return try {
        val parsers = listOf("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ssXXX")
        var parsed: java.util.Date? = null
        for (p in parsers) {
            try {
                val f = java.text.SimpleDateFormat(p, java.util.Locale.US)
                f.timeZone = java.util.TimeZone.getTimeZone("UTC")
                parsed = f.parse(iso); break
            } catch (_: Exception) {}
        }
        if (parsed == null) iso
        else java.text.SimpleDateFormat("dd.MM HH:mm", java.util.Locale.US).format(parsed)
    } catch (_: Exception) { iso }
}

/**
 * Yeni yönlendirmeli toplama: sistem sıradaki rafı söyler, raf doğrulanmadan
 * ürünleri göstermez. Raf içindeki ürünler okutulunca otomatik olarak sonraki
 * rafa geçer; bütün raflar bitmeden pick post edilemez.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GuidedPickDocument(no: String, flowMode: OutboundFlowMode? = null, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var headerLoaded by remember { mutableStateOf(false) }
    var linesComplete by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var binVerified by remember { mutableStateOf(false) }
    // ELOG: "ürüne dokunma, direkt okut" — görünür okut alanının metni.
    var scanInput by remember { mutableStateOf("") }
    // ELOG ana LP (toplama kabı): her pick için 1 sepet. Okutulmadan/oluşturulmadan
    // toplamaya başlanamaz — tüm ürünler bu LP'ye gider (shipping LP).
    var mainLp by remember { mutableStateOf("") }
    // Sistem sepeti üretilirken operatör beklemesin: iyimser olarak kapı açılır,
    // gerçek LP numarası gelince başlıkta güncellenir.
    var mainLpPending by remember { mutableStateOf(false) }
    // BC'ye yazımı süren satırlar — aynı satırın iki kez gönderilmesini engeller.
    var inFlightLines by remember { mutableStateOf<Set<Int>>(emptySet()) }
    var lpInput by remember { mutableStateOf("") }
    // ELOG: ana sepet ekranında varsayılan olarak "önerilen sepeti kullan" öne çıkar;
    // kullanıcı kendi kabını okutmak isterse bu bayrakla scan alanı açılır.
    var showLpScan by remember { mutableStateOf(false) }
    // ELOG: aynı ürün bu rafta birden çok satırda/siparişte ise tek okutmada miktar
    // popup'ı aç (ör. BN.0353 ×4, 2 siparişte 2+2) — 4 kere okutma yok, 1 kez okut,
    // "istenen 4" görüp gir → satırlara dağıt. qtyGroup dolunca dialog açılır.
    var qtyGroup by remember { mutableStateOf<LineGroup?>(null) }
    // Tek satırlı ürün okutulunca çıkan onay kartı (grup + okutulan lot).
    var confirmGroup by remember { mutableStateOf<Pair<LineGroup, String>?>(null) }
    // Belge başkasına atanmışsa toplamayı kilitlemek için oturum kullanıcısı.
    var myUserId by remember { mutableStateOf("") }

    fun canSafelyMutateNow(): Boolean =
        headerLoaded && linesComplete &&
            canMutateAssignedPick(header?.optString("assignedUserId").orEmpty(), myUserId)

    fun isComplete(line: JSONObject): Boolean {
        val required = line.optDouble("quantity", 0.0)
        return required > 0 && line.optDouble("qtyToHandle", 0.0) >= required
    }

    suspend fun reloadNow() {
        // Eski/eksik veriyle işlem yapılmasın. Başlık veya satırların herhangi
        // bir sayfası alınamazsa ekran salt okunur kalır.
        headerLoaded = false
        linesComplete = false
        header = null
        lines = emptyList()
        // Başlık ve satırlar bağımsız — PARALEL çek (sırayla iki tur beklemek
        // belge açılışını ve her yenilemeyi gereksiz yavaşlatıyordu).
        coroutineScope {
            val headerJob = async { BcApi.get(context, "picks('$no')") }
            val linesJob = async {
                BcApi.getAllPages(context, "pickLines?\$filter=no eq '$no'&\$top=500")
            }
            val h = headerJob.await()
            if (h.ok) {
                val parsed = runCatching { JSONObject(h.body) }.getOrNull()
                if (parsed != null) {
                    header = parsed
                    headerLoaded = true
                    // Kayıtlı ana sepeti geri yükle — ekrandan çıkıp girince
                    // sepetin sıfırlanmasının önüne geçer.
                    val saved = parsed.optString("mainLpNo")
                    if (saved.isNotBlank() && mainLp.isBlank()) mainLp = saved
                }
            }
            val l = linesJob.await()
            lines = l.rows
            linesComplete = l.complete
            status = when {
                !headerLoaded -> "HATA: Toplama belgesi alınamadı. Yenileyip tekrar deneyin."
                !linesComplete -> "HATA: Toplama satırlarının tamamı alınamadı. Yenileyip tekrar deneyin."
                else -> status
            }
        }
    }

    fun reload() {
        scope.launch {
            busy = true
            reloadNow()
            busy = false
        }
    }

    fun assignToMe() {
        scope.launch {
            if (!headerLoaded || !linesComplete) {
                status = "HATA: Belge tamamen yüklenmeden atama yapılamaz. Yenileyin."
                return@launch
            }
            busy = true
            status = "Kendinize atanıyor..."
            val me = BcApi.currentUserId(context)
            if (me.isBlank()) {
                status = "HATA: Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
                busy = false
                return@launch
            }
            val r = BcApi.boundAction(
                context, "picks", no, "reassign",
                JSONObject().apply { put("userId", me); put("reason", "terminalden kendime atadım") }.toString(),
            )
            status = if (r.ok) "✅ Pick kendinize atandı" else "HATA: ${BcApi.errorMessage(r.body)}"
            if (r.ok) myUserId = me
            reloadNow()
            busy = false
        }
    }

    // ELOG ana sepet: okutulan LP'yi bu pick'in toplama kabı yap. Boş okutulursa
    // sistem otomatik bir shipping LP üretir (startShippingLP). LP header'a bağlanır.
    /** LP'yi sunucuda doğrula ve pick başlığına kalıcı bağla. İki adım da
     * başarılı olmadan ürün okutma kapısı açılmaz. */
    suspend fun validateAndPersistMainLp(lp: String): String? {
        if (lp.isBlank()) return "Geçerli bir sepet numarası alınamadı."
        val safeLp = lp.replace("'", "''")
        val validation = BcApi.get(context, "licensePlates('$safeLp')")
        if (!validation.ok) return "Sepet bulunamadı veya doğrulanamadı."
        val lpHeader = runCatching { JSONObject(validation.body) }.getOrNull()
            ?: return "Sepet bilgisi okunamadı."
        if (!isPickContainerStatusUsable(lpHeader.optString("status")))
            return "Bu sepet açık değil. Başka bir sepet seçin."

        val persisted = BcApi.patch(
            context,
            "picks('${no.replace("'", "''")}')",
            JSONObject().apply { put("mainLpNo", lp) }.toString(),
        )
        return if (persisted.ok) null else "Sepet toplama belgesine bağlanamadı. Yenileyip tekrar deneyin."
    }

    fun startMainLp(scannedLp: String) {
        if (!canSafelyMutateNow()) {
            status = if (!headerLoaded || !linesComplete)
                "HATA: Belge tamamen yüklenmedi. Yenileyip tekrar deneyin."
            else "HATA: Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
            return
        }
        val lp = com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(scannedLp).value.trim()
        if (mainLpPending) return
        mainLpPending = true
        mainLp = ""
        status = if (lp.isNotBlank()) "📦 Sepet doğrulanıyor…" else "📦 Ana sepet hazırlanıyor…"
        scope.launch {
            val candidate = if (lp.isNotBlank()) lp else {
                val template = resolveLpTemplate(context, LpPurpose.PALLET)
                if (template == null) {
                    status = "HATA: Uygun palet şablonu belirlenemedi. Mevcut bir LP okutun veya LP ekranından şablon seçerek oluşturun."
                    mainLpPending = false
                    return@launch
                }
                val r = BcApi.boundAction(
                    context, "picks", no, "startShippingLP",
                    JSONObject().apply { put("lpTemplateCode", template) }.toString(),
                )
                if (!r.ok) {
                    status = QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                    ""
                } else BcApi.scalarValue(r.body).trim()
            }
            if (candidate.isNotBlank()) {
                val validationError = validateAndPersistMainLp(candidate)
                if (validationError == null) {
                    mainLp = candidate
                    lpInput = ""
                    showLpScan = false
                    status = "📦 Ana sepet: $candidate — toplamaya başlayın"
                } else {
                    mainLp = ""
                    status = "HATA: $validationError"
                }
            }
            mainLpPending = false
        }
    }

    /**
     * Satırı tamamla. İYİMSER: okutma anında satır yerel olarak "toplandı"
     * işaretlenir ve ekran açık kalır (operatör beklemeden sonrakine geçer).
     * BC yazımı arka planda gider; hata olursa yerel işaret geri alınır.
     */
    fun completeLine(line: JSONObject, lotNo: String = "") {
        if (!canSafelyMutateNow()) {
            status = if (!headerLoaded || !linesComplete)
                "HATA: Toplama satırları eksik. Yenileyip tekrar deneyin."
            else "HATA: Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
            return
        }
        if (isComplete(line)) return
        val lineNo = line.optInt("lineNo")
        if (lineNo in inFlightLines) return
        val itemNo = line.optString("itemNo")
        val qty = line.optDouble("quantity")
        // 1) Anında yerel tamamlama — UI hemen tepki verir.
        inFlightLines = inFlightLines + lineNo
        lines = lines.map { l ->
            if (l.optInt("lineNo") == lineNo) cloneWithQtyHandled(l, qty) else l
        }
        status = "✅ $itemNo tamamlandı"
        // 2) BC'ye arka planda yaz.
        scope.launch {
            val effectiveLot = lotNo.ifBlank { line.optString("lotNo") }
            val r = BcApi.confirmPickLine(context, no, lineNo, qty, effectiveLot)
            if (!r.ok) {
                // Geri al + gerçek durumu tazele.
                status = QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                reloadNow()
            }
            inFlightLines = inFlightLines - lineNo
        }
    }

    // ELOG: aynı üründen bu rafta birden çok açık satır varsa, girilen toplam
    // miktarı satırlara (outstanding'e göre) dağıt. Tek okutma → tek miktar girişi.
    /** Grup dağıtımı iyimser görünür; sunucu yazımları deadlock oluşmaması için seri gider. */
    fun completeGroup(group: LineGroup, totalQty: Double, lotNo: String) {
        if (!canSafelyMutateNow()) {
            status = if (!headerLoaded || !linesComplete)
                "HATA: Toplama satırları eksik. Yenileyip tekrar deneyin."
            else "HATA: Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
            return
        }
        val plan = distributeQty(group, totalQty, ::pickLineCapacity)
        if (plan.isEmpty()) return

        // 1) Anında yerel tamamlama.
        val planned = plan.associate { (ln, q) -> ln.optInt("lineNo") to q }
        inFlightLines = inFlightLines + planned.keys
        lines = lines.map { l ->
            val q = planned[l.optInt("lineNo")]
            if (q != null) cloneWithQtyHandled(l, q) else l
        }
        status = "✅ ${group.itemNo} → ${plan.size} siparişe dağıtıldı (${pickQty(totalQty)} adet)"

        // 2) BC'ye seri ve sınırlı retry ile yaz. Aynı pick tablosundaki paralel
        // PATCH'ler sahada deadlock üretip 1/2 satır yazılmış bırakıyordu.
        scope.launch {
            var okCount = 0
            var firstFailure: BcApi.ApiResult? = null
            for ((ln, q) in plan) {
                val effectiveLot = lotNo.ifBlank { ln.optString("lotNo") }
                val result = BcApi.confirmPickLine(context, no, ln.optInt("lineNo"), q, effectiveLot)
                if (result.ok) okCount++ else {
                    firstFailure = result
                    break
                }
            }
            if (firstFailure != null) {
                status = "HATA: $okCount/${plan.size} satır yazıldı — ${BcApi.errorMessage(firstFailure.body)}"
                reloadNow()   // iyimser değişikliği geri al
            }
            inFlightLines = inFlightLines - planned.keys
        }
    }

    // Ürün okutma yönlendirmesi: bu rafta aynı üründen ÇOK açık satır varsa miktar
    // popup'ı aç (dağıtım); tek satır varsa doğrudan tamamla. openLines = o an
    // açık aktif-raf satırları (çağıran verir — activeLines composable'da sonra tanımlı).
    fun handleItemScan(openLines: List<JSONObject>, itemNo: String, lotNo: String, serialNo: String = "") {
        val selection = selectScannedLineGroup(
            groups = groupLines(openLines, ::pickLineCapacity),
            itemNo = itemNo,
            lotNo = lotNo,
            serialNo = serialNo,
        )
        val group = selection.group
        when {
            selection.issue == ScannedGroupIssue.ItemMissing ->
                status = "⚠️ Bu rafta açık $itemNo satırı yok"
            selection.issue == ScannedGroupIssue.TrackingMismatch ->
                status = "HATA: Okutulan lot/seri bu ürünün açık toplama satırıyla eşleşmiyor."
            selection.issue == ScannedGroupIssue.Ambiguous ->
                status = "HATA: Bu ürün birden fazla lot/seri satırında. Lot veya seri barkodunu okutun."
            group == null -> status = "HATA: Toplama satırı seçilemedi. Yenileyip tekrar deneyin."
            // Çok satır → miktar dağıtım dialogu (operatör toplamı girer).
            group.count > 1 -> qtyGroup = group
            // Tek satır → ONAY kartı: kaç adet alınacağı büyük puntoyla gösterilir.
            // Eskiden sessizce tamamlanıyordu, operatör sepete kaç koyacağını
            // ekranda göremiyordu.
            else -> confirmGroup = group to lotNo
        }
    }

    fun registerPick() {
        val registerTakeLines = lines.filter { !it.optString("actionType").equals("Place", ignoreCase = true) }
        val registerAllCollected = headerLoaded && linesComplete &&
            registerTakeLines.isNotEmpty() && registerTakeLines.all(::isComplete)
        if (!canRegisterAssignedPick(
                header?.optString("assignedUserId").orEmpty(),
                myUserId,
                registerAllCollected,
                inFlightLines.size,
            )
        ) {
            status = when {
                !headerLoaded || !linesComplete -> "Belge tamamen yüklenmedi. Yenileyip tekrar deneyin."
                myUserId.isBlank() -> "HATA: Depo kullanıcısı doğrulanamadı. Yeniden giriş yapın."
                inFlightLines.isNotEmpty() -> "Ürün kayıtları tamamlanıyor. Lütfen bekleyin."
                !registerAllCollected -> "Önce tüm ürünleri toplayın."
                else -> "Bu toplamayı kaydetme yetkiniz yok."
            }
            return
        }
        scope.launch {
            busy = true
            status = "Toplama kaydediliyor..."
            val r = BcApi.registerPick(context, no)
            busy = false
            if (r.ok) {
                status = "✅ Toplama tamamlandı; siparişler paketlemeye aktarıldı"
                onBack()
            } else status = QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
        }
    }

    LaunchedEffect(no) { busy = true; reloadNow(); busy = false }
    LaunchedEffect(Unit) { myUserId = BcApi.currentUserId(context) }

    val takeLines = lines.filter { !it.optString("actionType").equals("Place", ignoreCase = true) }
    val outstanding = takeLines.filterNot(::isComplete)
    val currentBin = outstanding.sortedWith(compareBy(binWalkComparator) { it.optString("binCode") })
        .firstOrNull()?.optString("binCode")
    val activeLines = takeLines.filter { it.optString("binCode").equals(currentBin, ignoreCase = true) }
    val allCollected = headerLoaded && linesComplete && takeLines.isNotEmpty() && outstanding.isEmpty()
    val orderCount = takeLines.map { rawValue(it, "sourceNo").ifBlank { "—" } }.distinct().size
    val assignedTo = header?.optString("assignedUserId").orEmpty()
    val notAssigned = headerLoaded && assignedTo.isBlank()
    // Belge başkasına atanmış: liste ekranındaki uyarıya rağmen açıldıysa burada
    // toplama kilitli kalır — iki kişinin aynı pick'i toplaması miktarları bozar.
    // Kimlik çözülemediyse ayrı bir güvenli kilit gösterilir; mutasyonlar açılmaz.
    val lockedByOther = pickOwnerOf(assignedTo, myUserId) == PickOwner.Other
    val identityUnresolved = assignedTo.isNotBlank() && myUserId.isBlank()
    val canMutate = headerLoaded && linesComplete && canMutateAssignedPick(assignedTo, myUserId)

    LaunchedEffect(currentBin) {
        binVerified = currentBin.isNullOrBlank()
        if (currentBin != null && !currentBin.isBlank())
            status = "📍 Sıradaki raf: $currentBin — raf barkodunu okutun"
    }

    // Arka plan donanım-tarayıcı dinleyicisi: hem raf doğrulama (onNoMatch) hem
    // ürün okutma (onSingleMatch) burada işlenir — operatör görünür alana dokunmak
    // zorunda kalmadan sarı tetikle okutabilsin. Görünür "📷 Ürün okut" alanı ise
    // elle giriş + kamera içindir (focuslu iken donanımı da işler; tamamlanmış
    // satır ikinci kez okununca zararsızca "açık satır yok" der).
    val needsMainLp = (mainLp.isBlank() || mainLpPending) && canMutate
    DocumentScanHandler(
        // `busy` artık okutmayı engellemiyor: satır tamamlama iyimser çalışıyor,
        // operatör arka plandaki BC yazımını beklemeden sonraki ürüne geçebilir.
        enabled = canMutate && !allCollected && !needsMainLp && qtyGroup == null && confirmGroup == null,
        lines = if (binVerified) activeLines.filterNot(::isComplete) else emptyList(),
        // Tek eşleşme de olsa handleItemScan'e ver — o ürünün rafta çok satırı varsa
        // miktar popup'ı açar (BN.0353 ×4 = 2 sipariş → 1 okut, 4 gir).
        onSingleMatch = { line, resolved -> handleItemScan(activeLines.filterNot(::isComplete), line.optString("itemNo"), resolved.lotNo.orEmpty(), resolved.serialNo.orEmpty()) },
        onMultiMatch = { itemNo, resolved -> handleItemScan(activeLines.filterNot(::isComplete), itemNo, resolved.lotNo.orEmpty(), resolved.serialNo.orEmpty()) },
        onNoMatch = { resolved ->
            val scanned = resolved.value.trim()
            if (!binVerified && !currentBin.isNullOrBlank() && scanned.equals(currentBin, ignoreCase = true)) {
                binVerified = true
                status = "✅ Raf $currentBin doğrulandı — aşağıdaki ürüne dokunup okutun"
            } else if (!binVerified) {
                status = "❌ Yanlış raf. Beklenen: $currentBin · Okunan: $scanned"
            } else {
                status = "❌ Bu ürün $currentBin rafında beklenmiyor: ${resolved.itemNo ?: scanned}"
            }
        },
    )

    Column(Modifier.fillMaxSize()) {
        // Belge başlığından ürün kartlarının sonuna kadar TEK kaydırma alanı.
        // Önceden yalnız satır LazyColumn'u kayıyor, üstteki başlık/LP/okutma
        // alanları sabit kalıyordu; küçük ekranda kullanılabilir alan daralıyordu.
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(12.dp),
        ) {
            TextButton(onClick = onBack) { Text("‹ Pick Listesi") }
            if (flowMode != null) {
                V2PickFlowBanner(flowMode)
                Spacer(Modifier.height(8.dp))
            }
            // Başlık özeti: kaç sipariş, kaç ürün (tamamlanan/toplam) — operatör
            // daha ilk bakışta işin büyüklüğünü görsün.
            val doneCount = takeLines.count(::isComplete)
            DocHeaderCard(
                title = no,
                subtitle = "📦 $orderCount sipariş · 🧾 $doneCount/${takeLines.size} ürün" +
                    "\nLokasyon: ${header?.optString("locationCode").orEmpty()}" +
                    (if (!notAssigned) " · 👤 Atanan Kullanıcı: $assignedTo" else "") +
                    (if (mainLp.isNotBlank()) "\n📦 Ana sepet: $mainLp" else ""),
                percent = if (takeLines.isEmpty()) 0 else ((doneCount * 100.0) / takeLines.size).toInt(),
            )
            Spacer(Modifier.height(8.dp))

            StatusText(status)
            Spacer(Modifier.height(8.dp))

            when {
                !headerLoaded || !linesComplete -> EmptyState(
                    "Toplama belgesi tamamen yüklenemedi. Yenileyip tekrar deneyin.",
                )
                // ELOG: pick kimseye atanmadan ürün listesi/okutma hiç gösterilmez —
                // toplama sadece "Kendime Ata" ile başlatılabilir.
                notAssigned -> Column {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFEDE7F6)),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Bu pick henüz kimseye atanmadı", fontSize = 14.sp, color = Color(0xFF4527A0))
                            Spacer(Modifier.height(4.dp))
                            Text("Toplamaya başlamak için önce kendinize atayın.", fontSize = 12.sp, color = Color(0xFF5E35B1))
                            Spacer(Modifier.height(14.dp))
                            Button(
                                onClick = { assignToMe() },
                                enabled = !busy && !mainLpPending,
                                modifier = Modifier.fillMaxWidth().height(50.dp),
                            ) { Text("✋ Kendime Ata ve Toplamaya Başla", fontWeight = FontWeight.Bold) }
                        }
                    }
                }
                // Başkasına atanmış belge: salt görüntüleme. Toplamak isteyen
                // önce açıkça devralmalı — sessizce ortak toplama yapılamaz.
                identityUnresolved -> Column {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0)),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Depo kullanıcısı doğrulanamadı", fontWeight = FontWeight.Bold, color = Color(0xFFB45309))
                            Spacer(Modifier.height(4.dp))
                            Text("Güvenli devam etmek için yeniden giriş yapın.", fontSize = 12.sp, color = Color(0xFF92400E))
                        }
                    }
                }
                lockedByOther -> Column {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFFEBEE)),
                        border = BorderStroke(1.dp, OtherUserRed.copy(alpha = 0.5f)),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Bu toplama $assignedTo kullanıcısında", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = OtherUserRed)
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "Salt görüntüleme. Aynı pick'i iki kişi toplarsa miktarlar çakışır. " +
                                    "Toplamayı siz sürdürecekseniz işi devralın; değilse listeye dönün.",
                                fontSize = 12.sp, color = Color(0xFF8E2B2B),
                            )
                            Spacer(Modifier.height(14.dp))
                            Button(
                                onClick = { assignToMe() },
                                enabled = !busy && myUserId.isNotBlank(),
                                modifier = Modifier.fillMaxWidth().height(50.dp),
                            ) { Text("Devral ve Toplamaya Başla", fontWeight = FontWeight.Bold) }
                            Spacer(Modifier.height(6.dp))
                            TextButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("‹ Listeye dön", fontSize = 12.sp) }
                        }
                    }
                }
                // ELOG: atandıktan sonra, toplamadan ÖNCE ana sepeti (LP) okut.
                needsMainLp -> Column {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, Color(0xFFE0E0E0)),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(16.dp)) {
                            Text("Toplama kabı (sepet)", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(
                                "Ürünler bu sepete toplanacak. Sistem senin için bir sepet önerdi — kullanabilir ya da elindeki sepeti okutabilirsin.",
                                fontSize = 12.sp, color = Color.Gray,
                            )
                            Spacer(Modifier.height(14.dp))

                            // Önerilen sepet kartı — sistem toplama başlarken numara üretir.
                            Card(
                                colors = CardDefaults.cardColors(containerColor = Color(0xFFEDE7F6)),
                                border = BorderStroke(1.dp, PickAccent.copy(alpha = 0.4f)),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text("📦", fontSize = 26.sp)
                                    Spacer(Modifier.width(12.dp))
                                    Column(Modifier.weight(1f)) {
                                        Text("Önerilen sepet", fontSize = 11.sp, color = Color(0xFF5E35B1))
                                        Text("Yeni sepet oluşturulacak", fontWeight = FontWeight.Bold, color = Color(0xFF4527A0))
                                        Text("Onaylayınca sepet numarası atanır", fontSize = 11.sp, color = Color(0xFF7E57C2))
                                    }
                                }
                            }
                            Spacer(Modifier.height(12.dp))
                            Button(
                                onClick = { startMainLp("") },
                                enabled = !busy && canMutate,
                                modifier = Modifier.fillMaxWidth().height(50.dp),
                            ) { Text("✓ Önerilen sepeti kullan", fontWeight = FontWeight.Bold) }

                            Spacer(Modifier.height(10.dp))
                            if (!showLpScan) {
                                TextButton(
                                    onClick = { showLpScan = true },
                                    enabled = !busy && !mainLpPending && canMutate,
                                    modifier = Modifier.fillMaxWidth(),
                                ) { WmsActionLabel(WmsGlyph.SCAN, "Farklı bir sepet okut / değiştir") }
                            } else {
                                Text("Elindeki sepetin/LP barkodunu okut:", fontSize = 12.sp, color = Color.Gray)
                                Spacer(Modifier.height(6.dp))
                                com.dynops.bcwms.scanner.ScanField(
                                    label = "📦 Sepet / LP okut",
                                    value = lpInput,
                                    onValueChange = { lpInput = it },
                                    modifier = Modifier.fillMaxWidth(),
                                    enabled = !busy && !mainLpPending && canMutate,
                                    onScanned = { startMainLp(it) },
                                )
                                Spacer(Modifier.height(6.dp))
                                TextButton(
                                    onClick = { showLpScan = false; lpInput = "" },
                                    enabled = !busy && !mainLpPending && canMutate,
                                    modifier = Modifier.fillMaxWidth(),
                                ) { Text("‹ Vazgeç, öneriye dön", fontSize = 12.sp) }
                            }
                        }
                    }
                }
                allCollected -> Column {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F5E9)),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(Modifier.padding(18.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("✅ TÜM SİPARİŞLER TOPLANDI", color = Color(0xFF2E7D32), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            Text("Pick'i post ederek paketleme kuyruğuna bırakın.", color = Color(0xFF2E7D32), fontSize = 12.sp)
                        }
                    }
                }
                !binVerified && !currentBin.isNullOrBlank() -> Column {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF3E0)),
                        border = BorderStroke(2.dp, Color(0xFFEF6C00)),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("SIRADAKİ RAF", fontSize = 12.sp, color = Color(0xFFEF6C00), fontWeight = FontWeight.Bold)
                            Text(currentBin, fontSize = 32.sp, fontWeight = FontWeight.Black, color = Color(0xFFBF360C))
                            Text("Bu rafın barkodunu okutun", fontSize = 14.sp, color = Color(0xFFEF6C00))
                        }
                    }
                }
                else -> {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                if (currentBin.isNullOrBlank()) "📦 Toplanacak ürünler" else "📍 Bu rafın ürünleri",
                                fontSize = 12.sp, color = Color.Gray,
                            )
                            if (!currentBin.isNullOrBlank())
                                Text(currentBin, fontSize = 20.sp, fontWeight = FontWeight.Black, color = Color(0xFFBF360C))
                        }
                        Surface(color = PickAccent.copy(alpha = 0.12f), shape = RoundedCornerShape(8.dp)) {
                            Text(
                                "${activeLines.count(::isComplete)}/${activeLines.size}",
                                Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                fontWeight = FontWeight.Bold, fontSize = 14.sp, color = PickAccent,
                            )
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    // ELOG: dokunmadan direkt okut. Sadece barkod okutarak toplanır —
                    // manuel/"elle" giriş yok, yanlış ürün karışmasın diye kaldırıldı.
                    com.dynops.bcwms.scanner.ScanField(
                        label = "📷 Ürün okut",
                        value = scanInput,
                        onValueChange = { scanInput = it },
                        modifier = Modifier.fillMaxWidth(),
                        // Onay/miktar kartı açıkken okutma kapalı: arkadan gelen
                        // ikinci okutma açık kartı sessizce ezmesin.
                        enabled = canMutate && qtyGroup == null && confirmGroup == null,
                        onScanned = { raw ->
                            scanInput = ""
                            val resolved = com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(raw)
                            val open = activeLines.filterNot(::isComplete)
                            val match = matchLinesByBarcode(open, resolved)
                            // Eşleşen satırın ürününü handleItemScan'e ver → aynı üründen
                            // çok satır varsa miktar popup'ı açılır, tek satırsa tamamlanır.
                            if (match.isNotEmpty()) handleItemScan(open, match.first().optString("itemNo"), resolved.lotNo.orEmpty(), resolved.serialNo.orEmpty())
                            else status = "❌ Bu rafta açık '${resolved.itemNo ?: raw}' satırı yok"
                        },
                    )
                    Spacer(Modifier.height(12.dp))
                    // ELOG: satırları ÜRÜNE göre grupla (item+bin+varyant+lot/seri) —
                    // aynı ürün N farklı siparişte varsa TEK kart, büyük toplam miktar,
                    // altında hangi siparişlere ait olduğu küçük gri yazıyla listelenir.
                    // Kartlar sadece bilgi amaçlıdır — toplama SADECE barkod okutarak
                    // yapılır, dokunarak tamamlama/elle giriş yolu yok.
                    val itemGroups = groupLines(activeLines, ::pickLineCapacity)
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        itemGroups.forEach { group ->
                            val done = group.lines.all(::isComplete)
                            val doneCount = group.lines.count(::isComplete)
                            val orderNos = group.lines.map { rawValue(it, "sourceNo").ifBlank { "—" } }.distinct()
                            Card(
                                // ELOG: henüz toplanmamış (bekleyen) satırlar hafif kırmızı/pembe
                                // zeminde belirginleşsin; toplananlar yeşile döner.
                                colors = CardDefaults.cardColors(containerColor = if (done) Color(0xFFE8F5E9) else Color(0xFFFFF0F0)),
                                border = BorderStroke(1.dp, if (done) Color(0xFF66BB6A) else Color(0xFFF3BDBD)),
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text(if (done) "✅" else "📦", fontSize = 20.sp)
                                    Spacer(Modifier.width(10.dp))
                                    Column(Modifier.weight(1f)) {
                                        Text(group.itemNo, fontWeight = FontWeight.Bold)
                                        Text(group.description, fontSize = 12.sp, color = Color.Gray)
                                        if (group.binCode.isNotBlank()) {
                                            Spacer(Modifier.height(2.dp))
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Surface(color = Color(0xFFF3E5F5), shape = RoundedCornerShape(6.dp)) {
                                                    Text(
                                                        "📍 ${group.binCode}",
                                                        Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                        fontSize = 11.sp, color = Color(0xFF6A1B9A), fontWeight = FontWeight.Medium,
                                                    )
                                                }
                                            }
                                        }
                                        if (group.count > 1) {
                                            Spacer(Modifier.height(2.dp))
                                            Text(
                                                "🧾 ${orderNos.size} siparişe dağılıyor: ${orderNos.joinToString(" · ")}",
                                                fontSize = 11.sp, color = Color.Gray,
                                            )
                                        } else {
                                            Text("Sipariş: ${orderNos.first()}", fontSize = 11.sp, color = Color.Gray)
                                        }
                                    }
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        pickQty(group.lines.sumOf { it.optDouble("quantity") }),
                                        fontSize = 28.sp, fontWeight = FontWeight.Black,
                                        color = if (done) Color(0xFF2E7D32) else PickAccent,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        BottomActionBar {
            OutlinedButton(onClick = { reload() }, enabled = !busy, modifier = Modifier.weight(1f)) {
                WmsActionLabel(WmsGlyph.ENTRIES, "Yenile")
            }
            Button(
                onClick = { registerPick() },
                // Başkasının pick'i post edilemez — önce devralınmalı.
                enabled = !busy && canRegisterAssignedPick(assignedTo, myUserId, allCollected, inFlightLines.size),
                modifier = Modifier.weight(2f).height(54.dp),
            ) {
                Text(
                    when {
                        identityUnresolved -> "Yeniden Giriş Gerekli"
                        lockedByOther -> "Önce Devralın"
                        inFlightLines.isNotEmpty() -> "Kayıtlar Tamamlanıyor"
                        allCollected -> "✅ Pick'i Post Et"
                        else -> "Önce Tümünü Topla"
                    },
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }

    // ELOG miktar popup'ı: aynı ürün bu rafta çok satır/siparişte → "istenen 4"
    // göster, operatör miktarı girsin, satırlara dağıt.
    val qg = qtyGroup
    if (qg != null) {
        QuantityDialogSheet(
            title = "${qg.itemNo} — ${qg.count} siparişe dağıtılır",
            itemNo = qg.itemNo,
            initialQty = qg.totalOutstanding.takeIf { it > 0 } ?: 1.0,
            initialUom = qg.lines.first().optString("unitOfMeasureCode"),
            initialLot = qg.lines.first().optString("lotNo"),
            showLotSerial = true,
            showSerial = false,
            lotRequired = qg.lines.any { it.optBoolean("lotRequired", false) },
            showAvailableLotLookup = true,
            autoDetectLotFromStock = true,
            locationCode = rawValue(qg.lines.first(), "locationCode"),
            variantCode = qg.lines.first().optString("variantCode"),
            onDismiss = { qtyGroup = null },
            onConfirm = { res ->
                qtyGroup = null
                completeGroup(qg, res.quantity, res.lotNo)
            },
        )
    }

    // Tek satırlı ürün okutuldu → sepete KAÇ ADET koyacağını göster, onaylat.
    val cg = confirmGroup
    if (cg != null) {
        PickConfirmSheet(
            group = cg.first,
            onDismiss = { confirmGroup = null },
            onConfirm = {
                val g = cg.first
                val lot = cg.second
                confirmGroup = null
                completeLine(g.lines.first(), lot)
            },
        )
    }
}

@Composable
private fun V2PickFlowBanner(flow: OutboundFlowMode) {
    val instruction = when (flow) {
        OutboundFlowMode.Multi -> "Raf rotasını izle; aynı ürün farklı siparişlerdeyse toplam miktarı tek okumada dağıt."
        OutboundFlowMode.Mono -> "Her ürün tek siparişe gider. Rafı ve ürünü doğrula, siparişi tek adımda tamamla."
        OutboundFlowMode.SingleSku -> "Ortak SKU'yu toplu al; miktar sipariş paylarına otomatik dağıtılır."
    }
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = flow.accent.copy(alpha = 0.11f),
        border = BorderStroke(1.dp, flow.accent.copy(alpha = 0.45f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(flow.icon, fontSize = 22.sp, fontWeight = FontWeight.Black, color = flow.accent)
            Spacer(Modifier.width(10.dp))
            Column {
                Text("${flow.title} toplama", fontWeight = FontWeight.Bold, color = flow.accent)
                Text(instruction, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/**
 * Okutulan ürün için onay kartı: sepete kaç adet konacağı büyük puntoyla,
 * hangi siparişe gittiği ve raf bilgisiyle birlikte. Operatör miktarı görmeden
 * satır kapanmasın diye eklendi.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PickConfirmSheet(
    group: LineGroup,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val line = group.lines.first()
    val qty = group.totalOutstanding.takeIf { it > 0 } ?: line.optDouble("quantity", 1.0)
    val uom = line.optString("unitOfMeasureCode")
    val bin = firstValue(line, "binCode")
    val orderNo = firstValue(line, "sourceNo")
    val lot = line.optString("lotNo")

    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss) {
        Text(group.itemNo, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        val desc = line.optString("description")
        if (desc.isNotBlank())
            Text(desc, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(16.dp))

        // Asıl bilgi: sepete kaç adet.
        Card(
            colors = CardDefaults.cardColors(containerColor = PickAccent.copy(alpha = 0.12f)),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(
                Modifier.fillMaxWidth().padding(vertical = 18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("SEPETE KOY", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = PickAccent)
                Spacer(Modifier.height(6.dp))
                Text(
                    pickQty(qty) + (if (uom.isNotBlank()) " $uom" else ""),
                    fontSize = 40.sp,
                    fontWeight = FontWeight.Black,
                    color = PickAccent,
                )
            }
        }
        Spacer(Modifier.height(14.dp))

        if (bin.isNotBlank()) ConfirmRow("Raf", bin)
        if (orderNo.isNotBlank()) ConfirmRow("Sipariş", orderNo)
        if (lot.isNotBlank()) ConfirmRow("Lot", lot)

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = onConfirm,
            modifier = Modifier.fillMaxWidth().height(54.dp),
        ) { Text("Aldım, devam", fontWeight = FontWeight.Bold, fontSize = 16.sp) }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("Vazgeç") }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun ConfirmRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(label, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(80.dp))
        Text(value, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}

private fun pickQty(value: Double): String =
    if (value == value.toLong().toDouble()) value.toLong().toString() else value.toString()

// Depo yürüme yolu sıralaması: bin kodunu doğal (natural) sırayla karşılaştır.
// Kod içindeki sayı blokları sayısal, harf blokları harf-harf kıyaslanır; böylece
// "A-2" < "A-10" olur (düz String kıyasında A-10 < A-2 olurdu). Boş bin en sona.
private val binWalkComparator: Comparator<String> = Comparator { a, b ->
    if (a.isBlank() != b.isBlank()) return@Comparator if (a.isBlank()) 1 else -1
    val na = a.length; val nb = b.length
    var i = 0; var j = 0
    while (i < na && j < nb) {
        val ca = a[i]; val cb = b[j]
        if (ca.isDigit() && cb.isDigit()) {
            var si = i; while (si < na && a[si].isDigit()) si++
            var sj = j; while (sj < nb && b[sj].isDigit()) sj++
            // Baştaki sıfırları atlayarak sayısal büyüklüğü kıyasla.
            val da = a.substring(i, si).trimStart('0')
            val db = b.substring(j, sj).trimStart('0')
            if (da.length != db.length) return@Comparator da.length - db.length
            val c = da.compareTo(db)
            if (c != 0) return@Comparator c
            i = si; j = sj
        } else {
            val c = ca.uppercaseChar().compareTo(cb.uppercaseChar())
            if (c != 0) return@Comparator c
            i++; j++
        }
    }
    (na - i) - (nb - j)
}

private val PickAccent = Color(0xFF6C5CE7) // Ana menü "Giden" kategorisiyle aynı vurgu.
private val PendingOrange = Color(0xFFE65100)
// Başkasına atanmış işlerin rozeti — turuncudan (boşta) ayrışsın diye kırmızı.
private val OtherUserRed = Color(0xFFC62828)

/** Sahiplik rozeti — metin + renk; ikon yok, okunabilirlik için kısa etiket. */
@Composable
private fun OwnerBadge(text: String, color: Color) {
    Box(
        Modifier.clip(RoundedCornerShape(50)).background(color.copy(alpha = 0.10f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) { Text(text, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = color) }
}

/**
 * Ana menü kart diliyle pick satırı: ilerleme, sahiplik rozeti, Üzerime Al.
 * Rozet HER satırda görünür — özellikle "Tümü" filtresinde işin kimde olduğu
 * karta bakar bakmaz anlaşılsın diye.
 */
@Composable
private fun PickListCard(
    d: JSONObject,
    busy: Boolean,
    owner: PickOwner,
    onOpen: () -> Unit,
    onTake: () -> Unit,
) {
    val assigned = d.optString("assignedUserId").trim()
    val pct = d.optInt("percentComplete").coerceIn(0, 100)
    Card(
        onClick = onOpen,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp, pressedElevation = 4.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clip(RoundedCornerShape(13.dp)).background(PickAccent.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) { Text("🚚", fontSize = 20.sp) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text(d.optString("no"), fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
                Spacer(Modifier.height(2.dp))
                // Atama bilgisi artık alttaki rozette — burada tekrar edilmiyor.
                Text(
                    "📍 ${rawValue(d, "locationCode").ifBlank { "—" }}",
                    fontSize = 11.sp, color = Color.Gray,
                )
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    LinearProgressIndicator(
                        progress = { pct / 100f },
                        modifier = Modifier.weight(1f).height(5.dp).clip(RoundedCornerShape(3.dp)),
                        color = PickAccent,
                    )
                    Spacer(Modifier.width(6.dp))
                    Text("%$pct", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Color.Gray)
                }
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    when (owner) {
                        PickOwner.Unassigned -> OwnerBadge("Atanmamış — üstüne alınabilir", PendingOrange)
                        PickOwner.Mine -> OwnerBadge("Size atanmış", PickAccent)
                        // Başkasının işi: açılmadan önce uyarı çıkacağını da söyler.
                        PickOwner.Other -> OwnerBadge("$assigned kullanıcısında", OtherUserRed)
                        PickOwner.Unknown -> OwnerBadge("Atanan: $assigned", Color.Gray)
                    }
                    Spacer(Modifier.weight(1f))
                    if (owner == PickOwner.Unassigned) {
                        Button(
                            onClick = onTake,
                            enabled = !busy,
                            shape = RoundedCornerShape(50),
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 4.dp),
                            modifier = Modifier.height(34.dp),
                        ) { Text("✋ Üzerime Al", fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PickDocument(no: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var header by remember { mutableStateOf<JSONObject?>(null) }
    var lines by remember { mutableStateOf<List<JSONObject>>(emptyList()) }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var shipLp by remember { mutableStateOf<String?>(null) }
    var showShort by remember { mutableStateOf(false) }
    var shortLine by remember { mutableStateOf<JSONObject?>(null) }
    // PDF Picking §7: scan-and-verify state. Operatör "Tara & Tamamla"ya
    // bastığında scanLine doluyor; ScanVerifySheet açılıyor; barkod
    // okununca itemNo karşılaştırılıp ya tamamlanıyor ya hata gösteriliyor.
    var scanLine by remember { mutableStateOf<JSONObject?>(null) }
    var scanFilter by remember { mutableStateOf("") }
    // Pick sıralama (hafif wave/rota): bin koduna göre en küçükten en büyüğe
    // sırala → toplayıcı depoda tek yönde, gereksiz gidip-gelmeden yürür.
    // ELOG isteği: varsayılan AÇIK.
    var sortByBin by remember { mutableStateOf(true) }
    var columns by remember { mutableStateOf(ColumnPrefs.get(context, "pick", GridColumns.pick)) }
    var showColumns by remember { mutableStateOf(false) }
    var actionLine by remember { mutableStateOf<JSONObject?>(null) }
    var showTote by remember { mutableStateOf(false) }
    // ELOG müşteri isteği: bin+item aynı olan satırları tek satırda göster,
    // girilen miktarı alt satırlara dağıt (bkz. LineGrouping/LineGroupCards).
    var merge by remember { mutableStateOf(false) }
    var groupTarget by remember { mutableStateOf<LineGroup?>(null) }
    // ELOG sepet modu: ürün okutunca satırın siparişine atanmış sepeti öner;
    // sepet okutularak doğrulanır (yoksa okutulan sepet siparişe bağlanır).
    var toteMode by remember { mutableStateOf(false) }
    var toteSuggest by remember { mutableStateOf<Pair<JSONObject, String>?>(null) }
    // ELOG raf modu: raf (bin) barkodu okutulunca liste o rafın satırlarına iner.
    var binFilter by remember { mutableStateOf("") }

    fun reload() {
        scope.launch {
            busy = true
            val h = BcApi.get(context, "picks('$no')")
            if (h.ok) header = JSONObject(h.body)
            val l = BcApi.get(context, "pickLines?\$filter=no eq '$no'&\$top=100")
            lines = if (l.ok) BcApi.parseValueArray(l.body) else emptyList()
            busy = false
        }
    }
    LaunchedEffect(no) { reload() }

    fun action(name: String, body: String, okMsg: String, onResult: (BcApi.ApiResult) -> Unit = {}) {
        scope.launch {
            busy = true; status = "$name..."
            val r = BcApi.boundAction(context, "picks", no, name, body)
            busy = false
            status = if (r.ok) "TAMAM: $okMsg (HTTP ${r.httpCode})"
                else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
            onResult(r)
            if (r.ok) reload()
        }
    }

    fun registerForCurrentUser() {
        scope.launch {
            busy = true
            status = "Toplama kaydediliyor..."
            val r = BcApi.registerPick(context, no)
            busy = false
            status = if (r.ok) "TAMAM: Toplama kaydedildi"
                else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
            if (r.ok) reload()
        }
    }

    fun updateLine(line: JSONObject, qtyHandled: Double) {
        scope.launch {
            busy = true; status = "Satır güncelleniyor..."
            val r = BcApi.confirmPickLine(
                context = context,
                pickNo = no,
                lineNo = line.optInt("lineNo"),
                qtyToHandle = qtyHandled,
                lotNo = line.optString("lotNo"),
            )
            busy = false
            status = if (r.ok) "TAMAM: Satır güncellendi (HTTP ${r.httpCode})"
                else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
            if (r.ok) reload()
        }
    }

    val h = header
    // "Place" satırı gereksiz (hedef bin otomatik) — sadece Take satırlarını göster.
    val takeLines = lines.filter { !it.optString("actionType").equals("Place", ignoreCase = true) }

    // ELOG sepet modu: satırın kaynak siparişine atanmış sepeti BC'den sor;
    // sonuç ToteSuggestSheet'i açar (öneri varsa doğrulat, yoksa bağlat).
    fun requestToteSuggestion(line: JSONObject) {
        scope.launch {
            busy = true; status = "Sepet sorgulanıyor..."
            val src = rawValue(line, "sourceNo")
            val r = BcApi.boundAction(context, "picks", no, "toteForOrder",
                JSONObject().apply { put("sourceOrderNo", src) }.toString())
            busy = false
            val lp = if (r.ok) BcApi.scalarValue(r.body) else ""
            toteSuggest = line to lp
        }
    }

    // Donanım tarayıcı: ürünü okut → tek Take satırı otomatik tamamlanır; çok
    // eşleşme listeyi filtreler. Birleştirme açıkken tek eşleşme grubun miktar
    // dialogunu açar; sepet modunda önce sepet önerisi/doğrulaması gelir.
    // Eşleşmeyen okuma bir raf (bin) barkoduysa liste o rafa filtrelenir
    // (ELOG: "rafı okutuyor, alması gerekenleri görüyor").
    DocumentScanHandler(
        enabled = scanLine == null && !showShort && groupTarget == null && toteSuggest == null && !busy,
        lines = takeLines,
        onSingleMatch = { line, _ ->
            scanFilter = ""
            val g = if (merge) groupLines(takeLines, ::pickLineCapacity)
                .firstOrNull { grp -> grp.lines.any { it.optInt("lineNo") == line.optInt("lineNo") } } else null
            when {
                g != null && g.count > 1 -> groupTarget = g
                toteMode -> requestToteSuggestion(line)
                else -> updateLine(line, line.optDouble("quantity"))
            }
        },
        onMultiMatch = { itemNo, _ -> scanFilter = itemNo; status = "TAMAM: '$itemNo' için birden fazla satır — birini seçin" },
        onNoMatch = { r ->
            val scanned = r.value.trim()
            val bin = takeLines.firstOrNull { it.optString("binCode").equals(scanned, ignoreCase = true) }?.optString("binCode")
            if (!bin.isNullOrBlank()) {
                binFilter = bin
                status = "📍 Raf $bin — bu raftan alınacak satırlar"
            } else status = "⚠️ '${r.itemNo ?: r.value}' bu belgede yok"
        },
    )
    val binLines = if (binFilter.isBlank()) takeLines else takeLines.filter { it.optString("binCode").equals(binFilter, ignoreCase = true) }
    val filteredLines = if (scanFilter.isBlank()) binLines else binLines.filter { matchLinesByBarcode(listOf(it), com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(scanFilter)).isNotEmpty() }
    // En küçükten en büyüğe yürüme yolu: bin kodunu sayısal-akıllı sırala
    // (A-2 < A-10, düz alfabetik sıralamanın aksine).
    val displayLines = if (sortByBin) filteredLines.sortedWith(compareBy(binWalkComparator) { it.optString("binCode") }) else filteredLines
    val displayGroups = if (merge) groupLines(displayLines, ::pickLineCapacity) else emptyList()
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(12.dp)) {
            TextButton(onClick = onBack) { Text("‹ Belge Listesi") }
            DocHeaderCard(
                title = no,
                subtitle = "Lokasyon: ${h?.optString("locationCode") ?: ""} · ${bcStatusLabelTr(h?.optString("status") ?: "")}" +
                    (h?.optString("vehicleNo")?.takeIf { it.isNotBlank() }?.let { "\n🚚 Araç: $it" } ?: "") +
                    (shipLp?.let { "\nShipping LP: $it" } ?: ""),
                percent = h?.optDouble("percentComplete")?.toInt() ?: 0
            )
            Spacer(Modifier.height(6.dp))
            StatusText(status)
            if (status.startsWith("🔬")) {
                val navigator = com.dynops.bcwms.LocalNavigator.current
                Spacer(Modifier.height(4.dp))
                OutlinedButton(onClick = { navigator(com.dynops.bcwms.Screen.QualityMgmt) }) {
                    Text("🧫 MS Quality Mgmt'i Aç", fontWeight = FontWeight.Medium)
                }
            }
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(if (merge) "Gruplar (${displayGroups.size})" else "Satırlar (${displayLines.size}/${takeLines.size})", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.weight(1f))
                FilterChip(selected = toteMode, onClick = { toteMode = !toteMode }, label = { Text("🧺", fontSize = 12.sp) })
                FilterChip(selected = merge, onClick = { merge = !merge }, label = { Text("🔗 Birleştir", fontSize = 12.sp) })
                FilterChip(selected = sortByBin, onClick = { sortByBin = !sortByBin }, label = { Text("🧭 Bin", fontSize = 12.sp) })
                if (!merge) { TextButton(onClick = { showColumns = true }) { WmsActionLabel(WmsGlyph.FIELD_SETTINGS, "Kolonlar") } }
            }
            if (binFilter.isNotBlank()) { ScanFilterChip("📍 Raf $binFilter") { binFilter = "" }; Spacer(Modifier.height(4.dp)) }
            if (scanFilter.isNotBlank()) { ScanFilterChip(scanFilter) { scanFilter = "" }; Spacer(Modifier.height(4.dp)) }
            if (merge) {
                LineGroupCards(
                    groups = displayGroups,
                    staged = { it.optDouble("qtyToHandle", 0.0) },
                    modifier = Modifier.fillMaxWidth(),
                    expandRows = true,
                    onGroupClick = { if (!busy) groupTarget = it },
                )
            } else {
                LineGrid(
                    defs = GridColumns.pick, columns = columns, rows = displayLines,
                    modifier = Modifier.fillMaxWidth(),
                    isDone = { lineDone(it, LineModule.PICK) },
                    isPartial = { linePartial(it, LineModule.PICK) },
                    expandRows = true,
                    onRowClick = { if (!busy) actionLine = it },
                )
            }
        }

        BottomActionBar {
            if (shipLp == null) {
                OutlinedButton(onClick = {
                    scope.launch {
                        busy = true
                        status = "Uygun palet şablonu belirleniyor..."
                        val template = resolveLpTemplate(context, LpPurpose.PALLET)
                        if (template == null) {
                            status = "HATA: Uygun palet şablonu belirlenemedi. LP ekranından şablon seçerek bir LP oluşturun."
                            busy = false
                            return@launch
                        }
                        val r = BcApi.boundAction(
                            context, "picks", no, "startShippingLP",
                            JSONObject().apply { put("lpTemplateCode", template) }.toString(),
                        )
                        val createdLp = if (r.ok) BcApi.scalarValue(r.body).trim() else ""
                        status = when {
                            !r.ok -> QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                            createdLp.isBlank() -> "HATA: LP oluşturuldu ancak numarası alınamadı. Belgeyi yenileyip kontrol edin."
                            else -> "TAMAM: $createdLp başlatıldı"
                        }
                        if (createdLp.isNotBlank()) shipLp = createdLp
                        busy = false
                        if (createdLp.isNotBlank()) reload()
                    }
                }, enabled = !busy, modifier = Modifier.weight(1f)) { Text("LP Başlat") }
                OutlinedButton(onClick = { showTote = true }, enabled = !busy, modifier = Modifier.weight(1f)) { Text("🧺 Tote") }
            } else {
                OutlinedButton(onClick = {
                    val lp = shipLp!!
                    action("stopShippingLPToPrinter", JSONObject().apply {
                        put("lpNo", lp)
                        put("printLabel", true)
                        put("printerId", getDefaultPrinter(context))
                    }.toString(), "Shipping LP kapandı") { r ->
                        if (r.ok) shipLp = null
                    }
                }, enabled = !busy, modifier = Modifier.weight(1f)) { Text("Sevk LP Kapat") }
            }
            OutlinedButton(onClick = {
                // Paylaşımlı BC lisansı: atama oturumdaki WMS kullanıcısına yazılır.
                scope.launch {
                    val me = BcApi.currentUserId(context)
                    if (me.isNotBlank())
                        action("reassign", JSONObject().apply { put("userId", me); put("reason", "terminalden üstlenildi") }.toString(), "Üzerinize alındı ($me)")
                    else action("assignToMe", "{}", "Bana atandı")
                }
            }, enabled = !busy, modifier = Modifier.weight(1f)) { Text("Bana Ata") }
        }
        BottomActionBar {
            val canRegister = com.dynops.bcwms.lib.ActionGuards.hasQuantity(lines)
            Button(
                onClick = { registerForCurrentUser() },
                enabled = !busy && canRegister,
                modifier = Modifier.fillMaxWidth().height(54.dp),
            ) {
                Text(
                    if (canRegister) "✅ Toplamayı Kaydet" else "Önce satırlara miktar girin",
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }

    if (showShort) {
        ShortPickSheet(line = shortLine, onDismiss = { showShort = false }, onConfirm = { qty, reason ->
            showShort = false
            val ln = shortLine ?: return@ShortPickSheet
            action("markShort", JSONObject().apply {
                put("lineNo", ln.optInt("lineNo")); put("qty", qty); put("reasonCode", reason)
            }.toString(), "Short pick işlendi")
        })
    }

    val scanTarget = scanLine
    if (scanTarget != null) {
        ScanVerifySheet(
            expectedItemNo = scanTarget.optString("itemNo"),
            description = scanTarget.optString("description"),
            initialLot = scanTarget.optString("lotNo"),
            busy = busy,
            onDismiss = { if (!busy) scanLine = null },
            onVerified = { lotNo ->
                // Codex review Finding 2: busy=true önce set edilir, recompose
                // sırasında diğer "Tara/Tamamla/Short" butonları disabled olur,
                // sheet sonra kapatılır. Tek updateLine coroutine'i garanti.
                if (!busy) {
                    busy = true
                    scanLine = null
                    scope.launch {
                        try {
                            val qty = scanTarget.optDouble("quantity")
                            val r = BcApi.confirmPickLine(
                                context = context,
                                pickNo = no,
                                lineNo = scanTarget.optInt("lineNo"),
                                qtyToHandle = qty,
                                lotNo = lotNo,
                            )
                            status = if (r.ok) "✅ Doğrulandı + tamamlandı (HTTP ${r.httpCode})"
                                else QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                            if (r.ok) reload()
                        } finally {
                            busy = false
                        }
                    }
                }
            },
            onMismatch = {
                status = "❌ Tarama eşleşmedi: beklenen ${scanTarget.optString("itemNo")}, okunan $it"
            },
        )
    }

    val al = actionLine
    if (al != null) {
        PickLineActionSheet(
            line = al,
            onDismiss = { actionLine = null },
            onComplete = { actionLine = null; updateLine(al, al.optDouble("quantity")) },
            onScan = { actionLine = null; scanLine = al },
            onShort = { actionLine = null; shortLine = al; showShort = true },
        )
    }
    // ELOG sepet modu: öneriyi doğrulat ya da yeni sepeti siparişe bağla,
    // sonra satırı tamamla.
    val ts = toteSuggest
    if (ts != null) {
        ToteSuggestSheet(
            line = ts.first,
            expectedLp = ts.second,
            busy = busy,
            onDismiss = { if (!busy) toteSuggest = null },
            onConfirmed = { scannedLp ->
                val line = ts.first
                val expected = ts.second
                toteSuggest = null
                scope.launch {
                    if (expected.isBlank()) {
                        busy = true; status = "Sepet bağlanıyor..."
                        val src = rawValue(line, "sourceNo")
                        val r = BcApi.boundAction(context, "picks", no, "assignTote",
                            JSONObject().apply { put("sourceOrderNo", src); put("lpNo", scannedLp) }.toString())
                        busy = false
                        if (!r.ok) {
                            status = QcErrorParser.friendlyStatus(BcApi.errorMessage(r.body), r.httpCode)
                            return@launch
                        }
                    }
                    status = "🧺 $scannedLp ← ${line.optString("itemNo")}"
                    updateLine(line, line.optDouble("quantity"))
                }
            },
        )
    }

    val gt = groupTarget
    if (gt != null) {
        QuantityDialogSheet(
            title = "Toplama Miktarı (${gt.count} satıra dağıtılır)",
            itemNo = gt.itemNo,
            initialQty = gt.totalOutstanding.takeIf { it > 0 } ?: 1.0,
            initialUom = gt.lines.first().optString("unitOfMeasureCode"),
            initialLot = gt.lines.first().optString("lotNo"),
            // ELOG: lot no el terminalinden girilir; seri girişi pick'te kapalı.
            showLotSerial = true,
            showSerial = false,
            lotRequired = gt.lines.any { it.optBoolean("lotRequired", false) },
            showAvailableLotLookup = true,
            autoDetectLotFromStock = true,
            locationCode = rawValue(gt.lines.first(), "locationCode"),
            variantCode = gt.lines.first().optString("variantCode"),
            onDismiss = { groupTarget = null },
            onConfirm = { res ->
                groupTarget = null
                scope.launch {
                    busy = true; status = "Grup dağıtılıyor..."
                    val plan = distributeQty(gt, res.quantity, ::pickLineCapacity)
                    var okCount = 0
                    var firstErr: String? = null
                    for ((ln, q) in plan) {
                        val r = BcApi.confirmPickLine(context, no, ln.optInt("lineNo"), q, res.lotNo)
                        if (r.ok) okCount++ else {
                            if (firstErr == null) firstErr = BcApi.errorMessage(r.body)
                            break
                        }
                    }
                    busy = false
                    status = if (firstErr == null) "TAMAM: $okCount/${plan.size} satıra dağıtıldı"
                        else "HATA: $okCount/${plan.size} satır yazıldı — $firstErr"
                    reload()
                }
            },
        )
    }
    if (showColumns) {
        ChooseColumnsSheet(GridColumns.pick, columns, onDismiss = { showColumns = false }) { c -> columns = c; ColumnPrefs.save(context, "pick", c); showColumns = false }
    }
    if (showTote) {
        ToteScanSheet(
            title = "Tote'a Topla",
            hint = "Yeniden kullanılabilir tote'u (LP) okut → bu toplamanın kabı olur.",
            onDismiss = { showTote = false },
            onScanned = { lp -> showTote = false; shipLp = lp; status = "🧺 Tote $lp aktif toplama kabı" },
        )
    }
}

/**
 * ELOG sepet modu sheet'i: sistem sipariş için atanmış sepeti önerir
 * ("→ Sepet T-06-K2"); operatör sepeti okutarak doğrular. Sipariş için sepet
 * yoksa okutulan sepet siparişe bağlanır. Yanlış sepet okutulursa hata gösterir
 * ve satır tamamlanmaz.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ToteSuggestSheet(
    line: JSONObject,
    expectedLp: String,
    busy: Boolean,
    onDismiss: () -> Unit,
    onConfirmed: (String) -> Unit,
) {
    var raw by remember { mutableStateOf("") }
    var hint by remember {
        mutableStateOf(
            if (expectedLp.isNotBlank()) "Önerilen sepeti okutarak doğrulayın."
            else "Bu siparişin sepeti yok — bağlanacak sepeti okutun."
        )
    }
    fun submit(value: String) {
        val v = value.trim()
        if (v.isEmpty()) return
        if (expectedLp.isBlank() || v.equals(expectedLp, ignoreCase = true)) onConfirmed(v)
        else hint = "❌ Yanlış sepet: $v — beklenen $expectedLp"
    }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("🧺 Sepete Koy", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("${line.optString("itemNo")} — ${line.optString("description")}", fontSize = 12.sp, color = Color.Gray)
        Text("Sipariş: ${rawValue(line, "sourceNo").ifBlank { "-" }} · Miktar: ${line.optDouble("quantity")}", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(12.dp))
        if (expectedLp.isNotBlank()) {
            Surface(color = Color(0xFFE3F2FD), shape = RoundedCornerShape(10.dp)) {
                Text(
                    "→ Sepet $expectedLp",
                    Modifier.fillMaxWidth().padding(14.dp),
                    fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Color(0xFF1565C0),
                )
            }
            Spacer(Modifier.height(10.dp))
        }
        com.dynops.bcwms.scanner.ScanField(
            "Sepet / LP okut", raw, { raw = it },
            modifier = Modifier.fillMaxWidth(),
            onScanned = { s ->
                val v = com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(s).value.trim()
                raw = v
                submit(v)
            },
        )
        Spacer(Modifier.height(8.dp))
        Text(hint, fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(16.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.weight(1f)) { Text("Vazgeç") }
            Button(enabled = raw.isNotBlank() && !busy, onClick = { submit(raw) }, modifier = Modifier.weight(1f)) { Text("Onayla") }
        }
        Spacer(Modifier.height(24.dp))
    }
}

/** Bir pick satırına tıklayınca açılan aksiyon sheet'i (grid satırından). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PickLineActionSheet(
    line: JSONObject,
    onDismiss: () -> Unit,
    onComplete: () -> Unit,
    onScan: () -> Unit,
    onShort: () -> Unit,
) {
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("${line.optString("itemNo")} — ${line.optString("description")}", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        Text("Bin: ${line.optString("binCode")} · Miktar: ${line.optDouble("qtyToHandle")} / ${line.optDouble("quantity")}", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(16.dp))
        Button(onClick = onScan, modifier = Modifier.fillMaxWidth().height(52.dp)) {
            WmsActionLabel(WmsGlyph.SCAN, "Tara ve Tamamla")
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onComplete, modifier = Modifier.fillMaxWidth().height(50.dp)) { Text("✅ Tamamla (tam miktar)") }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onShort, modifier = Modifier.fillMaxWidth().height(50.dp)) { Text("⚠ Eksik Topla") }
        Spacer(Modifier.height(24.dp))
    }
}

/**
 * Scan a barcode and confirm it matches the expected item on a pick line.
 * Prevents "wrong item picked" errors that the PDF flagged (§7). Operatör
 * yanlış raftan okutursa updateLine çağrılmaz ve ekrana belirgin hata yazılır.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScanVerifySheet(
    expectedItemNo: String,
    description: String,
    initialLot: String,
    busy: Boolean,
    onDismiss: () -> Unit,
    onVerified: (lotNo: String) -> Unit,
    onMismatch: (String) -> Unit,
) {
    var raw by remember { mutableStateOf("") }
    // ELOG: lot no el terminalinden girilir. GS1 barkodunda lot varsa otomatik
    // dolar (AI 10); yoksa operatör okutur/yazar.
    var lot by remember { mutableStateOf(initialLot) }
    var hint by remember { mutableStateOf("Ürün barkodunu okutun. Beklenen: $expectedItemNo") }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Tara & Doğrula", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("Beklenen: $expectedItemNo · $description", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(12.dp))
        com.dynops.bcwms.scanner.ScanField(
            "Ürün / barkod", raw, { raw = it },
            modifier = Modifier.fillMaxWidth(),
            onScanned = { scanned ->
                val resolved = com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(scanned)
                val readItem = resolved.itemNo ?: scanned
                raw = readItem
                // GS1 barkodunda lot varsa alanı otomatik doldur (operatör düzeltebilir).
                resolved.lotNo?.takeIf { it.isNotBlank() }?.let { lot = it }
                if (readItem.equals(expectedItemNo, ignoreCase = true)) {
                    hint = if (lot.isNotBlank()) "✅ Eşleşti · Lot $lot" else "✅ Eşleşti — lot girip onaylayın"
                } else {
                    hint = "❌ Eşleşmedi: $readItem"
                    onMismatch(readItem)
                }
            },
        )
        Spacer(Modifier.height(8.dp))
        com.dynops.bcwms.scanner.ScanField(
            "Lot No", lot, { lot = it },
            modifier = Modifier.fillMaxWidth(),
            onScanned = { scanned ->
                // Lot barkodu da GS1 olabilir; AI 10 varsa onu, yoksa ham değeri al.
                val resolved = com.dynops.bcwms.scanner.BarcodeIntentResolver.resolve(scanned)
                lot = resolved.lotNo?.takeIf { it.isNotBlank() } ?: scanned.trim()
            },
        )
        Spacer(Modifier.height(8.dp))
        Text(hint, fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(16.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.weight(1f)) { Text("Vazgeç") }
            Button(
                enabled = raw.trim().equals(expectedItemNo, ignoreCase = true) && !busy,
                onClick = {
                    if (raw.trim().equals(expectedItemNo, ignoreCase = true)) onVerified(lot.trim())
                    else { hint = "❌ Eşleşmedi: $raw"; onMismatch(raw.trim()) }
                },
                modifier = Modifier.weight(1f),
            ) { Text("Onayla") }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ActionBadge(action: String) {
    val (bg, fg) = when (action) {
        "Take" -> Color(0xFFE3F2FD) to Color(0xFF1565C0)
        "Place" -> Color(0xFFE8F5E9) to Color(0xFF2E7D32)
        else -> Color(0xFFF5F5F5) to Color(0xFF616161)
    }
    Surface(color = bg, shape = RoundedCornerShape(6.dp)) {
        Text(action.ifBlank { "-" }, Modifier.padding(horizontal = 8.dp, vertical = 2.dp), color = fg, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ShortPickSheet(line: JSONObject?, onDismiss: () -> Unit, onConfirm: (qty: Double, reason: String) -> Unit) {
    var qty by remember { mutableStateOf((line?.optDouble("qtyToHandle") ?: 0.0).let { if (it == it.toLong().toDouble()) it.toLong().toString() else it.toString() }) }
    // BC'ye gönderilen sebep KODLARI (wire) İngilizce kalır — Reason.Get(code)
    // eşleşmesi için. Operatöre Türkçe etiket gösterilir.
    val reasons = listOf("DAMAGED", "NOTFOUND", "SHORTAGE", "EXPIRED")
    fun reasonLabel(code: String) = when (code) {
        "DAMAGED" -> "Hasarlı"
        "NOTFOUND" -> "Bulunamadı"
        "SHORTAGE" -> "Stok Eksik"
        "EXPIRED" -> "Miadı Geçmiş"
        else -> code
    }
    var reason by remember { mutableStateOf(reasons.first()) }
    com.dynops.bcwms.ui.SheetScaffold(onDismiss = onDismiss, contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp)) {
        Text("Eksik Toplama", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text("Ürün: ${line?.optString("itemNo") ?: "-"}", fontSize = 12.sp, color = Color.Gray)
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(qty, { qty = it.filter { c -> c.isDigit() || c == '.' } }, label = { Text("Eksik Miktar") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        Text("Sebep", fontSize = 12.sp, color = Color.Gray)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            reasons.forEach { FilterChip(selected = it == reason, onClick = { reason = it }, label = { Text(reasonLabel(it)) }) }
        }
        Spacer(Modifier.height(16.dp))
        Button(modifier = Modifier.fillMaxWidth(), onClick = { onConfirm(qty.toDoubleOrNull() ?: 0.0, reason) }) { Text("Eksik İşle") }
        Spacer(Modifier.height(24.dp))
    }
}
