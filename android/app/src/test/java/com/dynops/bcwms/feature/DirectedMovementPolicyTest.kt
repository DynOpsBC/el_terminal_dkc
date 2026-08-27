package com.dynops.bcwms.feature

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class DirectedMovementPolicyTest {

    @Test
    fun `confirmation sends selected lot to server`() {
        val body = JSONObject(directedMovementConfirmBody(10000, 4.0, "LOT-A", "SERIAL-A", "USER1"))

        assertEquals(10000, body.getInt("lineNo"))
        assertEquals(4.0, body.getDouble("qtyToHandle"), 0.0)
        assertEquals("LOT-A", body.getString("lotNo"))
        assertEquals("SERIAL-A", body.getString("serialNo"))
        assertEquals("USER1", body.getString("userId"))
    }
    private fun line(lineNo: Int, action: String, itemNo: String = "ITEM-1") = JSONObject().apply {
        put("lineNo", lineNo)
        put("actionType", action)
        put("itemNo", itemNo)
    }

    @Test
    fun `item scan selects only the take row`() {
        val matches = directedMovementTakeMatches(
            listOf(line(10000, "Take"), line(20000, "Place")),
            "ITEM-1",
        )

        assertEquals(listOf(10000), matches.map { it.optInt("lineNo") })
    }

    @Test
    fun `item scan keeps multiple take rows separate for manual lot selection`() {
        val matches = directedMovementTakeMatches(
            listOf(line(10000, "Take"), line(20000, "Take"), line(30000, "Place")),
            "item-1",
        )

        assertEquals(listOf(10000, 20000), matches.map { it.optInt("lineNo") })
    }

    @Test
    fun `lot tracked movement cannot register before lot is selected`() {
        val take = line(10000, "Take").apply {
            put("qtyToHandle", 4.0)
            put("lotRequired", true)
            put("lotNo", "")
        }

        assertEquals(false, directedMovementReadyToRegister(listOf(take)))
        take.put("lotNo", "LOT-A")
        assertEquals(true, directedMovementReadyToRegister(listOf(take)))
    }

    @Test
    fun `warehouse stock registration error names the actionable bin and item`() {
        val raw = "Quantity (Base) available must not be less than 100 in Bin Content " +
            "Location Code='MERKEZDEPO',Bin Code='A.A01.11',Item No.='AB.00005'."

        assertEquals(
            "HATA: A.A01.11 rafında AB.00005 için 100 miktar kullanılabilir stok yok. " +
                "Hareket miktarını veya raf stoğunu kontrol edin.",
            directedMovementRegisterError(raw, 400),
        )
    }
}
