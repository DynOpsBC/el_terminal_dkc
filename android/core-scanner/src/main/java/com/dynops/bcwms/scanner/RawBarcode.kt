package com.dynops.bcwms.scanner

data class RawBarcode(
  val raw: String,
  val symbology: ScanSource,
  val timestamp: Long = System.currentTimeMillis(),
)

enum class ScanSource {
  Camera,
  DataWedge,
  Honeywell,
  Datalogic,
  KeyboardWedge,
}
