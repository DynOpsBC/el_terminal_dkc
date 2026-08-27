package com.dynops.bcwms.core.domain.usecase

import com.dynops.bcwms.core.domain.entity.BarcodeIntent

fun interface ParseBarcode {
  suspend operator fun invoke(raw: String): BarcodeIntent
}
