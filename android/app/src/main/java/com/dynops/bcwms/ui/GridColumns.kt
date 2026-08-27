package com.dynops.bcwms.ui

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Konfigüre edilebilir tablo kolonları — Warehouse Insight "Choose Columns"
 * pariteti. Her ekran (screenKey) için mevcut kolon tanımları + kullanıcının
 * seçtiği görünürlük/sıra/genişlik cihazda saklanır. Satırlar kart yerine
 * gerçek bir grid'de (başlık satırı + kolonlar) çizilir ([LineGrid]).
 */
data class GridColumn(
    val key: String,
    val label: String,
    val defaultVisible: Boolean,
    val defaultWidth: Int,          // dp
    val value: (JSONObject) -> String,
)

/** Kullanıcının bir kolon için seçtiği durum (sıra listedeki konumdan gelir). */
data class ColumnState(val key: String, val visible: Boolean, val width: Int)

private fun fmtCol(v: Double): String =
    if (v == v.toLong().toDouble()) v.toLong().toString() else "%.2f".format(v).trimEnd('0').trimEnd('.')

private fun nz(o: JSONObject, key: String): String {
    val v = o.optString(key); return if (v == "null") "" else v
}

/** Warehouse Activity Line.Action Type (wire) → ekranda gösterilen Türkçe etiket. */
private fun actionTypeLabel(actionType: String): String = when (actionType) {
    "Take" -> "Al"
    "Place" -> "Koy"
    else -> actionType
}

/** Ekran-bazlı kolon tanımları (mevcut olabilecek tüm kolonlar). */
object GridColumns {

