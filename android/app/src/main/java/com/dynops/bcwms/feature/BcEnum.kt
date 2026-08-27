package com.dynops.bcwms.feature

/**
 * BC OData enum literal constants used in mobile composite-key strings.
 *
 * Hardcoding these inside calling code (e.g. "Put-away" in PutAwayShipModules) led to 404s
 * whenever the BC OData representation changed casing or spelling. Centralising them here
 * matches the way BC serialises Option/Enum members over OData v4 — exactly as published
 * by the page's source table.
 */
object BcEnum {

    /** Warehouse Activity Header.Type enum values as serialised over OData. */
    object WhseActivityType {
        const val PICK = "Pick"
        const val PUT_AWAY = "Put-away"   // Hyphen + lowercase 'a' matches BC's option caption.
        const val MOVEMENT = "Movement"
        const val INVT_PUT_AWAY = "Invt. Put-away"
        const val INVT_PICK = "Invt. Pick"
        const val INVT_MOVEMENT = "Invt. Movement"
    }

    /** Assembly Header.Document Type enum values. */
    object AssemblyDocType {
        const val QUOTE = "Quote"
        const val ORDER = "Order"
        const val BLANKET = "Blanket Order"
    }

    /** Prod. Order header status values used by Order Components / Routing Lines composite keys. */
    object ProdOrderStatus {
        const val SIMULATED = "Simulated"
        const val PLANNED = "Planned"
        const val FIRM_PLANNED = "Firm Planned"
        const val RELEASED = "Released"
        const val FINISHED = "Finished"
    }

    /**
     * BC serialises Option/Enum members with non-identifier characters escaped as _xNNNN_
     * (e.g. "Put-away" -> "Put_x002D_away") over OData. The underlying table's key/filter
     * expects the real option string, so decode the escapes before putting an echoed enum
     * value into a composite-key segment.
     */
    fun decodeOData(value: String): String {
        if (!value.contains("_x")) return value
        return Regex("_x([0-9A-Fa-f]{4})_").replace(value) { m ->
            m.groupValues[1].toInt(16).toChar().toString()
        }
    }
}
