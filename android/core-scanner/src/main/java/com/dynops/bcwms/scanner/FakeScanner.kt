package com.dynops.bcwms.scanner

class FakeScanner(
  private val nextRaw: String = "5901234123457",
) : Scanner {
  override val capabilities = ScannerCapabilities(
    supportedSources = setOf(ScanSource.Camera, ScanSource.KeyboardWedge),
  )

  override suspend fun scan(): RawBarcode = RawBarcode(nextRaw, ScanSource.Camera)
}
