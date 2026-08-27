package com.dynops.bcwms.scanner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BarcodeIntentResolverTest {
  private val resolver = BarcodeIntentResolver()

  @Test fun ean13HappyPath() {
    assertTrue(resolver.resolve("5901234123457") is BarcodeIntent.Item)
  }

  @Test fun ean13WrongLength() {
    assertTrue(resolver.resolve("590123412345") is BarcodeIntent.Unknown)
  }

  @Test fun gs1Full() {
    val intent = resolver.resolve("(01)08401234567890(10)LOT123(17)260101(21)SN42") as BarcodeIntent.Item
    assertEquals("08401234567890", intent.gtin)
    assertEquals("LOT123", intent.lot)
    assertEquals("260101", intent.expiry)
    assertEquals("SN42", intent.serial)
  }

  @Test fun gs1GtinOnly() {
    val intent = resolver.resolve("(01)08401234567890") as BarcodeIntent.Item
    assertEquals("08401234567890", intent.gtin)
  }

  @Test fun gs1GtinLot() {
    val intent = resolver.resolve("(01)08401234567890(10)LOT123") as BarcodeIntent.Item
    assertEquals("LOT123", intent.lot)
  }

  @Test fun sscc18Valid() {
    val intent = resolver.resolve("(00)123456789012345678") as BarcodeIntent.Lp
    assertEquals("123456789012345678", intent.sscc)
  }

  @Test fun binPrefixValid() {
    val intent = resolver.resolve("B-A01-01") as BarcodeIntent.Bin
    assertEquals("A01-01", intent.code)
  }

  @Test fun lpTemplateValid() {
    val intent = resolver.resolve("TPL-CARTON-S") as BarcodeIntent.LpTemplate
    assertEquals("CARTON-S", intent.code)
  }

  @Test fun emptyInput() {
    assertTrue(resolver.resolve("") is BarcodeIntent.Unknown)
  }

  @Test fun garbageInput() {
    assertTrue(resolver.resolve("not-a-barcode") is BarcodeIntent.Unknown)
  }

  @Test fun regexSpecialChars() {
    val intent = resolver.resolve("(01)08401234567890(10)LOT-1(21)SN-42") as BarcodeIntent.Item
    assertEquals("LOT-1", intent.lot)
    assertEquals("SN-42", intent.serial)
  }

  @Test fun ssccRejectsShortValue() {
    assertTrue(resolver.resolve("(00)123") is BarcodeIntent.Unknown)
  }

  @Test fun lpTemplateRejectsEmptyCode() {
    assertTrue(resolver.resolve("TPL-") is BarcodeIntent.Unknown)
  }

  @Test fun binRejectsEmptyCode() {
    assertTrue(resolver.resolve("B-") is BarcodeIntent.Unknown)
  }

  @Test fun gs1RejectsBadExpiry() {
    assertTrue(resolver.resolve("(01)08401234567890(17)26010") is BarcodeIntent.Unknown)
  }

  @Test fun ean13WinsBeforeUnknown() {
    val intent = resolver.resolve("0000000000000")
    assertTrue(intent is BarcodeIntent.Item)
  }
}
