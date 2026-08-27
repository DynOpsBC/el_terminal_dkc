package com.dynops.bcwms.feature

/**
 * A zero quantity is a valid physical count. New AL versions expose an explicit
 * counted flag; the quantity fallback keeps older in-progress sheets readable.
 */
internal fun isCountRecorded(hasExplicitFlag: Boolean, explicitFlag: Boolean, quantity: Double): Boolean =
    if (hasExplicitFlag) explicitFlag else quantity != 0.0

internal data class CountSlotLineState(
    val hasExplicitFlag: Boolean,
    val explicitlyCounted: Boolean,
    val quantity: Double,
)

/**
 * Posting is stricter than the legacy display fallback in [isCountRecorded]. A non-zero quantity
 * without the matching `countedN` flag is not proof that the active counter actually completed the
 * line in this count round. Conversely, an explicit flag makes a physical zero a valid answer.
 */
internal fun allRequiredCountLinesExplicitlyCompleted(lines: List<CountSlotLineState>): Boolean =
    lines.isNotEmpty() && lines.all { line ->
        line.hasExplicitFlag &&
            line.explicitlyCounted &&
            line.quantity.isFinite() &&
            line.quantity >= 0.0
    }

/**
 * A lotless count line must not accept a quantity when BC reports positive lot balances for the
 * same item/bin. Recording it would lose the answer to "which lot was counted?".
 */
internal fun countLineNeedsLotSelection(lineLotNo: String, positiveLotNos: List<String>): Boolean =
    lineLotNo.isBlank() && positiveLotNos.any { it.isNotBlank() }

/**
 * Plain lot numbers and plain item numbers have the same scanner shape. Prefer a lot when the
 * active count already contains it; otherwise only open the unexpected-item flow after BC confirms
 * that the scanned value is an item number.
 */
internal fun shouldResolvePlainCountBarcodeAsLot(
    hasLocalLotMatch: Boolean,
    itemExistsInBc: Boolean,
): Boolean = hasLocalLotMatch || !itemExistsInBc

internal data class CountDocumentActions(
    val canGenerateLines: Boolean,
    val canStartRecount: Boolean,
    val canPost: Boolean,
)

internal data class CountSlotAssignment(val slot: Int, val userId: String)

internal fun assignedCountSlotsForOperator(
    assignments: List<CountSlotAssignment>,
    currentUserId: String,
    adminTestSession: Boolean,
): List<Int> {
    val configured = assignments
        .filter { it.slot in 1..3 && it.userId.isNotBlank() }
        .distinctBy { it.slot }
    if (configured.isEmpty()) return listOf(1) // Eski belgeler için geriye uyumluluk.
    if (adminTestSession) return configured.map { it.slot }.sorted()
    if (currentUserId.isBlank()) return emptyList()
    return configured
        .filter { it.userId.equals(currentUserId, ignoreCase = true) }
        .map { it.slot }
        .sorted()
}

internal fun countDocumentIsMutable(status: String): Boolean =
    !status.equals("Posted", ignoreCase = true)

/**
 * Posting is fail-closed: a partial/paged line load must never be posted as a complete count.
 */
internal fun countDocumentActions(
    lineCount: Int,
    busy: Boolean,
    linesComplete: Boolean,
    headerLoaded: Boolean,
    activeSlotComplete: Boolean,
    status: String = "InProgress",
    activeSlotAssigned: Boolean = true,
    hasRecountRequired: Boolean = false,
): CountDocumentActions {
    val ready = !busy && linesComplete && headerLoaded && countDocumentIsMutable(status) && activeSlotAssigned
    return CountDocumentActions(
        canGenerateLines = ready && lineCount == 0,
        canStartRecount = ready && lineCount > 0,
        canPost = ready && lineCount > 0 && activeSlotComplete && !hasRecountRequired,
    )
}

internal data class SequentialWriteProgress(
    val total: Int,
    val succeeded: Int,
) {
    val complete: Boolean get() = total > 0 && succeeded == total
    val partial: Boolean get() = succeeded in 1 until total
}

/**
 * Client-side multi-line writes are not transactional. Normalise their progress so callers never
 * describe a partially persisted result as complete and can force a server reload/reconciliation.
 */
internal fun sequentialWriteProgress(total: Int, succeeded: Int): SequentialWriteProgress =
    SequentialWriteProgress(
        total = total.coerceAtLeast(0),
        succeeded = succeeded.coerceAtLeast(0),
    )
