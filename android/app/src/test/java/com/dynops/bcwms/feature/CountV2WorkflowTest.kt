package com.dynops.bcwms.feature

import com.dynops.bcwms.scanner.BarcodeIntentResolver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CountV2WorkflowTest {
    @Test
    fun `item lot quantity QR becomes an automatic count`() {
        val result = validateCountV2Label(
            BarcodeIntentResolver.resolve("MADDE KODU=AB.00005; LOT NO=A100797; MİKTAR=1,000; BİRİM=ADET")
        )

        assertTrue(result is CountV2LabelResult.Valid)
        val label = (result as CountV2LabelResult.Valid).label
        assertEquals("AB.00005", label.itemNo)
        assertEquals("A100797", label.lotNo)
        assertEquals("ADET", label.unitOfMeasureCode)
        assertEquals(1000.0, label.quantity, 0.0)
    }

    @Test
    fun `V2 rejects item barcode without explicit quantity`() {
        val result = validateCountV2Label(BarcodeIntentResolver.resolve("AB.00005"))

        assertTrue(result is CountV2LabelResult.Invalid)
        assertTrue((result as CountV2LabelResult.Invalid).message.contains("miktar"))
    }

    @Test
    fun `rapid duplicate is blocked but intentional later scan is allowed`() {
        assertTrue(isRapidCountV2Duplicate("QR-1", 1_000, "QR-1", 2_000))
        assertFalse(isRapidCountV2Duplicate("QR-1", 1_000, "QR-1", 2_500))
        assertFalse(isRapidCountV2Duplicate("QR-1", 1_000, "QR-2", 1_100))
    }

    @Test
    fun `classic sheet message explains both safe choices without a technical reference`() {
        val message = classicCountSheetV2Message(200)

        assertTrue(message.contains("200 hazır satır"))
        assertTrue(message.contains("Sayım ekranından devam edin"))
        assertTrue(message.contains("Yeni V2 Sayımı Oluştur"))
        assertFalse(message.contains("REF-"))
    }
}
