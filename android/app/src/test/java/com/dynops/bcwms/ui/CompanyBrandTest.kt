package com.dynops.bcwms.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class CompanyBrandTest {
    @Test
    fun `known Business Central company names select their own brands`() {
        assertEquals(CompanyBrand.BADE, resolveCompanyBrand("BADE NATURAL DOĞAL YAŞAM ÜRÜNLERİ SAN. TİC. A.Ş."))
        assertEquals(CompanyBrand.BS, resolveCompanyBrand("BS GROUP COSMETICS"))
        assertEquals(CompanyBrand.PIM, resolveCompanyBrand("PİM GRUP DANIŞMANLIK A.Ş."))
    }

    @Test
    fun `bade flavor keeps its brand before a company is resolved`() {
        assertEquals(CompanyBrand.BADE, resolveCompanyBrand("", "bade"))
        assertEquals(CompanyBrand.DEFAULT, resolveCompanyBrand("CRONUS USA, Inc.", "dynops"))
    }

    @Test
    fun `emu flavor never inherits customer logos`() {
        assertEquals(CompanyBrand.DEFAULT, resolveCompanyBrand("", "emu"))
        assertEquals(CompanyBrand.DEFAULT, resolveCompanyBrand("BADE NATURAL", "emu"))
        assertEquals(CompanyBrand.DEFAULT, resolveCompanyBrand("BS GROUP", "emu"))
    }
}
