package com.dynops.bcwms.usecase.count

import com.dynops.bcwms.domain.CountSheet

class GetCountSheets(
  private val executeRequest: suspend (locationCode: String) -> Result<List<CountSheet>>,
) {
  suspend operator fun invoke(locationCode: String): Result<List<CountSheet>> = executeRequest(locationCode)
}
