package com.dynops.bcwms.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.util.Log
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.scanner.BarcodeIntentResolver
import com.dynops.bcwms.scanner.ScanField
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.format.ResolverStyle
import java.util.Locale

data class QuantityResult(
    val quantity: Double,
    val uom: String,
    val lotNo: String,
    val serialNo: String,
    val supplierLotNo: String = "",
    val expiryDate: String = "",
)

/**
 * Modal bottom sheet for capturing a quantity with optional UoM / lot / serial.
 * Includes a stepper, a big "+1" button, and Confirm / Cancel.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuantityDialogSheet(
    title: String,
    itemNo: String,
    initialQty: Double = 1.0,
    initialUom: String = "",
    initialLot: String = "",
    initialSerial: String = "",
    initialSupplierLot: String = "",
    initialExpiryDate: String = "",
    uomOptions: List<String> = emptyList(),
    uomRequired: Boolean = false,
    uomSelectionOnly: Boolean = false,
    showLotSerial: Boolean = true,
    showSerial: Boolean = showLotSerial,
    showSupplierLot: Boolean = false,
    lotRequired: Boolean = false,
    lotSelectionOnly: Boolean = false,
    showAvailableLotLookup: Boolean = false,
    serialRequired: Boolean = false,
    quantityExactlyOne: Boolean = false,
    // Stoktaki lotları açılışta yoklar: lot bulunursa alan zorunlu sayılır ve
    // seçim listesi görünür. BC'deki lotRequired alanı yayınlanmamış olsa bile
    // lot takipli üründe boş lotla sevk edilmesini engeller.
    autoDetectLotFromStock: Boolean = false,
    locationCode: String = "",
    binCode: String = "",
    variantCode: String = "",
    supplierLotRequired: Boolean = false,
    showExpiryDate: Boolean = false,
    expiryDateRequired: Boolean = false,
    onAssignLotNo: (suspend () -> Result<String>)? = null,
    onConfirm: (QuantityResult) -> Unit,
    onDismiss: () -> Unit,
) {
    var qtyText by remember { mutableStateOf(formatQty(initialQty)) }
    var uom by remember { mutableStateOf(initialUom) }
    var lot by remember { mutableStateOf(initialLot) }
    var serial by remember { mutableStateOf(initialSerial) }
    var supplierLot by remember { mutableStateOf(initialSupplierLot) }
    var expiryDateText by remember(initialExpiryDate) { mutableStateOf(expiryDateForDisplay(initialExpiryDate)) }
    var assigningLot by remember { mutableStateOf(false) }
    var lotAssignmentError by remember { mutableStateOf("") }
    var showSupplierLotLookup by remember { mutableStateOf(false) }
    var showAvailableLotLookupContent by remember { mutableStateOf(false) }
    var uomExpanded by remember { mutableStateOf(false) }
    val selectableUoms = remember(uomOptions) {
        uomOptions.map(String::trim).filter(String::isNotBlank).distinctBy(String::uppercase)
    }
    LaunchedEffect(selectableUoms, initialUom) {
        if (uom.isBlank()) uom = selectableUoms.firstOrNull().orEmpty()
    }
    // -1 = henüz bilinmiyor / sorgulanamadı, 0 = stokta lot yok, >0 = lot var.
    var stockLotCount by remember(itemNo, locationCode, binCode, variantCode) { mutableStateOf(-1) }
    val probeContext = LocalContext.current
    val actionScope = rememberCoroutineScope()
    LaunchedEffect(autoDetectLotFromStock, showLotSerial, itemNo, locationCode, binCode, variantCode) {
        if (!autoDetectLotFromStock || !showLotSerial || itemNo.isBlank()) return@LaunchedEffect
        stockLotCount = fetchAvailableLots(probeContext, itemNo, locationCode, binCode, variantCode)
            .getOrNull()?.size ?: -1
    }
    val effectiveLotRequired = lotRequired || stockLotCount > 0
    val lotLookupVisible = showAvailableLotLookup || stockLotCount > 0
    val stockLotProbeReady = !autoDetectLotFromStock || !showLotSerial || itemNo.isBlank() || stockLotCount >= 0
    val normalizedExpiryDate = normalizeExpiryDate(expiryDateText)
    val expiryDateValid = expiryDateText.isBlank() || normalizedExpiryDate != null

    fun qty(): Double = qtyText.toDoubleOrNull() ?: 0.0
    fun setQty(v: Double) { qtyText = formatQty(v.coerceAtLeast(0.0)) }
    LaunchedEffect(quantityExactlyOne) {
        if (quantityExactlyOne) setQty(1.0)
    }

    SheetScaffold(onDismiss = onDismiss) {
            if (showSupplierLotLookup) {
                SupplierLotLookupContent(
                    itemNo = itemNo,
                    onBack = { showSupplierLotLookup = false },
                    onSelect = { selectedLot, selectedSupplierLot ->
                        lot = selectedLot
                        supplierLot = selectedSupplierLot
                        showSupplierLotLookup = false
                    },
                )
                return@SheetScaffold
            }
            if (showAvailableLotLookupContent) {
                AvailableLotLookupContent(
                    itemNo = itemNo,
                    locationCode = locationCode,
                    binCode = binCode,
                    variantCode = variantCode,
                    onBack = { showAvailableLotLookupContent = false },
                    onSelect = { selectedLot ->
                        lot = selectedLot
                        showAvailableLotLookupContent = false
                    },
                )
                return@SheetScaffold
            }

            Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Text("Ürün: $itemNo", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(16.dp))

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedIconButton(
                    onClick = { setQty(qty() - 1) },
                    enabled = !quantityExactlyOne,
                ) { Text("−", fontSize = 22.sp) }
                OutlinedTextField(
                    value = qtyText,
                    onValueChange = { qtyText = it.filter { c -> c.isDigit() || c == '.' } },
                    label = { Text("Miktar") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    readOnly = quantityExactlyOne,
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                OutlinedIconButton(
                    onClick = { setQty(qty() + 1) },
                    enabled = !quantityExactlyOne,
                ) { Text("+", fontSize = 22.sp) }
            }
            Spacer(Modifier.height(10.dp))
            Button(
                onClick = { setQty(qty() + 1) },
                enabled = !quantityExactlyOne,
                modifier = Modifier.fillMaxWidth().height(52.dp)
            ) { Text("+1", fontSize = 20.sp, fontWeight = FontWeight.Bold) }
            if (quantityExactlyOne) {
                Text(
                    "Seri takipli üründe her seri numarası tam olarak 1 temel birimdir.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(12.dp))
            if (uomSelectionOnly || selectableUoms.isNotEmpty()) {
                ExposedDropdownMenuBox(
                    expanded = uomExpanded,
                    onExpandedChange = { if (selectableUoms.isNotEmpty()) uomExpanded = !uomExpanded },
                ) {
                    OutlinedTextField(
                        value = uom,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(if (uomRequired) "Ölçü Birimi (zorunlu)" else "Ölçü Birimi (UOM)") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = uomExpanded) },
                        singleLine = true,
                        modifier = Modifier.menuAnchor().fillMaxWidth(),
                    )
                    ExposedDropdownMenu(expanded = uomExpanded, onDismissRequest = { uomExpanded = false }) {
                        selectableUoms.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option) },
                                onClick = { uom = option; uomExpanded = false },
                            )
                        }
                    }
                }
                if (uomRequired && uom.isBlank()) {
                    Text(
                        "Bu ürün için geçerli bir ölçü birimi seçilmelidir.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            } else {
                OutlinedTextField(
                    value = uom, onValueChange = { uom = it },
                    label = { Text("Ölçü Birimi (UOM)") }, singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
            if (showLotSerial) {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = lot,
                    onValueChange = { if (!lotSelectionOnly) lot = it },
                    readOnly = lotSelectionOnly || onAssignLotNo != null,
                    label = { Text(if (effectiveLotRequired || supplierLotRequired) "Lot No (zorunlu)" else "Lot No (opsiyonel)") }, singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                if (onAssignLotNo != null) {
                    Spacer(Modifier.height(6.dp))
                    OutlinedButton(
                        onClick = {
                            lotAssignmentError = ""
                            actionScope.launch {
                                assigningLot = true
                                onAssignLotNo()
                                    .onSuccess { assigned ->
                                        lot = assigned.trim()
                                        if (lot.isBlank())
                                            lotAssignmentError = "BC lot numarası üretmedi. Ürün kartındaki numara serisini kontrol edin."
                                    }
                                    .onFailure { error ->
                                        lotAssignmentError = error.message.orEmpty().ifBlank {
                                            "Lot numarası atanamadı."
                                        }
                                    }
                                assigningLot = false
                            }
                        },
                        enabled = !assigningLot && lot.isBlank(),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        if (assigningLot) {
                            CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(if (lot.isBlank()) "Lot No Ata" else "Lot No Atandı")
                    }
                    if (lotAssignmentError.isNotBlank()) {
                        Text(
                            lotAssignmentError,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
                if (lotLookupVisible) {
                    Spacer(Modifier.height(6.dp))
                    OutlinedButton(
                        onClick = { showAvailableLotLookupContent = true },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        WmsActionLabel(WmsGlyph.LICENSE_PLATE, "Stoktaki Lotlardan Seç")
                    }
                }
                if (effectiveLotRequired && lot.isBlank()) {
                    Text(
                        "Lot takipli üründe sevkiyat için stoktaki bir lotu seçmelisiniz.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                if (!stockLotProbeReady) {
                    Text(
                        "Stoktaki lotlar doğrulanamadı. Bağlantıyı kontrol edip bu ekranı yeniden açın.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            if (showSupplierLot) {
                Spacer(Modifier.height(8.dp))
                ScanField(
                    label = if (supplierLotRequired) "Tedarikçi Lotu (zorunlu)" else "Tedarikçi Lotu",
                    value = supplierLot,
                    onValueChange = { supplierLot = it },
                    modifier = Modifier.fillMaxWidth(),
                    onScanned = { scanned ->
                        val resolved = BarcodeIntentResolver.resolve(scanned)
                        supplierLot = resolved.lotNo?.takeIf(String::isNotBlank) ?: scanned.trim()
                    },
                )
                Spacer(Modifier.height(6.dp))
                OutlinedButton(
                    onClick = { showSupplierLotLookup = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    WmsActionLabel(WmsGlyph.ITEM_SEARCH, "Tedarikçi Lotu Lookup")
                }
                if (supplierLotRequired && supplierLot.isBlank()) {
                    Text(
                        "Bu alan okutulmadan veya girilmeden mal kabul satırı onaylanamaz.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            if (showSerial) {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = serial, onValueChange = { serial = it },
                    label = { Text(if (serialRequired) "Seri No (zorunlu)" else "Seri No (opsiyonel)") }, singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                if (serialRequired && serial.isBlank()) {
                    Text(
                        "Seri takipli üründe seri numarası girilmelidir.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            if (showExpiryDate || expiryDateRequired) {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = expiryDateText,
                    onValueChange = { value ->
                        expiryDateText = value.filter { it.isDigit() || it == '.' || it == '/' || it == '-' }
                            .take(10)
                    },
                    label = {
                        Text(
                            if (expiryDateRequired) "Son Kullanma Tarihi (zorunlu)"
                            else "Son Kullanma Tarihi"
                        )
                    },
                    supportingText = { Text("GG.AA.YYYY") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    isError = (expiryDateRequired && expiryDateText.isBlank()) || !expiryDateValid,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (expiryDateRequired && expiryDateText.isBlank()) {
                    Text(
                        "Bu ürünün takip kodu son kullanma tarihini zorunlu tutuyor.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                } else if (!expiryDateValid) {
                    Text(
                        "Geçerli bir tarih girin (ör. 31.12.2027).",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("İptal") }
                Button(
                    onClick = {
                        onConfirm(
                            QuantityResult(
                                quantity = qty(),
                                uom = uom.trim(),
                                lotNo = lot.trim(),
                                serialNo = serial.trim(),
                                supplierLotNo = supplierLot.trim(),
                                expiryDate = normalizedExpiryDate.orEmpty(),
                            )
                        )
                    },
                    enabled = qty() > 0 &&
                        (!quantityExactlyOne || qty() == 1.0) &&
                        stockLotProbeReady &&
                        (!uomRequired || uom.isNotBlank()) &&
                        (!effectiveLotRequired || lot.isNotBlank()) &&
                        (!serialRequired || serial.isNotBlank()) &&
                        (!supplierLotRequired || (lot.isNotBlank() && supplierLot.isNotBlank())) &&
                        expiryDateValid &&
                        (!expiryDateRequired || normalizedExpiryDate != null),
                    modifier = Modifier.weight(1f)
                ) { Text("Onayla") }
            }
            Spacer(Modifier.height(24.dp))
    }
}

private val TurkishDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("dd.MM.uuuu", Locale.forLanguageTag("tr-TR"))
        .withResolverStyle(ResolverStyle.STRICT)

internal fun normalizeExpiryDate(value: String): String? {
    val normalized = value.trim().replace('/', '.').replace('-', '.')
    if (normalized.isBlank()) return null
    return try {
        LocalDate.parse(normalized, TurkishDateFormatter).format(DateTimeFormatter.ISO_LOCAL_DATE)
    } catch (_: DateTimeParseException) {
        null
    }
}

internal fun expiryDateForDisplay(value: String): String {
    val trimmed = value.trim()
    if (trimmed.isBlank() || trimmed.startsWith("0001-01-01")) return ""
    return try {
        LocalDate.parse(trimmed.take(10), DateTimeFormatter.ISO_LOCAL_DATE).format(TurkishDateFormatter)
    } catch (_: DateTimeParseException) {
        trimmed
    }
}

@Composable
private fun AvailableLotLookupContent(
    itemNo: String,
    locationCode: String,
    binCode: String,
    variantCode: String,
    onBack: () -> Unit,
    onSelect: (lotNo: String) -> Unit,
) {
    val context = LocalContext.current
    var rows by remember(itemNo, locationCode, binCode, variantCode) { mutableStateOf<List<JSONObject>>(emptyList()) }
    var loading by remember(itemNo, locationCode, binCode, variantCode) { mutableStateOf(true) }
    var error by remember(itemNo, locationCode, binCode, variantCode) { mutableStateOf("") }

    LaunchedEffect(itemNo, locationCode, binCode, variantCode) {
        loading = true
        error = ""
        fetchAvailableLots(context, itemNo, locationCode, binCode, variantCode)
            .onSuccess { rows = it }
            .onFailure { error = it.message.orEmpty() }
        loading = false
    }

    TextButton(onClick = onBack) { Text("‹ Miktar girişine dön") }
    Text("Stoktaki Lotlar", fontWeight = FontWeight.Bold, fontSize = 18.sp)
    Text(
        listOf("Ürün: $itemNo", "Lokasyon: $locationCode", binCode.takeIf(String::isNotBlank)?.let { "Raf: $it" })
            .filterNotNull()
            .joinToString(" · "),
        fontSize = 12.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Spacer(Modifier.height(12.dp))

    when {
        loading -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            CircularProgressIndicator()
        }
        error.isNotBlank() -> StatusText(error)
        rows.isEmpty() -> Text(
            "Bu lokasyon/rafta pozitif stoklu lot bulunamadı.",
            color = MaterialTheme.colorScheme.error,
        )
        else -> rows.forEach { row ->
            val lotNo = row.optString("lotNo")
            val quantityBase = row.optDouble("quantityBase", 0.0)
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { onSelect(lotNo) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.fillMaxWidth()) {
                    Text(lotNo, fontWeight = FontWeight.Bold)
                    Text(
                        "Stok (temel): ${formatQty(quantityBase)}" +
                            row.optString("binCode").takeIf(String::isNotBlank)?.let { " · Raf: $it" }.orEmpty(),
                        fontSize = 12.sp,
                    )
                }
            }
        }
    }
    Spacer(Modifier.height(24.dp))
}

@Composable
private fun SupplierLotLookupContent(
    itemNo: String,
    onBack: () -> Unit,
    onSelect: (lotNo: String, supplierLotNo: String) -> Unit,
) {
    val context = LocalContext.current
    var rows by remember(itemNo) { mutableStateOf<List<JSONObject>>(emptyList()) }
    var query by remember { mutableStateOf("") }
    var loading by remember(itemNo) { mutableStateOf(true) }
    var error by remember(itemNo) { mutableStateOf("") }

    LaunchedEffect(itemNo) {
        loading = true
        error = ""
        val safeItemNo = itemNo.replace("'", "''")
        val page = BcApi.getAllPages(
            context,
            "supplierLots?\$filter=itemNo eq '$safeItemNo'&\$orderby=supplierLotNo&\$top=100",
        )
        if (page.complete) {
            rows = page.rows
        } else {
            error = "Tedarikçi lotlarının tamamı alınamadı. Bağlantıyı kontrol edip yeniden deneyin."
        }
        loading = false
    }

    val normalizedQuery = query.trim()
    val filteredRows = rows.filter { row ->
        normalizedQuery.isBlank() ||
            row.optString("supplierLotNo").contains(normalizedQuery, ignoreCase = true) ||
            row.optString("lotNo").contains(normalizedQuery, ignoreCase = true)
    }

    TextButton(onClick = onBack) { Text("‹ Mal kabule dön") }
    Text("Tedarikçi Lotu Seç", fontWeight = FontWeight.Bold, fontSize = 18.sp)
    Text(
        "Ürün: $itemNo · Seçildiğinde iç lot ve tedarikçi lotu birlikte doldurulur.",
        fontSize = 12.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = query,
        onValueChange = { query = it },
        label = { Text("Tedarikçi lotu veya iç lot ara") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(10.dp))

    when {
        loading -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            CircularProgressIndicator()
        }
        error.isNotBlank() -> StatusText(error)
        filteredRows.isEmpty() -> Text(
            if (rows.isEmpty()) "Bu ürün için kayıtlı tedarikçi lotu bulunamadı. Yeni lotu elle girebilir veya okutabilirsiniz."
            else "Aramayla eşleşen tedarikçi lotu bulunamadı.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        else -> filteredRows.take(50).forEach { row ->
            val supplierLotNo = row.optString("supplierLotNo")
            val lotNo = row.optString("lotNo")
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { onSelect(lotNo, supplierLotNo) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.fillMaxWidth()) {
                    Text(supplierLotNo, fontWeight = FontWeight.Bold)
                    Text(
                        "İç lot: $lotNo" + row.optDouble("inventory", 0.0)
                            .takeIf { it != 0.0 }
                            ?.let { " · Stok: ${formatQty(it)}" }
                            .orEmpty(),
                        fontSize = 12.sp,
                    )
                }
            }
        }
    }
    Spacer(Modifier.height(24.dp))
}

private fun formatQty(v: Double): String =
    if (v == v.toLong().toDouble()) v.toLong().toString() else v.toString()

/**
 * Stokta pozitif bakiyesi olan lotları getirir (BC: availableLots). Hem lot seçim
 * listesi hem de "bu ürün lot takipli mi" yoklaması aynı kaynağı kullansın diye
 * ortak: iki yerde farklı filtre kurulursa liste ile zorunluluk çelişebilir.
 */
