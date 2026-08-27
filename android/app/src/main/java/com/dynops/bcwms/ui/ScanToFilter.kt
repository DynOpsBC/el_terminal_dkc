package com.dynops.bcwms.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dynops.bcwms.BcApi
import com.dynops.bcwms.scanner.BarcodeIntentResolver
import com.dynops.bcwms.scanner.BarcodeKind
import com.dynops.bcwms.scanner.ResolvedBarcode
import com.dynops.bcwms.scanner.ScanBus
import org.json.JSONObject

/**
 * "Paletten ekrana" (scan-to-filter) — müşteri toplantısının 1 numaralı isteği.
 *
 * Depocu ürünü listeden seçmeden, eline aldığı ürünün barkodunu okutur; sistem
 * belgedeki ilgili satır(lar)ı bulur:
 *   - tek eşleşme  → [DocumentScanHandler.onSingleMatch] (çağıran taraf miktar
 *                    ekranını açar; "40 var, alıyor musun?")
 *   - çok eşleşme  → [DocumentScanHandler.onMultiMatch] (liste o ürüne filtrelenir,
 *                    kullanıcı hangi satır olduğunu seçer)
 *   - eşleşme yok  → [DocumentScanHandler.onNoMatch]  ("bu barkod bu belgede yok")
 *
 * Yalnız donanım tarayıcı (Zebra/Honeywell) [ScanBus] event'lerini dinler; kamera
 * taraması var olan `ScanField` / `ScanItemSheet` üzerinden akmaya devam eder.
 */

/** Okutulan barkodu satırlara eşleştirir (itemNo veya satıcı barkodu; case-insensitive). */
fun matchLinesByBarcode(
    lines: List<JSONObject>,
    resolved: ResolvedBarcode,
    matchKeys: List<String> = listOf("itemNo", "itemReference"),
): List<JSONObject> {
    val needle = (resolved.itemNo ?: resolved.value).trim()
    if (needle.isBlank()) return emptyList()
    return lines.filter { ln ->
        matchKeys.any { key ->
            val v = ln.optString(key)
            v.isNotBlank() && v != "null" && v.equals(needle, ignoreCase = true)
        }
    }
}

/**
 * Bir belge ekranına yerleştirilen görünmez tarama dinleyicisi. [enabled] false
 * iken (bir dialog/sheet açıkken) devre dışı kalır; böylece modal'ın kendi
 * `ScanField`'i ile aynı taramayı iki kez işlemez.
 */
@Composable
fun DocumentScanHandler(
    enabled: Boolean,
    lines: List<JSONObject>,
    matchKeys: List<String> = listOf("itemNo", "itemReference"),
    onSingleMatch: (JSONObject, ResolvedBarcode) -> Unit,
    onMultiMatch: (String, ResolvedBarcode) -> Unit,
    onNoMatch: (ResolvedBarcode) -> Unit,
) {
    // rememberUpdatedState: dinleyici yeniden başlatılmadan her zaman en güncel
    // satır listesini görür (belge reload olduğunda tarama kaçmasın).
    val currentLines by rememberUpdatedState(lines)
    val singleCb by rememberUpdatedState(onSingleMatch)
    val multiCb by rememberUpdatedState(onMultiMatch)
    val noneCb by rememberUpdatedState(onNoMatch)
    LaunchedEffect(enabled) {
        if (!enabled) return@LaunchedEffect
        ScanBus.events.collect { event ->
            val resolved = BarcodeIntentResolver.resolve(event.raw)
            val matches = matchLinesByBarcode(currentLines, resolved, matchKeys)
            when {
                matches.size == 1 -> singleCb(matches[0], resolved)
                matches.size > 1 -> multiCb((resolved.itemNo ?: resolved.value).trim(), resolved)
                else -> noneCb(resolved)
            }
        }
    }
}

/**
 * Belge LİSTESİ tarama dinleyicisi — "20 belge arasında girme-çıkma olmasın":
 * ürün barkodu okutunca, o ürünü içeren belgeleri satır-endpoint'inden bulur.
 *   - [onResult] (itemNo, docNumbers): çağıran taraf tek belgeyse açar, çoklaysa
 *     listeyi o belgelere filtreler.
 * [linesEndpoint] ör. "receiptLines"/"pickLines"; [docKey] belge anahtar alanı.
 */
