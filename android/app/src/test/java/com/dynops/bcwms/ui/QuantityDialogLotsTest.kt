package com.dynops.bcwms.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QuantityDialogLotsTest {
    @Test
    fun `available lots query does not send unsupported order by`() {
        val path = availableLotsPath("AB.00005", "MERKEZDEPO", "A.A01.11", "")

        assertFalse(path.contains("\$orderby", ignoreCase = true))
        assertTrue(path.contains("itemNo eq 'AB.00005'"))
        assertTrue(path.contains("locationCode eq 'MERKEZDEPO'"))
        assertTrue(path.contains("binCode eq 'A.A01.11'"))
        assertFalse(path.contains("variantCode"))
        assertTrue(path.endsWith("&\$top=200"))
    }
}
