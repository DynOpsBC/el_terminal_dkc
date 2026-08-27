package com.dynops.bcwms.lib

import org.json.JSONObject

/**
 * Guard helpers that prevent the user from hitting Register/Post when the
 * document has no actionable rows (qtyToHandle = 0). The previous behaviour
 * was to let the BC server reject the call with a raw "There is nothing to
 * post because the document does not contain a quantity or amount" error
 * (PDF section 3 — Mal Kabul). This helper short-circuits that on the UI.
 *
 * Usage:
 *   Button(
 *     enabled = !busy && ActionGuards.hasQuantity(lines),
 *     ...
 *   )
 */
object ActionGuards {

    /**
     * Returns `true` if at least one line in `lines` has a positive value
     * in the named field (default `qtyToHandle`). Empty list → false so
     * empty documents also get disabled.
     */
    fun hasQuantity(lines: List<JSONObject>, field: String = "qtyToHandle"): Boolean {
        if (lines.isEmpty()) return false
        return lines.any { (it.optDouble(field, 0.0)) > 0.0 }
    }

    /**
     * True if every non-skipped line carries a positive quantity. Used in
     * stricter "all-lines-must-be-handled" paths (e.g. Put-Away register).
     */
    fun allLinesHaveQuantity(lines: List<JSONObject>, field: String = "qtyToHandle"): Boolean {
        if (lines.isEmpty()) return false
        return lines.all { (it.optDouble(field, 0.0)) > 0.0 }
    }
}
