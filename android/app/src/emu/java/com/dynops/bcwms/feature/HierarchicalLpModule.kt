package com.dynops.bcwms.feature

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.BuildConfig
import com.dynops.bcwms.scanner.ScanField
import com.dynops.bcwms.ui.StatusText
import com.dynops.bcwms.ui.WmsGlyph
import com.dynops.bcwms.ui.WmsIcon
import com.dynops.bcwms.ui.WmsRefreshLabel
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

private enum class HierarchyTask(val title: String, val hint: String) {
    CREATE("LP Oluştur", "Ürün, kutu veya palet"),
    ATTACH("Birbirine Bağla", "Ürün → kutu, kutu → palet"),
    DETACH("Bağlantıyı Kaldır", "Yanlış bağlanan LP'yi çıkar"),
    VIEW("İçeriği Gör", "Paletin bütün ağacını göster"),
    MOVE("Tamamını Taşı", "Palet ve altlarını tek işlemde taşı"),
    PRINT("Etiket Yazdır", "Ürün, kutu veya palet etiketi"),
}

private enum class DkcUnit(val label: String, val template: String) {
    ITEM("Ürün", "DKC-ITEM"),
    BOX("Kutu", "DKC-BOX"),
    PALLET("Palet", "DKC-PALLET"),
}

