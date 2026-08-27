package com.dynops.bcwms.feature

import android.content.Context
import com.dynops.bcwms.BcApi

internal enum class LpPurpose { PALLET, CARTON }

/**
 * Şirket özel kodu uygulamaya gömmek yerine, BC'deki LP şablonlarından amacı
 * açıkça eşleşeni seçer. Belirsiz çoklu listede yanlış şablonla LP yaratmaz.
 */
internal fun chooseLpTemplate(rows: List<Pair<String, String>>, purpose: LpPurpose): String? {
    val valid = rows.mapNotNull { (rawCode, description) ->
        val code = rawCode.trim()
        if (code.isBlank()) null else code to description
    }
    if (valid.size == 1) return valid.single().first
    val preferredCodes = when (purpose) {
        LpPurpose.PALLET -> listOf("PALLET-EUR")
        LpPurpose.CARTON -> listOf("CARTON-S")
    }
    preferredCodes.firstNotNullOfOrNull { preferred ->
        valid.firstOrNull { (code, _) -> code.equals(preferred, ignoreCase = true) }?.first
    }?.let { return it }
    val tokens = when (purpose) {
        LpPurpose.PALLET -> listOf("pallet", "palet")
        LpPurpose.CARTON -> listOf("carton", "koli", "kutu")
    }
    val matches = valid.filter { (code, description) ->
        val haystack = "$code $description"
        tokens.any { haystack.contains(it, ignoreCase = true) }
    }
    return matches.singleOrNull()?.first
}

internal suspend fun resolveLpTemplate(context: Context, purpose: LpPurpose): String? {
    val page = BcApi.getAllPages(context, "licensePlateTemplates?\$top=100&\$select=code,description")
    if (!page.complete) return null
    return chooseLpTemplate(
        page.rows.map { it.optString("code") to it.optString("description") },
        purpose,
    )
}
