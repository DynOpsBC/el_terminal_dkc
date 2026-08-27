package com.dynops.bcwms.scanner

import kotlinx.coroutines.channels.Channel

class KeyboardWedgeScanner : Scanner {
  override val capabilities = ScannerCapabilities(setOf(ScanSource.KeyboardWedge))
  private val buffer = StringBuilder()
  private val scans = Channel<RawBarcode>(capacity = Channel.BUFFERED)

  fun onKey(char: Char) {
    when (char) {
      '\n', '\r', '\t' -> flush()
      else -> buffer.append(char)
    }
  }

  private fun flush() {
    val raw = buffer.toString()
    buffer.clear()
    if (raw.isNotBlank()) scans.trySend(RawBarcode(raw, ScanSource.KeyboardWedge))
  }

  override suspend fun scan(): RawBarcode = scans.receive()
}
