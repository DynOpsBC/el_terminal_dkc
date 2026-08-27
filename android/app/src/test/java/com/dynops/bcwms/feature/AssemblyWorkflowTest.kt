package com.dynops.bcwms.feature

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssemblyWorkflowTest {
    @Test
    fun `all remaining component lines must be explicitly staged`() {
        val lines = listOf(
            AssemblyLineStageState(remainingQuantity = 5.0, explicitlyStaged = true, stagedQuantity = 5.0),
            AssemblyLineStageState(remainingQuantity = 2.0, explicitlyStaged = false, stagedQuantity = 2.0),
        )
        assertFalse(canPostAssemblyDocument(true, true, false, lines))
        assertEquals(1, assemblyPendingLineCount(lines))
    }

    @Test
    fun `explicit zero is valid for one line when document has a positive staged quantity`() {
        val lines = listOf(
            AssemblyLineStageState(remainingQuantity = 5.0, explicitlyStaged = true, stagedQuantity = 5.0),
            AssemblyLineStageState(remainingQuantity = 2.0, explicitlyStaged = true, stagedQuantity = 0.0),
        )
        assertTrue(canPostAssemblyDocument(true, true, false, lines))
    }

    @Test
    fun `all zero assembly is blocked even when every line was touched`() {
        val lines = listOf(
            AssemblyLineStageState(remainingQuantity = 5.0, explicitlyStaged = true, stagedQuantity = 0.0),
            AssemblyLineStageState(remainingQuantity = 2.0, explicitlyStaged = true, stagedQuantity = 0.0),
        )
        assertFalse(canPostAssemblyDocument(true, true, false, lines))
    }

    @Test
    fun `quantity above remaining is not business valid`() {
        val lines = listOf(
            AssemblyLineStageState(remainingQuantity = 5.0, explicitlyStaged = true, stagedQuantity = 6.0),
        )
        assertFalse(canPostAssemblyDocument(true, true, false, lines))
    }

    @Test
    fun `partial page header failure and busy state all fail closed`() {
        val lines = listOf(
            AssemblyLineStageState(remainingQuantity = 5.0, explicitlyStaged = true, stagedQuantity = 5.0),
        )
        assertFalse(canPostAssemblyDocument(true, false, false, lines))
        assertFalse(canPostAssemblyDocument(false, true, false, lines))
        assertFalse(canPostAssemblyDocument(true, true, true, lines))
    }

    @Test
    fun `already completed component does not require staging`() {
        val lines = listOf(
            AssemblyLineStageState(remainingQuantity = 0.0, explicitlyStaged = false, stagedQuantity = 0.0),
            AssemblyLineStageState(remainingQuantity = 3.0, explicitlyStaged = true, stagedQuantity = 3.0),
        )
        assertTrue(canPostAssemblyDocument(true, true, false, lines))
    }
}
