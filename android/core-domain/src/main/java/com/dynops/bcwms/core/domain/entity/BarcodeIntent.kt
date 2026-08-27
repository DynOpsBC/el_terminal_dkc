package com.dynops.bcwms.core.domain.entity

sealed interface BarcodeIntent {
  data class Bin(val code: String) : BarcodeIntent
  data class Item(val itemReference: String, val gtin: String? = null, val lot: String? = null, val expiry: String? = null, val serial: String? = null) : BarcodeIntent
  data class Lp(val sscc: String) : BarcodeIntent
  data class LpTemplate(val code: String) : BarcodeIntent
  data class Lot(val code: String) : BarcodeIntent
  data class Serial(val code: String) : BarcodeIntent
  data class Unknown(val raw: String) : BarcodeIntent
}
