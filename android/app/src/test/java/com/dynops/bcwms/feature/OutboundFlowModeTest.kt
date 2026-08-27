package com.dynops.bcwms.feature

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OutboundFlowModeTest {
    @Test
    fun `legacy BC enum values map to V2 operation names`() {
        assertEquals(OutboundFlowMode.Multi, OutboundFlowMode.fromApi("Multi"))
        assertEquals(OutboundFlowMode.Mono, OutboundFlowMode.fromApi("Batch"))
        assertEquals(OutboundFlowMode.SingleSku, OutboundFlowMode.fromApi("Bulk"))
    }

    @Test
    fun `user facing names are accepted case insensitively`() {
        assertEquals(OutboundFlowMode.Mono, OutboundFlowMode.fromApi("mono"))
        assertEquals(OutboundFlowMode.SingleSku, OutboundFlowMode.fromApi("tek sku"))
    }

    @Test
    fun `unknown modes are not silently classified`() {
        assertNull(OutboundFlowMode.fromApi("wave"))
    }
}
