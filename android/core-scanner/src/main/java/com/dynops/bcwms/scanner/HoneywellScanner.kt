package com.dynops.bcwms.scanner

class HoneywellScanner(
  private val fallback: Scanner = FakeScanner(),
) : Scanner {
  override val capabilities = ScannerCapabilities(
    supportedSources = setOf(ScanSource.Honeywell),
    supportsHardwareTrigger = hasHoneywellAidc(),
  )

  override suspend fun scan(): RawBarcode = fallback.scan().copy(symbology = ScanSource.Honeywell)

  private fun hasHoneywellAidc(): Boolean = runCatching {
    Class.forName("com.honeywell.aidc.AidcManager")
  }.isSuccess
}
