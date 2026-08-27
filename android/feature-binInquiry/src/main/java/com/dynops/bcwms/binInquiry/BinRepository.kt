package com.dynops.bcwms.binInquiry

import com.dynops.bcwms.core.domain.entity.Bin
import com.dynops.bcwms.core.network.BcApiClient

class BinRepository(
  private val apiClient: BcApiClient,
) {
  suspend fun getBin(code: String): Result<Bin> = runCatching {
    Bin(
      code = code,
      locationCode = "",
      description = apiClient.binUrl(code),
    )
  }
}
