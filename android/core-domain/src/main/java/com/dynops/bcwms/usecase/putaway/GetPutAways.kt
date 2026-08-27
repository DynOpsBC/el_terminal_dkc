package com.dynops.bcwms.usecase.putaway

import com.dynops.bcwms.domain.entity.PutAwayDoc

class GetPutAways(
  private val executeRequest: suspend (userId: String) -> Result<List<PutAwayDoc>>,
) {
  suspend operator fun invoke(userId: String): Result<List<PutAwayDoc>> = executeRequest(userId)
}
