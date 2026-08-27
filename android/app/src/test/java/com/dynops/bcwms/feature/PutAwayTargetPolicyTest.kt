package com.dynops.bcwms.feature

import org.junit.Assert.assertEquals
import org.junit.Test

class PutAwayTargetPolicyTest {
    @Test
    fun `onerilen raf lokasyonda varsa kabul edilir`() {
        assertEquals(
            PutAwayTargetDecision.SUGGESTED,
            decidePutAwayTarget("Y.G03.32", "Y.G03.32", existsAtLocation = true),
        )
    }

    @Test
    fun `oneriden farkli fakat lokasyonda bulunan raf kabul edilir`() {
        assertEquals(
            PutAwayTargetDecision.ALTERNATIVE,
            decidePutAwayTarget("H.A01.11", "Y.G03.32", existsAtLocation = true),
        )
    }

    @Test
    fun `lokasyonda bulunmayan raf reddedilir`() {
        assertEquals(
            PutAwayTargetDecision.NOT_FOUND,
            decidePutAwayTarget("X.YOK.01", "Y.G03.32", existsAtLocation = false),
        )
    }

    @Test
    fun `bos hedef raf reddedilir`() {
        assertEquals(
            PutAwayTargetDecision.EMPTY,
            decidePutAwayTarget("", "Y.G03.32", existsAtLocation = true),
        )
    }
}
