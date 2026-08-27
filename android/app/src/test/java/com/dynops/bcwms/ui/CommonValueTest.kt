package com.dynops.bcwms.ui

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class CommonValueTest {
    @Test
    fun rawValueKeepsMissingApiFieldsEmpty() {
        val row = JSONObject().put("variantCode", "").put("nullField", JSONObject.NULL)

        assertEquals("", rawValue(row, "variantCode"))
        assertEquals("", rawValue(row, "nullField"))
        assertEquals("", rawValue(row, "missing"))
    }

    @Test
    fun rawValueUsesFirstRealFallbackWithoutInventingPlaceholder() {
        val row = JSONObject().put("lineLocation", "").put("headerLocation", "MERKEZDEPO")

        assertEquals("MERKEZDEPO", rawValue(row, "lineLocation", "headerLocation"))
        assertEquals("-", firstValue(row, "missing"))
    }
}
