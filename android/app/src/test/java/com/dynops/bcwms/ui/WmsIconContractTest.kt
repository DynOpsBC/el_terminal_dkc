package com.dynops.bcwms.ui

import com.dynops.bcwms.Screen
import org.junit.Assert.assertEquals
import org.junit.Test

class WmsIconContractTest {
    @Test
    fun `every application screen has a deliberate vector glyph`() {
        val mapped = Screen.entries.map(::glyphForScreen)

        assertEquals(Screen.entries.size, mapped.size)
        assertEquals("Her ana ekran kendi ikonuna sahip olmalı", mapped.size, mapped.distinct().size)
    }
}
