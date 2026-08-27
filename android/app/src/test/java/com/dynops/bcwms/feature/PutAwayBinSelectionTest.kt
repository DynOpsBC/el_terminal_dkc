package com.dynops.bcwms.feature

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PutAwayBinSelectionTest {
    @Test
    fun `ilk bin listesi sayfali ve sirali yuklenir`() {
        val path = putAwayBinListPath("MERKEZDEPO")

        assertEquals(
            "bins?\$filter=locationCode eq 'MERKEZDEPO'&\$orderby=code&\$top=200",
            path,
        )
    }

    @Test
    fun `tam bin aramasi lokasyon ve kodu server side filtreler`() {
        val path = putAwayExactBinPath("MERKEZDEPO", "Y.G03.12")

        assertEquals(
            "bins?\$filter=locationCode eq 'MERKEZDEPO' and code eq 'Y.G03.12'&\$orderby=code&\$top=1",
            path,
        )
    }

    @Test
    fun `tam bin aramasi odata tirnaklarini guvenli kacirir`() {
        val path = putAwayExactBinPath("M'RK", "Y'03")

        assertTrue(path.contains("locationCode eq 'M''RK'"))
        assertTrue(path.contains("code eq 'Y''03'"))
    }

    @Test
    fun `take ve place satirlari tek mantiksal yerlestirme sayilir`() {
        val common = mapOf(
            "sourceNo" to "PO-100",
            "sourceLineNo" to 10,
            "whseDocumentNo" to "PU-100",
            "whseDocumentLineNo" to 10,
            "itemNo" to "HM.00042",
            "variantCode" to "",
            "unitOfMeasureCode" to "KG",
        )
        fun line(action: String, lineNo: Int) = JSONObject().apply {
            common.forEach { (key, value) -> put(key, value) }
            put("actionType", action)
            put("lineNo", lineNo)
        }

        assertEquals(
            1,
            logicalPutAwayMovementCount(
                listOf(line("Take", 10000), line("Place", 20000)),
            ),
        )
    }

    @Test
    fun `farkli kaynak satirlari ayri yerlestirme sayilir`() {
        fun pair(sourceLineNo: Int): List<JSONObject> = listOf("Take", "Place").mapIndexed { index, action ->
            JSONObject().apply {
                put("sourceNo", "PO-100")
                put("sourceLineNo", sourceLineNo)
                put("whseDocumentNo", "PU-100")
                put("whseDocumentLineNo", sourceLineNo)
                put("itemNo", "HM.00042")
                put("unitOfMeasureCode", "KG")
                put("actionType", action)
                put("lineNo", sourceLineNo * 1000 + index)
            }
        }

        assertEquals(2, logicalPutAwayMovementCount(pair(10) + pair(20)))
    }
}
