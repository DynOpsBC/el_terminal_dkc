package com.dynops.bcwms.feature

import com.dynops.bcwms.scanner.BarcodeIntentResolver
import com.dynops.bcwms.scanner.BarcodeKind

internal enum class AdHocProductInputRoute {
    ProductMutation,
    LicensePlateWorkflow,
    Invalid,
}

internal data class AdHocProductInputDecision(
    val route: AdHocProductInputRoute,
    val value: String,
)

/**
 * The legacy "Product" form must never turn an LP barcode into an ad-hoc item
 * journal request with an empty item number. LPs have their own atomic
 * transfer/move-to-bin contract, so detecting one here only changes workflow;
 * it never produces a stock mutation by itself.
 */
internal fun decideAdHocProductInput(raw: String): AdHocProductInputDecision {
    val resolved = BarcodeIntentResolver.resolve(raw)
    return when (resolved.kind) {
        BarcodeKind.Lp -> AdHocProductInputDecision(
            route = AdHocProductInputRoute.LicensePlateWorkflow,
            value = resolved.value.trim(),
        )

        BarcodeKind.Item -> AdHocProductInputDecision(
            route = AdHocProductInputRoute.ProductMutation,
            value = resolved.itemNo?.trim().orEmpty().ifBlank { resolved.value.trim() },
        )

        else -> AdHocProductInputDecision(
            route = AdHocProductInputRoute.Invalid,
            value = resolved.value.trim(),
        )
    }
}
