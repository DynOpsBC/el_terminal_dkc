package com.dynops.bcwms.usecase.pick

import com.dynops.bcwms.entity.PickDoc

class GetPicks(private val executeRequest: suspend (assignedToMe: Boolean) -> Result<List<PickDoc>>) {
  suspend operator fun invoke(assignedToMe: Boolean = true): Result<List<PickDoc>> = executeRequest(assignedToMe)
}
