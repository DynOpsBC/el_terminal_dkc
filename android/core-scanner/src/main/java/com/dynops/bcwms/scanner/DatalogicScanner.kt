package com.dynops.bcwms.scanner

import android.content.Context
import android.content.Intent

class DatalogicScanner(
  private val context: Context,
  private val fallback: Scanner = FakeScanner(),
) : Scanner {
  override val capabilities = ScannerCapabilities(
    supportedSources = setOf(ScanSource.Datalogic),
    supportsHardwareTrigger = true,
  )

  fun requestScan() {
    context.sendBroadcast(Intent(ACTION_SOFT_TRIGGER))
  }

  override suspend fun scan(): RawBarcode = fallback.scan().copy(symbology = ScanSource.Datalogic)

  companion object {
    const val ACTION_SOFT_TRIGGER = "com.datalogic.decode.action.SOFT_TRIGGER"
  }
}
