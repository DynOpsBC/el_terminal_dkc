package com.dynops.bcwms

import com.dynops.bcwms.feature.allowAdminBypass
import com.dynops.bcwms.ui.assignedToMeClause
import com.dynops.bcwms.ui.canLoadAssignedOnlyList
import com.dynops.bcwms.ui.operatorFacingApiError
import com.dynops.bcwms.ui.operatorFacingStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductionUxRulesTest {
    @Test
    fun `BADE always uses the production operation flow`() {
        assertTrue(shouldForceProductionFlow("bade"))
        assertFalse(shouldForceProductionFlow("dynops"))
        assertTrue(shouldForceProductionFlow("emu"))
    }

    @Test
    fun `emu customer home hides technical test screens`() {
        val screens = operatorHomeScreens("emu")
        assertFalse(Screen.TestCenter in screens)
        assertFalse(Screen.PostingTest in screens)
        assertFalse(Screen.SelfTest in screens)
        assertTrue(Screen.Printers in screens)
        assertTrue(Screen.HierarchicalLP in screens)
        assertTrue(hierarchicalLpUiEnabled("emu"))
    }

    @Test
    fun `offline home only allows connection setup`() {
        assertTrue(isHomeTileEnabled(Screen.Connection, connected = false))
        assertTrue(isHomeTileEnabled(Screen.Help, connected = false))
        assertFalse(isHomeTileEnabled(Screen.Picking, connected = false))
        assertFalse(isHomeTileEnabled(Screen.Count, connected = false))
        assertTrue(isHomeTileEnabled(Screen.Packing, connected = true))
    }

    @Test
    fun `BADE operator menu hides support and destructive test tools`() {
        val screens = operatorHomeScreens("bade")

        assertTrue(Screen.Picking in screens)
        assertTrue(Screen.Packing in screens)
        assertTrue(Screen.LicensePlates in screens)
        assertTrue(Screen.Count in screens)
        assertTrue(Screen.CountV2 in screens)
        assertTrue(Screen.Printers in screens)
        assertTrue(Screen.Connection in screens)
        assertTrue(Screen.Help in screens)
        assertFalse(Screen.HierarchicalLP in screens)
        assertFalse(hierarchicalLpUiEnabled("bade"))
        assertFalse(Screen.TestCenter in screens)
        assertFalse(Screen.PostingTest in screens)
        assertFalse(Screen.SelfTest in screens)
        assertFalse(Screen.FieldSettings in screens)
    }

    @Test
    fun `BADE cannot bypass local operator authentication with service token`() {
        assertTrue(allowAdminBypass("bade"))
        assertTrue(allowAdminBypass("dynops"))
        assertTrue(allowAdminBypass("customer"))
    }

    @Test
    fun `assigned-only filtering fails closed when identity is unresolved`() {
        assertTrue(assignedToMeClause("", enabled = true)!!.contains("UNRESOLVED"))
        assertTrue(assignedToMeClause("operator", enabled = true)!!.contains("OPERATOR"))
        assertTrue(assignedToMeClause("operator", enabled = false) == null)
        assertFalse(canLoadAssignedOnlyList(showAll = false, localUserId = ""))
        assertTrue(canLoadAssignedOnlyList(showAll = true, localUserId = ""))
    }

    @Test
    fun `operator status hides transport and deployment details`() {
        val masked = operatorFacingStatus("HATA: Lot servisi yok (HTTP 404) — güncel BC uzantısını publish edin CorrelationId: abc")
        assertTrue(masked.startsWith("HATA: Lot bilgisi doğrulanamadı."))
        assertTrue(masked.contains("REF-"))
        assertFalse(masked.contains("HTTP"))
        assertFalse(masked.contains("CorrelationId"))
        assertEquals(
            "TAMAM: Sayım kaydedildi (sayıcı 2)",
            operatorFacingStatus("TAMAM: Sayım kaydedildi (slot 2) (HTTP 200)"),
        )
    }

    @Test
    fun `raw Business Central errors become Turkish support references`() {
        val visible = operatorFacingApiError("The Item does not exist. Identification fields: No.=X", 404)

        assertTrue(visible.startsWith("HATA: İşlem tamamlanamadı."))
        assertTrue(visible.contains("REF-"))
        assertFalse(visible.contains("Identification"))
        assertFalse(visible.contains("404"))
    }

    @Test
    fun `common English AL validations never reach the operator`() {
        listOf(
            "HATA: Item No. is required.",
            "HATA: Quantity must be greater than zero.",
            "HATA: Cannot determine the source bin.",
            "HATA: The document is already posted.",
            "HATA: Nothing to register.",
            "HATA: Target bin was not found.",
        ).forEach { raw ->
            val visible = operatorFacingStatus(raw)
            assertTrue(raw, visible.startsWith("HATA:"))
            assertTrue(raw, visible.contains("REF-"))
            assertFalse(raw, visible.contains(raw.removePrefix("HATA: "), ignoreCase = true))
        }
    }
}