    val receipt = listOf(
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("openQty", "Açık Mik.", true, 84) {
            val q = it.optDouble("quantity"); val r = it.optDouble("qtyReceived")
            fmtCol(if (q > 0) (q - r) else it.optDouble("qtyToReceive"))
        },
        GridColumn("uom", "UOM", true, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("gtin", "GTIN", true, 116) { nz(it, "gtin").ifBlank { nz(it, "itemReference") } },
        // BC'de zaten atanmış (veya mobilden girilmiş) lot/seri burada görünür —
        // Item Tracking Lines ile çift yönlü senkron.
        GridColumn("lotNo", "Lot No.", true, 96) { nz(it, "lotNo") },
        GridColumn("serialNo", "Seri No.", false, 96) { nz(it, "serialNo") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
        GridColumn("description2", "Açıklama 2", false, 150) { nz(it, "description2") },
        GridColumn("toReceive", "Girilen", false, 76) { fmtCol(it.optDouble("qtyToReceive")) },
        GridColumn("received", "Alınan", false, 76) { fmtCol(it.optDouble("qtyReceived")) },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    /**
     * Satın Alma Siparişi (PO) satırları. Ambar Mal Kabul'den AYRI bir kolon
     * seti: PO API'si farklı alan adları döndürüyor
     * (outstandingQuantity / qtyToReceive / qtyReceived).
     */
    val purchaseOrder = listOf(
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("description", "Açıklama", true, 170) { nz(it, "description") },
        GridColumn("outstanding", "Kalan", true, 76) { fmtCol(it.optDouble("outstandingQuantity")) },
        GridColumn("toReceive", "Alınacak", true, 84) { fmtCol(it.optDouble("qtyToReceive")) },
        GridColumn("received", "Alınan", true, 76) { fmtCol(it.optDouble("qtyReceived")) },
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("uom", "UOM", true, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("gtin", "GTIN", false, 116) { nz(it, "gtin").ifBlank { nz(it, "itemReference") } },
        GridColumn("lotNo", "Lot No.", false, 96) { nz(it, "lotNo") },
        GridColumn("serialNo", "Seri No.", false, 96) { nz(it, "serialNo") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
        GridColumn("quantity", "Toplam", false, 76) { fmtCol(it.optDouble("quantity")) },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    val pick = listOf(
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("lotNo", "Lot No.", true, 96) { nz(it, "lotNo") },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("toHandle", "Girilen", true, 72) { fmtCol(it.optDouble("qtyToHandle", 0.0)) },
        GridColumn("outstanding", "Kalan", true, 68) { fmtCol(it.optDouble("qtyOutstanding", 0.0)) },
        GridColumn("handled", "Alınan", false, 66) { fmtCol(it.optDouble("qtyHandled", 0.0)) },
        GridColumn("quantity", "Toplam", false, 72) { fmtCol(it.optDouble("quantity", 0.0)) },
        GridColumn("uom", "UOM", true, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("gtin", "GTIN", true, 116) { nz(it, "gtin") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
        GridColumn("lp", "LP", false, 110) { nz(it, "licensePlateNo") },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    val putaway = listOf(
        GridColumn("action", "İşlem", true, 72) { actionTypeLabel(nz(it, "actionType")) },
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        // Kısmi register netliği: Girilen (bu register'da konacak) / Kalan / Konan.
        GridColumn("toHandle", "Girilen", true, 72) { fmtCol(it.optDouble("qtyToHandle", 0.0)) },
        GridColumn("outstanding", "Kalan", true, 68) { fmtCol(it.optDouble("qtyOutstanding", 0.0)) },
        GridColumn("handled", "Konan", true, 66) { fmtCol(it.optDouble("qtyHandled", 0.0)) },
        GridColumn("quantity", "Toplam", false, 72) { fmtCol(it.optDouble("quantity", 0.0)) },
        GridColumn("uom", "UOM", true, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("lp", "LP", true, 110) { nz(it, "lpNo") },
        GridColumn("gtin", "GTIN", false, 116) { nz(it, "gtin") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    val shipment = listOf(
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("toShip", "Sevk Mik.", true, 84) { fmtCol(it.optDouble("qtyToShip")) },
        GridColumn("outstanding", "Kalan", true, 72) { fmtCol(it.optDouble("qtyOutstanding")) },
        GridColumn("uom", "UOM", true, 62) { nz(it, "uomCode") },
        GridColumn("gtin", "GTIN", true, 116) { nz(it, "gtin") },
        GridColumn("lotNo", "Lot No.", true, 96) { nz(it, "lotNo") },
        GridColumn("bin", "Bin", false, 92) { nz(it, "binCode") },
        GridColumn("lp", "LP", false, 110) { nz(it, "licensePlateNo") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    val salesSource = listOf(
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("outstanding", "Kalan", true, 76) { fmtCol(it.optDouble("outstandingQuantity")) },
        GridColumn("toShip", "Sevk Mik.", true, 84) { fmtCol(it.optDouble("qtyToShip")) },
        GridColumn("uom", "UOM", true, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("gtin", "GTIN", false, 116) { nz(it, "itemReference") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    val count = listOf(
        GridColumn("lpNo", "LP", true, 110) { nz(it, "lpNo") },
        GridColumn("itemNo", "Ürün No.", true, 104) { nz(it, "itemNo") },
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("lotNo", "Lot No.", true, 96) { nz(it, "lotNo") },
        GridColumn("serialNo", "Seri No.", false, 96) { nz(it, "serialNo") },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("systemQty", "Sistem", true, 72) { fmtCol(it.optDouble("systemQty")) },
        GridColumn("counted1", "Sayım 1", true, 74) { fmtCol(it.optDouble("countedQty1")) },
        GridColumn("counted2", "Sayım 2", false, 74) { fmtCol(it.optDouble("countedQty2")) },
        GridColumn("counted3", "Sayım 3", false, 74) { fmtCol(it.optDouble("countedQty3")) },
        GridColumn("variance", "Fark", true, 68) { fmtCol(it.optDouble("variance")) },
        GridColumn("uom", "UOM", false, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("variant", "Varyant", false, 84) { nz(it, "variantCode") },
    )

    val consumption = listOf(
        GridColumn("itemNo", "Bileşen", true, 104) { nz(it, "itemNo") },
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("remaining", "Kalan", true, 76) { fmtCol(it.optDouble("remainingQuantity")) },
        GridColumn("quantity", "Toplam", true, 72) { fmtCol(it.optDouble("quantity")) },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("prodOrder", "PÜ No.", true, 104) { nz(it, "prodOrderNo") },
        GridColumn("location", "Lokasyon", false, 84) { nz(it, "locationCode") },
        GridColumn("compLine", "Bileşen Satır", false, 90) { it.optInt("componentLineNo").toString() },
    )

    val output = listOf(
        GridColumn("operationNo", "Operasyon", true, 96) { nz(it, "operationNo") },
        GridColumn("workCenter", "İş Merkezi", true, 100) { nz(it, "workCenterNo") },
        GridColumn("description", "Açıklama", true, 160) { nz(it, "description") },
        GridColumn("runTime", "Süre (dk)", true, 78) { fmtCol(it.optDouble("runTime")) },
        GridColumn("prodOrder", "PÜ No.", true, 104) { nz(it, "prodOrderNo") },
        GridColumn("routingNo", "Rota No.", false, 96) { nz(it, "routingNo") },
    )

    val assembly = listOf(
        GridColumn("itemNo", "Bileşen", true, 104) { nz(it, "itemNo") },
        GridColumn("bin", "Bin", true, 92) { nz(it, "binCode") },
        GridColumn("required", "Gerekli", true, 76) { fmtCol(it.optDouble("quantity")) },
        GridColumn("consumed", "Tüketilen", true, 84) { fmtCol(it.optDouble("consumedQuantity")) },
        GridColumn("description", "Açıklama", false, 170) { nz(it, "description") },
        GridColumn("uom", "UOM", false, 62) { nz(it, "unitOfMeasureCode") },
        GridColumn("location", "Lokasyon", false, 84) { nz(it, "locationCode") },
        GridColumn("lineNo", "Satır", false, 60) { it.optInt("lineNo").toString() },
    )

    fun defs(screenKey: String): List<GridColumn> = when (screenKey) {
        "receipt" -> receipt
        "pick" -> pick
        "putaway" -> putaway
        "shipment" -> shipment
        "salesSource" -> salesSource
        "count" -> count
        "consumption" -> consumption
        "output" -> output
        "assembly" -> assembly
        else -> receipt
    }
}

/** Kolon konfigürasyonunun cihaz-yerel deposu (screenKey bazında). */
object ColumnPrefs {
    private const val PREFS = "dopswhs_columns"

    /** Kayıtlı düzeni döndürür (yoksa tanımların varsayılanı). Yeni eklenen
     *  tanımlar sona eklenir; artık olmayan kayıtlı anahtarlar atılır. */
    fun get(context: Context, screenKey: String, defs: List<GridColumn>): List<ColumnState> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(screenKey, null)
        if (raw.isNullOrBlank()) return defs.map { ColumnState(it.key, it.defaultVisible, it.defaultWidth) }
        val stored = runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getJSONObject(it) }
        }.getOrDefault(emptyList())
        val byKey = defs.associateBy { it.key }
        val result = mutableListOf<ColumnState>()
        val seen = HashSet<String>()
        for (o in stored) {
            val k = o.optString("key")
            val def = byKey[k] ?: continue
            result.add(ColumnState(k, o.optBoolean("visible", def.defaultVisible), o.optInt("width", def.defaultWidth)))
            seen.add(k)
        }
        // yeni tanımları sona ekle
        for (d in defs) if (!seen.contains(d.key)) result.add(ColumnState(d.key, d.defaultVisible, d.defaultWidth))
        return result
    }

    fun save(context: Context, screenKey: String, cols: List<ColumnState>) {
        val arr = JSONArray()
        cols.forEach { arr.put(JSONObject().apply { put("key", it.key); put("visible", it.visible); put("width", it.width) }) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(screenKey, arr.toString()).apply()
    }

    fun reset(context: Context, screenKey: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(screenKey).apply()
    }
}
