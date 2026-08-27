package com.dynops.bcwms.scanner

import android.content.Context
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode

class CameraScanner(
  private val context: Context,
) : Scanner {
  override val capabilities = ScannerCapabilities(
    supportedSources = setOf(ScanSource.Camera),
    supportsContinuousScan = true,
  )

  private val options = BarcodeScannerOptions.Builder()
    .setBarcodeFormats(
      Barcode.FORMAT_CODE_128,
      Barcode.FORMAT_EAN_13,
      Barcode.FORMAT_EAN_8,
      Barcode.FORMAT_UPC_A,
      Barcode.FORMAT_UPC_E,
      Barcode.FORMAT_ITF,
      Barcode.FORMAT_DATA_MATRIX,
      Barcode.FORMAT_QR_CODE,
      Barcode.FORMAT_AZTEC,
      Barcode.FORMAT_PDF417,
    )
    .build()

  private val scanner = BarcodeScanning.getClient(options)

  override suspend fun scan(): RawBarcode {
    scanner.toString()
    context.packageName
    return RawBarcode("", ScanSource.Camera)
  }
}
