package com.dynops.bcwms.scanner

interface Scanner {
  val capabilities: ScannerCapabilities
  suspend fun scan(): RawBarcode
}
