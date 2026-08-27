package com.dynops.bcwms.feature

import android.util.Log
import com.dynops.bcwms.ui.operatorFacingApiError

/**
 * Quality-related API error parser.
 *
 * MS Quality Management + DOPSWHS workflow events block Picks / Put-Aways
 * when a referenced lot/serial/package has an open Quality Inspection that
 * has not yet finished with a passing result. BC surfaces these blocks as
 * error responses on the bound action call.
 *
 * This helper detects the QC-block signature in the error text and pulls
 * out the inspection no. when present, so the mobile UI can show a
 * friendly banner ("Lot blocked by QC inspection INS-001 — bekle veya
 * Quality modülünden tamamla") instead of a raw HTTP error.
 *
 * Used by:
 * - PickingModule.kt (assignToMe / register / markShort actions)
 * - PutAwayShipModules.kt (Put-Away register, Shipment post)
 */
object QcErrorParser {

    private val INSPECTION_NO_REGEX = Regex("""\b(?:INS|QI|Q|QM)[\-_]?\d{1,8}\b""")
    private val QC_KEYWORDS = listOf("quality", "inspection", "qc", "blocked", "blok")

    /** True if the error text matches a Quality / Inspection block. */
    fun isQcBlocked(errMsg: String?): Boolean {
        if (errMsg.isNullOrBlank()) return false
        val lower = errMsg.lowercase()
        val hasKeyword = QC_KEYWORDS.count { lower.contains(it) } >= 2
        return hasKeyword || INSPECTION_NO_REGEX.containsMatchIn(errMsg)
    }

    /** Inspection no. if mentioned, else null. */
    fun extractInspectionNo(errMsg: String?): String? {
        if (errMsg.isNullOrBlank()) return null
        return INSPECTION_NO_REGEX.find(errMsg)?.value
    }

    /**
     * UI-friendly status line for a QC-blocked error. Falls back to the
     * original error if no inspection no. is found.
     */
    fun friendlyStatus(errMsg: String?, httpCode: Int = 0): String {
        val raw = errMsg ?: "Bilinmeyen hata"
        runCatching { Log.w("BCWMS.ApiError", "HTTP $httpCode ${raw.take(2000)}") }
        if (!isQcBlocked(raw)) return operatorFacingApiError(raw, httpCode)
        val ins = extractInspectionNo(raw)
        val tail = if (ins != null) "Kalite denetimi $ins tamamlanmalı." else "Açık kalite denetimi tamamlanmalı."
        return "🔬 Kalite kontrolü bekliyor — lot/seri kullanılamıyor. $tail"
    }
}
