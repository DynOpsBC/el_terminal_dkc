package com.dynops.bcwms.scanner

import android.content.Context
import android.os.Build
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent

class ScannerFactory(
  private val context: Context,
) {
  fun create(): Scanner {
    val manufacturer = Build.MANUFACTURER.lowercase()
    val model = Build.MODEL.lowercase()
    return when {
      "honeywell" in manufacturer -> HoneywellScanner()
      "datalogic" in manufacturer -> DatalogicScanner(context)
      "zebra" in manufacturer || "tc" in model -> DataWedgeScanner()
      else -> CameraScanner(context)
    }
  }
}

@Module
@InstallIn(SingletonComponent::class)
object ScannerModule {
  @Provides
  fun provideScannerFactory(@ApplicationContext context: Context): ScannerFactory = ScannerFactory(context)

  @Provides
  fun provideScanner(factory: ScannerFactory): Scanner = factory.create()
}
