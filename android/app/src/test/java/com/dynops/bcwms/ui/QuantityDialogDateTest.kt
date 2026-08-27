package com.dynops.bcwms.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QuantityDialogDateTest {
    @Test
    fun `turkish expiry input is converted to BC ISO date`() {
        assertEquals("2027-12-31", normalizeExpiryDate("31.12.2027"))
        assertEquals("2027-12-31", normalizeExpiryDate("31/12/2027"))
    }

    @Test
    fun `invalid calendar date is rejected`() {
        assertNull(normalizeExpiryDate("31.02.2027"))
        assertNull(normalizeExpiryDate(""))
    }

    @Test
    fun `BC ISO date is displayed in terminal format`() {
        assertEquals("31.12.2027", expiryDateForDisplay("2027-12-31"))
        assertEquals("", expiryDateForDisplay("0001-01-01"))
    }
}
