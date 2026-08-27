package com.dynops.bcwms.usecase.count

import com.dynops.bcwms.domain.CountMode

class CreateCountSheet(
  private val executeRequest: suspend (locationCode: String, mode: CountMode, counters: List<String>) -> Result<String>,
) {
  suspend operator fun invoke(locationCode: String, mode: CountMode, counters: List<String>): Result<String> =
    executeRequest(locationCode, mode, counters.filter { it.isNotBlank() })
}
