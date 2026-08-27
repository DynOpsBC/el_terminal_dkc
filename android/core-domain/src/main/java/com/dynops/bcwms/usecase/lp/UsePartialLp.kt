package com.dynops.bcwms.usecase.lp

import com.dynops.bcwms.entity.PartialUseAction

data class UsePartialLpRequest(val lpNo: String, val lineNo: Int, val quantity: Double, val action: PartialUseAction)

class UsePartialLp(private val executeRequest: suspend (UsePartialLpRequest) -> Result<Unit>) {
  suspend operator fun invoke(request: UsePartialLpRequest): Result<Unit> = executeRequest(request)
}
