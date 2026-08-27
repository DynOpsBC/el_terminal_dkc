package com.dynops.bcwms.feature

import com.dynops.bcwms.ui.WmsGlyph
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TerminalHelpContentTest {
    @Test
    fun `help covers every warehouse operation with actionable steps`() {
        assertEquals(TerminalHelpTopics.size, TerminalHelpTopics.map { it.id }.distinct().size)
        assertTrue(TerminalHelpTopics.size >= 15)
        assertTrue(TerminalHelpTopics.all { it.steps.size >= 5 })

        listOf("receiving", "shipping", "lp-partial-transfer", "adhoc", "directed", "count-v2")
            .forEach { required -> assertTrue(required, TerminalHelpTopics.any { it.id == required }) }

        assertTrue(
            "Yardım kartlarında emoji/fallback ikon kalmamalı",
            TerminalHelpTopics.none { glyphForHelpTopic(it) == WmsGlyph.HELP },
        )
    }
}
