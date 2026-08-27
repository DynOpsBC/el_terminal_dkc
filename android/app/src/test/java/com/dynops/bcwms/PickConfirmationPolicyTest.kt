package com.dynops.bcwms

import com.dynops.bcwms.feature.isPickContainerStatusUsable
import com.dynops.bcwms.feature.canMutateAssignedPick
import com.dynops.bcwms.feature.canRegisterAssignedPick
import com.dynops.bcwms.feature.pickReadyToRegister
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PickConfirmationPolicyTest {
    @Test
    fun `conflicts throttles and server errors are retried`() {
        assertTrue(BcApi.isRetryablePickConfirmation(409, "conflict"))
        assertTrue(BcApi.isRetryablePickConfirmation(423, "locked"))
        assertTrue(BcApi.isRetryablePickConfirmation(429, "slow down"))
        assertTrue(BcApi.isRetryablePickConfirmation(503, "unavailable"))
    }

    @Test
    fun `deadlock response is retried even when status is generic`() {
        assertTrue(BcApi.isRetryablePickConfirmation(400, "Database deadlock; try again"))
    }

    @Test
    fun `validation and missing records are not retried`() {
        assertFalse(BcApi.isRetryablePickConfirmation(400, "Quantity is invalid"))
        assertFalse(BcApi.isRetryablePickConfirmation(404, "Pick not found"))
    }

    @Test
    fun `only active LP statuses can be used as a picking container`() {
        assertTrue(isPickContainerStatusUsable("Open"))
        assertTrue(isPickContainerStatusUsable("Built"))
        assertTrue(isPickContainerStatusUsable("Assigned"))
        assertFalse(isPickContainerStatusUsable("Used"))
        assertFalse(isPickContainerStatusUsable("Unbuilt"))
        assertFalse(isPickContainerStatusUsable("Closed"))
        assertFalse(isPickContainerStatusUsable(""))
    }

    @Test
    fun `assigned pick mutations fail closed until local identity is verified`() {
        assertFalse(canMutateAssignedPick("MERve", ""))
        assertFalse(canMutateAssignedPick("MERve", "OTHER"))
        assertTrue(canMutateAssignedPick("MERve", "merve"))
    }

    @Test
    fun `pick register waits for every line write`() {
        assertTrue(canRegisterAssignedPick("MERve", "merve", readyToRegister = true, inFlightLineCount = 0))
        assertFalse(canRegisterAssignedPick("MERve", "merve", readyToRegister = true, inFlightLineCount = 1))
        assertFalse(canRegisterAssignedPick("MERve", "merve", readyToRegister = false, inFlightLineCount = 0))
    }

    @Test
    fun `normal pick can register a partial collected quantity`() {
        assertTrue(pickReadyToRegister("Single", listOf(4.0, 0.0), allCollected = false))
    }

    @Test
    fun `multi pick still requires every line`() {
        assertFalse(pickReadyToRegister("Multi", listOf(4.0, 0.0), allCollected = false))
        assertTrue(pickReadyToRegister("Multi", listOf(4.0, 2.0), allCollected = true))
    }
}
