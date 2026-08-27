package com.dynops.bcwms.feature

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PackingWorkflowTest {
    @Test
    fun `missing packing endpoint tells the operator to contact support`() {
        val message = packingStartFailureMessage(404)
        assertTrue(message.contains("hazır değil"))
        assertTrue(message.contains("yöneticinize"))
    }

    @Test
    fun `transient packing failure offers a retryable connection message`() {
        assertTrue(packingStartFailureMessage(503).contains("tekrar deneyin"))
    }

    @Test
    fun `same hardware scan inside debounce window is ignored`() {
        assertFalse(shouldAcceptPackingScan("ITEM-1", "item-1", 1_000, 1_100))
    }

    @Test
    fun `same item after debounce or a different item is accepted`() {
        assertTrue(shouldAcceptPackingScan("ITEM-1", "ITEM-1", 1_000, 1_251))
        assertTrue(shouldAcceptPackingScan("ITEM-2", "ITEM-1", 1_000, 1_010))
    }

    @Test
    fun `blank packing scan is rejected`() {
        assertFalse(shouldAcceptPackingScan("", "", 0, 100))
    }

    @Test
    fun `same box barcode cannot be assigned to another order`() {
        val existing = listOf("SO-1" to "BOX-001")
        assertTrue(packingBoxHasConflict("SO-2", "box-001", existing))
        assertFalse(packingBoxHasConflict("SO-1", "BOX-001", existing))
        assertFalse(packingBoxHasConflict("SO-2", "", existing))
    }

    @Test
    fun `box close waits for all optimistic item writes`() {
        assertTrue(packingCanCloseOrder(busy = false, pendingItemWrites = 0))
        assertFalse(packingCanCloseOrder(busy = false, pendingItemWrites = 1))
        assertFalse(packingCanCloseOrder(busy = true, pendingItemWrites = 0))
    }
}