@Composable
fun HierarchicalLpModule(onOpenClassicLp: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var task by remember { mutableStateOf(HierarchyTask.CREATE) }
    var checking by remember { mutableStateOf(true) }
    var serverEnabled by remember { mutableStateOf(false) }
    var templatesReady by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }

    fun checkServer() {
        scope.launch {
            checking = true
            status = "Business Central ayarları kontrol ediliyor..."
            val setup = BcApi.get(context, "movementOps('')?\$select=hierarchicalLpEnabled")
            serverEnabled = setup.ok && runCatching {
                JSONObject(setup.body).optBoolean("hierarchicalLpEnabled", false)
            }.getOrDefault(false)
            val templates = if (serverEnabled) BcApi.getAllPages(
                context,
                "licensePlateTemplates?\$filter=code eq 'DKC-ITEM' or code eq 'DKC-BOX' or code eq 'DKC-PALLET'&\$select=code&\$top=10",
            ) else null
            templatesReady = templates?.complete == true &&
                templates.rows.map { it.optString("code") }.toSet().containsAll(
                    setOf("DKC-ITEM", "DKC-BOX", "DKC-PALLET"),
                )
            checking = false
            status = when {
                !BuildConfig.FEATURE_HIERARCHICAL_LP -> "HATA: Bu APK hiyerarşik LP özelliğini içermiyor."
                !setup.ok -> "HATA: Güncel DKC Business Central uzantısına ulaşılamadı."
                !serverEnabled -> "HATA: Bu BC şirketinde Hiyerarşik LP kapalı. Advanced WMS Setup ekranından açın."
                !templatesReady -> "HATA: DKC şablonları eksik. BC Setup ekranında 'Create DKC LP Templates' çalıştırın."
                else -> "TAMAM: Ürün → kutu → palet akışı hazır."
            }
        }
    }

    LaunchedEffect(Unit) { checkServer() }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            WmsIcon(WmsGlyph.HIERARCHY, MaterialTheme.colorScheme.primary, Modifier.size(28.dp))
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("DKC Kutu ve Palet", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Text("Her adım barkod okutarak ilerler.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            OutlinedButton(onClick = { checkServer() }, enabled = !checking) {
                WmsRefreshLabel(checking, compact = true)
            }
        }
        Spacer(Modifier.height(8.dp))
        StatusText(status)

        if (!serverEnabled || !templatesReady) {
            Spacer(Modifier.height(12.dp))
            SetupHelpCard()
            return@Column
        }

        Spacer(Modifier.height(14.dp))
        HierarchyTask.entries.chunked(2).forEach { rowTasks ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                rowTasks.forEach { candidate ->
                    Card(
                        onClick = { task = candidate; status = "" },
                        modifier = Modifier.weight(1f).height(92.dp),
                        shape = RoundedCornerShape(16.dp),
                        border = BorderStroke(
                            if (task == candidate) 2.dp else 1.dp,
                            if (task == candidate) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
                        ),
                        colors = CardDefaults.cardColors(
                            containerColor = if (task == candidate) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.surface,
                        ),
                    ) {
                        Column(Modifier.fillMaxSize().padding(11.dp), verticalArrangement = Arrangement.Center) {
                            Text(candidate.title, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(candidate.hint, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                if (rowTasks.size == 1) Spacer(Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
        }

        when (task) {
            HierarchyTask.CREATE -> CreateHierarchyLpForm(
                onStatus = { status = it },
                onOpenClassicLp = onOpenClassicLp,
            )
            HierarchyTask.ATTACH -> RelationForm(detach = false, onStatus = { status = it })
            HierarchyTask.DETACH -> RelationForm(detach = true, onStatus = { status = it })
            HierarchyTask.VIEW -> ViewHierarchyForm(onStatus = { status = it })
            HierarchyTask.MOVE -> MoveHierarchyForm(onStatus = { status = it })
            HierarchyTask.PRINT -> PrintHierarchyForm(onStatus = { status = it })
        }
        Spacer(Modifier.height(28.dp))
    }
}

@Composable
private fun SetupHelpCard() {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(Modifier.padding(14.dp)) {
            Text("BC kurulumu tamamlanmalı", fontWeight = FontWeight.Bold)
            Text("1. EMU / Sandbox3007 / My Company şirketini açın.", fontSize = 13.sp)
            Text("2. Advanced WMS Setup'ta gerçek GS1 firma önekini girin.", fontSize = 13.sp)
            Text("3. Hierarchical LP Enabled alanını açın.", fontSize = 13.sp)
            Text("4. Create DKC LP Templates işlemini çalıştırın.", fontSize = 13.sp)
            Text("BADE şirketinde bu anahtar kapalı kalmalıdır.", fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun FormCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(Modifier.padding(14.dp), content = {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Spacer(Modifier.height(10.dp))
            content()
        })
    }
}

@Composable
private fun CreateHierarchyLpForm(onStatus: (String) -> Unit, onOpenClassicLp: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var unit by remember { mutableStateOf(DkcUnit.ITEM) }
    var location by remember { mutableStateOf("") }
    var bin by remember { mutableStateOf("") }
    var itemNo by remember { mutableStateOf("") }
    var sourceBin by remember { mutableStateOf("") }
    var quantity by remember { mutableStateOf("1") }
    var uom by remember { mutableStateOf("") }
    var lotNo by remember { mutableStateOf("") }
    var serialNo by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var createdNo by remember { mutableStateOf("") }

    FormCard("Yeni ${unit.label} LP") {
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            DkcUnit.entries.forEach { candidate ->
                FilterChip(
                    selected = unit == candidate,
                    onClick = { unit = candidate; createdNo = "" },
                    label = { Text(candidate.label) },
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        ScanField("Lokasyon", location, { location = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        ScanField("LP'nin Bulunduğu Bin", bin, { bin = it }, modifier = Modifier.fillMaxWidth())
        if (unit == DkcUnit.ITEM) {
            Spacer(Modifier.height(8.dp))
            ScanField("Ürün No.", itemNo, { itemNo = it }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            ScanField("Ürünün Alınacağı Kaynak Bin", sourceBin, { sourceBin = it }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(quantity, { quantity = it.filter { c -> c.isDigit() || c == '.' || c == ',' }.replace(',', '.') }, label = { Text("Miktar") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(uom, { uom = it }, label = { Text("Birim (boşsa temel birim)") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Spacer(Modifier.height(8.dp))
            ScanField("Lot No. (varsa)", lotNo, { lotNo = it }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            ScanField("Seri No. (varsa)", serialNo, { serialNo = it }, modifier = Modifier.fillMaxWidth())
        }
        Spacer(Modifier.height(12.dp))
        Button(
            modifier = Modifier.fillMaxWidth().height(52.dp),
            enabled = !busy && location.isNotBlank() && bin.isNotBlank() &&
                (unit != DkcUnit.ITEM || (itemNo.isNotBlank() && sourceBin.isNotBlank() && (quantity.toDoubleOrNull() ?: 0.0) > 0)),
            onClick = {
                scope.launch {
                    busy = true
                    createdNo = ""
                    onStatus("${unit.label} LP oluşturuluyor...")
                    val build = BcApi.boundAction(
                        context,
                        "licensePlateTemplates",
                        unit.template,
                        "build",
                        JSONObject().apply {
                            put("locationCode", location.trim())
                            put("binCode", bin.trim())
                        }.toString(),
                    )
                    val lpNo = if (build.ok) BcApi.scalarValue(build.body).trim() else ""
                    if (!build.ok || lpNo.isBlank()) {
                        busy = false
                        onStatus("HATA: ${BcApi.errorMessage(build.body)}")
                        return@launch
                    }
                    createdNo = lpNo
                    if (unit == DkcUnit.ITEM) {
                        val userId = BcApi.currentUserId(context).trim()
                        if (userId.isBlank()) {
                            busy = false
                            onStatus("HATA: $lpNo oluşturuldu fakat kullanıcı kimliği bulunamadığı için ürün eklenmedi.")
                            return@launch
                        }
                        val addLine = BcApi.boundAction(
                            context,
                            "licensePlates",
                            lpNo,
                            "addLineFromBin",
                            JSONObject().apply {
                                put("itemNo", itemNo.trim())
                                put("unitOfMeasure", uom.trim())
                                put("quantity", quantity.toDoubleOrNull() ?: 0.0)
                                put("lotNo", lotNo.trim())
                                put("serialNo", serialNo.trim())
                                put("sourceBinCode", sourceBin.trim())
                                put("userId", userId)
                            }.toString(),
                        )
                        if (!addLine.ok) {
                            busy = false
                            onStatus("HATA: $lpNo oluşturuldu fakat ürün eklenemedi: ${BcApi.errorMessage(addLine.body)}")
                            return@launch
                        }
                    }
                    val complete = BcApi.boundAction(context, "licensePlates", lpNo, "completeHierarchyNode")
                    busy = false
                    onStatus(
                        if (complete.ok) "TAMAM: ${unit.label} LP hazır — $lpNo"
                        else "HATA: $lpNo oluşturuldu fakat tamamlanamadı: ${BcApi.errorMessage(complete.body)}",
                    )
                }
            },
        ) { Text(if (busy) "Hazırlanıyor..." else "${unit.label} LP Oluştur ve Tamamla") }
        if (createdNo.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text("Oluşan LP: $createdNo", fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onOpenClassicLp, modifier = Modifier.fillMaxWidth()) {
            Text("Klasik LP Listesini Aç")
        }
    }
}

@Composable
private fun RelationForm(detach: Boolean, onStatus: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var parent by remember { mutableStateOf("") }
    var child by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    FormCard(if (detach) "LP Bağlantısını Kaldır" else "LP'leri Birbirine Bağla") {
        Text(
            if (detach) "Önce üst kutu/paleti, sonra çıkarılacak alt LP'yi okutun."
            else "Kutu için: üst = kutu, alt = ürün. Palet için: üst = palet, alt = kutu.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        ScanField("Üst LP (Kutu / Palet)", parent, { parent = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        ScanField("Alt LP (Ürün / Kutu)", child, { child = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = {
                scope.launch {
                    busy = true
                    val action = if (detach) "detachChild" else "attachChild"
                    val result = BcApi.boundAction(
                        context,
                        "licensePlates",
                        parent.trim(),
                        action,
                        JSONObject().apply { put("childLpNo", child.trim()) }.toString(),
                    )
                    busy = false
                    onStatus(
                        if (result.ok) "TAMAM: $child ${if (detach) "çıkarıldı" else "$parent içine bağlandı"}."
                        else "HATA: ${BcApi.errorMessage(result.body)}",
                    )
                    if (result.ok) child = ""
                }
            },
            enabled = !busy && parent.isNotBlank() && child.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (busy) "İşleniyor..." else if (detach) "Bağlantıyı Kaldır" else "Bağla") }
    }
}

@Composable
private fun ViewHierarchyForm(onStatus: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var root by remember { mutableStateOf("") }
    var tree by remember { mutableStateOf<JSONObject?>(null) }
    var busy by remember { mutableStateOf(false) }
    FormCard("Kutu / Palet İçeriği") {
        ScanField("Kök LP (tercihen palet)", root, { root = it; tree = null }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        Button(
            onClick = {
                scope.launch {
                    busy = true
                    val result = BcApi.boundAction(context, "licensePlates", root.trim(), "getHierarchy")
                    tree = if (result.ok) runCatching { JSONObject(BcApi.scalarValue(result.body)) }.getOrNull() else null
                    busy = false
                    onStatus(
                        if (tree != null) "TAMAM: Hiyerarşi yüklendi."
                        else "HATA: ${BcApi.errorMessage(result.body)}",
                    )
                }
            },
            enabled = !busy && root.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) { Text(if (busy) "Yükleniyor..." else "İçeriği Göster") }
        tree?.let {
            Spacer(Modifier.height(12.dp))
            HierarchyNode(it, 0)
        }
    }
}

@Composable
private fun HierarchyNode(node: JSONObject, depth: Int) {
    val children = node.optJSONArray("children") ?: JSONArray()
    Card(
        modifier = Modifier.fillMaxWidth().padding(start = (depth * 12).dp, bottom = 6.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (depth == 0) MaterialTheme.colorScheme.primaryContainer
            else MaterialTheme.colorScheme.surfaceVariant,
        ),
        shape = RoundedCornerShape(12.dp),
    ) {
        Column(Modifier.padding(10.dp)) {
            Text("${node.optString("unitType")} · ${node.optString("no")}", fontWeight = FontWeight.Bold)
            Text("${node.optString("locationCode")}/${node.optString("binCode")} · ${node.optString("status")}", fontSize = 11.sp)
            val lines = node.optJSONArray("lines") ?: JSONArray()
            for (index in 0 until lines.length()) {
                val line = lines.optJSONObject(index) ?: continue
                Text(
                    "${line.optString("itemNo")} × ${line.optDouble("quantity")} ${line.optString("unitOfMeasure")} · Lot ${line.optString("lotNo").ifBlank { "-" }}",
                    fontSize = 12.sp,
                )
            }
        }
    }
    for (index in 0 until children.length()) {
        children.optJSONObject(index)?.let { HierarchyNode(it, depth + 1) }
    }
}

@Composable
private fun MoveHierarchyForm(onStatus: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var root by remember { mutableStateOf("") }
    var targetBin by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    FormCard("Hiyerarşiyi Tek İşlemde Taşı") {
        Text("Yalnız kök paleti/kutuyu okutun; içindeki bütün alt LP'ler birlikte taşınır.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        ScanField("Kök LP", root, { root = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        ScanField("Hedef Bin", targetBin, { targetBin = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = {
                scope.launch {
                    busy = true
                    val userId = BcApi.currentUserId(context).trim()
                    if (userId.isBlank()) {
                        busy = false
                        onStatus("HATA: Kullanıcı kimliği bulunamadı. Yeniden giriş yapın.")
                        return@launch
                    }
                    val result = BcApi.boundAction(
                        context,
                        "licensePlates",
                        root.trim(),
                        "moveHierarchy",
                        JSONObject().apply {
                            put("targetBinCode", targetBin.trim())
                            put("userId", userId)
                        }.toString(),
                    )
                    busy = false
                    onStatus(
                        if (result.ok) "TAMAM: $root ve bütün alt LP'leri $targetBin binine taşındı."
                        else "HATA: ${BcApi.errorMessage(result.body)}",
                    )
                }
            },
            enabled = !busy && root.isNotBlank() && targetBin.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (busy) "Taşınıyor..." else "Tamamını Taşı") }
    }
}

@Composable
private fun PrintHierarchyForm(onStatus: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var lpNo by remember { mutableStateOf("") }
    var reason by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val printer = getDefaultPrinter(context, PRINTER_USAGE_LABEL)

    FormCard("Hiyerarşi Etiketi") {
        ScanField("Ürün / Kutu / Palet LP", lpNo, { lpNo = it }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            reason,
            { reason = it },
            label = { Text("Tekrar baskı nedeni") },
            supportingText = { Text("İlk baskıda boş bırakın; yeniden baskıda neden yazın.") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        Text("Etiket yazıcısı: ${printer.ifBlank { "seçilmedi" }}", fontSize = 12.sp, color = if (printer.isBlank()) MaterialTheme.colorScheme.error else Color.Gray)
        Spacer(Modifier.height(10.dp))
        Button(
            onClick = {
                scope.launch {
                    busy = true
                    val action = if (reason.isBlank()) "completeAndPrint" else "reprintHierarchyLabel"
                    val payload = JSONObject().apply {
                        put("printerId", printer)
                        put("labelProfile", "")
                        put("copies", 1)
                        if (reason.isNotBlank()) put("reason", reason.trim())
                    }.toString()
                    val result = BcApi.boundAction(context, "licensePlates", lpNo.trim(), action, payload)
                    busy = false
                    onStatus(
                        if (result.ok) "TAMAM: $lpNo etiketi yazıcı kuyruğuna gönderildi."
                        else "HATA: ${BcApi.errorMessage(result.body)}",
                    )
                }
            },
            enabled = !busy && lpNo.isNotBlank() && printer.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (busy) "Gönderiliyor..." else "Etiketi Yazdır") }
    }
}
