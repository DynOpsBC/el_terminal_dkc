package com.dynops.bcwms.feature

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountWorkflowTest {
    @Test
    fun `explicit counted flag preserves a physical zero count`() {
        assertTrue(isCountRecorded(hasExplicitFlag = true, explicitFlag = true, quantity = 0.0))
    }

    @Test
    fun `explicit false is not confused with a zero count`() {
        assertFalse(isCountRecorded(hasExplicitFlag = true, explicitFlag = false, quantity = 0.0))
    }

    @Test
    fun `legacy nonzero count remains recognized without flag`() {
        assertTrue(isCountRecorded(hasExplicitFlag = false, explicitFlag = false, quantity = 4.0))
    }

    @Test
    fun `lotless count is blocked when positive lot balances exist`() {
        assertTrue(countLineNeedsLotSelection(lineLotNo = "", positiveLotNos = listOf("LOT-A", "LOT-B")))
    }

    @Test
    fun `selected lot line accepts its own count quantity`() {
        assertFalse(countLineNeedsLotSelection(lineLotNo = "LOT-A", positiveLotNos = listOf("LOT-A", "LOT-B")))
    }

    @Test
    fun `untracked stock remains countable`() {
        assertFalse(countLineNeedsLotSelection(lineLotNo = "", positiveLotNos = emptyList()))
    }

    @Test
    fun `plain barcode matching an active count lot is resolved as lot`() {
        assertTrue(shouldResolvePlainCountBarcodeAsLot(hasLocalLotMatch = true, itemExistsInBc = false))
    }

    @Test
    fun `plain barcode not found as an item is resolved through BC lot lookup`() {
        assertTrue(shouldResolvePlainCountBarcodeAsLot(hasLocalLotMatch = false, itemExistsInBc = false))
    }

    @Test
    fun `confirmed item outside the bin keeps unexpected stock flow`() {
        assertFalse(shouldResolvePlainCountBarcodeAsLot(hasLocalLotMatch = false, itemExistsInBc = true))
    }

    @Test
    fun `empty complete sheet can generate but cannot post`() {
        val actions = countDocumentActions(0, busy = false, linesComplete = true, headerLoaded = true, activeSlotComplete = false)
        assertTrue(actions.canGenerateLines)
        assertFalse(actions.canStartRecount)
        assertFalse(actions.canPost)
    }

    @Test
    fun `loaded sheet can recount and post but cannot regenerate`() {
        val actions = countDocumentActions(12, busy = false, linesComplete = true, headerLoaded = true, activeSlotComplete = true)
        assertFalse(actions.canGenerateLines)
        assertTrue(actions.canStartRecount)
        assertTrue(actions.canPost)
    }

    @Test
    fun `posted sheet and unassigned operator cannot mutate counts`() {
        val posted = countDocumentActions(
            3, false, true, true, true,
            status = "Posted",
        )
        val unassigned = countDocumentActions(
            3, false, true, true, true,
            activeSlotAssigned = false,
        )
        assertFalse(posted.canGenerateLines || posted.canStartRecount || posted.canPost)
        assertFalse(unassigned.canGenerateLines || unassigned.canStartRecount || unassigned.canPost)
    }

    @Test
    fun `recount mismatch blocks posting but still permits a new recount`() {
        val actions = countDocumentActions(
            3, false, true, true, true,
            hasRecountRequired = true,
        )
        assertTrue(actions.canStartRecount)
        assertFalse(actions.canPost)
    }

    @Test
    fun `operator sees only their BC assigned count slot`() {
        val assignments = listOf(
            CountSlotAssignment(1, "SAYICI-A"),
            CountSlotAssignment(2, "SAYICI-B"),
        )
        assertTrue(assignedCountSlotsForOperator(assignments, "sayici-b", false) == listOf(2))
        assertTrue(assignedCountSlotsForOperator(assignments, "", true) == listOf(1, 2))
        assertTrue(assignedCountSlotsForOperator(emptyList(), "LEGACY", false) == listOf(1))
        assertTrue(assignedCountSlotsForOperator(assignments, "BASKA", false).isEmpty())
    }

    @Test
    fun `partial failed or busy load blocks every destructive count action`() {
        val partial = countDocumentActions(200, busy = false, linesComplete = false, headerLoaded = true, activeSlotComplete = true)
        val busy = countDocumentActions(200, busy = true, linesComplete = true, headerLoaded = true, activeSlotComplete = true)
        assertFalse(partial.canGenerateLines || partial.canStartRecount || partial.canPost)
        assertFalse(busy.canGenerateLines || busy.canStartRecount || busy.canPost)
    }

    @Test
    fun `explicit zero completes the active counter slot`() {
        val complete = allRequiredCountLinesExplicitlyCompleted(
            listOf(
                CountSlotLineState(hasExplicitFlag = true, explicitlyCounted = true, quantity = 0.0),
                CountSlotLineState(hasExplicitFlag = true, explicitlyCounted = true, quantity = 4.0),
            )
        )
        assertTrue(complete)
    }

    @Test
    fun `missing active slot flag blocks posting even when legacy quantity is nonzero`() {
        val complete = allRequiredCountLinesExplicitlyCompleted(
            listOf(CountSlotLineState(hasExplicitFlag = false, explicitlyCounted = false, quantity = 4.0))
        )
        val actions = countDocumentActions(1, false, true, true, activeSlotComplete = complete)
        assertFalse(complete)
        assertFalse(actions.canPost)
    }

    @Test
    fun `one incomplete line blocks the whole count document`() {
        val complete = allRequiredCountLinesExplicitlyCompleted(
            listOf(
                CountSlotLineState(hasExplicitFlag = true, explicitlyCounted = true, quantity = 1.0),
                CountSlotLineState(hasExplicitFlag = true, explicitlyCounted = false, quantity = 0.0),
            )
        )
        assertFalse(complete)
    }

    @Test
    fun `sequential write progress distinguishes partial persistence from completion`() {
        val partial = sequentialWriteProgress(total = 4, succeeded = 2)
        val complete = sequentialWriteProgress(total = 4, succeeded = 4)

        assertTrue(partial.partial)
        assertFalse(partial.complete)
        assertFalse(complete.partial)
        assertTrue(complete.complete)
    }

    @Test
    fun `sequential write progress clamps invalid counters fail closed`() {
        val negative = sequentialWriteProgress(total = 3, succeeded = -1)
        val overflow = sequentialWriteProgress(total = 3, succeeded = 99)
        val empty = sequentialWriteProgress(total = 0, succeeded = 0)

        assertFalse(negative.partial || negative.complete)
        assertFalse(overflow.partial || overflow.complete)
        assertFalse(empty.partial || empty.complete)
    }
}
