package com.dynops.bcwms.ui

import org.json.JSONObject

/**
 * İade satır birleştirme — müşteri isteği: aynı ürün farklı belgelerden/satırlardan
 * gelince (ör. 10 farklı siparişten aynı iade), depocu tek okutmada hepsini alsın.
 *
 * Birleştirme anahtarı: **Lokasyon/Bin + Ürün + Varyant**. Lot/Seri FARKLI ise
 * ayrık kalır (yanlış birleşmesin). Kullanıcı grup üzerinde bir miktar girince,
 * bu miktar grubun alt satırlarına outstanding'e göre dağıtılır ([distributeQty]).
 */
data class LineGroup(
    val key: String,
    val itemNo: String,
    val description: String,
    val binCode: String,
    val variantCode: String,
    val lines: List<JSONObject>,
    val totalOutstanding: Double,
) {
    val count: Int get() = lines.size
}

enum class ScannedGroupIssue {
    ItemMissing,
    TrackingMismatch,
    Ambiguous,
}

data class ScannedGroupSelection(
    val group: LineGroup? = null,
    val issue: ScannedGroupIssue? = null,
)

/**
 * Selects the exact item/lot/serial group represented by a scanned barcode.
 *
 * A pick can contain the same item more than once with different tracking
 * values. Picking the first item group in that case can write LOT-B against the
 * LOT-A warehouse line. Tracking is therefore matched before a group is
 * returned and an untracked scan is rejected whenever it is ambiguous.
 */
fun selectScannedLineGroup(
    groups: List<LineGroup>,
    itemNo: String,
    lotNo: String = "",
    serialNo: String = "",
): ScannedGroupSelection {
    val itemGroups = groups.filter { it.itemNo.equals(itemNo.trim(), ignoreCase = true) }
    if (itemGroups.isEmpty()) return ScannedGroupSelection(issue = ScannedGroupIssue.ItemMissing)

    val expectedLot = lotNo.trim()
    val expectedSerial = serialNo.trim()
    val hasTracking = expectedLot.isNotBlank() || expectedSerial.isNotBlank()
    val matchingGroups = if (!hasTracking) itemGroups else itemGroups.filter { group ->
        group.lines.any { line ->
            val lineLot = s(line, "lotNo")
            val lineSerial = s(line, "serialNo")
            (expectedLot.isBlank() || lineLot.equals(expectedLot, ignoreCase = true)) &&
                (expectedSerial.isBlank() || lineSerial.equals(expectedSerial, ignoreCase = true))
        }
    }

    if (hasTracking && matchingGroups.isEmpty())
        return ScannedGroupSelection(issue = ScannedGroupIssue.TrackingMismatch)
    if (matchingGroups.size != 1)
        return ScannedGroupSelection(issue = ScannedGroupIssue.Ambiguous)
    return ScannedGroupSelection(group = matchingGroups.single())
}

private fun s(o: JSONObject, key: String): String {
    val v = o.optString(key)
    return if (v == "null") "" else v
}

/**
 * Satırları ürün+bin+varyant+(lot/seri) anahtarıyla gruplar. Lot/Seri dolu ve
 * farklıysa gruplar ayrılır. [capacity] her satırın kalan (doldurulabilir)
 * miktarını verir; modülden modüle farklı hesaplanır.
 */
fun groupLines(lines: List<JSONObject>, capacity: (JSONObject) -> Double): List<LineGroup> {
    val order = LinkedHashMap<String, MutableList<JSONObject>>()
    for (ln in lines) {
        val item = s(ln, "itemNo")
        val bin = s(ln, "binCode")
        val variant = s(ln, "variantCode")
        // Lot/seri dolu ise anahtara ekle → farklı lot/seri birleşmez.
        val lot = s(ln, "lotNo")
        val serial = s(ln, "serialNo")
        val key = listOf(item, bin, variant, lot, serial).joinToString("|")
        order.getOrPut(key) { mutableListOf() }.add(ln)
    }
    return order.map { (key, group) ->
        val first = group.first()
        LineGroup(
            key = key,
            itemNo = s(first, "itemNo"),
            description = firstValue(first, "description"),
            binCode = s(first, "binCode"),
            variantCode = s(first, "variantCode"),
            lines = group,
            totalOutstanding = group.sumOf { capacity(it) },
        )
    }
}

/**
 * Girilen [qty]'yi grubun satırlarına kapasite sırasıyla dağıtır. Her satır kendi
 * kapasitesi kadar dolar, kalan bir sonrakine geçer.
 * Döndürür: (satır, o satıra yazılacak miktar) — miktar 0'dan büyük olanlar.
 */
fun distributeQty(group: LineGroup, qty: Double, capacity: (JSONObject) -> Double): List<Pair<JSONObject, Double>> {
    var remaining = qty
    val out = mutableListOf<Pair<JSONObject, Double>>()
    for (ln in group.lines) {
        if (remaining <= 0.0) break
        val cap = capacity(ln).takeIf { it > 0 } ?: remaining
        val take = minOf(cap, remaining)
        if (take > 0) { out.add(ln to take); remaining -= take }
    }
    return out
}
