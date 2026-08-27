package com.dynops.bcwms.scanner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BarcodeIntentResolverTest {
    @Test
    fun `GS1 AI 30 quantity is read from item label`() {
        val result = BarcodeIntentResolver.resolve("(01)08691234567890(10)A100797(30)5000")

        assertEquals(BarcodeKind.Item, result.kind)
        assertEquals("08691234567890", result.itemNo)
        assertEquals("A100797", result.lotNo)
        assertEquals(5000.0, result.quantity ?: -1.0, 0.0)
        assertNull(result.unitOfMeasureCode)
    }

    @Test
    fun `Bade item label fields and Turkish thousands quantity are read`() {
        val result = BarcodeIntentResolver.resolve(
            "MADDE KODU=AB.00005; LOT NO=A100797; MİKTAR/BİRİM=5,000 ADET"
        )

        assertEquals(BarcodeKind.Item, result.kind)
        assertEquals("AB.00005", result.itemNo)
        assertEquals("A100797", result.lotNo)
        assertEquals(5000.0, result.quantity ?: -1.0, 0.0)
    }

    @Test
    fun `JSON style item label is read`() {
        val result = BarcodeIntentResolver.resolve(
            "{\"itemNo\":\"AB.00005\",\"lotNo\":\"A100797\",\"quantity\":\"1147\",\"uom\":\"ADET\"}"
        )

        assertEquals("AB.00005", result.itemNo)
        assertEquals("A100797", result.lotNo)
        assertEquals(1147.0, result.quantity ?: -1.0, 0.0)
        assertEquals("ADET", result.unitOfMeasureCode)
    }

    @Test
    fun `custom V2 fields include serial variant and unit`() {
        val result = BarcodeIntentResolver.resolve(
            "MADDE KODU=AB.00005; LOT NO=A100797; SERİ NO=S-42; VARYANT KODU=KRM; MİKTAR=25; BİRİM=ADET"
        )

        assertEquals("S-42", result.serialNo)
        assertEquals("KRM", result.variantCode)
        assertEquals("ADET", result.unitOfMeasureCode)
    }

    @Test
    fun `custom item label without quantity leaves quantity empty`() {
        val result = BarcodeIntentResolver.resolve("MADDE KODU=AB.00005; LOT NO=A100797")

        assertEquals("AB.00005", result.itemNo)
        assertNull(result.quantity)
    }

    @Test
    fun `lot only field is classified as lot`() {
        val result = BarcodeIntentResolver.resolve("LOT NO=A100797")

        assertEquals(BarcodeKind.Lot, result.kind)
        assertEquals("A100797", result.value)
        assertEquals("A100797", result.lotNo)
    }
}
