package com.dynops.bcwms.feature

internal fun canDeleteLicensePlate(status: String, lineCount: Int): Boolean =
    lineCount == 0 && (
        status.equals("Open", ignoreCase = true) ||
            status.equals("Unbuilt", ignoreCase = true)
        )

internal fun validLpTrackingQuantity(serialTrackingRequired: Boolean, quantity: Double): Boolean =
    !serialTrackingRequired || quantity == 1.0

internal fun sourceBinBelongsToLpLocation(lpLocation: String, sourceBinLocations: List<String>): Boolean =
    lpLocation.isNotBlank() && sourceBinLocations.any { it.equals(lpLocation, ignoreCase = true) }

internal fun sourceBinLookupAllowsMove(
    pageComplete: Boolean,
    lpLocation: String,
    sourceBinLocations: List<String>,
): Boolean = pageComplete && sourceBinBelongsToLpLocation(lpLocation, sourceBinLocations)

internal fun activeLicensePlateStatus(status: String): Boolean =
    status.equals("Open", ignoreCase = true) ||
        status.equals("Built", ignoreCase = true) || status.equals("Assigned", ignoreCase = true)

internal fun lpUomOptions(baseUom: String, configuredUoms: List<String>, stockUoms: List<String>): List<String> =
    (listOf(baseUom) + configuredUoms + stockUoms)
        .map(String::trim)
        .filter(String::isNotBlank)
        .distinctBy(String::uppercase)

internal fun lpLotIsRequired(trackingRequiresLot: Boolean, availableLotCount: Int, scannedLot: String): Boolean =
    trackingRequiresLot || availableLotCount > 0 || scannedLot.isNotBlank()

internal fun canEditLicensePlate(status: String): Boolean =
    status.equals("Open", ignoreCase = true)

internal fun canTransferLicensePlate(status: String, lineCount: Int): Boolean =
    status.equals("Built", ignoreCase = true) && lineCount > 0

internal fun canPartiallyUseLicensePlate(status: String, lineCount: Int): Boolean =
    status.equals("Built", ignoreCase = true) && lineCount > 0

internal fun validPartialUseInput(quantity: Double?, lineNo: Int?, maximumQuantity: Double): Boolean =
    quantity != null && quantity > 0.0 && quantity <= maximumQuantity && lineNo != null && lineNo > 0

internal data class LpPartialAction(
    val apiValue: String,
    val label: String,
    val help: String,
)

internal val lpPartialActions = listOf(
    LpPartialAction(
        apiValue = "CreateNewLP",
        label = "Kalanı yeni LP'ye ayır",
        help = "Girilen miktar bu LP'de kalır; kalan miktar yeni bir LP'ye aktarılır.",
    ),
    LpPartialAction(
        apiValue = "RemoveExcess",
        label = "Miktarı düzelt",
        help = "Satır miktarı girilen miktara düşürülür.",
    ),
    LpPartialAction(
        apiValue = "RemoveUsedPortion",
        label = "Kullanılan miktarı çıkar",
        help = "Girilen miktar mevcut satırdan düşülür.",
    ),
)
