package com.dynops.bcwms.usecase.move

import com.dynops.bcwms.domain.entity.MoveDoc

class GetMovements(
  private val executeRequest: suspend (type: String?) -> Result<List<MoveDoc>>,
) {
  suspend operator fun invoke(type: String? = null): Result<List<MoveDoc>> = executeRequest(type)
}
