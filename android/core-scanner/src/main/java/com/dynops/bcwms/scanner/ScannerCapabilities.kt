package com.dynops.bcwms.scanner

data class ScannerCapabilities(
  val supportedSources: Set<ScanSource>,
  val supportsContinuousScan: Boolean = false,
  val supportsHardwareTrigger: Boolean = false,
)
