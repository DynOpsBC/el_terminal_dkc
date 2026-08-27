package com.dynops.bcwms.feature

private const val ASSEMBLY_QTY_EPSILON = 0.000001

internal data class AssemblyLineStageState(
    val remainingQuantity: Double,
    val explicitlyStaged: Boolean,
    val stagedQuantity: Double,
)

/**
 * Assembly posting must never infer operator intent from BC's default `qtyToAssemble` value.
 * Every line that still has a requirement must have been explicitly confirmed in this session.
 * Explicit zero is distinguishable from an untouched field and is valid for an individual line,
 * but the document as a whole still needs at least one positive quantity to post.
 */
internal fun canPostAssemblyDocument(
    headerLoaded: Boolean,
    linesComplete: Boolean,
    busy: Boolean,
    lines: List<AssemblyLineStageState>,
): Boolean {
    if (!headerLoaded || !linesComplete || busy || lines.isEmpty()) return false
    val remaining = lines.filter { it.remainingQuantity > ASSEMBLY_QTY_EPSILON }
    if (remaining.isEmpty()) return false

    val everyRemainingLineExplicitlyStaged = remaining.all { line ->
        line.explicitlyStaged &&
            line.stagedQuantity.isFinite() &&
            line.stagedQuantity >= 0.0 &&
            line.stagedQuantity <= line.remainingQuantity + ASSEMBLY_QTY_EPSILON
    }
    return everyRemainingLineExplicitlyStaged &&
        remaining.any { it.stagedQuantity > ASSEMBLY_QTY_EPSILON }
}

internal fun assemblyPendingLineCount(lines: List<AssemblyLineStageState>): Int =
    lines.count { it.remainingQuantity > ASSEMBLY_QTY_EPSILON && !it.explicitlyStaged }