@Composable
fun DocListScanHandler(
    enabled: Boolean,
    linesEndpoint: String,
    docKey: String = "no",
    // Belge barkodu (ör. RE000035 / %R%RE000035) okutulunca belgeyi doğrudan açmak için:
    documentsEndpoint: String? = null,        // belgelerin API endpoint'i (aç + doğrula), ör. "receipts"
    acceptDocTypes: Set<String> = emptySet(), // bu ekranın açtığı belge türleri, ör. setOf("receipt")
    onDocument: ((docNo: String) -> Unit)? = null,
    onError: ((message: String) -> Unit)? = null,
    onResult: (itemNo: String, docs: Set<String>) -> Unit,
) {
    val context = LocalContext.current
    val cb by rememberUpdatedState(onResult)
    val docCb by rememberUpdatedState(onDocument)
    LaunchedEffect(enabled, linesEndpoint) {
        if (!enabled) return@LaunchedEffect
        ScanBus.events.collect { ev ->
            val resolved = BarcodeIntentResolver.resolve(ev.raw)
            // 1) Belge barkodu → belgeyi doğrudan aç (bu ekranın türlerinden biriyse).
            if (resolved.kind == BarcodeKind.Document && docCb != null &&
                (acceptDocTypes.isEmpty() || resolved.docType in acceptDocTypes)
            ) {
                val docNo = resolved.value.trim()
                val exists = if (documentsEndpoint == null) true else {
                    val safe = docNo.replace("'", "''")
                    val r = BcApi.get(context, "$documentsEndpoint?\$filter=$docKey eq '$safe'&\$top=1&\$select=$docKey")
                    r.ok && BcApi.parseValueArray(r.body).isNotEmpty()
                }
                if (exists) { docCb?.invoke(docNo); return@collect }
                // Belge bulunamadıysa (yanlış ekran / kapalı belge) ürün aramasına düş.
            }
            // 2) Ürün barkodu → o ürünü içeren belgeleri bul (mevcut davranış).
            val itemNo = (resolved.itemNo ?: resolved.value).trim()
            if (itemNo.isBlank()) return@collect
            val safe = itemNo.replace("'", "''")
            val page = BcApi.getAllPages(context, "$linesEndpoint?\$filter=itemNo eq '$safe'&\$top=100&\$select=$docKey")
            if (!page.complete) {
                onError?.invoke("HATA: Ürün-belge eşleşmelerinin tamamı alınamadı. Yenileyip tekrar okutun.")
                return@collect
            }
            val docs = page.rows.map { it.optString(docKey) }.filter { it.isNotBlank() }.toSet()
            cb(itemNo, docs)
        }
    }
}

/**
 * Yazılan arama metnini ÜRÜN no olarak da dener: o ürünü satırlarında içeren
 * belgelerin no'larını döndürür (ör. Mal Kabul aramasına "1002" yazınca 1002'li
 * PO/WR'lar da listede kalır). DocListScanHandler'daki sorgunun yazılı-arama eşi.
 */
suspend fun docsContainingItem(
    context: android.content.Context,
    linesEndpoint: String,
    itemNo: String,
    docKey: String = "no",
): Set<String>? {
    val safe = itemNo.trim().replace("'", "''")
    if (safe.isBlank()) return emptySet()
    val page = BcApi.getAllPages(context, "$linesEndpoint?\$filter=itemNo eq '$safe'&\$top=100&\$select=$docKey")
    return if (page.complete) page.rows.map { it.optString(docKey) }.filter { it.isNotBlank() }.toSet()
    else null
}

/** Aktif tarama filtresini gösteren, temizlenebilir çip. Boş filtrede hiçbir şey çizmez. */
@Composable
fun ScanFilterChip(filter: String, onClear: () -> Unit) {
    if (filter.isBlank()) return
    Surface(
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
    ) {
        Row(
            Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Filtre: $filter",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                "✕ temizle",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable { onClear() },
            )
        }
    }
}
