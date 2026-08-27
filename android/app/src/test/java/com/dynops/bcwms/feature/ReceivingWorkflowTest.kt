package com.dynops.bcwms.feature

import org.junit.Assert.assertTrue
import org.junit.Test

class ReceivingWorkflowTest {
    @Test
    fun `preflight failure reports partial reset and requires reconciliation`() {
        val status = receivingPreflightFailureStatus(resetCount = 2)

        assertTrue(status.startsWith("UYARI: 2 satır sıfırlandı"))
        assertTrue(status.contains("Belge yenilendi"))
        assertTrue(status.contains("mal kabul kaydedilmedi"))
    }

    @Test
    fun `preflight failure without writes remains fail closed`() {
        val status = receivingPreflightFailureStatus(resetCount = 0)

        assertTrue(status.startsWith("HATA:"))
        assertTrue(status.contains("mal kabul kaydedilmedi"))
    }
}
