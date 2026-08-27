package com.dynops.bcwms

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountCapabilitiesTest {
    @Test
    fun `current metadata enables all protected count operations`() {
        val metadata = """
            <Action Name="addUnexpectedItem" />
                <Action Name="addUnexpectedLp" />
                <Action Name="prepareV2" />
                <Action Name="scanV2Label" />
                <Action Name="undoV2Scan" />
            <Property Name="counted1" /><Property Name="counted2" /><Property Name="counted3" />
        """.trimIndent()

        val result = BcApi.parseCountCapabilities(metadata)

        assertTrue(result.metadataLoaded)
        assertTrue(result.unexpectedItemAction)
        assertTrue(result.unexpectedLpAction)
        assertTrue(result.explicitZeroCount)
        assertTrue(result.v2Ready)
        assertTrue(result.varianceReady)
    }

    @Test
    fun `legacy metadata blocks protected count operations`() {
        val metadata = """
            <Action Name="attachLpToBin" />
            <Property Name="countedQty1" /><Property Name="countedQty2" /><Property Name="countedQty3" />
        """.trimIndent()

        val result = BcApi.parseCountCapabilities(metadata)

        assertFalse(result.unexpectedItemAction)
        assertFalse(result.unexpectedLpAction)
        assertFalse(result.explicitZeroCount)
        assertFalse(result.v2Ready)
        assertFalse(result.varianceReady)
    }
}