internal suspend fun fetchAvailableLots(
    context: android.content.Context,
    itemNo: String,
    locationCode: String,
    binCode: String,
    variantCode: String,
): Result<List<JSONObject>> {
    val path = availableLotsPath(itemNo, locationCode, binCode, variantCode)
    var page = BcApi.getAllPages(context, path)
    repeat(2) { attempt ->
        val error = page.error
        if (page.complete || error == null || !BcApi.isRetryableConnectionFailure(error)) return@repeat
        delay(if (attempt == 0) 250L else 650L)
        page = BcApi.getAllPages(context, path)
    }
    if (!page.complete) {
        Log.e(
            "BCWMS-Lots",
            "availableLots incomplete: http=${page.error?.httpCode}, body=${page.error?.body.orEmpty().take(500)}",
        )
        val code = page.error?.httpCode?.takeIf { it != 0 }
        val detail = page.error?.body
            ?.takeIf { it.isNotBlank() }
            ?.let(BcApi::errorMessage)
            ?.take(180)
        val message = buildString {
            append("Stoktaki lotların tamamı alınamadı. Bağlantıyı kontrol edip yeniden deneyin.")
            if (code != null) append(" (HTTP $code)")
            if (!detail.isNullOrBlank()) append(" — $detail")
        }
        return Result.failure(IllegalStateException(message))
    }
    Log.d(
        "BCWMS-Lots",
        "availableLots complete: path=$path, rows=${page.rows.size}, " +
            "balances=${page.rows.joinToString(limit = 20) { row ->
                "${row.optString("lotNo")}@${row.optString("binCode")}:${row.opt("quantityBase")}" 
            }}",
    )
    return Result.success(
        page.rows
            .filter { it.optString("lotNo").isNotBlank() && it.optDouble("quantityBase", 0.0) > 0.0 }
            .sortedBy { it.optString("lotNo") }
    )
}

internal fun availableLotsPath(
    itemNo: String,
    locationCode: String,
    binCode: String,
    variantCode: String,
): String {
    fun safe(value: String) = value.replace("'", "''")
    val filters = buildList {
        add("itemNo eq '${safe(itemNo)}'")
        if (locationCode.isNotBlank()) add("locationCode eq '${safe(locationCode)}'")
        if (binCode.isNotBlank()) add("binCode eq '${safe(binCode)}'")
        if (variantCode.isNotBlank()) add("variantCode eq '${safe(variantCode)}'")
        add("lotNo ne ''")
    }.joinToString(" and ")
    // availableLots bir BC Query API'sidir; Query nesnelerinde sunucu tarafı OrderBy
    // desteklenmez (HTTP 501). Sonuç aşağıda cihazda sıralandığı için yalnız filtrele.
    return "availableLots?\$filter=$filters&\$top=200"
}
