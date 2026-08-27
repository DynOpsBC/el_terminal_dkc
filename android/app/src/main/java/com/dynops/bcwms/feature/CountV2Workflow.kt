package com.dynops.bcwms.feature

import com.dynops.bcwms.scanner.BarcodeKind
import com.dynops.bcwms.scanner.ResolvedBarcode

/** Sunucuya tek, atomik Sayım V2 okutması olarak gönderilen kesin etiket bilgisi. */
internal data class CountV2Label(
    val itemNo: String,
    val variantCode: String,
    val unitOfMeasureCode: String,
    val lotNo: String,
    val serialNo: String,
    val quantity: Double,
    val raw: String,
)

internal sealed interface CountV2LabelResult {
    data class Valid(val label: CountV2Label) : CountV2LabelResult
    data class Invalid(val message: String) : CountV2LabelResult
}

/**
 * V2'de sistem miktarına veya elle girişe sessizce düşülmez. Yalnız ürün ve
 * pozitif miktarı açıkça taşıyan QR sayım satırı oluşturabilir.
 */
internal fun validateCountV2Label(resolved: ResolvedBarcode): CountV2LabelResult {
    if (resolved.kind != BarcodeKind.Item)
        return CountV2LabelResult.Invalid("Sayım V2 yalnız ürün etiketi kabul eder.")

    val itemNo = resolved.itemNo?.trim().orEmpty().ifBlank { resolved.value.trim() }
    if (itemNo.isBlank())
        return CountV2LabelResult.Invalid("QR içinde madde kodu bulunamadı.")

    val quantity = resolved.quantity
    if (quantity == null)
        return CountV2LabelResult.Invalid("QR içinde miktar yok. V2 manuel miktar istemez; ürün + lot + miktar içeren etiketi okutun.")
    if (!quantity.isFinite() || quantity <= 0.0)
        return CountV2LabelResult.Invalid("QR miktarı sıfırdan büyük olmalıdır.")

    return CountV2LabelResult.Valid(
        CountV2Label(
            itemNo = itemNo,
            variantCode = resolved.variantCode?.trim().orEmpty(),
            unitOfMeasureCode = resolved.unitOfMeasureCode?.trim().orEmpty(),
            lotNo = resolved.lotNo?.trim().orEmpty(),
            serialNo = resolved.serialNo?.trim().orEmpty(),
            quantity = quantity,
            raw = resolved.raw,
        )
    )
}

/** Donanım/kamera aynı decode olayını art arda yayarsa miktarın iki kez eklenmesini önler. */
internal fun isRapidCountV2Duplicate(
    previousRaw: String,
    previousAtMillis: Long,
    raw: String,
    nowMillis: Long,
    debounceMillis: Long = 1_500L,
): Boolean =
    previousRaw.isNotBlank() &&
        previousRaw == raw &&
        nowMillis >= previousAtMillis &&
        nowMillis - previousAtMillis < debounceMillis

internal fun classicCountSheetV2Message(lineCount: Int): String =
    "Bu belge klasik sayım için hazırlanmış ve $lineCount hazır satır içeriyor. " +
        "Mevcut satırlar silinmedi. Bu belgeyle ana menüdeki Sayım ekranından devam edin " +
        "veya Sayfa Listesi'ne dönüp Yeni V2 Sayımı Oluştur'a basın."
