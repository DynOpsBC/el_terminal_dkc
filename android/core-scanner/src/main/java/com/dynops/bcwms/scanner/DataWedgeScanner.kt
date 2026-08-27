package com.dynops.bcwms.scanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.channels.Channel

class DataWedgeScanner : BroadcastReceiver(), Scanner {
  override val capabilities = ScannerCapabilities(
    supportedSources = setOf(ScanSource.DataWedge),
    supportsContinuousScan = true,
    supportsHardwareTrigger = true,
  )

  private val scans = Channel<RawBarcode>(capacity = Channel.BUFFERED)

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != ACTION_SCAN) return
    val raw = intent.getStringExtra(EXTRA_DATA_STRING).orEmpty()
    if (raw.isNotBlank()) scans.trySend(RawBarcode(raw, ScanSource.DataWedge))
  }

  override suspend fun scan(): RawBarcode = scans.receive()

  companion object {
    const val ACTION_SCAN = "com.dynops.bcwms.SCAN"
    const val EXTRA_DATA_STRING = "com.symbol.datawedge.data_string"
  }
}
