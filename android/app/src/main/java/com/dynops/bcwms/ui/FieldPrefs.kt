package com.dynops.bcwms.ui

import android.content.Context
import androidx.compose.runtime.mutableStateMapOf

/**
 * Kullanıcının seçtiği görünür satır alanları — Warehouse Insight'ın uzun-bas
 * "kolon seçimi" ekranının karşılığı. Her firma/kullanıcı, satır kartlarında
 * hangi ek alanların görüneceğini kendisi açıp kapatır.
 *
 * Tercihler cihazda (SharedPreferences) kalıcıdır. Değerler Compose snapshot
 * state'inde tutulduğu için, ayar değişince açık olan tüm satır ekranları
 * otomatik yeniden çizilir. [extraFieldsText] bu tercihleri okur.
 *
 * Not: Bu sürüm cihaz-yerel ve global (tüm ekranlar için ortak). Firma-geneli
 * merkezi konfig (BC üzerinden) ve ekran-bazlı granülerlik Phase 2.
 */
data class LineFieldDef(val key: String, val label: String, val hint: String, val default: Boolean)

object FieldPrefs {
    private const val PREFS = "dopswhs_field_prefs"

    /** Kişiselleştirilebilir ek alanlar (satır kartı ikincil satırında). */
    val fields = listOf(
        LineFieldDef("uom", "Ölçü Birimi (UOM)", "Adet / Koli / Palet", true),
        LineFieldDef("variant", "Varyant", "Renk/beden vb. varyant kodu", true),
        LineFieldDef("itemRef", "Satıcı Barkodu", "Ürün Referansı (sipariş satırlarında)", true),
        LineFieldDef("lot", "Lot / Seri No", "Satırdaki lot veya seri numarası", false),
        LineFieldDef("desc2", "Açıklama 2", "Ürünün ikinci açıklama satırı", false),
    )

    private val state = mutableStateMapOf<String, Boolean>()
    private var loaded = false

    /** Idempotent: her recomposition'da güvenle çağrılabilir, yalnız ilk sefer okur. */
    fun load(context: Context) {
        if (loaded) return
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        fields.forEach { state[it.key] = p.getBoolean(it.key, it.default) }
        loaded = true
    }

    /** Snapshot-okuması: composable içinden çağrılınca değişimde recompose tetikler. */
    fun isOn(key: String): Boolean = state[key] ?: fields.firstOrNull { it.key == key }?.default ?: false

    fun set(context: Context, key: String, value: Boolean) {
        state[key] = value
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(key, value).apply()
    }
}
