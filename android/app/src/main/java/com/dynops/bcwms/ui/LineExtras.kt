package com.dynops.bcwms.ui

import androidx.compose.material3.CardColors
import androidx.compose.material3.CardDefaults
import androidx.compose.runtime.Composable
import org.json.JSONObject

/**
 * Satır kartı yardımcıları — müşteri toplantısı istekleri:
 *   - "yapılan satır belli olsun" → [lineDone] + [doneCardColors] (yeşil kart + ✓)
 *   - "ürün no+isim yetmiyor"     → [extraFieldsText] (UoM/Varyant/Satıcı barkodu/Açıklama 2)
 *
 * "Done" yüklemi, ilgili modülün Register/Post butonunu etkinleştiren miktar
 * alanıyla (bkz. ActionGuards.hasQuantity) birebir aynı sinyali kullanır: bir
 * satır tam olarak post/register'a katkı sağladığında yeşil olur.
 */
enum class LineModule { RECEIPT, PURCHASE, PICK, PUTAWAY, SHIPMENT, SALES, COUNT }

/**
 * Bir satırın operatör tarafından TAM işlenmiş ("yapıldı") sayılıp sayılmayacağı.
 * Pick/PutAway'de "yeşil" yalnız girilen miktar KALANIN TAMAMINI kapatıyorsa —
 * kısmi girişte satır yeşile boyanıp "bitti" izlenimi vermesin ([linePartial]
 * o durumu sarı gösterir). Sunucu qtyOutstanding göndermiyorsa (eski AL sürümü)
 * eski davranışa (miktar girildiyse yeşil) düşer.
 */
fun lineDone(ln: JSONObject, module: LineModule): Boolean = when (module) {
    LineModule.RECEIPT, LineModule.PURCHASE -> ln.optDouble("qtyToReceive", 0.0) > 0.0
    LineModule.PICK, LineModule.PUTAWAY -> {
        val toHandle = ln.optDouble("qtyToHandle", 0.0)
        val outstanding = ln.optDouble("qtyOutstanding", Double.NaN)
        if (outstanding.isNaN()) toHandle > 0.0 else toHandle > 0.0 && toHandle >= outstanding
    }
    LineModule.SHIPMENT, LineModule.SALES -> ln.optDouble("qtyToShip", 0.0) > 0.0
    LineModule.COUNT -> listOf("countedQty1", "countedQty2", "countedQty3")
        .any { ln.optDouble(it, 0.0) != 0.0 }
}

/**
 * Satır KISMEN işlenmiş mi: daha önce register edilmiş bir parça var (qtyHandled>0)
 * ya da girilen miktar kalanın sadece bir kısmını kapatıyor. Grid'de sarı gösterilir.
 */
fun linePartial(ln: JSONObject, module: LineModule): Boolean = when (module) {
    LineModule.PICK, LineModule.PUTAWAY -> {
        val handled = ln.optDouble("qtyHandled", 0.0)
        val toHandle = ln.optDouble("qtyToHandle", 0.0)
        val outstanding = ln.optDouble("qtyOutstanding", Double.NaN)
        handled > 0.0 || (!outstanding.isNaN() && toHandle > 0.0 && toHandle < outstanding)
    }
    else -> false
}

/** İşlenmiş satır için yeşil (success) tonlu kart rengi; aksi halde varsayılan. */
@Composable
fun doneCardColors(done: Boolean): CardColors =
    if (done) CardDefaults.cardColors(containerColor = bcwmsStatus().success.copy(alpha = 0.14f))
    else CardDefaults.cardColors()

/** Kart başlığında satırın yapıldığını gösteren işaret ("✓ " ya da boş). */
fun donePrefix(done: Boolean): String = if (done) "✓ " else ""

private fun firstNonBlank(obj: JSONObject, vararg keys: String): String? {
    for (k in keys) {
        val v = obj.optString(k)
        if (v.isNotBlank() && v != "null") return v
    }
    return null
}

/**
 * Satır kartının ikincil bilgi satırı — kullanıcının [FieldPrefs]'te AÇIK bıraktığı
 * ve satırda dolu olan opsiyonel alanlar. Ürün no+isim ayırt edici olmadığında
 * (benzer isimli ürünler) yardımcı olur; hangi alanların görüneceği Alan Ayarları
 * ekranından kişiselleştirilir.
 */
fun extraFieldsText(ln: JSONObject): String {
    val parts = buildList {
        if (FieldPrefs.isOn("uom")) firstNonBlank(ln, "unitOfMeasureCode", "uomCode")?.let { add("UOM $it") }
        if (FieldPrefs.isOn("variant")) firstNonBlank(ln, "variantCode")?.let { add("Varyant $it") }
        if (FieldPrefs.isOn("itemRef")) firstNonBlank(ln, "itemReference")?.let { add("Brkd $it") }
        if (FieldPrefs.isOn("lot")) firstNonBlank(ln, "lotNo", "serialNo")?.let { add("Lot $it") }
        if (FieldPrefs.isOn("desc2")) firstNonBlank(ln, "description2")?.let { add(it) }
    }
    return parts.joinToString(" · ")
}
